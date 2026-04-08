extends Node2D

@onready var queue:              WagonQueue  = $Queue
@onready var station:            Node2D      = $Station
@onready var loco_depot:         LocoDepot   = $LocoDepot
@onready var task_manager:       TaskManager = $TaskManager
@onready var task_panel:         TaskPanel   = $TaskPanel
@onready var task_toggle_button: Button      = $TaskToggleButton

var _timer_label: Label
var _timer_running: bool = false
var _time_elapsed: float = 0.0

func _ready() -> void:
	queue.position.y = Layout.QUEUE_Y
	queue.wagon_entered_track.connect(_on_wagon_entered_track)
	queue.queue_blocked.connect(_on_queue_blocked)
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
	_timer_running = false # Зупиняємо таймер
	
	var victory_scene = load("res://scenes/VictoryScreen.tscn").instantiate()
	
	# 1. СПОЧАТКУ передаємо час
	victory_scene.final_time = _format_time(_time_elapsed)
	
	# 2. ПОТІМ додаємо в дерево (це запустить _ready в VictoryScreen)
	get_tree().root.add_child(victory_scene)
	
	# 3. Очищуємо стару сцену
	get_tree().current_scene.queue_free()
	get_tree().current_scene = victory_scene

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
	_timer_label = Label.new()
	_timer_label.position = Vector2(20, 20) # Розміщення в лівому верхньому кутку
	_timer_label.add_theme_font_size_override("font_size", 36)
	_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_timer_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1, 0.8))
	_timer_label.add_theme_constant_override("outline_size", 6)
	_timer_label.text = "Час: 00:00"
	add_child(_timer_label)

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
	_timer_running = true # Запускаємо таймер
	
func _on_queue_blocked(wagon: Wagon) -> void:
	station.set_entry_filter(wagon.wagon_type)

func _on_queue_unblocked() -> void:
	station.clear_entry_filter()

func _on_track_entry_tapped(track_index: int) -> void:
	if not queue.is_blocked():
		return
	if station.is_track_full(track_index):
		return
	var wagon := queue.get_front_wagon()
	if wagon and not Layout.is_wagon_compatible(wagon.wagon_type, track_index):
		return
	queue.resolve_block(track_index)

func _on_wagon_entered_track(wagon: Wagon, track_index: int) -> void:
	var slot: int = station.reserve_slot(track_index)
	var target_y: float = station.get_track_y(track_index)
	# ЗМІНЕНО: Передаємо track_index для шестикутного зміщення
	var target_x: float = Layout.get_slot_x(track_index, slot)
	
	var start_y = Layout.QUEUE_Y
	var junction_x = Layout.JUNCTION_X
	var bend_start_y = target_y + 20.0
	var bend_end_x = junction_x + 40.0
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)

	tween.tween_property(wagon, "rotation", -PI/2, 0.15)
	
	var up_dist = abs(start_y - bend_start_y)
	tween.tween_property(wagon, "position:y", bend_start_y, up_dist / Layout.SPEED)
	
	tween.tween_property(wagon, "rotation", -PI/4, 0.1)
	
	var diag_end = Vector2(bend_end_x, target_y)
	var fixed_diag_dist = 44.7
	var constant_diag_speed = Layout.SPEED * 0.7 
	tween.tween_property(wagon, "position", diag_end, fixed_diag_dist / constant_diag_speed)
	
	tween.tween_property(wagon, "rotation", 0.0, 0.1)
	
	var final_dist = abs(bend_end_x - target_x)
	tween.tween_property(wagon, "position:x", target_x, final_dist / Layout.SPEED)
	
	tween.tween_callback(func(): _wagon_arrived(wagon, track_index, slot))

func _wagon_arrived(wagon: Wagon, track_index: int, slot: int) -> void:
	station.place_wagon(wagon, track_index, slot)

func _on_track_exit_tapped(track_index: int) -> void:
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	match track_index:
		1: _animate_exit(wagons, Layout.EXIT_LOADING_POS)
		7: _animate_exit(wagons, Layout.EXIT_REPAIR_POS)

func _on_track_exit_choice(track_index: int, submit: bool) -> void:
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	if submit:
		task_manager.submit(wagons)
		_animate_exit(wagons, Layout.EXIT_SUBMIT_POS)
	else:
		_return_to_queue(wagons)

func _animate_exit(wagons: Array, dest: Vector2) -> void:
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var delay := i * 0.12
		var dist := wagon.position.distance_to(dest)
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(wagon, "position", dest, dist / Layout.SPEED)
		tween.tween_callback(wagon.queue_free)

func _return_to_queue(wagons: Array) -> void:
	var base_x := queue.get_tail_global_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var dest := Vector2(base_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y)
		var tween := create_tween()
		var dist := wagon.position.distance_to(dest)
		tween.tween_property(wagon, "position", dest, dist / Layout.SPEED)
		
		tween.tween_callback(func(): 
			wagon.rotation = PI
			queue.receive_wagon(wagon)
			)
			
