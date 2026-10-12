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

class FakeLeaderboards extends Node:
	var submissions: Array[Dictionary] = []
	func submit_score(board_id: String, score: int) -> void:
		submissions.append({"board": board_id, "score": score})

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
	_test_defaults_and_records()
	_test_storage_and_backup()
	_test_normalization()
	_test_daily_and_history()
	_test_discovery()
	_test_cloud_merge()
	_test_disabled_adapter()
	_test_cloud_adapter_callbacks()
	_test_daily_score_routing()
	for store: Node in _stores:
		store.free()
	print("Service tests: %d checks, %d failures" % [_checks, _failures])
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
		await create_timer(0.35).timeout
	quit(0 if _failures == 0 else 1)

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
	backup.save_active_run({"huge": "x".repeat(140000)})
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
	_check(store._known_monsters.size() == 100, "exactly one hundred generated species are known")
	var keys: Array = store._known_monsters.keys()
	_check(not store.discover_monster("missing_species"), "unknown discovery rejected")
	_check(store.discover_monster(keys[0]) and not store.discover_monster(keys[0]), "discovery is unique")
	for key: String in keys.slice(1):
		store.discover_monster(key)
	_check(store.profile.discovered.size() == 100 and store.profile.achievements.has("collector"), "all generated species unlock collector")
	_check(store.reload_profile() and store.profile.discovered.size() == 100, "discovery round trip")

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
		"early vendor success is not treated as durable commit")
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
