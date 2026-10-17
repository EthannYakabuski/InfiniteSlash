extends RefCounted
## Rarity is rolled before card selection, so adding tradeoffs does not dilute
## legendary odds. Additive base-stat gains let enemy decade scaling outpace
## permanent growth without exhausting a build's useful options at level 50.

const ClassProfiles = preload("res://scripts/class_profiles.gd")
const DASH_BASE := 1.45
const DASH_FLOOR := 0.65
const DASH_CEILING := 2.50
const MOVE_CAP_MULTIPLIER := 1.75
const EPSILON := 0.00001
const SAFETY_MAX := 1000000000.0
const LEGENDARY_CHANCE := 0.012
const CORE_STATS := ["damage", "attack_speed", "reach", "max_health", "guard_capacity", "move_speed", "guard_regen", "guard_delay", "dash_recharge"]
const STAT_KEYS := {"damage": "damage", "attack_speed": "attack_interval", "reach": "attack_range", "max_health": "max_health", "guard_capacity": "guard_capacity", "move_speed": "move_speed", "guard_regen": "guard_regen", "guard_delay": "guard_delay", "dash_recharge": "dash_recharge"}
const STAT_LABELS := {"damage": "Damage", "attack_speed": "Slash interval", "reach": "Reach", "max_health": "Max health", "guard_capacity": "Guard", "move_speed": "Speed", "guard_regen": "Guard regen/s", "guard_delay": "Guard delay", "dash_recharge": "Dash recharge"}
const REGULAR_IDS := ["sharper_steel", "quicker_slices", "longer_reach", "heart_of_a_knight", "stronger_guard", "fleet_footed", "quickstep", "guard_mending", "swift_recovery", "keen_edge"]
const DEFINITIONS := {
	"sharper_steel": {"id": "sharper_steel", "name": "SHARPER STEEL", "description": "Permanently increase slash damage", "min_level": 2, "icon": "sword", "kind": "permanent", "rarity": "common"},
	"quicker_slices": {"id": "quicker_slices", "name": "QUICKER SLICES", "description": "6% shorter slash interval", "min_level": 2, "icon": "sword", "kind": "permanent", "rarity": "common"},
	"longer_reach": {"id": "longer_reach", "name": "LONGER REACH", "description": "+5 slash reach", "min_level": 2, "icon": "sword", "kind": "permanent", "rarity": "common"},
	"heart_of_a_knight": {"id": "heart_of_a_knight", "name": "HEART OF A KNIGHT", "description": "More maximum health and immediate healing", "min_level": 2, "icon": "shield", "kind": "permanent", "rarity": "common"},
	"stronger_guard": {"id": "stronger_guard", "name": "STRONGER GUARD", "description": "More guard capacity and immediate reserve", "min_level": 2, "icon": "shield", "kind": "permanent", "rarity": "common"},
	"fleet_footed": {"id": "fleet_footed", "name": "FLEET FOOTED", "description": "+6% base movement speed", "min_level": 3, "icon": "star", "kind": "permanent", "rarity": "common"},
	"quickstep": {"id": "quickstep", "name": "QUICKSTEP", "description": "Dash recharges 0.10 seconds sooner", "min_level": 5, "icon": "star", "kind": "permanent", "rarity": "common"},
	"guard_mending": {"id": "guard_mending", "name": "GUARD MENDING", "description": "Guard regenerates faster", "min_level": 3, "icon": "shield", "kind": "permanent", "rarity": "common"},
	"swift_recovery": {"id": "swift_recovery", "name": "SWIFT RECOVERY", "description": "Guard starts regenerating sooner", "min_level": 5, "icon": "shield", "kind": "permanent", "rarity": "common"},
	"keen_edge": {"id": "keen_edge", "name": "KEEN EDGE", "description": "More damage and reach", "min_level": 10, "max_picks": 3, "rarity": "rare", "icon": "sword", "kind": "permanent"},
	"bulwark": {"id": "bulwark", "name": "BULWARK", "description": "A larger, faster-recovering guard", "min_level": 10, "rarity": "rare", "icon": "shield", "kind": "permanent"},
	"wind_dancer": {"id": "wind_dancer", "name": "WIND DANCER", "description": "More speed and quicker dashes", "min_level": 10, "rarity": "rare", "icon": "star", "kind": "permanent"},
	"living_oak": {"id": "living_oak", "name": "LIVING OAK", "description": "More health and quicker guard recovery", "min_level": 10, "rarity": "rare", "icon": "shield", "kind": "permanent"},
	"vampire_steel": {"id": "vampire_steel", "name": "VAMPIRE STEEL", "description": "+2% lifesteal from slash damage", "min_level": 20, "max_picks": 5, "rarity": "rare", "icon": "sword", "kind": "permanent"},
	"thornmail": {"id": "thornmail", "name": "THORNMAIL", "description": "+35% reflected contact damage", "min_level": 20, "max_picks": 6, "rarity": "rare", "icon": "shield", "kind": "permanent"},
	"storm_lungs": {"id": "storm_lungs", "name": "STORM LUNGS", "description": "Much faster guard regeneration", "min_level": 20, "rarity": "rare", "icon": "shield", "kind": "permanent"},
	"titan_heart": {"id": "titan_heart", "name": "TITAN HEART", "description": "Large health and guard reserves", "min_level": 30, "rarity": "rare", "icon": "shield", "kind": "permanent"},
	"headhunter": {"id": "headhunter", "name": "HEADHUNTER", "description": "Slashes execute weakened normal enemies", "min_level": 30, "max_picks": 6, "rarity": "rare", "icon": "sword", "kind": "permanent"},
	"battle_cadence": {"id": "battle_cadence", "name": "BATTLE CADENCE", "description": "Faster, harder automatic slashes", "min_level": 30, "rarity": "rare", "icon": "sword", "kind": "permanent"},
	"abyssal_steel": {"id": "abyssal_steel", "name": "ABYSSAL STEEL", "description": "A major permanent damage boost", "min_level": 50, "rarity": "rare", "icon": "sword", "kind": "permanent"},
	"adamant_vow": {"id": "adamant_vow", "name": "ADAMANT VOW", "description": "A major health and guard boost", "min_level": 50, "rarity": "rare", "icon": "shield", "kind": "permanent"},
	"nightstrider": {"id": "nightstrider", "name": "NIGHTSTRIDER", "description": "More speed and longer combo grace", "min_level": 50, "rarity": "rare", "icon": "star", "kind": "permanent"},
	"phoenix_oath": {"id": "phoenix_oath", "name": "PHOENIX OATH", "description": "Survive one fatal hit this run\nRecover 50% health and full guard", "min_level": 25, "max_picks": 1, "rarity": "legendary", "icon": "shield", "kind": "permanent"},
	"blood_chalice": {"id": "blood_chalice", "name": "BLOOD CHALICE", "description": "+6% slash lifesteal", "min_level": 25, "max_picks": 2, "rarity": "legendary", "icon": "sword", "kind": "permanent"},
	"worldbreaker": {"id": "worldbreaker", "name": "WORLDBREAKER", "description": "Enormous damage and reach boost", "min_level": 25, "rarity": "legendary", "icon": "sword", "kind": "permanent"},
	"everguard": {"id": "everguard", "name": "EVERGUARD", "description": "Enormous guard regeneration boost", "min_level": 25, "rarity": "legendary", "icon": "shield", "kind": "permanent"},
	"hourglass": {"id": "hourglass", "name": "STOLEN HOURGLASS", "description": "Much faster slashes and dashes", "min_level": 25, "rarity": "legendary", "icon": "star", "kind": "permanent"},
	"eternal_encore": {"id": "eternal_encore", "name": "ETERNAL ENCORE", "description": "+1.5 seconds combo grace\nPermanently increase slash damage", "min_level": 25, "rarity": "legendary", "icon": "star", "kind": "permanent"},
	"field_rations": {"id": "field_rations", "name": "FIELD RATIONS", "description": "Fully restore health and guard", "min_level": 2, "icon": "shield", "kind": "recovery", "rarity": "common", "weight": 0.30},
	"royal_purse": {"id": "royal_purse", "name": "ROYAL PURSE", "description": "+10,000 score or more, guaranteed", "min_level": 40, "icon": "star", "kind": "treasure", "rarity": "common", "weight": 0.16},
	"lucky_purse": {"id": "lucky_purse", "name": "LUCKY PURSE", "description": "+5,000 to +30,000 score or more", "min_level": 40, "icon": "star", "kind": "treasure", "rarity": "common", "weight": 0.16},
}

