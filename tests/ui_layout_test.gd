extends SceneTree
## Exercises the actual overlay buttons and portrait layout without touching a run.

const Interface = preload("res://scripts/game_ui.gd")
const World = preload("res://scripts/world.gd")
const ClassProfiles = preload("res://scripts/class_profiles.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
var _failures: Array[String] = []
var _styles: Array[String] = []
var _resume_count := 0
var _pause_count := 0
var _audio_changes: Array = []
var _upgrades: Array[String] = []
var _layouts: Array = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := root.get_node_or_null("AudioManager")
	if audio != null:
		audio.set_enabled(false)
	var services := root.get_node_or_null("SaveData")
	if services != null:
		services.configure_storage("res://output/review/ui_test_profile.json")
	var world := World.new()
	root.add_child(world)
	var ui := Interface.new()
	root.add_child(ui)
	ui.start_requested.connect(func(style: String): _styles.append(style))
	ui.resume_requested.connect(func(): _resume_count += 1)
	ui.pause_requested.connect(func():
		_pause_count += 1
		ui.show_pause()
	)
	ui.audio_setting_changed.connect(func(key: String, enabled: bool): _audio_changes.append([key, enabled]))
	ui.upgrade_selected.connect(func(id: String): _upgrades.append(id))
	ui.achievements_requested.connect(func(): ui.show_achievements({"achievements": {"first_blood": 1}}))
	var viewport_index := 0
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1110), Vector2i(1080, 1920)]:
		viewport_index += 1
		root.size = dimensions
		await process_frame
		await process_frame
		world.reset()
		world.advance(0.1, 375.0)
		_check(is_equal_approx(world.elapsed, 375.0), "World elapsed contract")
		ui.show_launch(false, 15023)
		await process_frame
		await process_frame
		_check_buttons(ui, ["SwordButton", "ShieldButton"])
		_check_style_cards(ui)
		_check(ui.find_child("LeaderboardButton", true, false) == null, "Launch has no utility menu")
		ui.set_audio_settings({"music": true, "sfx": true})
		await _click_button(ui, "AudioSettingsButton")
		_check_buttons(ui, ["MusicToggle", "SfxToggle", "AudioBackButton"])
		await _click_button(ui, "MusicToggle")
		_check(ui.get("_audio_settings") == {"music": false, "sfx": true}, "Music can be disabled while effects remain enabled")
		await _click_button(ui, "SfxToggle")
		_check(ui.get("_audio_settings") == {"music": false, "sfx": false}, "Both audio channels can be disabled")
		await _click_button(ui, "MusicToggle")
		_check(ui.get("_audio_settings") == {"music": true, "sfx": false}, "Music can remain enabled with effects disabled")
		await _click_button(ui, "AudioBackButton")
		_check(ui.get("_overlay_kind") == "launch", "Audio returns to launch without starting a run")
		await _click_button(ui, "SwordButton")
		await _click_button(ui, "ShieldButton")
		ui.show_launch(true, 15023)
		await process_frame
		await process_frame
		_check_buttons(ui, ["ResumeButton", "SwordButton", "ShieldButton"])
		_check_style_cards(ui)
		ui.find_child("ResumeButton", true, false).pressed.emit()
		ui.hide_overlay()
		ui.update_hud({"boss_name": "", "boss_max": 1.0, "boss_hp": 0.0})
		_check(not ui.find_child("BossHealthBar", true, false).visible, "No boss bar outside a boss fight")
		ui.update_hud({"style": "shield", "health": 64.5, "max_health": 170, "score": 15823, "best": 15900,
			"level": 7, "xp": 4, "xp_goal": 10, "combo": 25, "multiplier": 3,
			"dash_ready": false, "dash_cooldown": 0.7, "guard_ratio": 0.4, "boss_name": "The Tinpot King",
			"boss_hp": 232, "boss_max": 700, "elapsed": 181, "buffs": {"ward": 3, "haste": 5}})
		_check(ui.find_child("HealthText", true, false).text == "65 / 170", "Health HUD rounds damage readout")
		_check(ui.find_child("ClassIcon", true, false).texture == ui.get("_icons")["shield"], "Health HUD identifies the selected Shield class")
		_check_status_cards(ui)
		_check(ui.find_child("DashDetail", true, false).text.contains("0.7s"), "Dash HUD shows the remaining recharge time")
		_check(ui.find_child("GuardLabel", true, false).text == "GUARD 40%", "Guard HUD labels the remaining reserve")
		ui.update_hud({"stage": 3, "night": true, "overdrive_time": 4.2})
		_check(ui.find_child("StageLabel", true, false).text.contains("CROWNFALL KEEP") and ui.find_child("StageLabel", true, false).text.contains("NIGHT"), "HUD identifies the late biome and night phase")
		_check(ui.find_child("OverdriveLabel", true, false).text.contains("4.2s"), "Overdrive HUD shows its remaining active duration")
		ui.update_hud({"health": 1000000000, "max_health": 1000000000, "score": 2000000000, "best": 2000000000})
		for label_name: String in ["ScoreLabel", "HealthText"]:
			var large_label: Label = ui.find_child(label_name, true, false)
			_check(large_label.size.x >= large_label.get_minimum_size().x, "endless large score/health remains readable without clipping: " + label_name)
			_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(large_label.get_global_rect()), "large score/health stays inside its portrait screen: " + label_name)
		ui.update_hud({"style": "sword"})
		_check(ui.find_child("ClassIcon", true, false).texture == ui.get("_icons")["sword"], "Health HUD follows a switch to Sword")
		ui.update_hud({"style": "shield", "health": 64.5, "max_health": 170, "score": 15823,
			"combo": 25, "boss_name": "The Tinpot King", "boss_hp": 232, "boss_max": 700})
		_check(ui.find_child("ScoreLabel", true, false).text == "15,823", "Score HUD formats thousands")
		_check(ui.find_child("ComboLabel", true, false).text.contains("25 COMBO"), "Combo HUD contract")
		_check(ui.find_child("BossHealthBar", true, false).visible, "Boss bar appears for an active boss")
		_check_buttons(ui, ["PauseButton", "SoundButton"])
		await _click_button(ui, "SoundButton")
		_check(ui.get("_overlay_kind") == "audio", "HUD sound button opens separate sound controls")
		_check(ui.close_auxiliary_overlay(), "Back closes the audio panel")
		_check(ui.get("_overlay_kind") == "pause", "Audio from combat returns to an explicitly paused run")
		for i in range(12):
			ui.toast("Reward %d" % i)
		ui.toast("Reward 11")
		_check(ui.get("_toasts").get_child_count() == 3, "Toasts are bounded and duplicate messages coalesce")
		ui.show_pause()
		_check(ui.get("_toasts").get_child_count() == 0, "Entering an overlay clears combat toasts")
		await process_frame
		await process_frame
		_check_buttons(ui, ["ResumeButton", "LeaderboardButton", "AchievementsButton"])
		await _click_button(ui, "AchievementsButton")
		_check(ui.get("_overlay_kind") == "achievements", "Actual GUI click opens badges without detaching an input target")
		await _click_button(ui, "AchievementsBackButton")
		_check(ui.get("_overlay_kind") == "pause", "Actual GUI click returns from badges")
		ui.show_scores({"best_score": 15023, "run_history": [{"style": "shield", "score": 821, "duration": 93}]}, "Offline · device scores")
		await process_frame
		await process_frame
		_check_buttons(ui, ["ScoresBackButton"])
		ui.find_child("ScoresBackButton", true, false).pressed.emit()
		_check(ui.find_child("ResumeButton", true, false) != null, "Scores returns to paused overlay")
		ui.show_end({"score": 15823, "best": 15823, "kills": 112, "bosses": 2, "duration": 123, "combo": 31, "new_best": true})
		await process_frame
		await process_frame
		_check_buttons(ui, ["SwordButton", "ShieldButton", "ShareButton"])
		_check_style_cards(ui)
		await _click_button(ui, "AudioSettingsButton")
		await _click_button(ui, "AudioBackButton")
		_check(ui.get("_overlay_kind") == "end", "Audio returns to the completed run without starting again")
		ui.show_achievements({"achievements": {"first_blood": 1739200123, "combo_25": 1739200130}})
		await process_frame
		await process_frame
		_check_buttons(ui, ["AchievementsBackButton"])
		_check(ui.find_child("AchievementList", true, false).get_child_count() == 60, "all20 local badge keys have readable title, description and spacing")
		ui.find_child("AchievementsBackButton", true, false).pressed.emit()
		_check(ui.find_child("ShareButton", true, false) != null, "Badges returns to completed run overlay")
		var choices := [
			{"id": "keen_edge", "name": "Keen Edge", "description": "+4 slash damage", "icon": "sword"},
			{"id": "thunderheart", "name": "Thunderheart", "description": "+1 lightning strike every fourth slash", "icon": "burst", "rarity": "rare"},
		]
		ui.show_upgrade_choices(choices, 10)
		await process_frame
		await process_frame
		_check_buttons(ui, ["UpgradeChoice1", "UpgradeChoice2", "AudioSettingsButton"])
		_check_upgrade_cards(ui)
		_check(ui.find_child("ResumeButton", true, false) == null, "Pending upgrade has no resume bypass")
		_check(not ui.close_auxiliary_overlay(), "Back cannot dismiss an unchosen upgrade")
		await _click_button(ui, "AudioSettingsButton")
		_check(ui.close_auxiliary_overlay(), "Back closes audio while an upgrade is pending")
		await process_frame
		await process_frame
		_check(ui.get("_overlay_kind") == "upgrade", "Audio returns to the pending upgrade")
		_check(ui.get("_overlay_data").choices == choices, "Audio preserves both exact randomized upgrade choices")
		_check_upgrade_cards(ui)
		await _click_button(ui, "UpgradeChoice2")
		ui.find_child("UpgradeChoice2", true, false).pressed.emit()
		_check(_upgrades.size() == viewport_index, "A choice emits once even if its callback is repeated")
		await _check_production_cards(ui)
	_check(_styles == ["sword", "shield", "sword", "shield", "sword", "shield"], "Style button signals carry exact keys")
	_check(_resume_count == 3, "Resume emits once per press")
	_check(_pause_count == 3, "Audio pauses each active run once")
	_check(_audio_changes == [["music", false], ["sfx", false], ["music", true], ["music", false], ["sfx", false], ["music", true], ["music", false], ["sfx", false], ["music", true]], "Audio emits the exact independent preference changes")
	_check(_upgrades == ["thunderheart", "thunderheart", "thunderheart"], "Upgrade choice emits its exact identifier")
	world.reset()
	_check(world.elapsed == 0.0, "World reset clears elapsed")
	var layout_file := FileAccess.open("res://output/review/ui_layouts.json", FileAccess.WRITE)
	if layout_file != null:
		layout_file.store_string(JSON.stringify(_layouts, "\t"))
	ui.queue_free()
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_LAYOUT_PASS: 540x960,540x1110,1080x1920; class and stage/rare/legendary/trade upgrade cards, independent audio, frozen choice/back behavior, status HUD,20badgekeys, actual one-tap input, local overlays and World contract")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _check_buttons(ui: Node, names: Array) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var overlay_data: Dictionary = ui.get("_overlay_data")
	var record := {"viewport": [viewport.size.x, viewport.size.y], "overlay": ui.get("_overlay_kind"),
		"can_resume": bool(overlay_data.get("can_resume", false)), "buttons": {}}
	for name in names:
		var button: Button = ui.find_child(name, true, false)
		_check(button != null, "Button exists: " + name)
		if button == null:
			continue
		var rect := button.get_global_rect()
		record.buttons[name] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		_check(button.is_visible_in_tree(), "Button visible: " + name)
		_check(rect.size.x >= 42 and rect.size.y >= 42, "Button touch target: " + name)
		_check(viewport.encloses(rect), "Button stays inside portrait viewport: " + name + " " + str(rect))
	_layouts.append(record)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)


