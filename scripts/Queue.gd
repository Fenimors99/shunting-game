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
var _returning: bool = false         # true поки вагони анімуються назад у чергу
var _spawn_settle_timer: float = 0.0 # > 0 поки вагони від кнопки ще не доїхали до видимої зони

# Дуга, перевернута: _arc_pts[0] = центр, _arc_pts[-1] = QUEUE_STOP_X
var _arc_pts: PackedVector2Array
var _arc_cumul: Array[float]
var _arc_length: float

var _tutorial_idx: int = 0
const TUTORIAL_SEQUENCE = [
	# --- ЗАВДАННЯ 1: 2 синіх, 1 зелений (Просте сортування) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	
	# --- ЗАВДАННЯ 2: 1 Рожевий (Ремонт + Завантаження) ---
	# Цей вагон виїде ЧЕРВОНИМ. Гравець має:
	# 1. Відправити на колію 7 (стане БІЛИМ після ремонту)
	# 2. Відправити на колію 1 (стане РОЖЕВИМ після завантаження)
	{"type": Wagon.WagonType.BROKEN, "color": 0}, 
	
	# --- ЗАВДАННЯ 3: 1 Рожевий, 1 Жовтий, 1 Синій (Комбіноване) ---
	{"type": Wagon.WagonType.BROKEN, "color": 0}, # Знову червоний для перетворення в рожевий
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN},  # (ЗАПАСНИЙ зелений)
]

# Рівень 2: Потрібно ~21 вагон для завдань, ми даємо 45.
# Стратегія: "Зелений потоп" на початку та розриви в серіях потрібних кольорів.
# Рівень 2: Оптимізовано до ~35 вагонів
const LEVEL2_SEQUENCE = [
	# --- БЛОК 1: Сміття та підготовка (7 вагонів) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN},
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.BROKEN, "color": 0},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, 
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN},

	# --- БЛОК 2: Перші потрібні впереміш (13 вагонів) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.BROKEN, "color": 0}, 
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},

	# --- БЛОК 3: Фінальна засипка (15 вагонів) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, 
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, 
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, 
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, 
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}
]

# Рівень 3: Потрібно ~18 вагонів, ми даємо 65.
# Стратегія: "Заблокований старт". Перші 15 вагонів — майже повне сміття (жовті та фіолетові).
# Враховуючи, що одна колія заблокована, гравцеві ПРИЙДЕТЬСЯ вивозити сміття назад у депо.
# Складність збережена за рахунок концентрації сміття на початку.
# Підвищено тиск через збільшення кількості зламаних вагонів та "фіолетового" сміття.
const LEVEL3_SEQUENCE = [
	# --- ФАЗА 1: Сміттєва стіна (6 вагонів) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE},

	# --- ФАЗА 2: Ремонтний тиск (+3 нових вагона: 2 зламаних, 1 жовтий) ---
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.BROKEN, "color": 0},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, # НОВИЙ (засмічення)
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.BROKEN, "color": 0},
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.BROKEN, "color": 0}, # НОВІ зламані
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},
	{"type": Wagon.WagonType.BROKEN, "color": 0}, {"type": Wagon.WagonType.BROKEN, "color": 0},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE},

	# --- ФАЗА 3: Основна видача (+3 нових вагона: 2 фіолетових, 1 синій) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, # НОВИЙ (для Завдання 3, але заважає зараз)
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, # НОВИЙ
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, 
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.PURPLE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, # НОВИЙ (запасний синій)

	# --- ФАЗА 4: Фінал (8 вагонів) ---
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.GREEN},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.YELLOW}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE},
	{"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}, {"type": Wagon.WagonType.NORMAL, "color": Wagon.WagonColorId.BLUE}
]

func _ready() -> void:
	_precompute_arc()
	
	if LevelConfig.current_level == 1:
		for i in TUTORIAL_SEQUENCE.size():
			_spawn_wagon(false)
	elif LevelConfig.current_level == 2:
		for i in LEVEL2_SEQUENCE.size():
			_spawn_wagon(false)
	elif LevelConfig.current_level == 3:
		for i in LEVEL3_SEQUENCE.size():
			_spawn_wagon(false)
	else:
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


