extends Node2D

@onready var queue:              WagonQueue  = $Queue
@onready var station:            Node2D      = $Station
@onready var loco_depot:         LocoDepot   = $LocoDepot
@onready var task_manager:       TaskManager = $TaskManager
@onready var task_panel:         TaskPanel   = $TaskPanel
@onready var task_toggle_button: Button      = $TaskToggleButton

# Вагон, що стоїть в центральній точці і чекає призначення на колію
var _wagon_at_center: Wagon = null

var _timer_label: Label
var _timer_running: bool = false
var _time_elapsed: float = 0.0

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
	_create_start_button()
	
func _on_all_tasks_completed() -> void:
	_timer_running = false
	# Чекаємо поки вагони відʼїдуть, потім fade-to-black → victory
	var tween := create_tween()
	tween.tween_interval(2.2)
	tween.tween_callback(_start_victory_transition)

func _start_victory_transition() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	overlay.size = get_viewport_rect().size
	overlay.z_index = 100
	add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.8)
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
	
func _on_start_pressed(btn: Button) -> void:
	btn.queue_free()
	queue.start()
	_timer_running = true

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
	if track_index == 7:
		_animate_to_repair(wagons)
	elif track_index == 1:
		_animate_to_loading(wagons)
	else:
		_animate_exit(wagons, track_index)

func _on_track_exit_choice(track_index: int, submit: bool) -> void:
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	if submit:
		task_manager.submit(wagons)
		_animate_submit(wagons, track_index)
	else:
		_return_to_queue(wagons, track_index)

func _animate_exit(wagons: Array, track_index: int) -> void:
	var exit_arc := Layout.get_exit_arc()
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		# Будуємо шлях: слот → збірна рейка → дуга → за екран
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append(Vector2(Layout.get_exit_rail_x(track_index), Layout.get_track_y(track_index)))
		if track_index < Layout.CENTER_TRACK:
			for j in range(track_index + 1, Layout.CENTER_TRACK + 1):
				pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
		elif track_index > Layout.CENTER_TRACK:
			for j in range(track_index - 1, Layout.CENTER_TRACK - 1, -1):
				pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
		pts.append_array(exit_arc)
		pts.append(Vector2(-Layout.WAGON_GAP, Layout.QUEUE_Y))
		var idx := i
		var delay_tween := create_tween()
		delay_tween.tween_interval(idx * 0.18)
		delay_tween.tween_callback(func():
			_animate_along_path(wagon, pts, wagon.queue_free)
		)

func _return_to_queue(wagons: Array, track_index: int) -> void:
	var exit_arc := Layout.get_exit_arc()
	var base_tail_x := queue.get_tail_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append(Vector2(Layout.get_exit_rail_x(track_index), Layout.get_track_y(track_index)))
		if track_index < Layout.CENTER_TRACK:
			for j in range(track_index + 1, Layout.CENTER_TRACK + 1):
				pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
		elif track_index > Layout.CENTER_TRACK:
			for j in range(track_index - 1, Layout.CENTER_TRACK - 1, -1):
				pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
		pts.append_array(exit_arc)
		pts.append(Vector2(base_tail_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y))
		var idx := i
		var delay_tween := create_tween()
		delay_tween.tween_interval(idx * 0.18)
		delay_tween.tween_callback(func():
			_animate_along_path(wagon, pts, func():
				wagon.rotation = PI
				queue.receive_wagon(wagon)
			)
		)

func _animate_submit(wagons: Array, track_index: int) -> void:
	var center_y := Layout.get_track_y(Layout.CENTER_TRACK)
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		# Той самий шлях що _animate_exit: збірна рейка → центр,
		# але замість дуги — пряма вправо по рейці здачі
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append(Vector2(Layout.get_exit_rail_x(track_index), Layout.get_track_y(track_index)))
		if track_index < Layout.CENTER_TRACK:
			for j in range(track_index + 1, Layout.CENTER_TRACK + 1):
				pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
		elif track_index > Layout.CENTER_TRACK:
			for j in range(track_index - 1, Layout.CENTER_TRACK - 1, -1):
				pts.append(Vector2(Layout.get_exit_rail_x(j), Layout.get_track_y(j)))
		pts.append(Vector2(Layout.SCREEN_W + Layout.WAGON_GAP, center_y))
		var idx := i
		var delay_tween := create_tween()
		delay_tween.tween_interval(idx * 0.18)
		delay_tween.tween_callback(func():
			_animate_along_path(wagon, pts, wagon.queue_free)
		)

func _animate_to_loading(wagons: Array) -> void:
	var arc    := Layout.get_track1_exit_arc()
	var arc_end := arc[arc.size() - 1]
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append_array(arc)
		pts.append(Vector2(arc_end.x, -Layout.WAGON_GAP))
		var idx := i
		var delay_tween := create_tween()
		delay_tween.tween_interval(idx * 0.18)
		delay_tween.tween_callback(func():
			_animate_along_path(wagon, pts, wagon.queue_free)
		)

func _animate_to_repair(wagons: Array) -> void:
	var dest_x   := Layout.REPAIR_DEPOT_RECT.get_center().x
	var track7_y := Layout.get_track_y(7)
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var pts := PackedVector2Array()
		pts.append(wagon.position)
		pts.append(Vector2(dest_x, track7_y))
		var idx := i
		var delay_tween := create_tween()
		delay_tween.tween_interval(idx * 0.18)
		delay_tween.tween_callback(func():
			_animate_along_path(wagon, pts, wagon.queue_free)
		)
