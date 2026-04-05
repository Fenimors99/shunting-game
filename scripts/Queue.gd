extends Node2D
class_name WagonQueue

const WAGON_SCENE := preload("res://scenes/Wagon.tscn")

const QUEUE_LIMIT    := 10
const SPAWN_INTERVAL := 3.0
const QUEUE_SPEED    := 80.0   # px/сек
const WAGON_GAP      := 100.0  # відстань між вагонами
const ENTRY_X        := 160.0  # X де вагон має бути призначений або заблокує

signal wagon_entered_track(wagon: Wagon, track_index: int)
signal queue_blocked(wagon: Wagon)
signal queue_unblocked()

var _wagons: Array[Wagon] = []
var _selected: Wagon = null
var _blocked: bool = false
var _spawn_timer: float = 0.0
var _post_entry_cooldown: float = -1.0  # -1 = не активний

const _COLORS := ["red", "blue", "green", "yellow", "purple"]

func _ready() -> void:
	# Початкові 5 вагонів — стоять, чекають на "Старт"
	for i in 5:
		_spawn_wagon(i)

func _process(delta: float) -> void:
	if _blocked:
		return
	_move_wagons(delta)
	_check_front_wagon()
	_tick_spawn(delta)

# --- Рух ---

func _move_wagons(delta: float) -> void:
	for w in _wagons:
		w.position.x -= QUEUE_SPEED * delta

func _check_front_wagon() -> void:
	if _wagons.is_empty():
		return
	var front: Wagon = _wagons[0]
	if front.position.x > ENTRY_X:
		return
	if front.assigned_track == -1:
		_block(front)
	else:
		_dispatch(front)

func _dispatch(wagon: Wagon) -> void:
	_wagons.remove_at(0)
	if _selected == wagon:
		_selected = null
	wagon.tapped.disconnect(_on_wagon_tapped)
	# Передаємо вагон у GameScreen (зберігаємо world-позицію)
	wagon.reparent(get_parent(), true)
	wagon_entered_track.emit(wagon, wagon.assigned_track)
	_post_entry_cooldown = SPAWN_INTERVAL

func _block(wagon: Wagon) -> void:
	_blocked = true
	wagon.start_blocking()
	queue_blocked.emit(wagon)

# --- Спавн ---

func _tick_spawn(delta: float) -> void:
	if _wagons.size() >= QUEUE_LIMIT:
		return
	if _post_entry_cooldown >= 0.0:
		_post_entry_cooldown -= delta
		if _post_entry_cooldown < 0.0:
			_do_spawn()
		return
	_spawn_timer += delta
	if _spawn_timer >= SPAWN_INTERVAL:
		_spawn_timer = 0.0
		_do_spawn()

func _do_spawn() -> void:
	_spawn_wagon(_wagons.size())

func _spawn_wagon(index: int) -> void:
	var w: Wagon = WAGON_SCENE.instantiate()
	w.wagon_color = _COLORS[randi() % _COLORS.size()]
	# Позиція: правіше від останнього вагона
	w.position = Vector2(ENTRY_X + (index + 1) * WAGON_GAP + 80.0, 0.0)
	w.tapped.connect(_on_wagon_tapped)
	add_child(w)
	_wagons.append(w)

# --- Вибір і призначення ---

func _on_wagon_tapped(wagon: Wagon) -> void:
	if _selected == wagon:
		wagon.deselect()
		_selected = null
		return
	if _selected != null:
		_selected.deselect()
	wagon.select()
	_selected = wagon

func assign_selected_to_track(track_index: int) -> void:
	if _selected == null:
		return
	_selected.assign(track_index)
	_selected = null

# Викликається з GameScreen коли гравець призначає заблокований вагон
func resolve_block(track_index: int) -> void:
	if not _blocked or _wagons.is_empty():
		return
	var front: Wagon = _wagons[0]
	front.stop_blocking()
	front.assign(track_index)
	_blocked = false
	queue_unblocked.emit()
	_dispatch(front)

func has_selected() -> bool:
	return _selected != null

func is_blocked() -> bool:
	return _blocked
