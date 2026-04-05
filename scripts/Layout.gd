class_name Layout

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

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING
