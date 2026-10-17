extends SceneTree
## Run with Godot --headless --path <project> --script tests/test_services.gd.

const STORE_SCRIPT = preload("res://scripts/services/save_data.gd")
const PLAY_SCRIPT = preload("res://scripts/services/play_services.gd")
var _failures := 0
var _checks := 0
var _fixture_root := ""
var _stores: Array[Node] = []

class FakeSnapshots extends Node:
	var loads := 0
	var saves := 0
	var payload: Dictionary = {}
	func load_game(_name: String, _create: bool) -> void:
		loads += 1
	func save_game(_name: String, _description: String, bytes: PackedByteArray, _played: int, _progress: int) -> void:
		saves += 1
		payload = JSON.parse_string(bytes.get_string_from_utf8())

class FakeSnapshot extends RefCounted:
	var content: PackedByteArray
	var metadata: Dictionary
	func _init(payload: Dictionary, pending := false) -> void:
		content = JSON.stringify(payload).to_utf8_buffer()
		metadata = {"has_change_pending": pending}

class FakeResolvingSnapshots extends FakeSnapshots:
	var available := true
	var start_result := true
	var resolutions: Array[Dictionary] = []
	func supports_conflict_resolution() -> bool:
		return available
	func resolve_conflict(id: String, description: String, bytes: PackedByteArray,
			played: int, progress: int) -> bool:
		payload = JSON.parse_string(bytes.get_string_from_utf8())
		resolutions.append({"id": id, "description": description,
			"payload": payload.duplicate(true), "played_ms": played, "progress": progress})
		return start_result

class FakeConflict extends RefCounted:
	var conflict_id: String
	var server_snapshot: Variant
	var conflicting_snapshot: Variant
	func _init(id: String, server: Variant, conflicting: Variant) -> void:
		conflict_id = id
		server_snapshot = server
		conflicting_snapshot = conflicting

class FakePlayer extends RefCounted:
	var player_id: String
	func _init(id: String) -> void:
		player_id = id

class FakeLeaderboards extends Node:
	var submissions: Array[Dictionary] = []
	func submit_score(board_id: String, score: int) -> void:
		submissions.append({"board": board_id, "score": score})

class FakeAchievements extends Node:
	var unlocks: Array[String] = []
	var steps: Array[Dictionary] = []
	func unlock_achievement(id: String) -> void:
		unlocks.append(id)
	func set_achievement_steps(id: String, progress: int) -> void:
		steps.append({"id": id, "progress": progress})

class DatedPlayServices extends PLAY_SCRIPT:
	var test_date := "2040-03-01"
	func _challenge_date() -> String:
		return test_date

func _initialize() -> void:
	_fixture_root = "res://output/test-data/service-tests/%s" % str(Time.get_ticks_usec())
	call_deferred("_run_tests")

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("SERVICES: " + message)

func _store(name: String) -> Node:
	var store: Node = STORE_SCRIPT.new()
	store.storage_path = _fixture_root.path_join(name + ".json")
	root.add_child(store)
	_stores.append(store)
	return store

func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _run_tests() -> void:
	_test_configured_feature_contract()
	_test_defaults_and_records()
	_test_storage_and_backup()
	_test_normalization()
	_test_daily_and_history()
	_test_discovery()
	_test_production_bestiary_and_records()
	_test_cloud_merge()
	_test_disabled_adapter()
	_test_cloud_adapter_callbacks()
	_test_resolved_cloud_conflict()
	_test_conflict_resolution_fallbacks()
	_test_invalid_conflict_branches()
	_test_conflict_retry_bound()
	_test_conflict_timeout_and_late_callbacks()
	_test_account_mismatch_blocks_cloud()
	_test_cloud_read_failure_callbacks()
	_test_daily_score_routing()
	_test_configured_boss_achievements()
	for store: Node in _stores:
		store.free()
	print("Service tests: %d checks, %d failures" % [_checks, _failures])
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
		await create_timer(0.35).timeout
	quit(0 if _failures == 0 else 1)

func _test_configured_feature_contract() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/play_services.json"))
	var expected_achievements := {
		"first_blood": "CgkI5NXU8p0YEAIQBA", "boss_slayer": "CgkI5NXU8p0YEAIQBQ",
		"century": "CgkI5NXU8p0YEAIQBg", "hundred_club": "CgkI5NXU8p0YEAIQBw",
		"survivor_60": "CgkI5NXU8p0YEAIQCA", "survivor": "CgkI5NXU8p0YEAIQCQ",
		"legend": "CgkI5NXU8p0YEAIQCg", "combo_25": "CgkI5NXU8p0YEAIQCw",
		"score_10000": "CgkI5NXU8p0YEAIQDA", "collector": "CgkI5NXU8p0YEAIQDQ",
		"thousand_kills": "CgkI5NXU8p0YEAIQDg", "ten_runs": "CgkI5NXU8p0YEAIQDw",
		"rare_boss": "CgkI5NXU8p0YEAIQEA", "all_bosses": "CgkI5NXU8p0YEAIQEQ",
		"bestiary_50": "CgkI5NXU8p0YEAIQEg", "bestiary_100": "CgkI5NXU8p0YEAIQEw",
		"bestiary_150": "CgkI5NXU8p0YEAIQFA", "bestiary_200": "CgkI5NXU8p0YEAIQFQ",
		"biome_50": "CgkI5NXU8p0YEAIQFg"
	}
	var expected_boards := {"high_score": "CgkI5NXU8p0YEAIQAQ", "longest_run": "CgkI5NXU8p0YEAIQAg",
		"bosses_in_run": "CgkI5NXU8p0YEAIQAw", "highest_combo": "CgkI5NXU8p0YEAIQFw", "highest_level": "CgkI5NXU8p0YEAIQGA"}
	var unique_ids: Dictionary = {}
	for key: String in expected_achievements:
		_check(config.achievements.get(key) == expected_achievements[key], "exact configured achievement ID: " + key)
		unique_ids[config.achievements.get(key, "")] = true
	_check(unique_ids.size() == 19 and not unique_ids.has(""), "all19 achievement IDs are configured and unique")
	var board_ids: Dictionary = {}
	for key: String in expected_boards:
		_check(config.leaderboards.get(key) == expected_boards[key], "exact configured leaderboard ID: " + key)
		board_ids[config.leaderboards.get(key, "")] = true
		unique_ids[config.leaderboards.get(key, "")] = true
	_check(board_ids.size() == 5 and not board_ids.has(""), "all5 leaderboard IDs are configured and unique")
	_check(unique_ids.size() == 24, "achievement and leaderboard IDs do not collide")
	_check(config.achievements.get("survivor_180") == "" and config.leaderboards.get("daily_score") == "",
		"optional daily board and duplicate local survival badge stay unmapped")
	var expected_incremental := {"century": 100, "collector": 100, "thousand_kills": 1000, "ten_runs": 10}
	_check(config.incremental_achievements.size() == 4, "the same four achievements retain Incremental configuration")
	for key: String in expected_incremental:
		var target: Variant = config.incremental_achievements.get(key)
		_check((target is int or target is float) and float(target) == float(expected_incremental[key]),
			"confirmed Incremental target is preserved: " + key)
	_check(config.game_id == "832658811620" and config.save_name == "infiniteslash_profile_v1" and config.enabled == true,
		"existing game identity and stable Saved Games slot remain enabled")

func _test_configured_boss_achievements() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/play_services.json"))
	var expected := {"rare_boss": "CgkI5NXU8p0YEAIQEA", "all_bosses": "CgkI5NXU8p0YEAIQEQ"}
	for key: String in expected:
		_check(config.achievements.get(key) == expected[key], key + " uses the owner-supplied Google ID")
		_check(not config.incremental_achievements.has(key), key + " remains a Standard achievement")
	var configured_ids: Array = []
	var unique_ids: Dictionary = {}
	for id: String in config.achievements.values():
		if not id.is_empty():
			configured_ids.append(id)
			unique_ids[id] = true
	_check(configured_ids.size() == 19 and configured_ids.size() == unique_ids.size(), "all nineteen configured achievement IDs are unique")
	var store := _store("configured_boss_achievements")
	for boss_id: String in store.BossCatalog.ids():
		store.record_boss_defeat(boss_id)
	store.reload_profile()
	for key: String in expected:
		_check(store.profile.achievements.has(key) and key in store.profile.cloud.pending_achievements, key + " earned offline remains queued after disk reload")
	var adapter: Node = PLAY_SCRIPT.new()
	adapter._store = store
	adapter.configuration = config.duplicate(true)
	root.add_child(adapter)
	adapter.set_process(false)
	var client := FakeAchievements.new()
	adapter.add_child(client)
	adapter._achievements = client
	adapter._flush_achievements()
	_check(client.unlocks.is_empty(), "queued boss awards wait for authentication")
	adapter._authenticated = true
	adapter._account_ready = true
	adapter._flush_achievements()
	_check(client.unlocks.size() == 2 and expected.rare_boss in client.unlocks and expected.all_bosses in client.unlocks, "previously earned boss awards replay through both real Google IDs")
	_check(client.steps.is_empty(), "boss awards use Standard unlock calls, not incremental steps")
	adapter._flush_achievements()
	_check(client.unlocks.size() == 2, "inflight awards are not submitted twice")
	adapter._on_achievement_unlocked(false, expected.rare_boss)
	_check("rare_boss" in store.profile.cloud.pending_achievements, "an unsuccessful rare-boss acknowledgement keeps the offline award queued")
	adapter._on_achievement_unlocked(true, expected.all_bosses)
	_check("all_bosses" not in store.profile.cloud.pending_achievements and store.profile.achievements.has("all_bosses"), "successful census acknowledgement clears its queue while preserving the earned badge")
	adapter._flush_achievements()
	_check(client.unlocks.size() == 2, "acknowledged attempts do not loop during the same session")
	adapter.free()

func _test_defaults_and_records() -> void:
	var store := _store("records")
	_check(store.profile.total_runs == 0 and store.profile.best_score == 0, "fresh profile starts empty")
	_check(store.profile.settings.music and store.profile.settings.sfx and store.profile.settings.haptics,
		"audio/haptics defaults are enabled")
	_check(store.active_run.is_empty(), "fresh profile has no suspended run")
	var unlocks: Array[String] = []
	store.achievement_unlocked.connect(func(key: String): unlocks.append(key))
	store.add_run({"score": 11000, "kills": 100, "bosses": 5, "duration": 181.5,
		"combo": 30, "mode": "shield", "collected_powerups": 7})
	_check(store.profile.best_score == 11000 and is_equal_approx(store.profile.best_duration, 181.5), "run records persist")
	_check(store.profile.best_combo == 30 and store.profile.best_bosses == 5, "combo/boss records persist")
	_check(store.profile.total_kills == 100 and store.profile.total_bosses == 5 and store.profile.total_runs == 1,
		"lifetime counters accumulate")
	_check(store.profile.collected_powerups == 7 and is_equal_approx(store.profile.total_played_seconds, 181.5),
		"time and powerups accumulate")
	for key: String in ["first_blood", "boss_slayer", "century", "hundred_club", "survivor",
		"survivor_60", "survivor_180", "legend", "combo_25", "score_10000"]:
		_check(store.profile.achievements.has(key) and key in unlocks, "milestone unlock: " + key)
	_check(not store.unlock("first_blood") and unlocks.count("first_blood") == 1, "unlocks emit exactly once")
	_check(not store.unlock("invented_key") and not store.profile.achievements.has("invented_key"), "unknown achievements rejected")
	store.add_run({"score": 1, "kills": 900, "bosses": 0, "duration": 5, "combo": 1})
	_check(store.profile.best_score == 11000 and store.profile.best_bosses == 5, "lower runs do not lower highs")
	_check(store.profile.total_kills == 1000 and store.profile.achievements.has("thousand_kills"), "cumulative goal spans runs")
	for index: int in range(8):
		store.add_run({"score": index})
	_check(store.profile.total_runs == 10 and store.profile.achievements.has("ten_runs"), "ten-run cumulative goal")
	_check(store.profile.cloud.pending_scores.high_score == 11000, "offline score queue retains maximum")
	_check(store.profile.cloud.pending_achievements.has("first_blood"), "offline unlock remains queued")