# Row = gained stat, column = sacrificed stat. The diagonal is empty; all
# remaining 9 * 8 ordered pairs have a stable saved ID and a distinct name.
const TRADE_NAMES := [
	["", "HEAVY HANDED", "CLOSE QUARTERS", "GLASS BLADE", "RECKLESS STEEL", "ROOTED FURY", "RUSTED RAGE", "RESTLESS WRATH", "LATE BLOOMING BLADE"],
	["FEATHER BLADE", "", "SHORT FUSE", "FRAGILE FRENZY", "OPEN FLURRY", "ROOTED TEMPEST", "FADING RHYTHM", "DELAYED TEMPO", "DELAYED QUICKCUT"],
	["HOLLOW HALBERD", "PATIENT SPEAR", "", "BRITTLE LANCE", "UNSHIELDED PIKE", "ANCHORED REACH", "WITHERED SHAFT", "SLEEPING SPEAR", "PATIENT PILGRIM"],
	["GENTLE GIANT", "PATIENT HEART", "COMPACT CHAMPION", "", "BARE CHEST", "HEAVY HEART", "MORTAL MENDING", "DROWSY GIANT", "WELL RESTED"],
	["BLUNT BASTION", "PATIENT SENTINEL", "CLOSE COVER", "HOLLOW ARMOR", "", "IRON ANCHOR", "FADING FORTRESS", "SLEEPING BULWARK", "PATIENT BULWARK"],
	["LIGHT TOUCH", "PATIENT RUNNER", "SHORT STRIDE", "PAPER RUNNER", "UNBURDENED", "", "FADING FOOTFALL", "DROWSY DANCER", "LONG STRIDER"],
	["GENTLE MENDER", "PATIENT MENDER", "CLOSE COMFORT", "FRAGILE RENEWAL", "THIN SHELL", "ROOTED RENEWAL", "", "SLEEPING SPRING", "MEASURED MENDING"],
	["SOFT REBOUND", "PATIENT REBOUND", "COMPACT RECOVERY", "BRITTLE REBOUND", "THIN REBOUND", "ANCHORED REBOUND", "SLOW SPRING", "", "QUICK REBOUND"],
	["FEATHER STEP", "PATIENT QUICKSTEP", "CLOSE ESCAPE", "FRAGILE ESCAPE", "OPEN ESCAPE", "ROOTED QUICKSTEP", "FADING QUICKSTEP", "DROWSY QUICKSTEP", ""],
]


