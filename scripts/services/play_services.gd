extends Node
## Native Play Games adapter. Missing configuration never gates a run or local save.

signal status_changed(message: String)
signal local_leaderboards_requested
signal local_achievements_requested

const CONFIG_PATH := "res://config/play_services.json"
const VENDOR := "res://addons/GodotPlayGameServices/scripts/"
const MAX_CONFLICT_ATTEMPTS := 10

var status := "Local play"
var configuration: Dictionary = {}
var _store: Node
var _native: Object
var _sign_in: Node
var _achievements: Node
var _leaderboards: Node
var _snapshots: Node
var _players: Node
var _authenticated := false
var _account_ready := false
var _account_mismatch := false
var _auth_pending := false
var _auth_deadline := 0.0
var _operation := ""
var _operation_deadline := 0.0
var _cloud_suspended := false
var _dirty := false
var _debounce_until := 0.0
var _ignore_store_change := false
var _write_nonce := ""
var _write_revision := 0
var _conflict_attempts := 0
var _verify_after := 0.0
var _queued_ui := ""
var _scores_inflight: Dictionary = {}
var _score_blocked: Dictionary = {}
var _achievements_inflight: Dictionary = {}
var _achievement_sent: Dictionary = {}

func _ready() -> void:
	if _store == null:
		_store = get_node_or_null("/root/SaveData")
	if _store != null:
		_store.profile_changed.connect(_on_profile_changed)
	if configuration.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			configuration = parsed
	_initialize_native()

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _timeout() -> float:
	var value: Variant = configuration.get("timeout_seconds", 15)
	return clampf(float(value), 5.0, 60.0) if value is int or value is float else 15.0

func _set_status(message: String) -> void:
	if status != message:
		status = message
		status_changed.emit(status)

func _configured() -> bool:
	var game_id: Variant = configuration.get("game_id", "")
	return configuration.get("enabled", false) == true and game_id is String \
		and game_id.is_valid_int() and int(game_id) > 0

func _initialize_native() -> void:
	if _store != null and _store.storage_read_only:
		_set_status("Newer progress preserved · Cloud sync paused")
		return
	if not _configured():
		_set_status("Local play")
		return
	if OS.get_name() != "Android" or not Engine.has_singleton("GodotPlayGameServices"):
		_set_status("Local play · Google Play unavailable")
		return
	var wrapper := get_node_or_null("/root/GodotPlayGameServices")
	if wrapper == null:
		_set_status("Local play · Google Play unavailable")
		return
	# Initialize before adding clients; vendor clients wire signals during their _ready().
	if wrapper.android_plugin == null:
		if wrapper.initialize() != 0:
			_set_status("Local play · Google Play unavailable")
			return
	_native = wrapper.android_plugin
	_sign_in = _client("sign_in/sign_in_client.gd")
	_achievements = _client("achievements/achievements_client.gd")
	_leaderboards = _client("leaderboards/leaderboards_client.gd")
	_snapshots = _client("snapshots/snapshots_client.gd")
	_players = _client("players/players_client.gd")
	_sign_in.user_authenticated.connect(_on_authenticated)
	_players.current_player_loaded.connect(_on_player_loaded)
	_achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	_leaderboards.score_submitted.connect(_on_score_submitted)
	_snapshots.game_loaded.connect(_on_game_loaded)
	if _snapshots.has_signal("game_load_failed"):
		_snapshots.connect("game_load_failed", _on_game_load_failed)
	_snapshots.game_saved.connect(_on_game_saved)
	_snapshots.conflict_emitted.connect(_on_conflict)
	_auth_pending = true
	_auth_deadline = _now() + _timeout()
	_set_status("Connecting to Google Play…")
	_sign_in.is_authenticated()

func _client(path: String) -> Node:
	var client: Node = load(VENDOR + path).new()
	add_child(client)
	return client

func is_available() -> bool:
	return _native != null

func is_authenticated() -> bool:
	return _authenticated and _account_ready and not _account_mismatch \
		and _store != null and not _store.storage_read_only

