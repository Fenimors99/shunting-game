extends Node2D
class_name WagonQueue

const WAGON_SCENE := preload("res://scenes/Wagon.tscn")

# Емітується коли передній вагон доїхав до кінця дуги (центр) і чекає призначення
signal wagon_at_center(wagon: Wagon)
signal queue_unblocked()

var _wagons: Array[Wagon] = []
var _wagon_dists: Array[float] = []  # відстань від центру для кожного вагона

var _blocked: bool = false
var _running: bool = false
var _spawn_timer: float = 0.0

# Дуга, перевернута: _arc_pts[0] = центр, _arc_pts[-1] = QUEUE_STOP_X
var _arc_pts: PackedVector2Array
var _arc_cumul: Array[float]
var _arc_length: float


func _ready() -> void:
	_precompute_arc()
	for i in Layout.QUEUE_VISIBLE_LIMIT:
		_spawn_wagon(false)


func _precompute_arc() -> void:
	var arc := Layout.get_entry_arc()
	_arc_pts = PackedVector2Array()
	# Реверсуємо: центр → QUEUE_STOP_X стає індексом 0
	for i in range(arc.size() - 1, -1, -1):
		_arc_pts.append(arc[i])
	_arc_cumul = [0.0]
	for i in range(1, _arc_pts.size()):
		_arc_cumul.append(_arc_cumul[i - 1] + _arc_pts[i - 1].distance_to(_arc_pts[i]))
	_arc_length = _arc_cumul[-1] if not _arc_cumul.is_empty() else 0.0


# Відстань від центру → локальна позиція у просторі Queue вузла.
# d=0  → центр (кінець дуги)
# d>0  → на дузі або горизонтальній частині
func _position_at_dist(d: float) -> Vector2:
	# Queue вузол розміщений в (0, QUEUE_Y) → глобальні точки дуги потрібно перевести в локальні
	var queue_offset := Vector2(0.0, Layout.QUEUE_Y)
	if d <= 0.0:
		return _arc_pts[0] - queue_offset
	if d < _arc_length:
		for i in range(1, _arc_pts.size()):
			if _arc_cumul[i] >= d or i == _arc_pts.size() - 1:
				var seg_len := _arc_cumul[i] - _arc_cumul[i - 1]
				var t := 0.0 if seg_len < 0.001 else clampf((d - _arc_cumul[i - 1]) / seg_len, 0.0, 1.0)
				return _arc_pts[i - 1].lerp(_arc_pts[i], t) - queue_offset
		return _arc_pts[-1] - queue_offset
	else:
		# Горизонтальна частина: продовження від кінця дуги праворуч
		var extra := d - _arc_length
		return (_arc_pts[-1] - Vector2(0.0, Layout.QUEUE_Y)) + Vector2(extra, 0.0)


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

	# Коли заблоковано — wagon[0] повністю заморожений,
	# решта рухається і зупиняється за ним через spacing нижче.
	var start_idx := 1 if _blocked else 0
	for i in range(start_idx, _wagons.size()):
		_wagon_dists[i] -= step

	# wagon[0] не може проїхати повз центр (d=0) якщо не заблокований
	if not _blocked and not _wagons.is_empty() and _wagon_dists[0] < 0.0:
		_wagon_dists[0] = 0.0

	# Дотримання мінімальної відстані між вагонами
	for i in range(1, _wagons.size()):
		var min_dist := _wagon_dists[i - 1] + Layout.WAGON_GAP
		if _wagon_dists[i] < min_dist:
			_wagon_dists[i] = min_dist

	# Оновлення позицій і напрямку
	for i in range(_wagons.size()):
		_wagons[i].position = _position_at_dist(_wagon_dists[i])
		_wagons[i].rotation = _rotation_at_dist(_wagon_dists[i])


func _rotation_at_dist(d: float) -> float:
	var eps := 2.0
	var p_ahead  := _position_at_dist(maxf(0.0, d - eps))
	var p_behind := _position_at_dist(d + eps)
	var dir := p_ahead - p_behind
	if dir.length_squared() < 0.0001:
		return PI
	return dir.angle()


