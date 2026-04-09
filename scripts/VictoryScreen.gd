extends Node2D
class_name VictoryScreen

const GAME_SCENE := "res://scenes/GameScreen.tscn"

var final_time:   String = "00:00"
var final_score:  int    = 0
var level_index:  int    = 0
var time_seconds: float  = 0.0

var _lb_container: VBoxContainer = null
var _pw: float = 560.0


static func _plural_baly(n: int) -> String:
	var abs_n := absi(n)
	var last2 := abs_n % 100
	var last1 := abs_n % 10
	if last2 >= 11 and last2 <= 14:
		return "%d балів" % n
	match last1:
		1: return "%d бал" % n
		2, 3, 4: return "%d бали" % n
		_: return "%d балів" % n


func _ready() -> void:
	var vp := get_viewport_rect().size
	_pw = 560.0
	var ph := 580.0

	# Фон
	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.06, 0.10, 0.97)
	overlay.size  = vp
	add_child(overlay)

	# Панель
	var panel := Panel.new()
	panel.position = Vector2((vp.x - _pw) / 2.0, (vp.y - ph) / 2.0)
	panel.size     = Vector2(_pw, ph)
	var ps := StyleBoxFlat.new()
	ps.bg_color     = Color(0.06, 0.10, 0.16, 0.98)
	ps.border_color = Color(0.30, 0.55, 0.85, 0.9)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	# Заголовок
	var title := Label.new()
	title.text = "Вітаємо!" if level_index == 0 else "Усі завдання виконано!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 28)
	title.size     = Vector2(_pw, 48)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.00))
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "Сортування завершено"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 80)
	sub.size     = Vector2(_pw, 32)
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.55, 0.70, 0.90, 0.8))
	panel.add_child(sub)

	# Час / бали
	var result_text: String
	if level_index == 0:
		result_text = "Ваш результат: " + _plural_baly(final_score)
	else:
		result_text = "Ваш час: " + final_time
	var time_lbl := Label.new()
	time_lbl.text = result_text
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_lbl.position = Vector2(0, 118)
	time_lbl.size     = Vector2(_pw, 32)
	time_lbl.add_theme_font_size_override("font_size", 22)
	time_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
	panel.add_child(time_lbl)

	# Розділювач
	var sep := ColorRect.new()
	sep.color    = Color(0.25, 0.40, 0.60, 0.4)
	sep.position = Vector2(40, 162)
	sep.size     = Vector2(_pw - 80, 1)
	panel.add_child(sep)

	# Leaderboard секція
	var lb_title := Label.new()
	lb_title.text = "Рейтинг"
	lb_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb_title.position = Vector2(0, 172)
	lb_title.size     = Vector2(_pw, 28)
	lb_title.add_theme_font_size_override("font_size", 17)
	lb_title.add_theme_color_override("font_color", Color(0.60, 0.78, 1.00, 0.85))
	panel.add_child(lb_title)

	_lb_container = VBoxContainer.new()
	_lb_container.position = Vector2(24, 204)
	_lb_container.size     = Vector2(_pw - 48, 290)
	_lb_container.add_theme_constant_override("separation", 3)
	panel.add_child(_lb_container)

	var loading_lbl := Label.new()
	loading_lbl.name = "LoadingLabel"
	loading_lbl.text = "Завантаження…"
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.add_theme_font_size_override("font_size", 15)
	loading_lbl.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7, 0.7))
	_lb_container.add_child(loading_lbl)

	# Кнопка рестарту
	var btn := Button.new()
	btn.text = "Грати знову"
	btn.custom_minimum_size = Vector2(220, 54)
	btn.position = Vector2((_pw - 220) / 2.0, ph - 70)
	var bs := StyleBoxFlat.new()
	bs.bg_color     = Color(0.10, 0.45, 0.20, 0.95)
	bs.border_color = Color(0.25, 0.80, 0.40)
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(10)
	var bsh := bs.duplicate()
	bsh.bg_color = Color(0.15, 0.60, 0.28, 0.95)
	btn.add_theme_stylebox_override("normal",   bs)
	btn.add_theme_stylebox_override("hover",    bsh)
	btn.add_theme_stylebox_override("pressed",  bsh)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_restart)
	panel.add_child(btn)

	# Запускаємо submit → по сигналу зробимо fetch
	FirebaseDB.score_submitted.connect(_on_score_submitted, CONNECT_ONE_SHOT)
	FirebaseDB.score_submit_failed.connect(_on_score_submit_failed, CONNECT_ONE_SHOT)
	FirebaseDB.submit_score(level_index, final_score, time_seconds)


func _on_score_submitted() -> void:
	FirebaseDB.leaderboard_loaded.connect(_on_leaderboard_loaded, CONNECT_ONE_SHOT)
	FirebaseDB.fetch_leaderboard(level_index)


func _on_score_submit_failed(_error: String) -> void:
	# Навіть при помилці спробуємо завантажити поточний рейтинг
	FirebaseDB.leaderboard_loaded.connect(_on_leaderboard_loaded, CONNECT_ONE_SHOT)
	FirebaseDB.fetch_leaderboard(level_index)


func _on_leaderboard_loaded(entries: Array) -> void:
	# Очищаємо "Завантаження…"
	for c in _lb_container.get_children():
		c.queue_free()

	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Рейтинг порожній"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6, 0.7))
		_lb_container.add_child(empty_lbl)
		return

	var current_uid: String = UserSession.current_user.get("uid", "")

	for i in entries.size():
		var entry: Dictionary = entries[i]
		var uid: String        = entry.get("uid", "")
		var name_str: String   = entry.get("displayName", "?")
		var is_me: bool = (uid == current_uid)

		var row := Panel.new()
		row.custom_minimum_size = Vector2(0, 26)
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.16, 0.28, 0.45, 0.75) if is_me else Color(0.08, 0.12, 0.20, 0.5)
		rs.set_corner_radius_all(4)
		row.add_theme_stylebox_override("panel", rs)
		_lb_container.add_child(row)

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (i + 1)
		rank_lbl.position = Vector2(6, 4)
		rank_lbl.add_theme_font_size_override("font_size", 13)
		rank_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if is_me else Color(0.55, 0.70, 0.90, 0.8))
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = name_str
		name_lbl.position = Vector2(44, 4)
		name_lbl.size = Vector2(330, 22)
		name_lbl.clip_text = true
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color",
			Color(1.0, 1.0, 1.0, 0.95) if is_me else Color(0.80, 0.88, 1.00, 0.85))
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		if level_index == 0:
			val_lbl.text = _plural_baly(int(entry.get("score", 0)))
		else:
			var t := int(entry.get("timeSeconds", 0))
			val_lbl.text = "%02d:%02d" % [t / 60, t % 60]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.position = Vector2(380, 4)
		val_lbl.size = Vector2(120, 22)
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.3) if is_me else Color(0.70, 0.85, 1.00, 0.85))
		row.add_child(val_lbl)


func _on_restart() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)
