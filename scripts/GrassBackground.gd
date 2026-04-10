extends Node2D
class_name GrassBackground

# Комментарии на русском языке, как ты просил.

@export var map_width: int = 120
@export var map_height: int = 70
@export var tile_size: int = 16

# Основной тайл травы
@export var base_tile: Texture2D

# Декоративные варианты
@export var detail_tile_1: Texture2D
@export var detail_tile_2: Texture2D

# Насколько часто появляются декоративные тайлы
@export_range(0.0, 1.0) var detail_1_chance: float = 0.08
@export_range(0.0, 1.0) var detail_2_chance: float = 0.06

# Сид генерации
@export var random_seed: int = 12345

# Если true, фон пересоздаётся при запуске сцены
@export var generate_on_ready: bool = true

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if generate_on_ready:
		generate()


func generate() -> void:
	# Удаляем старые тайлы, если фон уже генерировался ранее
	for child in get_children():
		child.queue_free()

	_rng.seed = random_seed

	# Проверка, что тайлы назначены
	if base_tile == null:
		push_error("Не назначен base_tile")
		return

	# Масштабирование 128 -> 16, то есть делим на 8
	var scale_factor := float(tile_size) / 128.0

	for y in range(map_height):
		for x in range(map_width):
			var sprite := Sprite2D.new()
			sprite.texture = _pick_tile()
			sprite.centered = false
			sprite.position = Vector2(x * tile_size, y * tile_size)
			sprite.scale = Vector2(scale_factor, scale_factor)

			# Отключаем сглаживание, чтобы пиксели были чёткими
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

			add_child(sprite)


func _pick_tile() -> Texture2D:
	var roll := _rng.randf()

	# Сначала редкий декоративный тайл 1
	if detail_tile_1 != null and roll < detail_1_chance:
		return detail_tile_1

	# Потом редкий декоративный тайл 2
	if detail_tile_2 != null and roll < detail_1_chance + detail_2_chance:
		return detail_tile_2

	# Иначе обычная трава
	return base_tile