func _test_storage_and_backup() -> void:
	var store := _store("storage")
	store.add_run({"score": 321, "kills": 3})
	store.profile.settings.music = false
	store.save_profile()
	store.save_active_run({"mode": "shield", "time": 14.5, "seed": 42,
		"data": {"player": {"x": 250, "y": 680}, "level": 3}})
	var reloaded := _store("storage")
	_check(reloaded.profile.best_score == 321 and not reloaded.profile.settings.music, "settings/profile round trip")
	_check(reloaded.active_run.get("seed") == 42 and reloaded.active_run.data.level == 3, "active-run Dictionary round trip")
	reloaded.clear_active_run()
	_check(reloaded.reload_profile() and reloaded.active_run.is_empty(), "clear-active persists")
	var backup := _store("backup")
	backup.add_run({"score": 100, "kills": 1})
	backup.add_run({"score": 999, "kills": 9})
	_write(backup.storage_path, "{broken json")
	_check(backup.reload_profile() and backup.profile.best_score == 100, "corrupt primary restores prior valid backup")
	backup.save_profile()
	_check(backup.reload_profile() and backup.profile.best_score == 100, "recovery writes a valid new primary")
	_check(not backup._read_file(backup.storage_path + ".bak").is_empty(), "corrupt primary never replaces good backup")
	_write(backup.storage_path, "broken")
	_write(backup.storage_path + ".bak", "broken")
	_check(not backup.reload_profile() and backup.profile.total_runs == 0, "both corrupt files restore defaults")
	backup.save_active_run({"bad": Vector2.ONE})
	_check(backup.active_run.is_empty() and not backup.last_storage_error.is_empty(), "engine objects rejected from active JSON")
	backup.save_active_run({"huge": "x".repeat(STORE_SCRIPT.MAX_ACTIVE_BYTES + 1)})
	_check(backup.active_run.is_empty(), "oversized active-run snapshots rejected")
	var future := _store("future")
	var future_text := JSON.stringify({"format": "InfiniteSlash", "schema_version": 99, "profile": {"best_score": 999999}})
	_write(future.storage_path, future_text)
	_check(not future.reload_profile() and future.storage_read_only, "future schema protected")
	future.add_run({"score": 1})
	_check(FileAccess.get_file_as_string(future.storage_path) == future_text, "older app does not overwrite future data")

func _test_normalization() -> void:
	var store := _store("normalization")
	store.add_run({"score": -20, "kills": "1000", "bosses": [], "duration": INF, "combo": NAN,
		"mode": "invalid", "powerups": -10, "challenge_date": "2026-02-31"})
	_check(store.profile.best_score == 0 and store.profile.total_kills == 0, "negative and string numbers rejected")
	_check(store.profile.best_duration == 0.0 and store.profile.best_combo == 0, "non-finite values rejected")
	_check(store.profile.run_history[0].mode == "sword" and not store.profile.run_history[0].has("challenge_date"),
		"invalid modes and calendar dates normalize")
	var envelope := {"format": "InfiniteSlash", "schema_version": 1, "profile": {
		"best_score": "bad", "settings": {"music": "no", "sfx": false}, "achievements": {"rogue": 1},
		"discovered": ["rogue", 1], "run_history": [false, {"score": 7}], "device_totals": []}}
	_write(store.storage_path, JSON.stringify(envelope))
	_check(store.reload_profile(), "partly malformed valid envelope loads safely")
	_check(store.profile.best_score == 0 and store.profile.settings.music and not store.profile.settings.sfx, "malformed settings keep defaults")
	_check(store.profile.achievements.is_empty() and store.profile.discovered.is_empty(), "unknown profile IDs rejected")
	_check(store.profile.run_history.size() == 1 and store.profile.run_history[0].score == 7, "valid history items survive malformed neighbors")

func _test_daily_and_history() -> void:
	var store := _store("daily")
	store.add_run({"score": 200, "mode": "daily", "challenge_date": "2026-10-12"})
	store.add_run({"score": 100, "mode": "shield", "challenge_date": "2026-10-12"})
	store.add_run({"score": 999})
	_check(store.profile.daily_best["2026-10-12"] == 200, "daily results use explicit date and retain high score")
	for day: int in range(1, 32):
		store.add_run({"score": day, "challenge_date": "2026-10-%02d" % day})
	_check(store.profile.daily_best.size() == 14 and not store.profile.daily_best.has("2026-10-01"), "daily dates bounded to latest fourteen")
	_check(store.profile.run_history.size() == 30, "history bounded to thirty results")
	_check(store.profile.run_history.back().score == 31, "history preserves most recent results")

func _test_discovery() -> void:
	var store := _store("discovery")
	_check(store._known_monsters.size() >= 100, "original creature roster remains known")
	var keys: Array = store._known_monsters.keys()
	_check(not store.discover_monster("missing_species"), "unknown discovery rejected")
	_check(store.discover_monster(keys[0]) and not store.discover_monster(keys[0]), "discovery is unique")
	for key: String in keys.slice(1):
		store.discover_monster(key)
	_check(store.profile.discovered.size() == keys.size() and store.profile.achievements.has("collector"), "one hundred species still unlock collector as the roster grows")
	_check(store.reload_profile() and store.profile.discovered.size() == keys.size(), "discovery round trip")

