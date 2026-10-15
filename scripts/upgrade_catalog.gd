extends RefCounted
## Permanent run upgrades share the existing class caps. Offers only contain
## upgrades that still change a stat; treasure keeps very long runs rewarding.

const ClassProfiles = preload("res://scripts/class_profiles.gd")
const DASH_BASE := 1.45
const DASH_FLOOR := 0.90
const MOVE_CAP_MULTIPLIER := 1.30
const EPSILON := 0.00001
const REGULAR_IDS := ["sharper_steel", "quicker_slices", "longer_reach", "heart_of_a_knight", "stronger_guard", "fleet_footed", "quickstep", "keen_edge"]
const DEFINITIONS := {
	"sharper_steel": {"id": "sharper_steel", "name": "SHARPER STEEL", "description": "+14% slash damage", "min_level": 2, "icon": "sword"},
	"quicker_slices": {"id": "quicker_slices", "name": "QUICKER SLICES", "description": "6% shorter time between slashes", "min_level": 2, "icon": "sword"},
	"longer_reach": {"id": "longer_reach", "name": "LONGER REACH", "description": "+5 slash reach", "min_level": 2, "icon": "sword"},
	"heart_of_a_knight": {"id": "heart_of_a_knight", "name": "HEART OF A KNIGHT", "description": "+8 maximum health and heal 18", "min_level": 2, "icon": "shield"},
	"stronger_guard": {"id": "stronger_guard", "name": "STRONGER GUARD", "description": "+8 guard capacity and restore 30 guard", "min_level": 2, "icon": "shield"},
	"fleet_footed": {"id": "fleet_footed", "name": "FLEET FOOTED", "description": "+6% base movement speed", "min_level": 3, "icon": "star"},
	"quickstep": {"id": "quickstep", "name": "QUICKSTEP", "description": "Dash recharges 0.10 seconds sooner", "min_level": 5, "icon": "star"},
	"keen_edge": {"id": "keen_edge", "name": "KEEN EDGE", "description": "+20% slash damage and +3 reach", "min_level": 10, "max_picks": 3, "rarity": "rare", "icon": "sword"},
	"field_rations": {"id": "field_rations", "name": "FIELD RATIONS", "description": "Fully restore health and guard", "min_level": 1, "icon": "shield"},
	"royal_purse": {"id": "royal_purse", "name": "ROYAL PURSE", "description": "+500 score, guaranteed", "min_level": 1, "icon": "star"},
	"lucky_purse": {"id": "lucky_purse", "name": "LUCKY PURSE", "description": "+100 to +1,000 score. Feeling lucky?", "min_level": 1, "icon": "star"},
}


static func get_upgrade(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {}).duplicate(true)


static func _profile(stats: Dictionary) -> Dictionary:
	if stats.get("class_stats") is Dictionary:
		return stats.class_stats
	return ClassProfiles.get_profile(str(stats.get("style", "sword")))


static func _value(stats: Dictionary, key: String, fallback: float) -> float:
	return float(stats.get(key, fallback))


static func eligible(level: int, stats: Dictionary, choice_counts: Dictionary = {}) -> Array:
	var profile := _profile(stats)
	var damage := _value(stats, "damage", profile.damage)
	var interval := _value(stats, "attack_interval", profile.attack_interval)
	var reach := _value(stats, "attack_range", profile.attack_range)
	var max_health := _value(stats, "max_health", profile.health)
	var guard := _value(stats, "guard_capacity", profile.guard_capacity)
	var move := _value(stats, "move_speed", profile.move_speed)
	var dash := _value(stats, "dash_recharge", DASH_BASE)
	var available: Array = []
	for id in REGULAR_IDS:
		var card: Dictionary = get_upgrade(id)
		if level < int(card.min_level):
			continue
		if card.has("max_picks") and int(choice_counts.get(id, 0)) >= int(card.max_picks):
			continue
		var benefits := false
		match id:
			"sharper_steel": benefits = damage < float(profile.damage_cap) - EPSILON
			"quicker_slices": benefits = interval > float(profile.attack_floor) + EPSILON
			"longer_reach": benefits = reach < float(profile.range_cap) - EPSILON
			"heart_of_a_knight": benefits = max_health < float(profile.health_cap) - EPSILON
			"stronger_guard": benefits = guard < float(profile.guard_cap) - EPSILON
			"fleet_footed": benefits = move < float(profile.move_speed) * MOVE_CAP_MULTIPLIER - EPSILON
			"quickstep": benefits = dash > DASH_FLOOR + EPSILON
			"keen_edge": benefits = damage < float(profile.damage_cap) - EPSILON and reach < float(profile.range_cap) - EPSILON
		if benefits:
			available.append(_describe(card, stats))
	return available


static func _fallbacks(stats: Dictionary) -> Array:
	var profile := _profile(stats)
	var max_health := _value(stats, "max_health", profile.health)
	var guard_capacity := _value(stats, "guard_capacity", profile.guard_capacity)
	if _value(stats, "health", max_health) < max_health - EPSILON or _value(stats, "guard_reserve", guard_capacity) < guard_capacity - EPSILON:
		return [get_upgrade("field_rations"), get_upgrade("royal_purse")]
	return [get_upgrade("royal_purse"), get_upgrade("lucky_purse")]


