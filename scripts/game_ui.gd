extends CanvasLayer
## Compact portrait HUD and one-tap overlays. All game decisions belong to game.gd.

signal start_requested(style: String)
signal resume_requested
signal pause_requested
signal leaderboard_requested
signal achievements_requested
signal audio_setting_changed(key: String, enabled: bool)
signal upgrade_selected(id: String)
signal daily_requested
signal share_requested
signal overlay_changed(kind: String)
signal rewarded_continue_requested
signal continue_declined
signal privacy_options_requested

const GOLD := Color("ffd77a")
const CREAM := Color("fff2d3")
const INK := Color("19252a")
const MUTED := Color("a8bcbd")
const ClassProfiles = preload("res://scripts/class_profiles.gd")
const ACHIEVEMENTS := {
	"first_blood": ["First Slice", "Defeat your first creature"],
	"boss_slayer": ["Crown Collector", "Defeat a boss"],
	"century": ["A Hundred Little Problems", "Defeat 100 creatures"],
	"survivor": ["Still Standing", "Survive for 3 minutes"],
	"legend": ["Knight of Infinite Nonsense", "Defeat 5 bosses in one run"],
	"combo_25": ["Slice Streak", "Reach a 25-kill combo"],
	"score_10000": ["Five Digits of Slop", "Score 10,000 in one run"],
	"collector": ["Bestiary Pioneer", "Defeat 100 different creature species"],
	"hundred_club": ["A Hundred in a Hurry", "Defeat 100 creatures in one run"],
	"survivor_60": ["Minute Knight", "Survive for one minute"],
	"survivor_180": ["Three Minute Hero", "Survive for three minutes"],
	"thousand_kills": ["Slop Sweeper", "Defeat 1,000 creatures"],
	"ten_runs": ["Back for More", "Complete ten runs"],
	"rare_boss": ["Royal Upset", "Defeat any rare boss"],
	"all_bosses": ["Crown Census", "Defeat all 12 different bosses"],
	"bestiary_50": ["Field Guide", "Defeat 50 different creature species"],
	"bestiary_100": ["Monster Scholar", "Defeat 100 different creature species"],
	"bestiary_150": ["Midnight Archivist", "Defeat 150 different creature species"],
	"bestiary_200": ["Living Bestiary", "Defeat 200 different creature species"],
	"biome_50": ["Beyond the Kingdom", "Reach level 50 and enter Crownfall Keep"],
}

var _root: Control
var _hud: Control
var _overlay: Control
var _card: VBoxContainer
var _card_scroll: ScrollContainer
var _card_center: CenterContainer
var _toasts: VBoxContainer
var _health: ProgressBar
var _xp: ProgressBar
var _guard: ProgressBar
var _boss: ProgressBar
var _health_text: Label
var _class_icon: TextureRect
var _score: Label
var _best: Label
var _level: Label
var _combo: Label
var _time: Label
var _stage: Label
var _rush: Label
var _dash: Label
var _dash_detail: Label
var _dash_card: Panel
var _dash_progress: ProgressBar
var _dash_icon: TextureRect
var _guard_card: Panel
var _guard_label: Label
var _guard_icon: TextureRect
var _buffs: Label
var _boss_name: Label
var _pause: Button
var _sound: Button
var _audio_settings: Dictionary = {"sfx": true, "music": true}
var _audio_previous_kind := "launch"
var _audio_previous_data: Dictionary = {}
var _upgrade_selection_locked := false
var _continue_selection_locked := false
var _privacy_options_required := false
var _ad_top_px := 0.0
var _ad_bottom_px := 0.0
var _ad_top_logical := 0.0
var _ad_bottom_logical := 0.0
var _size := Vector2(540, 960)
var _top := 26.0
var _bottom := 26.0
var _overlay_kind := ""
var _overlay_data: Dictionary = {}
var _previous_kind := "launch"
var _previous_data: Dictionary = {}
var _icons: Dictionary = {}


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	for icon in ["sword", "shield", "pause", "sound", "sound_disabled", "star", "burst", "music", "music_disabled", "fire", "hand", "size_larger"]:
		var path := "res://Assets/MobileControls/Sprites/Icons/Default/icon_%s.png" % icon
		if ResourceLoader.exists(path):
			_icons[icon] = load(path)
	_root = Control.new()
	_root.name = "GameInterface"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_build_hud()
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)
	_overlay.hide()
	_toasts = VBoxContainer.new()
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 5)
	_root.add_child(_toasts)
	get_viewport().size_changed.connect(_resize)
	_resize()