func _test_production_bestiary_and_records() -> void:
	var store := _store("production_bestiary")
	# Isolate milestone boundaries from asset-import timing and catalog order.
	for index: int in range(200):
		store._known_monsters["fixture_species_%03d" % index] = true
	_check(not store.record_monster_defeat("invented_species"), "unknown defeated species rejected")
	store.save_active_run({"seed": 828, "level": 31})
	for index: int in range(200):
		var id := "fixture_species_%03d" % index
		_check(store.record_monster_defeat(id), "a new species victory is recorded")
		if index in [48, 98, 148, 198]:
			_check(not store.profile.achievements.has("bestiary_%d" % (index + 2)), "bestiary goal waits for exact unique-species boundary")
		if index in [49, 99, 149, 199]:
			var key := "bestiary_%d" % (index + 1)
			_check(store.profile.achievements.has(key) and key in store.profile.cloud.pending_achievements,
				"unique-species milestone unlocks offline and remains queued")
	var revision: int = store.profile.revision
	_check(not store.record_monster_defeat("fixture_species_000") and store.profile.revision == revision,
		"repeated species neither inflate the collection nor rewrite storage")
	_check(store.profile.defeated_monsters.size() == 200 and store.profile.total_kills == 0,
		"species records do not alter completed-run cumulative kills")
	_check(store.profile.discovered.size() == 200 and store.profile.achievements.has("collector"),
		"confirmed defeats also fill the existing bestiary and its target100 collector")
	_check(store.record_biome_entry() and not store.record_biome_entry(), "biome arrival award is immediate and idempotent")
	_check(store.reload_profile() and store.profile.defeated_monsters.size() == 200 and store.active_run.seed == 828,
		"new collection and biome awards persist without altering the active run")
	var malformed: Dictionary = store.cloud_profile()
	malformed.defeated_monsters = ["fixture_species_000", "fixture_species_000", "forged", 9, {}]
	malformed.best_level = INF
	var normalized: Dictionary = store._normalize_profile(malformed)
	_check(normalized.defeated_monsters == ["fixture_species_000"] and normalized.best_level == 0,
		"species collection rejects forged, non-string, and duplicate identities; non-finite levels rejected")
	malformed.erase("defeated_monsters")
	normalized = store._normalize_profile(malformed)
	_check(normalized.defeated_monsters.size() == 200, "legacy kill-only discoveries migrate without erasing victories")
	var remote := _store("production_remote")
	for index: int in range(200):
		remote._known_monsters["fixture_species_%03d" % index] = true
	remote.record_monster_defeat("fixture_species_199")
	remote.add_run({"combo": 80, "level": 63, "bosses": 9})
	store.add_run({"combo": 55, "level": 51, "bosses": 7})
	store.save_active_run({"seed": 829})
	_check(store.merge_cloud_profile(remote.cloud_profile()), "higher remote combo and level records merge")
	_check(store.profile.best_combo == 80 and store.profile.best_level == 63 and store.profile.best_bosses == 9,
		"combo, level, and existing bosses-destroyed board use completed-run maxima")
	_check(store.profile.cloud.pending_scores.highest_combo == 80 and store.profile.cloud.pending_scores.highest_level == 63,
		"new records remain queued while playing offline")
	_check(store.active_run.seed == 829 and store.profile.defeated_monsters.size() == 200,
		"cloud union preserves active simulation and cannot reduce the collection")
	_check(not store.merge_cloud_profile(remote.cloud_profile()), "replayed species/record cloud payload is idempotent")
	var union_store := _store("production_collection_union")
	for id: String in store._known_monsters: union_store._known_monsters[id] = true
	union_store.profile.defeated_monsters = store.profile.defeated_monsters.slice(0, 49)
	union_store.profile.discovered = union_store.profile.defeated_monsters.duplicate()
	var complementary: Dictionary = remote.cloud_profile()
	complementary.defeated_monsters = store.profile.defeated_monsters.slice(25, 100)
	complementary.discovered = complementary.defeated_monsters.duplicate()
	_check(union_store.merge_cloud_profile(complementary) and union_store.profile.defeated_monsters.size() == 100,
		"overlapping complementary cloud collections union to100 distinct species")
	_check(union_store.profile.achievements.has("bestiary_50") and union_store.profile.achievements.has("bestiary_100"),
		"combined cloud victories cross species boundaries without requiring another kill")
	_check(not union_store.merge_cloud_profile(complementary), "replaying a complementary collection does not count repeats")
	var legacy_combo := _store("production_legacy_combo")
	legacy_combo.profile.best_combo = 88
	legacy_combo.save_profile()
	_check(legacy_combo.reload_profile() and legacy_combo.profile.cloud.pending_scores.highest_combo == 88,
		"a combo record predating its new board is queued during reload")
	_test_production_pending_replay(store)

func _test_production_pending_replay(store: Node) -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/play_services.json"))
	var expected_achievements := {"bestiary_50": "CgkI5NXU8p0YEAIQEg", "bestiary_100": "CgkI5NXU8p0YEAIQEw",
		"bestiary_150": "CgkI5NXU8p0YEAIQFA", "bestiary_200": "CgkI5NXU8p0YEAIQFQ", "biome_50": "CgkI5NXU8p0YEAIQFg"}
	var expected_boards := {"highest_combo": "CgkI5NXU8p0YEAIQFw", "highest_level": "CgkI5NXU8p0YEAIQGA"}
	var keys: Array = expected_achievements.keys()
	for key: String in keys:
		_check(config.achievements.get(key) == expected_achievements[key] and not config.incremental_achievements.has(key),
			"owner-supplied new achievement is configured as Standard: " + key)
	for key: String in expected_boards:
		_check(config.leaderboards.get(key) == expected_boards[key], "owner-supplied new leaderboard ID is configured: " + key)
	var adapter: Node = PLAY_SCRIPT.new()
	adapter._store = store
	# Explicitly blank fixture IDs exercise offline behavior independently of
	# the now-configured production JSON. No native Google client is created.
	adapter.configuration = {"enabled": false, "game_id": "", "leaderboards": {}, "achievements": {}}
	for key: String in keys: adapter.configuration.achievements[key] = ""
	for key: String in expected_boards: adapter.configuration.leaderboards[key] = ""
	root.add_child(adapter)
	adapter.set_process(false)
	var awards := FakeAchievements.new()
	var scores := FakeLeaderboards.new()
	adapter.add_child(awards)
	adapter.add_child(scores)
	adapter._achievements = awards
	adapter._leaderboards = scores
	adapter._authenticated = true
	adapter._account_ready = true
	adapter._flush_scores()
	adapter._flush_achievements()
	_check(scores.submissions.is_empty() and awards.unlocks.is_empty(), "blank feature IDs skip native calls and preserve pending records")
	for key: String in keys:
		_check(key in store.profile.cloud.pending_achievements, "blank-ID fixture preserves pending earned award: " + key)
		adapter.configuration.achievements[key] = config.achievements[key]
	adapter.configuration.leaderboards = {"highest_combo": config.leaderboards.highest_combo, "highest_level": config.leaderboards.highest_level}
	adapter._authenticated = false
	adapter._account_ready = false
	adapter._flush_scores()
	adapter._flush_achievements()
	_check(scores.submissions.is_empty() and awards.unlocks.is_empty(), "configured new IDs still wait for Google authentication")
	adapter._authenticated = true
	adapter._flush_scores()
	adapter._flush_achievements()
	_check(scores.submissions.is_empty() and awards.unlocks.is_empty(), "configured new IDs also wait for verified account readiness")
	adapter._account_ready = true
	adapter._flush_scores()
	adapter._flush_achievements()
	var submitted: Dictionary = {}
	for request: Dictionary in scores.submissions:
		submitted[request.board] = request.score
		_check(request.score is int and request.score > 0, "new leaderboard sends a positive integer record")
	_check(scores.submissions.size() == 2 and submitted == {expected_boards.highest_combo: 80, expected_boards.highest_level: 63},
		"saved maximum combo and level replay through the two actual owner-supplied IDs")
	_check(awards.unlocks.size() == 5 and awards.steps.is_empty(), "all five new local awards replay as Standard unlocks")
	for key: String in keys:
		_check(expected_achievements[key] in awards.unlocks, "actual supplied Standard ID receives its saved award: " + key)
	adapter._flush_scores()
	adapter._flush_achievements()
	_check(scores.submissions.size() == 2 and awards.unlocks.size() == 5, "new inflight features do not submit duplicates")
	for key: String in keys:
		adapter._on_achievement_unlocked(true, expected_achievements[key])
		_check(key not in store.profile.cloud.pending_achievements and store.profile.achievements.has(key),
			"acknowledged new award clears only its pending request")
	store.add_run({"combo": 90, "level": 70})
	adapter._on_score_submitted(true, expected_boards.highest_combo)
	adapter._on_score_submitted(true, expected_boards.highest_level)
	_check(store.profile.cloud.pending_scores.highest_combo == 90 and store.profile.cloud.pending_scores.highest_level == 70,
		"older acknowledgements preserve a higher newly earned combo and level")
	adapter._flush_scores()
	_check(scores.submissions.size() == 4 and scores.submissions[2].score == 90 and scores.submissions[3].score == 70,
		"new higher records submit after the older requests are acknowledged")
	adapter._on_score_submitted(true, expected_boards.highest_combo)
	adapter._on_score_submitted(true, expected_boards.highest_level)
	_check(not store.profile.cloud.pending_scores.has("highest_combo") and not store.profile.cloud.pending_scores.has("highest_level"),
		"successful new board acknowledgements clear only the exact submitted maxima")
	adapter.free()

