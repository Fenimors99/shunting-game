extends Node2D
class_name Wagon

enum State    { IDLE, BLOCKED }
enum WagonType { NORMAL, BROKEN, CARGO }

const NORMAL_COLORS := [
	Color(0.25, 0.50, 0.90),  # blue
	Color(0.20, 0.75, 0.35),  # green
	Color(0.95, 0.80, 0.15),  # yellow
	Color(0.65, 0.25, 0.85),  # purple
]

# Розміри вагона (можна підправити, якщо вони завеликі чи замалі)
const WAGON_WIDTH = 80.0
const WAGON_HEIGHT = 40.0

@export var wagon_type: WagonType = WagonType.NORMAL
var _normal_color: Color = NORMAL_COLORS[0]

var state: State = State.IDLE

@onready var _shadow: ColorRect = $Shadow
@onready var _body: ColorRect = $Body
@onready var _blink_timer: Timer = $BlinkTimer

func _ready() -> void:
	# 1. Спершу налаштовуємо візуал (центрування)
	_setup_visuals()
	
	# 2. Потім підключаємо таймер та оновлюємо кольори
	_blink_timer.timeout.connect(_on_blink_timeout)
	_refresh()

# --- Нова функція для центрування ---

func _setup_visuals() -> void:
	var size = Vector2(WAGON_WIDTH, WAGON_HEIGHT)
	
	# Робимо так, щоб (0,0) вагона був рівно посередині прямокутника
	var centered_pos = -size / 2.0
	
	# Налаштовуємо Body
	_body.size = size
	_body.position = centered_pos
	_body.pivot_offset = size / 2.0 # Центр для внутрішніх поворотів
	
	# Налаштовуємо Shadow
	_shadow.size = size
	_shadow.position = centered_pos
	_shadow.pivot_offset = size / 2.0

# --- Публічний API ---

func start_blocking() -> void:
	state = State.BLOCKED
	_shadow.color = Color(0.9, 0.15, 0.15, 0.85)
	_blink_timer.start()
	_refresh()

func stop_blocking() -> void:
	_blink_timer.stop()
	_shadow.visible = false
	state = State.IDLE
	_refresh()

# --- Внутрішнє ---

func _on_blink_timeout() -> void:
	_shadow.visible = !_shadow.visible

func _refresh() -> void:
	match wagon_type:
		WagonType.BROKEN: _body.color = Color(0.85, 0.25, 0.25)
		WagonType.CARGO:  _body.color = Color(0.95, 0.95, 0.95)
		_:                _body.color = _normal_color
	match state:
		State.IDLE:
			_shadow.visible = false
		State.BLOCKED:
			pass
