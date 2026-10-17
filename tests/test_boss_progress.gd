extends SceneTree
## Defeat discovery survives abandoned runs and merges as a validated cloud set.

const Store = preload("res://scripts/services/save_data.gd")
const Catalog = preload("res://scripts/boss_catalog.gd")
var checks := 0
var failures := 0
var fixture_root := ""
var stores: Array[Node] = []

func _initialize() -> void:
	fixture_root = "res://output/test-data/boss-progress/%s" % str(Time.get_ticks_usec())
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("BOSS PROGRESS: " + message)

func _store(name: String) -> Node:
	var store: Node = Store.new()
	store.storage_path = fixture_root.path_join(name + ".json")
	root.add_child(store)
	stores.append(store)
	return store

func _run() -> void:
	_test_immediate_victory()
	_test_normalization_and_legacy()
	_test_cloud_union()
	_test_pending_configuration()
	for store: Node in stores:
		store.free()
	print("Boss progression tests: %d checks, %d failures" % [checks, failures])
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
		await create_timer(0.35).timeout
	quit(0 if failures == 0 else 1)

func _test_immediate_victory() -> void:
	var store := _store("instant")
	_check(store.profile.defeated_bosses.is_empty(), "new profiles start with no defeated boss identities")
	store.save_active_run({"schema": 1, "health": 20, "elapsed": 91})
	var unlocked: Array[String] = []
	store.achievement_unlocked.connect(func(key: String): unlocked.append(key))
	_check(store.record_boss_defeat("tinpot_tyrant"), "first valid defeat is recorded")
	_check(store.profile.defeated_bosses == ["tinpot_tyrant"] and store.profile.total_bosses == 0 \
		and store.profile.total_runs == 0, "defeat discovery does not inflate completed-run counters")
	_check(not store.profile.achievements.has("rare_boss"), "common boss does not unlock rare boss badge")
	var revision := int(store.profile.revision)
	_check(not store.record_boss_defeat("tinpot_tyrant") and not store.record_boss_defeat("unknown") \
		and store.profile.revision == revision, "duplicate or unknown defeat does not rewrite storage")
	_check(store.discover_boss("moonmallow_majesty"), "discovery alias records a known rare boss")
	_check(store.profile.achievements.has("rare_boss") and unlocked.count("rare_boss") == 1 \
		and "rare_boss" in store.profile.cloud.pending_achievements, "rare victory immediately unlocks and queues Royal Upset once")
	var reloaded := _store("instant")
	_check(reloaded.profile.defeated_bosses == store.profile.defeated_bosses \
		and reloaded.profile.achievements.has("rare_boss"), "boss discovery and badge survive reload before the run ends")
	_check(reloaded.active_run.get("elapsed", 0) == 91, "immediate victory storage preserves suspended combat")

func _test_normalization_and_legacy() -> void:
	var store := _store("normalization")
	var malformed: Dictionary = store.profile.duplicate(true)
	malformed.defeated_bosses = ["tinpot_tyrant", "tinpot_tyrant", "unknown", 99, null, "lime_imperator"]
	store.profile = malformed
	store.save_profile()
	_check(store.profile.defeated_bosses == ["lime_imperator", "tinpot_tyrant"], "normalization validates, deduplicates and sorts stable IDs")
	var legacy: Dictionary = store.cloud_profile()
	legacy.erase("defeated_bosses")
	var normalized: Dictionary = store._normalize_profile(legacy)
	_check(normalized.defeated_bosses.is_empty() and normalized.device_id == store.profile.device_id, "old schema-one saves load with empty boss discovery without resetting progress")
	legacy.defeated_bosses = {"tinpot_tyrant": true}
	normalized = store._normalize_profile(legacy)
	_check(normalized.defeated_bosses.is_empty(), "incorrect collection types are ignored safely")
	var ids := Catalog.ids()
	for id: String in ids:
		store.record_boss_defeat(id)
	_check(store.profile.defeated_bosses.size() == 12 and store.profile.achievements.has("all_bosses"), "all unique boss identities unlock Crown Census")

func _test_cloud_union() -> void:
	var left := _store("cloud_left")
	var right := _store("cloud_right")
	var ids := Catalog.ids()
	for index: int in range(ids.size()):
		if index < 6:
			left.record_boss_defeat(ids[index])
		else:
			right.record_boss_defeat(ids[index])
	_check(not left.profile.achievements.has("all_bosses") and not right.profile.achievements.has("all_bosses"), "each device alone has only half the boss census")
	var remote: Dictionary = right.cloud_profile()
	_check(left.merge_cloud_profile(remote), "cloud merge imports unseen boss victories")
	_check(left.profile.defeated_bosses.size() == 12 and left.profile.achievements.has("all_bosses") \
		and "all_bosses" in left.profile.cloud.pending_achievements, "merged boss census unlocks locally and queues Google badge")
	_check(not left.merge_cloud_profile(remote), "replaying the same boss discovery snapshot is idempotent")
	_check(right.merge_cloud_profile(left.cloud_profile()) and right.profile.defeated_bosses == left.profile.defeated_bosses,
		"two devices converge on the full sorted boss set")
	var reloaded := _store("cloud_left")
	_check(reloaded.profile.defeated_bosses == left.profile.defeated_bosses \
		and reloaded.profile.achievements.has("all_bosses"), "cloud merged census and badge persist to disk")
	var old_remote: Dictionary = left.cloud_profile()
	old_remote.erase("defeated_bosses")
	right.merge_cloud_profile(old_remote)
	_check(right.profile.defeated_bosses.size() == 12, "older cloud snapshot cannot erase boss discovery")

func _test_pending_configuration() -> void:
	var configuration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://config/play_services.json"))
	_check(configuration.achievements.get("rare_boss", "missing") == "CgkI5NXU8p0YEAIQEA" \
		and configuration.achievements.get("all_bosses", "missing") == "CgkI5NXU8p0YEAIQEQ", "both boss badges retain the owner-provided Google IDs")
	_check(not configuration.incremental_achievements.has("rare_boss") \
		and not configuration.incremental_achievements.has("all_bosses"), "new badges are Standard rather than Incremental")
