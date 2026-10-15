extends Node
## Offline-first profile storage. Only completed runs affect competitive records.

const BossCatalog = preload("res://scripts/boss_catalog.gd")

signal achievement_unlocked(key: String)
signal profile_changed
signal storage_error(message: String)

const SCHEMA_VERSION := 1
const MAX_FILE_BYTES := 1048576
const MAX_ACTIVE_BYTES := 131072
const MAX_HISTORY := 30
const MAX_DAILY_DATES := 14
const MAX_VALUE := 1000000000000
const ACHIEVEMENTS := {
	"first_blood": "First Slice", "boss_slayer": "Crown Collector",
	"century": "A Hundred Little Problems", "survivor": "Still Standing",
	"legend": "Knight of Infinite Nonsense", "collector": "Bestiary Complete",
	"hundred_club": "A Hundred in a Hurry", "survivor_60": "Minute Knight",
	"survivor_180": "Three Minute Hero", "combo_25": "Slice Streak",
	"score_10000": "Five Digits of Slop", "thousand_kills": "Slop Sweeper",
	"ten_runs": "Back for More", "rare_boss": "Royal Upset", "all_bosses": "Crown Census"
}
const BOSS_ACHIEVEMENT_DESCRIPTIONS := {
	"rare_boss": "Defeat a rare boss: Moonmallow Majesty, Gilded Chancellor, or Lime Imperator.",
	"all_bosses": "Defeat all 12 different bosses across your runs."
}
const COUNTERS := ["runs", "kills", "bosses", "played", "powerups"]

var profile: Dictionary = {}
var active_run: Dictionary = {}
var storage_path := "user://infiniteslash_profile.json"
var storage_read_only := false
var last_storage_error := ""
var _known_monsters: Dictionary = {}

func _ready() -> void:
	_load_monster_ids()
	reload_profile()

## A test fixture or portable build may change storage without touching real progress.
func configure_storage(path: String) -> void:
	storage_path = path
	_load_monster_ids()
	reload_profile()

func _new_device_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _defaults() -> Dictionary:
	var device_id := _new_device_id()
	return {
		"schema_version": SCHEMA_VERSION, "device_id": device_id,
		"revision": 0, "updated_at": 0, "best_score": 0,
		"best_duration": 0.0, "best_combo": 0, "best_bosses": 0,
		"total_runs": 0, "total_kills": 0, "total_bosses": 0,
		"total_played_seconds": 0.0, "collected_powerups": 0,
		"device_totals": {device_id: _empty_counter()},
		"achievements": {}, "discovered": [], "defeated_bosses": [], "run_history": [], "daily_best": {},
		"settings": {"music": true, "sfx": true, "haptics": true},
		"cloud": {"pending_scores": {}, "pending_achievements": [],
			"last_verified_revision": 0, "player_id": ""}
	}

func _empty_counter() -> Dictionary:
	return {"runs": 0, "kills": 0, "bosses": 0, "played": 0.0, "powerups": 0}