func _check_front_wagon() -> void:
	if _wagons.is_empty() or _wagon_dists[0] > 0.0:
		return
	_blocked = true
	wagon_at_center.emit(_wagons[0])


func unblock() -> void:
	if not _blocked:
		return
	var wagon := _wagons[0]
	_wagons.remove_at(0)
	_wagon_dists.remove_at(0)
	wagon.reparent(get_parent(), true)
	_blocked = false
	queue_unblocked.emit()


func is_blocked() -> bool:
	return _blocked


# --- Спавн ---

func _create_random_wagon() -> Wagon:
	var w: Wagon = WAGON_SCENE.instantiate()
	if LevelConfig.current_level == 0:
		# Нескінченний режим: Red 7%, White 13%, Blue/Green/Yellow/Purple по 20%
		var roll := randi() % 100
		if roll < 7:
			w.wagon_type = Wagon.WagonType.BROKEN
		elif roll < 20:
			w.wagon_type = Wagon.WagonType.CARGO
		elif roll < 40:
			w.wagon_type = Wagon.WagonType.NORMAL
			w.color_id = Wagon.WagonColorId.BLUE
		elif roll < 60:
			w.wagon_type = Wagon.WagonType.NORMAL
			w.color_id = Wagon.WagonColorId.GREEN
		elif roll < 80:
			w.wagon_type = Wagon.WagonType.NORMAL
			w.color_id = Wagon.WagonColorId.YELLOW
		else:
			w.wagon_type = Wagon.WagonType.NORMAL
			w.color_id = Wagon.WagonColorId.PURPLE
	else:
		# Статичні рівні: оригінальна логіка спавну
		var roll := randi() % 5
		if roll == 0:
			w.wagon_type = Wagon.WagonType.BROKEN
		elif roll == 1:
			w.wagon_type = Wagon.WagonType.CARGO
		else:
			w.wagon_type = Wagon.WagonType.NORMAL
			w.color_id = randi() % Wagon.WagonColorId.size() as Wagon.WagonColorId
	w.rotation = PI
	return w


func _spawn_wagon(spawn_offscreen: bool) -> void:
	var w := _create_random_wagon()
	var start_dist: float
	if _wagon_dists.is_empty():
		start_dist = _arc_length + (Layout.QUEUE_START_X - Layout.QUEUE_STOP_X)
	else:
		start_dist = _wagon_dists.back() + Layout.WAGON_GAP
	if spawn_offscreen:
		var offscreen_dist := _arc_length + (Layout.QUEUE_OFFSCREEN_SPAWN_X - Layout.QUEUE_STOP_X)
		start_dist = maxf(offscreen_dist, start_dist)
	w.position = _position_at_dist(start_dist)
	add_child(w)
	_wagons.append(w)
	_wagon_dists.append(start_dist)


func _try_spawn_by_timer(delta: float) -> void:
	if _wagons.size() >= Layout.QUEUE_VISIBLE_LIMIT:
		return
	_spawn_timer += delta
	if _spawn_timer < Layout.QUEUE_SPAWN_INTERVAL:
		return
	_spawn_timer = 0.0
	_spawn_wagon(true)


# --- Повернення вагона з станції ---

func get_tail_x() -> float:
	if _wagon_dists.is_empty():
		return Layout.QUEUE_STOP_X + _arc_length + Layout.WAGON_GAP
	return _position_at_dist(_wagon_dists.back()).x


func receive_wagon(wagon: Wagon) -> void:
	wagon.reparent(self, true)
	wagon.stop_blocking()
	var tail_dist: float = (_wagon_dists.back() + Layout.WAGON_GAP) if not _wagon_dists.is_empty() else (_arc_length + Layout.WAGON_GAP)
	wagon.position = _position_at_dist(tail_dist)
	_wagons.append(wagon)
	_wagon_dists.append(tail_dist)
