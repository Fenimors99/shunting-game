extends Node2D
class_name Station

const COLOR_TRACK_NORMAL  := Color(0.4, 0.5, 0.7, 0.6)
const COLOR_TRACK_CARGO   := Color(0.9, 0.7, 0.1, 0.8)   # Колія 1
const COLOR_TRACK_REPAIR  := Color(0.9, 0.2, 0.2, 0.8)   # Колія 7
const COLOR_BG            := Color(0.08, 0.12, 0.18, 0.9)
const COLOR_BORDER        := Color(0.3, 0.4, 0.55, 0.5)

signal track_entry_tapped(track_index: int)
signal track_exit_tapped(track_index: int)
signal track_exit_choice(track_index: int, submit: bool)

var _track_wagons: Array = []      # Array[Array[Wagon]]
var _track_reserved: Array = []    # int на колію: зарезервовані + припарковані
var _entry_buttons: Array = []     # Array[Button]
var _exit_buttons: Array = []      # Array[Button]
var _choice_containers: Array = [] # Array[Node2D], для колій 2-6
var _submit_buttons:    Array = [] # Array[Button], кнопка "Здати ✓" для кожної колії 2-6
var _filter_active: bool = false
var _filter_type: Wagon.WagonType = Wagon.WagonType.NORMAL
var _loco_available: bool = true
var _task_manager: TaskManager = null

func _ready() -> void:
	_track_wagons.resize(Layout.TRACK_COUNT)
	_track_reserved.resize(Layout.TRACK_COUNT)
	_submit_buttons.resize(Layout.TRACK_COUNT)
	for i in Layout.TRACK_COUNT:
		_track_wagons[i] = []
		_track_reserved[i] = 0
		_submit_buttons[i] = null
	_create_entry_buttons()
	_create_exit_buttons()
	_create_choice_containers()
	_create_repair_depot_roof()

func _create_repair_depot_roof() -> void:
	var roof := Node2D.new()
	roof.z_index = 1  # один рівень над рейками/вагонами що на z=0
	roof.connect("draw", func():
		roof.draw_rect(Layout.REPAIR_DEPOT_RECT, Color(0.9, 0.2, 0.2, 1.0), true)
		roof.draw_rect(Layout.REPAIR_DEPOT_RECT, Color(0.7, 0.1, 0.1, 1.0), false, 2.0)
	)
	add_child(roof)

# Розраховує (start_x, end_x) рейок для колії відносно центральної (найдовшої).
# Коротші колії симетрично зміщені всередину, формуючи шестикутник.
func _get_track_bounds(track_index: int) -> Vector2:
	var cap_diff := float(Layout.MAX_TRACK_CAPACITY - Layout.get_track_capacity(track_index))
	var offset   := (cap_diff / 2.0) * Layout.WAGON_GAP
	return Vector2(Layout.STATION_LEFT + offset, Layout.STATION_RIGHT - offset)

func reserve_slot(track_index: int) -> int:
	var idx := track_index - 1
	var slot: int = _track_reserved[idx]
	_track_reserved[idx] += 1
	_refresh_entry_button(track_index)
	_refresh_exit_button(track_index)
	return slot

func place_wagon(wagon: Wagon, track_index: int, slot: int) -> void:
	_track_wagons[track_index - 1].append(wagon)
	# Передаємо track_index для правильного зміщення
	wagon.position = Vector2(Layout.get_slot_x(track_index, slot), Layout.get_track_y(track_index))
	_refresh_exit_button(track_index)

func pop_all_wagons(track_index: int) -> Array:
	var idx := track_index - 1
	var wagons: Array = _track_wagons[idx].duplicate()
	_track_wagons[idx].clear()
	_track_reserved[idx] = 0
	_refresh_entry_button(track_index)
	_refresh_exit_button(track_index)
	return wagons

func is_track_full(track_index: int) -> bool:
	return _track_reserved[track_index - 1] >= Layout.get_track_capacity(track_index)

func get_wagon_count(track_index: int) -> int:
	return _track_wagons[track_index - 1].size()

# --- Малювання ---

func _draw() -> void:
	_draw_station_bg()
	_draw_tracks()
	_draw_junction_line()
	_draw_exit_rails()