func _load_monster_ids() -> void:
	if not _known_monsters.is_empty():
		return
	if not FileAccess.file_exists("res://data/monsters.json"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	if parsed is Array:
		for entry: Variant in parsed:
			if entry is Dictionary and entry.get("generated", false) == true:
				var monster_id: Variant = entry.get("id", "")
				if monster_id is String and not monster_id.is_empty():
					_known_monsters[monster_id] = true

func _number(value: Variant, limit: float = float(MAX_VALUE)) -> float:
	if not (value is int or value is float):
		return 0.0
	var result := float(value)
	return clampf(result, 0.0, limit) if is_finite(result) else 0.0

func _integer(value: Variant, limit: int = MAX_VALUE) -> int:
	return int(_number(value, float(limit)))

func _valid_date(value: Variant) -> bool:
	if not value is String or value.length() != 10:
		return false
	if value.substr(4, 1) != "-" or value.substr(7, 1) != "-":
		return false
	var digits: String = value.replace("-", "")
	if not digits.is_valid_int():
		return false
	var year := int(value.substr(0, 4))
	var month := int(value.substr(5, 2))
	var day := int(value.substr(8, 2))
	if year < 2020 or year > 2200 or month < 1 or month > 12:
		return false
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
		days[1] = 29
	return day >= 1 and day <= days[month - 1]

func _normalize_run(raw: Dictionary) -> Dictionary:
	var mode: Variant = raw.get("mode", "sword")
	if not mode is String or mode not in ["sword", "shield", "daily"]:
		mode = "sword"
	var result := {
		"score": _integer(raw.get("score", 0)), "kills": _integer(raw.get("kills", 0)),
		"bosses": _integer(raw.get("bosses", 0)),
		"duration": _number(raw.get("duration", 0), 86400.0),
		"combo": _integer(raw.get("combo", 0)), "mode": mode,
		"collected_powerups": _integer(raw.get("collected_powerups", raw.get("powerups", 0))),
		"ended_at": _integer(raw.get("ended_at", Time.get_unix_time_from_system()))
	}
	var style: Variant = raw.get("style", "shield" if mode == "shield" else "sword")
	result.style = style if style in ["sword", "shield"] else "sword"
	if _valid_date(raw.get("challenge_date")):
		result["challenge_date"] = raw.challenge_date
	return result

func _normalize_profile(raw: Dictionary) -> Dictionary:
	var result := _defaults()
	var device_id: Variant = raw.get("device_id", "")
	if device_id is String and device_id.length() >= 8 and device_id.length() <= 64:
		result.device_id = device_id
	for key: String in ["revision", "updated_at", "best_score", "best_combo", "best_bosses"]:
		result[key] = _integer(raw.get(key, 0))
	result.best_duration = _number(raw.get("best_duration", 0), 86400.0)
	var settings: Variant = raw.get("settings", {})
	if settings is Dictionary:
		for key: String in result.settings:
			if settings.get(key) is bool:
				result.settings[key] = settings[key]
	var achievements: Variant = raw.get("achievements", {})
	if achievements is Dictionary:
		for key: String in ACHIEVEMENTS:
			if achievements.has(key) and _integer(achievements[key]) > 0:
				result.achievements[key] = _integer(achievements[key])
	var discovered: Variant = raw.get("discovered", [])
	if discovered is Array:
		for monster_id: Variant in discovered:
			if monster_id is String and _known_monsters.has(monster_id) and monster_id not in result.discovered:
				result.discovered.append(monster_id)
	result.discovered.sort()
	var defeated_bosses: Variant = raw.get("defeated_bosses", [])
	if defeated_bosses is Array:
		var known_bosses := BossCatalog.ids()
		for boss_id: Variant in defeated_bosses:
			if boss_id is String and boss_id in known_bosses and boss_id not in result.defeated_bosses:
				result.defeated_bosses.append(boss_id)
	result.defeated_bosses.sort()
	var history: Variant = raw.get("run_history", [])
	if history is Array:
		for run: Variant in history.slice(maxi(0, history.size() - MAX_HISTORY)):
			if run is Dictionary:
				result.run_history.append(_normalize_run(run))
	var daily: Variant = raw.get("daily_best", {})
	if daily is Dictionary:
		for date: Variant in daily:
			if _valid_date(date):
				result.daily_best[date] = _integer(daily[date])
	_prune_daily(result.daily_best)
	var components: Variant = raw.get("device_totals", {})
	result.device_totals = {}
	if components is Dictionary:
		var count := 0
		for id: Variant in components:
			if id is String and id.length() >= 8 and id.length() <= 64 and components[id] is Dictionary:
				var counter := _empty_counter()
				for key: String in COUNTERS:
					counter[key] = _number(components[id].get(key, 0)) if key == "played" else _integer(components[id].get(key, 0))
				result.device_totals[id] = counter
				count += 1
				if count >= 64:
					break
	if result.device_totals.is_empty():
		# One-time migration for simple cumulative profiles; future versions use per-device counters.
		result.device_totals[result.device_id] = {
			"runs": _integer(raw.get("total_runs", 0)), "kills": _integer(raw.get("total_kills", 0)),
			"bosses": _integer(raw.get("total_bosses", 0)),
			"played": _number(raw.get("total_played_seconds", 0)),
			"powerups": _integer(raw.get("collected_powerups", 0))
		}
	if not result.device_totals.has(result.device_id):
		result.device_totals[result.device_id] = _empty_counter()
	_recompute_totals(result)
	var cloud: Variant = raw.get("cloud", {})
	if cloud is Dictionary:
		var scores: Variant = cloud.get("pending_scores", {})
		if scores is Dictionary:
			for key: String in ["high_score", "longest_run", "bosses_in_run"]:
				if scores.has(key):
					result.cloud.pending_scores[key] = _integer(scores[key])
		var pending: Variant = cloud.get("pending_achievements", [])
		if pending is Array:
			for key: String in ACHIEVEMENTS:
				if key in pending and result.achievements.has(key):
					result.cloud.pending_achievements.append(key)
		var player_id: Variant = cloud.get("player_id", "")
		if player_id is String and player_id.length() <= 128:
			result.cloud.player_id = player_id
		result.cloud.last_verified_revision = _integer(cloud.get("last_verified_revision", 0))
	return result

func _recompute_totals(target: Dictionary) -> void:
	var total := _empty_counter()
	for component: Dictionary in target.device_totals.values():
		for key: String in COUNTERS:
			total[key] = minf(float(MAX_VALUE), float(total[key]) + float(component[key]))
	target.total_runs = int(total.runs)
	target.total_kills = int(total.kills)
	target.total_bosses = int(total.bosses)
	target.total_played_seconds = float(total.played)
	target.collected_powerups = int(total.powerups)

func _prune_daily(daily: Dictionary) -> void:
	var dates := daily.keys()
	dates.sort()
	while dates.size() > MAX_DAILY_DATES:
		daily.erase(dates.pop_front())

func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or parsed.get("format") != "InfiniteSlash":
		return {}
	if not parsed.get("schema_version") is float and not parsed.get("schema_version") is int:
		return {}
	if parsed.schema_version > SCHEMA_VERSION:
		return {"future": true}
	if parsed.schema_version != SCHEMA_VERSION or not parsed.get("profile") is Dictionary:
		return {}
	return parsed

func _json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 16:
		return false
	if value == null or value is bool or value is String or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is Array:
		for item: Variant in value:
			if not _json_safe(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _json_safe(value[key], depth + 1):
				return false
		return true
	return false

func _normalize_active(raw: Variant) -> Dictionary:
	if not raw is Dictionary or not _json_safe(raw):
		return {}
	if JSON.stringify(raw).to_utf8_buffer().size() > MAX_ACTIVE_BYTES:
		return {}
	return raw.duplicate(true)

func reload_profile() -> bool:
	storage_read_only = false
	last_storage_error = ""
	active_run = {}
	var data := _read_file(storage_path)
	if data.get("future", false):
		profile = _defaults()
		storage_read_only = true
		_report_error("Progress belongs to a newer game version; its save is preserved.")
		return false
	if data.is_empty():
		data = _read_file(storage_path + ".bak")
		if data.get("future", false):
			profile = _defaults()
			storage_read_only = true
			_report_error("Backup belongs to a newer game version; its save is preserved.")
			return false
	profile = _normalize_profile(data.profile) if not data.is_empty() else _defaults()
	active_run = _normalize_active(data.get("active_run", {}))
	_evaluate_achievements(false)
	return not data.is_empty()

func _report_error(message: String) -> void:
	last_storage_error = message
	storage_error.emit(message)

func save_profile() -> void:
	if storage_read_only:
		return
	if profile.is_empty():
		profile = _defaults()
	profile = _normalize_profile(profile)
	profile.revision = _integer(profile.revision + 1)
	profile.updated_at = int(Time.get_unix_time_from_system())
	var text := JSON.stringify({"format": "InfiniteSlash", "schema_version": SCHEMA_VERSION,
		"profile": profile, "active_run": active_run})
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		_report_error("Progress snapshot is too large to save.")
		return
	var absolute := ProjectSettings.globalize_path(storage_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		_report_error("Could not create the progress folder.")
		return
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		_report_error("Could not write progress.")
		return
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_report_error("Progress write was interrupted.")
		return
	var previous := _read_file(storage_path)
	if not previous.is_empty() and not previous.get("future", false):
		if FileAccess.file_exists(absolute + ".bak"):
			if DirAccess.remove_absolute(absolute + ".bak") != OK:
				_report_error("Could not replace the progress backup.")
				return
		if DirAccess.rename_absolute(absolute, absolute + ".bak") != OK:
			_report_error("Could not keep the progress backup.")
			return
	elif FileAccess.file_exists(absolute):
		if previous.get("future", false):
			storage_read_only = true
			_report_error("Newer progress was detected; its save is preserved.")
			return
		if DirAccess.remove_absolute(absolute) != OK:
			_report_error("Could not replace damaged progress.")
			return
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		_report_error("Could not finish saving progress; previous progress is backed up.")
		return
	last_storage_error = ""
	profile_changed.emit()

func add_run(run: Dictionary) -> void:
	if profile.is_empty():
		profile = _defaults()
	var result := _normalize_run(run)
	profile.best_score = maxi(int(profile.best_score), result.score)
	profile.best_duration = maxf(float(profile.best_duration), result.duration)
	profile.best_combo = maxi(int(profile.best_combo), result.combo)
	profile.best_bosses = maxi(int(profile.best_bosses), result.bosses)
	var counter: Dictionary = profile.device_totals[profile.device_id]
	counter.runs = _integer(counter.runs + 1)
	counter.kills = _integer(counter.kills + result.kills)
	counter.bosses = _integer(counter.bosses + result.bosses)
	counter.played = _number(counter.played + result.duration)
	counter.powerups = _integer(counter.powerups + result.collected_powerups)
	_recompute_totals(profile)
	profile.run_history.append(result)
	while profile.run_history.size() > MAX_HISTORY:
		profile.run_history.pop_front()
	if result.has("challenge_date"):
		var date: String = result.challenge_date
		profile.daily_best[date] = maxi(int(profile.daily_best.get(date, 0)), result.score)
		_prune_daily(profile.daily_best)
	_queue_records()
	_evaluate_achievements(true)
	active_run = {}
	save_profile()

func _queue_records() -> void:
	var pending: Dictionary = profile.cloud.pending_scores
	pending.high_score = maxi(int(pending.get("high_score", 0)), int(profile.best_score))
	pending.longest_run = maxi(int(pending.get("longest_run", 0)), int(profile.best_duration))
	pending.bosses_in_run = maxi(int(pending.get("bosses_in_run", 0)), int(profile.best_bosses))

func _unlock(key: String, announce: bool) -> bool:
	if not ACHIEVEMENTS.has(key) or profile.achievements.has(key):
		return false
	profile.achievements[key] = int(Time.get_unix_time_from_system())
	if key not in profile.cloud.pending_achievements:
		profile.cloud.pending_achievements.append(key)
	if announce:
		achievement_unlocked.emit(key)
	return true

func unlock(key: String) -> bool:
	if profile.is_empty():
		profile = _defaults()
	var added := _unlock(key, true)
	if added:
		save_profile()
	return added

func _evaluate_achievements(announce: bool) -> void:
	var checks := {
		"first_blood": profile.total_kills >= 1,
		"boss_slayer": profile.total_bosses >= 1,
		"century": profile.total_kills >= 100,
		"hundred_club": false,
		"survivor_60": profile.best_duration >= 60,
		"survivor_180": profile.best_duration >= 180,
		"survivor": profile.best_duration >= 180,
		"legend": profile.best_bosses >= 5,
		"combo_25": profile.best_combo >= 25,
		"score_10000": profile.best_score >= 10000,
		"thousand_kills": profile.total_kills >= 1000,
		"ten_runs": profile.total_runs >= 10,
		"collector": _known_monsters.size() >= 100 and profile.discovered.size() >= _known_monsters.size(),
		"rare_boss": false,
		"all_bosses": profile.get("defeated_bosses", []).size() >= BossCatalog.BOSSES.size()
	}
	for boss_id: String in profile.get("defeated_bosses", []):
		if BossCatalog.is_rare(boss_id):
			checks.rare_boss = true
	for run: Dictionary in profile.run_history:
		if run.kills >= 100:
			checks.hundred_club = true
	for key: String in checks:
		if checks[key]:
			_unlock(key, announce)

func discover_monster(monster_id: String) -> bool:
	_load_monster_ids()
	if not _known_monsters.has(monster_id) or monster_id in profile.discovered:
		return false
	profile.discovered.append(monster_id)
	profile.discovered.sort()
	_evaluate_achievements(true)
	save_profile()
	return true

## Persist unique victories at the moment of defeat, including runs later abandoned.
## Repeats do not rewrite storage or inflate cumulative completed-run counters.
func record_boss_defeat(boss_id: String) -> bool:
	if BossCatalog.by_id(boss_id).is_empty():
		return false
	if profile.is_empty():
		profile = _defaults()
	if boss_id in profile.defeated_bosses:
		return false
	profile.defeated_bosses.append(boss_id)
	profile.defeated_bosses.sort()
	_evaluate_achievements(true)
	save_profile()
	return true

func discover_boss(boss_id: String) -> bool:
	return record_boss_defeat(boss_id)

func save_active_run(run: Dictionary) -> void:
	var safe := _normalize_active(run)
	if not run.is_empty() and safe.is_empty():
		_report_error("Active run contains unsupported or oversized data.")
		return
	active_run = safe
	save_profile()

func clear_active_run() -> void:
	active_run = {}
	save_profile()

## Cloud snapshots contain persistent progression only; active runs stay on this device.
func cloud_profile() -> Dictionary:
	var payload := profile.duplicate(true)
	payload.erase("cloud")
	payload.erase("run_history")
	return payload

## Per-device maxima are a grow-only counter: replaying the same cloud save is idempotent.
func is_cloud_profile_valid(remote: Dictionary) -> bool:
	var id: Variant = remote.get("device_id", "")
	var components: Variant = remote.get("device_totals", {})
	return remote.get("schema_version", 0) == SCHEMA_VERSION and id is String \
		and id.length() >= 8 and id.length() <= 64 and components is Dictionary \
		and not components.is_empty() and components.get(id) is Dictionary

func merge_cloud_profile(remote: Dictionary) -> bool:
	if not is_cloud_profile_valid(remote):
		return false
	var incoming := _normalize_profile(remote)
	var before := JSON.stringify(cloud_profile())
	for key: String in ["best_score", "best_combo", "best_bosses"]:
		profile[key] = maxi(int(profile[key]), int(incoming[key]))
	profile.best_duration = maxf(float(profile.best_duration), float(incoming.best_duration))
	for id: String in incoming.device_totals:
		if not profile.device_totals.has(id):
			if profile.device_totals.size() >= 64:
				continue
			profile.device_totals[id] = _empty_counter()
		for key: String in COUNTERS:
			var merged := maxf(float(profile.device_totals[id][key]), float(incoming.device_totals[id][key]))
			profile.device_totals[id][key] = merged if key == "played" else int(merged)
	_recompute_totals(profile)
	for key: String in incoming.achievements:
		if not profile.achievements.has(key):
			profile.achievements[key] = incoming.achievements[key]
			if key not in profile.cloud.pending_achievements:
				profile.cloud.pending_achievements.append(key)
	for monster_id: String in incoming.discovered:
		if monster_id not in profile.discovered:
			profile.discovered.append(monster_id)
	profile.discovered.sort()
	for boss_id: String in incoming.defeated_bosses:
		if boss_id not in profile.defeated_bosses:
			profile.defeated_bosses.append(boss_id)
	profile.defeated_bosses.sort()
	for date: String in incoming.daily_best:
		profile.daily_best[date] = maxi(int(profile.daily_best.get(date, 0)), int(incoming.daily_best[date]))
	_prune_daily(profile.daily_best)
	# Preferences belong to this device: cloud load never silently changes music or haptics.
	_queue_records()
	_evaluate_achievements(false)
	var changed := before != JSON.stringify(cloud_profile())
	if changed:
		save_profile()
	return changed