func _build_hud() -> void:
	_hud = Control.new()
	_hud.name = "HUD"
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_hud)
	_health = _bar("HealthBar", Color("ef7764"), Color("3b3635"))
	_hud.add_child(_health)
	_health_text = _label("100 / 100", 17, CREAM)
	_health_text.name = "HealthText"
	_health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_health_text)
	_class_icon = TextureRect.new()
	_class_icon.name = "ClassIcon"
	_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_icon.texture = _icons.get("sword")
	_hud.add_child(_class_icon)
	_xp = _bar("ExperienceBar", GOLD, Color("3b493c"))
	_hud.add_child(_xp)
	_score = _label("0", 32, CREAM)
	_score.name = "ScoreLabel"
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_score)
	_best = _label("BEST 0", 13, GOLD)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_best)
	_level = _label("LV 1", 17, GOLD)
	_level.name = "LevelLabel"
	_hud.add_child(_level)
	_time = _label("0:00", 17, CREAM)
	_time.name = "TimeLabel"
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_time)
	_stage = _label("STAGE 1 · DAY", 12, MUTED)
	_stage.name = "StageLabel"
	_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_stage)
	_rush = _label("OVERDRIVE 0% · DASH THROUGH SHOTS", 13, Color("b5edff"))
	_rush.name = "OverdriveLabel"
	_rush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_rush)
	_combo = _label("", 22, GOLD)
	_combo.name = "ComboLabel"
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_combo)
	_dash_card = Panel.new()
	_dash_card.name = "DashCard"
	_dash_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dash_card.add_theme_stylebox_override("panel", _box(Color("1b3a40"), Color("5bacae")))
	_hud.add_child(_dash_card)
	_dash_icon = _hud_icon("burst", "DashIcon")
	_dash = _label("DASH READY", 18, Color("c4fff0"))
	_dash.name = "DashLabel"
	_hud.add_child(_dash)
	_dash_detail = _label("FLICK TO DASH", 12, CREAM)
	_dash_detail.name = "DashDetail"
	_hud.add_child(_dash_detail)
	_dash_progress = _bar("DashProgress", Color("a1e6df"), Color("293c41"))
	_hud.add_child(_dash_progress)
	_guard_card = Panel.new()
	_guard_card.name = "GuardCard"
	_guard_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_guard_card.add_theme_stylebox_override("panel", _box(Color("24343b"), Color("648a91")))
	_hud.add_child(_guard_card)
	_guard_icon = _hud_icon("shield", "GuardIcon")
	_guard_label = _label("GUARD 100%", 18, Color("c4ecf1"))
	_guard_label.name = "GuardLabel"
	_hud.add_child(_guard_label)
	_guard = _bar("GuardBar", Color("86d7d3"), Color("233d40"))
	_hud.add_child(_guard)
	_buffs = _label("", 17, GOLD)
	_buffs.name = "BuffLabel"
	_buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buffs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hud.add_child(_buffs)
	_boss_name = _label("", 18, GOLD)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_boss_name)
	_boss = _bar("BossHealthBar", Color("ef965a"), Color("433538"))
	_hud.add_child(_boss)
	_boss.hide()
	_pause = _button("", "PauseButton", Color("354b4d"), "pause")
	_pause.pressed.connect(func(): pause_requested.emit())
	_hud.add_child(_pause)
	_sound = _button("", "SoundButton", Color("354b4d"), "sound")
	_sound.pressed.connect(show_audio_settings)
	_hud.add_child(_sound)


