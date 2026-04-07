class_name Layout

# Базовий розмір viewport (відповідає project.godot)
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

# Точка розвороту черги (X де вагон має бути призначений або заблокує)
const JUNCTION_X := 240.0
# Y-позиція вузла Queue в GameScreen
const QUEUE_Y := 1039.0

# Станція
const STATION_LEFT := 560.0
const STATION_RIGHT := 1280.0
const TRACK_TOP := 305.0
const TRACK_SPACING := 85.0
const TRACK_COUNT := 7

# Єдина швидкість руху (черга + анімація), px/сек
const SPEED := 440.0

# Відстань між центрами вагонів
const WAGON_GAP := 100.0

# Скільки вагонів видно знизу одразу
const QUEUE_VISIBLE_LIMIT := 8

# Раз на скільки секунд випускається новий вагон із-за екрана
const QUEUE_SPAWN_INTERVAL := 1.0

# Початкова X-позиція першого вагона
const QUEUE_START_X := 1200.0

# X-позиція появи нового вагона за правою межею екрана
const QUEUE_OFFSCREEN_SPAWN_X := SCREEN_W + WAGON_GAP

# Місткість колій (статична)
const TRACK_CAPACITIES := { 1: 4, 2: 5, 3: 6, 4: 7, 5: 6, 6: 5, 7: 4 }

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING

static func get_track_capacity(track_index: int) -> int:
	return TRACK_CAPACITIES.get(track_index, 5)

static func get_slot_x(slot_index: int) -> float:
	return STATION_RIGHT - 33.0 - slot_index * WAGON_GAP

static func is_wagon_compatible(wagon_type: int, track_index: int) -> bool:
	if wagon_type == Wagon.WagonType.CARGO:
		return track_index == 1

	if wagon_type == Wagon.WagonType.BROKEN:
		return track_index == 7

	return track_index != 1 and track_index != 7

# --- Призначення виїздів ---
# Глобальні позиції куди вагони їдуть після виїзду з колії (за межами екрану)
const EXIT_LOADING_POS := Vector2(2200.0, 540.0)
const EXIT_REPAIR_POS := Vector2(2200.0, 1250.0)
const EXIT_SUBMIT_POS := Vector2(2200.0, -200.0)

# Локомотивне депо (на екрані)
const LOCO_DEPOT_RECT := Rect2(1310.0, 870.0, 180.0, 75.0)
