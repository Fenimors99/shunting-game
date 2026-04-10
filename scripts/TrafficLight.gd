extends Node2D
class_name TrafficLight

enum LightState {
	RED,
	GREEN
}

@export var housing_texture: Texture2D
@export var lamp_radius: float = 28.0

# Позиции центров ламп относительно левого верхнего угла спрайта.
# Подогнано под твой файл 248x128: слева красный, справа зелёный.
@export var red_center: Vector2 = Vector2(64.0, 64.0)
@export var green_center: Vector2 = Vector2(184.0, 64.0)

@export var red_on_color: Color = Color(1.0, 0.18, 0.12, 0.95)
@export var red_off_color: Color = Color(0.22, 0.05, 0.05, 0.9)

@export var green_on_color: Color = Color(0.2, 1.0, 0.35, 0.95)
@export var green_off_color: Color = Color(0.04, 0.18, 0.06, 0.9)

@export var glow_scale: float = 1.45
@export var sprite_scale: Vector2 = Vector2(0.5, 0.5)

var _state: LightState = LightState.RED
var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = housing_texture
	_sprite.scale = sprite_scale
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 2
	add_child(_sprite)

	queue_redraw()

func set_red() -> void:
	_state = LightState.RED
	queue_redraw()

func set_green() -> void:
	_state = LightState.GREEN
	queue_redraw()

func flash_green(duration: float = 1) -> void:
	set_green()

	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_inside_tree():
			set_red()
	)

func _draw() -> void:
	var sx := sprite_scale.x
	var sy := sprite_scale.y

	var red_pos := Vector2(red_center.x * sx, red_center.y * sy)
	var green_pos := Vector2(green_center.x * sx, green_center.y * sy)
	var radius := lamp_radius * minf(sx, sy)

	var red_color := red_on_color if _state == LightState.RED else red_off_color
	var green_color := green_on_color if _state == LightState.GREEN else green_off_color

	# Внешнее свечение
	draw_circle(red_pos, radius * glow_scale, Color(red_color.r, red_color.g, red_color.b, 0.18))
	draw_circle(green_pos, radius * glow_scale, Color(green_color.r, green_color.g, green_color.b, 0.18))

	# Основной свет
	draw_circle(red_pos, radius, red_color)
	draw_circle(green_pos, radius, green_color)

	# Яркое ядро огня
	draw_circle(red_pos, radius * 0.45, Color(1, 0.72, 0.72, 0.95) if _state == LightState.RED else Color(0.18, 0.08, 0.08, 0.65))
	draw_circle(green_pos, radius * 0.45, Color(0.82, 1, 0.82, 0.95) if _state == LightState.GREEN else Color(0.08, 0.15, 0.08, 0.65))
