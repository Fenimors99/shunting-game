extends Node2D

@onready var queue:              WagonQueue  = $Queue
@onready var station:            Station     = $Station
@onready var loco_depot:         LocoDepot   = $LocoDepot
@onready var task_manager:       TaskManager = $TaskManager
@onready var task_panel:         TaskPanel   = $TaskPanel
@onready var task_toggle_button: Button      = $TaskToggleButton

# Вагон, що стоїть в центральній точці і чекає призначення на колію
var _wagon_at_center: Wagon = null

var _timer_label: Label
var _timer_running: bool = false
var _time_elapsed: float = 0.0

var _pause_btn: Button
var _pause_overlay: Panel
var _pause_black_bg: ColorRect

# --- Бали (тільки нескінченний режим) ---
const SLOT_BASE_SCORES := [10, 20, 30, 50, 100]
var _total_score: int  = 0
var _streak:      int  = 0   # кількість здач підряд без повернення в чергу
var _score_label:  Label = null
var _streak_label: Label = null
var _spawn_btn:  Button = null
var _finish_btn: Button = null
var _help_btn:   Button = null
var _tutorial_overlay:    ColorRect = null
var _context_hint_overlay: Control = null
var _hint_paused_by_us: bool = false

const WAGON_ANIM_DELAY        := 0.18
const WAGON_RETURN_DELAY      := Layout.WAGON_GAP / Layout.SPEED  # ~0.25 — фізична відстань між вагонами
const VICTORY_WAIT_TIME := 2.2
const FADE_DURATION     := 0.8

func _ready() -> void:
	queue.position.y = Layout.QUEUE_Y
	queue.wagon_at_center.connect(_on_wagon_at_center)
	queue.queue_unblocked.connect(_on_queue_unblocked)
	station.track_entry_tapped.connect(_on_track_entry_tapped)
	station.track_exit_tapped.connect(_on_track_exit_tapped)
	station.track_exit_choice.connect(_on_track_exit_choice)
	loco_depot.availability_changed.connect(station.set_loco_available)
	station.set_task_manager(task_manager)
	station.set_wagon_queue(queue)
	task_panel.init(task_manager, task_toggle_button)
	task_manager.task_completed.connect(func(_i): station.refresh_all_exit_buttons())
	task_manager.all_tasks_completed.connect(_on_all_tasks_completed)
	station.repair_completed.connect(_on_repair_completed)
	station.loading_completed.connect(_on_loading_completed)
	station.disabled_btn_tapped.connect(_on_disabled_btn_tapped)
	_create_start_button()
	
func _on_all_tasks_completed() -> void:
	# В нескінченному режимі завдань завжди є — сигнал не емітується,
	# але захист на випадок майбутніх змін
	if LevelConfig.current_level == 0:
		return
	_timer_running = false
	var tween := create_tween()
	tween.tween_interval(VICTORY_WAIT_TIME)
	tween.tween_callback(_start_victory_transition)

func _start_victory_transition() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.size = get_viewport_rect().size
	overlay.z_index = 100
	add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 1.0), FADE_DURATION)
	tween.tween_callback(func():
		var victory_scene = load("res://scenes/VictoryScreen.tscn").instantiate()
		victory_scene.final_time   = _format_time(_time_elapsed)
		victory_scene.final_score  = _total_score
		victory_scene.level_index  = LevelConfig.current_level
		victory_scene.time_seconds = _time_elapsed
		get_tree().root.add_child(victory_scene)
		get_tree().current_scene.queue_free()
		get_tree().current_scene = victory_scene
	)

# Вагон доїхав до центру по кривій черзі — чекає призначення на колію
func _on_wagon_at_center(wagon: Wagon) -> void:
	_wagon_at_center = wagon
	wagon.start_blocking()
	station.set_entry_filter(wagon.wagon_type)

func _on_queue_unblocked() -> void:
	station.clear_entry_filter()

func _create_start_button() -> void:
	var btn := Button.new()
	btn.text = "СТАРТ"
	btn.custom_minimum_size = Vector2(200, 64)
	var vp := get_viewport_rect().size
	btn.position = Vector2(
		(vp.x - 200) / 2.0,
		Layout.QUEUE_Y - 82
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.55, 0.2, 0.95)
	style.border_color = Color(0.3, 0.9, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.7, 0.25, 0.95)
	style_hover.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 28)

	btn.pressed.connect(_on_start_pressed.bind(btn))
	add_child(btn)
	_create_timer_label()
	_create_pause_ui()
	if LevelConfig.current_level == 0:
		_create_score_display()
	_create_help_button()
	
