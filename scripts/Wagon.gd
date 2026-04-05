extends Area2D
class_name Wagon

enum State { IDLE, BLOCKED }

const WAGON_COLORS := {
	"red":    Color(0.85, 0.25, 0.25),
	"blue":   Color(0.25, 0.50, 0.90),
	"green":  Color(0.20, 0.75, 0.35),
	"yellow": Color(0.95, 0.80, 0.15),
	"purple": Color(0.65, 0.25, 0.85),
}

const _HALF_W := 50.0
const _HALF_H := 31.0

@export var wagon_color: String = "red"

var state: State = State.IDLE

@onready var _shadow: ColorRect = $Shadow
@onready var _body: ColorRect = $Body
@onready var _label: Label = $Label
@onready var _blink_timer: Timer = $BlinkTimer

func _ready() -> void:
	_blink_timer.timeout.connect(_on_blink_timeout)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", 22)
	_refresh()

# --- Публічний API ---

func start_blocking() -> void:
	state = State.BLOCKED
	_shadow.color = Color(0.9, 0.15, 0.15, 0.85)
	_blink_timer.start()
	_refresh()

func stop_blocking() -> void:
	_blink_timer.stop()
	_shadow.visible = false
	state = State.IDLE
	_refresh()

# --- Внутрішнє ---

func _on_blink_timeout() -> void:
	_shadow.visible = !_shadow.visible

func _refresh() -> void:
	_body.color = WAGON_COLORS.get(wagon_color, Color.GRAY)
	_body.modulate = Color.WHITE
	match state:
		State.IDLE:
			_shadow.visible = false
			_label.text = ""
		State.BLOCKED:
			_label.text = "!"
