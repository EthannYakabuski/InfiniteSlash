extends SceneTree
## Integrated production scenarios against the actual main scene and save path.

const Progression = preload("res://scripts/progression.gd")
const Hazards = preload("res://scripts/boss_hazards.gd")
const World = preload("res://scripts/world.gd")
var game: Variant
var save: Variant
var audio: Variant
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("PRODUCTION COMBAT: " + message)

func near(actual: float, expected: float, message: String, tolerance := 0.025) -> void:
	check(absf(actual - expected) <= tolerance, "%s (%.5f expected %.5f)" % [message, actual, expected])

func reset(style := "sword") -> void:
	game.testing = true
	game.demo = false
	game.start_run(style)
	game.set_process(false)
	game.set_physics_process(false)
	game.spawn_timer = 10000.0
	game.next_boss = 10000.0
	game.swing_timer = 10000.0
	game.hurt_timer = 0.0
	game.hitstop = 0.0

func _run() -> void:
	save = root.get_node("SaveData")
	audio = root.get_node("AudioManager")
	save.configure_storage(ProjectSettings.globalize_path("res://output/test-data/production-combat/%d.json" % Time.get_ticks_usec()))
	audio.set_enabled(false)
	var scene := load("res://scenes/main.tscn") as PackedScene
	check(scene != null, "actual game scene loads")
	if scene == null:
		quit(1)
		return
	game = scene.instantiate()
	game.testing = true
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	_test_mobile_guard()
	_test_ward_guard_consistency()
	_test_hazard_geometry()
	_test_second_wind_iteration()
	_test_dash_overdrive()
	_test_build_effects()
	_test_difficulty()
	_test_stage_spawn_roster()
	_test_ascended_cross_cohort()
	_test_new_snapshot_and_freeze()
	_test_legacy_snapshot()
	_test_legacy_purse_and_biome_records()
	_test_malformed_new_snapshot()
	_test_saturated_snapshot()
	_test_loot_frequency()
	var report := {"pass": failures.is_empty(), "checks": checks, "failures": failures}
	var file := FileAccess.open("res://output/review/production_combat_validation.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("PRODUCTION COMBAT TESTS: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	audio.stop_for_shutdown()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_mobile_guard() -> void:
	for style: String in ["sword", "shield"]:
		reset(style)
		game._update_player(0.5)
		near(game.guard_reserve, game.guard_capacity, style + " idle guard does not drain")
		game.dragging = true
		game.touch_origin = Vector2(250, 700)
		game.touch_position = Vector2(310, 700)
		var before: Vector2 = game.player_pos
		game._update_player(0.1)
		check(game.guarding and game.player_pos.x > before.x, style + " guard stays active while moving")
		near(game.guard_reserve, game.guard_capacity, style + " movement does not spend guard")
		game._release_input()
		check(not game.damage_player(20), style + " full guard blocks incoming contact damage")
		near(game.health, game.max_health, style + " fully blocked hit preserves health")
		var remaining: float = game.guard_reserve
		check(remaining < game.guard_capacity, style + " blocked attack consumes reserve")
		var delay: float = 0.5 if style == "sword" else 0.3
		near(game.guard_regen_wait, delay, style + " class-specific recovery delay")
		game._update_player(delay - 0.01)
		near(game.guard_reserve, remaining, style + " no regeneration before delay")
		game._update_player(0.02)
		near(game.guard_reserve, remaining + game.guard_regen * 0.01, style + " regeneration starts only after elapsed delay")
		game._absorb_attack(5.0)
		near(game.guard_regen_wait, delay, style + " another attack resets recovery delay")
		remaining = game.guard_reserve
		game.dragging = true
		game.touch_origin = Vector2(250, 700)
		game.touch_position = Vector2(310, 700)
		game._update_player(delay + 0.1)
		near(game.guard_reserve, minf(game.guard_capacity, remaining + game.guard_regen * 0.1), style + " recharge also works while moving")
	reset()
	game.guard_reserve = 12.0 # A quarter of the 48 guard cost of this attack.
	check(game.damage_player(40), "damage beyond an exhausted guard reaches health")
	near(game.health, game.max_health - 30.0, "guard overflow deals only unabsorbed proportion")
	near(game.guard_reserve, 0.0, "overflow exhausts guard without going negative")
	reset("shield")
	game.damage_player(100)
	near(game.health, game.max_health, "Shield can fully absorb a 100-damage attack at starting reserve")
	reset("sword")
	game.damage_player(100)
	check(game.health < game.max_health, "Sword's smaller reserve cannot fully absorb the same attack")

func _test_hazard_geometry() -> void:
	var origin := Vector2(220, 400)
	for kind: String in ["fire", "quake", "pulse"]:
		var hazard := Hazards.make(kind, origin, 20, Vector2.RIGHT)
		check(not Hazards.contains(hazard, origin), kind + " telegraph cannot damage the player")
		hazard.age = hazard.warning + hazard.duration
		check(not Hazards.active(hazard), kind + " stops dealing damage at expiry")
	var fire := Hazards.make("fire", origin, 20)
	fire.age = fire.warning + 0.1
	check(Hazards.contains(fire, origin) and not Hazards.contains(fire, origin + Vector2(140, 0)), "fire uses a bounded circular danger zone")
	var quake := Hazards.make("quake", origin, 20, Vector2.RIGHT)
	quake.age = quake.warning + 0.1
	check(Hazards.contains(quake, origin + Vector2(150, 0)), "earthquake rectangle rotates toward its aim")
	check(not Hazards.contains(quake, origin + Vector2(0, 110)), "earthquake has a safe lateral escape")
	var pulse := Hazards.make("pulse", origin, 20, Vector2.RIGHT)
	pulse.age = pulse.warning + 0.4
	var radius: float = Hazards.pulse_radius(pulse)
	check(not Hazards.contains(pulse, origin + Vector2.RIGHT * radius), "concave pulse has a traversable aimed gap")
	check(Hazards.contains(pulse, origin + Vector2.LEFT * radius), "pulse damages on the opposite wave front")
	check(not Hazards.contains(pulse, origin), "pulse does not fill the entire circle behind its wave")
	check(World.night_amount(30) == 0 and World.night_amount(110) == 1, "day and night have distinct full lighting phases")
	check(not World.is_night(84.9) and World.is_night(85) and not World.is_night(150), "night-only spawn window has exact deterministic boundaries")

func _test_ward_guard_consistency() -> void:
	for kind: String in ["body", "projectile", "hazard"]:
		for reserve: float in [0.0, 12.0, 65.0]:
			reset()
			game.guard_reserve = reserve
			game.ward_hits = 2
			game.buffs.ward = 12.0
			var amount := 20.0 if reserve == 65.0 else 40.0
			if kind == "body":
				game.damage_player(amount)
			elif kind == "projectile":
				game._add_bullet(game.player_pos, Vector2.ZERO, amount)
				game._update_bullets(0.0)
			else:
				var hazard := Hazards.make("fire", game.player_pos, amount)
				hazard.age = hazard.warning
				game.hazards.append(hazard)
				game._update_hazards(0.01)
			near(game.health, game.max_health, kind + " guard/Ward combination preserves health")
			check(game.ward_hits == (2 if reserve == 65.0 else 1), kind + " only health-reaching damage consumes one Ward charge")
			check(game.guard_reserve < reserve if reserve > 0 else game.guard_reserve == 0, kind + " spends available guard before checking Ward")

func _test_second_wind_iteration() -> void:
	reset()
	game.health = 1.0
	game.guard_reserve = 0.0
	game.second_wind = 1.0
	for index: int in range(3):
		var hazard := Hazards.make("fire", game.player_pos, 500)
		hazard.age = hazard.warning
		game.hazards.append(hazard)
	game._add_bullet(game.player_pos, Vector2.ZERO, 500)
	game._update_hazards(0.01)
	check(game.second_wind_used and game.health > 0, "lethal hazard triggers the one-use rescue")
	check(game.hazards.is_empty() and game.bullets.is_empty(), "rescue safely clears hazards and bullets during reverse iteration")
	game.hurt_timer = 0.0
	game.guard_reserve = 0.0
	game._receive_health_damage(500, Vector2.ZERO)
	near(game.health, 0.0, "rescue cannot trigger again in the same run")
	reset()
	game.health = 1.0
	game.guard_reserve = 0.0
	game.second_wind = 1.0
	for index: int in range(3): game._add_bullet(game.player_pos, Vector2.ZERO, 500)
	game._update_bullets(0.0)
	check(game.second_wind_used and game.bullets.is_empty(), "projectile iteration also survives a rescue that clears its array")

func _test_dash_overdrive() -> void:
	reset()
	check(game.try_dash(Vector2.RIGHT), "dash starts for the overdrive scenario")
	for index: int in range(9): game._add_bullet(game.player_pos + Vector2(20, 0), Vector2.ZERO, 30)
	game._update_bullets(0.0)
	check(game.bullets.is_empty() and game.overdrive_time > 0, "dashing through enough shots triggers overdrive")
	near(game.health, game.max_health, "dash-through shots preserve health")
	near(game.guard_reserve, game.guard_capacity, "dash-through shots do not spend guard")
	game.dash_timer = 0.0
	game.swing_timer = 0.0
	game._update_weapon(0.0)
	near(game.swing_timer, game.attack_interval * 0.85, "overdrive measurably speeds up automatic slashes")

func _test_difficulty() -> void:
	var previous_enemy: Dictionary = {}
	var previous_boss: Dictionary = {}
	for level: int in [10, 30, 50, 100]:
		reset()
		game.level = level
		game.elapsed = 90.0
		var normal: Dictionary = game.spawn_enemy(0, false, Vector2(100, 200))
		var boss: Dictionary = game.spawn_enemy(0, true, Vector2(300, 200))
		if not previous_enemy.is_empty():
			check(normal.hp > previous_enemy.hp and normal.damage > previous_enemy.damage and normal.speed > previous_enemy.speed, "normal enemy pressure increases at level%d" % level)
			check(boss.hp > previous_boss.hp and boss.damage > previous_boss.damage and boss.speed >= previous_boss.speed, "boss endurance and pressure increase at level%d" % level)
		previous_enemy = normal.duplicate()
		previous_boss = boss.duplicate()
		boss.phase = 1
		boss.aim = Vector2.DOWN
		game._fire_enemy(boss)
		check(game.hazards.is_empty() if level < 20 else not game.hazards.is_empty(), "elemental boss attacks obey the level20 gate")
	reset()
	game.level = 50
	for phase: int in [1, 2, 3]:
		var boss: Dictionary = game.spawn_enemy(0, true, Vector2(300, 200))
		boss.phase = phase
		game._cast_boss_element(boss)
	var kinds: Dictionary = {}
	for hazard: Dictionary in game.hazards: kinds[hazard.kind] = true
	check(kinds.has_all(["fire", "quake", "pulse"]), "late boss attack cycle includes every elemental geometry")

func _test_build_effects() -> void:
	reset()
	game.health = 40.0
	game.lifesteal = 0.1
	var enemy: Dictionary = game.spawn_enemy(0, false, game.player_pos + Vector2(0, -35))
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	game.damage_enemy(enemy, 10.0, Vector2.ZERO, true)
	near(game.health, 41.0, "lifesteal heals from actual slash damage")
	game.damage_enemy(enemy, 10.0, Vector2.ZERO, false)
	near(game.health, 41.0, "non-slash effects cannot amplify lifesteal into a feedback loop")
	reset()
	game.thorns = 0.5
	enemy = game.spawn_enemy(0, false, game.player_pos + Vector2(20, 0))
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	game.damage_player(20.0)
	near(enemy.hp, 90.0, "thorns returns its fraction of the incoming attack even when guard blocks it")
	reset()
	game.execute_threshold = 0.12
	enemy = game.spawn_enemy(0, false, game.player_pos + Vector2(20, 0))
	enemy.hp = 10.0
	enemy.max_hp = 100.0
	game.damage_enemy(enemy, 1.0)
	check(not enemy.alive, "execution finishes a wounded normal monster")
	var boss: Dictionary = game.spawn_enemy(0, true, Vector2(250, 200))
	boss.hp = 10.0
	boss.max_hp = 100.0
	game.damage_enemy(boss, 1.0)
	check(boss.alive, "execution does not bypass boss endurance")
	reset()
	game.overdrive_time = 6.0
	enemy = game.spawn_enemy(0, false, game.player_pos + Vector2(0, -35))
	enemy.hp = 100.0
	enemy.max_hp = 100.0
	game.perform_slash(Vector2.UP)
	near(enemy.hp, 100.0 - game.damage * 1.25, "overdrive increases real slash damage by25percent")

func _test_stage_spawn_roster() -> void:
	reset()
	check(game.roster.size() == 201 and game.textures.size() == 201, "all200 generated species plus supplied original are cached")
	var advanced := 0
	var nocturnal := 0
	var roles: Dictionary = {}
	for info: Dictionary in game.roster:
		if bool(info.get("night_only", false)): nocturnal += 1
		elif int(info.get("stage_min", 1)) >= 30:
			advanced += 1
			roles[str(info.get("role", ""))] = true
	check(advanced == 50 and nocturnal == 50, "expanded roster contains50 advanced and50 night-only species")
	check(roles.has_all(["glass_cannon", "tank", "volley"]), "advanced roster contains all three requested combat roles")
	for spec: Array in [[10, 30.0], [10, 110.0], [30, 30.0], [30, 110.0], [50, 30.0], [100, 110.0]]:
		game.level = int(spec[0])
		game.elapsed = float(spec[1])
		game.rng.seed = 572983
		var samples := {"night": 0, "advanced": 0, "invalid": 0}
		for index: int in range(2000):
			var selected: int = game._choose_monster()
			var info: Dictionary = game.roster[selected]
			if bool(info.get("night_only", false)): samples.night += 1
			elif int(info.get("stage_min", 1)) >= 30: samples.advanced += 1
			if int(info.get("stage_min", 1)) > game.level or int(info.get("stage_max", 10000)) < game.level: samples.invalid += 1
		check(samples.invalid == 0, "selected monsters obey stage gates at level%d" % game.level)
		if not World.is_night(game.elapsed):
			check(samples.night == 0, "daytime never spawns night-only species at level%d" % game.level)
		elif game.level >= 30:
			check(samples.night >= 1000 and samples.night <= 1700, "night species are prominent within their eligible night stage")
		if game.level < 30:
			check(samples.advanced == 0, "advanced war-host species never leak into stage1")
		elif game.level < 50 and not World.is_night(game.elapsed):
			check(samples.advanced >= 1400, "advanced species dominate daytime middle and late play")
		if game.level >= 50:
			check(samples.advanced == 0, "stage2-only advanced war host does not leak beyond level49")

func _test_ascended_cross_cohort() -> void:
	reset()
	var veteran_index := -1
	var veteran_hp := 0.0
	var original_tank := -1
	for index: int in range(game.roster.size()):
		var info: Dictionary = game.roster[index]
		if int(info.get("stage_min", 1)) == 30 and not bool(info.get("night_only", false)) and str(info.get("role", "")) == "tank" and float(info.health) > veteran_hp:
			veteran_index = index
			veteran_hp = float(info.health)
		if int(info.get("stage_min", 1)) == 1 and not bool(info.get("night_only", false)) and str(info.behavior) == "tank": original_tank = index
	check(veteran_index >= 0 and original_tank >= 0, "cross-cohort tank fixtures exist in the real roster")
	if veteran_index < 0 or original_tank < 0: return
	game.level = 49
	game.elapsed = 90.0
	var veteran: Dictionary = game.spawn_enemy(veteran_index, false, Vector2(120, 200))
	game.level = 50
	var ascended: Dictionary = game.spawn_enemy(original_tank, false, Vector2(380, 200))
	check(ascended.hp > veteran.hp and ascended.damage > veteran.damage and ascended.speed > veteran.speed,
		"level50 ascended original tank exceeds the strongest level49 veteran cohort")
	game.enemies.clear()
	ascended = game.spawn_enemy(original_tank, false, game.player_pos + Vector2(-120, 0))
	ascended.age = 2.0
	ascended.cooldown = 0.0
	game._update_enemies(0.01)
	check(ascended.windup > 0, "late normal tank visibly prepares its stomp before casting")
	game._update_enemies(0.6)
	check(game.hazards.size() == 1 and game.hazards[0].kind == "quake", "late normal tank emits the actual rectangular earthquake hazard")
	check(not Hazards.active(game.hazards[0]) and ascended.cooldown >= 0.9, "normal tank stomp has a dodgeable telegraph and bounded cooldown")
	game._update_enemies(0.25)
	check(game.hazards.size() == 1, "tank cannot continuously recast during its cooldown")

func _test_new_snapshot_and_freeze() -> void:
	reset()
	game.level = 50
	game.elapsed = 110.0
	game.xp_goal = Progression.xp_goal(50)
	game.health = 210.0
	game.max_health = 300.0
	game.damage = 550.0
	game.guard_capacity = 400.0
	game.guard_reserve = 222.0
	game.guard_regen = 77.0
	game.guard_delay = 0.2
	game.guard_regen_wait = 0.18
	game.guard_contact_cooldown = 0.12
	game.dash_recharge = 2.1
	game.lifesteal = 0.04
	game.thorns = 0.5
	game.second_wind = 1.0
	game.second_wind_used = true
	game.execute_threshold = 0.12
	game.combo_grace = 1.8
	game.overdrive_charge = 70.0
	game.overdrive_time = 4.2
	game.buffs.haste = 8.0
	for kind: String in ["fire", "quake", "pulse"]: game.hazards.append(Hazards.make(kind, Vector2(100, 300), 20, Vector2.RIGHT))
	var eligible: Array = game.UpgradeCatalog.eligible(50, game._upgrade_stats(), {})
	check(eligible.size() > 2, "late runs retain diverse eligible upgrades")
	game.upgrade_choices = [eligible[-1], eligible[-2]]
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(game.serialize_run()))
	save.save_active_run(snapshot)
	check(not save.active_run.is_empty(), "expanded stats and hazard vectors remain valid offline-save JSON")
	var offered: Array = snapshot.upgrade_choices.duplicate()
	check(game.restore_run(snapshot), "new combat snapshot restores")
	for field: String in ["guard_regen", "guard_delay", "guard_regen_wait", "guard_contact_cooldown", "dash_recharge", "lifesteal", "thorns", "execute_threshold", "combo_grace", "overdrive_charge", "overdrive_time", "damage", "guard_capacity", "guard_reserve"]:
		near(float(game.get(field)), float(snapshot[field]), "snapshot preserves " + field)
	check(game.second_wind_used and game.hazards.size() == 3 and game.hazards[1].size is Vector2, "snapshot restores rescue usage and all three hazard geometries")
	check(str(game.upgrade_rng.state) == snapshot.upgrade_state, "restoring choices does not consume future upgrade randomness")
	game.resume_run()
	check(game.state == "upgrading", "resuming a pending choice returns to its frozen choice screen")
	game._process(0.0)
	var frozen: Dictionary = game.serialize_run()
	var visual: float = game.visual_time
	game.tick(1.0)
	game._process(1.0)
	check(game.serialize_run() == frozen, "choice screen freezes enemies, hazards, buffs, guard timing, overdrive and progression")
	near(game.visual_time, visual, "level-up choice freezes combat animation time")
	check(game.serialize_run().upgrade_choices == offered, "both exact offered choices survive save, resume and a frozen frame")
	game.choose_upgrade(str(offered[0]))
	check(game.state == "running" and game.upgrade_choices.is_empty(), "taking one frozen choice resumes the run")