static func _profile(stats: Dictionary) -> Dictionary:
	return stats.class_stats if stats.get("class_stats") is Dictionary else ClassProfiles.get_profile(str(stats.get("style", "sword")))


static func _value(stats: Dictionary, key: String, fallback: float) -> float:
	var candidate: Variant = stats.get(key, fallback)
	if not candidate is float and not candidate is int:
		return fallback
	return float(candidate) if is_finite(float(candidate)) else fallback


static func stat_limits(stats: Dictionary) -> Dictionary:
	var profile := _profile(stats)
	var sword := str(stats.get("style", "sword")) != "shield"
	return {"damage": [2.0, SAFETY_MAX], "max_health": [12.0, SAFETY_MAX], "guard_capacity": [6.0, SAFETY_MAX], "attack_interval": [0.14 if sword else 0.27, 3.0], "attack_range": [36.0, 240.0], "move_speed": [120.0, float(profile.move_speed) * MOVE_CAP_MULTIPLIER], "guard_regen": [3.0, 2000.0], "guard_delay": [0.08, 2.0], "dash_recharge": [DASH_FLOOR, DASH_CEILING], "lifesteal": [0.0, 0.10], "thorns": [0.0, 2.0], "execute_threshold": [0.0, 0.18], "combo_grace": [0.0, 3.0]}


