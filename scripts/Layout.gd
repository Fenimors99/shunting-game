class_name Layout

# Базовий розмір viewport (відповідає project.godot)
const SCREEN_W := 1920.0
const SCREEN_H := 1080.0

# Точка розвороту черги (X де вагон має бути призначений або заблокує)
const JUNCTION_X    := 240.0
# Y-позиція вузла Queue в GameScreen
const QUEUE_Y       := 940.0

# Станція
const STATION_LEFT  := 560.0
const STATION_RIGHT := 1460.0
const TRACK_TOP     := 100.0
const TRACK_SPACING := 110.0
const TRACK_COUNT   := 7

# Єдина швидкість руху (черга + анімація), px/сек
const SPEED := 440.0

# Початкова X-позиція першого (переднього) вагона черги
const QUEUE_START_X := 1200.0

# Місткість колій (статична)
const TRACK_CAPACITIES := { 1: 5, 2: 5, 3: 6, 4: 7, 5: 6, 6: 5, 7: 5 }
# Відстань між вагонами на колії
const TRACK_SLOT_SPACING := 120.0

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING

static func get_track_capacity(track_index: int) -> int:
	return TRACK_CAPACITIES.get(track_index, 5)

static func get_slot_x(slot_index: int) -> float:
	return STATION_LEFT + 20.0 + slot_index * TRACK_SLOT_SPACING
