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
var _filter_active: bool = false
var _filter_type: Wagon.WagonType = Wagon.WagonType.NORMAL
var _loco_available: bool = true

func _ready() -> void:
	_track_wagons.resize(Layout.TRACK_COUNT)
	_track_reserved.resize(Layout.TRACK_COUNT)
	for i in Layout.TRACK_COUNT:
		_track_wagons[i] = []
		_track_reserved[i] = 0
	_create_entry_buttons()
	_create_exit_buttons()
	_create_choice_containers()

# --- Публічний API ---

func reserve_slot(track_index: int) -> int:
	var idx := track_index - 1
	var slot: int = _track_reserved[idx]
	_track_reserved[idx] += 1
	_refresh_entry_button(track_index)
	_refresh_exit_button(track_index)
	return slot

func place_wagon(wagon: Wagon, track_index: int, slot: int) -> void:
	_track_wagons[track_index - 1].append(wagon)
	# Використовуємо global_position, бо Layout повертає екранні координати
	wagon.global_position = Vector2(Layout.get_slot_x(track_index, slot), get_track_y(track_index))
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

func get_track_y(track_index: int) -> float:
	return Layout.get_track_y(track_index)

# --- Малювання ---

func _draw() -> void:
	_draw_station_bg()
	_draw_tracks()
	_draw_junction_line()
	_draw_exit_rails()

func _draw_station_bg() -> void:
	var left   := Layout.STATION_LEFT - 40
	var right  := Layout.STATION_RIGHT + 10 # Трохи додав простору для "носа"
	var top    := Layout.TRACK_TOP - 60
	var bottom := Layout.get_track_y(Layout.TRACK_COUNT) + 60
	
	var width := right - left
	var height := bottom - top
	var center_y := top + height / 2.0
	
	# Параметр звуження тільки для правої сторони
	var corner_offset := 100.0 

	# Точки фігури (Прямокутник зліва + Шестикутник справа = П'ятикутник)
	var shape_points := PackedVector2Array([
		Vector2(left, top),                    # 1. Верхній лівий (прямий кут)
		Vector2(right - corner_offset, top),   # 2. Початок звуження зверху справа
		Vector2(right, center_y),              # 3. Правий "ніс" (вершина)
		Vector2(right - corner_offset, bottom),# 4. Кінець звуження знизу справа
		Vector2(left, bottom)                  # 5. Нижній лівий (прямий кут)
	])

	# 1. Малюємо основний фон
	draw_polygon(shape_points, [Color(0.05, 0.08, 0.14, 0.97)])

	# 2. Малюємо підсвітку смуг (колій)
	for i in Layout.TRACK_COUNT:
		var y := Layout.get_track_y(i + 1)
		var lane_h := Layout.TRACK_SPACING * 0.75
		var stripe_color := Color(0.12, 0.18, 0.28, 0.5) if i % 2 == 0 else Color(0.07, 0.11, 0.19, 0.5)
		
		# Смуги починаються від прямого лівого краю і не доходять до гострого носа справа
		var s_left := left + 5.0
		var s_right := right - corner_offset
		draw_rect(Rect2(s_left, y - lane_h * 0.5, s_right - s_left, lane_h), stripe_color)

	# 3. Зовнішня рамка (обводка)
	# Додаємо першу точку в кінець, щоб лінія замкнулася автоматично
	var border_points := shape_points
	border_points.append(shape_points[0])
	draw_polyline(border_points, Color(0.25, 0.38, 0.55, 0.8), 2.5, true)

	# 4. Декоративний внутрішній контур ("скляний" ефект)
	var inner_margin := 4.0
	var inner_points := PackedVector2Array([
		Vector2(left + inner_margin, top + inner_margin),
		Vector2(right - corner_offset - inner_margin, top + inner_margin),
		Vector2(right - inner_margin * 2.0, center_y),
		Vector2(right - corner_offset - inner_margin, bottom - inner_margin),
		Vector2(left + inner_margin, bottom - inner_margin),
		Vector2(left + inner_margin, top + inner_margin)
	])
	draw_polyline(inner_points, Color(0.45, 0.6, 0.8, 0.12), 1.0, true)
	
func _draw_tracks() -> void:
	# 1. Ті самі межі, що ми використовували для малювання фону
	var left   := Layout.STATION_LEFT - 40
	var right  := Layout.STATION_RIGHT + 100
	var top    := Layout.TRACK_TOP - 60
	var bottom := Layout.get_track_y(Layout.TRACK_COUNT) + 60
	
	var height := bottom - top
	var center_y := top + height / 2.0
	var corner_offset := 70.0 # Має бути таким самим, як у _draw_station_bg
	
	for i in Layout.TRACK_COUNT:
		var track_y := Layout.get_track_y(i + 1)
		
		# --- РОЗРАХУНОК ОБРІЗКИ ---
		
		# Вираховуємо, наскільки далеко від центру (по вертикалі) знаходиться колія
		# 0.0 = центр, 1.0 = самий верх або самий нижній край
		var distance_from_center := absf(track_y - center_y) / (height / 2.0)
		
		# Чим далі колія від центру, тим сильніше ми її "підрізаємо" згідно зі скосом
		var track_right_edge := right - (distance_from_center * corner_offset)
		
		# Трохи відступимо від самого краю для краси (наприклад, на 10 пікселів)
		var final_x_end := track_right_edge - 10.0
		
		# 2. Малюємо саму колію (лінію)
		# Вона починається від прямого лівого краю і закінчується на розрахованій точці
		draw_line(
			Vector2(left, track_y), 
			Vector2(final_x_end, track_y), 
			Color(0.3, 0.4, 0.5, 0.4), # Колір рейок
			1.0 # Товщина
		)
		
		# 3. Малюємо текст (назви колій)
		# Тепер ми теж можемо їх підняти (як ви питали раніше)
		var labels := ["Колія 1 — вантажна", "Колія 2", "Колія 3",
					   "Колія 4", "Колія 5", "Колія 6", "Колія 7 — ремонтна"]
		
		var text_pos := Vector2(left + 20, track_y - 20) # Підняли на 20 пікселів
		draw_string(ThemeDB.fallback_font, text_pos, labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.GRAY)