func _hud_icon(icon_name: String, node_name: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = node_name
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _icons.get(icon_name)
	_hud.add_child(icon)
	return icon


func _resize() -> void:
	_size = get_viewport().get_visible_rect().size
	_top = 22.0
	_bottom = 22.0
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.y > 0 and safe.size.y > 0:
			var factor := _size.y / float(screen.y)
			_top = maxf(22.0, safe.position.y * factor + 10.0)
			_bottom = maxf(22.0, (screen.y - safe.end.y) * factor + 10.0)
	_update_ad_insets()
	_top += _ad_top_logical + (8.0 if _ad_top_logical > 0.0 else 0.0)
	_bottom += _ad_bottom_logical + (8.0 if _ad_bottom_logical > 0.0 else 0.0)
	var hp_width := minf(205.0, _size.x * 0.39)
	_place(_health, Vector2(24, _top + 5), Vector2(hp_width, 22))
	_place(_health_text, Vector2(49, _top + 5), Vector2(hp_width - 29, 22))
	_place(_class_icon, Vector2(30, _top + 7), Vector2(18, 18))
	_place(_xp, Vector2(24, _top + 34), Vector2(hp_width, 5))
	_place(_level, Vector2(24, _top + 45), Vector2(100, 25))
	_place(_score, Vector2(_size.x - 225, _top - 6), Vector2(136, 38))
	_place(_best, Vector2(_size.x - 240, _top + 30), Vector2(151, 20))
	_place(_time, Vector2(_size.x * 0.5 - 45, _top + 44), Vector2(90, 25))
	_place(_stage, Vector2(120, _top + 71), Vector2(_size.x - 240, 18))
	_place(_pause, Vector2(_size.x - 71, _top - 5), Vector2(48, 48))
	_place(_sound, Vector2(_size.x - 71, _top + 48), Vector2(48, 42))
	_place(_combo, Vector2(70, _top + 89), Vector2(_size.x - 140, 31))
	_place(_boss_name, Vector2(55, _top + 125), Vector2(_size.x - 110, 24))
	_place(_boss, Vector2(55, _top + 154), Vector2(_size.x - 110, 9))
	var status_width := (_size.x - 68.0) * 0.5
	var status_y := _size.y - _bottom - 62.0
	var dash_x := _size.x - 26.0 - status_width
	_place(_guard_card, Vector2(26, status_y), Vector2(status_width, 62))
	_place(_guard_icon, Vector2(36, status_y + 11), Vector2(24, 24))
	_place(_guard_label, Vector2(68, status_y + 8), Vector2(status_width - 50, 27))
	_place(_guard, Vector2(39, status_y + 43), Vector2(status_width - 26, 7))
	_place(_dash_card, Vector2(dash_x, status_y), Vector2(status_width, 62))
	_place(_dash_icon, Vector2(dash_x + 10, status_y + 11), Vector2(24, 24))
	_place(_dash, Vector2(dash_x + 42, status_y + 5), Vector2(status_width - 49, 26))
	_place(_dash_detail, Vector2(dash_x + 42, status_y + 29), Vector2(status_width - 49, 18))
	_place(_dash_progress, Vector2(dash_x + 13, status_y + 50), Vector2(status_width - 26, 5))
	_place(_buffs, Vector2(30, status_y - 38), Vector2(_size.x - 60, 30))
	_place(_rush, Vector2(30, status_y - 61), Vector2(_size.x - 60, 22))
	var toast_y := _size.y - _bottom - 112.0 if _overlay.visible else _top + 182.0
	_place(_toasts, Vector2(30, toast_y), Vector2(_size.x - 60, 110))
	if _card != null and is_instance_valid(_card):
		_position_card()


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions


func _position_card() -> void:
	if _card == null or not is_instance_valid(_card) or _card_scroll == null or not is_instance_valid(_card_scroll):
		return
	var width := minf(468.0, _size.x - 54.0)
	var available_height := maxf(64.0, _size.y - _top - _bottom - 32.0)
	_card.custom_minimum_size.x = width
	_card.size.x = width
	_place(_card_scroll, Vector2((_size.x - width) * 0.5, _top + 16.0), Vector2(width, available_height))
	_card_center.custom_minimum_size = Vector2(width, available_height)


func set_ad_banner_space(top_px: float, bottom_px: float) -> void:
	# The Android SDK reports physical pixels. Canvas-items stretch uses logical
	# viewport coordinates, so convert once here rather than in the game caller.
	_ad_top_px = top_px if is_finite(top_px) and top_px > 0.0 else 0.0
	_ad_bottom_px = bottom_px if is_finite(bottom_px) and bottom_px > 0.0 else 0.0
	if _root != null:
		_resize()


func _update_ad_insets() -> void:
	var native_height := float(DisplayServer.window_get_size().y)
	if native_height <= 0.0:
		native_height = float(DisplayServer.screen_get_size().y)
	var factor := _size.y / native_height if native_height > 0.0 else 1.0
	# The service owns visibility. Ignore stale native callbacks immediately when
	# another overlay opens, keeping scores/settings/reward flows free of banners.
	_ad_top_logical = _ad_top_px * factor if _overlay_kind in ["launch", "pause"] else 0.0
	_ad_bottom_logical = _ad_bottom_px * factor if _overlay_kind == "upgrade" else 0.0


func set_privacy_options_required(required: bool) -> void:
	_privacy_options_required = required
	if _root == null:
		return
	for node in _root.find_children("AudioSettingsButton", "Button", true, false):
		node.text = "AUDIO & PRIVACY" if required else "AUDIO"
	if _overlay_kind == "audio":
		var privacy := _card.get_node_or_null("PrivacyOptionsButton") as Button
		if privacy != null:
			privacy.visible = required
		var title := _card.get_node_or_null("AudioTitle") as Label
		if title != null:
			title.text = "SETTINGS" if required else "SOUND"
		_position_card()
		call_deferred("_position_card")


func update_hud(data: Dictionary) -> void:
	if _health == null:
		return
	var hp := float(data.get("health", 100))
	var maximum := maxf(1.0, float(data.get("max_health", 100)))
	_health.max_value = maximum
	_health.value = hp
	_health_text.text = "%d / %d" % [int(ceil(hp)), int(ceil(maximum))]
	_fit_hud_number(_health_text, 17, 11)
	var style := str(data.get("style", "sword"))
	_class_icon.texture = _icons.get(style, _icons.get("sword"))
	_class_icon.modulate = GOLD if style == "sword" else Color("b2e5e7")
	_score.text = _number(int(data.get("score", 0)))
	_fit_hud_number(_score, 32, 15)
	_best.text = "BEST " + _number(int(data.get("best", 0)))
	_level.text = "LV %d" % int(data.get("level", 1))
	_xp.max_value = maxf(1.0, float(data.get("xp_goal", 1)))
	_xp.value = float(data.get("xp", 0))
	var combo := int(data.get("combo", 0))
	_combo.text = "%d COMBO  ×%d" % [combo, int(data.get("multiplier", 1))] if combo >= 3 else ""
	_time.text = _duration(float(data.get("elapsed", 0)))
	var stage: int = int(data.get("stage", 1))
	_stage.text = "%s · %s" % ["CROWNFALL KEEP" if stage >= 3 else "STAGE %d" % stage, "NIGHT" if bool(data.get("night", false)) else "DAY"]
	var overdrive_time: float = float(data.get("overdrive_time", 0))
	_rush.text = "OVERDRIVE %.1fs · DAMAGE +25%%" % overdrive_time if overdrive_time > 0 else "OVERDRIVE %d%% · DASH THROUGH SHOTS" % int(data.get("overdrive_charge", 0))
	var dash_ready := bool(data.get("dash_ready", true))
	var dash_remaining := maxf(0.0, float(data.get("dash_cooldown", 0.0)))
	_dash.text = "DASH READY" if dash_ready else "DASH CHARGING"
	_dash.add_theme_color_override("font_color", Color("c4fff0") if dash_ready else CREAM)
	_dash_detail.text = "FLICK TO DASH" if dash_ready else ("READY IN %.1fs" % dash_remaining if dash_remaining > 0.0 else "RECHARGING")
	var dash_recharge := maxf(0.1, float(data.get("dash_recharge", 1.45)))
	_dash_progress.value = 100.0 if dash_ready else clampf(1.0 - dash_remaining / dash_recharge, 0.0, 1.0) * 100.0
	_dash_icon.modulate = Color("c4fff0") if dash_ready else MUTED
	var guard_ratio := clampf(float(data.get("guard_ratio", 1.0)), 0.0, 1.0)
	_guard.value = guard_ratio * 100.0
	_guard_label.text = "GUARD %d%%" % int(round(guard_ratio * 100.0))
	_guard_label.add_theme_color_override("font_color", Color("c4ecf1") if guard_ratio > 0.2 else Color("ffae8e"))
	var boss_max := float(data.get("boss_max", 0))
	var boss_active := not str(data.get("boss_name", "")).is_empty() and boss_max > 0.0 and float(data.get("boss_hp", 0)) > 0.0
	_boss.visible = boss_active
	_boss_name.visible = boss_active
	_boss.max_value = maxf(1.0, boss_max)
	_boss.value = float(data.get("boss_hp", 0))
	_boss_name.text = str(data.get("boss_name", ""))
	var buffs: Variant = data.get("buffs", [])
	var names: PackedStringArray = []
	if buffs is Dictionary:
		for key in buffs:
			names.append(str(key).to_upper())
	elif buffs is Array or buffs is PackedStringArray:
		for buff in buffs:
			names.append(str(buff).to_upper())
	elif buffs is String:
		names.append(buffs)
	var ward_hits := int(data.get("ward_hits", 0))
	if ward_hits > 0:
		names.append("WARD ×%d" % ward_hits)
	_buffs.text = " · ".join(names)


func show_launch(can_resume: bool, best_score: int) -> void:
	_overlay_data = {"can_resume": can_resume, "best": best_score}
	_new_overlay("launch")
	_title()
	_add_text("ONE MORE RUN.", 16, GOLD)
	_spacer(10)
	if can_resume:
		var resume := _action("RESUME RUN", "ResumeButton", GOLD)
		resume.pressed.connect(func(): resume_requested.emit())
		_spacer(4)
	_add_styles()
	_add_text("BEST  " + _number(best_score), 16, MUTED)
	_add_audio_button()
	_finish_overlay()


func show_pause() -> void:
	_overlay_data = {}
	_new_overlay("pause")
	_add_text("A LITTLE BREATHER", 14, GOLD)
	_add_text("PAUSED", 54, CREAM)
	_spacer(24)
	var resume := _action("KEEP SLASHING", "ResumeButton", GOLD)
	resume.pressed.connect(func(): resume_requested.emit())
	_spacer(16)
	_footer(false, false)
	_finish_overlay()


func show_continue_offer(data: Dictionary = {}) -> void:
	_overlay_data = data.duplicate(true)
	_continue_selection_locked = false
	_new_overlay("continue")
	_add_text("ONE MORE CHANCE", 17, GOLD)
	_add_text("NOT DONE YET?", 40, CREAM)
	_add_text("Watch an ad to return with full health and guard.", 20, CREAM)
	_add_text("One continue per run.", 15, MUTED)
	_spacer(18)
	var issued_card := _card
	var watch := _action("Watch ad • Full restore", "RewardedContinueButton", GOLD)
	watch.pressed.connect(func():
		if not _claim_continue_choice(issued_card):
			return
		rewarded_continue_requested.emit()
	)
	var decline := _action("End run", "DeclineContinueButton", Color("3b555b"))
	decline.custom_minimum_size.y = 52
	decline.pressed.connect(func():
		if not _claim_continue_choice(issued_card):
			return
		continue_declined.emit()
	)
	_finish_overlay()


func _claim_continue_choice(issued_card: VBoxContainer) -> bool:
	if _continue_selection_locked or _overlay_kind != "continue" or issued_card != _card:
		return false
	_continue_selection_locked = true
	for child in _card.get_children():
		if child is Button:
			child.disabled = true
	return true


func show_ad_waiting(message: String = "Opening your reward…") -> void:
	_overlay_data = {"message": message}
	_new_overlay("ad_waiting")
	_add_text("ONE MOMENT", 17, GOLD)
	_add_text("YOUR RUN IS PAUSED", 32, CREAM)
	_add_text(message, 19, MUTED)
	_finish_overlay()


func show_upgrade_choices(choices: Array, current_level: int) -> void:
	# The game owns the paused run and validates the selected identifier. Never
	# provide a resume/skip route while these two choices are awaiting a decision.
	_overlay_data = {"choices": choices.duplicate(true), "level": current_level}
	_upgrade_selection_locked = false
	_new_overlay("upgrade")
	_add_text("LEVEL %d" % current_level, 21, GOLD)
	_add_text("CHOOSE YOUR EDGE", 35, CREAM)
	_add_text("One upgrade. Your kind of chaos.", 17, MUTED)
	_spacer(10)
	for index in range(mini(2, choices.size())):
		if choices[index] is Dictionary:
			_card.add_child(_upgrade_button(choices[index], index))
		if index == 0:
			_add_text("OR", 14, MUTED)
	_spacer(5)
	_add_text("The arena waits for your choice.", 15, MUTED)
	_add_audio_button()
	_finish_overlay()


func _upgrade_button(choice: Dictionary, index: int) -> Button:
	var legendary := str(choice.get("rarity", "")).to_lower() == "legendary"
	var rare := bool(choice.get("rare", false)) or str(choice.get("rarity", "")).to_lower() in ["rare", "epic", "legendary"]
	var color := Color("5c3975") if legendary else Color("705032") if rare else (Color("3d6562") if index == 0 else Color("435c76"))
	var button := _button("", "UpgradeChoice%d" % (index + 1), color)
	button.custom_minimum_size.y = clampf(112 + str(choice.get("description", "")).split("\n").size() * 25, 155, 240)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.set_meta("upgrade_id", str(choice.get("id", "")))
	var issued_card := _card
	button.pressed.connect(func():
		if _upgrade_selection_locked or _overlay_kind != "upgrade" or issued_card != _card:
			return
		_upgrade_selection_locked = true
		for target in _card.get_children():
			if target is Button and target.has_meta("upgrade_id"):
				target.disabled = true
		upgrade_selected.emit(str(choice.get("id", "")))
	)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 19)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 13)
	button.add_child(margin)
	var contents := VBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.alignment = BoxContainer.ALIGNMENT_CENTER
	contents.add_theme_constant_override("separation", 8)
	margin.add_child(contents)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 12)
	contents.add_child(heading)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _icons.get(str(choice.get("icon", "star")), _icons.get("star"))
	icon.modulate = GOLD if rare else Color("c4fff0")
	heading.add_child(icon)
	var title := _label(str(choice.get("name", "A sharper edge")), 23, CREAM)
	title.name = "UpgradeTitle%d" % (index + 1)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var description := _label(str(choice.get("description", "")), 20, Color("e6f8eb"))
	description.name = "UpgradeDescription%d" % (index + 1)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(description)
	var hint := _label("LEGENDARY · TAP TO TAKE" if legendary else "RARE TRADE-OFF · TAP TO TAKE" if rare and bool(choice.get("tradeoff", false)) else "RARE UPGRADE · TAP TO TAKE" if rare else "TRADE-OFF · TAP TO TAKE" if bool(choice.get("tradeoff", false)) else "TAP TO TAKE", 12, Color("edc7ff") if legendary else GOLD if rare else Color("c6dfdf"))
	contents.add_child(hint)
	return button


