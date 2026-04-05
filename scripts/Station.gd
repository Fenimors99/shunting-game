extends Node2D
class_name Station

const COLOR_TRACK_NORMAL  := Color(0.4, 0.5, 0.7, 0.6)
const COLOR_TRACK_CARGO   := Color(0.9, 0.7, 0.1, 0.8)   # Колія 1
const COLOR_TRACK_REPAIR  := Color(0.9, 0.2, 0.2, 0.8)   # Колія 7
const COLOR_BG            := Color(0.08, 0.12, 0.18, 0.9)
const COLOR_BORDER        := Color(0.3, 0.4, 0.55, 0.5)

signal track_entry_tapped(track_index: int)

func _ready() -> void:
	_create_entry_buttons()

func get_track_y(track_index: int) -> float:
	return Layout.get_track_y(track_index)

# --- Малювання ---

func _draw() -> void:
	_draw_station_bg()
	_draw_tracks()
	_draw_junction_line()

func _draw_station_bg() -> void:
	var rect := Rect2(
		Vector2(Layout.STATION_LEFT - 30, Layout.TRACK_TOP - 40),
		Vector2(Layout.STATION_RIGHT - Layout.STATION_LEFT + 60, (Layout.TRACK_COUNT - 1) * Layout.TRACK_SPACING + 80)
	)
	draw_rect(rect, COLOR_BG)
	draw_rect(rect, COLOR_BORDER, false, 1.5)

func _draw_tracks() -> void:
	var labels := ["Колія 1 — вантажна", "Колія 2", "Колія 3",
				   "Колія 4", "Колія 5", "Колія 6", "Колія 7 — ремонтна"]
	for i in Layout.TRACK_COUNT:
		var y := Layout.get_track_y(i + 1)
		var color := COLOR_TRACK_NORMAL
		if i == 0:
			color = COLOR_TRACK_CARGO
		elif i == 6:
			color = COLOR_TRACK_REPAIR
		draw_line(Vector2(Layout.STATION_LEFT, y), Vector2(Layout.STATION_RIGHT, y), color, 3.0)

		draw_string(
			ThemeDB.fallback_font,
			Vector2(Layout.STATION_LEFT + 14, y - 10),
			labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
			Color(0.6, 0.7, 0.85, 0.7)
		)

func _draw_junction_line() -> void:
	draw_line(Vector2(Layout.JUNCTION_X, Layout.QUEUE_Y), Vector2(Layout.JUNCTION_X, Layout.TRACK_TOP), COLOR_BORDER, 1.5)
	draw_line(Vector2(Layout.JUNCTION_X, Layout.TRACK_TOP), Vector2(Layout.STATION_LEFT - 30, Layout.TRACK_TOP), COLOR_BORDER, 1.5)

# --- Кнопки входу (сині кружечки "+") ---

func _create_entry_buttons() -> void:
	for i in range(1, Layout.TRACK_COUNT + 1):
		var y := Layout.get_track_y(i)
		var btn := Button.new()
		btn.text = "+"
		btn.custom_minimum_size = Vector2(52, 52)
		btn.position = Vector2(Layout.STATION_LEFT - 72, y - 26)
		btn.add_theme_stylebox_override("normal",  _make_circle_style(Color(0.1, 0.3, 0.7, 0.9)))
		btn.add_theme_stylebox_override("hover",   _make_circle_style(Color(0.2, 0.5, 1.0)))
		btn.add_theme_stylebox_override("pressed", _make_circle_style(Color(0.05, 0.2, 0.6)))
		btn.add_theme_color_override("font_color", Color.WHITE)

		var idx := i
		btn.pressed.connect(func(): track_entry_tapped.emit(idx))
		add_child(btn)

func _make_circle_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color(0.3, 0.6, 1.0)
	s.set_border_width_all(2)
	s.set_corner_radius_all(26)
	return s