func _check_style_cards(ui: Node) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for style in ["sword", "shield"]:
		var title: String = style.capitalize()
		var button: Button = ui.find_child(title + "Button", true, false)
		var profile: Dictionary = ClassProfiles.PROFILES[style]
		var stats: Label = ui.find_child(title + "Stats", true, false)
		var strengths: Label = ui.find_child(title + "Strengths", true, false)
		var tradeoffs: Label = ui.find_child(title + "Tradeoffs", true, false)
		_check(stats.text == "%d HP  ·  %d DMG" % [int(profile.health), int(profile.damage)], title + " shows the actual shared starting stats")
		_check(strengths.text == ("↑ DMG  ↑ SPEED" if style == "sword" else "↑ HP  ↑ GUARD"), title + " clearly shows its strengths")
		_check(tradeoffs.text == ("↓ HP  ↓ GUARD" if style == "sword" else "↓ DMG  ↓ SPEED"), title + " clearly shows its tradeoffs")
		for content in [stats, strengths, tradeoffs, ui.find_child(title + "Identity", true, false)]:
			_check(button.get_global_rect().encloses(content.get_global_rect()), title + " comparison text stays inside its touch card")
			_check(viewport.encloses(content.get_global_rect()), title + " comparison text stays inside the portrait screen")
			_check(content.size.x >= content.get_minimum_size().x, title + " comparison text fits without clipping")


