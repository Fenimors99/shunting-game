extends Area2D
class_name Wagon

enum State { IDLE, SELECTED, ASSIGNED, BLOCKED }

const WAGON_COLORS := {
	"red":    Color(0.85, 0.25, 0.25),
	"blue":   Color(0.25, 0.50, 0.90),
	"green":  Color(0.20, 0.75, 0.35),
	"yellow": Color(0.95, 0.80, 0.15),
	"purple": Color(0.65, 0.25, 0.85),
}

signal tapped(wagon: Wagon)

@export var wagon_color: String = "red"

var state: State = State.IDLE
var assigned_track: int = -1

@onready var _body: ColorRect = $Body
@onready var _label: Label = $Label
@onready var _blink_timer: Timer = $BlinkTimer

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	_blink_timer.timeout.connect(_on_blink_timeout)
	_refresh()

# --- Публічний API ---

func select() -> void:
	state = State.SELECTED
	_refresh()

func deselect() -> void:
	state = State.ASSIGNED if assigned_track != -1 else State.IDLE
	_refresh()

func assign(track_index: int) -> void:
	assigned_track = track_index
	state = State.ASSIGNED
	_refresh()

func deassign() -> void:
	assigned_track = -1
	state = State.IDLE
	_refresh()

func start_blocking() -> void:
	state = State.BLOCKED
	_blink_timer.start()
	_refresh()

func stop_blocking() -> void:
	_blink_timer.stop()
	_body.visible = true
	state = State.IDLE
	_refresh()

# --- Внутрішнє ---

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tapped.emit(self)
	elif event is InputEventScreenTouch and event.pressed:
		tapped.emit(self)

func _on_blink_timeout() -> void:
	_body.visible = !_body.visible

func _refresh() -> void:
	_body.visible = true
	_body.color = WAGON_COLORS.get(wagon_color, Color.GRAY)
	match state:
		State.IDLE:
			_body.modulate = Color.WHITE
			_label.text = ""
		State.SELECTED:
			_body.modulate = Color(1.4, 1.4, 0.5)
			_label.text = ""
		State.ASSIGNED:
			_body.modulate = Color.WHITE
			_label.text = str(assigned_track)
		State.BLOCKED:
			_body.color = Color(0.9, 0.15, 0.15)
			_label.text = "!"
