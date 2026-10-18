extends Node
## Non-blocking ad orchestration. Desktop never creates a vendor/mock backend.
## Counter storage is device-only and deliberately independent of SaveData/cloud.

signal banner_space_changed(top_px: float, bottom_px: float)
signal availability_changed(rewarded_ready: bool)
signal fullscreen_started(kind: String)
signal fullscreen_finished(kind: String, reward_earned: bool)
signal privacy_options_changed(required: bool)

const CONFIG_PATH := "res://config/admob.json"
const TEST_UNITS := {"banner": "ca-app-pub-3940256099942544/6300978111",
	"interstitial": "ca-app-pub-3940256099942544/1033173712", "rewarded": "ca-app-pub-3940256099942544/5224354917"}
const MAX_COUNTER_FILE := 16384

var configuration: Dictionary = {}
var storage_path := "user://infiniteslash_ad_frequency.json"
var _backend: Node
var _available := false
var _initialized := false
var _consent_allowed := false
var _privacy_required := false
var _app_active := true
var _placement := ""
var _serial := 0
var _consent_token := 0
var _consent_deadline := 0.0
var _consent_retry := 0.0
var _init_token := 0
var _init_deadline := 0.0
var _loads: Dictionary = {}
var _ready_tokens: Dictionary = {}
var _ready_since: Dictionary = {}
var _attempts: Dictionary = {}
var _retry_at: Dictionary = {}
var _fullscreen_kind := ""
var _fullscreen_token := 0
var _show_deadline := 0.0
var _earned := false
var _top_space := 0.0
var _bottom_space := 0.0
var _rewarded_available := false
var _completed_since_interstitial := 0
var _interstitial_window := false
var _interstitial_after := 0.0
var _counter_read_only := false
var _pump_after := 0.0