static func normalize_stats(stats: Dictionary) -> Dictionary:
	var result: Dictionary = stats.duplicate(true)
	var profile := _profile(stats)
	var defaults := {"damage": float(profile.damage), "max_health": float(profile.health), "guard_capacity": float(profile.guard_capacity), "attack_interval": float(profile.attack_interval), "attack_range": float(profile.attack_range), "move_speed": float(profile.move_speed), "guard_regen": float(profile.guard_regen), "guard_delay": float(profile.get("guard_delay", 0.5)), "dash_recharge": DASH_BASE, "lifesteal": 0.0, "thorns": 0.0, "execute_threshold": 0.0, "combo_grace": 0.0}
	var limits := stat_limits(stats)
	for key: String in defaults:
		result[key] = clampf(_value(stats, key, float(defaults[key])), float(limits[key][0]), float(limits[key][1]))
	result.health = clampf(_value(stats, "health", result.max_health), 0.0, result.max_health)
	result.guard_reserve = clampf(_value(stats, "guard_reserve", result.guard_capacity), 0.0, result.guard_capacity)
	result.second_wind = bool(stats.get("second_wind", false))
	result.second_wind_used = bool(stats.get("second_wind_used", false))
	result.level = clampi(int(_value(stats, "level", 1.0)), 1, 1000)
	if result.has("dash_cooldown"):
		result.dash_cooldown = clampf(_value(stats, "dash_cooldown", 0.0), 0.0, result.dash_recharge)
	return result


static func all_definitions() -> Array:
	var result: Array = []
	for id: String in DEFINITIONS:
		result.append(get_upgrade(id))
	for gain_index: int in range(CORE_STATS.size()):
		for cost_index: int in range(CORE_STATS.size()):
			if gain_index != cost_index:
				result.append(_trade_definition(gain_index, cost_index))
	return result


static func _trade_definition(gain_index: int, cost_index: int) -> Dictionary:
	var gain: String = CORE_STATS[gain_index]
	var cost: String = CORE_STATS[cost_index]
	var gate: int = [5, 10, 20, 30, 50][(gain_index * 3 + cost_index) % 5]
	if gain == "dash_recharge" or cost == "dash_recharge":
		gate = maxi(10, gate)
	return {"id": "trade_%s_for_%s" % [cost, gain], "name": TRADE_NAMES[gain_index][cost_index], "description": "More %s, less %s" % [gain.replace("_", " "), cost.replace("_", " ")], "min_level": gate, "rarity": "rare" if gate >= 20 else "common", "icon": "sword" if gain_index <= 2 else "star" if gain in ["move_speed", "dash_recharge"] else "shield", "kind": "permanent", "weight": 0.30, "gain": gain, "cost": cost, "tradeoff": true}


static func get_upgrade(id: String) -> Dictionary:
	if DEFINITIONS.has(id):
		return DEFINITIONS[id].duplicate(true)
	if id.begins_with("trade_"):
		var parts := id.trim_prefix("trade_").split("_for_")
		if parts.size() == 2:
			var cost_index := CORE_STATS.find(parts[0])
			var gain_index := CORE_STATS.find(parts[1])
			if gain_index >= 0 and cost_index >= 0 and gain_index != cost_index:
				return _trade_definition(gain_index, cost_index)
	return {}


static func _growth(level: int) -> float:
	return 1.0 + 0.015 * float(clampi(level, 1, 1000) - 1)


static func _set_stat(result: Dictionary, key: String, value: float) -> void:
	var limits := stat_limits(result)
	var bounded := clampf(value, float(limits[key][0]), float(limits[key][1]))
	if key == "max_health":
		result.health = bounded * float(result.health) / maxf(1.0, float(result.max_health))
	elif key == "guard_capacity":
		result.guard_reserve = bounded * float(result.guard_reserve) / maxf(1.0, float(result.guard_capacity))
	result[key] = bounded