func set_audio_settings(settings: Dictionary) -> void:
	for key in ["music", "sfx"]:
		_audio_settings[key] = bool(settings.get(key, _audio_settings[key]))
	var any_enabled := bool(_audio_settings.sfx) or bool(_audio_settings.music)
	if _sound != null:
		_sound.icon = _icons.get("sound" if any_enabled else "sound_disabled")
	if _overlay_kind == "audio":
		_update_audio_buttons()


func show_audio_settings() -> void:
	if _overlay_kind == "audio":
		return
	if _overlay_kind.is_empty():
		# pause_requested is connected synchronously by game.gd, which freezes
		# combat before the audio panel can consume another touch.
		pause_requested.emit()
	_audio_previous_kind = _overlay_kind if not _overlay_kind.is_empty() else "pause"
	_audio_previous_data = _overlay_data.duplicate(true)
	_new_overlay("audio")
	_add_text("SET THE MOOD", 16, GOLD)
	var title := _add_text("SETTINGS" if _privacy_options_required else "SOUND", 48, CREAM)
	title.name = "AudioTitle"
	_add_text("Your music. Your mayhem.", 17, MUTED)
	_spacer(20)
	for spec in [["music", "BACKGROUND MUSIC", "MusicToggle", "music"], ["sfx", "SOUND EFFECTS", "SfxToggle", "sound"]]:
		var key: String = spec[0]
		var button := _action("", spec[2], Color("35565b"))
		button.custom_minimum_size.y = 82
		button.icon = _icons.get(spec[3])
		button.expand_icon = true
		button.pressed.connect(func():
			_audio_settings[key] = not bool(_audio_settings[key])
			audio_setting_changed.emit(key, bool(_audio_settings[key]))
			_update_audio_buttons()
		)
	var privacy := _action("PRIVACY CHOICES", "PrivacyOptionsButton", Color("30484a"))
	privacy.custom_minimum_size.y = 44
	privacy.add_theme_font_size_override("font_size", 14)
	privacy.visible = _privacy_options_required
	privacy.pressed.connect(func(): privacy_options_requested.emit())
	_spacer(15)
	var back := _action("BACK", "AudioBackButton", Color("548d94"))
	back.pressed.connect(_return_from_audio)
	_update_audio_buttons()
	_finish_overlay()