func _on_authenticated(authenticated: bool) -> void:
	if not _auth_pending:
		return
	_auth_pending = false
	_authenticated = authenticated
	if not authenticated:
		_set_status("Local play · Sign in for cloud scores")
		if _queued_ui == "scores":
			local_leaderboards_requested.emit()
		elif _queued_ui == "achievements":
			local_achievements_requested.emit()
		_queued_ui = ""
		return
	_auth_pending = true
	_auth_deadline = _now() + _timeout()
	_players.load_current_player(false)

func _on_player_loaded(player: Variant) -> void:
	if not _auth_pending or not _authenticated or _store == null:
		return
	_auth_pending = false
	if player == null or player.player_id.is_empty():
		_set_status("Local play · Could not check Google account")
		return
	var bound_id: String = _store.profile.cloud.player_id
	if not bound_id.is_empty() and bound_id != player.player_id:
		_account_mismatch = true
		_set_status("Account changed · Progress kept on this device")
		return
	_account_ready = true
	if bound_id.is_empty():
		_store.profile.cloud.player_id = player.player_id
		_persist_without_sync()
	_set_status("Google Play connected")
	_flush_scores()
	_flush_achievements()
	sync_profile()
	_open_queued_ui()

func _request_sign_in(ui: String) -> void:
	_queued_ui = ui
	if _auth_pending:
		return
	_auth_pending = true
	_auth_deadline = _now() + _timeout()
	_set_status("Signing in to Google Play…")
	_sign_in.sign_in()

func show_leaderboards() -> bool:
	if not is_available():
		local_leaderboards_requested.emit()
		return false
	if not _authenticated:
		_request_sign_in("scores")
		return true
	_leaderboards.show_all_leaderboards()
	return true

func show_achievements() -> bool:
	if not is_available():
		local_achievements_requested.emit()
		return false
	if not _authenticated:
		_request_sign_in("achievements")
		return true
	_achievements.show_achievements()
	return true

func _open_queued_ui() -> void:
	var ui := _queued_ui
	_queued_ui = ""
	if ui == "scores":
		_leaderboards.show_all_leaderboards()
	elif ui == "achievements":
		_achievements.show_achievements()

func _id(group: String, key: String) -> String:
	var ids: Variant = configuration.get(group, {})
	if not ids is Dictionary:
		return ""
	var value: Variant = ids.get(key, "")
	return value if value is String and value.length() <= 128 else ""

## SaveData.add_run must be called once by gameplay before this method.
func submit_run(_run: Dictionary) -> void:
	_dirty = true
	_debounce_until = _now() + 1.0
	if is_authenticated():
		_flush_scores()
		_flush_achievements()

func _on_profile_changed() -> void:
	if _ignore_store_change:
		return
	_dirty = true
	_debounce_until = _now() + 1.0

func _persist_without_sync() -> void:
	_ignore_store_change = true
	_store.save_profile()
	_ignore_store_change = false

func _challenge_date() -> String:
	# Daily gameplay seeds use UTC, so optional cloud scores must select the same date.
	return Time.get_date_string_from_system(true)

func _flush_scores() -> void:
	if not is_authenticated() or _store == null:
		return
	var pending: Dictionary = _store.profile.cloud.pending_scores.duplicate()
	var today := _challenge_date()
	if _store.profile.daily_best.has(today):
		pending.daily_score = _store.profile.daily_best[today]
	for key: String in pending:
		var board_id := _id("leaderboards", key)
		if board_id.is_empty() or _scores_inflight.has(board_id) or _score_blocked.has(board_id):
			continue
		var value := int(pending[key])
		if value <= 0:
			continue
		_scores_inflight[board_id] = {"key": key, "value": value, "deadline": _now() + _timeout()}
		_leaderboards.submit_score(board_id, value)

func _on_score_submitted(success: bool, board_id: String) -> void:
	if not _scores_inflight.has(board_id) or _store == null:
		return
	var request: Dictionary = _scores_inflight[board_id]
	_scores_inflight.erase(board_id)
	if success:
		var pending: Dictionary = _store.profile.cloud.pending_scores
		if int(pending.get(request.key, 0)) <= request.value:
			pending.erase(request.key)
		_persist_without_sync()
	else:
		_score_blocked[board_id] = true
		_set_status("Cloud scores waiting · Progress saved here")