static func _trade_change(result: Dictionary, stat: String, improve: bool, strength: float) -> void:
	var key: String = STAT_KEYS[stat]
	var profile := _profile(result)
	var growth := _growth(int(result.level))
	var value := float(result[key])
	match stat:
		"damage": value += float(profile.damage) * 0.26 * strength * growth if improve else -value * 0.16
		"attack_speed": value *= 1.0 - 0.14 * strength if improve else 1.12
		"reach": value += 14.0 * strength if improve else -10.0
		"max_health": value += float(profile.health) * 0.24 * strength * growth if improve else -value * 0.16
		"guard_capacity": value += float(profile.guard_capacity) * 0.30 * strength * growth if improve else -value * 0.20
		"move_speed": value += float(profile.move_speed) * 0.18 * strength if improve else -value * 0.10
		"guard_regen": value += float(profile.guard_regen) * 0.40 * strength * growth if improve else -value * 0.20
		"guard_delay": value *= maxf(0.45, 1.0 - 0.28 * strength) if improve else 1.35
		"dash_recharge": value += -0.12 * strength if improve else 0.20
	_set_stat(result, key, value)


static func _is_improved(stat: String, before: Dictionary, after: Dictionary) -> bool:
	var key: String = STAT_KEYS[stat]
	var difference := float(after[key]) - float(before[key])
	return difference < -EPSILON if stat in ["attack_speed", "guard_delay", "dash_recharge"] else difference > EPSILON


static func _benefits(card: Dictionary, before: Dictionary, after: Dictionary) -> bool:
	if card.get("tradeoff", false):
		return _is_improved(card.gain, before, after) and _is_improved(card.cost, after, before)
	match str(card.id):
		"royal_purse", "lucky_purse": return true
		"field_rations": return float(before.health) < float(before.max_health) - EPSILON or float(before.guard_reserve) < float(before.guard_capacity) - EPSILON
		"phoenix_oath": return not bool(before.second_wind) and not bool(before.second_wind_used)
		"keen_edge", "worldbreaker": return float(after.damage) > float(before.damage) + EPSILON and float(after.attack_range) > float(before.attack_range) + EPSILON
		"wind_dancer": return float(after.move_speed) > float(before.move_speed) + EPSILON and float(after.dash_recharge) < float(before.dash_recharge) - EPSILON
	for key: String in ["damage", "attack_interval", "attack_range", "max_health", "guard_capacity", "move_speed", "dash_recharge", "guard_regen", "guard_delay", "lifesteal", "thorns", "execute_threshold", "combo_grace"]:
		if absf(float(after[key]) - float(before[key])) > EPSILON:
			return true
	return false


static func eligible(level: int, stats: Dictionary, choice_counts: Dictionary = {}) -> Array:
	var before: Dictionary = normalize_stats(stats)
	before.level = clampi(level, 1, 1000)
	var result: Array = []
	for card: Dictionary in all_definitions():
		if level < int(card.min_level):
			continue
		if card.has("max_picks") and int(choice_counts.get(str(card.id), 0)) >= int(card.max_picks):
			continue
		var after := apply_upgrade(str(card.id), before)
		if _benefits(card, before, after):
			result.append(_describe(card, before, after))
	return result


static func rarity_chances(level: int) -> Dictionary:
	var rare := 0.26 if level >= 50 else 0.23 if level >= 30 else 0.19 if level >= 20 else 0.16 if level >= 10 else 0.0
	var legendary := LEGENDARY_CHANCE if level >= 25 else 0.0
	return {"common": 1.0 - rare - legendary, "rare": rare, "legendary": legendary}


static func _weighted_pick(rng: RandomNumberGenerator, cards: Array) -> Dictionary:
	var total := 0.0
	for card: Dictionary in cards:
		total += float(card.get("weight", 1.0))
	var ticket := rng.randf() * total
	for card: Dictionary in cards:
		ticket -= float(card.get("weight", 1.0))
		if ticket <= 0.0:
			return card
	return cards.back()


static func _pick_by_rarity(rng: RandomNumberGenerator, level: int, cards: Array) -> Dictionary:
	var chances := rarity_chances(level)
	var ticket := rng.randf()
	var rarity := "legendary" if ticket < float(chances.legendary) else "rare" if ticket < float(chances.legendary) + float(chances.rare) else "common"
	var bucket: Array = []
	for card: Dictionary in cards:
		if str(card.rarity) == rarity:
			bucket.append(card)
	if bucket.is_empty():
		for card: Dictionary in cards:
			if str(card.rarity) == "common":
				bucket.append(card)
	return _weighted_pick(rng, cards if bucket.is_empty() else bucket)