func _update_audio_buttons() -> void:
	for spec in [["music", "MusicToggle", "BACKGROUND MUSIC", "music"], ["sfx", "SfxToggle", "SOUND EFFECTS", "sound"]]:
		var button := _card.get_node_or_null(str(spec[1])) as Button
		if button == null:
			continue
		var enabled := bool(_audio_settings[spec[0]])
		button.text = "%s   %s" % [spec[2], "ON" if enabled else "OFF"]
		button.icon = _icons.get(str(spec[3]) if enabled else str(spec[3]) + "_disabled")
		button.add_theme_stylebox_override("normal", _box(Color("355f5c") if enabled else Color("344249"), Color("8fcab5") if enabled else Color("677a7e")))


func _return_from_audio() -> void:
	_restore_overlay(_audio_previous_kind, _audio_previous_data)


func close_auxiliary_overlay() -> bool:
	if _overlay_kind == "audio":
		_return_from_audio()
		return true
	if _overlay_kind in ["scores", "achievements"]:
		_return_overlay()
		return true
	return false


func show_end(data: Dictionary) -> void:
	_overlay_data = data.duplicate(true)
	_new_overlay("end")
	_add_text("A GLORIOUS LITTLE MESS", 14, GOLD)
	_add_text("%s" % _number(int(data.get("score", 0))), 72 if int(data.get("score", 0)) < 1000000 else 52, CREAM)
	_add_text("NEW BEST!" if bool(data.get("new_best", false)) else "BEST  " + _number(int(data.get("best", 0))), 20, GOLD)
	_spacer(4)
	_add_text("%d creatures   ·   %d bosses   ·   %s" % [int(data.get("kills", 0)), int(data.get("bosses", 0)), _duration(float(data.get("duration", 0)))], 16, MUTED)
	_add_text("BEST COMBO  %d" % int(data.get("combo", 0)), 14, MUTED)
	_spacer(19)
	_add_text("AGAIN?", 22, CREAM)
	_add_styles()
	_spacer(10)
	_footer(true, true)
	_finish_overlay()