func _test_cloud_merge() -> void:
	var local := _store("cloud_local")
	var remote := _store("cloud_remote")
	local.add_run({"score": 700, "kills": 20, "duration": 20, "collected_powerups": 2})
	local.profile.settings.music = false
	local.save_active_run({"seed": 123})
	remote.add_run({"score": 500, "kills": 30, "bosses": 1, "duration": 30, "collected_powerups": 3,
		"challenge_date": "2026-10-12"})
	var payload: Dictionary = remote.cloud_profile()
	_check(not payload.has("cloud") and not payload.has("active_run"), "cloud excludes device-local requests and active simulation")
	_check(local.merge_cloud_profile(payload), "new cloud progress merges")
	_check(local.profile.total_kills == 50 and local.profile.total_runs == 2, "different-device cumulative counters merge losslessly")
	_check(local.profile.best_score == 700 and local.profile.best_duration == 30, "cloud merges record maxima")
	_check(local.profile.collected_powerups == 5 and local.profile.total_bosses == 1, "cloud merges powerup/boss totals")
	_check(not local.profile.settings.music and local.active_run.seed == 123, "cloud cannot change local settings or active run")
	_check(not local.merge_cloud_profile(payload) and local.profile.total_kills == 50, "replayed cloud payload is idempotent")
	remote.add_run({"score": 900, "kills": 7})
	_check(local.merge_cloud_profile(remote.cloud_profile()) and local.profile.total_kills == 57, "new remote increments added without double counting")
	_check(not local.merge_cloud_profile({"schema_version": 99, "best_score": 1000000}), "future cloud schema rejected")
	_check(not local.merge_cloud_profile({}), "empty cloud cannot reset local progress")
	_check(not local.merge_cloud_profile({"schema_version": 1, "best_score": 999999}), "incomplete cloud profile rejected")
	_check(local.profile.cloud.pending_scores.high_score == 900, "merged cloud records remain replayable")

func _test_disabled_adapter() -> void:
	var store := _store("adapter")
	var adapter: Node = PLAY_SCRIPT.new()
	adapter._store = store
	adapter.configuration = {"enabled": false, "game_id": "", "leaderboards": {}, "achievements": {}}
	root.add_child(adapter)
	var events: Array[String] = []
	adapter.local_leaderboards_requested.connect(func(): events.append("scores"))
	adapter.local_achievements_requested.connect(func(): events.append("achievements"))
	_check(adapter.status == "Local play" and adapter.get_child_count() == 0, "disabled adapter creates no native clients")
	_check(not adapter.is_available() and not adapter.is_authenticated(), "offline availability is explicit")
	_check(not adapter.show_leaderboards() and not adapter.show_achievements(), "offline UI calls return local route")
	_check(events == ["scores", "achievements"], "offline affordances emit local UI signals")
	store.add_run({"score": 123, "kills": 2})
	adapter.submit_run({"score": 123})
	adapter.sync_profile()
	adapter._process(0.1)
	_check(store.profile.cloud.pending_scores.high_score == 123 and adapter.status == "Local play", "disabled submissions preserve local queue")
	adapter.free()
	var unavailable: Node = PLAY_SCRIPT.new()
	unavailable._store = store
	unavailable.configuration = {"enabled": true, "game_id": "1234"}
	root.add_child(unavailable)
	_check(not unavailable.is_available() and unavailable.get_child_count() == 0, "configured desktop still needs actual Android singleton")
	unavailable.free()

