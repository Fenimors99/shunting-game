extends Node2D
class_name TaskPanel

const PANEL_W := 400.0
const TOGGLE_W := 32.0   # залишено для сумісності з GameScreen
const TOGGLE_H := 80.0

# Мітки і кольори складності для нескінченного режиму
const SLOT_LABELS := ["Найпростіше", "Легко", "Середнє", "Складно", "Неможливо"]
const SLOT_COLORS := [
	Color(0.25, 0.88, 0.42),
	Color(0.20, 0.78, 0.90),
	Color(0.98, 0.84, 0.18),
	Color(0.97, 0.52, 0.10),
	Color(0.92, 0.24, 0.24),
]

const FADE_OUT_DURATION := 0.35
const FADE_IN_DURATION  := 0.35

# Геометрія панелі
const HEADER_H  := 64.0   # висота шапки
const CARD_PAD  := 14.0   # відступ зверху і знизу всередині картки
const FONT_HDR  := 24     # шрифт заголовку панелі
const FONT_LBL  := 21     # шрифт мітки складності
const FONT_CNT  := 18     # шрифт кількості вагонів
const DOT_R     := 11.0   # радіус кружка вагона
const DOT_STEP  := 68.0   # крок між кружками
const CARD_GAP  := 8.0    # зазор між картками
const BAR_W     := 5.0    # ширина кольорової смуги зліва

var _task_manager: TaskManager
var _task_alphas: Array[float] = []

func _ready() -> void:
	z_index = 1
	position.x = 0.0
	position.y = 0.0

func init(tm: TaskManager, btn: Button) -> void:
	_task_manager = tm
	btn.visible = false   # прибираємо кнопку-стрілку

	_task_alphas.resize(_task_manager.get_task_count())
	_task_alphas.fill(1.0)

	if LevelConfig.current_level == 0:
		_task_manager.task_completed.connect(_on_task_completed_infinite)
		_task_manager.task_added.connect(_on_task_added_infinite)
	else:
		_task_manager.task_completed.connect(func(_i): queue_redraw())

	queue_redraw()

# --- Fade-анімації (нескінченний режим) ---

func _on_task_completed_infinite(index: int) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float):
		_task_alphas[index] = v
		queue_redraw()
	, 1.0, 0.0, FADE_OUT_DURATION)

func _on_task_added_infinite(index: int) -> void:
	var tween := create_tween()
	tween.tween_method(func(v: float):
		_task_alphas[index] = v
		queue_redraw()
	, 0.0, 1.0, FADE_IN_DURATION)

# --- Малювання ---

func _card_h() -> float:
	return CARD_PAD + float(FONT_LBL) + 10.0 + DOT_R * 2.0 + CARD_PAD

func _draw() -> void:
	if _task_manager == null:
		return

	var font  := ThemeDB.fallback_font
	var tasks := _task_manager.get_tasks()
	var n     := tasks.size()
	var ch    := _card_h()

	# Висота панелі — динамічна
	var panel_h := HEADER_H + float(n) * ch + float(n + 1) * CARD_GAP

	# Фон панелі
	draw_rect(Rect2(0, 0, PANEL_W, panel_h), Color(0.05, 0.08, 0.13, 0.97))
	draw_rect(Rect2(0, 0, PANEL_W, panel_h), Color(0.25, 0.38, 0.58, 0.85), false, 2.0)

	# Заголовок
	draw_string(font, Vector2(16, HEADER_H * 0.62),
		"Сортувальний листок",
		HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_HDR,
		Color(0.70, 0.82, 1.00, 0.80))
	draw_line(Vector2(0, HEADER_H - 1), Vector2(PANEL_W, HEADER_H - 1),
		Color(0.25, 0.38, 0.58, 0.55), 1.0)

	# Картки завдань
	var y := HEADER_H + CARD_GAP
	for i in n:
		var done  : bool  = _task_manager.is_completed(i)
		var alpha : float = _task_alphas[i] if i < _task_alphas.size() else 1.0
		var req   : Dictionary = tasks[i]

		# Колір складності
		var diff_col: Color
		if LevelConfig.current_level == 0:
			diff_col = SLOT_COLORS[i] if i < SLOT_COLORS.size() else Color.WHITE
		else:
			diff_col = Color(0.50, 0.65, 1.00)
		if done:
			diff_col = diff_col.darkened(0.5)
		diff_col.a = alpha

		# Фон картки
		var bg_col := Color(0.08, 0.16, 0.10, 0.65 * alpha) if done \
				else Color(0.08, 0.13, 0.24, 0.60 * alpha)
		draw_rect(Rect2(6, y, PANEL_W - 12, ch), bg_col)
		# Тонка рамка картки
		draw_rect(Rect2(6, y, PANEL_W - 12, ch),
			Color(0.30, 0.45, 0.65, 0.25 * alpha), false, 1.0)

		# Ліва кольорова смуга
		draw_rect(Rect2(6, y, BAR_W, ch), diff_col)

		# Мітка складності
		var label: String
		if LevelConfig.current_level == 0:
			label = SLOT_LABELS[i] if i < SLOT_LABELS.size() else "Завдання %d" % (i + 1)
		else:
			label = "Завдання %d" % (i + 1)
		var lbl_x := BAR_W + 14.0
		draw_string(font, Vector2(lbl_x, y + CARD_PAD + FONT_LBL),
			label, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LBL, diff_col)

		# Галочка (статичні рівні)
		if done and LevelConfig.current_level != 0:
			draw_string(font, Vector2(PANEL_W - 32, y + CARD_PAD + FONT_LBL),
				"✓", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_LBL,
				Color(0.30, 0.92, 0.48, alpha))

		# Кружки вагонів
		var dots_y := y + CARD_PAD + float(FONT_LBL) + 10.0 + DOT_R
		var rx := lbl_x
		for color_id in req:
			var count: int = req[color_id]
			var dot_col: Color = Wagon.NORMAL_COLORS[color_id]
			if done:
				dot_col = dot_col.darkened(0.45)
			dot_col.a = alpha

			# Обводка для контрасту
			draw_circle(Vector2(rx + DOT_R, dots_y), DOT_R + 2.0,
				Color(0.0, 0.0, 0.0, 0.40 * alpha))
			draw_circle(Vector2(rx + DOT_R, dots_y), DOT_R, dot_col)

			var cnt_col := Color(0.92, 0.96, 1.00, alpha) if not done \
					else Color(0.45, 0.55, 0.45, alpha)
			draw_string(font, Vector2(rx + DOT_R * 2.0 + 6.0, dots_y + 6.0),
				"×%d" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_CNT, cnt_col)
			rx += DOT_STEP

		y += ch + CARD_GAP
