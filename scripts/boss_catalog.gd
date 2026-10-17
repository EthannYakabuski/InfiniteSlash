extends RefCounted
## Stable boss identities, separate from encounter difficulty and monster roster order.
## Selection consumes only the run RNG, so Daily seeds and resumed runs stay repeatable.

const PHASE_TWO_SECONDS := 180.0
const PHASE_THREE_SECONDS := 420.0
const BOSSES: Array[Dictionary] = [
	{"id": "tinpot_tyrant", "name": "Tinpot Tyrant", "monster_id": "original_tinpot", "tier": 1, "rare": false, "pattern": "fan", "health_multiplier": 0.92, "damage_multiplier": 0.85, "speed_multiplier": 0.92, "cooldown_multiplier": 1.08},
	{"id": "moss_baron", "name": "Moss Baron", "monster_id": "moss_muzzle", "tier": 1, "rare": false, "pattern": "ring", "health_multiplier": 1.05, "damage_multiplier": 0.90, "speed_multiplier": 0.85, "cooldown_multiplier": 1.10},
	{"id": "ember_earl", "name": "Ember Earl", "monster_id": "ember_earl", "tier": 1, "rare": false, "pattern": "charge", "health_multiplier": 0.95, "damage_multiplier": 0.92, "speed_multiplier": 1.10, "cooldown_multiplier": 1.04},
	{"id": "moonmallow_majesty", "name": "Moonmallow Majesty", "monster_id": "moon_mallow", "tier": 1, "rare": true, "pattern": "spiral", "health_multiplier": 1.08, "damage_multiplier": 0.94, "speed_multiplier": 1.00, "cooldown_multiplier": 1.06},
	{"id": "thistle_regent", "name": "Thistle Regent", "monster_id": "thistle_totem", "tier": 2, "rare": false, "pattern": "ring", "health_multiplier": 1.10, "damage_multiplier": 1.00, "speed_multiplier": 0.95, "cooldown_multiplier": 1.00},
	{"id": "azure_archduke", "name": "Azure Archduke", "monster_id": "azure_baron", "tier": 2, "rare": false, "pattern": "spiral", "health_multiplier": 1.02, "damage_multiplier": 1.00, "speed_multiplier": 1.07, "cooldown_multiplier": 0.97},
	{"id": "acorn_king", "name": "Acorn King", "monster_id": "acorn_king", "tier": 2, "rare": false, "pattern": "charge", "health_multiplier": 1.08, "damage_multiplier": 1.02, "speed_multiplier": 1.03, "cooldown_multiplier": 1.00},
	{"id": "gilded_chancellor", "name": "Gilded Chancellor", "monster_id": "gilded_goggle", "tier": 2, "rare": true, "pattern": "fan", "health_multiplier": 1.15, "damage_multiplier": 1.04, "speed_multiplier": 1.00, "cooldown_multiplier": 0.98},
	{"id": "violet_sovereign", "name": "Violet Sovereign", "monster_id": "violet_warden", "tier": 3, "rare": false, "pattern": "ring", "health_multiplier": 1.20, "damage_multiplier": 1.08, "speed_multiplier": 1.03, "cooldown_multiplier": 0.94},
	{"id": "crimson_duke", "name": "Crimson Duke", "monster_id": "crimson_duke", "tier": 3, "rare": false, "pattern": "charge", "health_multiplier": 1.14, "damage_multiplier": 1.10, "speed_multiplier": 1.12, "cooldown_multiplier": 0.96},
	{"id": "ochre_oracle", "name": "Ochre Oracle", "monster_id": "ochre_oracle", "tier": 3, "rare": false, "pattern": "spiral", "health_multiplier": 1.17, "damage_multiplier": 1.08, "speed_multiplier": 1.00, "cooldown_multiplier": 0.92},
	{"id": "lime_imperator", "name": "Lime Imperator", "monster_id": "lime_royal", "tier": 3, "rare": true, "pattern": "fan", "health_multiplier": 1.24, "damage_multiplier": 1.12, "speed_multiplier": 1.05, "cooldown_multiplier": 0.94}
]

static func all() -> Array[Dictionary]:
	return BOSSES.duplicate(true)

static func ids() -> Array[String]:
	var result: Array[String] = []
	for definition: Dictionary in BOSSES:
		result.append(definition.id)
	return result

static func by_id(id: String) -> Dictionary:
	for definition: Dictionary in BOSSES:
		if definition.id == id:
			return definition.duplicate(true)
	return {}

static func is_rare(id: String) -> bool:
	return bool(by_id(id).get("rare", false))

static func phase(elapsed: float) -> int:
	if not is_finite(elapsed) or elapsed < PHASE_TWO_SECONDS:
		return 1
	return 2 if elapsed < PHASE_THREE_SECONDS else 3

## The current tier dominates each phase. All other tiers remain possible;
## early visitors use the encounter's base stats, rather than late-run health.
static func tier_weights(elapsed: float) -> Array[int]:
	match phase(elapsed):
		1: return [88, 10, 2]
		2: return [12, 78, 10]
		_: return [8, 16, 76]

static func level_tier_weights(level: int) -> Array[int]:
	if level < 20: return [88, 10, 2]
	if level < 50: return [10, 76, 14]
	if level < 80: return [3, 20, 77]
	return [1, 9, 90]

static func choose(rng: RandomNumberGenerator, elapsed: float, last_id: String = "", level: int = -1) -> Dictionary:
	# Optional level keeps old saved/debug callers compatible; live encounters
	# follow the player's stage rather than simply waiting out the clock.
	var weights := level_tier_weights(level) if level >= 1 else tier_weights(elapsed)
	var ticket := rng.randi_range(1, 100)
	var tier := 1
	for index: int in range(weights.size()):
		ticket -= weights[index]
		if ticket <= 0:
			tier = index + 1
			break
	var eligible: Array[Dictionary] = []
	var total := 0
	for definition: Dictionary in BOSSES:
		if int(definition.tier) == tier and definition.id != last_id:
			eligible.append(definition)
			total += 9 if definition.rare else 28
	ticket = rng.randi_range(1, total)
	for definition: Dictionary in eligible:
		ticket -= 9 if definition.rare else 28
		if ticket <= 0:
			return definition.duplicate(true)
	return eligible.back().duplicate(true)