static func roll_offers(rng: RandomNumberGenerator, level: int, stats: Dictionary, choice_counts: Dictionary = {}) -> Array:
	var available := eligible(level, stats, choice_counts)
	var offers: Array = []
	for _slot: int in range(2):
		if available.is_empty():
			break
		var selected := _pick_by_rarity(rng, level, available)
		offers.append(selected)
		available.erase(selected)
	# Treasure/recovery never occupy both slots while a permanent build exists.
	var has_build := false
	for card: Dictionary in offers:
		has_build = has_build or str(card.kind) == "permanent"
	if not has_build:
		var builds: Array = []
		for card: Dictionary in available:
			if str(card.kind) == "permanent":
				builds.append(card)
		if not builds.is_empty():
			offers[offers.size() - 1] = _pick_by_rarity(rng, level, builds)
	# Pathological numeric-safety-limit snapshots still get two distinct buttons.
	for id: String in ["field_rations", "royal_purse", "lucky_purse"]:
		if offers.size() >= 2:
			break
		var duplicate := false
		for card: Dictionary in offers:
			duplicate = duplicate or str(card.id) == id
		if not duplicate:
			offers.append(get_upgrade(id))
	if rng.randi_range(0, 1) == 1:
		offers.reverse()
	return offers


static func offer(rng: RandomNumberGenerator, level: int, stats: Dictionary, choice_counts: Dictionary = {}) -> Array:
	return roll_offers(rng, level, stats, choice_counts)


static func _number(value: float) -> String:
	if absf(value) >= 100000.0:
		return "%.0fk" % (value / 1000.0)
	return str(int(roundf(value))) if absf(value - roundf(value)) < 0.005 else "%.2f" % value


static func _stat_line(stat: String, before: Dictionary, after: Dictionary) -> String:
	var key: String = STAT_KEYS[stat]
	if stat == "attack_speed":
		return "%s Slashes/s %s → %s" % ["↑" if _is_improved(stat, before, after) else "↓", _number(1.0 / float(before[key])), _number(1.0 / float(after[key]))]
	if stat in ["guard_delay", "dash_recharge"]:
		return "%s %s %ss → %ss" % ["↓" if _is_improved(stat, before, after) else "↑", STAT_LABELS[stat], _number(float(before[key])), _number(float(after[key]))]
	return "%s %s %s → %s" % ["↑" if _is_improved(stat, before, after) else "↓", STAT_LABELS[stat], _number(float(before[key])), _number(float(after[key]))]


static func _describe(card: Dictionary, before: Dictionary, after: Dictionary) -> Dictionary:
	if card.get("tradeoff", false):
		card.description = "GAIN · " + _stat_line(card.gain, before, after) + "\nCOST · " + _stat_line(card.cost, before, after)
		return card
	var changed: Array[String] = []
	for stat: String in CORE_STATS:
		if _is_improved(stat, before, after):
			changed.append(_stat_line(stat, before, after))
	for key: String in ["lifesteal", "thorns", "execute_threshold"]:
		if float(after[key]) > float(before[key]) + EPSILON:
			changed.append("%s %s%% → %s%%" % [key.replace("_", " ").capitalize(), _number(float(before[key]) * 100.0), _number(float(after[key]) * 100.0)])
	if float(after.combo_grace) > float(before.combo_grace) + EPSILON:
		changed.append("Combo grace +%ss" % _number(float(after.combo_grace) - float(before.combo_grace)))
	if str(card.id) == "heart_of_a_knight":
		changed.append("Heal up to %s health" % _number(18.0 * _growth(int(before.level))))
	elif str(card.id) == "stronger_guard":
		changed.append("Restore up to %s guard" % _number(30.0 * _growth(int(before.level))))
	elif str(card.id) == "royal_purse":
		changed.append("+%s score, guaranteed" % _number(float(_purse_value(int(before.level)))))
	elif str(card.id) == "lucky_purse":
		var bonus := maxi(0, int(before.level) - 40) * 500
		changed.append("+%s to +%s score" % [_number(5000.0 + bonus), _number(30000.0 + bonus)])
	if not changed.is_empty():
		card.description = "\n".join(changed)
	return card