func _test_legacy_snapshot() -> void:
	reset()
	game.level = 12
	game.spawn_enemy(game.roster.size() - 1, false, Vector2(200, 300))
	var legacy: Dictionary = JSON.parse_string(JSON.stringify(game.serialize_run()))
	legacy.erase("combat_version")
	legacy.balance_version = 3
	legacy.enemies[0].kind = 100
	legacy.enemies[0].erase("monster_id")
	legacy.xp_goal = int(8.0 + pow(12.0, 1.28) * 3.0)
	legacy.xp = int(legacy.xp_goal / 2)
	var fraction := float(legacy.xp) / float(legacy.xp_goal)
	for key: String in ["guard_regen", "guard_delay", "guard_regen_wait", "guard_contact_cooldown", "lifesteal", "thorns", "second_wind", "second_wind_used", "execute_threshold", "combo_grace", "overdrive_charge", "overdrive_time", "hazards"]: legacy.erase(key)
	check(game.restore_run(legacy), "old combat snapshot remains resumable")
	check(game.enemies.size() == 1 and game.enemies[0].monster_id == "original_tinpot" and game.enemies[0].kind == game.roster.size() - 1, "legacy index100 still resolves to the original creature after catalog expansion")
	check(game.xp_goal == Progression.xp_goal(12), "legacy goal migrates to the new requested XP band")
	near(float(game.xp) / game.xp_goal, fraction, "legacy XP fraction is preserved", 1.0 / game.xp_goal)
	near(game.guard_delay, 0.5, "legacy Sword run receives the new base guard recovery delay")
	check(game.hazards.is_empty() and not game.second_wind_used, "absent new fields get harmless defaults")

