class_name Layout

# Базовий розмір viewport
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

const JUNCTION_X    := 240.0
const QUEUE_Y       := 1039.0
# Вертикальна розподільна рейка
const DIST_RAIL_X   := 450.0
# Центральна колія (trunk) — Колія 4 (індекс 1-based)
const CENTER_TRACK  := 4

const STATION_LEFT  := 560.0
const STATION_RIGHT := 1280.0
const TRACK_TOP     := 305.0
const TRACK_SPACING := 90.0
const TRACK_COUNT   := 7
const CARGO_TRACK   := 1
const REPAIR_TRACK  := 7

const SPEED := 440.0

# Відстань між центрами вагонів
const WAGON_GAP := 110.0

# Скільки вагонів видно знизу одразу
const QUEUE_VISIBLE_LIMIT := 8

# X де горизонтальна черга закінчується і починається L-поворот
const QUEUE_STOP_X := 200.0
# Радіус заокруглення кутів L-повороту
const QUEUE_ARC_R  := 100.0

# Права збірна рейка (дзеркало DIST_RAIL_X)
const EXIT_RAIL_X  := SCREEN_W - DIST_RAIL_X   # 1470
# X вертикального сегменту правого L-повороту (дзеркало QUEUE_STOP_X)
const EXIT_STOP_X  := SCREEN_W - QUEUE_STOP_X  # 1720

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

static func get_slot_x(track_index: int, slot_index: int) -> float:
	var capacity_diff := float(MAX_TRACK_CAPACITY) - get_track_capacity(track_index)
	var offset := (capacity_diff / 2.0) * WAGON_GAP
	return STATION_RIGHT - 33.0 - offset - slot_index * WAGON_GAP

# X-позиція розподільної рейки для конкретної колії
static func get_dist_rail_x(track_index: int) -> float:
	var cap_diff := float(MAX_TRACK_CAPACITY - get_track_capacity(track_index))
	return DIST_RAIL_X + (cap_diff / 2.0) * WAGON_GAP

# Точка входу в центральну колію (trunk) — куди приходить дуга з черги.
static func get_center_entry_point() -> Vector2:
	return Vector2(get_dist_rail_x(CENTER_TRACK), get_track_y(CENTER_TRACK))

# Маршрут від горизонтальної черги до центрального входу в станцію.
# Форма: горизонталь → чверть-коло → вертикаль → чверть-коло → горизонталь у центр.
static func get_entry_arc(steps_per_arc: int = 24) -> PackedVector2Array:
	var center := get_center_entry_point()
	var R := QUEUE_ARC_R

	# Кут 1 (знизу): горизонталь → вертикаль
	var c1 := Vector2(QUEUE_STOP_X + R, QUEUE_Y - R)
	# Кут 2 (вгорі): вертикаль → горизонталь у центр
	var c2 := Vector2(QUEUE_STOP_X + R, center.y + R)

	var pts := PackedVector2Array()
	pts.append(Vector2(QUEUE_STOP_X + R, QUEUE_Y))

	for i in range(1, steps_per_arc + 1):
		var angle := PI * 0.5 + float(i) / steps_per_arc * PI * 0.5
		pts.append(c1 + Vector2(cos(angle), sin(angle)) * R)

	pts.append(Vector2(QUEUE_STOP_X, center.y + R))

	for i in range(1, steps_per_arc + 1):
		var angle := PI + float(i) / steps_per_arc * PI * 0.5
		pts.append(c2 + Vector2(cos(angle), sin(angle)) * R)

	pts.append(center)
	return pts

# --- Правий вихід (дзеркало входу) ---

# X збірної рейки для конкретної колії (дзеркало get_dist_rail_x)
static func get_exit_rail_x(track_index: int) -> float:
	var cap_diff := float(MAX_TRACK_CAPACITY - get_track_capacity(track_index))
	return EXIT_RAIL_X - (cap_diff / 2.0) * WAGON_GAP

# Центральна точка правого виходу (дзеркало get_center_entry_point)
static func get_exit_center_point() -> Vector2:
	return Vector2(get_exit_rail_x(CENTER_TRACK), get_track_y(CENTER_TRACK))