func _incremental_progress(key: String) -> int:
	match key:
		"century", "thousand_kills": return int(_store.profile.total_kills)
		"ten_runs": return int(_store.profile.total_runs)
		"collector": return _store.profile.discovered.size()
	return 0

func _flush_achievements() -> void:
	if not is_authenticated() or _store == null:
		return
	var incremental: Variant = configuration.get("incremental_achievements", {})
	if not incremental is Dictionary:
		incremental = {}
	for key: String in _store.ACHIEVEMENTS:
		var achievement_id := _id("achievements", key)
		if achievement_id.is_empty() or _achievements_inflight.has(achievement_id):
			continue
		var unlocked: bool = _store.profile.achievements.has(key)
		var progress := _incremental_progress(key) if incremental.has(key) else (1 if unlocked else 0)
		if progress <= 0 or int(_achievement_sent.get(achievement_id, 0)) >= progress:
			continue
		_achievements_inflight[achievement_id] = {"key": key, "progress": progress,
			"unlocked": unlocked, "deadline": _now() + _timeout()}
		if incremental.has(key):
			_achievements.set_achievement_steps(achievement_id, progress)
		else:
			_achievements.unlock_achievement(achievement_id)

func _on_achievement_unlocked(unlocked: bool, achievement_id: String) -> void:
	if not _achievements_inflight.has(achievement_id) or _store == null:
		return
	var request: Dictionary = _achievements_inflight[achievement_id]
	_achievements_inflight.erase(achievement_id)
	_achievement_sent[achievement_id] = request.progress
	# False is also emitted for an incremental goal that has not reached its target.
	if unlocked:
		_store.profile.cloud.pending_achievements.erase(request.key)
		_persist_without_sync()

func _save_name() -> String:
	var value: Variant = configuration.get("save_name", "infiniteslash_profile_v1")
	if not value is String or value.is_empty() or value.length() > 100:
		return "infiniteslash_profile_v1"
	for character: String in value:
		if character not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~":
			return "infiniteslash_profile_v1"
	return value

func sync_profile() -> void:
	if not is_authenticated() or _store == null:
		return
	if _cloud_suspended:
		_set_status("Cloud sync paused · Progress saved here")
		return
	if not _operation.is_empty():
		_dirty = true
		return
	_dirty = false
	_conflict_attempts = 0
	_operation = "load"
	_operation_deadline = _now() + _timeout()
	_set_status("Checking cloud progress…")
	_snapshots.load_game(_save_name(), false)

func _parse_snapshot(snapshot: Variant) -> Dictionary:
	if snapshot == null or snapshot.content.size() > _store.MAX_FILE_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(snapshot.content.get_string_from_utf8()) != OK:
		return {}
	var parsed: Variant = parser.data
	return parsed if parsed is Dictionary else {}

func _on_game_loaded(snapshot: Variant) -> void:
	if _operation not in ["load", "verify"] or _cloud_suspended:
		return
	var remote := _parse_snapshot(snapshot)
	if _operation == "verify":
		if remote.get("sync_nonce", "") == _write_nonce and snapshot != null:
			if snapshot.metadata != null and snapshot.metadata.has_change_pending:
				_suspend_cloud("Cloud upload pending · Progress saved here")
				return
			_store.profile.cloud.last_verified_revision = _write_revision
			_persist_without_sync()
			_operation = ""
			_set_status("Cloud save checked")
			return
		_suspend_cloud("Cloud verification waiting · Progress saved here")
		return
	if snapshot != null and not _store.is_cloud_profile_valid(remote):
		_suspend_cloud("Cloud save needs a newer version · Local progress preserved")
		return
	if not remote.is_empty():
		_ignore_store_change = true
		_store.merge_cloud_profile(remote)
		_ignore_store_change = false
	_begin_save()

func _on_game_load_failed(name: String, _message: String) -> void:
	if name != _save_name() or _operation.is_empty() or _cloud_suspended:
		return
	# A read/open failure is never an absent save: do not create or overwrite remote progress.
	_suspend_cloud("Cloud load waiting · Progress saved here")

