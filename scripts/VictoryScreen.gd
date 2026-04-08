extends Node2D
class_name VictoryScreen

const GAME_SCENE := "res://scenes/GameScreen.tscn"
# Ось цей рядок обов'язковий:
var final_time: String = "00:00"

func _ready() -> void:
	var vp := get_viewport_rect().size

	# Затемнення фону
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.06, 0.10, 0.97)
	overlay.size  = vp
	add_child(overlay)
	
	# Панель по центру
	var pw := 520.0
	var ph := 320.0
	var panel := Panel.new()
	panel.position = Vector2((vp.x - pw) / 2.0, (vp.y - ph) / 2.0)
	panel.size     = Vector2(pw, ph)
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.10, 0.16, 0.98)
	ps.border_color = Color(0.30, 0.55, 0.85, 0.9)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Заголовок
	var title := Label.new()
	title.text = "Усі завдання виконано!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 52)
	title.size     = Vector2(pw, 48)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.00))
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "Сортування завершено"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 108)
	sub.size     = Vector2(pw, 32)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.90, 0.8))
	panel.add_child(sub)

	var center_time_label := Label.new()
	center_time_label.text = "Ваш час: " + final_time
	center_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_time_label.position = Vector2(0, 140) 
	center_time_label.size = Vector2(pw, 32) # Тепер pw доступна!
	center_time_label.add_theme_font_size_override("font_size", 22)
	center_time_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	
	# Додаємо саме до panel, яка оголошена вище в цій же функції
	panel.add_child(center_time_label)

	# Роздільник
	var sep := ColorRect.new()
	sep.color    = Color(0.25, 0.40, 0.60, 0.4)
	sep.position = Vector2(40, 180)
	sep.size     = Vector2(pw - 80, 1)
	panel.add_child(sep)

	# Кнопка рестарту
	var btn := Button.new()
	btn.text = "Грати знову"
	btn.custom_minimum_size = Vector2(220, 60)
	btn.position = Vector2((pw - 220) / 2.0, 210)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.10, 0.45, 0.20, 0.95)
	bs.border_color = Color(0.25, 0.80, 0.40)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(10)
	var bsh := bs.duplicate()
	bsh.bg_color = Color(0.15, 0.60, 0.28, 0.95)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover",  bsh)
	btn.add_theme_stylebox_override("pressed", bsh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(_on_restart)
	panel.add_child(btn)

func _on_restart() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