func hide_overlay() -> void:
	_overlay.hide()
	_overlay_kind = ""
	_hud.show()
	_resize()
	overlay_changed.emit("")
	if OS.is_debug_build():
		print("INFINITESLASH_UI running")


func show_scores(profile: Dictionary, cloud_status: String) -> void:
	_remember_overlay()
	_overlay_data = {"profile": profile, "cloud_status": cloud_status}
	_new_overlay("scores")
	_add_text("HALL OF LITTLE LEGENDS", 14, GOLD)
	_add_text("SCORES", 48, CREAM)
	_add_text("PERSONAL BEST  " + _number(int(profile.get("best_score", 0))), 22, GOLD)
	_add_text("COMBO %d   ·   LEVEL %d   ·   BOSSES %d" % [int(profile.get("best_combo", 0)), int(profile.get("best_level", 1)), int(profile.get("best_bosses", 0))], 15, CREAM)
	_add_text(cloud_status if not cloud_status.is_empty() else "Saved on this device", 13, MUTED)
	_spacer(14)
	var history: Array = profile.get("run_history", [])
	if history.is_empty():
		_add_text("Your first legend starts with one tap.", 17, CREAM)
	else:
		var offset := maxi(0, history.size() - 8)
		for i in range(history.size() - 1, offset - 1, -1):
			var run: Dictionary = history[i] if history[i] is Dictionary else {}
			var style := str(run.get("style", run.get("mode", "sword"))).to_upper()
			var text := "%s   %s   ·   %s" % [style, _number(int(run.get("score", 0))), _duration(float(run.get("duration", run.get("elapsed", 0))))]
			_add_text(text, 16, CREAM)
	_spacer(20)
	var back := _action("BACK", "ScoresBackButton", Color("548d94"))
	back.pressed.connect(_return_overlay)
	_finish_overlay()


