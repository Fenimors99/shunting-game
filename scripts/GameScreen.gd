extends Node2D

# Константи маршруту (мають збігатися з Queue.gd і Station.gd)
const QUEUE_Y      := 620.0
const JUNCTION_X   := 160.0
const STATION_LEFT := 380.0
const ANIM_SPEED   := 220.0   # px/сек

@onready var queue:   WagonQueue = $Queue
@onready var station: Node2D    = $Station

func _ready() -> void:
	queue.wagon_entered_track.connect(_on_wagon_entered_track)
	queue.queue_blocked.connect(_on_queue_blocked)
	queue.queue_unblocked.connect(_on_queue_unblocked)
	station.track_entry_tapped.connect(_on_track_entry_tapped)

# --- Сигнали черги ---

func _on_queue_blocked(_wagon: Wagon) -> void:
	print("Черга заблокована — призначте вагон")

func _on_queue_unblocked() -> void:
	print("Черга розблокована")

# --- Тап на кружечок входу колії ---

func _on_track_entry_tapped(track_index: int) -> void:
	if queue.has_selected():
		queue.assign_selected_to_track(track_index)
	elif queue.is_blocked():
		queue.resolve_block(track_index)

# --- Анімація вагона: черга → поворот вгору → поворот вправо → колія ---

func _on_wagon_entered_track(wagon: Wagon, track_index: int) -> void:
	var target_y: float  = station.get_track_y(track_index)
	var up_time: float   = abs(QUEUE_Y - target_y) / ANIM_SPEED
	var right_time: float = abs(STATION_LEFT - JUNCTION_X) / ANIM_SPEED

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)

	# 1. Рухається вгору до потрібної колії
	tween.tween_property(wagon, "position:y", target_y, up_time)
	# 2. Рухається вправо до входу на станцію
	tween.tween_property(wagon, "position:x", STATION_LEFT + 20, right_time)
	# 3. Вагон на місці — припинити анімацію
	tween.tween_callback(func(): _wagon_arrived(wagon, track_index))

func _wagon_arrived(wagon: Wagon, track_index: int) -> void:
	print("Вагон стоїть на Колії ", track_index)
	# TODO: передати вагон в Track (Етап 3)
