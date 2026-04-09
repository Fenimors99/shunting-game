extends Node2D
class_name LevelSelectScreen

const GAME_SCENE := "res://scenes/GameScreen.tscn"

var _lb_overlay: Control = null
var _lb_list: VBoxContainer = null
var _lb_active_level: int = 0
var _lb_tab_btns: Array = []


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var vp := get_viewport_rect().size

	# Фон
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.07, 0.12, 1.0)
	bg.size = vp
	add_child(bg)

	# Заголовок
	var title := Label.new()
	title.text = "Виберіть режим гри"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 80)
	title.size = Vector2(vp.x, 60)
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.85, 0.93, 1.00))
	add_child(title)

	# Грид рівнів
	var center_node := CenterContainer.new()
	center_node.size = vp
	center_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_node)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 30)
	center_node.add_child(grid)

	var blue_color := Color(0.15, 0.40, 0.85)
	for i in range(1, 4):
		grid.add_child(_create_level_button(str(i), i, blue_color))

	var purple_color := Color(0.60, 0.20, 0.70)
	grid.add_child(_create_level_button("∞", 0, purple_color))

	# Ім'я користувача — правий верхній кут
	var user_name: String = UserSession.current_user.get("displayName", "")
	if not user_name.is_empty():
		var user_lbl := Label.new()
		user_lbl.text = user_name
		user_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		user_lbl.position = Vector2(vp.x - 300 - 20, 20)
		user_lbl.size     = Vector2(300, 36)
		user_lbl.add_theme_font_size_override("font_size", 18)
		user_lbl.add_theme_color_override("font_color", Color(0.65, 0.78, 1.00, 0.85))
		add_child(user_lbl)

	# Кнопка рейтингу — знизу по центру
	var lb_btn := Button.new()
	lb_btn.text = "Рейтинг"
	lb_btn.custom_minimum_size = Vector2(220, 58)
	lb_btn.position = Vector2((vp.x - 220) / 2.0, vp.y - 110)
	var lbs := StyleBoxFlat.new()
	lbs.bg_color     = Color(0.08, 0.14, 0.26, 0.95)
	lbs.border_color = Color(0.30, 0.55, 0.85, 0.85)
	lbs.set_border_width_all(2)
	lbs.set_corner_radius_all(12)
	var lbsh := lbs.duplicate()
	lbsh.bg_color = Color(0.12, 0.22, 0.40, 0.95)
	lb_btn.add_theme_stylebox_override("normal",  lbs)
	lb_btn.add_theme_stylebox_override("hover",   lbsh)
	lb_btn.add_theme_stylebox_override("pressed", lbsh)
	lb_btn.add_theme_font_size_override("font_size", 22)
	lb_btn.add_theme_color_override("font_color", Color(0.75, 0.88, 1.00))
	lb_btn.pressed.connect(_on_leaderboard_pressed)
	add_child(lb_btn)


func _create_level_button(txt: String, level_id: int, base_color: Color) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(95, 95)
	var s := StyleBoxFlat.new()
	s.bg_color = base_color
	s.set_border_width_all(2)
	s.border_color = base_color.lightened(0.3)
	s.set_corner_radius_all(15)
	var sh := s.duplicate()
	sh.bg_color = base_color.lightened(0.1)
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_font_size_override("font_size", 46)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.pressed.connect(func(): _on_level_selected(level_id))
	return btn


func _on_level_selected(level_num: int) -> void:
	LevelConfig.current_level = level_num
	get_tree().change_scene_to_file(GAME_SCENE)


# --- Leaderboard overlay ---

func _on_leaderboard_pressed() -> void:
	if _lb_overlay != null:
		return
	var vp := get_viewport_rect().size

	# Затемнення
	_lb_overlay = ColorRect.new()
	(_lb_overlay as ColorRect).color = Color(0.0, 0.0, 0.0, 0.70)
	(_lb_overlay as ColorRect).size  = vp
	_lb_overlay.set_script(null)
	add_child(_lb_overlay)

	# Закриття по кліку на тло
	var click_area := Button.new()
	click_area.flat = true
	click_area.custom_minimum_size = vp
	click_area.position = Vector2.ZERO
	click_area.pressed.connect(_close_leaderboard)
	_lb_overlay.add_child(click_area)

	# Панель
	var pw := 500.0
	var ph := 580.0
	var panel := Panel.new()
	panel.size     = Vector2(pw, ph)
	panel.position = (vp - panel.size) / 2.0
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.10, 0.16, 0.99)
	ps.border_color = Color(0.30, 0.55, 0.85, 0.9)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	_lb_overlay.add_child(panel)

	# Заголовок
	var title := Label.new()
	title.text = "Рейтинг"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 24)
	title.size     = Vector2(pw, 40)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.93, 1.00))
	panel.add_child(title)

	# Вкладки рівнів
	var tabs_row := HBoxContainer.new()
	tabs_row.position = Vector2(24, 74)
	tabs_row.size     = Vector2(pw - 48, 44)
	tabs_row.add_theme_constant_override("separation", 8)
	panel.add_child(tabs_row)

	_lb_tab_btns.clear()
	var tab_labels := ["1", "2", "3", "∞"]
	var tab_levels := [1, 2, 3, 0]
	for i in tab_labels.size():
		var tb := _create_tab_button(tab_labels[i], tab_levels[i])
		tabs_row.add_child(tb)
		_lb_tab_btns.append(tb)

	# Розділювач
	var sep := ColorRect.new()
	sep.color    = Color(0.25, 0.40, 0.60, 0.4)
	sep.position = Vector2(24, 126)
	sep.size     = Vector2(pw - 48, 1)
	panel.add_child(sep)

	# Список
	_lb_list = VBoxContainer.new()
	_lb_list.position = Vector2(24, 136)
	_lb_list.size     = Vector2(pw - 48, 390)
	_lb_list.add_theme_constant_override("separation", 4)
	panel.add_child(_lb_list)

	# Кнопка закрити
	var close_btn := Button.new()
	close_btn.text = "Закрити"
	close_btn.custom_minimum_size = Vector2(160, 46)
	close_btn.position = Vector2((pw - 160) / 2.0, ph - 58)
	var cs := StyleBoxFlat.new()
	cs.bg_color     = Color(0.10, 0.18, 0.30, 0.95)
	cs.border_color = Color(0.30, 0.50, 0.75)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(8)
	var csh := cs.duplicate()
	csh.bg_color = Color(0.15, 0.26, 0.44, 0.95)
	close_btn.add_theme_stylebox_override("normal",  cs)
	close_btn.add_theme_stylebox_override("hover",   csh)
	close_btn.add_theme_stylebox_override("pressed", csh)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.add_theme_color_override("font_color", Color(0.75, 0.88, 1.00))
	close_btn.pressed.connect(_close_leaderboard)
	panel.add_child(close_btn)

	# Завантажуємо перший таб (рівень 1)
	_switch_tab(1)


