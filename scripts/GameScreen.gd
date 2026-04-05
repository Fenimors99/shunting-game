extends Node2D

@onready var queue:      WagonQueue = $Queue
@onready var station:    Node2D    = $Station
@onready var loco_depot: LocoDepot = $LocoDepot

func _ready() -> void:
	queue.position.y = Layout.QUEUE_Y
	queue.wagon_entered_track.connect(_on_wagon_entered_track)
	queue.queue_blocked.connect(_on_queue_blocked)
	queue.queue_unblocked.connect(_on_queue_unblocked)
	station.track_entry_tapped.connect(_on_track_entry_tapped)
	station.track_exit_tapped.connect(_on_track_exit_tapped)
	station.track_exit_choice.connect(_on_track_exit_choice)
	loco_depot.availability_changed.connect(station.set_loco_available)
	_create_start_button()

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

func _on_start_pressed(btn: Button) -> void:
	btn.queue_free()
	queue.start()

# --- Сигнали черги ---

func _on_queue_blocked(wagon: Wagon) -> void:
	station.set_entry_filter(wagon.wagon_type)

func _on_queue_unblocked() -> void:
	station.clear_entry_filter()

# --- Тап на кружечок входу колії ---

func _on_track_entry_tapped(track_index: int) -> void:
	if not queue.is_blocked():
		return
	if station.is_track_full(track_index):
		return
	var wagon := queue.get_front_wagon()
	if wagon and not _wagon_fits_track(wagon, track_index):
		return
	queue.resolve_block(track_index)

func _wagon_fits_track(wagon: Wagon, track_index: int) -> bool:
	match wagon.wagon_type:
		Wagon.WagonType.BROKEN: return track_index == 7
		Wagon.WagonType.CARGO:  return track_index == 1
		_: return track_index != 1 and track_index != 7

# --- Анімація вагона: черга → поворот вгору → поворот вправо → колія ---

func _on_wagon_entered_track(wagon: Wagon, track_index: int) -> void:
	var slot: int        = station.reserve_slot(track_index)
	var target_y: float  = station.get_track_y(track_index)
	var target_x: float  = Layout.get_slot_x(slot)
	var up_time: float    = abs(Layout.QUEUE_Y - target_y) / Layout.SPEED
	var right_time: float = abs(target_x - Layout.JUNCTION_X) / Layout.SPEED

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	tween.tween_property(wagon, "position:y", target_y, up_time)
	tween.tween_property(wagon, "position:x", target_x, right_time)
	tween.tween_callback(func(): _wagon_arrived(wagon, track_index, slot))

func _wagon_arrived(wagon: Wagon, track_index: int, slot: int) -> void:
	station.place_wagon(wagon, track_index, slot)

# --- Виїзд з колії ---

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
		_animate_exit(wagons, Layout.EXIT_SUBMIT_POS)
	else:
		_return_to_queue(wagons)

# wagons виїжджають правіше, потім зникають за екраном
func _animate_exit(wagons: Array, dest: Vector2) -> void:
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var delay := i * 0.12
		var dist := wagon.position.distance_to(dest)
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(wagon, "position", dest, dist / Layout.SPEED)
		tween.tween_callback(wagon.queue_free)

# wagons повертаються в хвіст черги
func _return_to_queue(wagons: Array) -> void:
	var base_x := queue.get_tail_global_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var dest := Vector2(base_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y)
		var dist := wagon.position.distance_to(dest)
		var tween := create_tween()
		tween.tween_property(wagon, "position", dest, dist / Layout.SPEED)
		tween.tween_callback(func(): queue.receive_wagon(wagon))