# Вихідна дуга: центр → горизонталь → чверть-коло → вертикаль → чверть-коло → горизонталь вліво.
# Дзеркало get_entry_arc: вгору-вправо → вертикаль вниз → ліво (форма _I, дзеркало ⌐).
static func get_exit_arc(steps_per_arc: int = 24) -> PackedVector2Array:
	var center := get_exit_center_point()
	var R := QUEUE_ARC_R

	# Кут 1 (вгорі-право): горизонталь → вниз (3π/2 → 2π)
	var c1 := Vector2(EXIT_STOP_X - R, center.y + R)
	# Кут 2 (внизу-ліво): вниз → ліво (дзеркало входу: 0 → π/2)
	var c2 := Vector2(EXIT_STOP_X - R, QUEUE_Y - R)

	var pts := PackedVector2Array()
	pts.append(center)

	# Горизонталь до кута 1
	pts.append(Vector2(EXIT_STOP_X - R, center.y))

	# Кут 1: право → вниз
	for i in range(1, steps_per_arc + 1):
		var angle := 1.5 * PI + float(i) / steps_per_arc * PI * 0.5
		pts.append(c1 + Vector2(cos(angle), sin(angle)) * R)

	# Вертикаль вниз
	pts.append(Vector2(EXIT_STOP_X, QUEUE_Y - R))

	# Кут 2: вниз → ліво (дзеркало: 0 → π/2)
	for i in range(1, steps_per_arc + 1):
		var angle := float(i) / steps_per_arc * PI * 0.5
		pts.append(c2 + Vector2(cos(angle), sin(angle)) * R)

	pts.append(Vector2(EXIT_STOP_X - R, QUEUE_Y))
	return pts

# Вихід колії 1: горизонталь → чверть-коло право→вгору → вертикаль за верхній край.
# fork = (exit_rail_x(1), track_y(1)); дуга: π/2 → 0; кінець → (fork.x+R, fork.y-R).
static func get_track1_exit_arc(steps_per_arc: int = 24) -> PackedVector2Array:
	var fork := Vector2(get_exit_rail_x(1), get_track_y(1))
	var R    := QUEUE_ARC_R
	var c    := Vector2(fork.x, fork.y - R)  # центр дуги: прямо над fork
	var pts  := PackedVector2Array()
	pts.append(fork)
	for i in range(1, steps_per_arc + 1):
		var angle := PI * 0.5 - float(i) / steps_per_arc * PI * 0.5
		pts.append(c + Vector2(cos(angle), sin(angle)) * R)
	# кінець: (fork.x + R, fork.y - R), напрямок — вгору
	return pts

