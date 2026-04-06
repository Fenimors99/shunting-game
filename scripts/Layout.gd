class_name Layout

# Базовий розмір viewport (відповідає project.godot)
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

# Точка розвороту черги (X де вагон має бути призначений або заблокує)
const JUNCTION_X    := 240.0
# Y-позиція вузла Queue в GameScreen
const QUEUE_Y       := 1039.0

# Станція
const STATION_LEFT  := 560.0
const STATION_RIGHT := 1280.0
const TRACK_TOP     := 305.0
const TRACK_SPACING := 85.0
const TRACK_COUNT   := 7

# Єдина швидкість руху (черга + анімація), px/сек
const SPEED := 440.0

# Початкова X-позиція першого (переднього) вагона черги
const QUEUE_START_X := 1200.0

# Місткість колій (статична)
const TRACK_CAPACITIES := { 1: 5, 2: 5, 3: 6, 4: 7, 5: 6, 6: 5, 7: 5 }
# Відстань між центрами вагонів (черга і колія)
const WAGON_GAP := 100.0

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING

static func get_track_capacity(track_index: int) -> int:
	return TRACK_CAPACITIES.get(track_index, 5)

# ОНОВЛЕНО: додано track_index як перший параметр
static func get_slot_x(track_index: int, slot_index: int) -> float:
	# Використовуємо нашу нову функцію, щоб знайти крайню точку для цієї колії
	var stop_x := get_track_stop_x(track_index)
	
	# Розраховуємо позицію вагона: перший (slot 0) стає в stop_x, 
	# наступні — лівіше на відстань WAGON_GAP
	return stop_x - (slot_index * WAGON_GAP)

# --- Призначення виїздів ---
# Глобальні позиції куди вагони їдуть після виїзду з колії (за межами екрану)
const EXIT_LOADING_POS  := Vector2(2200.0,  540.0)   # Під'їзна колія  — справа по центру
const EXIT_REPAIR_POS   := Vector2(2200.0, 1250.0)   # Вагонне депо    — справа знизу
const EXIT_SUBMIT_POS   := Vector2(2200.0, -200.0)   # Здати завдання  — вгору праворуч

# Локомотивне депо (на екрані)
const LOCO_DEPOT_RECT   := Rect2(750.0, 90.0, 180.0, 75.0)

static func is_wagon_compatible(wagon_type: Wagon.WagonType, track_index: int) -> bool:
	match wagon_type:
		Wagon.WagonType.BROKEN: return track_index == 7
		Wagon.WagonType.CARGO:  return track_index == 1
		_: return track_index != 1 and track_index != 7

static func get_track_stop_x(track_index: int) -> float:
	var track_y := get_track_y(track_index)
	
	# Параметри (мають збігатися з тими, що в _draw_station_bg)
	var right := STATION_RIGHT + 100.0
	var top := TRACK_TOP - 60.0
	var bottom := get_track_y(7) + 60.0 # 7 — кількість колій
	var height := bottom - top
	var center_y := top + height / 2.0
	var corner_offset := 70.0 
	
	var distance_from_center := absf(track_y - center_y) / (height / 2.0)
	var edge_x := right - (distance_from_center * corner_offset)
	
	return edge_x - 170.0 # Відступ для зупинки
