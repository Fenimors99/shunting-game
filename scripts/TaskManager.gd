extends Node
class_name TaskManager

signal task_completed(index: int)
signal all_tasks_completed()

# Кожне завдання — словник { WagonColorId: кількість }
const TASKS: Array = [
	{ Wagon.WagonColorId.BLUE: 4, Wagon.WagonColorId.GREEN: 1 },
	{ Wagon.WagonColorId.BLUE: 2, Wagon.WagonColorId.GREEN: 3, Wagon.WagonColorId.YELLOW: 1 },
]

var _completed: Array[bool] = []

func _ready() -> void:
	_completed.resize(TASKS.size())
	_completed.fill(false)

# Чи можна здати саме ці вагони (точна відповідність одному незакритому завданню)
func can_submit(wagons: Array) -> bool:
	var actual := _count_colors(wagons)
	for i in TASKS.size():
		if not _completed[i] and actual == TASKS[i]:
			return true
	return false

# Позначає відповідне завдання виконаним. Повертає індекс або -1.
func submit(wagons: Array) -> int:
	var actual := _count_colors(wagons)
	for i in TASKS.size():
		if not _completed[i] and actual == TASKS[i]:
			_completed[i] = true
			task_completed.emit(i)
			if _completed.all(func(v): return v):
				all_tasks_completed.emit()
			return i
	return -1

func is_completed(index: int) -> bool:
	return _completed[index]

func _count_colors(wagons: Array) -> Dictionary:
	var counts := {}
	for w in wagons:
		if w.wagon_type != Wagon.WagonType.NORMAL:
			continue
		var c: int = w.color_id
		counts[c] = counts.get(c, 0) + 1
	return counts