func _click_button(ui: Node, button_name: String) -> void:
	var button: Button = ui.find_child(button_name, true, false)
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
	await process_frame
	await process_frame


func _check_status_cards(ui: Node) -> void:
	var viewport := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	for prefix in ["Dash", "Guard"]:
		var card: Panel = ui.find_child(prefix + "Card", true, false)
		_check(viewport.encloses(card.get_global_rect()), prefix + " status card stays in the safe portrait area")
		var label: Label = ui.find_child(prefix + "Label", true, false)
		_check(card.get_global_rect().encloses(label.get_global_rect()), prefix + " large label fits its status card")
		_check(label.get_theme_font_size("font_size") >= 18, prefix + " status is visibly larger than the previous small text")
		_check(label.size.x >= label.get_minimum_size().x, prefix + " status fits without clipping")
	var dash: Panel = ui.find_child("DashCard", true, false)
	var guard: Panel = ui.find_child("GuardCard", true, false)
	_check(not dash.get_global_rect().intersects(guard.get_global_rect()), "Guard and dash cards do not overlap")
	_check(not dash.get_global_rect().intersects(ui.find_child("BuffLabel", true, false).get_global_rect()), "Buffs sit above the dash and guard cards")


func _check_upgrade_cards(ui: Node) -> void:
	for index in [1, 2]:
		var button: Button = ui.find_child("UpgradeChoice%d" % index, true, false)
		for prefix in ["UpgradeTitle", "UpgradeDescription"]:
			var label: Label = ui.find_child("%s%d" % [prefix, index], true, false)
			_check(button.get_global_rect().encloses(label.get_global_rect()), "Upgrade title and stat description fit inside its touch card")
			_check(label.size.y >= label.get_minimum_size().y, "Upgrade description fits its wrapped height")
			if prefix == "UpgradeDescription":
				_check(label.get_theme_font_size("font_size") >= 20, "Upgrade stat descriptions remain prominent")
	var first: Button = ui.find_child("UpgradeChoice1", true, false)
	var second: Button = ui.find_child("UpgradeChoice2", true, false)
	_check(not first.get_global_rect().intersects(second.get_global_rect()), "Upgrade choice touch targets do not overlap")

func _check_production_cards(ui: Node) -> void:
	for spec: Array in [[20, "vampire_steel", "trade_guard_delay_for_move_speed"], [30, "titan_heart", "headhunter"], [50, "abyssal_steel", "adamant_vow"], [25, "phoenix_oath", "worldbreaker"]]:
		var choices: Array = []
		for key: String in [spec[1], spec[2]]:
			choices.append(Upgrades.get_upgrade(key))
		ui.show_upgrade_choices(choices, int(spec[0]))
		await process_frame
		await process_frame
		_check_buttons(ui, ["UpgradeChoice1", "UpgradeChoice2", "AudioSettingsButton"])
		_check_upgrade_cards(ui)