func _test_cloud_adapter_callbacks() -> void:
	var store := _store("callbacks")
	var remote := _store("callbacks_remote")
	store.add_run({"score": 100, "kills": 3})
	remote.add_run({"score": 200, "kills": 4})
	var adapter: Node = PLAY_SCRIPT.new()
	adapter._store = store
	adapter.configuration = {"enabled": false, "game_id": "", "save_name": "test_profile"}
	root.add_child(adapter)
	var snapshots := FakeSnapshots.new()
	adapter.add_child(snapshots)
	adapter._snapshots = snapshots
	adapter._authenticated = true
	adapter._account_ready = true
	adapter.sync_profile()
	_check(snapshots.loads == 1 and adapter._operation == "load", "cloud sync loads before writing")
	adapter._on_game_loaded(FakeSnapshot.new(remote.cloud_profile()))
	_check(snapshots.saves == 1 and snapshots.payload.best_score == 200 and snapshots.payload.total_kills == 7,
		"cloud save contains merged progression")
	var written_revision: int = adapter._write_revision
	store.add_run({"score": 900, "kills": 8})
	adapter._on_game_saved(true, "test_profile", "test")
	_check(adapter._operation == "verify_wait" and store.profile.cloud.last_verified_revision == 0,
		"commit callback alone is not acknowledged before readback")
	adapter._verify_after = 0.0
	adapter._process(0.0)
	_check(snapshots.loads == 2 and adapter._operation == "verify", "commit callback starts readback")
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload))
	_check(store.profile.cloud.last_verified_revision == written_revision and store.profile.best_score == 900,
		"verified earlier write cannot erase newer local progress")
	adapter._scores_inflight["fake_board"] = {"key": "high_score", "value": 200, "deadline": INF}
	adapter._on_score_submitted(true, "fake_board")
	_check(store.profile.cloud.pending_scores.high_score == 900, "older score acknowledgment preserves newer pending best")
	adapter._operation = "verify"
	adapter._write_nonce = snapshots.payload.sync_nonce
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload, true))
	_check(adapter._cloud_suspended and adapter._operation.is_empty(), "pending native upload leaves local data replayable")
	var before: int = store.profile.total_kills
	adapter._on_game_loaded(FakeSnapshot.new({"schema_version": 1, "best_score": 99999999}))
	_check(store.profile.total_kills == before and store.profile.best_score == 900, "late cloud replies are ignored after suspension")
	adapter._cloud_suspended = false
	adapter._operation = "load"
	adapter._operation_deadline = 0.0
	adapter._dirty = false
	adapter._process(0.0)
	_check(adapter._cloud_suspended and store.profile.cloud.pending_scores.high_score == 900,
		"native timeout releases operation while retaining progress")
	adapter.free()

func _cloud_adapter(store: Node, snapshots: Node, slot: String) -> Node:
	var adapter: Node = PLAY_SCRIPT.new()
	adapter._store = store
	adapter.configuration = {"enabled": false, "game_id": "", "save_name": slot,
		"leaderboards": {}, "achievements": {}}
	root.add_child(adapter)
	adapter.set_process(false)
	adapter.add_child(snapshots)
	adapter._snapshots = snapshots
	adapter._authenticated = true
	adapter._account_ready = true
	return adapter

func _conflict_pair(name: String) -> Dictionary:
	var local := _store(name + "_local")
	var remote := _store(name + "_remote")
	local.add_run({"score": 100, "kills": 3, "bosses": 1, "duration": 12.5,
		"collected_powerups": 2})
	remote.add_run({"score": 11000, "kills": 4, "bosses": 5, "duration": 22.75,
		"combo": 30, "collected_powerups": 3})
	return {"local": local, "remote": remote,
		"server": FakeSnapshot.new(remote.cloud_profile()),
		"branch": FakeSnapshot.new(local.cloud_profile())}

func _test_resolved_cloud_conflict() -> void:
	var pair := _conflict_pair("resolve")
	var store: Node = pair.local
	var remote: Node = pair.remote
	store.profile.settings.music = false
	store.save_active_run({"seed": 814})
	var species: Array = store._known_monsters.keys()
	store.discover_monster(species[0])
	remote.discover_monster(species[1])
	pair.server = FakeSnapshot.new(remote.cloud_profile())
	pair.branch = FakeSnapshot.new(store.cloud_profile())
	var snapshots := FakeResolvingSnapshots.new()
	var adapter := _cloud_adapter(store, snapshots, "resolved_profile")
	adapter.sync_profile()
	_check(snapshots.loads == 1 and snapshots.resolutions.is_empty(), "conflict resolution begins only after a cloud read")
	adapter._on_conflict(FakeConflict.new("first-conflict", pair.server, pair.branch))
	_check(snapshots.resolutions.size() == 1 and snapshots.resolutions[0].id == "first-conflict",
		"validated conflict starts native resolution using the supplied conflict ID")
	_check(store.profile.total_runs == 2 and store.profile.total_kills == 7 and store.profile.total_bosses == 6,
		"conflict combines independent completed-run counters")
	_check(store.profile.collected_powerups == 5 and is_equal_approx(store.profile.total_played_seconds, 35.25),
		"conflict combines time and powerup counters")
	_check(store.profile.best_score == 11000 and store.profile.best_duration == 22.75 and
		store.profile.best_combo == 30 and store.profile.best_bosses == 5,
		"conflict keeps maximum competitive records")
	_check(store.profile.discovered.size() == 2 and store.profile.achievements.has("legend") and
		store.profile.achievements.has("score_10000"), "conflict unions species discoveries and earned badges")
	_check(not store.profile.settings.music and store.active_run.seed == 814,
		"conflict preserves device preferences and unfinished battle")
	var first: Dictionary = snapshots.resolutions[0]
	_check(first.played_ms == 35250 and first.progress == 7 and first.description.contains("11000"),
		"native resolution receives milliseconds, completed kills and the merged score description")
	_check(first.payload.total_kills == 7 and first.payload.best_score == 11000 and
		not first.payload.has("active_run") and not first.payload.has("cloud") and not first.payload.has("run_history"),
		"resolution uploads merged persistent progression without device-local simulation or request state")
	var nonce: String = first.payload.sync_nonce
	_check(nonce.length() == 32 and store.profile.cloud.last_verified_revision == 0 and adapter._operation == "save",
		"starting native resolution adds a nonce but does not acknowledge upload")
	adapter._on_conflict(FakeConflict.new("replacement-conflict", pair.server, pair.branch))
	_check(snapshots.resolutions.size() == 2 and store.profile.total_runs == 2 and store.profile.total_kills == 7,
		"repeated conflict branches are idempotent while native conflict IDs change")
	_check(snapshots.resolutions[1].payload.sync_nonce != nonce,
		"a replacement conflict write has a fresh nonce rather than reusing the earlier operation")
	var written_revision: int = adapter._write_revision
	store.add_run({"score": 22000, "kills": 8, "duration": 4})
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload))
	_check(store.profile.cloud.last_verified_revision == 0 and adapter._operation == "save",
		"readback arriving before the native commit callback cannot acknowledge conflict resolution")
	adapter._on_game_saved(true, "resolved_profile", "native commit complete")
	_check(adapter._operation == "verify_wait" and store.profile.cloud.last_verified_revision == 0,
		"native commit success still waits for matching conflict readback")
	adapter._verify_after = 0.0
	adapter._process(0.0)
	_check(snapshots.loads == 2 and adapter._operation == "verify", "resolved commit requests a verification read")
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload))
	_check(adapter._operation.is_empty() and store.profile.cloud.last_verified_revision == written_revision,
		"only matching non-pending readback acknowledges the resolved revision")
	_check(store.profile.best_score == 22000 and store.profile.total_kills == 15 and
		store.profile.cloud.pending_scores.high_score == 22000,
		"verified conflict write cannot erase newer local progress or a higher pending score")
	adapter.free()

