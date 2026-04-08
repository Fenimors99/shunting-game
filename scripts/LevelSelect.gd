extends Node2D
class_name LevelSelectScreen

const GAME_SCENE := "res://scenes/GameScreen.tscn"

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# 0. ОЧИЩЕННЯ
	for child in get_children():
		child.queue_free()
	
	var vp := get_viewport_rect().size

	# 1. ФОН
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.12, 1.0)
	bg.size = vp
	add_child(bg)

	# 2. ЗАГОЛОВОК
	var title := Label.new()
	title.text = "Виберіть режим гри"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 60)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.85, 0.93, 1.00))
	add_child(title)

	# 3. КОНТЕЙНЕР ДЛЯ ЦЕНТРУВАННЯ (ОНОВЛЕНО)
	# Цей вузол автоматично триматиме сітку в центрі екрана
	var center_node := CenterContainer.new()
	center_node.size = vp 
	center_node.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	add_child(center_node)

	var grid := GridContainer.new()
	grid.columns = 2 
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)
	
	# Додаємо сітку в CenterContainer, а не напряму в add_child
	center_node.add_child(grid)

	# 4. СТВОРЮЄМО 3 ЗВИЧАЙНІ РІВНІ
	var blue_color = Color(0.15, 0.40, 0.85)
	for i in range(1, 4):
		var btn = _create_level_button(str(i), i, blue_color)
		grid.add_child(btn)

	# 5. СТВОРЮЄМО БЕЗКІНЕЧНИЙ РІВЕНЬ
	var purple_color = Color(0.60, 0.20, 0.70)
	var infinite_btn = _create_level_button("∞", 0, purple_color)
	grid.add_child(infinite_btn)

func _create_level_button(txt: String, level_id: int, base_color: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(95, 95)
	
	# СТИЛІЗАЦІЯ
	var s := StyleBoxFlat.new()
	s.bg_color = base_color
	s.set_border_width_all(2)
	s.border_color = base_color.lightened(0.3)
	s.set_corner_radius_all(15)
	
	var sh := s.duplicate()
	sh.bg_color = base_color.lightened(0.1)
	
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_font_size_override("font_size", 46)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	# ПІДКЛЮЧЕННЯ СИГНАЛУ
	# Використовуємо level_id, щоб знати, який рівень запускати
	btn.pressed.connect(func(): _on_level_selected(level_id))
	
	return btn

func _on_level_selected(level_num: int) -> void:
	print("Обрано рівень: ", level_num)
	# Тут можна передати номер рівня в GameScreen перед зміною сцени
	get_tree().change_scene_to_file(GAME_SCENE)