func _create_timer_label() -> void:
	if LevelConfig.current_level == 0:
		_create_finish_button()
		return
	const W := 210.0
	const H := 62.0
	const PAUSE_SIZE := 62.0
	const GAP := 10.0
	var vp := get_viewport_rect().size
	var total_w := W + GAP + PAUSE_SIZE
	var start_x := (vp.x - total_w) / 2.0
	var box := Node2D.new()
	box.z_index = 1
	box.position = Vector2(start_x, 16)
	box.connect("draw", func():
		box.draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.09, 0.15, 0.96))
		box.draw_rect(Rect2(0, 0, W, H), Color(0.30, 0.45, 0.65, 0.8), false, 2.0)
		box.draw_rect(Rect2(2, 2, W - 4, H - 4), Color(0.50, 0.65, 0.85, 0.10), false, 1.0)
	)
	_timer_label = Label.new()
	_timer_label.position = Vector2(12, 10)
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", Color(0.80, 0.88, 1.00, 0.95))
	_timer_label.text = "Час: 00:00"
	box.add_child(_timer_label)
	add_child(box)


func _create_finish_button() -> void:
	const W         := 210.0
	const H         := 62.0
	const PAUSE_SIZE := 62.0
	const GAP       := 10.0
	var vp      := get_viewport_rect().size
	var start_x := (vp.x - W - GAP - PAUSE_SIZE) / 2.0
	var btn := Button.new()
	btn.text = "Завершити гру"
	btn.custom_minimum_size = Vector2(W, H)
	btn.position = Vector2(start_x, 16)
	btn.z_index  = 1
	btn.visible  = false  # показуємо після старту разом з паузою
	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.06, 0.09, 0.15, 0.96)
	s.border_color = Color(0.30, 0.45, 0.65, 0.80)
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	var sh := s.duplicate()
	sh.bg_color = Color(0.10, 0.18, 0.30, 0.96)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color(0.80, 0.88, 1.00, 0.95))
	btn.pressed.connect(_on_finish_pressed)
	add_child(btn)
	# зберігаємо посилання щоб показати після старту
	_finish_btn = btn


func _on_finish_pressed() -> void:
	get_tree().paused = true
	_show_finish_confirm()


func _show_finish_confirm() -> void:
	var vp := get_viewport_rect().size
	var overlay := ColorRect.new()
	overlay.name  = "FinishConfirmOverlay"
	overlay.color = Color(0.0, 0.0, 0.0, 0.65)
	overlay.size  = vp
	overlay.z_index = 60
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var pw := 380.0
	var ph := 200.0
	var panel := Panel.new()
	panel.size     = Vector2(pw, ph)
	panel.position = (vp - panel.size) / 2.0
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.09, 0.15, 0.98)
	ps.border_color = Color(0.30, 0.45, 0.65, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	overlay.add_child(panel)

	var lbl := Label.new()
	lbl.text = "Завершити гру?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 40)
	lbl.size     = Vector2(pw, 40)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.93, 1.00))
	panel.add_child(lbl)

	var sub := Label.new()
	sub.text = "Результат буде збережено"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 84)
	sub.size     = Vector2(pw, 24)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.90, 0.75))
	panel.add_child(sub)

	var make_btn := func(txt: String, col: Color) -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(130, 52)
		var bs := StyleBoxFlat.new()
		bs.bg_color = col.darkened(0.3)
		bs.border_color = col
		bs.set_border_width_all(1)
		bs.set_corner_radius_all(10)
		var bsh := bs.duplicate()
		bsh.bg_color = col.darkened(0.1)
		b.add_theme_stylebox_override("normal",  bs)
		b.add_theme_stylebox_override("hover",   bsh)
		b.add_theme_stylebox_override("pressed", bsh)
		b.add_theme_font_size_override("font_size", 20)
		b.process_mode = Node.PROCESS_MODE_ALWAYS
		return b

	var btn_yes: Button = make_btn.call("Так", Color(0.3, 0.8, 0.4))
	btn_yes.position = Vector2(50, 130)
	btn_yes.pressed.connect(func():
		overlay.queue_free()
		get_tree().paused = false
		_timer_running = false
		_start_victory_transition()
	)
	panel.add_child(btn_yes)

	var btn_no: Button = make_btn.call("Ні", Color(0.8, 0.3, 0.3))
	btn_no.position = Vector2(200, 130)
	btn_no.pressed.connect(func():
		overlay.queue_free()
		get_tree().paused = false
	)
	panel.add_child(btn_no)

func _process(delta: float) -> void:
	if _timer_running:
		_time_elapsed += delta
		if _timer_label != null:
			_timer_label.text = "Час: " + _format_time(_time_elapsed)
	if _spawn_btn != null:
		var should_disable := not queue.is_below_limit() or queue._returning or queue._spawn_settle_timer > 0.0
		if _spawn_btn.disabled != should_disable:
			_spawn_btn.disabled = should_disable
			_spawn_btn.queue_redraw()

func _format_time(time_in_sec: float) -> String:
	var m := int(time_in_sec) / 60
	var s := int(time_in_sec) % 60
	return "%02d:%02d" % [m, s]
	
func _create_pause_ui() -> void:
	_create_pause_button()
	_create_pause_overlay()

