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
	wagon.position = Vector2(Layout.get_slot_x(slot), get_track_y(track_index))
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
	var left   := Layout.STATION_LEFT - 30
	var top    := Layout.TRACK_TOP - 40
	var right  := Layout.STATION_RIGHT + 62   # охоплює кнопки виходу
	var bottom := Layout.get_track_y(Layout.TRACK_COUNT) + 40
	var w := right - left
	var h := bottom - top

	# Основний фон
	draw_rect(Rect2(left, top, w, h), Color(0.05, 0.08, 0.14, 0.97))

	# Підсвітка смуг між коліями
	for i in Layout.TRACK_COUNT:
		var y := Layout.get_track_y(i + 1)
		var lane_h := Layout.TRACK_SPACING * 0.72
		var c := Color(0.12, 0.18, 0.28, 0.5) if i % 2 == 0 else Color(0.07, 0.11, 0.19, 0.5)
		draw_rect(Rect2(left, y - lane_h * 0.5, w, lane_h), c)

	# Зовнішня рамка
	draw_rect(Rect2(left, top, w, h), Color(0.25, 0.38, 0.55, 0.8), false, 2.0)
	# Внутрішній світлий контур
	draw_rect(Rect2(left + 3, top + 3, w - 6, h - 6), Color(0.45, 0.6, 0.8, 0.12), false, 1.0)

func _draw_tracks() -> void:
	var labels := ["Колія 1 — вантажна", "Колія 2", "Колія 3",
				   "Колія 4", "Колія 5", "Колія 6", "Колія 7 — ремонтна"]
	var font := ThemeDB.fallback_font

	for i in Layout.TRACK_COUNT:
		var y := Layout.get_track_y(i + 1)
		var color := COLOR_TRACK_NORMAL
		if i == 0:   color = COLOR_TRACK_CARGO
		elif i == 6: color = COLOR_TRACK_REPAIR

		# Шпали
		var sleeper_color := Color(0.28, 0.32, 0.38, 0.55)
		var sx := Layout.STATION_LEFT
		while sx <= Layout.STATION_RIGHT:
			draw_line(Vector2(sx, y - 5), Vector2(sx, y + 5), sleeper_color, 2.5)
			sx += 24.0

		# Рейки (дві нитки)
		draw_line(Vector2(Layout.STATION_LEFT, y - 3), Vector2(Layout.STATION_RIGHT, y - 3), color, 2.0)
		draw_line(Vector2(Layout.STATION_LEFT, y + 3), Vector2(Layout.STATION_RIGHT, y + 3), color, 2.0)

		# Підпис
		draw_string(font,
			Vector2(Layout.STATION_LEFT + 10, y - 12),
			labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Color(0.65, 0.75, 0.9, 0.75)
		)

func _draw_junction_line() -> void:
	draw_line(Vector2(get_viewport_rect().size.x, Layout.QUEUE_Y), Vector2(Layout.JUNCTION_X, Layout.QUEUE_Y), Color(0.5, 0.6, 0.75, 0.5), 3.0)
	draw_line(Vector2(Layout.JUNCTION_X, Layout.QUEUE_Y), Vector2(Layout.JUNCTION_X, Layout.TRACK_TOP), COLOR_BORDER, 1.5)
	draw_line(Vector2(Layout.JUNCTION_X, Layout.TRACK_TOP), Vector2(Layout.STATION_LEFT - 30, Layout.TRACK_TOP), COLOR_BORDER, 1.5)

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
	elif _filter_active and not _track_compatible(_filter_type, track_index):
		btn.text = "+"
		btn.disabled = true
		btn.add_theme_stylebox_override("disabled", _make_circle_style(Color(0.15, 0.15, 0.18, 0.5)))
	else:
		btn.text = "+"
		btn.disabled = false
		btn.add_theme_stylebox_override("normal", _make_circle_style(Color(0.1, 0.3, 0.7, 0.9)))

static func _track_compatible(wagon_type: Wagon.WagonType, track_index: int) -> bool:
	match wagon_type:
		Wagon.WagonType.BROKEN: return track_index == 7
		Wagon.WagonType.CARGO:  return track_index == 1
		_: return track_index != 1 and track_index != 7

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
