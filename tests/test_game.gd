extends SceneTree
## Scenario tests exercise the real scene, input events and fixed-step simulation.

var game: Variant
var save: Variant
var audio: Variant
var checks: int = 0
var failures: Array[String] = []
var report: Dictionary = {}


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("GAME TEST: " + message)


func near(actual: float, expected: float, message: String, tolerance: float = 0.02) -> void:
	check(absf(actual - expected) <= tolerance, "%s (got %.5f, expected %.5f)" % [message, actual, expected])


func reset(choice: String = "sword") -> void:
	game.testing = true
	game.demo = false
	game.start_run(choice)
	game.set_physics_process(false)
	game.set_process(false)
	game.enemies.clear()
	game.bullets.clear()
	game.drops.clear()
	game.effects.clear()
	game.spawn_timer = 10000.0
	game.next_boss = 10000.0
	game.hurt_timer = 0.0
	game.hitstop = 0.0
	game.swing_timer = 10000.0
	game.visual_time = 0.0


func role_index(role: String) -> int:
	for index in range(game.roster.size()):
		if game.roster[index].behavior == role:
			return index
	return -1


func touch(index: int, pressed: bool, pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = pos
	game._unhandled_input(event)


func drag(index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	game._unhandled_input(event)


func _run() -> void:
	save = root.get_node("SaveData")
	audio = root.get_node("AudioManager")
	var fixture := ProjectSettings.globalize_path("res://output/test-data/game-qa/profile.json")
	save.configure_storage(fixture)
	audio.set_enabled(false)
	var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
	check(packed != null, "Actual main scene loads")
	if packed == null:
		quit(1)
		return
	game = packed.instantiate()
	game.testing = true
	root.add_child(game)
	game.testing = true
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	check(game.ready_complete and game.state == "launch", "Boot reaches the sword/shield launch overlay")
	check(game.roster.size() == 101 and game.textures.size() == 101, "All 100 new creatures plus original are cached")
	_test_controls()
	_test_damage_guard()
	_test_class_comparison()
	_test_slash_splitter()
	_test_enemy_patterns_boss()
	_test_powerups_upgrades()
	_test_run_build_choices()
	_test_boss_variation_restore()
	_test_audio_preferences()
	_test_pause_restart()
	_test_snapshot()
	_test_malformed_snapshots()
	await _test_stress()
	report["checks"] = checks
	report["failures"] = failures
	report["pass"] = failures.is_empty()
	var file := FileAccess.open("res://output/review/game_validation.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("GAME TESTS: %d checks, %d failures" % [checks, failures.size()])
	game.queue_free()
	audio.stop_for_shutdown()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _test_controls() -> void:
	for choice in ["sword", "shield"]:
		reset(choice)
		check(game.state == "running" and game.style == choice, "%s choice immediately starts" % choice)
		near(game.health, 80.0 if choice == "sword" else 170.0, "%s health baseline" % choice)
		var initial: Vector2 = game.player_pos
		touch(0, true, Vector2(270, 740))
		game.visual_time = 0.30
		drag(0, Vector2(335, 740))
		game._update_player(0.10)
		check(game.player_pos.x > initial.x and not game.guarding, "%s thumb drag moves and releases guard" % choice)
		near(game.player_pos.x - initial.x, game.move_speed * 0.10, "%s movement speed" % choice)
		touch(1, true, Vector2(60, 600))
		drag(1, Vector2(10, 600))
		check(game.active_touch == 0, "Second finger cannot steal the active thumb")
		touch(1, false, Vector2(10, 600))
		check(game.dragging, "Second finger release does not stop movement")
		touch(0, false, Vector2(335, 740))
		game._update_player(0.016)
		check(not game.dragging and game.guarding and game.parry_timer > 0, "Lifting the active thumb begins a timed parry")
	reset()
	touch(0, true, Vector2(250, 730))
	game.visual_time = 0.08
	drag(0, Vector2(330, 730))
	check(game.gesture_dashed and game.dash_timer > 0, "A deliberate fast 80px flick starts a dash")
	check(not game.try_dash(Vector2.LEFT), "Dash cooldown rejects a second dash")
	game.dash_cooldown = 0.0
	game.visual_time = 0.12
	drag(0, Vector2(400, 730))
	near(game.dash_cooldown, 0.0, "The same gesture cannot dash twice even after cooldown is reset")
	touch(0, false, Vector2(400, 730))
	check(not game.gesture_dashed and not game.dragging, "Release rearms the next gesture")
	reset()
	touch(0, true, Vector2(250, 730))
	game.visual_time = 0.40
	drag(0, Vector2(330, 730))
	check(game.dash_timer == 0.0, "A slow drag does not accidentally dash")
	check(not game.try_dash(Vector2.ZERO), "A zero-direction dash is rejected")
	game._release_input()
	game.player_pos = Vector2(-100, 10000)
	game._update_player(0.016)
	check(game.player_pos.x >= 25 and game.player_pos.y <= game.arena.y - 58, "Movement clamps the knight inside the play area")
	game.dash_cooldown = 1.45
	for step in 90:
		game.tick(1.0 / 60.0)
	near(game.dash_cooldown, 0.0, "Dash becomes available again after its full cooldown")


func _test_damage_guard() -> void:
	reset()
	game.guarding = false
	check(game.damage_player(20), "An exposed knight takes damage")
	near(game.health, 60.0, "Damage subtracts the expected amount")
	check(not game.damage_player(20), "Damage grace prevents stacked same-frame hits")
	near(game.health, 60.0, "Damage grace leaves health unchanged")
	game.hurt_timer = 0.0
	game.try_dash(Vector2.UP)
	check(not game.damage_player(50), "Dash grants temporary collision invulnerability")
	for choice in ["sword", "shield"]:
		reset(choice)
		game.guarding = true
		game.parry_timer = 0.0
		var initial: float = game.health
		game.damage_player(20)
		near(initial - game.health, 15.0 if choice == "sword" else 4.0, "%s guard contact reduction" % choice)
		game.hurt_timer = 0.0
		game.parry_timer = 0.15
		initial = game.health
		check(not game.damage_player(20), "%s perfect guard cancels contact damage" % choice)
		near(game.health, initial, "Perfect guard leaves health unchanged")
	reset()
	game.guarding = true
	game.parry_timer = 0.10
	game.guard_reserve = 50.0
	game._add_bullet(game.player_pos + Vector2(25, 0), Vector2.ZERO, 10)
	game._update_bullets(0.016)
	check(game.bullets.is_empty() and game.score == 4, "Perfect guard removes a nearby bullet and awards a small score")
	check(game.guard_reserve > 50, "Perfect bullet guard refunds reserve")
	reset()
	for step in 360:
		game._update_player(1.0 / 60.0)
	check(game.guard_reserve == 0.0 and not game.guarding, "A stationary guard stays exhausted instead of flickering/recharging")
	game._gesture_press(Vector2(270, 740))
	game.visual_time = 1.0
	game._gesture_drag(Vector2(335, 740))
	game._update_player(0.10)
	check(game.guard_reserve > 0, "Moving restores exhausted guard reserve")
	reset()
	game.ward_hits = 3
	game.buffs.ward = 12.0
	for charge in 3:
		game.hurt_timer = 0.0
		check(not game.damage_player(20), "Ward absorbs charge %d" % (charge + 1))
	check(game.ward_hits == 0 and game.health == 80, "The ward absorbs exactly three hits")
	game.hurt_timer = 0.0
	game.guarding = false
	check(game.damage_player(20), "A fourth hit passes through an exhausted ward")


func _test_class_comparison() -> void:
	var classes: Dictionary = {}
	for choice in ["sword", "shield"]:
		var result: Dictionary = {}
		reset(choice)
		result["health"] = game.max_health
		result["move_speed"] = game.move_speed
		near(game.damage, 32.0 if choice == "sword" else 24.0, "%s damage baseline after Shield buff" % choice)
		near(game.attack_interval, 0.36 if choice == "sword" else 0.60, "%s attack cadence remains unchanged" % choice)
		near(game.guard_capacity, 65.0 if choice == "sword" else 165.0, "%s guard capacity remains unchanged" % choice)
		var target: Dictionary = game.spawn_enemy(0, false, game.player_pos + Vector2(0, -60))
		target.hp = 240.0
		target.max_hp = 240.0
		game.guarding = false
		game.swing_timer = 0.0
		var frames: int = 0
		while target.alive and frames < 1200:
			game._update_weapon(1.0 / 60.0)
			frames += 1
		result["moving_target_kill_seconds"] = frames / 60.0
		check(not target.alive and game.kills == 1, "%s defeats the same 240 HP target through automatic attacks" % choice)
		reset(choice)
		target = game.spawn_enemy(0, false, game.player_pos + Vector2(0, -60))
		target.hp = 1000.0
		target.max_hp = 1000.0
		game.guarding = true
		game.swing_timer = 0.0
		for frame in 240:
			game._update_weapon(1.0 / 60.0)
		result["guarded_damage_in_four_seconds"] = 1000.0 - target.hp
		check(target.hp < 1000, "%s still counterattacks while guarding" % choice)
		reset(choice)
		game.parry_timer = 0.0
		for hit in 8:
			for frame in 48:
				game.tick(1.0 / 60.0)
			game.damage_player(20)
		result["eight_guarded_hits_remaining_health"] = game.health
		result["survives_eight_guarded_hits"] = game.state == "running"
		reset(choice)
		frames = 0
		while game.guard_reserve > 0 and frames < 1200:
			game._update_player(1.0 / 60.0)
			frames += 1
		result["idle_guard_seconds"] = frames / 60.0
		check(game.guard_reserve == 0 and not game.guarding, "%s eventually exhausts guard without recharging at rest" % choice)
		for frame in 120:
			game._update_player(1.0 / 60.0)
		check(game.guard_reserve == 0 and not game.guarding, "%s remains exposed after guard exhaustion" % choice)
		game._gesture_press(Vector2(270, 740))
		game.visual_time = 1.0
		game._gesture_drag(Vector2(335, 740))
		for frame in 120:
			game._update_player(1.0 / 60.0)
		result["reserve_recharged_in_two_seconds"] = game.guard_reserve
		check(game.guard_reserve > 0 and not game.guarding, "%s recharges reserve only while moving" % choice)
		reset(choice)
		game.parry_timer = 0.0
		frames = 0
		while game.guard_reserve > 0 and frames < 1200:
			game._update_player(1.0 / 60.0)
			if frames % 15 == 0:
				game._add_bullet(game.player_pos + Vector2(10, 0), Vector2.ZERO, 10)
			game._update_bullets(1.0 / 60.0)
			frames += 1
		result["guard_under_four_bullets_per_second"] = frames / 60.0
		check(game.guard_reserve == 0, "%s cannot block an identical continuous bullet stream forever" % choice)
		reset(choice)
		for upgrade in 300:
			game.level_up()
			game.choose_upgrade(str(game.upgrade_choices[0].id))
		result["capped_health"] = game.max_health
		result["capped_damage"] = game.damage
		result["capped_attack_interval"] = game.attack_interval
		result["capped_range"] = game.attack_range
		result["capped_guard"] = game.guard_capacity
		result["capped_move_speed"] = game.move_speed
		near(game.max_health, 160.0 if choice == "sword" else 300.0, "%s reaches its own health cap" % choice)
		near(game.damage, 150.0 if choice == "sword" else 95.0, "%s reaches its own damage cap" % choice)
		near(game.attack_interval, 0.22 if choice == "sword" else 0.40, "%s reaches its own attack cadence cap" % choice)
		near(game.attack_range, 124.0 if choice == "sword" else 108.0, "%s reaches its own reach cap" % choice)
		near(game.guard_capacity, 110.0 if choice == "sword" else 250.0, "%s reaches its own guard cap" % choice)
		var snapshot: Dictionary = game.serialize_run()
		check(snapshot.get("balance_version", 0) == 3, "%s snapshot records the new class balance version" % choice)
		var parser := JSON.new()
		check(parser.parse(JSON.stringify(snapshot)) == OK, "%s capped run serializes as JSON" % choice)
		reset("shield" if choice == "sword" else "sword")
		check(game.restore_run(parser.data), "%s capped run restores after switching classes" % choice)
		check(game.style == choice and game.state == "paused", "%s restore selects its saved class and waits for resume" % choice)
		near(game.max_health, result["capped_health"], "%s restore retains class health cap" % choice)
		near(game.damage, result["capped_damage"], "%s restore retains class damage cap" % choice)
		near(game.attack_interval, result["capped_attack_interval"], "%s restore retains class attack cadence" % choice)
		near(game.attack_range, result["capped_range"], "%s restore retains class reach cap" % choice)
		near(game.guard_capacity, result["capped_guard"], "%s restore retains class guard capacity" % choice)
		near(game.move_speed, result["capped_move_speed"], "%s restore retains its chosen movement upgrades" % choice)
		classes[choice] = result
	var sword: Dictionary = classes["sword"]
	var shield: Dictionary = classes["shield"]
	check(shield["moving_target_kill_seconds"] > sword["moving_target_kill_seconds"] * 2.0, "Sword still defeats identical targets substantially faster than buffed Shield")
	check(sword["move_speed"] > shield["move_speed"] * 1.25, "Sword movement is visibly faster than Shield movement")
	check(shield["health"] > sword["health"] * 2, "Shield begins with more than twice Sword's health")
	check(not sword["survives_eight_guarded_hits"] and shield["survives_eight_guarded_hits"], "Identical contact pressure defeats Sword while Shield survives")
	check(shield["eight_guarded_hits_remaining_health"] >= shield["health"] * 0.8, "Shield visibly mitigates repeated guarded contact damage")
	check(shield["idle_guard_seconds"] > sword["idle_guard_seconds"] * 3.5 and shield["idle_guard_seconds"] < 8, "Shield holds guard far longer but still exhausts it")
	check(shield["guard_under_four_bullets_per_second"] > sword["guard_under_four_bullets_per_second"] * 3, "Shield sustains the same bullet pressure far longer")
	check(shield["guard_under_four_bullets_per_second"] < shield["idle_guard_seconds"], "Projectile blocks consume Shield reserve in addition to idle drain")
	check(shield["reserve_recharged_in_two_seconds"] > sword["reserve_recharged_in_two_seconds"] * 1.2, "Shield replenishes more reserve during the same movement interval")
	check(sword["capped_damage"] / sword["capped_attack_interval"] > shield["capped_damage"] / shield["capped_attack_interval"] * 2.5, "Sword retains substantially higher damage output at maximum upgrades")
	check(shield["capped_health"] > sword["capped_health"] * 1.8 and shield["capped_guard"] > sword["capped_guard"] * 2, "Shield retains substantially higher survival reserves at maximum upgrades")
	report["class_comparison"] = classes
	_test_legacy_class_migration()
	_test_v2_shield_damage_migration()


func _test_legacy_class_migration() -> void:
	for choice in ["sword", "shield"]:
		reset(choice)
		game.score = 123
		game.elapsed = 37.5
		game.spawn_enemy(role_index("fan"), false, Vector2(120, 250))
		game._add_bullet(Vector2(160, 400), Vector2(80, 40), 12)
		var snapshot: Dictionary = game.serialize_run()
		snapshot.erase("balance_version")
		snapshot["max_health"] = 100.0 if choice == "sword" else 125.0
		snapshot["health"] = snapshot["max_health"] * 0.5
		snapshot["damage"] = 22.0 if choice == "sword" else 16.0
		snapshot["attack_interval"] = 0.46 if choice == "sword" else 0.51
		snapshot["attack_range"] = 84.0
		snapshot["guard_capacity"] = 100.0 if choice == "sword" else 130.0
		snapshot["guard_reserve"] = snapshot["guard_capacity"] * 0.5
		var expected_rng: int = game.rng.randi()
		var expected_loot: int = game.loot_rng.randi()
		reset("shield" if choice == "sword" else "sword")
		check(game.restore_run(snapshot), "%s legacy run migrates successfully" % choice)
		check(game.style == choice and game.state == "paused", "%s legacy run resumes as its saved class" % choice)
		near(game.max_health, 80.0 if choice == "sword" else 170.0, "%s legacy run adopts new health baseline" % choice)
		near(game.health / game.max_health, 0.5, "%s migration preserves proportional health" % choice)
		near(game.damage, 32.0 if choice == "sword" else 24.0, "%s migration adopts new damage baseline" % choice)
		near(game.attack_interval, 0.36 if choice == "sword" else 0.60, "%s migration adopts new attack cadence" % choice)
		near(game.attack_range, 92.0 if choice == "sword" else 80.0, "%s migration adopts new attack reach" % choice)
		near(game.guard_capacity, 65.0 if choice == "sword" else 165.0, "%s migration adopts new guard capacity" % choice)
		near(game.guard_reserve / game.guard_capacity, 0.5, "%s migration preserves proportional guard reserve" % choice)
		check(game.score == 123 and game.elapsed == 37.5 and game.enemies.size() == 1 and game.bullets.size() == 1, "%s legacy migration preserves progress and active hazards" % choice)
		check(game.rng.randi() == expected_rng and game.loot_rng.randi() == expected_loot, "%s legacy migration preserves encounter and loot RNG sequence" % choice)


func _test_v2_shield_damage_migration() -> void:
	var cases: Array[Dictionary] = [
		{"style": "shield", "damage": 18.0, "expected": 24.0, "label": "Shield baseline"},
		{"style": "shield", "damage": 60.0, "expected": 80.0, "label": "upgraded Shield"},
		{"style": "shield", "damage": 90.0, "expected": 95.0, "label": "Shield near its damage cap"},
		{"style": "sword", "damage": 32.0, "expected": 32.0, "label": "Sword baseline"},
		{"style": "sword", "damage": 140.0, "expected": 140.0, "label": "upgraded Sword"},
	]
	for scenario in cases:
		reset(scenario["style"])
		game.level = 17
		game.score = 321
		game.elapsed = 58.25
		game.combo = 3
		game.best_combo = 5
		game.max_health += 16.0
		game.health = game.max_health * 0.6
		game.guard_capacity += 16.0
		game.guard_reserve = game.guard_capacity * 0.45
		game.attack_interval *= 0.9
		game.attack_range += 5.0
		game.damage = scenario["damage"]
		game.buffs = {"haste": 4.0}
		game.spawn_enemy(role_index("fan"), false, Vector2(120, 250))
		game._add_bullet(Vector2(160, 400), Vector2(80, 40), 12)
		game._drop(Vector2(230, 430), "gold", 1)
		var v2_snapshot: Dictionary = game.serialize_run()
		v2_snapshot["balance_version"] = 2
		var reference_snapshot: Dictionary = v2_snapshot.duplicate(true)
		reference_snapshot["balance_version"] = 3
		reference_snapshot["damage"] = scenario["expected"]
		check(game.restore_run(reference_snapshot), "%s v3 reference run restores" % scenario["label"])
		var reference: Dictionary = game.serialize_run()
		check(game.restore_run(v2_snapshot), "%s v2 saved run migrates" % scenario["label"])
		near(game.damage, scenario["expected"], "%s migration applies only the intended damage adjustment" % scenario["label"])
		var actual: Dictionary = game.serialize_run()
		var changed_fields: Array[String] = []
		for field in reference:
			if field in ["damage", "balance_version"]:
				continue
			if actual.get(field) != reference[field]:
				changed_fields.append(str(field))
		check(changed_fields.is_empty(), "%s v2 migration leaves all other saved stats, progress, hazards and RNG unchanged: %s" % [scenario["label"], changed_fields])
		check(actual["balance_version"] == 3, "%s migrated run is saved as balance version 3" % scenario["label"])
		check(game.style == scenario["style"] and game.state == "paused", "%s migration preserves class and requires a safe resume" % scenario["label"])
		game.resume_run()
		game.tick(1.0 / 60.0)
		check(game.state == "running" and game.player_pos.is_finite(), "%s first migrated gameplay frame remains valid" % scenario["label"])


func _test_slash_splitter() -> void:
	reset()
	var front: Dictionary = game.spawn_enemy(0, false, game.player_pos + Vector2(0, -65))
	var behind: Dictionary = game.spawn_enemy(0, false, game.player_pos + Vector2(0, 65))
	var distant: Dictionary = game.spawn_enemy(0, false, game.player_pos + Vector2(0, -200))
	front.hp = 100.0
	behind.hp = 100.0
	distant.hp = 100.0
	game._add_bullet(game.player_pos + Vector2(0, -50), Vector2.ZERO, 10)
	game._add_bullet(game.player_pos + Vector2(0, 50), Vector2.ZERO, 10)
	game.perform_slash(Vector2.UP)
	near(front.hp, 100.0 - game.damage, "A slash hits its front target once")
	near(behind.hp, 100.0, "The slash does not hit a target behind the knight")
	near(distant.hp, 100.0, "The slash respects its reach")
	check(game.bullets.size() == 1 and game.bullets[0].pos.y > game.player_pos.y, "The slash clears front bullets but preserves rear threats")
	game.damage_enemy(front, 1000)
	var before: int = game.kills
	game.damage_enemy(front, 1000)
	check(game.kills == before, "An already defeated enemy cannot award a second kill")
	reset()
	var splitter: Dictionary = game.spawn_enemy(role_index("splitter"), false, game.player_pos + Vector2(0, -45))
	splitter.hp = 1.0
	game.perform_slash(Vector2.UP)
	var survivors: int = 0
	for enemy in game.enemies:
		if enemy.alive and enemy.minion:
			survivors += 1
	check(survivors == 2 and game.kills == 1, "Splitter offspring survive the slash that created them")


func _test_enemy_patterns_boss() -> void:
	for role in ["chaser", "skitter", "charger", "spitter", "fan", "orbiter", "tank", "splitter"]:
		reset()
		var enemy: Dictionary = game.spawn_enemy(role_index(role), false, Vector2(270, 250))
		check(not enemy.is_empty() and enemy.behavior == role, "%s uses its actual roster behavior" % role)
		enemy.age = 2.0
		enemy.cooldown = 0.0
		game._update_enemies(0.016)
		check(enemy.pos.is_finite(), "%s updates to a finite position" % role)
		if role in ["spitter", "fan", "orbiter", "charger"]:
			if role == "charger":
				enemy.pos = game.player_pos + Vector2(0, -150)
				game._update_enemies(0.016)
			check(enemy.windup >= 0.5 and game.bullets.is_empty(), "%s telegraphs before its attack" % role)
			game._update_enemies(0.30)
			check(game.bullets.is_empty() and enemy.charge == 0, "%s cannot fire in the middle of its windup" % role)
			game._update_enemies(0.50)
			check(enemy.charge > 0 if role == "charger" else game.bullets.size() == (3 if role == "fan" else 1), "%s completes the correct attack after its windup" % role)
	reset()
	var spitter: Dictionary = game.spawn_enemy(role_index("spitter"), false, Vector2(-30, 250))
	spitter.age = 2.0
	spitter.cooldown = 0.0
	game._update_enemies(0.016)
	check(spitter.windup == 0, "An off-screen ranged enemy cannot begin firing")
	reset()
	for index in 110:
		game.spawn_enemy(0, false, Vector2(50 + index % 8 * 55, 250))
	game.elapsed = 45.0
	game.next_boss = 45.0
	game._update_spawns(0.016)
	check(game._boss() != null and game.enemies.size() <= game.MAX_ENEMIES, "A full regular wave still reserves room for the scheduled boss")
	reset()
	game.boss_number = 1
	var boss: Dictionary = game.spawn_enemy(100, true, Vector2(270, 240), false, game.BossCatalog.by_id("moss_baron"))
	game._prepare_attack(boss)
	check(boss.windup >= 0.8 and game.bullets.is_empty(), "The boss has a visible warning interval before shots")
	boss.phase = 0
	game._fire_enemy(boss)
	check(game.bullets.size() == 11, "The boss radial volley leaves three slots as a safe wedge")
	var wedge_clear: bool = true
	for bullet in game.bullets:
		if absf(wrapf(bullet.vel.angle() - boss.aim.angle(), -PI, PI)) < TAU / 14.0 - 0.001:
			wedge_clear = false
	check(wedge_clear, "The radial volley keeps the telegraphed forward gap clear")
	game.health = 30.0
	game.damage_enemy(boss, 100000)
	check(game.bosses == 1 and game.bullets.is_empty(), "Defeating a boss clears its remaining bullets")
	near(game.health, 60.0, "Boss defeat immediately restores 30 health")
	check(game.relief_until >= game.elapsed + 4.9 and game.drops.size() >= 3, "Boss defeat creates a relief window and guaranteed rewards")


func _test_powerups_upgrades() -> void:
	reset()
	game.health = game.max_health - 5.0
	game.collect_drop({"kind": "heart", "value": 25})
	near(game.health, game.max_health, "Healing caps at maximum health")
	for kind in ["haste", "hurricane", "ward", "magnet", "frost", "spark"]:
		for repeat in 5:
			game.collect_drop({"kind": kind, "value": 1})
		check(game.buffs[kind] <= 18, "%s stacking respects the duration cap" % kind)
	check(game.ward_hits == 3, "Repeated wards replace charges instead of accumulating invulnerability")
	for upgrade in 110:
		game.level_up()
		game.choose_upgrade(str(game.upgrade_choices[0].id))
	check(game.damage <= 150 and game.attack_interval >= 0.22 and game.attack_range <= 124, "Offensive upgrades remain within late-run caps")
	check(game.max_health <= 160 and game.guard_capacity <= 110, "Defensive upgrades remain within late-run caps")
	game.buffs = {"haste": 0.01, "ward": 0.01}
	game.hitstop = 0.0
	game.tick(0.02)
	check(game.buffs.is_empty() and game.ward_hits == 0, "Expired buffs disappear and expired ward charges are removed")
	reset()
	game._drop(game.player_pos + Vector2(100, 0), "xp", 2)
	game.drops[0].life = 0.001
	game._update_drops(0.02)
	check(game.drops.is_empty(), "Uncollected pickups expire")
	game.collect_drop({"kind": "xp", "value": 8})
	check(game.level == 2 and game.xp == 0 and game.state == "upgrading" and game.upgrade_choices.size() == 2, "Reaching the first XP goal pauses for two upgrade choices")
	game.choose_upgrade(str(game.upgrade_choices[0].id))
	check(game.state == "running", "Picking one reward resumes gameplay")


func _test_run_build_choices() -> void:
	reset()
	game.buffs = {"haste": 5.0}
	game.combo = 4
	game.combo_timer = 2.0
	game.dash_cooldown = 0.7
	game.spawn_enemy(0, false, Vector2(200, 260))
	game._add_bullet(Vector2(150, 500), Vector2(100, 40), 12)
	game._drop(game.player_pos, "xp", 8)
	var damage_before: float = game.damage
	game._update_drops(0.016)
	check(game.state == "upgrading" and game.upgrade_choices.size() == 2, "Actual XP pickup enters a two-card choice")
	near(game.damage, damage_before, "Level-up applies no automatic damage reward")
	check(game.drops.is_empty() and game.active_touch == -1, "Collected XP is removed before the pending decision is saved")
	var frozen: Dictionary = game.serialize_run()
	var animation_time: float = game.visual_time
	var first_options: Array = frozen.upgrade_choices.duplicate()
	game.tick(5.0)
	game._physics_process(5.0)
	game._process(0.5)
	check(game.serialize_run() == frozen, "Level-up freezes timer, actors, bullets, buffs, combo and cooldowns")
	near(game.visual_time, animation_time, "Choice overlay freezes background animation too")
	game.level_up()
	game.choose_upgrade("not_an_offered_upgrade")
	check(game.level == 2 and game.state == "upgrading" and game.serialize_run().upgrade_choices == first_options, "Re-entry and invalid choices cannot reroll offers or advance a level")
	game._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(game.state == "upgrading", "Android Back and losing focus cannot bypass a pending choice")
	var first_id: String = str(game.upgrade_choices[0].id)
	game.choose_upgrade(first_id)
	check(game.state == "running" and game.upgrade_counts.get(first_id, 0) == 1 and game.upgrade_choices.is_empty(), "Exactly the selected card is applied once and gameplay resumes")
	var after_choice: Dictionary = game.serialize_run()
	game.choose_upgrade(first_id)
	check(game.serialize_run() == after_choice, "A duplicate choice after resume is ignored")
	check(game.hurt_timer >= 0.6 and not game.dragging, "Returning from choices grants damage grace and fresh thumb input")
	reset("shield")
	game.collect_drop({"kind": "xp", "value": 100})
	check(game.state == "upgrading" and game.xp == 92, "Large XP rewards retain overflow while the first choice waits")
	var pending_snapshot: Dictionary = game.serialize_run()
	var expected_upgrades: int = game.upgrade_rng.randi()
	var expected_boss: int = game.boss_rng.randi()
	reset()
	check(game.restore_run(JSON.parse_string(JSON.stringify(pending_snapshot))), "A pending upgrade survives a JSON save/restart")
	check(game.state == "paused" and game.serialize_run().upgrade_choices == pending_snapshot.upgrade_choices, "Restored run keeps the exact original options behind Resume")
	check(game.upgrade_rng.randi() == expected_upgrades and game.boss_rng.randi() == expected_boss, "Both new RNG streams resume without rerolling")
	game.resume_run()
	check(game.state == "upgrading" and game.xp == 92, "Resume returns to the required choice without discarding excess XP")
	var picks := 0
	var spent_xp := 8
	while game.state == "upgrading" and picks < 20:
		var previous_goal: int = game.xp_goal
		game.choose_upgrade(str(game.upgrade_choices[0].id))
		picks += 1
		if game.state == "upgrading": spent_xp += previous_goal
	check(game.state == "running" and picks == game.level - 1 and picks > 1, "Overflow presents and applies one explicit choice per earned level")
	check(spent_xp + game.xp == 100, "Queued decisions conserve every point of earned XP")
	var committed: int = 0
	for count in game.upgrade_counts.values(): committed += int(count)
	check(committed == picks, "Saved build counts contain exactly one accepted pick per level")
	var bad: Dictionary = pending_snapshot.duplicate(true)
	bad.upgrade_choices = ["sharper_steel", "sharper_steel"]
	check(not game.restore_run(bad), "Duplicate saved offers are rejected")
	bad.upgrade_choices = ["keen_edge", "sharper_steel"]
	check(not game.restore_run(bad), "A saved level-two choice cannot bypass the level-ten gate")
	bad.upgrade_choices = ["unknown", "sharper_steel"]
	check(not game.restore_run(bad), "Unknown saved upgrade IDs are rejected safely")


func _test_boss_variation_restore() -> void:
	var first_bosses: Dictionary = {}
	for seed_value in 24:
		reset()
		game.boss_rng.seed = seed_value + 100
		game.elapsed = 45
		game.next_boss = 45
		game._update_spawns(0.016)
		var boss: Dictionary = game._boss()
		first_bosses[boss.boss_id] = true
		check(not game.BossCatalog.by_id(str(boss.boss_id)).is_empty(), "Scheduled boss has a stable catalog identity")
	check(first_bosses.size() >= 4, "Different run seeds produce varied opening bosses")
	var snapshot: Dictionary = game.serialize_run()
	var original_id: String = str(game._boss().boss_id)
	var expected: String = str(game.BossCatalog.choose(game.boss_rng, 250.0, game.last_boss_id).id)
	reset()
	check(game.restore_run(JSON.parse_string(JSON.stringify(snapshot))), "Named boss encounter restores")
	check(str(game._boss().boss_id) == original_id and game.last_boss_id == original_id, "Boss identity and repeat protection survive restart")
	check(str(game.BossCatalog.choose(game.boss_rng, 250.0, game.last_boss_id).id) == expected, "Boss sequence resumes from the exact saved random state")
	for pattern in ["ring", "fan", "charge", "spiral"]:
		reset()
		var definition: Dictionary = {}
		for item in game.BossCatalog.all():
			if item.pattern == pattern: definition = item
		var boss: Dictionary = game.spawn_enemy(0, true, Vector2(200, 250), false, definition)
		boss.phase = 0
		boss.aim = Vector2.DOWN
		game._fire_enemy(boss)
		check(boss.charge > 0 if pattern == "charge" else game.bullets.size() == (7 if pattern == "fan" else 11), "%s boss executes its distinct attack pattern" % pattern)
	reset()
	var rare: Dictionary = game.spawn_enemy(0, true, Vector2(200, 250), false, game.BossCatalog.by_id("moonmallow_majesty"))
	game.testing = false
	game.damage_enemy(rare, 100000)
	game.testing = true
	check("moonmallow_majesty" in save.profile.defeated_bosses and save.profile.achievements.has("rare_boss"), "An actual rare-boss kill records its victory and local badge immediately")


func _test_audio_preferences() -> void:
	reset()
	for combination in [[true, false], [false, true], [false, false], [true, true]]:
		game._set_audio_setting("music", combination[0])
		game._set_audio_setting("sfx", combination[1])
		check(audio.is_music_enabled() == combination[0] and audio.is_sfx_enabled() == combination[1], "Music and effects support the requested independent combination")
		save.reload_profile()
		check(save.profile.settings.music == combination[0] and save.profile.settings.sfx == combination[1], "Independent audio preferences survive a disk reload")
	game._set_audio_setting("unsupported", false)
	check(save.profile.settings.music and save.profile.settings.sfx, "Unknown audio settings are ignored")
	audio.set_enabled(false)


func _test_pause_restart() -> void:
	reset()
	touch(0, true, Vector2(250, 730))
	game.pause_run()
	check(game.state == "paused" and not game.dragging and game.active_touch == -1, "Pause releases active input")
	var before: float = game.elapsed
	game._physics_process(0.5)
	near(game.elapsed, before, "Paused physics cannot advance hazards")
	game.resume_run()
	check(game.state == "running" and game.hurt_timer >= 0.45, "Resume returns safely with fresh damage grace")
	game.end_run()
	check(game.state == "dead", "End-run overlay follows a completed run")
	game.start_run("shield")
	check(game.state == "running" and game.score == 0 and game.kills == 0 and game.style == "shield", "One-tap restart clears the previous run and switches style")


func _test_snapshot() -> void:
	reset("shield")
	game.score = 417
	game.elapsed = 67.5
	game.combo = 7
	game.best_combo = 12
	game.buffs = {"haste": 5.0, "ward": 6.0}
	game.ward_hits = 2
	game.spawn_enemy(role_index("fan"), false, Vector2(120, 250))
	game._add_bullet(Vector2(160, 400), Vector2(80, 40), 12)
	game._drop(Vector2(230, 430), "gold", 1)
	var snapshot: Dictionary = game.serialize_run()
	var parser := JSON.new()
	check(parser.parse(JSON.stringify(snapshot)) == OK, "Active gameplay snapshot survives a real JSON round trip")
	var expected_rng: int = game.rng.randi()
	var expected_loot: int = game.loot_rng.randi()
	game.start_run("sword")
	check(game.restore_run(parser.data), "A valid JSON snapshot restores the actual game")
	check(game.state == "paused" and game.style == "shield", "Restored gameplay waits behind a paused resume overlay")
	check(game.score == 417 and game.combo == 7 and game.best_combo == 12 and game.ward_hits == 2, "Progress, combo and ward charges survive restore")
	near(game.elapsed, 67.5, "Elapsed time survives restore")
	check(game.enemies.size() == 1 and game.bullets.size() == 1 and game.drops.size() == 1, "All active entity categories survive restore")
	check(game.rng.randi() == expected_rng and game.loot_rng.randi() == expected_loot, "Encounter and loot RNG resume at their saved sequence")
	check(game.hurt_timer >= 0.45 and not game.dragging, "Restoring grants grace and clears stale gestures")
	game.resume_run()
	game.tick(0.016)
	check(game.player_pos.is_finite(), "The first resumed frame remains valid")


func _test_malformed_snapshots() -> void:
	reset()
	var baseline: Dictionary = game.serialize_run()
	for field in ["schema", "health", "elapsed", "score", "max_health", "damage", "attack_interval", "guard_capacity", "xp_goal", "dash_cooldown"]:
		var bad: Dictionary = baseline.duplicate(true)
		bad[field] = ["unexpected array"]
		check(not game.restore_run(bad), "Restore rejects a wrong-type %s scalar" % field)
	for field in ["health", "elapsed", "damage", "attack_interval", "next_boss"]:
		var bad: Dictionary = baseline.duplicate(true)
		bad[field] = NAN
		check(not game.restore_run(bad), "Restore rejects a non-finite %s scalar" % field)
	var bad_player: Dictionary = baseline.duplicate(true)
	bad_player.player = [["nested"], {}]
	check(not game.restore_run(bad_player), "Restore rejects non-numeric player coordinates")
	check(not game.restore_run({}), "Restore rejects a missing snapshot schema")
	reset()
	var valid_enemy: Dictionary = game._encode_entity(game.spawn_enemy(0, false, Vector2(180, 250)))
	var malformed: Array = [null, 2, {}, {"pos": [0]}, {"pos": [[1], {}]}]
	for field in ["hp", "speed", "damage", "age", "cooldown", "windup", "radius", "phase"]:
		var bad: Dictionary = valid_enemy.duplicate(true)
		bad[field] = {"wrong": "type"}
		malformed.append(bad)
	var wrong_kind: Dictionary = valid_enemy.duplicate(true)
	wrong_kind.kind = 100000
	malformed.append(wrong_kind)
	var bad_bool: Dictionary = valid_enemy.duplicate(true)
	bad_bool.alive = "yes"
	malformed.append(bad_bool)
	check(game._decode_entities(malformed, 100, "enemy").is_empty(), "Malformed enemy dictionaries are skipped safely")
	var saturated: Array = []
	for index in 300:
		saturated.append(valid_enemy.duplicate(true))
	check(game._decode_entities(saturated, game.MAX_ENEMIES, "enemy").size() <= game.MAX_ENEMIES, "Oversized saved waves stay capped on decode")
	var bullet: Dictionary = {"pos": [120, 250], "vel": [10000, 10000], "damage": 10000, "life": 10000, "boss": false, "radius": 10000}
	var decoded: Array = game._decode_entities([bullet], 240, "bullet")
	check(decoded.size() == 1, "A numeric oversized bullet is sanitized")
	if not decoded.is_empty():
		check(decoded[0].radius <= 8 and decoded[0].vel.length() <= 350.1 and decoded[0].damage <= 30 and decoded[0].life <= 7, "Restored bullet radius, velocity, damage and lifetime have safe caps")
	var wrong_bullet: Dictionary = bullet.duplicate(true)
	wrong_bullet.vel = [null, []]
	check(game._decode_entities([wrong_bullet], 240, "bullet").is_empty(), "Wrong-type bullet vectors are skipped safely")
	var wrong_drop: Dictionary = {"pos": [120, 250], "kind": "unknown", "value": 4, "life": 10, "phase": 0}
	check(game._decode_entities([wrong_drop], 60, "drop").is_empty(), "Unknown saved pickups are rejected")


func _test_stress() -> void:
	reset()
	game.demo = true
	game.elapsed = 240.0
	game.next_boss = 240.0
	game.spawn_timer = 0.0
	game.swing_timer = 0.0
	game.rng.seed = 10112
	game.loot_rng.seed = 551019
	var samples: Array[int] = []
	var peaks := {"enemies": 0, "bullets": 0, "drops": 0, "effects": 0}
	var begin: int = Time.get_ticks_usec()
	for frame in 18000:
		if frame % 60 == 0:
			for n in range(game.MAX_ENEMIES):
				game.spawn_enemy(n % game.roster.size(), false, Vector2(40 + (n % 8) * 64, 170 + (n % 11) * 55))
			for n in range(game.MAX_BULLETS):
				game._add_bullet(Vector2(30 + (n % 12) * 43, 170 + (n % 14) * 42), Vector2.from_angle(n * 0.31) * 140, 12, true)
			for n in range(game.MAX_DROPS):
				game._drop(Vector2(30 + (n % 9) * 54, 250 + (n % 8) * 75), "xp", 1)
			for n in range(game.MAX_EFFECTS):
				game._add_effect(Vector2(100, 250), Vector2(1, 1), "spark", Color.WHITE, 0.4)
		var step_start: int = Time.get_ticks_usec()
		# The stress bot chooses deliberately; production play never auto-picks.
		while game.state == "upgrading":
			game.choose_upgrade(str(game.upgrade_choices[0].id))
		game.tick(1.0 / 60.0)
		game._process(1.0 / 60.0)
		samples.append(Time.get_ticks_usec() - step_start)
		peaks.enemies = maxi(peaks.enemies, game.enemies.size())
		peaks.bullets = maxi(peaks.bullets, game.bullets.size())
		peaks.drops = maxi(peaks.drops, game.drops.size())
		peaks.effects = maxi(peaks.effects, game.effects.size())
		if frame % 600 == 0:
			check(game.enemies.size() <= game.MAX_ENEMIES and game.bullets.size() <= game.MAX_BULLETS and game.drops.size() <= game.MAX_DROPS and game.effects.size() <= game.MAX_EFFECTS, "Stress entities remain capped at simulated second %d" % (frame / 60))
			check(game.player_pos.is_finite() and is_finite(game.health) and game.health >= 0, "Stress player state is finite and nonnegative")
			await process_frame
	var duration_ms: float = (Time.get_ticks_usec() - begin) / 1000.0
	samples.sort()
	var total: int = 0
	for sample in samples:
		total += sample
	var stress := {"simulated_seconds": 300, "steps": 18000, "wall_time_ms": duration_ms, "average_step_ms": total / 18000.0 / 1000.0, "p95_step_ms": samples[int(samples.size() * 0.95)] / 1000.0, "max_step_ms": samples[-1] / 1000.0, "peaks": peaks, "kills": game.kills, "bosses_seen": game.boss_number, "level": game.level, "rendering_measured": false, "android_device_measured": false}
	report["stress"] = stress
	check(game.textures.size() == 101 and game.get_child_count() == 2, "Stress simulation uses cached textures and fixed world/HUD nodes")
	check(game.state == "running" and game.elapsed >= 539.9, "The actual simulation completes five continuous minutes")
	print("STRESS: " + JSON.stringify(stress))