func _draw_station_bg() -> void:
	var top_y    := Layout.TRACK_TOP - 50.0
	var bottom_y := Layout.get_track_y(Layout.TRACK_COUNT) + 40.0
	# Екватор шестикутника — центральна (найдовша) колія
	var mid_y    := Layout.get_track_y((Layout.TRACK_COUNT + 1) / 2)

	# Базові межі фону: трохи ширші за станцію
	var padding    := 30.0
	var left_base  := Layout.STATION_LEFT  - padding
	var right_base := Layout.STATION_RIGHT + padding

	# Зміщення кута = відступ до найкоротшої колії + базовий padding фону.
	# Так кут шестикутника візуально збігається з початком крайньої колії.
	var min_cap        := float(Layout.MAX_TRACK_CAPACITY - Layout.TRACK_CAPACITIES.values().min())
	var track_offset   := (min_cap / 2.0) * Layout.WAGON_GAP
	var corner_indent  := padding + track_offset

	var points := PackedVector2Array([
		Vector2(left_base + corner_indent, top_y),       # Верхній лівий кут
		Vector2(right_base - corner_indent, top_y),      # Верхній правий кут
		Vector2(right_base, mid_y),                      # Середній правий кут (екватор)
		Vector2(right_base - corner_indent, bottom_y),   # Нижній правий кут
		Vector2(left_base + corner_indent, bottom_y),    # Нижній лівий кут
		Vector2(left_base, mid_y)                        # Середній лівий кут
	])

	# Малюємо заливку
	draw_colored_polygon(points, Color(0.05, 0.08, 0.14, 0.97))

	# Малюємо зовнішню рамку
	var line_points := points.duplicate()
	line_points.append(points[0]) # Замикаємо контур
	draw_polyline(line_points, Color(0.25, 0.38, 0.55, 0.8), 2.0)

	# Малюємо внутрішній світлий контур (трохи звужений)
	var in_points := PackedVector2Array([
		Vector2(left_base + corner_indent, top_y + 3),
		Vector2(right_base - corner_indent, top_y + 3),
		Vector2(right_base - 3, mid_y),
		Vector2(right_base - corner_indent, bottom_y - 3),
		Vector2(left_base + corner_indent, bottom_y - 3),
		Vector2(left_base + 3, mid_y),
		Vector2(left_base + corner_indent, top_y + 3)
	])
	draw_polyline(in_points, Color(0.45, 0.6, 0.8, 0.12), 1.0)

func _draw_tracks() -> void:
	var labels := ["Колія 1 — вантажна", "Колія 2", "Колія 3",
				   "Колія 4", "Колія 5", "Колія 6", "Колія 7 — ремонтна"]
	var font := ThemeDB.fallback_font

	for i in Layout.TRACK_COUNT:
		var track_idx = i + 1
		var y := Layout.get_track_y(track_idx)
		var bounds := _get_track_bounds(track_idx)
		var start_x = bounds.x
		var end_x = bounds.y
		
		var color := COLOR_TRACK_NORMAL
		if i == 0:   color = COLOR_TRACK_CARGO
		elif i == 6: color = COLOR_TRACK_REPAIR

		# Шпали
		var sleeper_color := Color(0.28, 0.32, 0.38, 0.55)
		var sx: float = start_x
		while sx <= end_x:
			draw_line(Vector2(sx, y - 5), Vector2(sx, y + 5), sleeper_color, 2.5)
			sx += 24.0

		# Рейки (дві нитки), підрізані під шестикутник
		draw_line(Vector2(start_x, y - 3), Vector2(end_x, y - 3), color, 2.0)
		draw_line(Vector2(start_x, y + 3), Vector2(end_x, y + 3), color, 2.0)

		# Підпис
		draw_string(font,
			Vector2(start_x + 10, y - 30),
			labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(0.65, 0.75, 0.9, 0.75)
		)

