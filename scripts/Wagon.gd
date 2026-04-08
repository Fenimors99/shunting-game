extends Node2D
class_name Wagon

enum State      { IDLE, BLOCKED }
enum WagonType  { NORMAL, BROKEN, CARGO }
enum WagonColorId { BLUE, GREEN, YELLOW, PURPLE }

const NORMAL_COLORS := [
	Color(0.25, 0.50, 0.90),  # BLUE
	Color(0.20, 0.75, 0.35),  # GREEN
	Color(0.95, 0.80, 0.15),  # YELLOW
	Color(0.65, 0.25, 0.85),  # PURPLE
	Color(1.0, 0.4, 0.7),     # Pink
]

# Попередньо завантажуємо текстури з папки assets
const TEXTURES := [
	preload("res://assets/carriage_12.png"),
	preload("res://assets/carriage_22.png"),
	preload("res://assets/tank_car_12.png")
]

@export var wagon_type: WagonType = WagonType.NORMAL
var color_id: WagonColorId = WagonColorId.BLUE

var state: State = State.IDLE

# Тепер це Sprite2D замість ColorRect
@onready var _shadow: Sprite2D = $Shadow
@onready var _body: Sprite2D = $Body
@onready var _blink_timer: Timer = $BlinkTimer

func _ready() -> void:
	_setup_visuals()
	_blink_timer.timeout.connect(_on_blink_timeout)
	_refresh()

func _setup_visuals() -> void:
	# 1. Вибираємо випадкову текстуру з трьох доступних для БУДЬ-ЯКОГО вагона
	var random_texture = TEXTURES.pick_random()
	
	# 2. Налаштовуємо основний спрайт
	_body.texture = random_texture
	_body.scale = Vector2(0.125, 0.125) # Зменшуємо у 8 разів, як ви просили
	_body.position = Vector2.ZERO # Sprite2D автоматично центрується
	
	# 3. Налаштовуємо тінь/підсвічування
	_shadow.texture = random_texture
	# Робимо тінь трохи більшою (0.135 замість 0.125) для гарного ефекту обведення
	_shadow.scale = Vector2(0.135, 0.135) 
	_shadow.position = Vector2.ZERO
	_shadow.modulate = Color(0.9, 0.15, 0.15, 0.85)

func start_blocking() -> void:
	state = State.BLOCKED
	_blink_timer.start()
	_refresh()

func stop_blocking() -> void:
	_blink_timer.stop()
	_shadow.visible = false
	state = State.IDLE
	_refresh()

func _on_blink_timeout() -> void:
	_shadow.visible = !_shadow.visible

func _refresh() -> void:
	# ЗМІНЕНО: Тепер використовуємо `modulate` замість `color` для фарбування спрайтів
	match wagon_type:
		WagonType.BROKEN: _body.modulate = Color(0.85, 0.25, 0.25) # Червоні (в 7 колію)
		WagonType.CARGO:  _body.modulate = Color(0.95, 0.95, 0.95) # Білі (в 1 колію)
		_:                _body.modulate = NORMAL_COLORS[color_id]
		
	match state:
		State.IDLE:
			_shadow.visible = false
		State.BLOCKED:
			pass
