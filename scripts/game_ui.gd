extends CanvasLayer
## Compact portrait HUD and one-tap overlays. All game decisions belong to game.gd.

signal start_requested(style: String)
signal resume_requested
signal pause_requested
signal leaderboard_requested
signal achievements_requested
signal audio_toggled
signal daily_requested
signal share_requested

const GOLD := Color("ffd77a")
const CREAM := Color("fff2d3")
const INK := Color("19252a")
const MUTED := Color("a8bcbd")
const ACHIEVEMENTS := {
	"first_blood": ["First Slice", "Defeat your first creature"],
	"boss_slayer": ["Crown Collector", "Defeat a boss"],
	"century": ["A Hundred Little Problems", "Defeat 100 creatures"],
	"survivor": ["Still Standing", "Survive for 3 minutes"],
	"legend": ["Knight of Infinite Nonsense", "Defeat 5 bosses in one run"],
	"combo_25": ["Slice Streak", "Reach a 25-kill combo"],
	"score_10000": ["Five Digits of Slop", "Score 10,000 in one run"],
	"collector": ["Bestiary Complete", "Discover all 100 creatures"],
	"hundred_club": ["A Hundred in a Hurry", "Defeat 100 creatures in one run"],
	"survivor_60": ["Minute Knight", "Survive for one minute"],
	"survivor_180": ["Three Minute Hero", "Survive for three minutes"],
	"thousand_kills": ["Slop Sweeper", "Defeat 1,000 creatures"],
	"ten_runs": ["Back for More", "Complete ten runs"],
}

var _root: Control
var _hud: Control
var _overlay: Control
var _card: VBoxContainer
var _toasts: VBoxContainer
var _health: ProgressBar
var _xp: ProgressBar
var _guard: ProgressBar
var _boss: ProgressBar
var _health_text: Label
var _score: Label
var _best: Label
var _level: Label
var _combo: Label
var _time: Label
var _dash: Label
var _buffs: Label
var _boss_name: Label
var _pause: Button
var _sound: Button
var _sound_enabled := true
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
	for icon in ["sword", "shield", "pause", "sound", "sound_disabled", "star"]:
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
	_xp = _bar("ExperienceBar", GOLD, Color("3b493c"))
	_hud.add_child(_xp)
	_score = _label("0", 32, CREAM)
	_score.name = "ScoreLabel"
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_score)
	_best = _label("BEST 0", 13, GOLD)
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_best)
	_level = _label("LV 1", 13, GOLD)
	_hud.add_child(_level)
	_time = _label("0:00", 14, CREAM)
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_time)
	_combo = _label("", 22, GOLD)
	_combo.name = "ComboLabel"
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_combo)
	_dash = _label("DASH READY", 11, Color("b2e5e7"))
	_dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hud.add_child(_dash)
	_guard = _bar("GuardBar", Color("86d7d3"), Color("233d40"))
	_hud.add_child(_guard)
	_buffs = _label("", 13, GOLD)
	_buffs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buffs.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hud.add_child(_buffs)
	_boss_name = _label("", 16, GOLD)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_child(_boss_name)
	_boss = _bar("BossHealthBar", Color("ef965a"), Color("433538"))
	_hud.add_child(_boss)
	_boss.hide()
	_pause = _button("", "PauseButton", Color("354b4d"), "pause")
	_pause.pressed.connect(func(): pause_requested.emit())
	_hud.add_child(_pause)
	_sound = _button("", "SoundButton", Color("354b4d"), "sound")
	_sound.pressed.connect(_toggle_sound)
	_hud.add_child(_sound)


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
	var hp_width := minf(205.0, _size.x * 0.39)
	_place(_health, Vector2(24, _top + 5), Vector2(hp_width, 22))
	_place(_health_text, Vector2(24, _top + 5), Vector2(hp_width, 22))
	_place(_xp, Vector2(24, _top + 34), Vector2(hp_width, 5))
	_place(_level, Vector2(24, _top + 45), Vector2(80, 20))
	_place(_score, Vector2(_size.x - 225, _top - 6), Vector2(136, 38))
	_place(_best, Vector2(_size.x - 240, _top + 30), Vector2(151, 20))
	_place(_time, Vector2(_size.x * 0.5 - 40, _top + 44), Vector2(80, 20))
	_place(_pause, Vector2(_size.x - 71, _top - 5), Vector2(48, 48))
	_place(_sound, Vector2(_size.x - 71, _top + 48), Vector2(48, 42))
	_place(_combo, Vector2(70, _top + 89), Vector2(_size.x - 140, 31))
	_place(_boss_name, Vector2(55, _top + 125), Vector2(_size.x - 110, 24))
	_place(_boss, Vector2(55, _top + 154), Vector2(_size.x - 110, 9))
	_place(_guard, Vector2(26, _size.y - _bottom - 10), Vector2(100, 5))
	_place(_dash, Vector2(_size.x - 162, _size.y - _bottom - 19), Vector2(137, 22))
	_place(_buffs, Vector2(140, _size.y - _bottom - 25), Vector2(_size.x - 290, 32))
	var toast_y := _size.y - _bottom - 112.0 if _overlay.visible else _top + 182.0
	_place(_toasts, Vector2(30, toast_y), Vector2(_size.x - 60, 110))
	if _card != null and is_instance_valid(_card):
		_position_card()


