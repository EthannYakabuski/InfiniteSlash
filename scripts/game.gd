extends Node2D
## Bounded, fixed-step arcade simulation. No entity loads resources during combat.

const WorldScript = preload("res://scripts/world.gd")
const UIScript = preload("res://scripts/game_ui.gd")
const MAX_ENEMIES = 100
const MAX_BULLETS = 240
const MAX_DROPS = 60
const MAX_EFFECTS = 90
const PLAYER_RADIUS = 13.0
const BOSS_TITLES = ["THE TINPOT KING", "DUCHESS WOBBLE", "MOSSJAW THE HUNGRY", "SIR SPIT-A-LOT", "THE PUMPKIN PROBLEM", "MADAME MOONMOTH", "CAPTAIN CLATTER", "THE CROWN OF SLOP"]
const UNLOCK_TIMES = {"chaser": 0.0, "skitter": 12.0, "tank": 20.0, "spitter": 16.0, "charger": 25.0, "fan": 32.0, "orbiter": 38.0, "splitter": 45.0}
const BUFF_NAMES = {"haste": "QUICKSILVER", "hurricane": "HURRICANE", "ward": "THREE-HIT WARD", "magnet": "LOOT MAGNET", "frost": "FROSTBITE", "spark": "THUNDERBLADE"}
const ACHIEVEMENT_NAMES = {"first_blood": "FIRST SLICE", "boss_slayer": "CROWN COLLECTOR", "century": "A HUNDRED LITTLE PROBLEMS", "hundred_club": "CENTURY CLUB", "survivor": "STILL STANDING", "survivor_60": "ONE MINUTE WONDER", "survivor_180": "STILL STANDING", "legend": "KNIGHT OF INFINITE NONSENSE", "combo_25": "SLICE STREAK", "score_10000": "FIVE DIGITS OF SLOP", "collector": "BESTIARY COMPLETE", "thousand_kills": "A THOUSAND SLICES", "ten_runs": "ONE MORE RUN"}

var world
var hud
var roster: Array = []
var textures: Array = []
var monster_atlas: Texture2D
var projectile_atlas: Texture2D
var shadow_texture: Texture2D
var hero_texture: Texture2D
var weapon_fallback: Texture2D = preload("res://Assets/MobileControls/Sprites/Icons/Default/icon_sword.png")
var shield_fallback: Texture2D = preload("res://Assets/MobileControls/Sprites/Icons/Default/icon_shield.png")
var arena = Vector2(540, 960)
var state = "launch"
var style = "sword"
var daily = false
var challenge_date = ""
var run_seed: int = 0
var rng = RandomNumberGenerator.new()
var loot_rng = RandomNumberGenerator.new()
var visual_rng = RandomNumberGenerator.new()
var player_pos = Vector2(270, 720)
var move_direction = Vector2.ZERO
var facing = Vector2.UP
var health = 100.0
var max_health = 100.0
var damage = 20.0
var attack_interval = 0.46
var attack_range = 84.0
var move_speed = 265.0
var elapsed = 0.0
var visual_time = 0.0
var score: int = 0
var kills: int = 0
var bosses: int = 0
var powerups: int = 0
var combo: int = 0
var best_combo: int = 0
var combo_timer = 0.0
var level: int = 1
var xp: int = 0
var xp_goal: int = 8
var ward_hits: int = 0
var buffs: Dictionary = {}
var spawn_timer = 0.65
var next_boss = 45.0
var boss_number: int = 0
var relief_until = 0.0
var swing_timer = 0.12
var slash_time = 0.0
var slash_angle = -PI / 2
var slash_serial: int = 0
var hurt_timer = 0.0
var dash_timer = 0.0
var dash_cooldown = 0.0
var dash_direction = Vector2.UP
var guard_reserve = 100.0
var guard_capacity = 100.0
var guarding = false
var parry_timer = 0.0
var parry_rearm = 0.0
var was_moving = false
var hitstop = 0.0
var shake = 0.0
var spark_timer = 0.0
var save_timer = 0.0
var hud_timer = 0.0
var enemies: Array = []
var bullets: Array = []
var drops: Array = []
var effects: Array = []
var active_touch: int = -1
var dragging = false
var touch_origin = Vector2.ZERO
var touch_position = Vector2.ZERO
var gesture_origin = Vector2.ZERO
var gesture_started = 0.0
var gesture_dashed = false
var keyboard_active = false
var demo = false
var testing = false
var ready_complete = false

func _ready() -> void:
	visual_rng.randomize()
	arena = get_viewport_rect().size
	_build_render_textures()
	_load_roster()
	if ResourceLoader.exists("res://Assets/Generated/knight_sheet.png"):
		hero_texture = load("res://Assets/Generated/knight_sheet.png")
	world = WorldScript.new()
	add_child(world)
	move_child(world, 0)
	hud = UIScript.new()
	add_child(hud)
	hud.start_requested.connect(func(choice: String): start_run(choice))
	hud.resume_requested.connect(resume_run)
	hud.pause_requested.connect(pause_run)
	hud.leaderboard_requested.connect(_show_scores)
	hud.achievements_requested.connect(_show_achievements)
	hud.audio_toggled.connect(_toggle_audio)
	hud.daily_requested.connect(func(): start_run("sword", true))
	if hud.has_signal("share_requested"):
		hud.share_requested.connect(_share_score)
	SaveData.achievement_unlocked.connect(_achievement_toast)
	PlayServices.local_leaderboards_requested.connect(func(): hud.show_scores(SaveData.profile, str(PlayServices.status)))
	PlayServices.local_achievements_requested.connect(func(): hud.show_achievements(SaveData.profile))
	get_tree().auto_accept_quit = false
	get_tree().quit_on_go_back = false
	ready_complete = true
	var args = OS.get_cmdline_user_args()
	testing = "--test" in args
	demo = "--demo" in args or "--stress" in args
	if not SaveData.active_run.is_empty() and not testing and not demo:
		if restore_run(SaveData.active_run):
			hud.show_launch(true, int(SaveData.profile.get("best_score", 0)))
		else:
			SaveData.clear_active_run()
			_show_launch()
	else:
		_show_launch()
	if demo:
		start_run("sword")
		if "--stress" in args:
			elapsed = 240.0
			for i in range(MAX_ENEMIES):
				spawn_enemy(i % roster.size(), false, Vector2(rng.randf_range(20, arena.x - 20), rng.randf_range(160, arena.y - 130)))
			for i in range(MAX_BULLETS):
				_add_bullet(Vector2(rng.randf_range(0, arena.x), rng.randf_range(150, arena.y)), Vector2.from_angle(rng.randf() * TAU) * 120, 10, true)
	_update_hud()

