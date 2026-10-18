extends SceneTree
## Actual game-scene ad lifecycle tests. No native SDK, ad request or real profile.

class FakeAds extends Node:
	signal banner_space_changed(top_px: float, bottom_px: float)
	signal availability_changed(rewarded_ready: bool)
	signal fullscreen_started(kind: String)
	signal fullscreen_finished(kind: String, earned: bool)
	signal privacy_options_changed(required: bool)
	var rewarded_ready := true
	var show_allowed := true
	var fullscreen := ""
	var placement := ""
	var active := true
	var completed := 0
	var rewarded_requests := 0
	var interstitial_requests := 0
	func set_banner_placement(value: String) -> void: placement = value
	func set_app_active(value: bool) -> void: active = value
	func get_fullscreen_kind() -> String: return fullscreen
	func is_privacy_options_required() -> bool: return false
	func show_privacy_options() -> bool: return false
	func is_rewarded_ready() -> bool: return rewarded_ready and fullscreen.is_empty() and active
	func record_completed_game() -> void: completed += 1
	func show_interstitial_if_due() -> bool:
		interstitial_requests += 1
		return false
	func show_rewarded_continue() -> bool:
		rewarded_requests += 1
		if not show_allowed or not is_rewarded_ready(): return false
		rewarded_ready = false
		begin("rewarded")
		return true
	func begin(kind: String) -> void:
		fullscreen = kind
		fullscreen_started.emit(kind)
	func finish(kind: String, earned := false) -> void:
		fullscreen = ""
		fullscreen_finished.emit(kind, earned)

var game: Variant
var ads: FakeAds
var save: Variant
var audio: Variant
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error("ADS GAME: " + description)

func reset() -> void:
	game._ad_fullscreen_kind = ""
	game._set_ad_app_active(true)
	ads.fullscreen = ""
	ads.rewarded_ready = true
	ads.show_allowed = true
	game.testing = true
	game.demo = false
	game.start_run("shield")
	game.set_process(false)
	game.set_physics_process(false)
	game.spawn_timer = 10000.0
	game.next_boss = 10000.0
	game.swing_timer = 10000.0
	game.hurt_timer = 0.0
	game.score = 12345
	game.kills = 100
	game.bosses = 5
	game.elapsed = 180.0
	game.combo = 32
	game.best_combo = 40
	game.combo_timer = 2.5
	game.level = 30
	game.buffs = {"frost": 7.0}
	game.guard_reserve = 0.0
	game.damage = 222.0
	game.second_wind = 1.0
	game.second_wind_used = true
	game.upgrade_counts = {"sharper_steel": 3}

func die() -> void:
	game.health = 0.0
	game.end_run()

