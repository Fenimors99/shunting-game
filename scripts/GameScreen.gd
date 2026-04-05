extends Node2D

@onready var queue:   WagonQueue = $Queue
@onready var station: Node2D    = $Station

func _ready() -> void:
	queue.position.y = Layout.QUEUE_Y
	queue.wagon_entered_track.connect(_on_wagon_entered_track)
	queue.queue_blocked.connect(_on_queue_blocked)
	queue.queue_unblocked.connect(_on_queue_unblocked)
	station.track_entry_tapped.connect(_on_track_entry_tapped)
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

func _on_queue_blocked(_wagon: Wagon) -> void:
	print("Черга заблокована — призначте вагон")

func _on_queue_unblocked() -> void:
	print("Черга розблокована")

# --- Тап на кружечок входу колії ---

func _on_track_entry_tapped(track_index: int) -> void:
	if queue.is_blocked() and not station.is_track_full(track_index):
		queue.resolve_block(track_index)

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