static func _purse_value(level: int) -> int:
	return 10000 + maxi(0, level - 40) * 250


static func apply_upgrade(id: String, stats: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var card := get_upgrade(id)
	if card.is_empty():
		return stats.duplicate(true)
	var result := normalize_stats(stats)
	var profile := _profile(result)
	var growth := _growth(int(result.level))
	if card.get("tradeoff", false):
		var strength := 1.60 if int(card.min_level) >= 50 else 1.30 if int(card.min_level) >= 30 else 1.15 if int(card.min_level) >= 20 else 1.0
		_trade_change(result, card.gain, true, strength)
		_trade_change(result, card.cost, false, strength)
		return normalize_stats(result)
	match id:
		"sharper_steel": result.damage += float(profile.damage) * 0.14 * growth
		"quicker_slices": result.attack_interval *= 0.94
		"longer_reach": result.attack_range += 5.0
		"heart_of_a_knight":
			result.max_health += 8.0 * growth
			result.health = minf(result.max_health, float(result.health) + 18.0 * growth)
		"stronger_guard":
			result.guard_capacity += 8.0 * growth
			result.guard_reserve = minf(result.guard_capacity, float(result.guard_reserve) + 30.0 * growth)
		"fleet_footed": result.move_speed += float(profile.move_speed) * 0.06
		"quickstep": result.dash_recharge -= 0.10
		"guard_mending": result.guard_regen += float(profile.guard_regen) * 0.20 * growth
		"swift_recovery": result.guard_delay *= 0.88
		"keen_edge":
			result.damage += float(profile.damage) * 0.22 * growth
			result.attack_range += 3.0
		"bulwark":
			result.guard_capacity += float(profile.guard_capacity) * 0.24 * growth
			result.guard_regen += float(profile.guard_regen) * 0.25 * growth
		"wind_dancer":
			result.move_speed += float(profile.move_speed) * 0.10
			result.dash_recharge -= 0.12
		"living_oak":
			result.max_health += float(profile.health) * 0.18 * growth
			result.health = minf(result.max_health, float(result.health) + 30.0 * growth)
			result.guard_delay *= 0.85
		"vampire_steel": result.lifesteal += 0.02
		"thornmail": result.thorns += 0.35
		"storm_lungs":
			result.guard_regen += float(profile.guard_regen) * 0.45 * growth
			result.guard_delay *= 0.85
		"titan_heart":
			result.max_health += float(profile.health) * 0.35 * growth
			result.guard_capacity += float(profile.guard_capacity) * 0.35 * growth
		"headhunter": result.execute_threshold += 0.03
		"battle_cadence":
			result.attack_interval *= 0.86
			result.damage += float(profile.damage) * 0.16 * growth
		"abyssal_steel": result.damage += float(profile.damage) * 0.85 * growth
		"adamant_vow":
			result.max_health += float(profile.health) * 0.65 * growth
			result.guard_capacity += float(profile.guard_capacity) * 0.65 * growth
		"nightstrider":
			result.move_speed += float(profile.move_speed) * 0.15
			result.combo_grace += 0.50
			result.guard_delay *= 0.80
		"phoenix_oath": result.second_wind = true
		"blood_chalice": result.lifesteal += 0.06
		"worldbreaker":
			result.damage += float(profile.damage) * growth
			result.attack_range += 20.0
		"everguard":
			result.guard_regen += float(profile.guard_regen) * 1.2 * growth
			result.guard_delay *= 0.65
		"hourglass":
			result.attack_interval *= 0.75
			result.dash_recharge -= 0.25
		"eternal_encore":
			result.combo_grace += 1.5
			result.damage += float(profile.damage) * 0.50 * growth
		"field_rations":
			result.health = result.max_health
			result.guard_reserve = result.guard_capacity
		"royal_purse": result.score = int(_value(stats, "score", 0.0)) + _purse_value(int(result.level))
		"lucky_purse":
			var random_source := rng
			if random_source == null:
				random_source = RandomNumberGenerator.new()
				random_source.randomize()
			var bonus := maxi(0, int(result.level) - 40) * 500
			result.score = int(_value(stats, "score", 0.0)) + random_source.randi_range(5000 + bonus, 30000 + bonus)
	return normalize_stats(result)