func show_achievements(profile: Dictionary) -> void:
	_remember_overlay()
	_overlay_data = {"profile": profile}
	_new_overlay("achievements")
	_add_text("YOUR LITTLE GLORIES", 14, GOLD)
	_add_text("BADGES", 48, CREAM)
	var earned: Variant = profile.get("achievements", {})
	var records := ACHIEVEMENTS.duplicate(true)
	var service := get_node_or_null("/root/SaveData")
	if service != null:
		var constants: Dictionary = service.get_script().get_script_constant_map()
		var titles: Dictionary = constants.get("ACHIEVEMENTS", {})
		for key in titles:
			if records.has(key):
				records[key][0] = str(titles[key])
			else:
				records[key] = [str(titles[key]), "Keep adventuring"]
	var scroll := ScrollContainer.new()
	scroll.name = "AchievementScroll"
	scroll.custom_minimum_size.y = minf(390.0, _size.y * 0.40)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "AchievementList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 5)
	scroll.add_child(list)
	var count := 0
	for key in records:
		var unlocked := false
		if earned is Dictionary:
			unlocked = bool(earned.get(key, false))
		elif earned is Array or earned is PackedStringArray:
			unlocked = key in earned
		if unlocked:
			count += 1
		var details: Array = records[key]
		var title := _label(("★  " if unlocked else "○  ") + str(details[0]), 17, GOLD if unlocked else MUTED)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(title)
		var description := _label(str(details[1]), 12, CREAM if unlocked else MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(description)
		var space := Control.new()
		space.custom_minimum_size.y = 8
		space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(space)
	_add_text("%d / %d EARNED" % [count, records.size()], 15, GOLD)
	_spacer(10)
	var back := _action("BACK", "AchievementsBackButton", Color("548d94"))
	back.pressed.connect(_return_overlay)
	_finish_overlay()


func toast(message: String, tint: Color = GOLD) -> void:
	if _toasts == null:
		return
	for existing in _toasts.get_children():
		if existing is Label and existing.text == message:
			return
	while _toasts.get_child_count() >= 3:
		var oldest := _toasts.get_child(0)
		_dispose_toast(oldest)
	var label := _label(message, 19, tint)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toasts.add_child(label)
	var tween := label.create_tween()
	label.set_meta("dismiss_tween", tween)
	tween.tween_interval(2.1)
	tween.tween_property(label, "modulate:a", 0.0, 0.45)
	tween.tween_callback(label.queue_free)


func _new_overlay(kind: String) -> void:
	if _toasts != null:
		for child in _toasts.get_children():
			_dispose_toast(child)
	for child in _overlay.get_children():
		# A pressed callback may still be inside the old button's input dispatch.
		# Hide it now, then free it after dispatch instead of detaching it mid-event.
		if child is CanvasItem:
			child.hide()
		child.queue_free()
	_overlay_kind = kind
	_hud.visible = kind == "pause"
	_overlay.show()
	_resize()
	var veil := ColorRect.new()
	veil.name = "ArenaVeil"
	veil.color = Color(0.045, 0.095, 0.115, 0.84 if kind in ["scores", "achievements"] else 0.76)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(veil)
	_card_scroll = ScrollContainer.new()
	_card_scroll.name = "OverlayScroll"
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_overlay.add_child(_card_scroll)
	_card_center = CenterContainer.new()
	_card_center.name = "OverlayCenter"
	_card_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_card_scroll.add_child(_card_center)
	_card = VBoxContainer.new()
	_card.name = "OverlayCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_constant_override("separation", 9)
	_card_center.add_child(_card)


func _dispose_toast(child: Node) -> void:
	if child.has_meta("dismiss_tween"):
		var tween: Tween = child.get_meta("dismiss_tween")
		if tween != null and tween.is_valid():
			tween.kill()
	_toasts.remove_child(child)
	child.queue_free()


func _finish_overlay() -> void:
	_position_card()
	call_deferred("_position_card")
	overlay_changed.emit(_overlay_kind)
	if OS.is_debug_build():
		print("INFINITESLASH_UI ", _overlay_kind)


func _title() -> void:
	_add_text("INFINITE", 45, CREAM)
	var slash := _add_text("SLASH", 84, GOLD)
	slash.add_theme_color_override("font_outline_color", Color("663d28"))
	slash.add_theme_constant_override("outline_size", 7)


func _add_styles() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size.y = 184
	_card.add_child(row)
	for style in ["sword", "shield"]:
		row.add_child(_style_button(style))


func _style_button(style: String) -> Button:
	var title := style.capitalize()
	var profile: Dictionary = ClassProfiles.PROFILES[style]
	var tint := Color("c88743") if style == "sword" else Color("4a9298")
	var button := _button("", title + "Button", tint)
	button.custom_minimum_size.y = 184
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func(): start_requested.emit(style))
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	button.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var details := VBoxContainer.new()
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 5)
	margin.add_child(details)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 10)
	details.add_child(heading)
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(39, 39)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _icons.get(style)
	heading.add_child(icon)
	var name_label := _label(style.to_upper(), 23, CREAM)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_child(name_label)
	var identity := _label("STRIKE FAST" if style == "sword" else "STAND STRONG", 12, CREAM)
	identity.name = title + "Identity"
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(identity)
	var strengths := _label("↑ DMG  ↑ SPEED" if style == "sword" else "↑ HP  ↑ GUARD", 17, Color("c4ffe3"))
	strengths.name = title + "Strengths"
	strengths.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(strengths)
	var tradeoffs := _label("↓ HP  ↓ GUARD" if style == "sword" else "↓ DMG  ↓ SPEED", 16, Color("ffe0d5"))
	tradeoffs.name = title + "Tradeoffs"
	tradeoffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(tradeoffs)
	var stats := _label("%d HP  ·  %d DMG" % [int(profile.health), int(profile.damage)], 17, CREAM)
	stats.name = title + "Stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.add_child(stats)
	return button