func _begin_save() -> void:
	_operation = "save"
	_operation_deadline = _now() + _timeout()
	var payload := _cloud_write_bytes()
	_set_status("Saving cloud progress…")
	_snapshots.save_game(_save_name(), "InfiniteSlash · %s points" % str(_store.profile.best_score),
		payload, int(_store.profile.total_played_seconds * 1000), int(_store.profile.total_kills))

func _cloud_write_bytes() -> PackedByteArray:
	_write_revision = int(_store.profile.revision)
	_write_nonce = Crypto.new().generate_random_bytes(16).hex_encode()
	var payload: Dictionary = _store.cloud_profile()
	payload.sync_nonce = _write_nonce
	return JSON.stringify(payload).to_utf8_buffer()

func _on_game_saved(success: bool, name: String, _description: String) -> void:
	if _operation != "save" or name != _save_name() or _cloud_suspended:
		return
	if not success:
		_suspend_cloud("Cloud save waiting · Progress saved here")
		return
	# Our native fork waits for commit; readback also checks offline pending state and payload identity.
	_operation = "verify_wait"
	_verify_after = _now() + 1.0
	_operation_deadline = _now() + _timeout()
	_set_status("Checking cloud save…")

func _on_conflict(conflict: Variant) -> void:
	if _operation.is_empty() or _cloud_suspended or _store == null or conflict == null:
		return
	var invalid_profile := false
	_ignore_store_change = true
	for snapshot: Variant in [conflict.server_snapshot, conflict.conflicting_snapshot]:
		var remote := _parse_snapshot(snapshot)
		if snapshot == null or not _store.is_cloud_profile_valid(remote):
			invalid_profile = true
		else:
			_store.merge_cloud_profile(remote)
	_ignore_store_change = false
	# Never replace a malformed or newer-schema branch with a profile this client cannot understand.
	if invalid_profile:
		_suspend_cloud("Cloud conflict needs review · Local progress preserved")
		return
	if _snapshots == null or not _snapshots.has_method("supports_conflict_resolution") \
		or not _snapshots.supports_conflict_resolution():
		_suspend_cloud("Cloud conflict · Progress merged safely on this device")
		return
	if conflict.conflict_id.is_empty() or _conflict_attempts >= MAX_CONFLICT_ATTEMPTS:
		_suspend_cloud("Cloud conflict waiting · Progress saved here")
		return
	_conflict_attempts += 1
	_operation = "save"
	_operation_deadline = _now() + _timeout()
	var payload := _cloud_write_bytes()
	_set_status("Combining cloud progress…")
	if not _snapshots.resolve_conflict(conflict.conflict_id,
		"InfiniteSlash · %s points" % str(_store.profile.best_score), payload,
		int(_store.profile.total_played_seconds * 1000), int(_store.profile.total_kills)):
		_suspend_cloud("Cloud conflict waiting · Progress saved here")

func _suspend_cloud(message: String) -> void:
	_operation = ""
	_cloud_suspended = true
	_dirty = true
	_set_status(message)

func _process(_delta: float) -> void:
	var now := _now()
	if _auth_pending and now >= _auth_deadline:
		_auth_pending = false
		_set_status("Local play · Google Play took too long")
		if _queued_ui == "scores":
			local_leaderboards_requested.emit()
		elif _queued_ui == "achievements":
			local_achievements_requested.emit()
		_queued_ui = ""
	if not _operation.is_empty() and now >= _operation_deadline:
		# Native callbacks have no request token. Suspend until next launch to reject late replies safely.
		_suspend_cloud("Cloud sync paused · Progress saved here")
	if _operation == "verify_wait" and now >= _verify_after:
		_operation = "verify"
		_operation_deadline = now + _timeout()
		_snapshots.load_game(_save_name(), false)
	for board_id: String in _scores_inflight.keys():
		if now >= _scores_inflight[board_id].deadline:
			_scores_inflight.erase(board_id)
			_score_blocked[board_id] = true
	for achievement_id: String in _achievements_inflight.keys():
		if now >= _achievements_inflight[achievement_id].deadline:
			_achievement_sent[achievement_id] = _achievements_inflight[achievement_id].progress
			_achievements_inflight.erase(achievement_id)
	if _dirty and now >= _debounce_until and is_authenticated() and _operation.is_empty() and not _cloud_suspended:
		_flush_scores()
		_flush_achievements()
		sync_profile()
