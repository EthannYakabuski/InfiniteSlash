extends SceneTree
## Exercises the actual overlay buttons and portrait layout without touching a run.

const Interface = preload("res://scripts/game_ui.gd")
const World = preload("res://scripts/world.gd")
var _failures: Array[String] = []
var _styles: Array[String] = []
var _resume_count := 0
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
	ui.achievements_requested.connect(func(): ui.show_achievements({"achievements": {"first_blood": 1}}))
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1110)]:
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
		_check(ui.find_child("LeaderboardButton", true, false) == null, "Launch has no utility menu")
		ui.find_child("SwordButton", true, false).pressed.emit()
		ui.find_child("ShieldButton", true, false).pressed.emit()
		ui.show_launch(true, 15023)
		await process_frame
		await process_frame
		_check_buttons(ui, ["ResumeButton", "SwordButton", "ShieldButton"])
		ui.find_child("ResumeButton", true, false).pressed.emit()
		ui.hide_overlay()
		ui.update_hud({"boss_name": "", "boss_max": 1.0, "boss_hp": 0.0})
		_check(not ui.find_child("BossHealthBar", true, false).visible, "No boss bar outside a boss fight")
		ui.update_hud({"health": 64.5, "max_health": 125, "score": 15823, "best": 15900,
			"level": 7, "xp": 4, "xp_goal": 10, "combo": 25, "multiplier": 3,
			"dash_ready": false, "guard_ratio": 0.4, "boss_name": "The Tinpot King",
			"boss_hp": 232, "boss_max": 700, "elapsed": 181, "buffs": {"ward": 3, "haste": 5}})
		_check(ui.find_child("HealthText", true, false).text == "65 / 125", "Health HUD rounds damage readout")
		_check(ui.find_child("ScoreLabel", true, false).text == "15,823", "Score HUD formats thousands")
		_check(ui.find_child("ComboLabel", true, false).text.contains("25 COMBO"), "Combo HUD contract")
		_check(ui.find_child("BossHealthBar", true, false).visible, "Boss bar appears for an active boss")
		_check_buttons(ui, ["PauseButton", "SoundButton"])
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
		ui.show_achievements({"achievements": {"first_blood": 1739200123, "combo_25": 1739200130}})
		await process_frame
		await process_frame
		_check_buttons(ui, ["AchievementsBackButton"])
		ui.find_child("AchievementsBackButton", true, false).pressed.emit()
		_check(ui.find_child("ShareButton", true, false) != null, "Badges returns to completed run overlay")
	_check(_styles == ["sword", "shield", "sword", "shield"], "Style button signals carry exact keys")
	_check(_resume_count == 2, "Resume emits once per press")
	world.reset()
	_check(world.elapsed == 0.0, "World reset clears elapsed")
	var layout_file := FileAccess.open("res://output/review/ui_layouts.json", FileAccess.WRITE)
	if layout_file != null:
		layout_file.store_string(JSON.stringify(_layouts, "\t"))
	ui.queue_free()
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_LAYOUT_PASS: portrait 540x960 and expanded540x1110; controls, HUD, local overlays and World contract")
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
