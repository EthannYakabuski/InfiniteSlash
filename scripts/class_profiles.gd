extends RefCounted
## Shared balance source for combat and the one-tap class cards.

const BALANCE_VERSION := 3
const PROFILES := {
	"sword": {
		"health": 80.0, "damage": 32.0, "attack_interval": 0.36,
		"move_speed": 290.0, "attack_range": 92.0, "guard_capacity": 65.0,
		"guard_drain": 32.0, "guard_regen": 22.0, "block_cost": 12.0,
		"parry_window": 0.12, "guard_damage_multiplier": 0.75,
		"guard_attack_interval": 0.65, "health_cap": 160.0, "damage_cap": 150.0,
		"attack_floor": 0.22, "range_cap": 124.0, "guard_cap": 110.0,
	},
	"shield": {
		"health": 170.0, "damage": 24.0, "attack_interval": 0.60,
		"move_speed": 220.0, "attack_range": 80.0, "guard_capacity": 165.0,
		"guard_drain": 22.0, "guard_regen": 28.0, "block_cost": 5.0,
		"parry_window": 0.32, "guard_damage_multiplier": 0.20,
		"guard_attack_interval": 0.68, "health_cap": 300.0, "damage_cap": 95.0,
		"attack_floor": 0.40, "range_cap": 108.0, "guard_cap": 250.0,
	},
}


static func get_profile(style: String) -> Dictionary:
	return PROFILES.get(style, PROFILES.sword)


static func at_level(style: String, level: int) -> Dictionary:
	# Reconstruct automatic upgrades when migrating pre-class-balance runs.
	# This deliberately avoids combat rewards, sounds and upgrade notifications.
	var stats: Dictionary = get_profile(style).duplicate()
	for next_level in range(2, clampi(level, 1, 100) + 1):
		match (next_level - 2) % 5:
			0: stats.damage = minf(stats.damage_cap, stats.damage * 1.14)
			1: stats.attack_interval = maxf(stats.attack_floor, stats.attack_interval * 0.94)
			2: stats.attack_range = minf(stats.range_cap, stats.attack_range + 5.0)
			3: stats.health = minf(stats.health_cap, stats.health + 8.0)
			4: stats.guard_capacity = minf(stats.guard_cap, stats.guard_capacity + 8.0)
	return stats
