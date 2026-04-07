extends Node2D
class_name WagonQueue

const WAGON_SCENE := preload("res://scenes/Wagon.tscn")

signal wagon_entered_track(wagon: Wagon, track_index: int)
signal queue_blocked(wagon: Wagon)
signal queue_unblocked()

var _wagons: Array[Wagon] = []
var _blocked: bool = false
var _running: bool = false
var _spawn_timer: float = 0.0


func _ready() -> void:
	for i in Layout.QUEUE_VISIBLE_LIMIT:
		_spawn_wagon(false)


func start() -> void:
	_running = true
	_spawn_timer = 0.0


func _process(delta: float) -> void:
	if not _running:
		return

	_move_wagons(delta)
	_try_spawn_by_timer(delta)

	if not _blocked:
		_check_front_wagon()


# --- Рух ---

func _move_wagons(delta: float) -> void:
	if _wagons.is_empty():
		return

	var step := Layout.SPEED * delta

	# Первый вагон едет только если очередь не заблокирована
	if not _blocked:
		var front: Wagon = _wagons[0]
		front.position.x -= step

	# Остальные вагоны подтягиваются к предыдущему
	for i in range(1, _wagons.size()):
		var prev: Wagon = _wagons[i - 1]
		var current: Wagon = _wagons[i]

		var target_x := prev.position.x + Layout.WAGON_GAP
		var new_x := current.position.x - step

		# Вагон едет влево, но не может встать ближе, чем нужно
		current.position.x = maxf(target_x, new_x)


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

func _create_random_wagon() -> Wagon:
	var w: Wagon = WAGON_SCENE.instantiate()
	var roll := randi() % 5

	if roll == 0:
		w.wagon_type = Wagon.WagonType.BROKEN
	elif roll == 1:
		w.wagon_type = Wagon.WagonType.CARGO
	else:
		w.wagon_type = Wagon.WagonType.NORMAL
		w.color_id = randi() % Wagon.NORMAL_COLORS.size() as Wagon.WagonColorId

	w.rotation = PI
	return w


func _spawn_wagon(spawn_offscreen: bool) -> void:
	var w: Wagon = _create_random_wagon()
	var base_x: float = Layout.QUEUE_START_X if _wagons.is_empty() else _wagons.back().position.x + Layout.WAGON_GAP
	var spawn_x: float = maxf(Layout.QUEUE_OFFSCREEN_SPAWN_X, base_x) if spawn_offscreen else base_x
	w.position = Vector2(spawn_x, 0.0)
	add_child(w)
	_wagons.append(w)


func _try_spawn_by_timer(delta: float) -> void:
	if _wagons.size() >= Layout.QUEUE_VISIBLE_LIMIT:
		return

	_spawn_timer += delta

	if _spawn_timer < Layout.QUEUE_SPAWN_INTERVAL:
		return

	_spawn_timer = 0.0
	_spawn_wagon(true)


func get_front_wagon() -> Wagon:
	return _wagons[0] if not _wagons.is_empty() else null


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


# --- Повернення вагона з станції в хвіст черги ---

func get_tail_global_x() -> float:
	if _wagons.is_empty():
		return Layout.QUEUE_START_X

	return _wagons.back().position.x


func receive_wagon(wagon: Wagon) -> void:
	wagon.reparent(self, true)
	wagon.stop_blocking()
	_wagons.append(wagon)
