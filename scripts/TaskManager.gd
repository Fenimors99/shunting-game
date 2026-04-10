extends Node
class_name TaskManager

signal task_completed(index: int)
signal all_tasks_completed()
signal task_added(index: int)   # тільки для нескінченного режиму

# --- Статичні завдання для рівнів 1–3 ---
const STATIC_TASKS: Array = [
	# Рівень 1 (ОЗНАЙОМЧИЙ)
	[
		# 1. Просте завдання: вчимося сортувати базові кольори
		{ Wagon.WagonColorId.BLUE: 2, Wagon.WagonColorId.GREEN: 1 },
		
		# 2. Ремонт і завантаження: Гравець має взяти червоний (BROKEN), 
		# відправити в ремонт (стане CARGO), потім на завантаження (стане рожевим NORMAL)
		{ 4: 1 }, # 4 - це індекс рожевого кольору у вашому Wagon.gd
		
		# 3. Комбіноване завдання для закріплення
		{ 4: 1, Wagon.WagonColorId.YELLOW: 1, Wagon.WagonColorId.BLUE: 1 },
	],
	# Рівень 2 (ГОЛОВОЛОМКА - 4 завдання, нелінійне проходження)
	[
		{ Wagon.WagonColorId.BLUE: 2, Wagon.WagonColorId.GREEN: 1 }, # Завдання 1
		{ 4: 1, Wagon.WagonColorId.YELLOW: 2 },                      # Завдання 2 (Рожевий + Жовті)
		{ 4: 1, Wagon.WagonColorId.PURPLE: 1 },                      # Завдання 3 (Рожевий + Фіолет)
		{ Wagon.WagonColorId.GREEN: 1, Wagon.WagonColorId.BLUE: 1, Wagon.WagonColorId.PURPLE: 1 }, # Завдання 4 (Мікс)
	],
	# Рівень 3
	[
		# Рівень 3 (ОБМЕЖЕНИЙ ПРОСТІР - Колія 2 заблокована)
		{ Wagon.WagonColorId.BLUE: 3, Wagon.WagonColorId.PURPLE: 2 },            # Завдання 1
		{ 4: 1, Wagon.WagonColorId.YELLOW: 2, Wagon.WagonColorId.GREEN: 2 },    # Завдання 2 (Рожевий + Жовті + Зелені)
		{ Wagon.WagonColorId.PURPLE: 2, Wagon.WagonColorId.BLUE: 2, Wagon.WagonColorId.YELLOW: 2 }, # Завдання 3 (Мікс)
	],
]

# Кількість вагонів для кожного слоту складності (індекс = слот)
# Найпростіше → Неможливо
const SLOT_WAGONS := [3, 4, 5, 6, 7]
const INFINITE_TASK_SLOTS := 5

# Затримка між зникненням виконаного та появою нового завдання (секунди)
const REPLACE_DELAY := 0.5

# Для статичних рівнів
var _tasks: Array = []
var _completed: Array[bool] = []

# Для нескінченного режиму
var _active_tasks: Array[Dictionary] = []

func _ready() -> void:
	if LevelConfig.current_level == 0:
		_active_tasks.resize(INFINITE_TASK_SLOTS)
		# Заповнюємо порожніми словниками щоб перевірка різноманітності працювала
		for i in INFINITE_TASK_SLOTS:
			_active_tasks[i] = {}
		for i in INFINITE_TASK_SLOTS:
			_active_tasks[i] = _generate_task(i)
	else:
		var idx := clampi(LevelConfig.current_level - 1, 0, STATIC_TASKS.size() - 1)
		_tasks = STATIC_TASKS[idx]
		_completed.resize(_tasks.size())
		_completed.fill(false)

# --- Публічний API ---

# Повертає масив завдань (Dictionary) — для TaskPanel
func get_tasks() -> Array:
	if LevelConfig.current_level == 0:
		return _active_tasks
	return _tasks

func get_task_count() -> int:
	return get_tasks().size()

func can_submit(wagons: Array) -> bool:
	return _find_matching_task(wagons) != -1

# Позначає завдання виконаним. Повертає індекс або -1.
func submit(wagons: Array) -> int:
	var i := _find_matching_task(wagons)
	if i == -1:
		return -1

	task_completed.emit(i)

	if LevelConfig.current_level == 0:
		# Замінюємо завдання того ж слоту (зберігаємо складність)
		var captured := i
		get_tree().create_timer(REPLACE_DELAY).timeout.connect(func():
			_active_tasks[captured] = _generate_task(captured)
			task_added.emit(captured)
		)
	else:
		_completed[i] = true
		if _completed.all(func(v): return v):
			all_tasks_completed.emit()

	return i

func is_completed(index: int) -> bool:
	if LevelConfig.current_level == 0:
		return false
	return _completed[index]

# --- Генерація завдань для нескінченного режиму ---

# Скільки інших завдань можуть вимагати той самий колір одночасно
const MAX_COLOR_OVERLAP := 2

# Будує один словник завдання для слоту (без перевірки різноманітності)
func _make_task_dict(slot: int) -> Dictionary:
	var total: int = SLOT_WAGONS[slot]
	var max_colors := mini(5, total)
	var min_colors := 2 if slot > 0 else 1
	var num_colors := randi_range(min_colors, max_colors)
	var available: Array = [
		Wagon.WagonColorId.BLUE,
		Wagon.WagonColorId.GREEN,
		Wagon.WagonColorId.YELLOW,
		Wagon.WagonColorId.PURPLE,
		4,  # Pink
	]
	available.shuffle()
	var counts: Array = []
	counts.resize(num_colors)
	counts.fill(1)
	var remaining := total - num_colors
	for _j in remaining:
		counts[randi() % num_colors] += 1
	var task := {}
	for k in num_colors:
		task[available[k]] = counts[k]
	return task

# Перевіряє: жоден колір нового завдання не зустрічається в MAX_COLOR_OVERLAP+ інших слотах
func _is_diverse(task: Dictionary, skip_slot: int) -> bool:
	for color_id in task:
		var seen := 0
		for i in _active_tasks.size():
			if i == skip_slot:
				continue
			if _active_tasks[i].has(color_id):
				seen += 1
		if seen >= MAX_COLOR_OVERLAP:
			return false
	return true

# Генерує завдання для слоту: до 12 спроб знайти різноманітний варіант
func _generate_task(slot: int) -> Dictionary:
	for _attempt in 12:
		var task := _make_task_dict(slot)
		if _is_diverse(task, slot):
			return task
	# Fallback — повертаємо хоч щось після вичерпання спроб
	return _make_task_dict(slot)

# --- Пошук відповідного завдання ---

func _find_matching_task(wagons: Array) -> int:
	var actual := _count_colors(wagons)
	var tasks := get_tasks()
	for i in tasks.size():
		if LevelConfig.current_level != 0 and _completed[i]:
			continue
		if actual == tasks[i]:
			return i
	return -1

func _count_colors(wagons: Array) -> Dictionary:
	var counts := {}
	for w in wagons:
		if w.wagon_type != Wagon.WagonType.NORMAL:
			continue
		var c: int = w.color_id
		counts[c] = counts.get(c, 0) + 1
	return counts
