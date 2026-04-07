class_name Layout

# Базовий розмір viewport
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

const JUNCTION_X    := 240.0
const QUEUE_Y       := 1039.0
const QUEUE_ARC_X   := 420.0   # Де черга закінчується і починається дуга повороту

const STATION_LEFT  := 560.0
const STATION_RIGHT := 1280.0
const TRACK_TOP     := 305.0
const TRACK_SPACING := 90.0
const TRACK_COUNT   := 7

const SPEED := 440.0

# Відстань між центрами вагонів
const WAGON_GAP := 95.0

# Скільки вагонів видно знизу одразу
const QUEUE_VISIBLE_LIMIT := 8

# Раз на скільки секунд випускається новий вагон із-за екрана
const QUEUE_SPAWN_INTERVAL := 1.0

# Початкова X-позиція першого вагона
const QUEUE_START_X := 1200.0

# X-позиція появи нового вагона за правою межею екрана
const QUEUE_OFFSCREEN_SPAWN_X := SCREEN_W + WAGON_GAP

# Місткості колій — симетричний шестикутник навколо центральної колії
const TRACK_CAPACITIES   := { 1: 4, 2: 5, 3: 6, 4: 7, 5: 6, 6: 5, 7: 4 }
const MAX_TRACK_CAPACITY := 7   # місткість центральної (найдовшої) колії

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING

static func get_track_capacity(track_index: int) -> int:
	return TRACK_CAPACITIES.get(track_index, 5)

# ЗМІНЕНО: Тепер приймає track_index для обчислення відступу
static func get_slot_x(track_index: int, slot_index: int) -> float:
	# Вираховуємо наскільки ця колія коротша за найдовшу (7)
	var capacity_diff = 7.0 - get_track_capacity(track_index)
	# Відступаємо від правого краю, щоб відцентрувати вагони
	var offset = (capacity_diff / 2.0) * WAGON_GAP
	return STATION_RIGHT - 33.0 - offset - slot_index * WAGON_GAP

const EXIT_LOADING_POS  := Vector2(2200.0,  540.0)
const EXIT_REPAIR_POS   := Vector2(2200.0, 1250.0)
const EXIT_SUBMIT_POS   := Vector2(2200.0, -200.0)

const LOCO_DEPOT_RECT   := Rect2(1310.0, 800.0, 180.0, 75.0)

static func is_wagon_compatible(wagon_type: Wagon.WagonType, track_index: int) -> bool:
	match wagon_type:
		Wagon.WagonType.BROKEN: return track_index == 7
		Wagon.WagonType.CARGO:  return track_index == 1
		_: return track_index != 1 and track_index != 7