func _test_conflict_resolution_fallbacks() -> void:
	for mode: String in ["legacy_wrapper", "unsupported_native", "empty_id", "native_rejected"]:
		var pair := _conflict_pair("fallback_" + mode)
		var store: Node = pair.local
		var snapshots: Node = FakeSnapshots.new() if mode == "legacy_wrapper" else FakeResolvingSnapshots.new()
		if mode == "unsupported_native": snapshots.available = false
		if mode == "native_rejected": snapshots.start_result = false
		var adapter := _cloud_adapter(store, snapshots, "fallback_profile")
		adapter.sync_profile()
		adapter._on_conflict(FakeConflict.new("" if mode == "empty_id" else "fallback-conflict", pair.server, pair.branch))
		_check(adapter._cloud_suspended and adapter._operation.is_empty(), "%s suspends unresolved cloud operations" % mode)
		_check(store.profile.best_score == 11000 and store.profile.total_kills == 7 and
			store.profile.cloud.pending_scores.high_score == 11000,
			"%s preserves useful merged progress and queued records" % mode)
		_check(store.reload_profile() and store.profile.total_kills == 7,
			"%s merged progress is durable on this device" % mode)
		_check(snapshots.saves == 0 and store.profile.cloud.last_verified_revision == 0,
			"%s does not substitute an ordinary overwrite or acknowledge a failed resolution" % mode)
		if mode != "legacy_wrapper":
			_check(snapshots.resolutions.size() == (1 if mode == "native_rejected" else 0),
				"%s starts native resolution only when supported with a nonempty ID" % mode)
		adapter._on_game_saved(true, "fallback_profile", "late result")
		_check(adapter._cloud_suspended and store.profile.cloud.last_verified_revision == 0,
			"%s rejects a late native acknowledgment after fallback" % mode)
		adapter.free()

func _test_invalid_conflict_branches() -> void:
	for mode: String in ["future_schema", "malformed_json", "missing_branch"]:
		var pair := _conflict_pair("invalid_" + mode)
		var store: Node = pair.local
		var invalid: Variant = FakeSnapshot.new(pair.remote.cloud_profile())
		if mode == "future_schema":
			var future: Dictionary = pair.remote.cloud_profile()
			future.schema_version = 99
			future.best_score = 999999
			invalid = FakeSnapshot.new(future)
		elif mode == "malformed_json":
			invalid.content = "{malformed".to_utf8_buffer()
		else:
			invalid = null
		var snapshots := FakeResolvingSnapshots.new()
		var adapter := _cloud_adapter(store, snapshots, "invalid_profile")
		adapter.sync_profile()
		adapter._on_conflict(FakeConflict.new("invalid-conflict", invalid, pair.server))
		_check(adapter._cloud_suspended and snapshots.resolutions.is_empty() and snapshots.saves == 0,
			"%s branch prevents remote conflict overwrite" % mode)
		_check(store.profile.best_score == 11000 and store.profile.total_kills == 7 and store.profile.total_runs == 2,
			"%s rejection still retains the valid branch's merged local progress" % mode)
		_check(store.reload_profile() and store.profile.best_score == 11000 and
			store.profile.cloud.last_verified_revision == 0,
			"%s preserves useful progress on disk without accepting unknown data" % mode)
		adapter.free()

func _test_conflict_retry_bound() -> void:
	var pair := _conflict_pair("bounded")
	var store: Node = pair.local
	var snapshots := FakeResolvingSnapshots.new()
	var adapter := _cloud_adapter(store, snapshots, "bounded_profile")
	adapter.sync_profile()
	for attempt in 11:
		adapter._on_conflict(FakeConflict.new("conflict-%d" % attempt, pair.server, pair.branch))
	_check(snapshots.resolutions.size() == 10 and adapter._cloud_suspended and adapter._operation.is_empty(),
		"a continually conflicting server is bounded to ten native resolution attempts")
	var nonces: Dictionary = {}
	for request: Dictionary in snapshots.resolutions:
		nonces[request.payload.sync_nonce] = true
	_check(nonces.size() == 10, "each bounded retry identifies its own merged write")
	_check(store.profile.total_runs == 2 and store.profile.total_kills == 7 and
		store.profile.cloud.pending_scores.high_score == 11000,
		"ten repeated conflicts do not inflate counters or discard replayable records")
	adapter._on_conflict(FakeConflict.new("eleventh-conflict", pair.server, pair.branch))
	_check(snapshots.resolutions.size() == 10 and store.profile.cloud.last_verified_revision == 0,
		"suspended retry exhaustion cannot restart an unbounded resolution loop")
	adapter.free()

func _test_conflict_timeout_and_late_callbacks() -> void:
	var pair := _conflict_pair("resolution_timeout")
	var store: Node = pair.local
	var snapshots := FakeResolvingSnapshots.new()
	var adapter := _cloud_adapter(store, snapshots, "timeout_profile")
	adapter.sync_profile()
	adapter._on_conflict(FakeConflict.new("slow-conflict", pair.server, pair.branch))
	adapter._operation_deadline = 0.0
	adapter._process(0.0)
	_check(adapter._cloud_suspended and adapter._operation.is_empty(), "timed-out native conflict resolution suspends safely")
	store.add_run({"score": 22000, "kills": 9})
	adapter._on_game_saved(true, "timeout_profile", "late commit")
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload))
	adapter._on_conflict(FakeConflict.new("late-conflict", pair.server, pair.branch))
	_check(store.profile.cloud.last_verified_revision == 0 and snapshots.resolutions.size() == 1,
		"late commit, readback and conflict callbacks cannot acknowledge or restart timed-out resolution")
	_check(store.profile.total_kills == 16 and store.profile.best_score == 22000 and
		store.profile.cloud.pending_scores.high_score == 22000,
		"late conflict callbacks preserve newer local counters, records and pending uploads")
	adapter.sync_profile()
	_check(snapshots.loads == 1 and adapter._cloud_suspended,
		"manual sync cannot reuse a session with ambiguous late native replies")
	adapter.free()

