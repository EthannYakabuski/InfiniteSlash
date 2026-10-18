extends SceneTree
## Render-only native-space fixtures. These strips are NOT actual served ads.

const Interface = preload("res://scripts/game_ui.gd")
const World = preload("res://scripts/world.gd")
const Upgrades = preload("res://scripts/upgrade_catalog.gd")
var ui: Variant
var top_strip: ColorRect
var bottom_strip: ColorRect
var records: Array = []
var directory := "res://output/review/ad-ui"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Ad UI captures require a real renderer.")
		quit(2)
		return
	root.get_node("SaveData").configure_storage("res://output/test-data/ad_ui_capture_profile.json")
	root.get_node("AudioManager").set_enabled(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var world := World.new()
	root.add_child(world)
	ui = Interface.new()
	root.add_child(ui)
	var fixture := CanvasLayer.new()
	fixture.layer = 99
	root.add_child(fixture)
	top_strip = _strip()
	bottom_strip = _strip()
	fixture.add_child(top_strip)
	fixture.add_child(bottom_strip)
	for dimensions in [Vector2i(540, 960), Vector2i(540, 1110), Vector2i(1080, 1920)]:
		root.size = dimensions
		await process_frame
		await process_frame
		world.advance(0, 110, 50)
		ui.update_hud({"style": "shield", "health": 103, "max_health": 170, "score": 45200, "best": 92000, "level": 30, "xp": 15, "xp_goal": 100, "elapsed": 110, "night": true, "stage": 2, "guard_ratio": 0.6, "dash_ready": true})
		ui.set_ad_banner_space(100, 160)
		ui.show_launch(true, 92000)
		await _capture(dimensions, "home_top_banner")
		ui.show_pause()
		await _capture(dimensions, "pause_top_banner")
		var choices: Array = []
		for card in Upgrades.eligible(50, {"style": "sword", "level": 50}):
			if str(card.id) in ["phoenix_oath", "trade_guard_capacity_for_move_speed"]:
				choices.append(card)
		ui.show_upgrade_choices(choices, 50)
		await _capture(dimensions, "upgrade_bottom_banner")
		ui.set_privacy_options_required(true)
		ui.show_audio_settings()
		await _capture(dimensions, "audio_privacy_no_banner")
		ui.set_privacy_options_required(false)
		ui.show_continue_offer()
		await _capture(dimensions, "continue_no_banner")
		ui.show_ad_waiting()
		await _capture(dimensions, "waiting_no_banner")
		ui.show_end({"score": 45200, "best": 92000, "kills": 345, "bosses": 5, "duration": 246, "combo": 72})
		await _capture(dimensions, "results_no_banner")
		ui.set_ad_banner_space(0, 0)
		ui.show_launch(false, 92000)
		await _capture(dimensions, "home_no_inventory")
	var file := FileAccess.open(directory + "/captures.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"actual_native_ads_served": false, "fixture_only": true, "captures": records}, "  "))
	file.close()
	ui.queue_free()
	world.queue_free()
	fixture.queue_free()
	root.get_node("AudioManager").stop_for_shutdown()
	await process_frame
	print("AD_UI_CAPTURE_PASS:24 native-space fixtures, no actual native ad requests")
	quit(0)


func _strip() -> ColorRect:
	var strip := ColorRect.new()
	strip.color = Color("142330")
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "NATIVE BANNER SPACE\nUI layout fixture • not a served ad"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("b9d4e4"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(label)
	return strip


func _capture(dimensions: Vector2i, name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	top_strip.visible = ui._ad_top_logical > 0
	bottom_strip.visible = ui._ad_bottom_logical > 0
	top_strip.position = Vector2.ZERO
	top_strip.size = Vector2(ui._size.x, ui._ad_top_logical)
	bottom_strip.position = Vector2(0, ui._size.y - ui._ad_bottom_logical)
	bottom_strip.size = Vector2(ui._size.x, ui._ad_bottom_logical)
	await process_frame
	await RenderingServer.frame_post_draw
	var path := directory + "/%dx%d_%s.png" % [dimensions.x, dimensions.y, name]
	var screenshot := root.get_texture().get_image()
	screenshot.save_png(path)
	var native_height := float(DisplayServer.window_get_size().y)
	records.append({"file": path, "window": [dimensions.x, dimensions.y], "image": [screenshot.get_width(), screenshot.get_height()], "viewport": [ui._size.x, ui._size.y], "native_window_height": native_height, "top_logical": ui._ad_top_logical, "bottom_logical": ui._ad_bottom_logical, "overlay": ui._overlay_kind})
