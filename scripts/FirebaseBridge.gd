extends Node
class_name FirebaseBridge

signal auth_success(user_info: Dictionary)
signal auth_failed(error: String)

var _is_web: bool
var _success_cb: JavaScriptObject
var _error_cb:   JavaScriptObject

func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return
	_success_cb = JavaScriptBridge.create_callback(_on_sign_in_success)
	_error_cb   = JavaScriptBridge.create_callback(_on_sign_in_error)

func sign_in_with_google() -> void:
	if not _is_web:
		# В редакторі — симулюємо вхід для зручності розробки
		auth_success.emit({
			"uid":         "dev-user",
			"displayName": "Dev User",
			"email":       "dev@local",
			"photoURL":    ""
		})
		return
	JavaScriptBridge.get_interface("window").fbSignInWithGoogle(_success_cb, _error_cb)

func sign_out() -> void:
	if not _is_web:
		return
	JavaScriptBridge.get_interface("window").fbSignOut()

func get_current_user() -> Dictionary:
	if not _is_web:
		return {}
	var raw = JavaScriptBridge.get_interface("window").fbGetCurrentUser()
	if raw == null:
		return {}
	var result = JSON.parse_string(str(raw))
	return result if result is Dictionary else {}

func _on_sign_in_success(args: Array) -> void:
	var user_info = JSON.parse_string(str(args[0]))
	if user_info is Dictionary:
		auth_success.emit(user_info)
	else:
		auth_failed.emit("Failed to parse user info")

func _on_sign_in_error(args: Array) -> void:
	auth_failed.emit(str(args[0]))