func _process(delta: float) -> void:
	if not _running:
		return
	if _spawn_settle_timer > 0.0:
		_spawn_settle_timer = maxf(0.0, _spawn_settle_timer - delta)
	_move_wagons(delta)
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

	# wagon[0] зупиняється на пів-вагона до центру (d = WAGON_GAP/2)
	const FRONT_STOP := Layout.WAGON_GAP * 0.5
	if not _blocked and not _wagons.is_empty() and _wagon_dists[0] < FRONT_STOP:
		_wagon_dists[0] = FRONT_STOP

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
	const FRONT_STOP := Layout.WAGON_GAP * 0.5
	if _wagons.is_empty() or _wagon_dists[0] > FRONT_STOP:
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
	w.rotation = PI
	
	var sequence = []
	if LevelConfig.current_level == 1:
		sequence = TUTORIAL_SEQUENCE
	elif LevelConfig.current_level == 2:
		sequence = LEVEL2_SEQUENCE
	elif LevelConfig.current_level == 3:
		sequence = LEVEL3_SEQUENCE

	# Якщо це рівень з фіксованою чергою
	if sequence.size() > 0:
		if _tutorial_idx < sequence.size():
			var data = sequence[_tutorial_idx]
			w.wagon_type = data["type"]
			if w.wagon_type == Wagon.WagonType.NORMAL:
				w.color_id = data["color"]
			_tutorial_idx += 1
		else:
			# ЗАПОБІЖНИК: якщо фіксовані вагони закінчилися
			var roll := randi() % 4
			if roll == 0:
				w.wagon_type = Wagon.WagonType.BROKEN
			else:
				w.wagon_type = Wagon.WagonType.NORMAL
				w.color_id = randi() % Wagon.WagonColorId.size() as Wagon.WagonColorId
		return w
				
	# Логіка для нескінченного режиму (0)
	if LevelConfig.current_level == 0:
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
	# Логіка для інших статичних рівнів (3+)
	else:
		var roll := randi() % 5
		if roll == 0:
			w.wagon_type = Wagon.WagonType.BROKEN
		elif roll == 1:
			w.wagon_type = Wagon.WagonType.CARGO
		else:
			w.wagon_type = Wagon.WagonType.NORMAL
			w.color_id = randi() % Wagon.WagonColorId.size() as Wagon.WagonColorId
			
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


# --- Ручне поповнення черги ---

func fill_to_limit() -> void:
	var count := Layout.QUEUE_VISIBLE_LIMIT - _wagons.size()
	if count <= 0:
		return
	for _i in count:
		_spawn_wagon(true)
	# Час доїзду останнього вагона до входу в дугу (x = QUEUE_STOP_X + QUEUE_ARC_R = 300).
	# Фактична x-позиція спавну = 300 + (QUEUE_OFFSCREEN_SPAWN_X - QUEUE_STOP_X) = 2130.
	# Відстань до дуги = QUEUE_OFFSCREEN_SPAWN_X - QUEUE_STOP_X = 1830px → ~4.2с на вагон.
	var last_extra := float(count - 1) * Layout.WAGON_GAP
	_spawn_settle_timer = (Layout.QUEUE_OFFSCREEN_SPAWN_X - Layout.QUEUE_STOP_X + last_extra) / Layout.SPEED

func is_below_limit() -> bool:
	return _wagons.size() < Layout.QUEUE_VISIBLE_LIMIT


# --- Повернення вагона з станції ---

func get_wagon_count() -> int:
	return _wagons.size()

func has_capacity_for(n: int) -> bool:
	if _returning or _spawn_settle_timer > 0.0:
		return false
	return _wagons.size() + n <= Layout.QUEUE_MAX_CAPACITY

func set_returning(v: bool) -> void:
	_returning = v

func get_tail_x() -> float:
	if _wagon_dists.is_empty():
		return Layout.QUEUE_STOP_X + _arc_length + Layout.WAGON_GAP
	return _position_at_dist(_wagon_dists.back()).x


func receive_wagon(wagon: Wagon) -> void:
	wagon.reparent(self, true)
	wagon.stop_blocking()
	# Виводимо dist із поточної позиції вагона (кінцева точка анімації),
	# щоб уникнути стрибка через просування черги під час польоту.
	# Після reparent позиція вагона — в локальному просторі Queue (world_x, 0).
	var arc_entry_x := Layout.QUEUE_STOP_X + Layout.QUEUE_ARC_R  # = 300
	var tail_dist: float
	if wagon.position.x > arc_entry_x:
		tail_dist = _arc_length + (wagon.position.x - arc_entry_x)
	else:
		tail_dist = _arc_length + Layout.WAGON_GAP  # fallback
	# Вагон не може бути попереду хвоста (якщо черга сильно просунулась)
	if not _wagon_dists.is_empty() and tail_dist < _wagon_dists.back() + Layout.WAGON_GAP:
		tail_dist = _wagon_dists.back() + Layout.WAGON_GAP
		wagon.position = _position_at_dist(tail_dist)
	_wagons.append(wagon)
	_wagon_dists.append(tail_dist)
