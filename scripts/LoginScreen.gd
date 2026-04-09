extends Node2D
class_name LoginScreen

const LEVEL_SELECT_SCENE := "res://scenes/LevelSelect.tscn" # Новий шлях

@onready var firebase: FirebaseBridge = $FirebaseBridge

var _btn_signin: Button
var _label_status: Label

func _ready() -> void:
	firebase.auth_success.connect(_on_auth_success)
	firebase.auth_failed.connect(_on_auth_failed)
	_build_ui()

func _build_ui() -> void:
	var vp := get_viewport_rect().size

	# Фон
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.12, 1.0)
	bg.size  = vp
	add_child(bg)

	# Заголовок
	var title := Label.new()
	title.text = "Shunting Game"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, vp.y * 0.28)
	title.size     = Vector2(vp.x, 72)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.93, 1.00))
	add_child(title)

	var sub := Label.new()
	sub.text = "Маневрова гра"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, vp.y * 0.28 + 80)
	sub.size     = Vector2(vp.x, 36)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.90, 0.75))
	add_child(sub)

	# Кнопка Sign In
	_btn_signin = Button.new()
	_btn_signin.text = "Увійти через Google"
	_btn_signin.custom_minimum_size = Vector2(320, 64)
	_btn_signin.position = Vector2((vp.x - 320) / 2.0, vp.y * 0.55)

	var s := StyleBoxFlat.new()
	s.bg_color     = Color(0.15, 0.40, 0.85, 0.95)
	s.border_color = Color(0.40, 0.65, 1.00)
	s.set_border_width_all(2)
	s.set_corner_radius_all(12)
	var sh := s.duplicate()
	sh.bg_color = Color(0.20, 0.50, 1.00, 0.95)
	_btn_signin.add_theme_stylebox_override("normal",  s)
	_btn_signin.add_theme_stylebox_override("hover",   sh)
	_btn_signin.add_theme_stylebox_override("pressed", sh)
	_btn_signin.add_theme_color_override("font_color", Color.WHITE)
	_btn_signin.add_theme_font_size_override("font_size", 22)
	_btn_signin.pressed.connect(_on_signin_pressed)
	add_child(_btn_signin)

	# Статус / помилка
	_label_status = Label.new()
	_label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_status.position = Vector2(0, vp.y * 0.55 + 80)
	_label_status.size     = Vector2(vp.x, 36)
	_label_status.add_theme_font_size_override("font_size", 16)
	_label_status.add_theme_color_override("font_color", Color(0.70, 0.80, 1.00, 0.75))
	add_child(_label_status)

func _on_signin_pressed() -> void:
	_btn_signin.disabled = true
	_label_status.text   = "Відкриваємо вікно входу..."
	firebase.sign_in_with_google()

func _on_auth_success(user_info: Dictionary) -> void:
	_label_status.text = "Вхід виконано: %s" % user_info.get("displayName", "")
	await get_tree().create_timer(0.8).timeout
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)

func _on_auth_failed(error: String) -> void:
	_btn_signin.disabled = false
	if error.is_empty():
		return
	_label_status.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_label_status.text = "Помилка: %s" % error