func _create_pause_button() -> void:
	const SIZE_PX    := 62.0
	const TIMER_W    := 210.0
	const GAP        := 10.0
	const TOTAL_W    := TIMER_W + GAP + SIZE_PX
	var vp := get_viewport_rect().size
	var start_x := (vp.x - TOTAL_W) / 2.0
	_pause_btn = Button.new()
	_pause_btn.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	_pause_btn.position = Vector2(start_x + TIMER_W + GAP, 16)
	_pause_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_btn.flat = true
	_pause_btn.visible = false
	_pause_btn.z_index = 51
	_pause_btn.connect("draw", func():
		var center := Vector2(SIZE_PX / 2, SIZE_PX / 2)
		var radius  := SIZE_PX / 2
		var color_bg     := Color(0.06, 0.09, 0.15, 0.96)
		var color_border := Color(0.30, 0.45, 0.65, 0.8)
		var color_icon   := Color(0.80, 0.88, 1.00, 0.95)
		_pause_btn.draw_circle(center, radius, color_bg)
		_pause_btn.draw_arc(center, radius - 1, 0, TAU, 64, color_border, 2.0, true)
		if get_tree().paused:
			_pause_btn.draw_colored_polygon(
				PackedVector2Array([Vector2(25, 20), Vector2(25, 42), Vector2(45, 31)]), color_icon)
		else:
			_pause_btn.draw_rect(Rect2(22, 20, 6, 22), color_icon)
			_pause_btn.draw_rect(Rect2(34, 20, 6, 22), color_icon)
	)
	_pause_btn.pressed.connect(_on_pause_toggle)
	add_child(_pause_btn)

func _create_score_display() -> void:
	const W      := 230.0
	const H      := 62.0
	# Відступ враховує кнопку "?" (62px) + gap (10px) + правий margin (16px)
	const MARGIN := 88.0
	var vp := get_viewport_rect().size

	var box := Node2D.new()
	box.z_index = 1
	box.position = Vector2(vp.x - W - MARGIN, 16)
	box.connect("draw", func():
		box.draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.09, 0.15, 0.96))
		box.draw_rect(Rect2(0, 0, W, H), Color(0.30, 0.45, 0.65, 0.8), false, 2.0)
		box.draw_rect(Rect2(2, 2, W - 4, H - 4), Color(0.50, 0.65, 0.85, 0.10), false, 1.0)
	)

	# Стрік — зліва, маленький
	_streak_label = Label.new()
	_streak_label.position = Vector2(10, 8)
	_streak_label.add_theme_font_size_override("font_size", 15)
	_streak_label.text = ""
	box.add_child(_streak_label)

	# Бали — під стріком, більший шрифт
	_score_label = Label.new()
	_score_label.position = Vector2(10, 30)
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_color", Color(0.98, 0.88, 0.30, 0.95))
	_score_label.text = "Бали: 0"
	box.add_child(_score_label)
	box.add_child(_streak_label)

	add_child(box)

func _update_score_display() -> void:
	if _score_label == null:
		return
	_score_label.text = "Бали: %d" % _total_score
	if _streak >= 3:
		_streak_label.text = "Серія ×2.0  !!!"
		_streak_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.15, 0.95))
	elif _streak == 2:
		_streak_label.text = "Серія ×1.5"
		_streak_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.15, 0.95))
	else:
		_streak_label.text = ""

func _score_submit(task_idx: int, wagons: Array) -> void:
	if LevelConfig.current_level != 0:
		return
	# Базові очки слоту
	var base: int = SLOT_BASE_SCORES[task_idx] if task_idx < SLOT_BASE_SCORES.size() else 10
	# Бонус за рожеві вагони (+10% за кожен)
	var pink_count := 0
	for w in wagons:
		if w.wagon_type == Wagon.WagonType.NORMAL and int(w.color_id) == 4:
			pink_count += 1
	var after_pink: float = base * (1.0 + pink_count * 0.1)
	# Стрік: спочатку рахуємо здачу, потім застосовуємо множник
	_streak += 1
	var streak_mult := 1.0
	if _streak == 2:
		streak_mult = 1.5
	elif _streak >= 3:
		streak_mult = 2.0
	var points := int(round(after_pink * streak_mult))
	_total_score += points
	_update_score_display()

func _create_pause_overlay() -> void:
	var vp := get_viewport_rect().size

	_pause_black_bg = ColorRect.new()
	_pause_black_bg.color = Color(0.0, 0.0, 0.0, 1.0)
	_pause_black_bg.size = vp
	_pause_black_bg.visible = false
	_pause_black_bg.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_black_bg.z_index = 50
	add_child(_pause_black_bg)

	_pause_overlay = Panel.new()
	_pause_overlay.size = Vector2(420, 380)
	_pause_overlay.position = (vp - _pause_overlay.size) / 2.0
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false
	_pause_overlay.z_index = 51
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.09, 0.15, 0.98)
	style.border_color = Color(0.30, 0.45, 0.65, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	_pause_overlay.add_theme_stylebox_override("panel", style)
	add_child(_pause_overlay)

	var lbl := Label.new()
	lbl.text = "Гру призупинено"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 40)
	lbl.size = Vector2(420, 50)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 1.00))
	_pause_overlay.add_child(lbl)

	var btn_container := VBoxContainer.new()
	btn_container.size = Vector2(300, 220)
	btn_container.position = Vector2(60, 110)
	btn_container.add_theme_constant_override("separation", 15)
	_pause_overlay.add_child(btn_container)
	_populate_pause_menu(btn_container)

func _populate_pause_menu(container: VBoxContainer) -> void:
	var make_btn := func(txt: String, color: Color) -> Button:
		var b := Button.new()
		b.text = txt
		b.custom_minimum_size = Vector2(0, 70)
		var bs := StyleBoxFlat.new()
		bs.bg_color = color.darkened(0.3)
		bs.set_corner_radius_all(10)
		bs.set_border_width_all(1)
		bs.border_color = color
		b.add_theme_stylebox_override("normal", bs)
		b.add_theme_font_size_override("font_size", 22)
		return b

	var btn_resume: Button = make_btn.call("Продовжити", Color(0.3, 0.6, 0.9))
	btn_resume.pressed.connect(_on_pause_toggle)
	container.add_child(btn_resume)

	var btn_restart: Button = make_btn.call("Почати заново", Color(0.3, 0.8, 0.4))
	btn_restart.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	container.add_child(btn_restart)

	var btn_exit: Button = make_btn.call("Вихід до рівнів", Color(0.8, 0.3, 0.3))
	btn_exit.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
	)
	container.add_child(btn_exit)
	
func _on_pause_toggle() -> void:
	var new_pause_state = not get_tree().paused
	get_tree().paused = new_pause_state
	
	# Оновлюємо видимість обох елементів паузи
	_pause_black_bg.visible = new_pause_state # <--- ДОДАТО
	_pause_overlay.visible = new_pause_state
	
	# 2. Ховаємо КРУЖЕЧОК, якщо ми на паузі, і показуємо, якщо повернулися в гру
	_pause_btn.visible = not new_pause_state
	
	_pause_btn.queue_redraw()
	
func _on_start_pressed(btn: Button) -> void:
	btn.queue_free()
	queue.start()
	_timer_running = true
	_pause_btn.visible = true
	if _finish_btn != null:
		_finish_btn.visible = true
	_create_spawn_button()

func _create_spawn_button() -> void:
	if LevelConfig.current_level == 1 or LevelConfig.current_level == 2 or LevelConfig.current_level == 3:
		return
	const SIZE := 62.0
	const MARGIN := 16.0
	var vp := get_viewport_rect().size
	_spawn_btn = Button.new()
	_spawn_btn.custom_minimum_size = Vector2(SIZE, SIZE)
	_spawn_btn.position = Vector2(vp.x - SIZE - MARGIN, Layout.QUEUE_Y - SIZE * 1.5)
	_spawn_btn.flat = true
	_spawn_btn.z_index = 1
	_spawn_btn.connect("draw", func():
		var center := Vector2(SIZE / 2.0, SIZE / 2.0)
		var color_bg     := Color(0.10, 0.30, 0.60, 0.95)
		var color_border := Color(0.35, 0.60, 1.00, 0.9)
		var color_icon   := Color(1.0, 1.0, 1.0, 0.95)
		if _spawn_btn.disabled:
			color_bg     = Color(0.15, 0.15, 0.20, 0.6)
			color_border = Color(0.3, 0.3, 0.4, 0.5)
			color_icon   = Color(0.5, 0.5, 0.55, 0.5)
		_spawn_btn.draw_circle(center, SIZE / 2.0, color_bg)
		_spawn_btn.draw_arc(center, SIZE / 2.0 - 1.0, 0.0, TAU, 64, color_border, 2.0, true)
		var t := SIZE / 2.0
		var arm := 13.0
		_spawn_btn.draw_line(Vector2(t - arm, t), Vector2(t + arm, t), color_icon, 3.0, true)
		_spawn_btn.draw_line(Vector2(t, t - arm), Vector2(t, t + arm), color_icon, 3.0, true)
	)
	_spawn_btn.pressed.connect(func():
		queue.fill_to_limit()
		_spawn_btn.queue_redraw()
	)
	_spawn_btn.gui_input.connect(func(event: InputEvent):
		if _spawn_btn.disabled and event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_on_disabled_btn_tapped("spawn_busy")
	)
	add_child(_spawn_btn)
	
func _on_track_entry_tapped(track_index: int) -> void:
	if _wagon_at_center == null:
		return
	if station.is_track_full(track_index):
		return
	if not Layout.is_wagon_compatible(_wagon_at_center.wagon_type, track_index):
		return
	var wagon := _wagon_at_center
	_wagon_at_center = null
	wagon.stop_blocking()
	queue.unblock()
	var slot: int = station.reserve_slot(track_index)
	# Вагон зупинився трохи до центру — стартуємо з поточної позиції,
	# щоб анімація плавно пройшла решту дуги перед розподільчою рейкою.
	var base_path := Layout.get_track_path_from_center(track_index, slot)
	var path := PackedVector2Array()
	path.append(wagon.position)
	path.append_array(base_path)
	_animate_along_path(wagon, path, func():
		wagon.rotation = 0.0
		station.place_wagon(wagon, track_index, slot)
	)

