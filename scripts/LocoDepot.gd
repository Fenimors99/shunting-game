extends Node2D
class_name LocoDepot

const MAX_LOCOS   := 3
const RETURN_TIME := 20.0

signal availability_changed(has_loco: bool)
const W           := 340.0
const H           := 112.0

var _timers: Array[float] = []

func _ready() -> void:
	_timers.resize(MAX_LOCOS)
	_timers.fill(0.0)

func _process(delta: float) -> void:
	var needs_redraw := false
	for i in MAX_LOCOS:
		if _timers[i] > 0.0:
			var prev_ceil := ceili(_timers[i])
			var will_expire := _timers[i] <= delta
			_timers[i] = maxf(0.0, _timers[i] - delta)
			if will_expire:
				availability_changed.emit(has_locomotive())
				needs_redraw = true
			elif ceili(_timers[i]) != prev_ceil:
				needs_redraw = true
	if needs_redraw:
		queue_redraw()

func has_locomotive() -> bool:
	for t in _timers:
		if t == 0.0:
			return true
	return false

func use_locomotive() -> bool:
	for i in MAX_LOCOS:
		if _timers[i] == 0.0:
			_timers[i] = RETURN_TIME
			queue_redraw()
			availability_changed.emit(has_locomotive())
			return true
	return false

func available_count() -> int:
	var n := 0
	for t in _timers:
		if t == 0.0: n += 1
	return n

func _draw() -> void:
	var font := ThemeDB.fallback_font

	# Фон
	draw_rect(Rect2(0, 0, W, H), Color(0.10, 0.08, 0.05, 0.93))
	draw_rect(Rect2(0, 0, W, H), Color(0.60, 0.45, 0.20, 0.85), false, 2.0)
	draw_rect(Rect2(2, 2, W - 4, H - 4), Color(0.70, 0.55, 0.25, 0.12), false, 1.0)

	# Заголовок
	draw_string(font, Vector2(12, 22),
		"Локомотивне депо",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.70, 0.35, 0.9))

	for i in MAX_LOCOS:
		var y := 42 + i * 24
		var free := _timers[i] == 0.0
		draw_circle(Vector2(18, y), 7, Color(0.25, 0.85, 0.40) if free else Color(0.90, 0.50, 0.15))
		var label := "доступний" if free else "%dс" % ceili(_timers[i])
		var col := Color(0.75, 0.90, 0.75) if free else Color(0.95, 0.75, 0.40)
		draw_string(font, Vector2(34, y + 6), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
