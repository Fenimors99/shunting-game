class_name Layout

# Точка розвороту черги (X де вагон має бути призначений)
const JUNCTION_X    := 160.0
# Y-позиція вузла Queue в GameScreen
const QUEUE_Y       := 620.0

# Станція
const STATION_LEFT  := 380.0
const STATION_RIGHT := 980.0
const TRACK_TOP     := 140.0
const TRACK_SPACING := 70.0
const TRACK_COUNT   := 7

static func get_track_y(track_index: int) -> float:
	return TRACK_TOP + (track_index - 1) * TRACK_SPACING