func _animate_along_path(wagon: Wagon, path: PackedVector2Array, on_done: Callable) -> void:
	# Накопичені довжини відрізків для рівномірної швидкості
	var cumul: Array[float] = [0.0]
	for i in range(1, path.size()):
		cumul.append(cumul[i - 1] + path[i - 1].distance_to(path[i]))
	var total: float = cumul[cumul.size() - 1]
	if total < 1.0:
		on_done.call()
		return

	var tween := create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_method(func(t: float):
		var d := t * total
		for i in range(1, path.size()):
			if cumul[i] >= d or i == path.size() - 1:
				var seg_len := cumul[i] - cumul[i - 1]
				var seg_t   := 0.0 if seg_len < 0.001 else (d - cumul[i - 1]) / seg_len
				wagon.position = path[i - 1].lerp(path[i], clampf(seg_t, 0.0, 1.0))
				var seg_dir := path[i] - path[i - 1]
				if seg_dir.length_squared() > 0.0001:
					wagon.rotation = seg_dir.angle()
				break,
		0.0, 1.0, total / Layout.SPEED
	)
	tween.tween_callback(on_done)

func _on_track_exit_tapped(track_index: int) -> void:
	station.flash_track_green(track_index, station.get_wagon_count(track_index) * 0.5)
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	if track_index == Layout.REPAIR_TRACK:
		_animate_to_repair(wagons)
	elif track_index == Layout.CARGO_TRACK:
		_animate_to_loading(wagons)
	else:
		_animate_exit(wagons, track_index)

func _on_track_exit_choice(track_index: int, submit: bool) -> void:
	station.flash_track_green(track_index, station.get_wagon_count(track_index) * 0.5)
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	if submit:
		var task_idx := task_manager.submit(wagons)
		if task_idx == -1:
			# Склад колії змінився поки меню було відкрите — повертаємо вагони
			_return_to_queue(wagons, track_index)
			return
		_score_submit(task_idx, wagons)
		_animate_submit(wagons, track_index)
	else:
		# Свідоме повернення в чергу — скидаємо стрік
		if LevelConfig.current_level == 0 and _streak > 0:
			_streak = 0
			_update_score_display()
		_return_to_queue(wagons, track_index)

