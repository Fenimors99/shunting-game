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
	var vp := get_viewport_rect().size
	task_toggle_button.position = Vector2(
		vp.x - TaskPanel.TOGGLE_W,
		(vp.y - TaskPanel.TOGGLE_H) / 2.0
	)
	task_panel.init(task_manager, task_toggle_button)
	task_manager.task_completed.connect(func(_i): station.refresh_all_exit_buttons())
	task_manager.all_tasks_completed.connect(_on_all_tasks_completed)
	station.repair_completed.connect(_on_repair_completed)
	station.loading_completed.connect(_on_loading_completed)
	_create_start_button()
	
func _on_all_tasks_completed() -> void:
	_timer_running = false
	# Чекаємо поки вагони відʼїдуть, потім fade-to-black → victory
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
		victory_scene.final_time = _format_time(_time_elapsed)
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
	_create_timer_label() # Додаємо цей рядок
	_create_pause_ui() # Додаємо сюди
	
func _create_timer_label() -> void:
	var W := 210.0
	var H := 62.0
	var box := Node2D.new()
	box.z_index = 1
	box.position = Vector2(16, 16)
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

func _process(delta: float) -> void:
	if _timer_running:
		_time_elapsed += delta
		_timer_label.text = "Час: " + _format_time(_time_elapsed)

func _format_time(time_in_sec: float) -> String:
	var m := int(time_in_sec) / 60
	var s := int(time_in_sec) % 60
	return "%02d:%02d" % [m, s]
	
func _create_pause_ui() -> void:
	_create_pause_button()
	_create_pause_overlay()

func _create_pause_button() -> void:
	const SIZE_PX := 62.0
	_pause_btn = Button.new()
	_pause_btn.custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	_pause_btn.position = Vector2(16 + 210 + 10, 16)
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
	var path := Layout.get_track_path_from_center(track_index, slot)
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
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	if submit:
		if task_manager.submit(wagons) == -1:
			# Склад колії змінився поки меню було відкрите — повертаємо вагони
			_return_to_queue(wagons, track_index)
			return
		_animate_submit(wagons, track_index)
	else:
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
	var exit_arc    := Layout.get_exit_arc()
	var base_tail_x := queue.get_tail_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := _build_exit_path_to_center(wagon, track_index)
		pts.append_array(exit_arc)
		pts.append(Vector2(base_tail_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y))
		_animate_delayed(wagon, pts, i * WAGON_ANIM_DELAY, func():
			wagon.rotation = PI
			queue.receive_wagon(wagon)
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
	var ret_x       := Layout.get_loading_return_x()
	var ret_arc     := Layout.get_loading_return_arc()
	var exit_arc    := Layout.get_exit_arc()
	var base_tail_x := queue.get_tail_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		wagon.become_loaded()
		wagon.position = Vector2(ret_x, -Layout.WAGON_GAP)
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append_array(ret_arc)                    # → (1620, 575) вправо
		pts.append_array(exit_arc.slice(2))          # крок 3+: дуга→вертикаль→дуга→QUEUE_Y
		pts.append(Vector2(base_tail_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y))
		_animate_delayed(wagon, pts, i * WAGON_RETURN_DELAY, func():
			wagon.rotation = PI
			queue.receive_wagon(wagon)
		)

func _on_repair_completed(wagons: Array) -> void:
	var arc         := Layout.get_repair_exit_arc()
	var base_tail_x := queue.get_tail_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		wagon.repair()
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append_array(arc)
		pts.append(Vector2(base_tail_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y))
		_animate_delayed(wagon, pts, i * WAGON_RETURN_DELAY, func():
			wagon.rotation = PI
			queue.receive_wagon(wagon)
		)
