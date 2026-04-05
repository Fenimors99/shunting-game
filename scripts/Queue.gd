extends Node2D
class_name WagonQueue

const WAGON_SCENE  := preload("res://scenes/Wagon.tscn")
const WAGON_COUNT  := 50

signal wagon_entered_track(wagon: Wagon, track_index: int)
signal queue_blocked(wagon: Wagon)
signal queue_unblocked()

var _wagons: Array[Wagon] = []
var _blocked: bool = false
var _running: bool = false

const _COLORS := ["red", "blue", "green", "yellow", "purple"]

func _ready() -> void:
	for i in WAGON_COUNT:
		_spawn_wagon()

func start() -> void:
	_running = true

func _process(delta: float) -> void:
	if not _running or _blocked:
		return
	_move_wagons(delta)
	_check_front_wagon()

# --- Рух ---

func _move_wagons(delta: float) -> void:
	for w in _wagons:
		w.position.x -= Layout.SPEED * delta

func _check_front_wagon() -> void:
	if _wagons.is_empty():
		return
	var front: Wagon = _wagons[0]
	if front.position.x > Layout.JUNCTION_X:
		return
	_block(front)

func _dispatch(wagon: Wagon, track_index: int) -> void:
	_wagons.remove_at(0)
	wagon.reparent(get_parent(), true)
	wagon_entered_track.emit(wagon, track_index)

func _block(wagon: Wagon) -> void:
	_blocked = true
	wagon.start_blocking()
	queue_blocked.emit(wagon)

# --- Спавн ---

func _spawn_wagon() -> void:
	var w: Wagon = WAGON_SCENE.instantiate()
	w.wagon_color = _COLORS[randi() % _COLORS.size()]
	var spawn_x: float = Layout.QUEUE_START_X if _wagons.is_empty() \
		else _wagons.back().position.x + Layout.WAGON_GAP
	w.position = Vector2(spawn_x, 0.0)
	add_child(w)
	_wagons.append(w)

# --- Призначення ---

func resolve_block(track_index: int) -> void:
	if not _blocked or _wagons.is_empty():
		return
	var front: Wagon = _wagons[0]
	front.stop_blocking()
	_blocked = false
	queue_unblocked.emit()
	_dispatch(front, track_index)

func is_blocked() -> bool:
	return _blocked
