extends SceneTree
## Real interface input/layout tests. No native ad is loaded or displayed.

const Interface = preload("res://scripts/game_ui.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
var failures: Array[String] = []
var checks := 0
var rewarded_requests := 0
var declines := 0
var privacy_requests := 0
var selections: Array[String] = []
var overlays: Array[String] = []
var layouts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("AD UI: " + message)


func settle() -> void:
	await process_frame
	await process_frame
	await process_frame


func click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
	await settle()


func inside_clip(ui, name: String) -> void:
	var button: Button = ui.find_child(name, true, false)
	check(button != null and button.is_visible_in_tree(), name + " remains visible")
	if button == null:
		return
	ui._card_scroll.ensure_control_visible(button)
	await settle()
	var clip: Rect2 = ui._card_scroll.get_global_rect()
	check(clip.encloses(button.get_global_rect()), name + " is reachable entirely inside the reserved ad-free band")
	check(button.size.x >= 42 and button.size.y >= 42, name + " keeps a one-hand touch target")


func _run() -> void:
	root.get_node("SaveData").configure_storage("res://output/test-data/ad_ui_profile.json")
	root.get_node("AudioManager").set_enabled(false)
	var ui = Interface.new()
	root.add_child(ui)
	ui.rewarded_continue_requested.connect(func(): rewarded_requests += 1)
	ui.continue_declined.connect(func(): declines += 1)
	ui.privacy_options_requested.connect(func(): privacy_requests += 1)
	ui.upgrade_selected.connect(func(id: String): selections.append(id))
	ui.overlay_changed.connect(func(kind: String): overlays.append(kind))
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1110), Vector2i(1080, 1920)]:
		root.size = dimensions
		await settle()
		ui.set_ad_banner_space(0, 0)
		ui.show_launch(false, 12345)
		await settle()
		var original_top: float = ui._top
		var original_bottom: float = ui._bottom
		var native_height := float(DisplayServer.window_get_size().y)
		if native_height <= 0:
			native_height = float(DisplayServer.screen_get_size().y)
		var factor: float = ui._size.y / native_height if native_height > 0 else 1.0
		ui.set_ad_banner_space(100, 160)
		await settle()
		check(is_equal_approx(ui._ad_top_logical, 100 * factor), "native top height converts into logical viewport coordinates")
		check(ui._ad_bottom_logical == 0, "home never reserves the bottom banner")
		check(is_equal_approx(ui._top, original_top + 100 * factor + 8), "home adds the real top banner and a small touch gap")
		await inside_clip(ui, "SwordButton")
		await inside_clip(ui, "ShieldButton")
		await inside_clip(ui, "AudioSettingsButton")
		ui.show_pause()
		await settle()
		check(ui._ad_top_logical > 0 and ui._ad_bottom_logical == 0, "pause uses only the top banner")
		check(ui.find_child("HealthBar", true, false).position.y >= ui._top, "paused health/score controls stay below the native banner")
		check(ui.find_child("PauseButton", true, false).position.y + 5 >= ui._top, "paused pause button stays below the native banner")
		await inside_clip(ui, "ResumeButton")
		await inside_clip(ui, "LeaderboardButton")
		await inside_clip(ui, "AchievementsButton")
		ui.show_audio_settings()
		await settle()
		check(ui._ad_top_logical == 0 and ui._ad_bottom_logical == 0, "audio excludes stale banner reservations")
		ui.set_privacy_options_required(false)
		check(not ui.find_child("PrivacyOptionsButton", true, false).is_visible_in_tree(), "privacy entry is hidden when UMP does not require it")
		ui.set_privacy_options_required(true)
		await settle()
		await inside_clip(ui, "PrivacyOptionsButton")
		await click(ui.find_child("PrivacyOptionsButton", true, false))
		check(ui._overlay_kind == "audio", "opening native privacy options does not replace local settings state")
		ui.set_privacy_options_required(false)
		ui.close_auxiliary_overlay()
		check(ui._overlay_kind == "pause" and ui._ad_top_logical > 0, "returning from audio restores paused top-banner layout")
		var choices: Array = []
		for id in ["phoenix_oath", "worldbreaker"]:
			choices.append(Upgrades.get_upgrade(id))
		ui.show_upgrade_choices(choices, 25)
		await settle()
		check(ui._ad_top_logical == 0 and is_equal_approx(ui._ad_bottom_logical, 160 * factor), "level-up choices use only the actual bottom banner height")
		check(ui._card_scroll.get_global_rect().end.y <= ui._size.y - ui._bottom, "upgrade scroll clip ends before the banner/touch-safe region")
		check(ui._card_scroll.clip_contents, "long upgrade content is clipped rather than drawn under a native banner")
		await inside_clip(ui, "UpgradeChoice1")
		await inside_clip(ui, "UpgradeChoice2")
		check(not ui.close_auxiliary_overlay(), "banner layout does not add a pending-upgrade back/skip bypass")
		await inside_clip(ui, "AudioSettingsButton")
		await click(ui.find_child("AudioSettingsButton", true, false))
		check(ui._overlay_kind == "audio" and ui._ad_bottom_logical == 0, "upgrade audio excludes the bottom banner")
		ui.close_auxiliary_overlay()
		await settle()
		check(ui._overlay_data.choices == choices and ui._overlay_data.level == 25, "audio preserves exact pending level choices")
		await inside_clip(ui, "UpgradeChoice1")
		await click(ui.find_child("UpgradeChoice1", true, false))
		ui.find_child("UpgradeChoice2", true, false).pressed.emit()
		check(selections.size() == layouts.size() + 1, "upgrade remains a one-shot selection with banner reservation")
		for kind in ["scores", "achievements", "end", "continue", "ad_waiting"]:
			match kind:
				"scores": ui.show_scores({}, "Offline")
				"achievements": ui.show_achievements({})
				"end": ui.show_end({})
				"continue": ui.show_continue_offer()
				"ad_waiting": ui.show_ad_waiting()
			await settle()
			check(ui._ad_top_logical == 0 and ui._ad_bottom_logical == 0, kind + " ignores stale native banner heights")
		ui.show_continue_offer()
		await settle()
		await inside_clip(ui, "RewardedContinueButton")
		await inside_clip(ui, "DeclineContinueButton")
		check(not ui.close_auxiliary_overlay(), "continue offer has no accidental resume route")
		var watch: Button = ui.find_child("RewardedContinueButton", true, false)
		var skip: Button = ui.find_child("DeclineContinueButton", true, false)
		await click(watch)
		watch.pressed.emit()
		skip.pressed.emit()
		check(rewarded_requests == layouts.size() + 1 and declines == layouts.size(), "watch tap emits once and blocks the competing end-run tap")
		ui.show_ad_waiting()
		check(ui.find_child("RewardedContinueButton", true, false).disabled, "stale reward card is disabled while it awaits deferred cleanup")
		await settle()
		check(ui._card.find_children("*", "Button", true, false).is_empty(), "ad waiting has no duplicate request or resume buttons")
		ui.show_continue_offer()
		await settle()
		await click(ui.find_child("DeclineContinueButton", true, false))
		ui.find_child("DeclineContinueButton", true, false).pressed.emit()
		check(declines == layouts.size() + 1, "end-run choice emits exactly once")
		ui.show_end({"score": 12345})
		await settle()
		await inside_clip(ui, "SwordButton")
		await inside_clip(ui, "ShieldButton")
		ui.show_launch(false, 0)
		ui.set_ad_banner_space(0, 0)
		await settle()
		check(ui._ad_top_logical == 0 and ui._ad_bottom_logical == 0 and ui._top == original_top and ui._bottom == original_bottom, "no inventory returns immediately to the original no-ad spacing")
		ui.set_ad_banner_space(-1, NAN)
		check(ui._ad_top_px == 0 and ui._ad_bottom_px == 0, "invalid SDK heights cannot create reserved space")
		ui.hide_overlay()
		check(ui._ad_top_logical == 0 and ui._ad_bottom_logical == 0, "live combat reserves no ad area")
		layouts.append({"window": [dimensions.x, dimensions.y], "viewport": [ui._size.x, ui._size.y], "physical_to_logical": factor})
	check(privacy_requests == 3, "privacy entry emits one request per real GUI click at all three sizes")
	for kind in ["launch", "pause", "audio", "upgrade", "scores", "achievements", "end", "continue", "ad_waiting", ""]:
		check(kind in overlays, "root can manage banners from overlay signal: " + kind)
	var report := {"pass": failures.is_empty(), "checks": checks, "failures": failures, "layouts": layouts, "native_ads_requested": false}
	var file := FileAccess.open("res://output/review/ad_ui_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("AD_UI_TESTS: %d checks, %d failures" % [checks, failures.size()])
	ui.queue_free()
	root.get_node("AudioManager").stop_for_shutdown()
	await settle()
	quit(0 if failures.is_empty() else 1)
