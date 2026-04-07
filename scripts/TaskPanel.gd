extends Node2D
class_name TaskPanel

const PANEL_W  := 260.0
const PANEL_H  := 320.0
const TOGGLE_W := 32.0
const TOGGLE_H := 80.0

var _task_manager: TaskManager
var _toggle_btn:   Button
var _open     := true
var _tweening := false

var _pos_open:   float
var _pos_closed: float

func _ready() -> void:
	var vp := get_viewport_rect().size
	_pos_open   = vp.x - PANEL_W
	_pos_closed = vp.x
	position.x  = _pos_open
	position.y  = (vp.y - PANEL_H) / 2.0

# Викликається з GameScreen після того як вузли готові.
# tm    — менеджер завдань
# btn   — кнопка-тоггл, оголошена в сцені як сиблінг (не дочірній вузол панелі)
func init(tm: TaskManager, btn: Button) -> void:
	_task_manager = tm
	_toggle_btn   = btn
	_task_manager.task_completed.connect(func(_i): queue_redraw())
	_apply_toggle_style()
	_toggle_btn.pressed.connect(_toggle)
	queue_redraw()

func _draw() -> void:
	if _task_manager == null:
		return

	var font := ThemeDB.fallback_font

	# Фон панелі
	draw_rect(Rect2(0, 0, PANEL_W, PANEL_H), Color(0.06, 0.09, 0.15, 0.96))
	draw_rect(Rect2(0, 0, PANEL_W, PANEL_H), Color(0.30, 0.45, 0.65, 0.8), false, 2.0)
	draw_rect(Rect2(2, 2, PANEL_W - 4, PANEL_H - 4), Color(0.50, 0.65, 0.85, 0.10), false, 1.0)

	# Заголовок
	draw_string(font, Vector2(14, 26),
		"Сортувальний листок",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
		Color(0.80, 0.88, 1.00, 0.95))
	draw_line(Vector2(10, 34), Vector2(PANEL_W - 10, 34), Color(0.30, 0.45, 0.65, 0.5), 1.0)

	# Завдання
	var y := 52.0
	for i in TaskManager.TASKS.size():
		var done: bool = _task_manager.is_completed(i)

		var row_color := Color(0.12, 0.22, 0.12, 0.6) if done else Color(0.08, 0.12, 0.20, 0.5)
		draw_rect(Rect2(8, y - 14, PANEL_W - 16, 18), row_color)

		var box_col := Color(0.20, 0.75, 0.35) if done else Color(0.35, 0.45, 0.60)
		draw_rect(Rect2(14, y - 11, 13, 13), box_col)
		draw_rect(Rect2(14, y - 11, 13, 13), Color(0.60, 0.75, 0.90, 0.6), false, 1.0)
		if done:
			draw_string(font, Vector2(15, y), "v",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.05, 0.05, 0.05))

		var num_col := Color(0.55, 0.75, 0.55) if done else Color(0.70, 0.80, 1.00)
		draw_string(font, Vector2(34, y),
			"Завдання %d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, num_col)

		y += 26.0

		var req: Dictionary = TaskManager.TASKS[i]
		var rx := 28.0
		for color_id in req:
			var count: int = req[color_id]
			var dot_col: Color = Wagon.NORMAL_COLORS[color_id]
			if done:
				dot_col = dot_col.darkened(0.4)
			draw_circle(Vector2(rx + 6, y - 5), 6, dot_col)
			draw_string(font, Vector2(rx + 16, y),
				"× %d" % count,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(0.85, 0.90, 1.00, 0.85) if not done else Color(0.50, 0.60, 0.50))
			rx += 52.0

		y += 22.0

		if i < TaskManager.TASKS.size() - 1:
			draw_line(Vector2(10, y), Vector2(PANEL_W - 10, y),
				Color(0.25, 0.35, 0.50, 0.4), 1.0)
			y += 8.0

func _apply_toggle_style() -> void:
	_toggle_btn.custom_minimum_size = Vector2(TOGGLE_W, TOGGLE_H)
	_toggle_btn.text = "<"

	var s := StyleBoxFlat.new()
	s.bg_color    = Color(0.12, 0.20, 0.35, 0.95)
	s.border_color = Color(0.30, 0.45, 0.65, 0.8)
	s.set_border_width_all(2)
	s.corner_radius_top_left    = 8
	s.corner_radius_bottom_left = 8
	_toggle_btn.add_theme_stylebox_override("normal", s)

	var sh := s.duplicate()
	sh.bg_color = Color(0.18, 0.30, 0.50, 0.95)
	_toggle_btn.add_theme_stylebox_override("hover", sh)
	_toggle_btn.add_theme_color_override("font_color", Color.WHITE)
	_toggle_btn.add_theme_font_size_override("font_size", 14)

func _toggle() -> void:
	if _tweening:
		return
	_tweening = true
	_open = not _open
	_toggle_btn.text = ">" if not _open else "<"

	var target_x := _pos_open if _open else _pos_closed
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:x", target_x, 0.3)
	tween.tween_callback(func(): _tweening = false)