func _run() -> void:
	save = root.get_node("SaveData")
	audio = root.get_node("AudioManager")
	save.configure_storage(ProjectSettings.globalize_path("res://output/test-data/admob-game/%d.json" % Time.get_ticks_usec()))
	audio.set_enabled(false)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	ads = FakeAds.new()
	root.add_child(ads)
	game.bind_ads_service(ads)
	await process_frame
	_test_success()
	_test_unavailable_declined_failed()
	_test_focus_and_privacy()
	_test_snapshot()
	_test_non_run_fullscreen_saves()
	await _test_final_records()
	await _test_recovered_boot()
	game.bind_ads_service(null)
	game.queue_free()
	ads.queue_free()
	audio.set_external_paused(false)
	audio.stop_for_shutdown()
	await process_frame
	var report := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "native_ads_requested": false}
	var out := FileAccess.open("res://output/review/admob_game_validation.json", FileAccess.WRITE)
	if out != null: out.store_string(JSON.stringify(report, "\t"))
	print("ADS_GAME_TESTS checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_success() -> void:
	reset()
	die()
	check(game.state == "continue_offer" and not game._run_finalized, "eligible death pauses for an optional continue")
	check(game.ad_death_pending and not game.rewarded_continue_used, "offer is not itself a consumed continue")
	var before: Dictionary = game.serialize_run()
	game.tick(3.0)
	check(game.elapsed == 180.0 and game.buffs.frost == 7.0 and game.combo_timer == 2.5, "offer freezes timers and combo")
	game._request_rewarded_continue()
	check(game.state == "ad_showing" and game.rewarded_continue_used, "watch starts one SDK session and consumes the only continue")
	check(audio._external_paused, "game audio is suspended during native fullscreen")
	game.tick(5.0)
	game.choose_upgrade("sharper_steel")
	game.start_run("sword")
	check(game.state == "ad_showing" and game.score == 12345 and game.damage == 222, "native fullscreen blocks gameplay, choices and restarts")
	var requests: int = ads.rewarded_requests
	game._request_rewarded_continue()
	check(ads.rewarded_requests == requests, "double taps cannot show another rewarded ad")
	ads.finish("rewarded", true)
	check(game.state == "running" and game.health == game.max_health and game.guard_reserve == game.guard_capacity, "earned reward plus dismissal restores full health and guard")
	check(not game.ad_death_pending and game.rewarded_continue_used and not game._run_finalized, "successful continue remains the same unfinished run")
	check(not audio._external_paused and not audio.is_music_enabled() and not audio.is_sfx_enabled(), "closing ad restores audio without changing preferences")
	var after: Dictionary = game.serialize_run()
	for key: String in ["score", "kills", "bosses", "powerups", "combo", "best_combo", "combo_timer", "elapsed", "level", "xp", "damage", "attack_interval", "attack_range", "seed", "rng_state", "loot_state", "upgrade_state", "boss_state", "buffs", "enemies", "bullets", "hazards", "drops", "upgrade_counts", "upgrade_choices", "player", "max_health", "guard_capacity", "guard_regen", "guard_delay", "move_speed", "dash_recharge", "lifesteal", "thorns", "second_wind", "second_wind_used", "execute_threshold", "combo_grace", "overdrive_charge", "overdrive_time", "ward_hits", "dash_cooldown"]:
		check(after[key] == before[key], "continue preserves " + key)
	check(game.hurt_timer >= 1.5, "brief return protection prevents an unavoidable immediate second death")
	game.health = 19.0
	game._on_ad_fullscreen_finished("rewarded", true)
	check(game.health == 19.0, "duplicate or stale dismissal cannot grant another restore")
	ads.rewarded_ready = true
	die()
	check(game.state == "dead", "second death finishes even with another ad in inventory")

func _test_unavailable_declined_failed() -> void:
	reset()
	ads.rewarded_ready = false
	die()
	check(game.state == "dead" and not game.rewarded_continue_used, "no inventory follows normal results immediately")
	reset()
	die()
	game._decline_rewarded_continue()
	check(game.state == "dead" and not game.rewarded_continue_used, "declining the offer finishes normally")
	reset()
	die()
	ads.rewarded_ready = false
	game._request_rewarded_continue()
	check(game.state == "dead", "inventory lost between offer and tap finishes safely")
	reset()
	die()
	ads.show_allowed = false
	game._request_rewarded_continue()
	check(game.state == "dead", "a synchronous native show failure cannot leave the run waiting")
	reset()
	die()
	game._request_rewarded_continue()
	ads.finish("rewarded", false)
	check(game.state == "dead" and game.health == 0.0, "closing or failing without SDK-earned reward grants no health")
	reset()
	die()
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.state == "dead", "Android Back declines the optional continue")

func _test_focus_and_privacy() -> void:
	reset()
	die()
	game._request_rewarded_continue()
	game._set_ad_app_active(false)
	ads.finish("rewarded", true)
	check(game.state == "paused" and game.health == game.max_health and audio._external_paused, "earned reward cannot resume simulation or audio behind another activity")
	game._set_ad_app_active(true)
	check(game.state == "running" and not audio._external_paused, "returning focus resumes the earned continue")
	game.pause_run()
	check(ads.placement == "pause", "pause overlay requests its top banner")
	game.hud.show_audio_settings()
	check(ads.placement == "", "auxiliary settings screen hides the banner")
	ads.begin("privacy")
	var frozen: float = game.elapsed
	game.tick(3)
	check(game.elapsed == frozen and game.state == "ad_showing", "privacy form also freezes the game")
	ads.finish("privacy", false)
	check(game.state == "paused" and game.hud._overlay_kind == "audio", "privacy dismissal preserves the settings panel")
	game.hud.show_pause()
	game._set_ad_app_active(false)
	check(ads.placement == "", "backgrounding hides native banners")
	game._set_ad_app_active(true)
	check(ads.placement == "pause", "focus restores only the currently supported banner placement")

