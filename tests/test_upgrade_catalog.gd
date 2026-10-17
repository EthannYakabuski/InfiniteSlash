extends SceneTree

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
		push_error(message)


func baseline(style: String = "sword", level: int = 1) -> Dictionary:
	return Catalog.normalize_stats({"style": style, "level": level, "score": 0})


func ids(cards: Array) -> Array:
	var result: Array = []
	for card: Dictionary in cards:
		result.append(str(card.id))
	return result


func valid_stats(stats: Dictionary) -> bool:
	var limits: Dictionary = Catalog.stat_limits(stats)
	for key: String in limits:
		if not is_finite(float(stats[key])) or float(stats[key]) < float(limits[key][0]) - 0.00001 or float(stats[key]) > float(limits[key][1]) + 0.00001:
			return false
	return float(stats.health) >= 0.0 and float(stats.health) <= float(stats.max_health) and float(stats.guard_reserve) >= 0.0 and float(stats.guard_reserve) <= float(stats.guard_capacity)


func _run() -> void:
	# This pure catalog suite deliberately occupies the main thread for seconds.
	# Drain startup playback first so the dummy audio backend can release its WAV
	# before the long deterministic sampling loop blocks main-thread updates.
	var startup_audio := root.get_node_or_null("AudioManager")
	if startup_audio != null and startup_audio.has_method("stop_for_shutdown"):
		startup_audio.stop_for_shutdown()
	await create_timer(0.15).timeout
	await process_frame
	await process_frame
	var definitions := Catalog.all_definitions()
	var unique: Dictionary = {}
	var names: Dictionary = {}
	var trades := 0
	var legends := 0
	for card: Dictionary in definitions:
		check(card.has_all(["id", "name", "description", "min_level", "rarity", "kind", "icon"]), "card has complete UI/save metadata: " + str(card.id))
		check(not unique.has(str(card.id)) and not names.has(str(card.name)), "card has unique stable ID and name: " + str(card.id))
		unique[str(card.id)] = true
		names[str(card.name)] = true
		if bool(card.get("tradeoff", false)):
			trades += 1
		if str(card.rarity) == "legendary":
			legends += 1
			check(int(card.min_level) >= 25, "legendary card cannot leak before level 25")
	check(trades == 72, "all 72 ordered tradeoffs across nine core stats exist")
	check(legends == 6, "six distinct legendary build cards exist")
	check(Catalog.get_upgrade("unknown").is_empty(), "unknown saved ID has no definition")
	check(Catalog.get_upgrade("trade_damage_for_damage").is_empty(), "same-stat fake tradeoff is rejected")
	check(Catalog.get_upgrade("trade_invalid_for_damage").is_empty(), "unknown-stat fake tradeoff is rejected")
	var copied := Catalog.get_upgrade("sharper_steel")
	copied.name = "CHANGED"
	check(Catalog.get_upgrade("sharper_steel").name == "SHARPER STEEL", "metadata returned to UI is a defensive copy")
	check(Catalog.eligible(2, baseline()).size() == 5, "first level-up retains the five foundational options")
	for gate: int in [10, 20, 30, 50]:
		var at_gate: Array = Catalog.eligible(gate, baseline("sword", gate))
		var new_rare := 0
		for card: Dictionary in at_gate:
			if int(card.min_level) == gate and str(card.rarity) == "rare" and not bool(card.get("tradeoff", false)):
				new_rare += 1
		check(new_rare >= 3, "level %d unlocks at least three distinct pure rare options" % gate)
	check(not ids(Catalog.eligible(39, baseline())).has("royal_purse"), "treasure is reserved for late build decisions")
	check(ids(Catalog.eligible(40, baseline())).has("royal_purse"), "Royal Purse unlocks at level 40")
	check(not ids(Catalog.eligible(10, baseline(), {"keen_edge": 3})).has("keen_edge"), "Keen Edge retains its three-pick limit")
	check(ids(Catalog.eligible(10, baseline(), {"keen_edge": 2})).has("keen_edge"), "third Keen Edge pick remains available")
	check(Catalog.rarity_chances(9).rare == 0.0 and Catalog.rarity_chances(24).legendary == 0.0, "rare and legendary chance are gated")
	check(is_equal_approx(float(Catalog.rarity_chances(25).legendary), 0.012), "legendary chance is explicitly 1.2 percent per offer slot")
	for style: String in ["sword", "shield"]:
		_test_class(style)
	_test_rarity()
	var manifest := FileAccess.open("res://output/review/production_upgrade_manifest.json", FileAccess.WRITE)
	if manifest != null:
		manifest.store_string(JSON.stringify(definitions, "\t"))
		manifest.close()
	manifest = null
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
	await create_timer(0.1).timeout
	await process_frame
	await process_frame
	if failures.is_empty():
		print("UPGRADE_CATALOG_TESTS_PASS checks=%d cards=%d trades=%d" % [checks, definitions.size(), trades])
		quit(0)
	else:
		print("UPGRADE_CATALOG_TESTS_FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _test_class(style: String) -> void:
	var stats := baseline(style)
	var profile: Dictionary = ClassProfiles.get_profile(style)
	var original := JSON.stringify(stats)
	var profile_original := JSON.stringify(profile)
	var heart := Catalog.apply_upgrade("heart_of_a_knight", stats)
	check(is_equal_approx(float(heart.max_health), float(profile.health) + 8.0), style + " foundational health reward remains useful")
	var guard := Catalog.apply_upgrade("stronger_guard", stats)
	check(is_equal_approx(float(guard.guard_capacity), float(profile.guard_capacity) + 8.0), style + " foundational guard capacity reward remains useful")
	check(JSON.stringify(stats) == original and JSON.stringify(profile) == profile_original, style + " reward application cannot mutate source stats or profile")
	check(Catalog.apply_upgrade("unknown", stats) == stats, style + " unknown upgrade is a harmless no-op")
	check(float(stats.guard_delay) == (0.3 if style == "shield" else 0.5), style + " correct class guard recovery delay")
	check(float(profile.guard_cost_multiplier) == (0.8 if style == "shield" else 1.2), style + " correct class guard damage cost")
	var all_trades := 0
	stats.level = 50
	stats.health = float(stats.max_health) * 0.5
	stats.guard_reserve = float(stats.guard_capacity) * 0.4
	for card: Dictionary in Catalog.eligible(50, stats):
		var changed := Catalog.apply_upgrade(str(card.id), stats)
		check(valid_stats(changed), style + " card respects all stat bounds: " + str(card.id))
		if bool(card.get("tradeoff", false)):
			all_trades += 1
			check(Catalog._is_improved(card.gain, stats, changed) and Catalog._is_improved(card.cost, changed, stats), style + " trade has a real benefit and real cost: " + str(card.id))
			check(str(card.description).contains("→") and str(card.description).contains("\n"), style + " trade displays effective before/after values")
			if str(card.gain) == "max_health" or str(card.cost) == "max_health":
				check(is_equal_approx(float(changed.health) / float(changed.max_health), 0.5), style + " health trade preserves the current health ratio")
			if str(card.gain) == "guard_capacity" or str(card.cost) == "guard_capacity":
				check(is_equal_approx(float(changed.guard_reserve) / float(changed.guard_capacity), 0.4), style + " guard trade preserves the current reserve ratio")
	check(all_trades == 72, style + " all ordered tradeoffs are usable at sensible level-50 stats")
	var floored := stats.duplicate(true)
	floored.guard_capacity = 6.0
	floored.guard_reserve = 0.0
	check(not ids(Catalog.eligible(50, floored)).has("trade_guard_capacity_for_damage"), style + " trade cannot become a free reward when the sacrificed stat is exhausted")
	var maximum := Catalog.stat_limits(stats)
	stats.move_speed = float(maximum.move_speed[1])
	check(not ids(Catalog.eligible(50, stats)).has("trade_damage_for_move_speed"), style + " trade cannot sacrifice a stat for an already capped benefit")
	var dash_cost := baseline(style, 50)
	dash_cost.dash_recharge = Catalog.DASH_CEILING
	check(not ids(Catalog.eligible(50, dash_cost)).has("trade_dash_recharge_for_damage"), style + " an exhausted dash downside cannot grant free damage")
	var dash_gain := baseline(style, 50)
	dash_gain.dash_recharge = Catalog.DASH_FLOOR
	check(not ids(Catalog.eligible(50, dash_gain)).has("trade_damage_for_dash_recharge"), style + " a capped dash benefit cannot cost damage")
	var slower_dash := Catalog.apply_upgrade("trade_dash_recharge_for_damage", baseline(style, 50))
	check(float(slower_dash.dash_recharge) > Catalog.DASH_BASE and float(slower_dash.damage) > float(profile.damage), style + " dash trade can meaningfully sacrifice recharge beyond its starting duration")
	var restored_dash := Catalog.apply_upgrade("quickstep", slower_dash)
	check(is_equal_approx(float(restored_dash.dash_recharge), float(slower_dash.dash_recharge) - 0.10), style + " Quickstep repairs a traded dash at its unchanged ordinary rate")
	# Reaching every old 0.2 class cap must no longer collapse the run to purses.
	stats = baseline(style, 100)
	stats.damage = float(profile.damage_cap)
	stats.max_health = float(profile.health_cap)
	stats.health = stats.max_health
	stats.guard_capacity = float(profile.guard_cap)
	stats.guard_reserve = stats.guard_capacity
	check(ids(Catalog.eligible(100, stats)).has("sharper_steel") and ids(Catalog.eligible(100, stats)).has("heart_of_a_knight") and ids(Catalog.eligible(100, stats)).has("stronger_guard"), style + " damage, health and guard retain permanent growth beyond the old caps")
	var random_a := RandomNumberGenerator.new()
	var random_b := RandomNumberGenerator.new()
	random_a.seed = 88231
	random_b.seed = 88231
	var repeatable := true
	var valid_offers := true
	var late_build := true
	for index: int in range(130):
		var level := 2 + index
		stats.level = level
		var offers := Catalog.roll_offers(random_a, level, stats)
		var repeated := Catalog.roll_offers(random_b, level, stats)
		repeatable = repeatable and JSON.stringify(offers) == JSON.stringify(repeated)
		valid_offers = valid_offers and offers.size() == 2 and offers[0].id != offers[1].id
		var build := false
		for card: Dictionary in offers:
			valid_offers = valid_offers and int(card.min_level) <= level
			build = build or str(card.kind) == "permanent"
		late_build = late_build and build
	check(repeatable, style + " seeded offer RNG survives complete reproducible early-to-endgame sequences")
	check(valid_offers, style + " every sequence roll has two different level-eligible offers")
	check(late_build, style + " every level retains at least one permanent build choice")
	stats = baseline(style, 40)
	check(Catalog.apply_upgrade("royal_purse", stats).score == 10000, style + " Royal Purse pays ten thousand score at unlock")
	stats.level = 50
	check(Catalog.apply_upgrade("royal_purse", stats).score == 12500, style + " purse value keeps growing in late stages")
	var bounded_luck := true
	var same_luck := true
	for _index: int in range(30):
		var first := Catalog.apply_upgrade("lucky_purse", stats, random_a)
		var second := Catalog.apply_upgrade("lucky_purse", stats, random_b)
		bounded_luck = bounded_luck and int(first.score) >= 10000 and int(first.score) <= 35000
		same_luck = same_luck and first.score == second.score
	check(bounded_luck and same_luck, style + " Lucky Purse follows the advertised range and supplied RNG")
	stats.health = 1.0
	stats.guard_reserve = 0.0
	var restored := Catalog.apply_upgrade("field_rations", stats)
	check(restored.health == restored.max_health and restored.guard_reserve == restored.guard_capacity, style + " recovery fully restores without changing capacities")
	stats = baseline(style, 25)
	var phoenix := Catalog.apply_upgrade("phoenix_oath", stats)
	check(bool(phoenix.second_wind) and not bool(phoenix.second_wind_used), style + " Phoenix Oath grants a distinct unspent revival")
	check(not ids(Catalog.eligible(25, phoenix)).has("phoenix_oath"), style + " an owned Phoenix Oath cannot stack")
	phoenix.second_wind = false
	phoenix.second_wind_used = true
	check(not ids(Catalog.eligible(25, phoenix)).has("phoenix_oath"), style + " a consumed Phoenix Oath cannot be bought again")
	var broken := baseline(style)
	broken.damage = INF
	broken.guard_delay = -900.0
	broken.move_speed = NAN
	broken.guard_reserve = INF
	check(valid_stats(Catalog.normalize_stats(broken)), style + " malformed numeric values normalize into safe finite bounds")
	# Hundreds of deliberate upgrades must stay finite without stale class caps.
	stats = baseline(style)
	for level: int in range(2, 301):
		stats.level = level
		stats = Catalog.apply_upgrade(["sharper_steel", "heart_of_a_knight", "stronger_guard"][(level - 2) % 3], stats)
	check(valid_stats(stats) and float(stats.damage) > float(profile.damage_cap) and float(stats.max_health) > float(profile.health_cap) and float(stats.guard_capacity) > float(profile.guard_cap), style + " long-run permanent progression safely exceeds all legacy caps")


func _test_rarity() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 997001
	var cards := Catalog.eligible(50, baseline("sword", 50))
	var legendary := 0
	var rare := 0
	for _index: int in range(10000):
		var selected := Catalog._pick_by_rarity(rng, 50, cards)
		legendary += 1 if str(selected.rarity) == "legendary" else 0
		rare += 1 if str(selected.rarity) == "rare" else 0
	check(legendary >= 80 and legendary <= 160, "seeded 10000-slot sample keeps legendary offers extremely rare")
	check(rare >= 2400 and rare <= 2800, "rare category chance is independent of its large card count")