func _ready() -> void:
	if configuration.is_empty() and FileAccess.file_exists(CONFIG_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary: configuration = parsed
	_load_counter()
	call_deferred("_boot")

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _token() -> int:
	_serial += 1
	return _serial

func _diagnostic(event: String, details: Dictionary = {}) -> void:
	if configuration.get("test_mode", false) != true and not OS.is_debug_build(): return
	var data := details.duplicate()
	data["event"] = event
	print("INFINITESLASH_ADS ", JSON.stringify(data))

func _number(key: String, fallback: float, minimum: float, maximum: float) -> float:
	var value: Variant = configuration.get(key, fallback)
	return clampf(float(value), minimum, maximum) if (value is int or value is float) and is_finite(float(value)) else fallback

func _boot() -> void:
	if configuration.get("enabled", false) != true: return
	if _backend == null:
		if OS.get_name() != "Android": return
		_backend = load("res://scripts/services/admob_backend.gd").new()
		add_child(_backend)
	if _backend.has_method("set_diagnostics_enabled"):
		_backend.set_diagnostics_enabled(configuration.get("test_mode", false) == true or OS.is_debug_build())
	_available = _backend.is_available()
	_diagnostic("backend", {"available": _available})
	if not _available: return
	for pair: Array in [["consent_completed", "_on_consent_completed"], ["form_started", "_on_form_started"],
		["privacy_completed", "_on_privacy_completed"], ["initialized", "_on_initialized"],
		["loaded", "_on_loaded"], ["load_failed", "_on_load_failed"], ["shown", "_on_shown"],
		["closed", "_on_closed"], ["reward_earned", "_on_reward_earned"], ["show_failed", "_on_show_failed"]]:
		_backend.connect(pair[0], Callable(self, pair[1]))
	_backend.set_app_active(_app_active)
	_consent_retry = maxf(_now(), 0.001)
	_begin_consent()

func _begin_consent() -> void:
	if not _available or _consent_token != 0 or not _app_active or not _fullscreen_kind.is_empty(): return
	_consent_retry = 0.0
	_consent_token = _token()
	_consent_deadline = _now() + _number("load_timeout_seconds", 30, 5, 60)
	if not _backend.begin_consent(_consent_token):
		_consent_token = 0
		_consent_retry = _now() + 60.0

func _on_form_started(token: int, kind: String) -> void:
	if kind == "consent" and token == _consent_token and _fullscreen_kind.is_empty():
		_consent_deadline = 0.0
		_fullscreen_token = token
		_fullscreen_kind = "consent"
		_destroy_banner()
		fullscreen_started.emit("consent")

func _set_privacy(required: bool) -> void:
	if _privacy_required != required:
		_privacy_required = required
		privacy_options_changed.emit(required)

func _on_consent_completed(token: int, allowed: bool, required: bool) -> void:
	if token != _consent_token or token == 0: return
	_consent_token = 0
	_consent_deadline = 0.0
	_consent_allowed = allowed and _backend.can_request_ads()
	_diagnostic("consent_completed", {"allowed": _consent_allowed, "privacy_required": required})
	_set_privacy(required)
	if _fullscreen_kind == "consent": _finish_fullscreen(false)
	_consent_retry = 0.0 if _consent_allowed else _now() + 60.0
	if _consent_allowed: _ensure_initialized()
	else: _drop_all_ads()

func _ensure_initialized() -> void:
	if _initialized:
		_pump()
		return
	if _init_token != 0 or not _can_request(): return
	_init_token = _token()
	_init_deadline = _now() + 30.0
	if not _backend.initialize_ads(_init_token, configuration):
		_init_token = 0
		_consent_retry = _now() + 60.0

func _on_initialized(token: int) -> void:
	if token == 0 or token != _init_token: return
	_init_token = 0
	_init_deadline = 0.0
	_initialized = true
	_diagnostic("initialized")
	_pump()

func _can_request() -> bool:
	return _available and _consent_allowed and _backend != null and _backend.can_request_ads()

func _unit(kind: String) -> String:
	# Debug builds and the delivered configuration use Google's real test ads.
	if configuration.get("test_mode", true) == true or OS.is_debug_build():
		return TEST_UNITS.get(kind, "")
	var units: Variant = configuration.get("production_ad_units", {})
	if not units is Dictionary: return ""
	var id: Variant = units.get(kind, "")
	if not id is String: return ""
	var pattern := RegEx.new()
	pattern.compile("^ca-app-pub-[0-9]{16}/[0-9]{10}$")
	return id if pattern.search(id) != null else ""

func set_banner_placement(placement: String) -> void:
	var wanted := placement if placement in ["home", "pause", "upgrade"] else ""
	if wanted == _placement: return
	_placement = wanted
	_destroy_banner()
	_attempts.erase("banner")
	_retry_at.erase("banner")
	_pump()

func set_app_active(active: bool) -> void:
	if _app_active == active: return
	_app_active = active
	if _backend != null: _backend.set_app_active(active)
	if not active:
		_destroy_banner()
		_interstitial_window = false
	_update_availability()
	if active:
		if _consent_retry > 0 and _now() >= _consent_retry: _begin_consent()
		_pump()

func is_rewarded_ready() -> bool:
	return _app_active and _fullscreen_kind.is_empty() and _can_request() and _ready_tokens.has("rewarded") \
		and _now() - float(_ready_since.get("rewarded", 0)) < _number("cache_expiry_seconds", 3300, 60, 3300)

func get_fullscreen_kind() -> String:
	return _fullscreen_kind

func is_privacy_options_required() -> bool:
	return _privacy_required

func show_privacy_options() -> bool:
	if not _available or not _app_active or not _privacy_required or not _fullscreen_kind.is_empty() or _consent_token != 0: return false
	_drop_all_ads()
	_consent_allowed = false
	_fullscreen_token = _token()
	_fullscreen_kind = "privacy"
	_earned = false
	fullscreen_started.emit("privacy")
	if not _backend.show_privacy(_fullscreen_token):
		_finish_fullscreen(false)
		_consent_retry = _now() + 60.0
		return false
	return true

func _on_privacy_completed(token: int, allowed: bool, required: bool) -> void:
	if _fullscreen_kind != "privacy" or token != _fullscreen_token: return
	_consent_allowed = allowed
	_diagnostic("privacy_completed", {"allowed": allowed, "privacy_required": required})
	_set_privacy(required)
	_finish_fullscreen(false)
	if allowed: _ensure_initialized()
	else: _consent_retry = _now() + 60.0

func show_rewarded_continue() -> bool:
	if not is_rewarded_ready():
		_pump()
		return false
	return _show_ad("rewarded")

func record_completed_game() -> void:
	_completed_since_interstitial = mini(3, _completed_since_interstitial + 1)
	_interstitial_window = true
	_save_counter()
	_pump()

func show_interstitial_if_due() -> bool:
	# Never consume a saved due counter on launch or automatically after a load.
	if not _interstitial_window: return false
	_interstitial_window = false
	if _completed_since_interstitial < 3 or _now() < _interstitial_after or not _app_active or not _fullscreen_kind.is_empty() or not _can_request() or not _ready_tokens.has("interstitial"):
		_pump()
		return false
	return _show_ad("interstitial")

func _show_ad(kind: String) -> bool:
	var token := int(_ready_tokens.get(kind, 0))
	if token == 0: return false
	if _now() - float(_ready_since.get(kind, 0)) >= _number("cache_expiry_seconds", 3300, 60, 3300):
		_backend.discard(kind, token)
		_ready_tokens.erase(kind)
		_ready_since.erase(kind)
		_pump()
		return false
	_fullscreen_token = token
	_fullscreen_kind = kind
	_earned = false
	_show_deadline = _now() + 12.0
	_ready_tokens.erase(kind)
	_ready_since.erase(kind)
	_destroy_banner()
	_update_availability()
	fullscreen_started.emit(kind)
	if not _backend.show_ad(kind, token):
		_on_show_failed(kind, token)
		return false
	return true

func _on_shown(kind: String, token: int) -> void:
	if kind != _fullscreen_kind or token != _fullscreen_token: return
	_diagnostic("shown", {"kind": kind})
	_show_deadline = 0.0
	if kind == "interstitial":
		_completed_since_interstitial = 0
		_save_counter()

func _on_reward_earned(token: int) -> void:
	if _fullscreen_kind == "rewarded" and token == _fullscreen_token:
		_earned = true
		_diagnostic("reward_earned")

func _on_closed(kind: String, token: int) -> void:
	if kind != _fullscreen_kind or token != _fullscreen_token: return
	_diagnostic("closed", {"kind": kind, "earned": _earned and kind == "rewarded"})
	_finish_fullscreen(_earned and kind == "rewarded")

func _on_show_failed(kind: String, token: int) -> void:
	if kind == _fullscreen_kind and token == _fullscreen_token:
		_diagnostic("show_failed", {"kind": kind})
		_finish_fullscreen(false)

func _finish_fullscreen(reward: bool) -> void:
	var kind := _fullscreen_kind
	var token := _fullscreen_token
	if kind.is_empty(): return
	_fullscreen_kind = ""
	_fullscreen_token = 0
	_show_deadline = 0.0
	_earned = false
	# Set before emitting: finalising a cancelled continue can synchronously request
	# an interstitial. Preserve its due counter, but do not chain fullscreen ads.
	_interstitial_after = _now() + 30.0
	if kind in ["rewarded", "interstitial"] and _backend != null: _backend.discard(kind, token)
	fullscreen_finished.emit(kind, reward)
	_pump()

func _update_availability() -> void:
	var available := is_rewarded_ready()
	if available != _rewarded_available:
		_rewarded_available = available
		availability_changed.emit(available)

func _space(top: float, bottom: float) -> void:
	if top == _top_space and bottom == _bottom_space: return
	_top_space = top
	_bottom_space = bottom
	banner_space_changed.emit(top, bottom)

func _destroy_banner() -> void:
	var token := int(_ready_tokens.get("banner", _loads.get("banner", {}).get("token", 0)))
	_ready_tokens.erase("banner")
	_ready_since.erase("banner")
	_loads.erase("banner")
	if _backend != null and token != 0: _backend.discard("banner", token)
	_space(0, 0)

func _drop_all_ads() -> void:
	_destroy_banner()
	for kind: String in ["rewarded", "interstitial"]:
		var token := int(_ready_tokens.get(kind, _loads.get(kind, {}).get("token", 0)))
		if _backend != null and token != 0: _backend.discard(kind, token)
	_ready_tokens.clear()
	_ready_since.clear()
	_loads.clear()
	_update_availability()

func _request(kind: String) -> void:
	if _loads.has(kind) or _ready_tokens.has(kind) or _now() < float(_retry_at.get(kind, 0)): return
	var unit := _unit(kind)
	if unit.is_empty(): return
	var token := _token()
	_loads[kind] = {"token": token, "deadline": _now() + _number("load_timeout_seconds", 30, 5, 60)}
	_attempts[kind] = int(_attempts.get(kind, 0)) + 1
	if not _backend.load_ad(kind, unit, token, _placement): _on_load_failed(kind, token)

func _on_loaded(kind: String, token: int, height_px: float) -> void:
	# Banner auto-refresh reuses its native view/token. Fullscreen duplicate load
	# callbacks must not destroy a ready ad or an ad already being displayed.
	if int(_ready_tokens.get(kind, 0)) == token and token != 0:
		if kind == "banner" and is_finite(height_px) and height_px > 0:
			_space(0.0 if _placement == "upgrade" else height_px, height_px if _placement == "upgrade" else 0.0)
		return
	if kind == _fullscreen_kind and token == _fullscreen_token: return
	if not _loads.has(kind) or int(_loads[kind].token) != token:
		if _backend != null: _backend.discard(kind, token)
		return
	_loads.erase(kind)
	_diagnostic("loaded", {"kind": kind})
	if not _can_request() or (kind == "banner" and (not _app_active or _placement.is_empty() or not _fullscreen_kind.is_empty())):
		_backend.discard(kind, token)
		return
	_ready_tokens[kind] = token
	_ready_since[kind] = _now()
	_attempts[kind] = 0
	_retry_at.erase(kind)
	if kind == "banner":
		if not is_finite(height_px) or height_px <= 0:
			_ready_tokens.erase(kind)
			_backend.discard(kind, token)
			_retry_at[kind] = _now() + 60
			return
		_space(0.0 if _placement == "upgrade" else height_px, height_px if _placement == "upgrade" else 0.0)
		_backend.show_banner(token)
	_update_availability()

func _on_load_failed(kind: String, token: int) -> void:
	if not _loads.has(kind) or int(_loads[kind].token) != token: return
	_loads.erase(kind)
	_diagnostic("load_failed", {"kind": kind})
	if _backend != null: _backend.discard(kind, token)
	var attempts := int(_attempts.get(kind, 1))
	_retry_at[kind] = _now() + (300.0 if attempts >= 3 else _number("retry_base_seconds", 30, 10, 120) * pow(2.0, attempts - 1))
	if attempts >= 3: _attempts[kind] = 0
	_update_availability()

func _pump() -> void:
	_pump_after = _now() + 0.5
	if not _app_active or not _initialized or not _fullscreen_kind.is_empty() or not _can_request(): return
	for kind: String in ["rewarded", "interstitial"]: _request(kind)
	if not _placement.is_empty(): _request("banner")
	_update_availability()

func _process(_delta: float) -> void:
	var now := _now()
	if _consent_token != 0 and _consent_deadline > 0 and now >= _consent_deadline:
		_backend.cancel_consent(_consent_token)
		_consent_token = 0
		_consent_deadline = 0
		_consent_retry = now + 60.0
	if _app_active and _fullscreen_kind.is_empty() and _consent_token == 0 and _consent_retry > 0 and now >= _consent_retry:
		_begin_consent()
	if _init_token != 0 and now >= _init_deadline:
		_init_token = 0
		_consent_retry = now + 60
	for kind: String in _loads.keys():
		if now >= float(_loads[kind].deadline): _on_load_failed(kind, int(_loads[kind].token))
	for kind: String in _ready_tokens.keys():
		if now - float(_ready_since[kind]) >= _number("cache_expiry_seconds", 3300, 60, 3300):
			_backend.discard(kind, int(_ready_tokens[kind]))
			_ready_tokens.erase(kind)
			_ready_since.erase(kind)
			if kind == "banner": _space(0, 0)
	if _show_deadline > 0 and now >= _show_deadline: _finish_fullscreen(false)
	if now >= _pump_after: _pump()

func _read_counter(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_COUNTER_FILE: return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK: return {}
	return parser.data if parser.data is Dictionary else {}

func _load_counter() -> void:
	var data := _read_counter(storage_path)
	if data.is_empty(): data = _read_counter(storage_path + ".bak")
	var version: Variant = data.get("schema", 1)
	_counter_read_only = (version is int or version is float) and float(version) > 1
	var value: Variant = data.get("completed_since_interstitial", 0)
	_completed_since_interstitial = clampi(int(value), 0, 3) if (value is int or value is float) and is_finite(float(value)) else 0
	if _counter_read_only: _completed_since_interstitial = 0

func _save_counter() -> void:
	if _counter_read_only: return
	var absolute := ProjectSettings.globalize_path(storage_path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute + ".tmp", FileAccess.WRITE)
	if file == null: return
	file.store_string(JSON.stringify({"schema": 1, "completed_since_interstitial": _completed_since_interstitial}))
	file.flush()
	if file.get_error() != OK: return
	file.close()
	if FileAccess.file_exists(absolute):
		DirAccess.copy_absolute(absolute, absolute + ".bak")
		if DirAccess.remove_absolute(absolute) != OK: return
	DirAccess.rename_absolute(absolute + ".tmp", absolute)

func _exit_tree() -> void:
	if _backend != null:
		_drop_all_ads()
		_backend.shutdown()
