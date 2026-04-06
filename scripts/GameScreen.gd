extends Node2D

@onready var queue:      WagonQueue = $Queue
@onready var station:    Node2D    = $Station
@onready var loco_depot: LocoDepot = $LocoDepot

func _ready() -> void:
	queue.position.y = Layout.QUEUE_Y
	queue.wagon_entered_track.connect(_on_wagon_entered_track)
	queue.queue_blocked.connect(_on_queue_blocked)
	queue.queue_unblocked.connect(_on_queue_unblocked)
	station.track_entry_tapped.connect(_on_track_entry_tapped)
	station.track_exit_tapped.connect(_on_track_exit_tapped)
	station.track_exit_choice.connect(_on_track_exit_choice)
	loco_depot.availability_changed.connect(station.set_loco_available)
	loco_depot.position = Layout.LOCO_DEPOT_RECT.position
	_create_start_button()

func _create_start_button() -> void:
	var btn := Button.new()
	btn.text = "СТАРТ"
	btn.custom_minimum_size = Vector2(200, 64)
	var vp := get_viewport_rect().size
	btn.position = Vector2(
		(vp.x - 200) / 2.0,
		Layout.QUEUE_Y - 82
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.55, 0.2, 0.95)
	style.border_color = Color(0.3, 0.9, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)

	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.7, 0.25, 0.95)
	style_hover.set_corner_radius_all(10)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_hover)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 28)

	btn.pressed.connect(_on_start_pressed.bind(btn))
	add_child(btn)

func _on_start_pressed(btn: Button) -> void:
	btn.queue_free()
	queue.start()

# --- Сигнали черги ---

func _on_queue_blocked(wagon: Wagon) -> void:
	station.set_entry_filter(wagon.wagon_type)

func _on_queue_unblocked() -> void:
	station.clear_entry_filter()

# --- Тап на кружечок входу колії ---

func _on_track_entry_tapped(track_index: int) -> void:
	if not queue.is_blocked():
		return
	if station.is_track_full(track_index):
		return
	var wagon := queue.get_front_wagon()
	if wagon and not Layout.is_wagon_compatible(wagon.wagon_type, track_index):
		return
	queue.resolve_block(track_index)

# --- Анімація вагона: черга → поворот вгору → поворот вправо → колія ---

func _on_wagon_entered_track(wagon: Wagon, track_index: int) -> void:
	var slot: int        = station.reserve_slot(track_index)
	var target_y: float  = station.get_track_y(track_index)
	var target_x: float  = Layout.get_slot_x(track_index, slot)
	
	# Точки маршруту згідно з вашим малюванням рейок
	var start_y = Layout.QUEUE_Y
	var junction_x = Layout.JUNCTION_X
	var bend_start_y = target_y + 20.0
	var bend_end_x = junction_x + 40.0
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR) # Поїзди рухаються лінійно від точки до точки

	# --- КРОК 1: ПОВОРОТ ВГОРУ ---
	# Вагон стоїть на junction_x, розвертається носом вгору
	tween.tween_property(wagon, "rotation", -PI/2, 0.15)
	
	# --- КРОК 2: РУХ ВГОРУ ПО ВЕРТИКАЛІ ---
	# Їдемо суворо по осі Y до точки початку згину
	var up_dist = abs(start_y - bend_start_y)
	tween.tween_property(wagon, "position:y", bend_start_y, up_dist / Layout.SPEED)
	
	# --- КРОК 3: ПОВОРОТ НА ДІАГОНАЛЬ ---
	# Повертаємо на 45 градусів (PI/4)
	tween.tween_property(wagon, "rotation", -PI/4, 0.1)
	
	# --- КРОК 4: РУХ ПО ДІАГОНАЛІ (ФІКСОВАНА ШВИДКІСТЬ) ---
	var diag_end = Vector2(bend_end_x, target_y)
	
	# Оскільки згин завжди від (Junction, Y+20) до (Junction+40, Y),
	# ми можемо точно вирахувати довжину гіпотенузи: sqrt(20^2 + 40^2) ≈ 44.7
	var fixed_diag_dist = 44.7
	
	# Використовуємо стабільну швидкість (наприклад, 700 пікселів/сек)
	# незалежно від того, яка це колія
	var constant_diag_speed = Layout.SPEED * 0.7 
	tween.tween_property(wagon, "position", diag_end, fixed_diag_dist / constant_diag_speed)
	
	# --- КРОК 5: ПОВОРОТ ГОРИЗОНТАЛЬНО ---
	# Вирівнюємо вагон для заїзду на станцію
	tween.tween_property(wagon, "rotation", 0.0, 0.1)
	
	# --- КРОК 6: РУХ ПО КОЛІЇ ПРЯМО ---
	# Їдемо до призначеного слота суворо по X
	var final_dist = abs(bend_end_x - target_x)
	tween.tween_property(wagon, "position:x", target_x, final_dist / Layout.SPEED)
	
	tween.tween_callback(func(): _wagon_arrived(wagon, track_index, slot))
	
func _move_wagon_to_station(wagon: Wagon, track_idx: int) -> void:
	# Отримуємо динамічний X для цієї колії
	var stop_x := Layout.get_track_stop_x(track_idx)
	var target_pos := Vector2(stop_x, Layout.get_track_y(track_idx))
	
	var tween := create_tween()
	var dist := wagon.position.distance_to(target_pos)
	
	# Рух до нової точки зупинки
	tween.tween_property(wagon, "position", target_pos, dist / Layout.SPEED)
	
	# Якщо у вас є поворот при заїзді, не забудьте його залишити
	tween.parallel().tween_property(wagon, "rotation", 1.5 * PI, 0.3)

func _wagon_arrived(wagon: Wagon, track_index: int, slot: int) -> void:
	station.place_wagon(wagon, track_index, slot)

# --- Виїзд з колії ---

func _on_track_exit_tapped(track_index: int) -> void:
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	match track_index:
		1: _animate_exit(wagons, Layout.EXIT_LOADING_POS)
		7: _animate_exit(wagons, Layout.EXIT_REPAIR_POS)

func _on_track_exit_choice(track_index: int, submit: bool) -> void:
	if not loco_depot.use_locomotive():
		return
	var wagons: Array = station.pop_all_wagons(track_index)
	if submit:
		_animate_exit(wagons, Layout.EXIT_SUBMIT_POS)
	else:
		_return_to_queue(wagons)

# wagons виїжджають правіше, потім зникають за екраном
func _animate_exit(wagons: Array, dest: Vector2) -> void:
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var delay := i * 0.12
		var dist := wagon.position.distance_to(dest)
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(wagon, "position", dest, dist / Layout.SPEED)
		tween.tween_callback(wagon.queue_free)

# wagons повертаються в хвіст черги
func _return_to_queue(wagons: Array) -> void:
	var base_x := queue.get_tail_global_x() + Layout.WAGON_GAP
	for i in wagons.size():
		var wagon: Wagon = wagons[i]
		var dest := Vector2(base_x + i * Layout.WAGON_GAP, Layout.QUEUE_Y)
		var tween := create_tween()
		# --- МИ ВИДАЛИЛИ tween_property для rotation тут ---
		var dist := wagon.position.distance_to(dest)
		# Вагон просто їде до черги (наприклад, задом наперед)
		tween.tween_property(wagon, "position", dest, dist / Layout.SPEED)
		
		tween.tween_callback(func(): 
			# МИТТЄВО встановлюємо PI (ліворуч) без анімації,
			# щоб підготувати вагон до наступного виїзду
			wagon.rotation = PI
			queue.receive_wagon(wagon)
			)
			