func _test_malformed_new_snapshot() -> void:
	reset()
	var valid: Dictionary = game.serialize_run()
	for key: String in ["guard_regen", "guard_delay", "guard_regen_wait", "guard_contact_cooldown", "lifesteal", "thorns", "second_wind", "execute_threshold", "combo_grace", "overdrive_charge", "overdrive_time"]:
		var broken: Dictionary = valid.duplicate(true)
		broken[key] = NAN
		check(not game.restore_run(broken), "non-finite new field rejected: " + key)
	var broken: Dictionary = valid.duplicate(true)
	broken.combat_version = 999
	check(not game.restore_run(broken), "future combat schema cannot be silently loaded")
	var hazard: Dictionary = game._encode_entity(Hazards.make("fire", Vector2(200, 300), 20))
	hazard.aim = [NAN, 0.0]
	broken = valid.duplicate(true)
	broken.hazards = [hazard]
	check(game.restore_run(broken) and game.hazards.is_empty(), "malformed hazard vectors are quarantined without destroying valid player progress")

func _test_legacy_purse_and_biome_records() -> void:
	reset()
	game.level = 2
	var legacy: Dictionary = game.serialize_run()
	legacy.erase("combat_version")
	legacy.upgrade_choices = ["royal_purse", "lucky_purse"]
	check(game.restore_run(legacy), "old saved purse choices below the new level40 gate are preserved")
	game.resume_run()
	game.choose_upgrade("royal_purse")
	check(game.state == "running" and game.score >= 10000, "taking a legacy purse resumes and grants its new meaningful score reward")
	var strict: Dictionary = game.serialize_run()
	strict.upgrade_choices = ["royal_purse", "lucky_purse"]
	check(not game.restore_run(strict), "new saves cannot forge the legacy-only early purse exemption")
	reset()
	game.level = 62
	var older_keep_run: Dictionary = game.serialize_run()
	older_keep_run.erase("combat_version")
	save.profile.achievements.erase("biome_50")
	save.profile.cloud.pending_achievements.erase("biome_50")
	check(game.restore_run(older_keep_run), "a pre-update run already beyond the Keep threshold restores")
	game.testing = false
	game.resume_run()
	game.testing = true
	check(save.profile.achievements.has("biome_50") and "biome_50" in save.profile.cloud.pending_achievements,
		"resuming an existing level62 run awards and queues biome arrival immediately")
	save.profile.achievements.erase("biome_50")
	save.profile.cloud.pending_achievements.erase("biome_50")
	reset()
	game.level = 49
	game.xp_goal = Progression.xp_goal(49)
	# Only the fixture's SaveData is active; permit real integration callbacks.
	game.testing = false
	game.level_up()
	game.testing = true
	check(game.level == 50 and save.profile.achievements.has("biome_50"), "actual level50 transition records Beyond the Kingdom immediately")
	check("biome_50" in save.profile.cloud.pending_achievements, "actual biome arrival queues its pending online award")
	reset()
	game.level = 67
	game.best_combo = 83
	game.bosses = 8
	game.testing = false
	game.end_run()
	game.testing = true
	check(save.profile.best_level == 67 and save.profile.run_history.back().level == 67, "real run completion records highest level in the profile and history")
	check(save.profile.best_combo == 83 and save.profile.best_bosses == 8, "real run completion retains combo and existing bosses board records")
	check(save.profile.cloud.pending_scores.highest_level == 67 and save.profile.cloud.pending_scores.highest_combo == 83, "real gameplay result feeds both new leaderboard queues")

