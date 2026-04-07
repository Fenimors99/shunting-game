class_name Layout

# Базовий розмір viewport
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

const JUNCTION_X    := 240.0
const QUEUE_Y       := 1039.0
# Вертикальна розподільна рейка
const DIST_RAIL_X   := 220.0
# Де горизонтальна черга закінчується і починається дуга вгору
# = DIST_RAIL_X + (QUEUE_Y - track_7_y), щоб дуга була рівномірною
const QUEUE_ARC_X   := DIST_RAIL_X + QUEUE_Y - (TRACK_TOP + (TRACK_COUNT - 1) * TRACK_SPACING)

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

# Глибина петлі вхідної дуги нижче QUEUE_Y
const ENTRY_ARC_DEPTH := 350.0

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING

static func get_track_capacity(track_index: int) -> int:
	return TRACK_CAPACITIES.get(track_index, 5)

static func get_slot_x(track_index: int, slot_index: int) -> float:
	var capacity_diff := float(MAX_TRACK_CAPACITY) - get_track_capacity(track_index)
	var offset := (capacity_diff / 2.0) * WAGON_GAP
	return STATION_RIGHT - 33.0 - offset - slot_index * WAGON_GAP

# X-позиція розподільної рейки для конкретної колії
static func get_dist_rail_x(track_index: int) -> float:
	var cap_diff := float(MAX_TRACK_CAPACITY - get_track_capacity(track_index))
	return DIST_RAIL_X + (cap_diff / 2.0) * WAGON_GAP

# Нижня точка розподільної рейки (колія 7)
static func get_dist_rail_bottom() -> Vector2:
	return Vector2(get_dist_rail_x(TRACK_COUNT), get_track_y(TRACK_COUNT) + 20.0)

# Масив точок вхідної дуги (черга → низ розподільної рейки)
static func get_entry_arc(steps: int = 48) -> PackedVector2Array:
	var bot := get_dist_rail_bottom()
	return _cubic_bezier_pts(
		Vector2(QUEUE_ARC_X, QUEUE_Y),
		Vector2(QUEUE_ARC_X, QUEUE_Y + ENTRY_ARC_DEPTH),
		Vector2(bot.x - 50.0, QUEUE_Y + ENTRY_ARC_DEPTH),
		Vector2(bot.x, bot.y),
		steps
	)

# Повний маршрут від точки зупинки черги до слоту на колії.
# Використовується і для малювання рейок, і для анімації вагонів.
static func get_entry_path(track_index: int, slot: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# 1. Петля-дуга вниз і вгору до низу розподільної рейки
	pts.append_array(get_entry_arc())
	# 2. По розподільній рейці вгору до потрібної колії
	for i in range(TRACK_COUNT, track_index - 1, -1):
		pts.append(Vector2(get_dist_rail_x(i), get_track_y(i) + 20.0))
	# 3. Маленька стрілка-відгалуження в колію
	var dx := get_dist_rail_x(track_index)
	var ty := get_track_y(track_index)
	pts.append(Vector2(dx + 28.0, ty))
	# 4. Горизонтально до слоту
	pts.append(Vector2(get_slot_x(track_index, slot), ty))
	return pts

static func _cubic_bezier_pts(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2,
		steps: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		var t  := float(i) / steps
		var mt := 1.0 - t
		pts.append(mt*mt*mt*p0 + 3.0*mt*mt*t*p1 + 3.0*mt*t*t*p2 + t*t*t*p3)
	return pts

const EXIT_LOADING_POS  := Vector2(2200.0,  540.0)
const EXIT_REPAIR_POS   := Vector2(2200.0, 1250.0)
const EXIT_SUBMIT_POS   := Vector2(2200.0, -200.0)

const LOCO_DEPOT_RECT   := Rect2(1310.0, 800.0, 180.0, 75.0)

static func is_wagon_compatible(wagon_type: Wagon.WagonType, track_index: int) -> bool:
	match wagon_type:
		Wagon.WagonType.BROKEN: return track_index == 7
		Wagon.WagonType.CARGO:  return track_index == 1
		_: return track_index != 1 and track_index != 7