func _draw_junction_line() -> void:
	var rail_color := Color(0.5, 0.6, 0.75, 0.5)
	var thin_color := COLOR_BORDER

	# 1. Основна горизонтальна лінія (черга)
	# Додаємо невеликий нахлест (наприклад, 5 пікселів), щоб рейки візуально зістикувалися
	_draw_rail_segment(
		Vector2(get_viewport_rect().size.x, Layout.QUEUE_Y),
		Vector2(Layout.JUNCTION_X - 3, Layout.QUEUE_Y), 
		rail_color
	)

	# 2. Обчислюємо реальні межі вертикального стовбура
	# Починаємо з координати черги
	var min_y = Layout.QUEUE_Y
	var max_y = Layout.QUEUE_Y
	
	# Перевіряємо всі точки, де колії приєднуються до стовбура (y + 20)
	for i in range(1, Layout.TRACK_COUNT + 1):
		var branch_connection_y = Layout.get_track_y(i) + 20
		min_y = min(min_y, branch_connection_y)
		max_y = max(max_y, branch_connection_y)

	# 3. Малюємо вертикальний "стовбур" від найвищої до найнижчої точки
	_draw_rail_segment(
		Vector2(Layout.JUNCTION_X, min_y),
		Vector2(Layout.JUNCTION_X, max_y),
		thin_color
	)
	
	# 4. Малюємо відгалуження до колій
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		var start := Vector2(Layout.JUNCTION_X, y + 20)
		var mid := Vector2(Layout.JUNCTION_X + 40, y)
		var end := Vector2(Layout.STATION_LEFT - 30, y)

		_draw_rail_segment(start, mid, thin_color)
		_draw_rail_segment(mid, end, thin_color)
		
		
func _draw_rail_segment(from: Vector2, to: Vector2, color: Color) -> void:
	var dir := (to - from).normalized()
	var normal := Vector2(-dir.y, dir.x)

	var rail_offset := 3.0

	# рейки
	draw_line(from + normal * rail_offset, to + normal * rail_offset, color, 2.0)
	draw_line(from - normal * rail_offset, to - normal * rail_offset, color, 2.0)

	# шпали
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
	var rail_color := Color(0.5, 0.6, 0.75, 0.4)
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		draw_line(Vector2(Layout.STATION_RIGHT, y), Vector2(Layout.STATION_RIGHT + 60, y), rail_color, 1.5)


# --- Кнопки входу ---

func _create_entry_buttons() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(52, 52)
		btn.position = Vector2(Layout.STATION_LEFT - 100, y - 26)
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
		var btn := Button.new()
		btn.text = "→"
		btn.custom_minimum_size = Vector2(52, 52)
		btn.position = Vector2(Layout.STATION_RIGHT + 90, y - 26)
		btn.add_theme_stylebox_override("normal",  _make_circle_style(Color(0.1, 0.45, 0.15, 0.9)))
		btn.add_theme_stylebox_override("hover",   _make_circle_style(Color(0.2, 0.7, 0.25)))
		btn.add_theme_stylebox_override("pressed", _make_circle_style(Color(0.05, 0.3, 0.1)))
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.disabled = true
		var idx := i
		btn.pressed.connect(func(): _on_exit_pressed(idx))
		add_child(btn)
		_exit_buttons.append(btn)

func set_loco_available(available: bool) -> void:
	_loco_available = available
	for i in range(1, Layout.TRACK_COUNT + 1):
		_refresh_exit_button(i)

func _refresh_exit_button(track_index: int) -> void:
	var parked: int = get_wagon_count(track_index)
	var in_transit: bool = _track_reserved[track_index - 1] > parked
	_exit_buttons[track_index - 1].disabled = \
		parked == 0 or in_transit or not _loco_available

func _on_exit_pressed(track_index: int) -> void:
	if track_index == 1 or track_index == 7:
		track_exit_tapped.emit(track_index)
	else:
		_show_choice(track_index)

# --- Вибір напрямку (колії 2-6) ---

func _create_choice_containers() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		var container := Node2D.new()
		container.visible = false
		add_child(container)
		_choice_containers.append(container)

		if i == 1 or i == 7:
			continue

		var y := Layout.get_track_y(i)
		var bx := Layout.STATION_RIGHT + 180.0  # правіше кнопки-стрілочки

		var btn_s := _make_choice_btn("Здати ✓", Color(0.1, 0.45, 0.15))
		btn_s.position = Vector2(bx, y - 58)   # вище колії
		container.add_child(btn_s)

		var btn_q := _make_choice_btn("В чергу ↩", Color(0.45, 0.28, 0.08))
		btn_q.position = Vector2(bx, y + 14)   # нижче колії
		container.add_child(btn_q)

		var idx := i
		btn_s.pressed.connect(func(): _on_choice(idx, true))
		btn_q.pressed.connect(func(): _on_choice(idx, false))

func _show_choice(track_index: int) -> void:
	_choice_containers[track_index - 1].visible = true
	_exit_buttons[track_index - 1].disabled = true

func _on_choice(track_index: int, submit: bool) -> void:
	_choice_containers[track_index - 1].visible = false
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

func _make_circle_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(0.3, 0.6, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(26)
	return s