func _test_loot_frequency() -> void:
	reset()
	game.loot_rng.seed = 88931
	var optional_drops := 0
	for index: int in range(2000):
		game.enemies.clear()
		game.drops.clear()
		var enemy: Dictionary = game.spawn_enemy(0, false, Vector2(100, 200))
		game._kill_enemy(enemy)
		for drop: Dictionary in game.drops:
			if drop.kind != "xp": optional_drops += 1
	check(optional_drops >= 100 and optional_drops <= 250, "optional loot is substantially rarer across 2000 deterministic kills (got%d)" % optional_drops)

func _test_saturated_snapshot() -> void:
	reset()
	game.level = 100
	game.elapsed = 110.0
	game.xp_goal = Progression.xp_goal(100)
	for index: int in range(game.MAX_ENEMIES):
		var enemy: Dictionary = game.spawn_enemy(index % game.roster.size(), false, Vector2(30.123456789 + index % 12 * 40.137489, 200.4378129 + index / 12 * 30.198497))
		enemy.age = 25.987654321
		enemy.aim = Vector2(0.438759154, 0.89893195).normalized()
		enemy.knock = Vector2(84.39875842, -12.85473892)
	for index: int in range(game.MAX_BULLETS):
		game._add_bullet(Vector2(30.13847586 + index % 12 * 40.248597, 200.13259874 + index / 12 * 12.859314), Vector2(45.349386527, 142.674321684), 101.375198476, index % 2 == 0)
	for index: int in range(game.MAX_DROPS): game._drop(Vector2(50 + index * 5, 320), "xp", index + 1)
	for index: int in range(Hazards.MAX_HAZARDS): game.hazards.append(Hazards.make(["fire", "quake", "pulse"][index % 3], Vector2(101.25, 300.47), 123.45, Vector2(0.43, 0.89)))
	for definition: Dictionary in game.UpgradeCatalog.all_definitions(): game.upgrade_counts[str(definition.id)] = 2
	var snapshot: Dictionary = game.serialize_run()
	var bytes: int = JSON.stringify(snapshot).to_utf8_buffer().size()
	print("PRODUCTION_SATURATED_SAVE_BYTES ", bytes)
	check(bytes <= save.MAX_ACTIVE_BYTES and save._json_safe(snapshot), "fully saturated late run fits the bounded active-save budget")
	save.save_active_run(snapshot)
	check(save.last_storage_error.is_empty() and save.active_run.enemies.size() == game.MAX_ENEMIES, "fully saturated late run saves successfully")
	check(save.reload_profile() and game.restore_run(save.active_run), "fully saturated late run survives disk reload and gameplay restore")
	check(game.enemies.size() == game.MAX_ENEMIES and game.bullets.size() == game.MAX_BULLETS and game.drops.size() == game.MAX_DROPS and game.hazards.size() == Hazards.MAX_HAZARDS,
		"saturated restore retains every bounded enemy, bullet, drop and elemental hazard")