# Шлях від слоту на колії до центральної збірної рейки (спільна частина для exit/submit/queue).
func _build_exit_path_to_center(wagon: Wagon, track_index: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(wagon.position)
	pts.append(Vector2(Layout.get_exit_rail_x(track_index), Layout.get_track_y(track_index)))
	if track_index < Layout.CENTER_TRACK:
		for j in range(track_index + 1, Layout.CENTER_TRACK + 1):
			pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
	elif track_index > Layout.CENTER_TRACK:
		for j in range(track_index - 1, Layout.CENTER_TRACK - 1, -1):
			pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
	return pts

func _animate_delayed(wagon: Wagon, pts: PackedVector2Array, delay: float, on_done: Callable) -> void:
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(func(): _animate_along_path(wagon, pts, on_done))

func _animate_exit(wagons: Array, track_index: int) -> void:
	var exit_arc := Layout.get_exit_arc()
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := _build_exit_path_to_center(wagon, track_index)
		pts.append_array(exit_arc)
		pts.append(Vector2(-Layout.WAGON_GAP, Layout.QUEUE_Y))
		_animate_delayed(wagon, pts, i * WAGON_ANIM_DELAY, wagon.queue_free)

func _return_to_queue(wagons: Array, track_index: int) -> void:
	queue.set_returning(true)
	var exit_arc    := Layout.get_exit_arc()
	var base_tail_x := queue.get_tail_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := _build_exit_path_to_center(wagon, track_index)
		pts.append_array(exit_arc)
		pts.append(Vector2(base_tail_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y))
		var is_last := (i == wagons.size() - 1)
		_animate_delayed(wagon, pts, i * WAGON_ANIM_DELAY, func():
			wagon.rotation = PI
			queue.receive_wagon(wagon)
			if is_last:
				queue.set_returning(false)
		)

func _animate_submit(wagons: Array, track_index: int) -> void:
	var center_y := Layout.get_track_y(Layout.CENTER_TRACK)
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := _build_exit_path_to_center(wagon, track_index)
		pts.append(Vector2(Layout.SCREEN_W + Layout.WAGON_GAP, center_y))
		_animate_delayed(wagon, pts, i * WAGON_ANIM_DELAY, wagon.queue_free)

func _animate_to_loading(wagons: Array) -> void:
	var arc     := Layout.get_track1_exit_arc()
	var arc_end := arc[arc.size() - 1]
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append_array(arc)
		pts.append(Vector2(arc_end.x, -Layout.WAGON_GAP))
		var is_last := (i == wagons.size() - 1)
		_animate_delayed(wagon, pts, i * WAGON_ANIM_DELAY, func():
			if is_last:
				station.start_loading(wagons)
		)

func _animate_to_repair(wagons: Array) -> void:
	var dest_x   := Layout.REPAIR_DEPOT_RECT.get_center().x
	var track7_y := Layout.get_track_y(Layout.REPAIR_TRACK)
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := PackedVector2Array([wagon.position, Vector2(dest_x, track7_y)])
		var is_last := (i == wagons.size() - 1)
		_animate_delayed(wagon, pts, i * WAGON_ANIM_DELAY, func():
			wagon.rotation = 0.0
			if is_last:
				station.start_repair(wagons)
		)

func _on_loading_completed(wagons: Array) -> void:
	queue.set_returning(true)
	var ret_x    := Layout.get_loading_return_x()
	var ret_arc  := Layout.get_loading_return_arc()
	var exit_arc := Layout.get_exit_arc()
	var exit_end := exit_arc[exit_arc.size() - 1]  # (1620, 1039)
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		wagon.become_loaded()
		wagon.position = Vector2(ret_x, -Layout.WAGON_GAP)
		var is_last := (i == wagons.size() - 1)
		# Фаза 1: фіксована геометрія (від дроп-зони через дугу до рівня черги)
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append_array(ret_arc)
		pts.append_array(exit_arc.slice(2))
		_animate_delayed(wagon, pts, i * WAGON_RETURN_DELAY, func():
			# Фаза 2: обчислюємо поточний хвіст черги прямо зараз, щоб уникнути стрибка
			var dest_x := queue.get_tail_x() + Layout.WAGON_GAP
			_animate_along_path(wagon,
				PackedVector2Array([exit_end, Vector2(dest_x, Layout.QUEUE_Y)]),
				func():
					wagon.rotation = PI
					queue.receive_wagon(wagon)
					if is_last: queue.set_returning(false)
			)
		)

func _on_repair_completed(wagons: Array) -> void:
	queue.set_returning(true)
	var arc      := Layout.get_repair_exit_arc()
	var arc_end  := arc[arc.size() - 1]  # (1361, 1039)
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		wagon.repair()
		var is_last := (i == wagons.size() - 1)
		# Фаза 1: фіксована геометрія (дуга виходу з ремонтного депо)
		var arc_pts := PackedVector2Array()
		arc_pts.append(wagon.position)
		arc_pts.append_array(arc)
		_animate_delayed(wagon, arc_pts, i * WAGON_RETURN_DELAY, func():
			# Фаза 2: обчислюємо поточний хвіст черги прямо зараз, щоб уникнути стрибка
			var dest_x := queue.get_tail_x() + Layout.WAGON_GAP
			_animate_along_path(wagon,
				PackedVector2Array([arc_end, Vector2(dest_x, Layout.QUEUE_Y)]),
				func():
					wagon.rotation = PI
					queue.receive_wagon(wagon)
					if is_last: queue.set_returning(false)
			)
		)

# ─────────────────────────────────────────────
# Кнопка допомоги "?"
# ─────────────────────────────────────────────

func _create_help_button() -> void:
	const SIZE_PX := 62.0
	const MARGIN  := 16.0
	var vp := get_viewport_rect().size
	_help_btn = Button.new()
	_help_btn.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	_help_btn.position = Vector2(vp.x - SIZE_PX - MARGIN, MARGIN)
	_help_btn.flat = true
	_help_btn.z_index = 2
	_help_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_help_btn.connect("draw", func():
		var center := Vector2(SIZE_PX / 2, SIZE_PX / 2)
		_help_btn.draw_circle(center, SIZE_PX / 2, Color(0.06, 0.09, 0.15, 0.96))
		_help_btn.draw_arc(center, SIZE_PX / 2 - 1, 0, TAU, 64, Color(0.30, 0.45, 0.65, 0.8), 2.0, true)
		var font := ThemeDB.fallback_font
		var fs   := 34
		var txt  := "?"
		var tw   := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var asc  := font.get_ascent(fs)
		_help_btn.draw_string(font, Vector2((SIZE_PX - tw) / 2.0, (SIZE_PX + asc) / 2.0 - 3),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.80, 0.88, 1.00, 0.95))
	)
	_help_btn.pressed.connect(_on_help_pressed)
	add_child(_help_btn)

func _on_help_pressed() -> void:
	if _timer_running and not get_tree().paused:
		get_tree().paused = true
		if _pause_btn != null:
			_pause_btn.visible = false
		_hint_paused_by_us = true
	else:
		_hint_paused_by_us = false
	_show_tutorial()

# ─────────────────────────────────────────────
# Повноекранний туторіал
# ─────────────────────────────────────────────

