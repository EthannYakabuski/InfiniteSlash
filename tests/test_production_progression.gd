extends SceneTree

const Progression = preload("res://scripts/progression.gd")
const Catalog = preload("res://scripts/upgrade_catalog.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	check(Progression.xp_goal(1) == 10, "first XP goal rises from eight to ten")
	for level: int in [2, 10, 19, 20, 21, 30, 39, 40, 41, 50, 99, 100]:
		var old_goal := int(8.0 + pow(float(level), 1.28) * 3.0)
		var factor := 1.25 if level <= 20 else 1.5 if level <= 40 else 2.0
		check(Progression.xp_goal(level) == int(ceil(old_goal * factor)), "exact requested XP multiplier and rounding at level %d" % level)
	check(Progression.stage(29) == 1 and Progression.stage(30) == 2 and Progression.stage(49) == 2 and Progression.stage(50) == 3 and Progression.stage(79) == 3 and Progression.stage(80) == 4, "stage gates exactly match the agreed level bands")
	check(not bool(Progression.boss_scaling(19).elemental) and bool(Progression.boss_scaling(20).elemental), "boss elemental attacks unlock at level twenty")
	var monotonic := true
	var finite := true
	var prior_goal := 0
	var prior_health := 0.0
	var prior_damage := 0.0
	for level: int in range(1, 1001):
		var enemy := Progression.enemy_scaling(level)
		var boss := Progression.boss_scaling(level)
		var goal := Progression.xp_goal(level)
		monotonic = monotonic and goal > prior_goal and float(enemy.health) >= prior_health and float(enemy.damage) >= prior_damage
		for key: String in ["health", "damage", "speed", "projectile_speed", "cooldown", "aggression"]:
			finite = finite and is_finite(float(enemy[key])) and is_finite(float(boss[key])) and float(enemy[key]) > 0.0 and float(boss[key]) > 0.0
		prior_goal = goal
		prior_health = float(enemy.health)
		prior_damage = float(enemy.damage)
	check(monotonic, "XP, enemy HP and enemy damage never regress through level one thousand")
	check(finite, "all supported enemy/boss scaling remains finite and positive")
	for level: int in [1, 11, 21, 31, 41, 51, 61, 71, 81, 91]:
		var now := Progression.enemy_scaling(level)
		var later := Progression.enemy_scaling(level + 10)
		check(float(later.health) >= float(now.health) * 1.61 and float(later.damage) >= float(now.damage) * 1.37, "every ten levels compounds enemy health/damage at %d" % level)
	check(float(Progression.enemy_scaling(30).speed) > float(Progression.enemy_scaling(29).speed) and float(Progression.enemy_scaling(50).speed) > float(Progression.enemy_scaling(49).speed), "middle and late gates increase movement pressure immediately")
	check(float(Progression.boss_scaling(50).health) > float(Progression.enemy_scaling(50).health) * 3.5 and float(Progression.boss_scaling(80).health) > float(Progression.enemy_scaling(80).health) * 4.7, "late and endgame bosses get substantial extra health")
	check(float(Progression.boss_scaling(50).cooldown) < float(Progression.enemy_scaling(50).cooldown) and float(Progression.boss_scaling(50).speed) > float(Progression.enemy_scaling(50).speed), "late bosses actively attack and chase more aggressively")
	check(float(Progression.enemy_scaling(100).health) > 500.0 and float(Progression.enemy_scaling(100).damage) > 50.0, "level one hundred is intentionally an extreme survival challenge")
	for style: String in ["sword", "shield"]:
		var stats := Catalog.normalize_stats({"style": style, "level": 1})
		var starting_damage := float(stats.damage)
		for level: int in range(2, 101):
			stats.level = level
			stats = Catalog.apply_upgrade("sharper_steel", stats)
		check(float(Progression.enemy_scaling(100).health) > float(stats.damage) / starting_damage, style + " even ninety-nine focused damage upgrades grow slower than enemy health")
	check(Progression.xp_goal(-99) == Progression.xp_goal(1) and Progression.xp_goal(999999999) == Progression.xp_goal(1000), "malformed extreme levels use bounded progression values")
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
	await create_timer(0.1).timeout
	await process_frame
	await process_frame
	if failures.is_empty():
		print("PRODUCTION_PROGRESSION_TESTS_PASS checks=%d" % checks)
		quit(0)
	else:
		print("PRODUCTION_PROGRESSION_TESTS_FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)