func _draw_junction_line() -> void:
	var rail_color := Color(0.5, 0.6, 0.75, 0.5)
	var thin_color := COLOR_BORDER

	# 1. Горизонтальна черга до початку L-повороту
	_draw_rail_segment(
		Vector2(get_viewport_rect().size.x, Layout.QUEUE_Y),
		Vector2(Layout.QUEUE_STOP_X + Layout.QUEUE_ARC_R, Layout.QUEUE_Y),
		rail_color
	)

	# 2. Дуга від черги до центру (колія 4)
	_draw_curved_rail(Layout.get_entry_arc(), rail_color)

	# 3. Верхня гілка: центр (колія 4) → колія 3 → 2 → 1
	for i in range(Layout.CENTER_TRACK - 1, 0, -1):
		_draw_rail_segment(
			Vector2(Layout.get_dist_rail_x(i + 1), Layout.get_track_y(i + 1)),
			Vector2(Layout.get_dist_rail_x(i),     Layout.get_track_y(i)),
			thin_color
		)

	# 4. Нижня гілка: центр (колія 4) → колія 5 → 6 → 7
	for i in range(Layout.CENTER_TRACK + 1, Layout.TRACK_COUNT + 1):
		_draw_rail_segment(
			Vector2(Layout.get_dist_rail_x(i - 1), Layout.get_track_y(i - 1)),
			Vector2(Layout.get_dist_rail_x(i),     Layout.get_track_y(i)),
			thin_color
		)


func _draw_curved_rail(pts: PackedVector2Array, color: Color) -> void:
	if pts.size() < 2:
		return
	var pts_a := PackedVector2Array()
	var pts_b := PackedVector2Array()
	for i in range(pts.size()):
		var dir: Vector2
		if i == 0:
			dir = (pts[1] - pts[0]).normalized()
		elif i == pts.size() - 1:
			dir = (pts[i] - pts[i - 1]).normalized()
		else:
			dir = (pts[i + 1] - pts[i - 1]).normalized()
		var n := Vector2(-dir.y, dir.x)
		pts_a.append(pts[i] + n * 3.0)
		pts_b.append(pts[i] - n * 3.0)
	draw_polyline(pts_a, color, 2.0)
	draw_polyline(pts_b, color, 2.0)