func _show_tutorial() -> void:
	if _tutorial_overlay != null:
		return
	var vp := get_viewport_rect().size

	_tutorial_overlay = ColorRect.new()
	_tutorial_overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	_tutorial_overlay.size  = vp
	_tutorial_overlay.z_index = 62
	_tutorial_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_tutorial_overlay)

	const PW := 1100.0
	const PH := 720.0
	var panel := Panel.new()
	panel.size     = Vector2(PW, PH)
	panel.position = (vp - panel.size) / 2.0
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.09, 0.15, 0.99)
	ps.border_color = Color(0.30, 0.45, 0.65, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", ps)
	_tutorial_overlay.add_child(panel)

	var title_lbl := Label.new()
	title_lbl.text = "Як грати"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size     = Vector2(PW, 56)
	title_lbl.position = Vector2(0, 18)
	title_lbl.add_theme_font_size_override("font_size", 36)
	title_lbl.add_theme_color_override("font_color", Color(0.80, 0.88, 1.00))
	panel.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.position = Vector2(PW - 58, 14)
	close_btn.flat = true
	close_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", Color(0.65, 0.75, 0.90))
	close_btn.pressed.connect(_hide_tutorial)
	panel.add_child(close_btn)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 74)
	scroll.size     = Vector2(PW - 48, PH - 92)
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(PW - 68, 0)
	scroll.add_child(vbox)

	_make_tutorial_section(vbox,
		"1. Черга вагонів",
		"Вагони з'являються праворуч і рухаються до сортувальної станції. Коли вагон зупиняється — призначте його на колію за допомогою кнопки «+» ліворуч від колії. Кнопка «+» у правій нижній частині екрана додає нові вагони в чергу (до 8 одиниць)."
	)
	_make_tutorial_section(vbox,
		"2. Колії та дії",
		"Натисніть кнопку входу «+» (ліворуч від колії), щоб направити поточний вагон. Натисніть кнопку виходу «>» (праворуч), щоб зняти всі вагони з колії.\n\n• Колія 1 — вантажна: приймає лише місцеві вагони (Білого кольору), для подальшої обробки (Перетворення кольору на рожевий).\n• Колія 7 — ремонтна: приймає лише пошкоджені вагони (Червоні), для подальшого ремонтування (Перетворення кольору на білий).\n• Колії 2–6 — звичайні: для сортування та виконання завдань."
	)
	_make_tutorial_section(vbox,
		"3. Завдання (Сортувальний листок)",
		"У панелі зліва відображаються активні завдання — потрібні кольори вагонів та їх кількість. Зберіть відповідні вагони на одній колії та натисніть «>», потім «Здати». Якщо склад точно відповідає завданню — воно виконається і зарахується.\n\nКнопка «В чергу» повертає вагони назад у чергу (але скидає серію у нескінченному режимі)."
	)
	_make_tutorial_section(vbox,
		"4. Локомотиви",
		"Для виходу вагонів з будь-якої колії потрібен локомотив. Доступно 3 локомотиви — кожен повертається приблизно через 20 секунд після використання. Слідкуйте за індикатором депо: якщо всі локомотиви зайняті, кнопки виходу будуть недоступні."
	)
	_make_tutorial_section(vbox,
		"5. Бали та серія (нескінченний режим)",
		"Кожне виконане завдання приносить очки. Складніші завдання (більше вагонів) дають більше очок (10, 20, 30, 50 та 100 відповідно до складності).\n\n• 2 здачі підряд → серія ×1.5\n• 3+ здачі підряд → серія ×2.0 !!!\n\nПовернення вагонів у чергу скидає серію. Рожеві вагони (після вантажу або після ремонту та вантажу) дають +10% бонусу за кожен."
	)
	_make_tutorial_section(vbox,
		"6. Режими гри",
		"Рівні (1–3): задана послідовність вагонів у черзі та фіксований набір завдань. Всі завдання відомі заздалегідь. Ціль — виконати всі завдання якнайшвидше. Результат фіксується як час проходження.\n\nНескінченний режим (∞): нові завдання генеруються безперервно після кожного виконання. Грайте, поки хочете — завершіть гру кнопкою «Завершити гру». Результат — кількість набраних очок. Змагайтесь з іншими гравцями та займайте якнайвище місце у таблиці лідерів!"
	)

func _hide_tutorial() -> void:
	if _tutorial_overlay != null:
		_tutorial_overlay.queue_free()
		_tutorial_overlay = null
	if _hint_paused_by_us and get_tree().paused and \
			(_pause_overlay == null or not _pause_overlay.visible):
		get_tree().paused = false
		if _pause_btn != null and _timer_running:
			_pause_btn.visible = true
	_hint_paused_by_us = false

func _make_tutorial_section(parent: VBoxContainer, title: String, body: String) -> void:
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", Color(0.40, 0.75, 1.00))
	parent.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.add_theme_font_size_override("font_size", 17)
	body_lbl.add_theme_color_override("font_color", Color(0.82, 0.88, 0.95))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(1040, 0)
	parent.add_child(body_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.25, 0.35, 0.55, 0.5))
	parent.add_child(sep)

# ─────────────────────────────────────────────
# Контекстний хінт для задизейблених кнопок
# ─────────────────────────────────────────────

func _on_disabled_btn_tapped(reason: String) -> void:
	if _context_hint_overlay != null:
		return
	if _timer_running and not get_tree().paused:
		get_tree().paused = true
		if _pause_btn != null:
			_pause_btn.visible = false
		_hint_paused_by_us = true
	var info := _reason_to_hint(reason)
	_show_context_hint(info[0], info[1])

