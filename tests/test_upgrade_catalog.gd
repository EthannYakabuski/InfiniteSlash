extends SceneTree
## Focused tests for class-aware, deterministic, effective level-up offers.

const Catalog = preload("res://scripts/upgrade_catalog.gd")
const ClassProfiles = preload("res://scripts/class_profiles.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("UPGRADE TEST: " + message)


func baseline(style: String = "sword") -> Dictionary:
	var profile: Dictionary = ClassProfiles.get_profile(style)
	return {"style": style, "health": float(profile.health), "max_health": float(profile.health), "damage": float(profile.damage), "attack_interval": float(profile.attack_interval), "attack_range": float(profile.attack_range), "guard_capacity": float(profile.guard_capacity), "guard_reserve": float(profile.guard_capacity), "move_speed": float(profile.move_speed), "dash_recharge": Catalog.DASH_BASE, "score": 0}


func capped(style: String = "sword") -> Dictionary:
	var stats := baseline(style)
	var profile: Dictionary = ClassProfiles.get_profile(style)
	stats.health = float(profile.health_cap)
	stats.max_health = float(profile.health_cap)
	stats.damage = float(profile.damage_cap)
	stats.attack_interval = float(profile.attack_floor)
	stats.attack_range = float(profile.range_cap)
	stats.guard_capacity = float(profile.guard_cap)
	stats.guard_reserve = float(profile.guard_cap)
	stats.move_speed = float(profile.move_speed) * Catalog.MOVE_CAP_MULTIPLIER
	stats.dash_recharge = Catalog.DASH_FLOOR
	return stats


func ids(cards: Array) -> Array:
	var result: Array = []
	for card in cards:
		result.append(str(card.id))
	return result


func _run() -> void:
	check(Catalog.eligible(2, baseline()).size() == 5, "first level-up draws from all five former automatic rewards")
	check(Catalog.eligible(3, baseline()).size() == 6, "movement upgrade unlocks at level 3")
	check(Catalog.eligible(5, baseline()).size() == 7, "dash recharge upgrade unlocks at level 5")
	check(Catalog.eligible(9, baseline()).size() == 7, "combined damage and reach reward stays gated before level 10")
	check(Catalog.eligible(10, baseline()).size() == 8, "Keen Edge joins offers at level 10")
	check(not ids(Catalog.eligible(10, baseline(), {"keen_edge": 3})).has("keen_edge"), "Keen Edge stops after its three picks")
	check(ids(Catalog.eligible(10, baseline(), {"keen_edge": 2})).has("keen_edge"), "Keen Edge can still be picked a third time")
	check(Catalog.get_upgrade("unknown").is_empty(), "unknown saved upgrade ID cannot acquire a definition")
	var copy := Catalog.get_upgrade("sharper_steel")
	copy.name = "CHANGED"
	check(Catalog.get_upgrade("sharper_steel").name == "SHARPER STEEL", "UI metadata is a defensive copy")
	var random_a := RandomNumberGenerator.new()
	var random_b := RandomNumberGenerator.new()
	random_a.seed = 88231
	random_b.seed = 88231
	var reproducible := true
	var valid_offers := true
	var variety: Dictionary = {}
	for index in range(100):
		var level := 2 + index % 30
		var offers: Array = Catalog.roll_offers(random_a, level, baseline())
		var repeated: Array = Catalog.roll_offers(random_b, level, baseline())
		reproducible = reproducible and JSON.stringify(offers) == JSON.stringify(repeated)
		valid_offers = valid_offers and offers.size() == 2 and offers[0].id != offers[1].id
		for card in offers:
			valid_offers = valid_offers and card.has_all(["id", "name", "description", "min_level", "icon"]) and int(card.min_level) <= level
			variety[str(card.id)] = true
	check(reproducible, "same dedicated upgrade RNG state reproduces the offer sequence")
	check(valid_offers, "all 100 rolls contain two different eligible, fully described choices")
	check(variety.size() == 8, "random offers can expose every regular build option")
	var deterministic_fallback := true
	var bounded_luck := true
	for _index in range(30):
		var luck_a: Dictionary = Catalog.apply_upgrade("lucky_purse", capped(), random_a)
		var luck_b: Dictionary = Catalog.apply_upgrade("lucky_purse", capped(), random_b)
		deterministic_fallback = deterministic_fallback and luck_a.score == luck_b.score
		bounded_luck = bounded_luck and int(luck_a.score) >= 100 and int(luck_a.score) <= 1000
	check(deterministic_fallback, "Lucky Purse uses the supplied run RNG")
	check(bounded_luck, "Lucky Purse never awards outside its advertised range")
	for style in ["sword", "shield"]:
		_test_class(style, random_a)
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
	# The dummy audio backend drains its first mix on a real-time worker.
	await create_timer(0.10).timeout
	await process_frame
	await process_frame
	if failures.is_empty():
		print("UPGRADE_CATALOG_TESTS_PASS checks=%d" % checks)
		quit(0)
	else:
		print("UPGRADE_CATALOG_TESTS_FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _test_class(style: String, rng: RandomNumberGenerator) -> void:
	var profile: Dictionary = ClassProfiles.get_profile(style)
	var stats := baseline(style)
	stats.health = 1.0
	stats.guard_reserve = 0.0
	var before := JSON.stringify(stats)
	var heart: Dictionary = Catalog.apply_upgrade("heart_of_a_knight", stats)
	check(is_equal_approx(float(heart.max_health), float(profile.health) + 8.0) and is_equal_approx(float(heart.health), 19.0), style + " heart raises capacity and heals immediately")
	var guard: Dictionary = Catalog.apply_upgrade("stronger_guard", stats)
	check(is_equal_approx(float(guard.guard_capacity), float(profile.guard_capacity) + 8.0) and is_equal_approx(float(guard.guard_reserve), 30.0), style + " guard upgrade raises capacity and replenishes reserve")
	check(JSON.stringify(stats) == before, style + " applying upgrades never mutates input or the class profile")
	check(Catalog.apply_upgrade("unknown", stats) == stats, style + " unknown upgrade is a harmless no-op")
	var every_option_changes_stats := true
	for card in Catalog.eligible(20, stats):
		every_option_changes_stats = every_option_changes_stats and Catalog.apply_upgrade(str(card.id), stats) != stats
	check(every_option_changes_stats, style + " every advertised permanent upgrade changes a stat")
	for _index in range(120):
		for id in Catalog.REGULAR_IDS:
			stats = Catalog.apply_upgrade(id, stats)
	check(is_equal_approx(float(stats.damage), float(profile.damage_cap)), style + " damage stops at its distinct class cap")
	check(is_equal_approx(float(stats.attack_interval), float(profile.attack_floor)), style + " slash cadence stops at its distinct class floor")
	check(is_equal_approx(float(stats.attack_range), float(profile.range_cap)), style + " reach stops at its distinct class cap")
	check(is_equal_approx(float(stats.max_health), float(profile.health_cap)), style + " maximum health stops at its distinct class cap")
	check(is_equal_approx(float(stats.guard_capacity), float(profile.guard_cap)), style + " guard capacity stops at its distinct class cap")
	check(is_equal_approx(float(stats.move_speed), float(profile.move_speed) * Catalog.MOVE_CAP_MULTIPLIER), style + " movement remains bounded at +30% of class base")
	check(is_equal_approx(float(stats.dash_recharge), Catalog.DASH_FLOOR), style + " dash recharge remains bounded at 0.90 seconds")
	check(Catalog.eligible(100, stats).is_empty(), style + " capped stats are not offered as ineffective upgrades")
	var all_caps := capped(style)
	var fallback: Array = ids(Catalog.roll_offers(rng, 100, all_caps))
	check(fallback.size() == 2 and fallback.has("royal_purse") and fallback.has("lucky_purse"), style + " full-health capped runs still offer two useful score choices")
	check(Catalog.apply_upgrade("royal_purse", all_caps).score == 500, style + " guaranteed treasure remains useful after all stat caps")
	all_caps.health = 1.0
	all_caps.guard_reserve = 0.0
	fallback = ids(Catalog.roll_offers(rng, 100, all_caps))
	check(fallback.has("field_rations") and fallback.has("royal_purse"), style + " wounded capped runs can choose recovery or guaranteed points")
	var restored: Dictionary = Catalog.apply_upgrade("field_rations", all_caps)
	check(restored.health == restored.max_health and restored.guard_reserve == restored.guard_capacity, style + " recovery restores health and guard without raising caps")
	all_caps.damage = float(profile.damage_cap) - 1.0
	var last_stat_kept := true
	for _index in range(20):
		last_stat_kept = last_stat_kept and ids(Catalog.roll_offers(rng, 100, all_caps)).has("sharper_steel")
	check(last_stat_kept, style + " last available stat improvement always appears beside a useful fallback")
	var near_cap: Array = Catalog.eligible(20, all_caps)
	check(near_cap.size() == 1 and not str(near_cap[0].description).contains("+14%"), style + " near-cap cards describe the effective percentage rather than promising a full 14%")
	all_caps = baseline(style)
	all_caps.attack_range = profile.range_cap
	check(not ids(Catalog.eligible(20, all_caps)).has("keen_edge"), style + " combined power reward requires both advertised stats to benefit")