func _draw_rail_segment(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := (to - from).normalized()
	var normal := Vector2(-dir.y, dir.x)
	var rail_offset := 3.0

	draw_line(from + normal * rail_offset, to + normal * rail_offset, color, 2.0)
	draw_line(from - normal * rail_offset, to - normal * rail_offset, color, 2.0)

	var sleeper_color := Color(0.778, 0.825, 0.947, 0.608) 
	var length := from.distance_to(to)
	var step := 20.0
	var dist := 7.0

	while dist <= length - 5.0:
		var t := dist / length
		var pos := from.lerp(to, t)
		var angle := dir.angle()
		draw_set_transform(pos, angle, Vector2.ONE)
		draw_rect(Rect2(-9, -3, 2, 8), sleeper_color)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		dist += step
		
func _draw_exit_rails() -> void:
	var rail_color := Color(0.5, 0.6, 0.75, 0.5)
	var thin_color := COLOR_BORDER

	# 1. Горизонтальні відрізки від правого краю кожної колії до збірної рейки
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		var bounds := _get_track_bounds(i)
		_draw_rail_segment(
			Vector2(bounds.y, y),
			Vector2(Layout.get_exit_rail_x(i), y),
			rail_color
		)

	# 2. Збірна рейка: верхня гілка (колія 3→2→1)
	for i in range(Layout.CENTER_TRACK - 1, 0, -1):
		_draw_rail_segment(
			Vector2(Layout.get_exit_rail_x(i + 1), Layout.get_track_y(i + 1)),
			Vector2(Layout.get_exit_rail_x(i),     Layout.get_track_y(i)),
			thin_color
		)

	# 3. Збірна рейка: нижня гілка (колія 5→6→7)
	for i in range(Layout.CENTER_TRACK + 1, Layout.TRACK_COUNT + 1):
		_draw_rail_segment(
			Vector2(Layout.get_exit_rail_x(i - 1), Layout.get_track_y(i - 1)),
			Vector2(Layout.get_exit_rail_x(i),     Layout.get_track_y(i)),
			thin_color
		)

	# 3.4. Вихід колії 1: дуга право→вгору + вертикаль за екран
	var arc1 := Layout.get_track1_exit_arc()
	_draw_curved_rail(arc1, rail_color)
	var arc1_end := arc1[arc1.size() - 1]
	_draw_rail_segment(arc1_end, Vector2(arc1_end.x, 0.0), rail_color)

	# 3.5. Пряма гілка від колії 7 до ремонтного депо
	var track7_y := Layout.get_track_y(7)
	var fork_x   := Layout.get_exit_rail_x(7)
	_draw_rail_segment(
		Vector2(fork_x, track7_y),
		Vector2(Layout.REPAIR_DEPOT_RECT.position.x, track7_y),
		rail_color
	)

	# 3.6. Пряма здачі завдань: від центру (колія 4) вправо за екран
	var center4 := Layout.get_exit_center_point()
	_draw_rail_segment(center4, Vector2(get_viewport_rect().size.x, center4.y), rail_color)

	# 4. Вихідна дуга
	_draw_curved_rail(Layout.get_exit_arc(), rail_color)

	# 5. Горизонталь від кінця дуги до правого краю екрана
	_draw_rail_segment(
		Vector2(Layout.EXIT_STOP_X + Layout.QUEUE_ARC_R, Layout.QUEUE_Y),
		Vector2(get_viewport_rect().size.x, Layout.QUEUE_Y),
		rail_color
	)

# --- Кнопки входу ---

func _create_entry_buttons() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		var bounds := _get_track_bounds(i)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(52, 52)
		# Зміщуємо кнопку паралельно межі шестикутника
		btn.position = Vector2(bounds.x - 80, y - 26)
		btn.add_theme_stylebox_override("normal",  _make_circle_style(Color(0.1, 0.3, 0.7, 0.9)))
		btn.add_theme_stylebox_override("hover",   _make_circle_style(Color(0.2, 0.5, 1.0)))
		btn.add_theme_stylebox_override("pressed", _make_circle_style(Color(0.05, 0.2, 0.6)))
		btn.add_theme_color_override("font_color", Color.WHITE)
		var idx := i
		btn.pressed.connect(func(): track_entry_tapped.emit(idx))
		add_child(btn)
		_entry_buttons.append(btn)

func set_entry_filter(wagon_type: Wagon.WagonType) -> void:
	_filter_active = true
	_filter_type = wagon_type
	for i in range(1, Layout.TRACK_COUNT + 1):
		_refresh_entry_button(i)

func clear_entry_filter() -> void:
	_filter_active = false
	for i in range(1, Layout.TRACK_COUNT + 1):
		_refresh_entry_button(i)

func _refresh_entry_button(track_index: int) -> void:
	var btn: Button = _entry_buttons[track_index - 1]
	if is_track_full(track_index):
		btn.text = ""
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", _make_circle_style(Color(0.3, 0.15, 0.15, 0.6)))
	elif _filter_active and not Layout.is_wagon_compatible(_filter_type, track_index):
		btn.text = "+"
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", _make_circle_style(Color(0.15, 0.15, 0.18, 0.5)))
	else:
		btn.text = "+"
		btn.disabled = false
		btn.add_theme_stylebox_override("normal", _make_circle_style(Color(0.1, 0.3, 0.7, 0.9)))


# --- Кнопки виходу ---

func _create_exit_buttons() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		var bounds := _get_track_bounds(i)
		var btn := Button.new()
		btn.text = ">"
		btn.custom_minimum_size = Vector2(52, 52)
		# Зміщуємо кнопку паралельно межі шестикутника
		btn.position = Vector2(bounds.y + 40, y - 26)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.disabled = true
		var idx := i
		btn.pressed.connect(func(): _on_exit_pressed(idx))
		add_child(btn)
		_exit_buttons.append(btn)
		_set_exit_btn_green(i)

func set_task_manager(tm: TaskManager) -> void:
	_task_manager = tm

func refresh_all_exit_buttons() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		_refresh_exit_button(i)

func set_loco_available(available: bool) -> void:
	_loco_available = available
	for i in range(1, Layout.TRACK_COUNT + 1):
		_refresh_exit_button(i)

func _refresh_exit_button(track_index: int) -> void:
	# Якщо меню зараз відкрите — оновлюємо кнопку "Здати" під актуальний склад колії,
	# але не чіпаємо саму кнопку-стрілку (щоб гравець міг закрити меню).
	if _choice_containers[track_index - 1].visible:
		var btn_s: Button = _submit_buttons[track_index - 1]
		if btn_s != null and _task_manager != null:
			btn_s.disabled = not _task_manager.can_submit(_track_wagons[track_index - 1])
		return
		
	var parked: int = get_wagon_count(track_index)
	var in_transit: bool = _track_reserved[track_index - 1] > parked
	_exit_buttons[track_index - 1].disabled = parked == 0 or in_transit or not _loco_available

func _on_exit_pressed(track_index: int) -> void:
	if track_index == Layout.CARGO_TRACK or track_index == Layout.REPAIR_TRACK:
		track_exit_tapped.emit(track_index)
	else:
		# Перевіряємо, чи вже відкрите меню для цієї колії
		if _choice_containers[track_index - 1].visible:
			_hide_choice(track_index)
		else:
			_show_choice(track_index)

# --- Вибір напрямку (колії 2-6) ---

func _create_choice_containers() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		var container := Node2D.new()
		container.visible = false
		add_child(container)
		_choice_containers.append(container)

		if i == Layout.CARGO_TRACK or i == Layout.REPAIR_TRACK:
			continue

		var y := Layout.get_track_y(i)
		var bounds := _get_track_bounds(i)
		var bx := bounds.y + 110.0  # Правіше кнопки-стрілочки по діагоналі

		var btn_s := _make_choice_btn("Здати", Color(0.1, 0.45, 0.15))
		btn_s.position = Vector2(bx, y - 58)
		container.add_child(btn_s)
		_submit_buttons[i - 1] = btn_s

		var btn_q := _make_choice_btn("В чергу", Color(0.45, 0.28, 0.08))
		btn_q.position = Vector2(bx, y + 14)
		container.add_child(btn_q)

		var idx := i
		btn_s.pressed.connect(func(): _on_choice(idx, true))
		btn_q.pressed.connect(func(): _on_choice(idx, false))
		

func _hide_choice(track_index: int) -> void:
	_choice_containers[track_index - 1].visible = false
	_set_exit_btn_green(track_index)
	_refresh_exit_button(track_index)

func _show_choice(track_index: int) -> void:
	_choice_containers[track_index - 1].visible = true
	_set_exit_btn_red(track_index)
	
	# "Здати ✓" доступна тільки якщо вагони точно закривають одне завдання
	var btn_s: Button = _submit_buttons[track_index - 1]
	if btn_s != null and _task_manager != null:
		btn_s.disabled = not _task_manager.can_submit(_track_wagons[track_index - 1])

func _on_choice(track_index: int, submit: bool) -> void:
	_hide_choice(track_index) # Ховаємо меню і скидаємо колір кнопки
	track_exit_choice.emit(track_index, submit)

func _make_choice_btn(label: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(146, 44)
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(8)
	s.set_border_width_all(2)
	s.border_color = color.lightened(0.3)
	btn.add_theme_stylebox_override("normal", s)
	var sh := s.duplicate()
	sh.bg_color = color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func _set_exit_btn_green(track_index: int) -> void:
	var btn: Button = _exit_buttons[track_index - 1]
	btn.add_theme_stylebox_override("normal",  _make_circle_style(Color(0.1, 0.45, 0.15, 0.9)))
	btn.add_theme_stylebox_override("hover",   _make_circle_style(Color(0.2, 0.7, 0.25)))
	btn.add_theme_stylebox_override("pressed", _make_circle_style(Color(0.05, 0.3, 0.1)))

func _set_exit_btn_red(track_index: int) -> void:
	var btn: Button = _exit_buttons[track_index - 1]
	btn.add_theme_stylebox_override("normal",  _make_circle_style(Color(0.8, 0.2, 0.2, 0.9)))
	btn.add_theme_stylebox_override("hover",   _make_circle_style(Color(0.9, 0.3, 0.3)))
	btn.add_theme_stylebox_override("pressed", _make_circle_style(Color(0.6, 0.1, 0.1)))

func _make_circle_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(0.3, 0.6, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(26)
	return s