func _test_snapshot() -> void:
	reset()
	die()
	var pending: Dictionary = game.serialize_run()
	check(game.restore_run(pending) and game.health == 0 and game.ad_death_pending, "interrupted death snapshot restores as dead, without a free health point")
	game._finalize_run()
	check(game.state == "dead", "unearned interrupted continue finishes instead of offering another life")
	reset()
	die()
	game._request_rewarded_continue()
	ads.finish("rewarded", true)
	var used: Dictionary = game.serialize_run()
	check(game.restore_run(used) and game.rewarded_continue_used, "used continue survives active-run restore")
	game.resume_run()
	die()
	check(game.state == "dead", "restart cannot reset the one-continue limit")
	used.erase("rewarded_continue_used")
	used.erase("ad_death_pending")
	check(game.restore_run(used) and not game.rewarded_continue_used, "legacy healthy snapshots keep the available first continue")
	for key: String in ["rewarded_continue_used", "ad_death_pending"]:
		var invalid: Dictionary = used.duplicate(true)
		invalid[key] = "true"
		check(not game.restore_run(invalid), "invalid ad snapshot flag is rejected: " + key)
	var invalid_death: Dictionary = used.duplicate(true)
	invalid_death.health = 0
	check(not game.restore_run(invalid_death), "ordinary zero-health snapshot remains invalid")

func _test_non_run_fullscreen_saves() -> void:
	reset()
	save.clear_active_run()
	game._show_launch()
	game.testing = false
	ads.begin("consent")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(save.active_run.is_empty(), "backgrounding startup consent cannot create a fake resumable run")
	ads.finish("consent", false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.state == "launch", "startup consent returns to the original class selection")
	reset()
	game.testing = false
	ads.rewarded_ready = false
	die()
	check(save.active_run.is_empty(), "completed run has no active snapshot")
	ads.begin("interstitial")
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(save.active_run.is_empty(), "backgrounding the results interstitial cannot recreate the completed run")
	ads.finish("interstitial", false)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(game.state == "dead", "results interstitial returns to the same completed result")
	game.testing = true

func _test_final_records() -> void:
	reset()
	game.testing = false
	var completed_before: int = save.profile.total_runs
	var ad_count_before: int = ads.completed
	die()
	check(save.profile.total_runs == completed_before and save.active_run.ad_death_pending, "offering continue durably saves death without prematurely finishing a run")
	game._request_rewarded_continue()
	check(save.active_run.rewarded_continue_used and save.active_run.health == 0, "pending native ad cannot reload the earlier healthy autosave")
	ads.finish("rewarded", true)
	check(save.active_run.health == game.max_health and save.active_run.rewarded_continue_used, "earned revive is saved before gameplay resumes")
	check(save.profile.total_runs == completed_before and ads.completed == ad_count_before, "rewarded life itself is not another game played")
	die()
	check(save.profile.total_runs == completed_before + 1 and ads.completed == ad_count_before + 1, "final death records and counts this game exactly once")
	check(save.profile.best_score >= 12345 and save.profile.best_level >= 30 and save.profile.best_combo >= 40, "continued run retains full competitive eligibility")
	for key: String in ["hundred_club", "legend", "score_10000", "survivor_180", "combo_25"]:
		check(save.profile.achievements.has(key), "continued run retains run-based achievement eligibility: " + key)
	game._finalize_run()
	check(save.profile.total_runs == completed_before + 1 and ads.completed == ad_count_before + 1, "duplicate finalization cannot double-submit records or ad cadence")
	await process_frame
	check(ads.interstitial_requests >= 1, "interstitial check occurs at the final results break")
	game.testing = true

func _test_recovered_boot() -> void:
	# This script owns a fresh fixture path, so the real launch restoration path
	# can safely run without the game's --test bypass.
	check(not "--test" in OS.get_cmdline_user_args(), "runner exercises actual cold-boot restoration without the --test bypass")
	if "--test" in OS.get_cmdline_user_args(): return
	reset()
	die()
	save.save_active_run(game.serialize_run())
	var previous_runs: int = save.profile.total_runs
	var recovered: Variant = load("res://scenes/main.tscn").instantiate()
	root.add_child(recovered)
	recovered.set_process(false)
	recovered.set_physics_process(false)
	check(recovered.state == "dead" and recovered.health == 0 and recovered._run_finalized,
		"real startup finalizes an interrupted unearned continue instead of presenting Resume")
	check(save.active_run.is_empty() and save.profile.total_runs == previous_runs + 1,
		"recovered death commits exactly one result and clears its pending snapshot")
	recovered._finalize_run()
	check(save.profile.total_runs == previous_runs + 1, "recovered death cannot be counted twice")
	recovered.queue_free()
	await process_frame
