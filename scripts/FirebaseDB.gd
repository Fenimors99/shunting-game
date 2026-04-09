extends Node
class_name FirebaseDB

signal score_submitted
signal score_submit_failed(error: String)
signal leaderboard_loaded(entries: Array)

var _is_web: bool
var _done_cb:       JavaScriptObject
var _err_cb:        JavaScriptObject
var _fetch_done_cb: JavaScriptObject
var _fetch_err_cb:  JavaScriptObject


func _ready() -> void:
	_is_web = OS.has_feature("web")
	if not _is_web:
		return
	_done_cb       = JavaScriptBridge.create_callback(_on_submit_done)
	_err_cb        = JavaScriptBridge.create_callback(_on_submit_error)
	_fetch_done_cb = JavaScriptBridge.create_callback(_on_fetch_done)
	_fetch_err_cb  = JavaScriptBridge.create_callback(_on_fetch_error)


func submit_score(level: int, score: int, time_seconds: float) -> void:
	if not _is_web:
		score_submitted.emit()
		return
	var u := UserSession.current_user
	JavaScriptBridge.get_interface("window").fbSubmitScore(
		u.get("uid", "anonymous"),
		u.get("displayName", "Unknown"),
		level, score, time_seconds,
		_done_cb, _err_cb
	)


func fetch_leaderboard(level: int, limit: int = 10) -> void:
	if not _is_web:
		leaderboard_loaded.emit([])
		return
	JavaScriptBridge.get_interface("window").fbFetchLeaderboard(
		level, limit, _fetch_done_cb, _fetch_err_cb
	)


func _on_submit_done(_args: Array) -> void:
	score_submitted.emit()


func _on_submit_error(args: Array) -> void:
	score_submit_failed.emit(str(args[0]) if args.size() > 0 else "unknown error")


func _on_fetch_done(args: Array) -> void:
	var raw := str(args[0]) if args.size() > 0 else "[]"
	var data = JSON.parse_string(raw)
	leaderboard_loaded.emit(data if data is Array else [])


func _on_fetch_error(_args: Array) -> void:
	leaderboard_loaded.emit([])