func _build_render_textures() -> void:
	# Tiny code-native pixel shapes keep the same rim/core visuals in one quad.
	var image = Image.create(54, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var colors = [Color("ffc077"), Color("ff895e"), Color("a1dfee")]
	for variant in range(3):
		for y in range(18):
			for x in range(18):
				var distance = Vector2(x - 8.5, y - 8.5).length()
				var color = Color("3e2835") if distance < 8.5 else Color.TRANSPARENT
				if distance < 6.5: color = colors[variant]
				if Vector2(x - 7.5, y - 7.5).length() < 2.8: color = Color("fff3cc")
				image.set_pixel(variant * 18 + x, y, color)
	projectile_atlas = ImageTexture.create_from_image(image)
	var shadow = Image.create(32, 12, false, Image.FORMAT_RGBA8)
	shadow.fill(Color.TRANSPARENT)
	for y in range(12):
		for x in range(32):
			if pow((x - 15.5) / 15.5, 2) + pow((y - 5.5) / 5.5, 2) < 1:
				shadow.set_pixel(x, y, Color(0.07, 0.12, 0.1, 0.28))
	shadow_texture = ImageTexture.create_from_image(shadow)

func _load_roster() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	if parsed is Array:
		roster = parsed
	else:
		push_error("Monster roster is missing or invalid.")
	roster.append({"id": "original_tinpot", "name": "Cinder Tinpot", "texture": "res://Assets/Monsters/creature-sheet (2).png", "behavior": "chaser", "health": 36, "damage": 10, "speed": 68, "score": 20, "radius": 17, "shoot_interval": 2.8, "bullet_speed": 130, "generated": false, "animation_fps": 8})
	if ResourceLoader.exists("res://Assets/Generated/monster_atlas.png"):
		monster_atlas = load("res://Assets/Generated/monster_atlas.png")
	for item in roster:
		textures.append(monster_atlas if monster_atlas != null else load(str(item.texture)))

func _show_launch() -> void:
	state = "launch"
	player_pos = Vector2(arena.x * 0.5, arena.y * 0.69)
	hud.show_launch(false, int(SaveData.profile.get("best_score", 0)))

func start_run(choice: String = "sword", daily_challenge: bool = false) -> void:
	style = "shield" if choice == "shield" else "sword"
	daily = daily_challenge
	challenge_date = Time.get_date_string_from_system(true) if daily else ""
	run_seed = int(challenge_date.replace("-", "")) * 7919 if daily else int(Time.get_ticks_usec())
	rng.seed = run_seed
	loot_rng.seed = run_seed ^ 1234567
	state = "running"
	enemies.clear()
	bullets.clear()
	drops.clear()
	effects.clear()
	max_health = 125.0 if style == "shield" else 100.0
	health = max_health
	damage = 16.0 if style == "shield" else 22.0
	attack_interval = 0.51 if style == "shield" else 0.46
	attack_range = 84.0
	move_speed = 245.0 if style == "shield" else 265.0
	guard_capacity = 130.0 if style == "shield" else 100.0
	guard_reserve = guard_capacity
	player_pos = Vector2(arena.x * 0.5, arena.y * 0.72)
	facing = Vector2.UP
	move_direction = Vector2.ZERO
	elapsed = 0.0
	score = 0
	kills = 0
	bosses = 0
	powerups = 0
	combo = 0
	best_combo = 0
	combo_timer = 0.0
	level = 1
	xp = 0
	xp_goal = 8
	ward_hits = 0
	buffs.clear()
	spawn_timer = 0.45
	next_boss = 45.0
	boss_number = 0
	relief_until = 0.0
	swing_timer = 0.15
	slash_time = 0.0
	hurt_timer = 0.0
	dash_timer = 0.0
	dash_cooldown = 0.0
	parry_timer = 0.0
	parry_rearm = 0.0
	hitstop = 0.0
	shake = 0.0
	spark_timer = 0.0
	save_timer = 0.0
	guarding = false
	was_moving = false
	_release_input()
	world.reset()
	hud.hide_overlay()
	AudioManager.play_sound("start")
	if not testing and not demo:
		SaveData.clear_active_run()
		SaveData.save_active_run(serialize_run())
	if daily:
		hud.toast("DAILY TROUBLE · " + challenge_date, Color("ffd580"))
	elif not testing:
		hud.toast("INTO THE NONSENSE", Color("fff1d0"))
	_update_hud()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if state != "running":
		return
	tick(minf(delta, 0.05))

func tick(delta: float) -> void:
	elapsed += delta
	combo_timer = maxf(0, combo_timer - delta)
	if combo_timer <= 0:
		combo = 0
	for key in buffs.keys():
		buffs[key] = maxf(0, float(buffs[key]) - delta)
		if buffs[key] <= 0:
			buffs.erase(key)
			if key == "ward": ward_hits = 0
	dash_cooldown = maxf(0, dash_cooldown - delta)
	hurt_timer = maxf(0, hurt_timer - delta)
	parry_timer = maxf(0, parry_timer - delta)
	parry_rearm = maxf(0, parry_rearm - delta)
	if hitstop > 0:
		hitstop -= delta
		return
	_update_player(delta)
	_update_spawns(delta)
	_update_enemies(delta)
	_update_bullets(delta)
	_update_drops(delta)
	_update_weapon(delta)
	if buffs.has("spark"):
		spark_timer -= delta
		if spark_timer <= 0:
			spark_timer = 0.9
			_chain_lightning()
	for i in range(enemies.size() - 1, -1, -1):
		if not enemies[i].alive:
			enemies.remove_at(i)
	save_timer += delta
	if save_timer >= 10.0 and not testing and not demo:
		save_timer = 0.0
		SaveData.save_active_run(serialize_run())
	if health <= 0 and state == "running":
		end_run()

func _process(delta: float) -> void:
	visual_time += minf(delta, 0.05)
	if get_viewport_rect().size != arena:
		arena = get_viewport_rect().size
		player_pos = _clamp_player(player_pos)
	slash_time = maxf(0, slash_time - delta)
	shake = maxf(0, shake - delta * 25)
	for i in range(effects.size() - 1, -1, -1):
		var effect = effects[i]
		effect.life -= delta
		if effect.kind != "lightning": effect.pos += effect.vel * delta
		if effect.life <= 0: effects.remove_at(i)
	if world != null:
		world.advance(delta if state == "running" else delta * 0.18 if state == "launch" else 0.0, elapsed)
	hud_timer -= delta
	if hud_timer <= 0 and ready_complete:
		hud_timer = 0.08
		_update_hud()
	queue_redraw()

func _update_player(delta: float) -> void:
	var keyboard = Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	keyboard_active = keyboard.length_squared() > 0.01
	if keyboard_active:
		move_direction = keyboard.normalized()
	elif dragging:
		var offset = touch_position - touch_origin
		move_direction = offset.limit_length(65) / 65.0 if offset.length() > 9 else Vector2.ZERO
	else:
		move_direction = Vector2.ZERO
	if demo:
		var target = Vector2(arena.x * 0.5 + sin(elapsed * 0.8) * arena.x * 0.31, arena.y * 0.64 + cos(elapsed * 0.6) * 120)
		move_direction = (target - player_pos).limit_length(60) / 60.0
	var moving = move_direction.length_squared() > 0.01
	if was_moving and not moving and parry_rearm <= 0 and guard_reserve > 4:
		parry_timer = 0.23 if style == "shield" else 0.16
		parry_rearm = 0.65
	was_moving = moving
	guarding = not moving and dash_timer <= 0 and guard_reserve > 0
	if guarding:
		guard_reserve = maxf(0, guard_reserve - 28.0 * delta)
		if guard_reserve <= 0: guarding = false
	elif moving:
		guard_reserve = minf(guard_capacity, guard_reserve + 20.0 * delta)
	if moving:
		facing = move_direction.normalized()
	if dash_timer > 0:
		dash_timer = maxf(0, dash_timer - delta)
		player_pos += dash_direction * 630.0 * delta
		if effects.size() < MAX_EFFECTS and int(elapsed * 60) % 2 == 0:
			_add_effect(player_pos, Vector2.ZERO, "trail", Color("8fe4ea"), 0.25)
	else:
		player_pos += move_direction * move_speed * (1.12 if buffs.has("haste") else 1.0) * delta
	player_pos = _clamp_player(player_pos)

func _clamp_player(pos: Vector2) -> Vector2:
	return Vector2(clampf(pos.x, 25, arena.x - 25), clampf(pos.y, 152, arena.y - 58))

func try_dash(direction: Vector2) -> bool:
	if state != "running" or dash_cooldown > 0 or direction.length_squared() < 0.01:
		return false
	dash_direction = direction.normalized()
	dash_timer = 0.18
	dash_cooldown = 1.45
	guarding = false
	AudioManager.play_sound("dash")
	return true

func _update_spawns(delta: float) -> void:
	spawn_timer -= delta
	var has_boss = _boss() != null
	if elapsed >= next_boss and not has_boss:
		# A full ordinary wave must never silently consume a boss event.
		if enemies.size() >= MAX_ENEMIES:
			enemies.remove_at(0)
		boss_number += 1
		spawn_enemy(roster.size() - 1 if boss_number == 1 else rng.randi_range(0, roster.size() - 2), true, Vector2(arena.x * 0.5, 190))
		next_boss = elapsed + 45.0
		has_boss = true
		hud.toast(BOSS_TITLES[(boss_number - 1) % BOSS_TITLES.size()], Color("ffb679"))
		AudioManager.play_sound("boss")
		shake = 5.0
	if spawn_timer <= 0:
		spawn_timer = maxf(0.23, 0.88 - elapsed * 0.0018) * (1.8 if has_boss else 1.0) * (2.8 if elapsed < relief_until else 1.0)
		var group = mini(4, 1 + int(elapsed / 75.0))
		for n in range(group):
			spawn_enemy()

func _choose_monster() -> int:
	var eligible: Array[int] = []
	for i in range(roster.size()):
		if elapsed >= float(UNLOCK_TIMES.get(str(roster[i].behavior), 0.0)):
			eligible.append(i)
	return eligible[rng.randi_range(0, eligible.size() - 1)] if not eligible.is_empty() else 0

func spawn_enemy(index: int = -1, is_boss: bool = false, spawn_pos: Vector2 = Vector2.INF, is_minion: bool = false) -> Dictionary:
	if enemies.size() >= MAX_ENEMIES:
		return {}
	if index < 0: index = _choose_monster()
	index = clampi(index, 0, roster.size() - 1)
	var info = roster[index]
	if spawn_pos == Vector2.INF:
		if rng.randf() < 0.72:
			spawn_pos = Vector2(rng.randf_range(30, arena.x - 30), 95)
		else:
			spawn_pos = Vector2(-35 if rng.randf() < 0.5 else arena.x + 35, rng.randf_range(190, arena.y * 0.6))
	var scaling = 1.0 + minf(1.6, elapsed / 430.0)
	var hp = float(info.health) * scaling
	if is_boss: hp = 560.0 * pow(1.21, minf(12, boss_number - 1))
	if is_minion: hp = 12.0 * scaling
	var enemy = {"kind": index, "pos": spawn_pos, "hp": hp, "max_hp": hp, "radius": 35.0 if is_boss else float(info.get("radius", 16)) * (0.65 if is_minion else 1.0), "speed": 58.0 if is_boss else float(info.speed) * (1.0 + minf(0.4, elapsed / 900.0)), "damage": minf(26, float(info.damage) * (1.0 + elapsed / 1100.0)), "behavior": "boss" if is_boss else "chaser" if is_minion else str(info.behavior), "boss": is_boss, "minion": is_minion, "alive": true, "age": 0.0, "cooldown": rng.randf_range(1.4, 2.6), "windup": 0.0, "charge": 0.0, "aim": Vector2.DOWN, "knock": Vector2.ZERO, "flash": 0.0, "phase": 0, "anim": rng.randf() * 4.0, "last_slash": -1}
	enemies.append(enemy)
	return enemy

func _update_enemies(delta: float) -> void:
	var slow = 0.65 if buffs.has("frost") else 1.0
	for enemy in enemies:
		if not enemy.alive: continue
		enemy.age += delta
		enemy.flash = maxf(0, enemy.flash - delta)
		enemy.cooldown -= delta
		var offset = player_pos - enemy.pos
		var distance = offset.length()
		var direction = offset / maxf(0.01, distance)
		var velocity = direction * enemy.speed
		var behavior = str(enemy.behavior)
		if enemy.charge > 0:
			enemy.charge -= delta
			velocity = enemy.aim * (340.0 if enemy.boss else 290.0)
		elif enemy.windup > 0:
			enemy.windup = maxf(0, enemy.windup - delta)
			velocity = Vector2.ZERO
			if enemy.windup <= 0: _fire_enemy(enemy)
		elif behavior == "boss":
			var desired = Vector2(arena.x * 0.5 + sin(enemy.age * 0.8) * arena.x * 0.29, clampf(player_pos.y - 170, 190, arena.y * 0.58))
			velocity = (desired - enemy.pos).limit_length(60)
			if enemy.cooldown <= 0: _prepare_attack(enemy)
		elif behavior in ["spitter", "fan", "orbiter"]:
			if behavior == "orbiter":
				velocity = direction.rotated(PI * 0.44) * enemy.speed
				if distance < 180: velocity -= direction * enemy.speed * 0.8
				elif distance > 260: velocity += direction * enemy.speed * 0.7
			else:
				velocity *= 0.9 if distance > 245 else -0.65 if distance < 150 else 0.0
			if enemy.cooldown <= 0 and enemy.age > 1.1 and _is_on_screen(enemy.pos): _prepare_attack(enemy)
		elif behavior == "charger":
			if enemy.cooldown <= 0 and distance < 340 and enemy.age > 1.0: _prepare_attack(enemy)
		elif behavior == "skitter":
			velocity = direction.rotated(sin(enemy.age * 5.0 + enemy.anim) * 0.6) * enemy.speed
		if behavior == "tank": velocity *= 0.85
		velocity += enemy.knock
		enemy.knock = enemy.knock.move_toward(Vector2.ZERO, 540 * delta)
		enemy.pos += velocity * delta * slow
		if not enemy.boss and (enemy.pos.y > arena.y + 150 or enemy.age > 70):
			enemy.alive = false
			continue
		if enemy.age > 0.5 and enemy.pos.distance_squared_to(player_pos) < pow(enemy.radius + PLAYER_RADIUS, 2):
			damage_player(enemy.damage, (player_pos - enemy.pos).normalized())

func _is_on_screen(pos: Vector2) -> bool:
	return pos.x > 8 and pos.x < arena.x - 8 and pos.y > 140 and pos.y < arena.y - 25

func _prepare_attack(enemy: Dictionary) -> void:
	enemy.aim = (player_pos - enemy.pos).normalized()
	enemy.windup = 0.85 if enemy.boss else 0.7 if enemy.behavior == "charger" else 0.6
	if enemy.boss: enemy.phase += 1

func _fire_enemy(enemy: Dictionary) -> void:
	var info = roster[enemy.kind]
	var bullet_speed = maxf(115, float(info.get("bullet_speed", 130))) + minf(65, elapsed * 0.13)
	if enemy.boss:
		enemy.cooldown = maxf(1.5, 2.9 - boss_number * 0.09)
		match int(enemy.phase) % 3:
			0:
				for i in range(14):
					if i in [0, 1, 13]: continue
					var angle = enemy.aim.angle() + float(i) * TAU / 14.0
					_add_bullet(enemy.pos, Vector2.from_angle(angle) * (125 + mini(50, boss_number * 6)), 13, true)
			1:
				for i in range(-2, 3): _add_bullet(enemy.pos, enemy.aim.rotated(i * 0.25) * bullet_speed, 14, true)
			2:
				if boss_number >= 2:
					enemy.charge = 0.48
				else:
					for i in range(-1, 2): _add_bullet(enemy.pos, enemy.aim.rotated(i * 0.38) * bullet_speed, 12, true)
	elif enemy.behavior == "charger":
		enemy.charge = 0.48
		enemy.cooldown = 2.7
	else:
		enemy.cooldown = maxf(1.2, float(info.get("shoot_interval", 2.8)) - elapsed * 0.0015)
		if enemy.behavior == "fan":
			for i in range(-1, 2): _add_bullet(enemy.pos, enemy.aim.rotated(i * 0.32) * bullet_speed, enemy.damage, false)
		else:
			_add_bullet(enemy.pos, enemy.aim * bullet_speed, enemy.damage, false)

func _add_bullet(pos: Vector2, velocity: Vector2, bullet_damage: float, boss_shot: bool = false) -> void:
	if bullets.size() >= MAX_BULLETS: return
	bullets.append({"pos": pos, "vel": velocity, "damage": bullet_damage, "life": 7.0, "boss": boss_shot, "radius": 6.0 if boss_shot else 5.0})

func _update_bullets(delta: float) -> void:
	var slow = 0.62 if buffs.has("frost") else 1.0
	for i in range(bullets.size() - 1, -1, -1):
		var bullet = bullets[i]
		bullet.pos += bullet.vel * delta * slow
		bullet.life -= delta
		if bullet.life <= 0 or not Rect2(Vector2(-70, 80), arena + Vector2(140, 30)).has_point(bullet.pos):
			bullets.remove_at(i)
			continue
		var distance = bullet.pos.distance_to(player_pos)
		if guarding and guard_reserve > 0 and distance < 34 + bullet.radius:
			var perfect = parry_timer > 0
			guard_reserve = clampf(guard_reserve + (4 if perfect else -8), 0, guard_capacity)
			if perfect: score += 4
			_burst(bullet.pos, Color("b0edf1") if perfect else Color("ffd382"), 3)
			AudioManager.play_sound("block")
			bullets.remove_at(i)
		elif distance < PLAYER_RADIUS + bullet.radius:
			damage_player(bullet.damage, bullet.vel.normalized())
			bullets.remove_at(i)

func _update_weapon(delta: float) -> void:
	swing_timer -= delta
	if swing_timer > 0: return
	var nearest = null
	var best_distance = 210.0 * 210.0
	for enemy in enemies:
		if not enemy.alive: continue
		var distance = player_pos.distance_squared_to(enemy.pos)
		if distance < best_distance:
			nearest = enemy
			best_distance = distance
	var direction = (nearest.pos - player_pos).normalized() if nearest != null else facing
	perform_slash(direction)
	swing_timer = (0.83 if guarding else attack_interval) * (0.67 if buffs.has("haste") else 1.0)

func perform_slash(direction: Vector2) -> void:
	slash_serial += 1
	slash_time = 0.18
	slash_angle = direction.angle()
	var reach = attack_range + (34 if buffs.has("hurricane") else 0)
	var half_arc = 1.42 if buffs.has("hurricane") else 1.24
	AudioManager.play_sound("slash", 1.0 + level * 0.005)
	for enemy in enemies:
		if not enemy.alive or enemy.last_slash == slash_serial: continue
		var offset = enemy.pos - player_pos
		if offset.length() <= reach + enemy.radius and (offset.length() < 25 or absf(wrapf(offset.angle() - slash_angle, -PI, PI)) <= half_arc):
			enemy.last_slash = slash_serial
			damage_enemy(enemy, damage * (1.3 if buffs.has("hurricane") else 1.0), offset.normalized() * 165)
	for i in range(bullets.size() - 1, -1, -1):
		var offset = bullets[i].pos - player_pos
		if offset.length() < reach and absf(wrapf(offset.angle() - slash_angle, -PI, PI)) < half_arc:
			_burst(bullets[i].pos, Color("ffe0a0"), 2)
			bullets.remove_at(i)

func damage_enemy(enemy: Dictionary, amount: float, knockback: Vector2 = Vector2.ZERO) -> void:
	if not enemy.alive: return
	enemy.hp -= amount
	enemy.flash = 0.12
	enemy.knock = knockback * (0.2 if enemy.boss else 0.45 if enemy.behavior == "tank" else 1.0)
	hitstop = maxf(hitstop, 0.025)
	_burst(enemy.pos, Color("ffe2a6"), 2)
	AudioManager.play_sound("hit")
	if enemy.hp <= 0: _kill_enemy(enemy)

func _kill_enemy(enemy: Dictionary) -> void:
	enemy.alive = false
	var info = roster[enemy.kind]
	kills += 1
	combo += 1
	best_combo = maxi(best_combo, combo)
	combo_timer = 2.8
	score += int(float(info.score) * (0.35 if enemy.minion else 1.0)) * multiplier() * (15 if enemy.boss else 1)
	_burst(enemy.pos, Color("ffcd75"), 9 if enemy.boss else 5)
	_drop(enemy.pos, "xp", 18 if enemy.boss else 1 if enemy.minion else 2)
	if not testing and not demo:
		if bool(info.get("generated", true)): SaveData.discover_monster(str(info.id))
		if kills == 1: SaveData.unlock("first_blood")
		if combo >= 25: SaveData.unlock("combo_25")
		if score >= 10000: SaveData.unlock("score_10000")
	if enemy.boss:
		bosses += 1
		bullets.clear()
		health = minf(max_health, health + 30)
		_drop(enemy.pos + Vector2(-28, 20), "heart", 25)
		_drop(enemy.pos + Vector2(28, 20), "hurricane", 1)
		relief_until = elapsed + 5.0
		next_boss = maxf(next_boss, elapsed + 12)
		shake = 8.0
		hud.toast("CROWN COLLECTED · +30 HEALTH", Color("ffd580"))
		AudioManager.play_sound("level")
		if not testing and not demo:
			SaveData.unlock("boss_slayer")
			if bosses >= 5: SaveData.unlock("legend")
	elif enemy.behavior == "splitter" and not enemy.minion:
		for side in [-1, 1]:
			var child = spawn_enemy(int(enemy.kind), false, enemy.pos + Vector2(side * 20, 0), true)
			if not child.is_empty(): child.last_slash = slash_serial
	if not enemy.minion and loot_rng.randf() < (0.23 if health < max_health * 0.4 else 0.16):
		var options = ["heart", "haste", "hurricane", "ward", "magnet", "frost", "spark", "gold"]
		var kind = "heart" if health < max_health * 0.35 and loot_rng.randf() < 0.6 else options[loot_rng.randi_range(0, options.size() - 1)]
		_drop(enemy.pos + Vector2(12, 0), kind, 1)
	if kills == 3: _drop(enemy.pos, "haste", 1)

func multiplier() -> int:
	return 4 if combo >= 35 else 3 if combo >= 20 else 2 if combo >= 5 else 1

func damage_player(amount: float, direction: Vector2 = Vector2.ZERO) -> bool:
	if state != "running" or hurt_timer > 0 or dash_timer > 0 or demo: return false
	if guarding and parry_timer > 0:
		guard_reserve = minf(guard_capacity, guard_reserve + 10)
		_burst(player_pos, Color("fff4c3"), 8)
		AudioManager.play_sound("block")
		return false
	if ward_hits > 0:
		ward_hits -= 1
		hurt_timer = 0.7
		_burst(player_pos, Color("89e6ff"), 7)
		AudioManager.play_sound("block")
		return false
	var received = amount * (0.35 if style == "shield" else 0.65) if guarding else amount
	health = maxf(0, health - received)
	hurt_timer = 0.7
	combo = 0
	combo_timer = 0
	shake = 5.0
	player_pos = _clamp_player(player_pos + direction * 12)
	_burst(player_pos, Color("ff816f"), 7)
	AudioManager.play_sound("hurt")
	if OS.get_name() == "Android" and bool(SaveData.profile.get("settings", {}).get("haptics", true)):
		Input.vibrate_handheld(30, 0.4)
	return true

func _drop(pos: Vector2, kind: String, value: int) -> void:
	if drops.size() >= MAX_DROPS:
		if kind == "xp":
			for drop in drops:
				if drop.kind == "xp":
					drop.value += value
					return
		return
	drops.append({"pos": pos, "kind": kind, "value": value, "life": 14.0, "phase": visual_rng.randf() * TAU})

func _update_drops(delta: float) -> void:
	var attraction = 230.0 if buffs.has("magnet") else minf(140, 64 + level * 3)
	for i in range(drops.size() - 1, -1, -1):
		var drop = drops[i]
		drop.life -= delta
		var offset = player_pos - drop.pos
		if offset.length() < attraction:
			drop.pos += offset.normalized() * (310.0 if buffs.has("magnet") else 180.0) * delta
		if offset.length() < 23:
			collect_drop(drop)
			drops.remove_at(i)
		elif drop.life <= 0:
			drops.remove_at(i)

func collect_drop(drop: Dictionary) -> void:
	var kind = str(drop.kind)
	if kind == "xp":
		xp += int(drop.value)
		while xp >= xp_goal:
			xp -= xp_goal
			level_up()
		AudioManager.play_sound("pickup", 1.05)
		return
	powerups += 1
	if kind == "heart":
		health = minf(max_health, health + maxf(22, float(drop.value)))
		_burst(player_pos, Color("a7e789"), 8)
		hud.toast("+22 HEALTH", Color("b6efa0"))
	elif kind == "gold":
		score += 75 * multiplier()
		hud.toast("POCKET MONEY", Color("ffe29c"))
	else:
		buffs[kind] = minf(18, float(buffs.get(kind, 0)) + (6 if kind == "frost" else 12 if kind == "ward" else 9))
		if kind == "ward": ward_hits = 3
		hud.toast(str(BUFF_NAMES.get(kind, kind.to_upper())), Color("a8e7ef"))
	AudioManager.play_sound("pickup")

func level_up() -> void:
	level += 1
	xp_goal = int(8 + pow(float(level), 1.28) * 3)
	var upgrade = ""
	match (level - 2) % 5:
		0:
			damage = minf(130, damage * 1.14)
			upgrade = "SHARPER STEEL"
		1:
			attack_interval = maxf(0.27, attack_interval * 0.94)
			upgrade = "QUICKER SLICES"
		2:
			attack_range = minf(116, attack_range + 5)
			upgrade = "LONGER REACH"
		3:
			max_health = minf(220, max_health + 8)
			health = minf(max_health, health + 18)
			upgrade = "HEART OF A KNIGHT"
		4:
			guard_capacity = minf(190, guard_capacity + 8)
			guard_reserve = minf(guard_capacity, guard_reserve + 30)
			upgrade = "STRONGER GUARD"
	_burst(player_pos, Color("ffd574"), 12)
	hud.toast("LEVEL %d · %s" % [level, upgrade], Color("ffe5a5"))
	AudioManager.play_sound("level")

func _chain_lightning() -> void:
	var remaining = 3
	var last_pos = player_pos
	for enemy in enemies:
		if enemy.alive and player_pos.distance_to(enemy.pos) < 245:
			_add_effect(last_pos, enemy.pos - last_pos, "lightning", Color("b3f5ff"), 0.14)
			last_pos = enemy.pos
			damage_enemy(enemy, damage * 0.55)
			remaining -= 1
			if remaining <= 0: break

func _add_effect(pos: Vector2, velocity: Vector2, kind: String, color: Color, lifetime: float) -> void:
	if effects.size() >= MAX_EFFECTS: return
	effects.append({"pos": pos, "vel": velocity, "kind": kind, "color": color, "life": lifetime, "max_life": lifetime})

func _burst(pos: Vector2, color: Color, count: int) -> void:
	for n in range(count):
		_add_effect(pos, Vector2.from_angle(visual_rng.randf() * TAU) * visual_rng.randf_range(35, 150), "spark", color, visual_rng.randf_range(0.2, 0.45))

func _boss():
	for enemy in enemies:
		if enemy.boss and enemy.alive: return enemy
	return null

func _update_hud() -> void:
	var boss = _boss()
	hud.update_hud({"health": health, "max_health": max_health, "score": score, "best": int(SaveData.profile.get("best_score", 0)), "level": level, "xp": xp, "xp_goal": xp_goal, "combo": combo, "multiplier": multiplier(), "dash_ready": dash_cooldown <= 0, "guard_ratio": guard_reserve / guard_capacity, "boss_name": BOSS_TITLES[(maxi(1, boss_number) - 1) % BOSS_TITLES.size()] if boss != null else "", "boss_hp": float(boss.hp) if boss != null else 0.0, "boss_max": float(boss.max_hp) if boss != null else 1.0, "elapsed": elapsed, "buffs": buffs, "ward_hits": ward_hits, "combo_ratio": combo_timer / 2.8})

func pause_run() -> void:
	if state != "running": return
	state = "paused"
	_release_input()
	hud.show_pause()
	if not testing and not demo: SaveData.save_active_run(serialize_run())

func resume_run() -> void:
	if state != "paused": return
	state = "running"
	_release_input()
	hurt_timer = maxf(hurt_timer, 0.45)
	hud.hide_overlay()

func end_run() -> void:
	if state != "running": return
	state = "dead"
	_release_input()
	var new_best = score > int(SaveData.profile.get("best_score", 0))
	var result = {"score": score, "kills": kills, "bosses": bosses, "duration": elapsed, "combo": best_combo, "mode": "daily" if daily else style, "style": style, "challenge_date": challenge_date, "collected_powerups": powerups}
	if not testing and not demo:
		SaveData.add_run(result)
		SaveData.clear_active_run()
		PlayServices.submit_run(result)
	result["best"] = maxi(score, int(SaveData.profile.get("best_score", 0)))
	result["new_best"] = new_best
	hud.show_end(result)
	AudioManager.play_sound("death")
	_burst(player_pos, Color("ffbe8a"), 18)

func _show_scores() -> void:
	if state == "running": pause_run()
	PlayServices.show_leaderboards()

func _show_achievements() -> void:
	if state == "running": pause_run()
	PlayServices.show_achievements()

func _toggle_audio() -> void:
	var settings = SaveData.profile.get("settings", {})
	var enabled = not (bool(settings.get("music", true)) or bool(settings.get("sfx", true)))
	settings["music"] = enabled
	settings["sfx"] = enabled
	SaveData.profile["settings"] = settings
	SaveData.save_profile()
	AudioManager.set_enabled(enabled)
	hud.toast("SOUND ON" if enabled else "SOUND OFF", Color("fff1d0"))

func _share_score() -> void:
	var text = "I sliced through %d creatures and %d bosses in InfiniteSlash. Score: %d. One thumb. Endless trouble." % [kills, bosses, score]
	if daily: text += " Daily challenge: " + challenge_date
	DisplayServer.clipboard_set(text)
	hud.toast("SCORE COPIED · CHALLENGE A FRIEND", Color("ffe29c"))

func _achievement_toast(key: String) -> void:
	if hud != null: hud.toast("BADGE · " + str(ACHIEVEMENT_NAMES.get(key, key.replace("_", " ").to_upper())), Color("ffe29c"))

func _notification(what: int) -> void:
	if not ready_complete: return
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if state == "running" and not demo and not testing: pause_run()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "running": pause_run()
		elif state == "paused": resume_run()
		else: get_tree().quit()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if state == "running" and not testing and not demo: SaveData.save_active_run(serialize_run())
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if state == "running": pause_run()
			elif state == "paused": resume_run()
		elif event.keycode == KEY_SPACE and state == "running": try_dash(move_direction if move_direction.length() > 0 else facing)
	if state != "running": return
	if event is InputEventScreenTouch:
		if event.pressed and active_touch < 0:
			active_touch = event.index
			_gesture_press(event.position)
		elif not event.pressed and event.index == active_touch:
			_release_input()
	elif event is InputEventScreenDrag and event.index == active_touch:
		_gesture_drag(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and active_touch < 0:
		if event.pressed: _gesture_press(event.position)
		else: _release_input()
	elif event is InputEventMouseMotion and dragging and active_touch < 0:
		_gesture_drag(event.position)

func _gesture_press(pos: Vector2) -> void:
	dragging = true
	touch_origin = pos
	touch_position = pos
	gesture_origin = pos
	gesture_started = visual_time
	gesture_dashed = false

func _gesture_drag(pos: Vector2) -> void:
	touch_position = pos
	var displacement = pos - gesture_origin
	var duration = visual_time - gesture_started
	if not gesture_dashed and displacement.length() >= 60 and duration < 0.22 and duration > 0.015 and displacement.length() / duration > 650:
		gesture_dashed = try_dash(displacement)
	var offset = pos - touch_origin
	if offset.length() > 100:
		touch_origin = pos - offset.normalized() * 100

func _release_input() -> void:
	dragging = false
	active_touch = -1
	move_direction = Vector2.ZERO
	gesture_dashed = false

func _encode_entity(entity: Dictionary) -> Dictionary:
	var result = entity.duplicate(true)
	for key in ["pos", "vel", "aim", "knock"]:
		if result.has(key) and result[key] is Vector2:
			result[key] = [result[key].x, result[key].y]
	return result

func _finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _numeric_fields(data: Dictionary, keys: Array) -> bool:
	for key in keys:
		if data.has(key) and not _finite_number(data[key]): return false
	return true

func _decode_entities(values, cap: int, category: String) -> Array:
	var result: Array = []
	if not values is Array: return result
	for raw in values.slice(0, cap):
		if not raw is Dictionary or not raw.get("pos") is Array or raw.pos.size() != 2: continue
		var entity = raw.duplicate(true)
		var valid = true
		for key in ["pos", "vel", "aim", "knock"]:
			if entity.has(key):
				if not entity[key] is Array or entity[key].size() != 2 or not _finite_number(entity[key][0]) or not _finite_number(entity[key][1]):
					valid = false
					break
				entity[key] = Vector2(float(entity[key][0]), float(entity[key][1]))
				if not entity[key].is_finite(): valid = false
		if not valid: continue
		if category == "enemy":
			if not entity.has_all(["kind", "hp", "max_hp", "radius", "speed", "damage", "behavior", "boss", "minion", "alive", "age", "cooldown", "windup", "charge", "aim", "knock", "flash", "phase", "anim", "last_slash"]): continue
			if not _numeric_fields(entity, ["kind", "hp", "max_hp", "radius", "speed", "damage", "age", "cooldown", "windup", "charge", "flash", "phase", "anim", "last_slash"]): continue
			if not entity.boss is bool or not entity.minion is bool or not entity.alive is bool: continue
			if not entity.behavior is String or not entity.behavior in ["boss", "chaser", "skitter", "tank", "spitter", "charger", "fan", "orbiter", "splitter"]: continue
			entity.kind = int(entity.kind)
			if entity.kind < 0 or entity.kind >= roster.size(): continue
			entity.hp = clampf(float(entity.hp), 1, 10000)
			entity.max_hp = clampf(float(entity.max_hp), 1, 10000)
			entity.speed = clampf(float(entity.speed), 1, 200)
			entity.damage = clampf(float(entity.damage), 1, 30)
			entity.radius = clampf(float(entity.radius), 8, 40)
			entity.age = clampf(float(entity.age), 0, 86400)
			entity.cooldown = clampf(float(entity.cooldown), 0, 8)
			entity.windup = clampf(float(entity.windup), 0, 1)
			entity.charge = clampf(float(entity.charge), 0, 0.5)
			entity.flash = clampf(float(entity.flash), 0, 0.2)
			entity.phase = clampi(int(entity.phase), 0, 100000)
			entity.anim = clampf(float(entity.anim), 0, 4)
			entity.last_slash = -1
			entity.knock = entity.knock.limit_length(200)
			entity.aim = entity.aim.normalized()
		elif category == "bullet":
			if not entity.has_all(["vel", "damage", "life", "boss", "radius"]): continue
			if not _numeric_fields(entity, ["damage", "life", "radius"]) or not entity.boss is bool: continue
			entity.vel = entity.vel.limit_length(350)
			entity.damage = clampf(float(entity.damage), 1, 30)
			entity.life = clampf(float(entity.life), 0, 7)
			entity.radius = clampf(float(entity.radius), 3, 7)
		elif category == "drop":
			if not entity.has_all(["kind", "value", "life", "phase"]): continue
			if not _numeric_fields(entity, ["value", "life", "phase"]): continue
			if not str(entity.kind) in ["xp", "heart", "gold", "haste", "hurricane", "ward", "magnet", "frost", "spark"]: continue
			entity.value = clampi(int(entity.value), 1, 100)
			entity.life = clampf(float(entity.life), 0, 14)
			entity.phase = clampf(float(entity.phase), 0, TAU)
		result.append(entity)
	return result

func serialize_run() -> Dictionary:
	var saved_enemies: Array = []
	var saved_bullets: Array = []
	var saved_drops: Array = []
	for entity in enemies:
		if entity.alive: saved_enemies.append(_encode_entity(entity))
	for entity in bullets: saved_bullets.append(_encode_entity(entity))
	for entity in drops: saved_drops.append(_encode_entity(entity))
	return {"schema": 1, "style": style, "daily": daily, "challenge_date": challenge_date, "seed": str(run_seed), "rng_state": str(rng.state), "loot_state": str(loot_rng.state), "player": [player_pos.x, player_pos.y], "elapsed": elapsed, "score": score, "kills": kills, "bosses": bosses, "powerups": powerups, "combo": combo, "best_combo": best_combo, "combo_timer": combo_timer, "level": level, "xp": xp, "xp_goal": xp_goal, "health": health, "max_health": max_health, "damage": damage, "attack_interval": attack_interval, "attack_range": attack_range, "guard_capacity": guard_capacity, "guard_reserve": guard_reserve, "ward_hits": ward_hits, "buffs": buffs.duplicate(true), "next_boss": next_boss, "boss_number": boss_number, "spawn_timer": spawn_timer, "relief_until": relief_until, "dash_cooldown": dash_cooldown, "enemies": saved_enemies, "bullets": saved_bullets, "drops": saved_drops}

func restore_run(data: Dictionary) -> bool:
	if not _finite_number(data.get("schema")) or int(data.schema) != 1 or not data.has_all(["player", "health", "elapsed", "score", "style"]): return false
	if not _numeric_fields(data, ["health", "elapsed", "score", "kills", "bosses", "powerups", "combo", "best_combo", "combo_timer", "level", "xp", "xp_goal", "max_health", "damage", "attack_interval", "attack_range", "guard_capacity", "guard_reserve", "ward_hits", "next_boss", "boss_number", "spawn_timer", "relief_until", "dash_cooldown"]): return false
	if not data.style is String or (data.has("daily") and not data.daily is bool): return false
	if not data.player is Array or data.player.size() != 2 or not _finite_number(data.player[0]) or not _finite_number(data.player[1]) or float(data.health) <= 0: return false
	var pos = Vector2(float(data.player[0]), float(data.player[1]))
	if not pos.is_finite(): return false
	style = "shield" if str(data.style) == "shield" else "sword"
	daily = bool(data.get("daily", false))
	challenge_date = str(data.get("challenge_date", ""))
	run_seed = int(str(data.get("seed", "1")))
	rng.seed = run_seed
	rng.state = int(str(data.get("rng_state", str(rng.state))))
	loot_rng.seed = run_seed ^ 1234567
	loot_rng.state = int(str(data.get("loot_state", str(loot_rng.state))))
	player_pos = _clamp_player(pos)
	elapsed = clampf(float(data.elapsed), 0, 86400)
	score = clampi(int(data.score), 0, 2000000000)
	kills = clampi(int(data.get("kills", 0)), 0, 1000000)
	bosses = clampi(int(data.get("bosses", 0)), 0, 1000)
	powerups = clampi(int(data.get("powerups", 0)), 0, 1000000)
	combo = clampi(int(data.get("combo", 0)), 0, 10000)
	best_combo = maxi(combo, clampi(int(data.get("best_combo", 0)), 0, 10000))
	combo_timer = clampf(float(data.get("combo_timer", 0)), 0, 2.8)
	level = clampi(int(data.get("level", 1)), 1, 100)
	xp_goal = clampi(int(data.get("xp_goal", 8)), 1, 10000)
	xp = clampi(int(data.get("xp", 0)), 0, xp_goal - 1)
	max_health = clampf(float(data.get("max_health", 100)), 1, 220)
	health = clampf(float(data.health), 1, max_health)
	damage = clampf(float(data.get("damage", 22)), 1, 130)
	attack_interval = clampf(float(data.get("attack_interval", 0.46)), 0.27, 0.83)
	attack_range = clampf(float(data.get("attack_range", 84)), 60, 116)
	guard_capacity = clampf(float(data.get("guard_capacity", 100)), 1, 190)
	guard_reserve = clampf(float(data.get("guard_reserve", 100)), 0, guard_capacity)
	move_speed = 245.0 if style == "shield" else 265.0
	ward_hits = clampi(int(data.get("ward_hits", 0)), 0, 3)
	buffs.clear()
	if data.get("buffs") is Dictionary:
		for key in BUFF_NAMES:
			if data.buffs.has(key) and _finite_number(data.buffs[key]): buffs[key] = clampf(float(data.buffs[key]), 0, 18)
	next_boss = maxf(elapsed, float(data.get("next_boss", elapsed + 45)))
	boss_number = clampi(int(data.get("boss_number", bosses)), 0, 1000)
	spawn_timer = clampf(float(data.get("spawn_timer", 0.5)), 0, 3)
	relief_until = clampf(float(data.get("relief_until", 0)), 0, elapsed + 5)
	dash_cooldown = clampf(float(data.get("dash_cooldown", 0)), 0, 1.45)
	enemies = _decode_entities(data.get("enemies", []), MAX_ENEMIES, "enemy")
	bullets = _decode_entities(data.get("bullets", []), MAX_BULLETS, "bullet")
	drops = _decode_entities(data.get("drops", []), MAX_DROPS, "drop")
	effects.clear()
	slash_time = 0
	dash_timer = 0
	hurt_timer = 0.45
	hitstop = 0
	_release_input()
	state = "paused"
	return true

func _draw() -> void:
	if not ready_complete: return
	var shake_offset = Vector2(sin(visual_time * 81), cos(visual_time * 93)) * shake
	draw_set_transform(shake_offset)
	if state == "launch":
		for i in range(7):
			var pos = Vector2(arena.x * (0.13 + float(i % 3) * 0.35) + sin(visual_time + i) * 12, arena.y * (0.22 + float(i) * 0.095))
			_draw_monster(i * 13 % textures.size(), pos, 53, int(visual_time * 7 + i) % 4, Color(1, 1, 1, 0.8))
	for enemy in enemies:
		if enemy.alive:
			var size = 103.0 if enemy.boss else 37.0 if enemy.minion else 68.0 if enemy.behavior == "tank" else 56.0
			draw_texture_rect(shadow_texture, Rect2(enemy.pos + Vector2(-size * 0.27, size * 0.22), Vector2(size * 0.54, size * 0.17)), false)
	for enemy in enemies:
		if not enemy.alive: continue
		if enemy.windup > 0:
			var warning = Color(1, 0.52, 0.34, 0.5 + sin(visual_time * 22) * 0.2)
			if enemy.behavior == "charger" or (enemy.boss and int(enemy.phase) % 3 == 2 and boss_number >= 2):
				draw_line(enemy.pos, enemy.pos + enemy.aim * 260, warning, 14)
				draw_line(enemy.pos, enemy.pos + enemy.aim * 260, Color(1, 0.88, 0.6, 0.8), 2)
			else:
				draw_arc(enemy.pos, enemy.radius + 10 + enemy.windup * 8, 0, TAU, 28, warning, 3)
				draw_line(enemy.pos, enemy.pos + enemy.aim * 42, warning, 3)
		var size = 103.0 if enemy.boss else 37.0 if enemy.minion else 68.0 if enemy.behavior == "tank" else 56.0
		var tint = Color("a6dce9") if buffs.has("frost") else Color.WHITE
		if enemy.flash > 0: tint = Color(2, 1.5, 1.2)
		_draw_monster(enemy.kind, enemy.pos, size, int(enemy.age * float(roster[enemy.kind].get("animation_fps", 8)) + enemy.anim) % 4, tint)
		if enemy.boss:
			var crown = PackedVector2Array([enemy.pos + Vector2(-18, -size * 0.42), enemy.pos + Vector2(-21, -size * 0.59), enemy.pos + Vector2(-7, -size * 0.51), enemy.pos + Vector2(0, -size * 0.68), enemy.pos + Vector2(7, -size * 0.51), enemy.pos + Vector2(21, -size * 0.59), enemy.pos + Vector2(18, -size * 0.42)])
			draw_colored_polygon(crown, Color("ffd276"))
		elif enemy.hp < enemy.max_hp:
			draw_rect(Rect2(enemy.pos + Vector2(-17, -size * 0.55), Vector2(34, 4)), Color("25313b"))
			draw_rect(Rect2(enemy.pos + Vector2(-17, -size * 0.55), Vector2(34 * maxf(0, enemy.hp / enemy.max_hp), 4)), Color("f7b578"))
	for drop in drops: _draw_drop(drop)
	_draw_player()
	for bullet in bullets:
		var extent = bullet.radius + 2
		var variant = 2 if buffs.has("frost") else 1 if bullet.boss else 0
		draw_texture_rect_region(projectile_atlas, Rect2(bullet.pos - Vector2.ONE * extent, Vector2.ONE * extent * 2), Rect2(variant * 18, 0, 18, 18))
	for effect in effects:
		var color = effect.color
		color.a *= clampf(effect.life / effect.max_life, 0, 1)
		if effect.kind == "lightning":
			draw_line(effect.pos, effect.pos + effect.vel, color, 3)
		elif effect.kind == "trail":
			draw_circle(effect.pos, 18 * effect.life / effect.max_life, color)
		else:
			draw_rect(Rect2(effect.pos - Vector2(2, 2), Vector2(4, 4)), color)
	draw_set_transform(Vector2.ZERO)
	if dragging and state == "running":
		draw_circle(touch_origin, 43, Color(0.05, 0.08, 0.1, 0.15))
		draw_arc(touch_origin, 43, 0, TAU, 32, Color(1, 0.94, 0.8, 0.25), 2)
		var nub = touch_origin + (touch_position - touch_origin).limit_length(43)
		draw_circle(nub, 14, Color(1, 0.94, 0.8, 0.32))

func _draw_monster(index: int, pos: Vector2, size: float, frame: int, tint: Color) -> void:
	var texture = textures[index]
	var cell = 24.0 if monster_atlas != null else float(texture.get_height())
	var source_pos = Vector2((index % 10) * 96 + frame * 24, int(index / 10) * 24) if monster_atlas != null else Vector2(frame * cell, 0)
	draw_texture_rect_region(texture, Rect2(pos - Vector2.ONE * size * 0.5, Vector2.ONE * size), Rect2(source_pos, Vector2.ONE * cell), tint)

func _draw_player() -> void:
	var alive = state != "dead"
	var pos = player_pos + Vector2(0, sin(visual_time * 11) * (1.8 if move_direction.length() > 0.1 else 0.7))
	draw_texture_rect(shadow_texture, Rect2(pos + Vector2(-24, 17), Vector2(48, 14)), false)
	if guarding and alive:
		draw_circle(pos, 32, Color(0.45, 0.79, 0.85, 0.12))
		draw_arc(pos, 32, -PI / 2, -PI / 2 + TAU * guard_reserve / guard_capacity, 36, Color("ffe0a0") if parry_timer > 0 else Color("8bcdd6"), 3)
	elif dash_cooldown <= 0 and alive:
		draw_arc(pos, 26, 0.45, PI - 0.45, 16, Color(0.78, 0.91, 0.9, 0.4), 2)
	if ward_hits > 0:
		for i in range(ward_hits): draw_circle(pos + Vector2((i - 1) * 10, -31), 3, Color("92e9ff"))
	var tint = Color(1, 1, 1, 0.28) if not alive else Color("ffb19b") if hurt_timer > 0 and int(visual_time * 18) % 2 == 0 else Color.WHITE
	var frame = int(visual_time * (10 if move_direction.length() > 0.1 else 4)) % 4
	if hero_texture != null:
		var cell = Vector2(hero_texture.get_width() / 2.0, hero_texture.get_height() / 3.0)
		draw_texture_rect_region(hero_texture, Rect2(pos - Vector2(39, 39), Vector2(78, 78)), Rect2(Vector2((frame % 2) * cell.x, int(frame / 2) * cell.y), cell), tint)
	else:
		# Only visible while art is importing; the final build includes the generated atlas.
		draw_rect(Rect2(pos - Vector2(13, 0), Vector2(26, 26)), Color("467d98"))
		draw_rect(Rect2(pos - Vector2(18, 22), Vector2(36, 28)), Color("8d9cba"))
		draw_rect(Rect2(pos - Vector2(13, 10), Vector2(26, 7)), Color("26313e"))
	if alive:
		var weapon_angle = slash_angle + PI / 2 + (-1.1 + (0.18 - slash_time) / 0.18 * 2.2 if slash_time > 0 else 0)
		draw_set_transform(pos + Vector2(15, 6), weapon_angle)
		if hero_texture != null:
			var cell = Vector2(hero_texture.get_width() / 2.0, hero_texture.get_height() / 3.0)
			draw_texture_rect_region(hero_texture, Rect2(Vector2(-18, -53), Vector2(36, 62)), Rect2(Vector2(0, cell.y * 2), cell))
		else: draw_texture_rect(weapon_fallback, Rect2(-16, -45, 32, 45), false, Color("ffe1a4"))
		draw_set_transform(pos + Vector2(-19, 9))
		if hero_texture != null:
			var cell = Vector2(hero_texture.get_width() / 2.0, hero_texture.get_height() / 3.0)
			draw_texture_rect_region(hero_texture, Rect2(-16, -18, 32, 37), Rect2(Vector2(cell.x, cell.y * 2), cell))
		else: draw_texture_rect(shield_fallback, Rect2(-14, -15, 28, 30), false, Color("9fdae5"))
		draw_set_transform(Vector2.ZERO)
	if slash_time > 0:
		var alpha = slash_time / 0.18
		var reach = attack_range + (34 if buffs.has("hurricane") else 0)
		draw_arc(pos, reach, slash_angle - 1.2, slash_angle + 1.2, 28, Color(1, 0.83, 0.48, alpha * 0.9), 8)
		draw_arc(pos, reach - 7, slash_angle - 1.1, slash_angle + 1.1, 26, Color(1, 0.98, 0.86, alpha), 2)

func _draw_drop(drop: Dictionary) -> void:
	var pos = drop.pos + Vector2(0, sin(visual_time * 5 + drop.phase) * 3)
	var alpha = minf(1, drop.life / 2.0)
	var color = Color("ffdb87") if drop.kind in ["xp", "gold"] else Color("aff19a") if drop.kind == "heart" else Color("8ddeef")
	color.a = alpha
	if drop.kind == "xp":
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -6), pos + Vector2(5, 0), pos + Vector2(0, 6), pos + Vector2(-5, 0)]), color)
	else:
		draw_circle(pos, 15, Color(0.08, 0.13, 0.16, alpha * 0.8))
		draw_arc(pos, 15, 0, TAU, 20, color, 2)
		if drop.kind == "heart":
			draw_colored_polygon(PackedVector2Array([pos + Vector2(0, 7), pos + Vector2(-8, -1), pos + Vector2(-8, -5), pos + Vector2(-4, -7), pos + Vector2(0, -3), pos + Vector2(4, -7), pos + Vector2(8, -5), pos + Vector2(8, -1)]), Color(1, 0.5, 0.45, alpha))
		else:
			var symbol = {"haste": ">>", "hurricane": "/", "ward": "W", "magnet": "M", "frost": "*", "spark": "Z", "gold": "$"}.get(drop.kind, "+")
			draw_string(ThemeDB.fallback_font, pos + Vector2(-12, 6), symbol, HORIZONTAL_ALIGNMENT_CENTER, 24, 16, color)