func _place(control: Control, at: Vector2, dimensions: Vector2) -> void:
	control.position = at
	control.size = dimensions


func _position_card() -> void:
	var width := minf(468.0, _size.x - 54.0)
	_card.size.x = width
	var height := _card.get_combined_minimum_size().y
	_card.position = Vector2((_size.x - width) * 0.5, maxf(_top + 20.0, (_size.y - height) * 0.5))


func update_hud(data: Dictionary) -> void:
	if _health == null:
		return
	var hp := float(data.get("health", 100))
	var maximum := maxf(1.0, float(data.get("max_health", 100)))
	_health.max_value = maximum
	_health.value = hp
	_health_text.text = "%d / %d" % [int(ceil(hp)), int(maximum)]
	_score.text = _number(int(data.get("score", 0)))
	_best.text = "BEST " + _number(int(data.get("best", 0)))
	_level.text = "LV %d" % int(data.get("level", 1))
	_xp.max_value = maxf(1.0, float(data.get("xp_goal", 1)))
	_xp.value = float(data.get("xp", 0))
	var combo := int(data.get("combo", 0))
	_combo.text = "%d COMBO  ×%d" % [combo, int(data.get("multiplier", 1))] if combo >= 3 else ""
	_time.text = _duration(float(data.get("elapsed", 0)))
	_dash.text = "DASH READY" if bool(data.get("dash_ready", true)) else "DASH RECHARGING"
	_dash.modulate.a = 1.0 if bool(data.get("dash_ready", true)) else 0.5
	_guard.value = clampf(float(data.get("guard_ratio", 1.0)), 0.0, 1.0) * 100.0
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


func show_end(data: Dictionary) -> void:
	_overlay_data = data.duplicate(true)
	_new_overlay("end")
	_add_text("A GLORIOUS LITTLE MESS", 14, GOLD)
	_add_text("%s" % _number(int(data.get("score", 0))), 72, CREAM)
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
	if OS.is_debug_build():
		print("INFINITESLASH_UI running")


func show_scores(profile: Dictionary, cloud_status: String) -> void:
	_remember_overlay()
	_overlay_data = {"profile": profile, "cloud_status": cloud_status}
	_new_overlay("scores")
	_add_text("HALL OF LITTLE LEGENDS", 14, GOLD)
	_add_text("SCORES", 48, CREAM)
	_add_text("PERSONAL BEST  " + _number(int(profile.get("best_score", 0))), 22, GOLD)
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
	_card = VBoxContainer.new()
	_card.name = "OverlayCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_constant_override("separation", 9)
	_overlay.add_child(_card)


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
	row.custom_minimum_size.y = 125
	_card.add_child(row)
	var sword := _button("SWORD", "SwordButton", Color("c88743"), "sword")
	sword.custom_minimum_size.y = 125
	sword.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sword.add_theme_font_size_override("font_size", 23)
	sword.add_theme_constant_override("icon_max_width", 47)
	sword.pressed.connect(func(): start_requested.emit("sword"))
	row.add_child(sword)
	var shield := _button("SHIELD", "ShieldButton", Color("4a9298"), "shield")
	shield.custom_minimum_size.y = 125
	shield.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shield.add_theme_font_size_override("font_size", 23)
	shield.add_theme_constant_override("icon_max_width", 43)
	shield.pressed.connect(func(): start_requested.emit("shield"))
	row.add_child(shield)


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


func _remember_overlay() -> void:
	if _overlay_kind not in ["scores", "achievements"]:
		_previous_kind = _overlay_kind if not _overlay_kind.is_empty() else "pause"
		_previous_data = _overlay_data.duplicate(true)


func _return_overlay() -> void:
	match _previous_kind:
		"end":
			show_end(_previous_data)
		"launch":
			show_launch(bool(_previous_data.get("can_resume", false)), int(_previous_data.get("best", 0)))
		_:
			show_pause()


func _toggle_sound() -> void:
	_sound_enabled = not _sound_enabled
	_sound.icon = _icons.get("sound" if _sound_enabled else "sound_disabled")
	audio_toggled.emit()


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


func _number(value: int) -> String:
	var raw := str(maxi(0, value))
	var output := ""
	for i in range(raw.length()):
		if i > 0 and (raw.length() - i) % 3 == 0:
			output += ","
		output += raw[i]
	return output