func _create_tab_button(txt: String, level_id: int) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(80, 40)
	btn.pressed.connect(func(): _switch_tab(level_id))
	return btn


func _switch_tab(level: int) -> void:
	_lb_active_level = level
	_refresh_tab_styles()
	_show_loading()
	FirebaseDB.leaderboard_loaded.connect(_on_leaderboard_loaded, CONNECT_ONE_SHOT)
	FirebaseDB.fetch_leaderboard(level)


func _refresh_tab_styles() -> void:
	var tab_levels := [1, 2, 3, 0]
	for i in _lb_tab_btns.size():
		var btn: Button = _lb_tab_btns[i]
		var active: bool = (tab_levels[i] == _lb_active_level)
		var s := StyleBoxFlat.new()
		s.bg_color     = Color(0.20, 0.38, 0.70) if active else Color(0.08, 0.13, 0.22)
		s.border_color = Color(0.40, 0.65, 1.00) if active else Color(0.20, 0.32, 0.50)
		s.set_border_width_all(1)
		s.set_corner_radius_all(8)
		btn.add_theme_stylebox_override("normal",  s)
		btn.add_theme_stylebox_override("hover",   s)
		btn.add_theme_stylebox_override("pressed", s)
		btn.add_theme_font_size_override("font_size", 18)
		btn.add_theme_color_override("font_color", Color.WHITE if active else Color(0.60, 0.75, 0.95))


func _show_loading() -> void:
	for c in _lb_list.get_children():
		c.queue_free()
	var lbl := Label.new()
	lbl.text = "Завантаження…"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.7))
	_lb_list.add_child(lbl)


func _on_leaderboard_loaded(entries: Array) -> void:
	if _lb_list == null:
		return
	for c in _lb_list.get_children():
		c.queue_free()

	if entries.is_empty():
		var lbl := Label.new()
		lbl.text = "Ще немає результатів"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
		_lb_list.add_child(lbl)
		return

	var current_uid: String = UserSession.current_user.get("uid", "")

	for i in entries.size():
		var entry: Dictionary = entries[i]
		var uid: String        = entry.get("uid", "")
		var is_me: bool        = (uid == current_uid)

		var row := Panel.new()
		row.custom_minimum_size = Vector2(0, 30)
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.16, 0.28, 0.45, 0.75) if is_me else Color(0.08, 0.12, 0.20, 0.5)
		rs.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", rs)
		_lb_list.add_child(row)

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (i + 1)
		rank_lbl.position = Vector2(6, 6)
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if is_me else Color(0.55, 0.70, 0.90, 0.8))
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = entry.get("displayName", "?")
		name_lbl.position = Vector2(48, 6)
		name_lbl.size = Vector2(300, 22)
		name_lbl.clip_text = true
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color",
			Color(1.0, 1.0, 1.0) if is_me else Color(0.80, 0.88, 1.00, 0.85))
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		if _lb_active_level == 0:
			val_lbl.text = "%d балів" % int(entry.get("score", 0))
		else:
			var t := int(entry.get("timeSeconds", 0))
			val_lbl.text = "%02d:%02d" % [t / 60, t % 60]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.position = Vector2(352, 6)
		val_lbl.size     = Vector2(96, 22)
		val_lbl.add_theme_font_size_override("font_size", 14)
		val_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if is_me else Color(0.70, 0.85, 1.00, 0.85))
		row.add_child(val_lbl)


func _close_leaderboard() -> void:
	if _lb_overlay != null:
		_lb_overlay.queue_free()
		_lb_overlay = null
		_lb_list = null
		_lb_tab_btns.clear()
