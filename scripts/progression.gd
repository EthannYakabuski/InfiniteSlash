extends RefCounted
## Level is the authoritative difficulty clock. All multipliers are bounded for
## malformed saves, but they keep rising throughout the supported level range.

const MAX_LEVEL := 1000


static func bounded_level(level: int) -> int:
	return clampi(level, 1, MAX_LEVEL)


static func xp_goal(current_level: int) -> int:
	# The goal belongs to the level currently shown on the HUD: collecting it
	# advances the knight to current_level + 1. Keep the original integer goal
	# before applying the requested band increase, rounding up fractional XP.
	var level := bounded_level(current_level)
	var original := 8 if level == 1 else int(8.0 + pow(float(level), 1.28) * 3.0)
	var multiplier := 1.25 if level <= 20 else 1.5 if level <= 40 else 2.0
	return int(ceil(float(original) * multiplier))


static func stage(level: int) -> int:
	if level < 30:
		return 1
	if level < 50:
		return 2
	return 3 if level < 80 else 4


static func stage_name(level: int) -> String:
	match stage(level):
		1: return "MEADOW MAYHEM"
		2: return "THE WAR HOST"
		3: return "CROWNFALL KEEP"
		_: return "THE IMPOSSIBLE CROWN"


static func enemy_scaling(current_level: int) -> Dictionary:
	var level := bounded_level(current_level)
	var decade := int((level - 1) / 10)
	var within_decade := float((level - 1) % 10)
	var late := level >= 50
	var middle := level >= 30
	# Unlike the player's base-stat additive upgrades, enemy HP and damage
	# compound every ten levels. The stage gates add deliberate pressure spikes.
	var health_stage := 5.5 if late else 2.4 if middle else 1.0
	var damage_stage := 2.65 if late else 1.65 if middle else 1.0
	return {
		"health": minf(10000000.0, pow(1.62, minf(34.0, decade)) * health_stage * (1.0 + within_decade * 0.025)),
		"damage": minf(100000.0, pow(1.38, minf(34.0, decade)) * damage_stage * (1.0 + within_decade * 0.012)),
		"speed": minf(2.70, 1.0 + decade * 0.075 + (0.48 if late else 0.24 if middle else 0.0)),
		"projectile_speed": minf(2.15, 1.0 + decade * 0.055 + (0.25 if late else 0.12 if middle else 0.0)),
		"cooldown": maxf(0.34, 1.0 - decade * 0.040 - (0.18 if late else 0.09 if middle else 0.0)),
		"volley_bonus": mini(12, int(decade / 2) + (4 if late else 2 if middle else 0)),
		"aggression": minf(3.0, 1.0 + decade * 0.12 + (0.65 if late else 0.30 if middle else 0.0)),
	}


static func boss_scaling(current_level: int) -> Dictionary:
	var level := bounded_level(current_level)
	var result := enemy_scaling(level)
	# Middle bosses need sustained engagements; late bosses combine that staying
	# power with faster attacks. Identity multipliers are applied by the caller.
	result.health = minf(30000000.0, float(result.health) * (4.8 if level >= 80 else 3.6 if level >= 50 else 2.6 if level >= 30 else 1.9 if level >= 20 else 1.0))
	result.speed = minf(3.0, float(result.speed) * (1.30 if level >= 50 else 1.18 if level >= 20 else 1.0))
	result.cooldown = maxf(0.25, float(result.cooldown) * (0.70 if level >= 50 else 0.82 if level >= 20 else 1.0))
	result.elemental = level >= 20
	return result