func _test_account_mismatch_blocks_cloud() -> void:
	var pair := _conflict_pair("account_mismatch")
	var store: Node = pair.local
	store.profile.cloud.player_id = "original-account"
	var snapshots := FakeResolvingSnapshots.new()
	var adapter := _cloud_adapter(store, snapshots, "account_profile")
	adapter._auth_pending = true
	adapter._on_player_loaded(FakePlayer.new("different-account"))
	adapter.sync_profile()
	_check(adapter._account_mismatch and not adapter.is_authenticated(), "detected account mismatch prevents authenticated cloud access")
	_check(snapshots.loads == 0 and snapshots.resolutions.is_empty() and snapshots.saves == 0,
		"account mismatch cannot start a load, overwrite or resolution for another Google player")
	_check(store.profile.cloud.player_id == "original-account" and store.profile.total_kills == 3 and
		store.profile.best_score == 100, "account mismatch keeps the original account binding and local progression")
	adapter.free()

func _test_cloud_read_failure_callbacks() -> void:
	var store := _store("initial_read_failure")
	store.add_run({"score": 1200, "kills": 10})
	store.save_active_run({"seed": 112})
	var snapshots := FakeSnapshots.new()
	var adapter := _cloud_adapter(store, snapshots, "read_profile")
	adapter.sync_profile()
	adapter._on_game_load_failed("different_slot", "unrelated failure")
	_check(not adapter._cloud_suspended and adapter._operation == "load" and snapshots.saves == 0,
		"a read error for another slot cannot cancel the pending profile read")
	adapter._on_game_load_failed("read_profile", "could not read snapshot contents")
	_check(adapter._cloud_suspended and adapter._operation.is_empty() and snapshots.saves == 0,
		"unreadable existing cloud data suspends sync without overwriting it as a missing save")
	_check(store.profile.best_score == 1200 and store.profile.total_kills == 10 and
		store.profile.cloud.pending_scores.high_score == 1200 and store.active_run.seed == 112,
		"initial read failure retains local progress, queued records and the unfinished battle")
	_check(store.reload_profile() and store.profile.cloud.pending_scores.high_score == 1200,
		"initial read failure leaves replayable progress on disk")
	adapter._on_game_loaded(null)
	adapter._on_game_load_failed("read_profile", "late read failure")
	_check(snapshots.saves == 0 and adapter._cloud_suspended and store.profile.cloud.last_verified_revision == 0,
		"late missing-save or error callbacks after read suspension cannot trigger an overwrite or acknowledgment")
	adapter.free()

	store = _store("verification_read_failure")
	store.add_run({"score": 3300, "kills": 5})
	snapshots = FakeSnapshots.new()
	adapter = _cloud_adapter(store, snapshots, "verify_profile")
	adapter.sync_profile()
	adapter._on_game_loaded(null)
	adapter._on_game_saved(true, "verify_profile", "committed")
	adapter._verify_after = 0.0
	adapter._process(0.0)
	_check(snapshots.saves == 1 and snapshots.loads == 2 and adapter._operation == "verify",
		"verification failure fixture has a committed write awaiting its actual readback")
	store.add_run({"score": 5000, "kills": 9})
	adapter._on_game_load_failed("different_slot", "unrelated verification failure")
	_check(adapter._operation == "verify" and not adapter._cloud_suspended,
		"verification read ignores errors for unrelated save slots")
	adapter._on_game_load_failed("verify_profile", "verification read failed")
	_check(adapter._cloud_suspended and snapshots.saves == 1 and store.profile.cloud.last_verified_revision == 0,
		"verification read failure cannot acknowledge a revision or write another replacement")
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload))
	_check(store.profile.best_score == 5000 and store.profile.total_kills == 14 and
		store.profile.cloud.pending_scores.high_score == 5000 and store.profile.cloud.last_verified_revision == 0,
		"late matching readback after a read error preserves newer progress without falsely verifying the earlier write")
	adapter.free()

	store = _store("late_idle_read_failure")
	store.add_run({"score": 700, "kills": 2})
	snapshots = FakeSnapshots.new()
	adapter = _cloud_adapter(store, snapshots, "idle_profile")
	adapter.sync_profile()
	adapter._on_game_loaded(null)
	var written_revision: int = adapter._write_revision
	adapter._on_game_saved(true, "idle_profile", "committed")
	adapter._verify_after = 0.0
	adapter._process(0.0)
	adapter._on_game_loaded(FakeSnapshot.new(snapshots.payload))
	adapter._on_game_load_failed("idle_profile", "late unrelated failure")
	_check(adapter._operation.is_empty() and not adapter._cloud_suspended and
		store.profile.cloud.last_verified_revision == written_revision,
		"an idle late error cannot revoke an already verified write or suspend a finished operation")
	adapter.free()

func _test_daily_score_routing() -> void:
	var store := _store("daily_routing")
	var adapter := DatedPlayServices.new()
	adapter._store = store
	adapter.configuration = {"enabled": false, "game_id": "", "leaderboards": {"daily_score": "daily_board"}}
	root.add_child(adapter)
	var board := FakeLeaderboards.new()
	adapter.add_child(board)
	adapter._leaderboards = board
	adapter._authenticated = true
	adapter._account_ready = true
	# A neighboring date can hold a larger score; submit only the UTC challenge's date.
	store.profile.daily_best = {"2040-02-29": 999, "2040-03-01": 888}
	adapter._flush_scores()
	_check(board.submissions.size() == 1 and board.submissions[0] == {"board": "daily_board", "score": 888},
		"daily native board selects challenge date rather than larger adjacent-day best")
	adapter._on_score_submitted(true, "daily_board")
	adapter.test_date = "2040-03-02"
	store.profile.daily_best[adapter.test_date] = 77
	adapter._flush_scores()
	_check(board.submissions.size() == 2 and board.submissions[1].score == 77,
		"UTC day rollover routes the new date's own score")
	adapter._on_score_submitted(true, "daily_board")
	adapter.test_date = "2040-03-03"
	adapter._flush_scores()
	_check(board.submissions.size() == 2, "missing current challenge date does not upload an older day's record")
	adapter.free()
	var production: Node = PLAY_SCRIPT.new()
	_check(production._challenge_date() == Time.get_date_string_from_system(true), "production challenge date uses the game's UTC convention")
	production.free()