func _reason_to_hint(reason: String) -> Array:
	match reason:
		"track_full":
			return ["Колія заповнена",
				"На цій колії вже немає вільних місць. Спочатку відправте вагони з колії кнопкою «>»."]
		"incompatible":
			return ["Несумісний тип вагону",
				"Цей тип вагону не може заїхати на дану колію.\n\n• Колія 1 — лише для місцевих вагонів (Білих)\n• Колія 7 — лише для пошкоджених вагонів (Червоних)\n• Колії 2–6 — для всіх інших вагонів"]
		"no_wagons":
			return ["На колії немає вагонів",
				"Спочатку направте вагони на колію за допомогою кнопки «+»."]
		"in_transit":
			return ["Вагони вже рухаються",
				"З цієї колії вже виходять вагони. Зачекайте, поки рух завершиться."]
		"no_loco":
			return ["Немає вільного локомотива",
				"Для виходу вагонів з колії потрібен локомотив. Усі 3 локомотиви зараз зайняті — дочекайтесь повернення (таймери локомотивів над сортувальною станцією)."]
		"repair_busy":
			return ["Ремонтне депо зайняте",
				"Вагони вже знаходяться в ремонтному депо. Дочекайтесь завершення ремонту та виводу вагонів."]
		"loading_busy":
			return ["Вантажний термінал зайнятий",
				"Вагони вже обробляються на вантажному терміналі. Дочекайтесь завершення та виводу вагонів."]
		"submit_mismatch":
			return ["Не відповідає жодному завданню",
				"Поточний склад вагонів на колії не збігається з жодним активним завданням. Перевірте «Сортувальний листок» — кольори та кількість мають точно відповідати вимогам."]
		"queue_full":
			return ["Черга вагонів заповнена",
				"В черзі немає місця для повернення вагонів або вагони зараз прямують до кінця черги."]
		"release_queue_full":
			return ["Черга вагонів заповнена",
				"Немає місця в черзі для прийому вагонів з депо або вагони зараз прямують до кінця."]
		"spawn_busy":
			return ["Черга не готова",
				"Черга вагонів заповнена або вагони ще рухаються в кінець черги"]
	return ["Дія недоступна", "Ця кнопка зараз неактивна. Спробуйте пізніше та зверніться до команди розробки. Ця помилка не була спланована"]

func _show_context_hint(title: String, body: String) -> void:
	var vp := get_viewport_rect().size

	# Фон — ColorRect на весь екран (як в решті модалів)
	_context_hint_overlay = Control.new()
	_context_hint_overlay.z_index = 63
	_context_hint_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_context_hint_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.size  = vp
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	_context_hint_overlay.add_child(bg)

	# PanelContainer — автоматично тягнеться за VBoxContainer
	const PW := 564.0
	const PAD_H := 32.0
	const PAD_V := 26.0
	var pc := PanelContainer.new()
	pc.process_mode = Node.PROCESS_MODE_ALWAYS
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.09, 0.15, 0.99)
	ps.border_color = Color(0.45, 0.60, 0.85, 1.0)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(16)
	ps.content_margin_left   = PAD_H
	ps.content_margin_right  = PAD_H
	ps.content_margin_top    = PAD_V
	ps.content_margin_bottom = PAD_V
	pc.add_theme_stylebox_override("panel", ps)
	_context_hint_overlay.add_child(pc)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(PW - PAD_H * 2, 0)
	vbox.add_theme_constant_override("separation", 14)
	pc.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 26)
	title_lbl.add_theme_color_override("font_color", Color(0.85, 0.93, 1.00))
	vbox.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.add_theme_font_size_override("font_size", 16)
	body_lbl.add_theme_color_override("font_color", Color(0.72, 0.80, 0.92))
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.custom_minimum_size = Vector2(PW - PAD_H * 2, 0)
	vbox.add_child(body_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	vbox.add_child(spacer)

	var ok_btn := Button.new()
	ok_btn.text = "Зрозуміло"
	ok_btn.custom_minimum_size = Vector2(160, 48)
	ok_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	var bs := StyleBoxFlat.new()
	bs.bg_color     = Color(0.15, 0.35, 0.65, 0.95)
	bs.border_color = Color(0.35, 0.60, 1.00)
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(10)
	var bsh := bs.duplicate()
	bsh.bg_color = Color(0.22, 0.48, 0.85, 0.95)
	ok_btn.add_theme_stylebox_override("normal",  bs)
	ok_btn.add_theme_stylebox_override("hover",   bsh)
	ok_btn.add_theme_stylebox_override("pressed", bsh)
	ok_btn.add_theme_font_size_override("font_size", 20)
	ok_btn.add_theme_color_override("font_color", Color.WHITE)
	ok_btn.pressed.connect(_hide_context_hint)
	vbox.add_child(ok_btn)

	# Центруємо після того як Godot прорахує layout (deferred)
	var pc_ref := pc
	(func():
		pc_ref.position = (vp - pc_ref.size) / 2.0
	).call_deferred()

func _hide_context_hint() -> void:
	if _context_hint_overlay != null:
		_context_hint_overlay.queue_free()
		_context_hint_overlay = null
	if _hint_paused_by_us and get_tree().paused and \
			(_pause_overlay == null or not _pause_overlay.visible):
		get_tree().paused = false
		if _pause_btn != null and _timer_running:
			_pause_btn.visible = true
	_hint_paused_by_us = false
