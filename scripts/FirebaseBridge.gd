extends Node
class_name FirebaseBridge

signal auth_success(user_info: Dictionary)
signal auth_failed(error: String)

var _is_web: bool
var _error_cb: JavaScriptObject

func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return
	_error_cb = JavaScriptBridge.create_callback(_on_sign_in_error)
	# Wait one frame so parent LoginScreen._ready() connects signals first
	await get_tree().process_frame
	_poll_redirect()

func _poll_redirect() -> void:
	var result = str(JavaScriptBridge.get_interface("window").fbCheckRedirect())
	if result == "pending":
		await get_tree().create_timer(0.2).timeout
		_poll_redirect()
	elif result != "none":
		if result.begins_with("error:"):
			auth_failed.emit(result.substr(6))
		else:
			var user_info = JSON.parse_string(result)
			if user_info is Dictionary:
				auth_success.emit(user_info)

func sign_in_with_google() -> void:
	if not _is_web:
		auth_success.emit({
			"uid":         "dev-user",
			"displayName": "Dev User",
			"email":       "dev@local",
			"photoURL":    ""
		})
		return
	# If already signed in (redirect result missed by timing), emit success directly
	var current = get_current_user()
	if not current.is_empty():
		auth_success.emit(current)
		return
	JavaScriptBridge.get_interface("window").fbSignInWithGoogle(_error_cb)
	_poll_redirect()

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

func _on_sign_in_error(args: Array) -> void:
	auth_failed.emit(str(args[0]))