# Повний маршрут від точки зупинки черги до слоту на колії.
# Використовується і для малювання рейок, і для анімації вагонів.
#
# Топологія:
#   черга → дуга → центр (колія 4)
#                       ├─ вгору → колія 3 → 2 → 1
#                       │  (trunk, пряме продовження)
#                       └─ вниз  → колія 5 → 6 → 7
static func get_entry_path(track_index: int, slot: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	# 1. Дуга від черги до центру (колія 4)
	pts.append_array(get_entry_arc())
	# 2. Розподільна рейка від центру до цільової колії
	if track_index < CENTER_TRACK:
		# Вгору: через колії 3 → 2 → 1 (зупиняємось на потрібній)
		for i in range(CENTER_TRACK - 1, track_index - 1, -1):
			pts.append(Vector2(get_dist_rail_x(i), get_track_y(i)))
	elif track_index > CENTER_TRACK:
		# Вниз: через колії 5 → 6 → 7 (зупиняємось на потрібній)
		for i in range(CENTER_TRACK + 1, track_index + 1):
			pts.append(Vector2(get_dist_rail_x(i), get_track_y(i)))
	# track_index == CENTER_TRACK: вже в центрі, не рухаємось
	# 3. Відгалуження в колію
	var dx := get_dist_rail_x(track_index)
	var ty := get_track_y(track_index)
	pts.append(Vector2(dx + 28.0, ty))
	# 4. Горизонтально до слоту
	pts.append(Vector2(get_slot_x(track_index, slot), ty))
	return pts

# Маршрут від центральної точки (кінець дуги) до слоту на колії.
# Використовується коли вагон вже стоїть в центрі після проїзду дуги.
static func get_track_path_from_center(track_index: int, slot: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(get_center_entry_point())
	if track_index < CENTER_TRACK:
		for i in range(CENTER_TRACK - 1, track_index - 1, -1):
			pts.append(Vector2(get_dist_rail_x(i), get_track_y(i)))
	elif track_index > CENTER_TRACK:
		for i in range(CENTER_TRACK + 1, track_index + 1):
			pts.append(Vector2(get_dist_rail_x(i), get_track_y(i)))
	var dx := get_dist_rail_x(track_index)
	var ty := get_track_y(track_index)
	pts.append(Vector2(dx + 28.0, ty))
	pts.append(Vector2(get_slot_x(track_index, slot), ty))
	return pts


const LOCO_DEPOT_RECT    := Rect2(1310.0, 800.0, 180.0, 75.0)
const REPAIR_DEPOT_RECT  := Rect2(1480.0, 808.0, 150.0, 74.0)  # будівля ремонту, колія 7
const LOADING_DEPOT_RECT := Rect2(1415.0, 100.0, 130.0, 55.0)  # зона навантаження, біля виходу колії 1

# Зміщення рейки повернення з навантаження відносно рейки в'їзду
const LOADING_RETURN_OFFSET := 60.0

# Вихідна дуга ремонтного депо: вниз → чверть-коло вправо → горизонталь черги.
# Геометрія: центр = (depot_center_x + R, track7_y), де R = QUEUE_Y - track7_y.
static func get_repair_exit_arc(steps_per_arc: int = 24) -> PackedVector2Array:
	var start := Vector2(REPAIR_DEPOT_RECT.get_center().x, get_track_y(REPAIR_TRACK))
	var R     := QUEUE_Y - start.y  # ≈ 194 px
	# Центр ЛІВОРУЧ: дуга від 0 до π/2 → старт іде вниз, кінець — ліворуч (напрям черги)
	var c     := Vector2(start.x - R, start.y)
	var pts   := PackedVector2Array()
	for i in range(steps_per_arc + 1):
		var angle := float(i) / steps_per_arc * PI * 0.5
		pts.append(c + Vector2(cos(angle), sin(angle)) * R)
	return pts

# Повернення з вантажного депо: вертикаль вниз → чверть-коло вправо → входить у горизонталь
# exit_arc між exit_center та першою дугою, тобто кінець = (EXIT_STOP_X - R, track_y(4)).
# Дуга: центр = (end_x, end_y - R_arc); кут π → π/2; R_arc = LOADING_RETURN_OFFSET.
static func get_loading_return_arc(steps_per_arc: int = 24) -> PackedVector2Array:
	var R     := LOADING_RETURN_OFFSET
	var end_x := EXIT_STOP_X - QUEUE_ARC_R          # 1620
	var end_y := get_track_y(CENTER_TRACK)           # 575
	var c     := Vector2(end_x, end_y - R)
	var pts   := PackedVector2Array()
	for i in range(steps_per_arc + 1):
		var angle := PI - float(i) / steps_per_arc * PI * 0.5
		pts.append(c + Vector2(cos(angle), sin(angle)) * R)
	return pts

# X-позиція паралельної рейки повернення = (1620 - LOADING_RETURN_OFFSET).
static func get_loading_return_x() -> float:
	return EXIT_STOP_X - QUEUE_ARC_R - LOADING_RETURN_OFFSET

static func is_wagon_compatible(wagon_type: Wagon.WagonType, track_index: int) -> bool:
	match wagon_type:
		Wagon.WagonType.BROKEN: return track_index == 7
		Wagon.WagonType.CARGO:  return track_index == 1
		_: return track_index != 1 and track_index != 7