static func roll_offers(rng: RandomNumberGenerator, level: int, stats: Dictionary, choice_counts: Dictionary = {}) -> Array:
	var available: Array = eligible(level, stats, choice_counts)
	var offers: Array = []
	if available.size() >= 2:
		for _slot in range(2):
			var index := rng.randi_range(0, available.size() - 1)
			offers.append(available[index])
			available.remove_at(index)
	else:
		# Always retain the last uncapped stat rather than hiding it behind treasure.
		offers = available
		var backups := _fallbacks(stats)
		while offers.size() < 2:
			var index := rng.randi_range(0, backups.size() - 1)
			offers.append(backups[index])
			backups.remove_at(index)
	if rng.randi_range(0, 1) == 1:
		offers.reverse()
	return offers


static func offer(rng: RandomNumberGenerator, level: int, stats: Dictionary, choice_counts: Dictionary = {}) -> Array:
	return roll_offers(rng, level, stats, choice_counts)


static func _describe(card: Dictionary, stats: Dictionary) -> Dictionary:
	var updated: Dictionary = apply_upgrade(str(card.id), stats)
	var profile := _profile(stats)
	match str(card.id):
		"sharper_steel":
			var before := _value(stats, "damage", profile.damage)
			card.description = "+%s%% slash damage\n%s → %s damage" % [_number((float(updated.damage) / before - 1.0) * 100.0), _number(before), _number(updated.damage)]
		"quicker_slices":
			card.description = "Faster automatic slashes\n%.2fs → %.2fs between hits" % [_value(stats, "attack_interval", profile.attack_interval), float(updated.attack_interval)]
		"longer_reach": card.description = "+%s slash reach\n%s → %s reach" % [_number(float(updated.attack_range) - _value(stats, "attack_range", profile.attack_range)), _number(_value(stats, "attack_range", profile.attack_range)), _number(updated.attack_range)]
		"heart_of_a_knight": card.description = "+%s maximum health\nHeal up to 18 health" % _number(float(updated.max_health) - _value(stats, "max_health", profile.health))
		"stronger_guard": card.description = "+%s guard capacity\nRestore up to 30 guard" % _number(float(updated.guard_capacity) - _value(stats, "guard_capacity", profile.guard_capacity))
		"fleet_footed": card.description = "+%s%% base movement speed\n%s → %s speed" % [_number((float(updated.move_speed) - _value(stats, "move_speed", profile.move_speed)) / float(profile.move_speed) * 100.0), _number(_value(stats, "move_speed", profile.move_speed)), _number(updated.move_speed)]
		"quickstep": card.description = "Dash recharges sooner\n%.2fs → %.2fs" % [_value(stats, "dash_recharge", DASH_BASE), float(updated.dash_recharge)]
		"keen_edge": card.description = "+%s%% damage and +%s reach\nRARE · level 10+" % [_number((float(updated.damage) / _value(stats, "damage", profile.damage) - 1.0) * 100.0), _number(float(updated.attack_range) - _value(stats, "attack_range", profile.attack_range))]
	return card


static func _number(value: float) -> String:
	return str(int(roundf(value))) if absf(value - roundf(value)) < 0.05 else "%.1f" % value


static func apply_upgrade(id: String, stats: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var result: Dictionary = stats.duplicate(true)
	var profile := _profile(stats)
	match id:
		"sharper_steel": result.damage = minf(float(profile.damage_cap), _value(stats, "damage", profile.damage) * 1.14)
		"quicker_slices": result.attack_interval = maxf(float(profile.attack_floor), _value(stats, "attack_interval", profile.attack_interval) * 0.94)
		"longer_reach": result.attack_range = minf(float(profile.range_cap), _value(stats, "attack_range", profile.attack_range) + 5.0)
		"heart_of_a_knight":
			result.max_health = minf(float(profile.health_cap), _value(stats, "max_health", profile.health) + 8.0)
			result.health = minf(result.max_health, _value(stats, "health", profile.health) + 18.0)
		"stronger_guard":
			result.guard_capacity = minf(float(profile.guard_cap), _value(stats, "guard_capacity", profile.guard_capacity) + 8.0)
			result.guard_reserve = minf(result.guard_capacity, _value(stats, "guard_reserve", profile.guard_capacity) + 30.0)
		"fleet_footed": result.move_speed = minf(float(profile.move_speed) * MOVE_CAP_MULTIPLIER, _value(stats, "move_speed", profile.move_speed) + float(profile.move_speed) * 0.06)
		"quickstep":
			result.dash_recharge = maxf(DASH_FLOOR, _value(stats, "dash_recharge", DASH_BASE) - 0.10)
			if result.has("dash_cooldown"):
				result.dash_cooldown = minf(float(result.dash_cooldown), result.dash_recharge)
		"keen_edge":
			result.damage = minf(float(profile.damage_cap), _value(stats, "damage", profile.damage) * 1.20)
			result.attack_range = minf(float(profile.range_cap), _value(stats, "attack_range", profile.attack_range) + 3.0)
		"field_rations":
			result.health = _value(stats, "max_health", profile.health)
			result.guard_reserve = _value(stats, "guard_capacity", profile.guard_capacity)
		"royal_purse": result.score = int(stats.get("score", 0)) + 500
		"lucky_purse":
			var random_source: RandomNumberGenerator = rng
			if random_source == null:
				random_source = RandomNumberGenerator.new()
				random_source.randomize()
			result.score = int(stats.get("score", 0)) + random_source.randi_range(100, 1000)
	return result