func _footer(include_daily: bool, include_share: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	_card.add_child(row)
	for spec in [["SCORES", "LeaderboardButton"], ["BADGES", "AchievementsButton"]]:
		var button := _button(spec[0], spec[1], Color("30484a"))
		button.custom_minimum_size.y = 49
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 14)
		if spec[1] == "LeaderboardButton":
			button.pressed.connect(func(): leaderboard_requested.emit())
		else:
			button.pressed.connect(func(): achievements_requested.emit())
		row.add_child(button)
	if include_daily:
		var daily := _button("DAILY RUN", "DailyButton", Color("30484a"))
		daily.custom_minimum_size.y = 49
		daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		daily.add_theme_font_size_override("font_size", 14)
		daily.pressed.connect(func(): daily_requested.emit())
		row.add_child(daily)
	if include_share:
		var share := _action("COPY MY LEGEND", "ShareButton", Color("30484a"))
		share.custom_minimum_size.y = 48
		share.add_theme_font_size_override("font_size", 14)
		share.pressed.connect(func(): share_requested.emit())
	_add_audio_button()


func _add_audio_button() -> void:
	var button := _action("AUDIO & PRIVACY" if _privacy_options_required else "AUDIO", "AudioSettingsButton", Color("30484a"))
	button.custom_minimum_size.y = 44
	button.add_theme_font_size_override("font_size", 14)
	button.icon = _icons.get("sound")
	button.expand_icon = true
	button.pressed.connect(show_audio_settings)


func _remember_overlay() -> void:
	if _overlay_kind not in ["scores", "achievements"]:
		_previous_kind = _overlay_kind if not _overlay_kind.is_empty() else "pause"
		_previous_data = _overlay_data.duplicate(true)


func _return_overlay() -> void:
	_restore_overlay(_previous_kind, _previous_data)


func _restore_overlay(kind: String, data: Dictionary) -> void:
	match kind:
		"end":
			show_end(data)
		"launch":
			show_launch(bool(data.get("can_resume", false)), int(data.get("best", 0)))
		"upgrade":
			show_upgrade_choices(data.get("choices", []), int(data.get("level", 2)))
		"scores":
			show_scores(data.get("profile", {}), str(data.get("cloud_status", "")))
		"achievements":
			show_achievements(data.get("profile", {}))
		"continue":
			show_continue_offer(data)
		"ad_waiting":
			show_ad_waiting(str(data.get("message", "Opening your reward…")))
		_:
			show_pause()


func _add_text(text: String, font_size: int, color: Color) -> Label:
	var label := _label(text, font_size, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card.add_child(label)
	return label


func _spacer(height: float) -> void:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.custom_minimum_size.y = height
	_card.add_child(space)


func _action(text: String, node_name: String, color: Color) -> Button:
	var button := _button(text, node_name, color)
	button.custom_minimum_size.y = 65
	_card.add_child(button)
	return button


func _button(text: String, node_name: String, color: Color, icon_name := "") -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", CREAM)
	if color.get_luminance() > 0.62:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, INK)
	button.add_theme_constant_override("icon_max_width", 26)
	button.add_theme_constant_override("h_separation", 12)
	button.add_theme_stylebox_override("normal", _box(color, color.lightened(0.16)))
	button.add_theme_stylebox_override("hover", _box(color.lightened(0.10), GOLD))
	button.add_theme_stylebox_override("pressed", _box(color.darkened(0.16), GOLD))
	if not icon_name.is_empty():
		button.icon = _icons.get(icon_name)
		button.expand_icon = true
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.07, 0.12, 0.13, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	return label


func _bar(node_name: String, foreground: Color, background: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.name = node_name
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	var bg := _box(background, background.lightened(0.08))
	bg.content_margin_left = 0
	bg.content_margin_right = 0
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	var fill := _box(foreground, foreground.lightened(0.16))
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _box(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(2)
	box.set_corner_radius_all(13)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	box.shadow_color = Color(0.02, 0.04, 0.05, 0.30)
	box.shadow_size = 4
	box.shadow_offset = Vector2(0, 4)
	return box


func _duration(seconds: float) -> String:
	var whole := maxi(0, int(seconds))
	return "%d:%02d" % [whole / 60, whole % 60]


func _fit_hud_number(label: Label, preferred: int, minimum: int) -> void:
	var font := label.get_theme_font("font")
	var size := preferred
	var width := maxf(80, label.size.x)
	while size > minimum and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
		size -= 1
	label.add_theme_font_size_override("font_size", size)

func _number(value: int) -> String:
	var raw := str(maxi(0, value))
	var output := ""
	for i in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0:
			output += ","
		output += raw[i]
	return output
