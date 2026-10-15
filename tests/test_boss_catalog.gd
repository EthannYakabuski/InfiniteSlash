extends SceneTree
## Pure deterministic boss selection and content checks; no combat simulation needed.

const Catalog = preload("res://scripts/boss_catalog.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("BOSS CATALOG: " + message)

func _run() -> void:
	var definitions := Catalog.all()
	_check(definitions.size() == 12 and Catalog.ids().size() == 12, "12 stable boss identities")
	var roster: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	var monster_ids: Array[String] = ["original_tinpot"]
	for monster: Dictionary in roster:
		monster_ids.append(monster.id)
	var unique_ids: Dictionary = {}
	var tier_counts := [0, 0, 0]
	var rare_counts := [0, 0, 0]
	var invalid := false
	for definition: Dictionary in definitions:
		invalid = invalid or unique_ids.has(definition.id) or definition.monster_id not in monster_ids \
			or definition.pattern not in ["ring", "fan", "charge", "spiral"] \
			or definition.name.length() > 25 or definition.name.is_empty() \
			or definition.health_multiplier < 0.85 or definition.health_multiplier > 1.25 \
			or definition.damage_multiplier < 0.8 or definition.damage_multiplier > 1.15
		unique_ids[definition.id] = true
		tier_counts[int(definition.tier) - 1] += 1
		if definition.rare:
			rare_counts[int(definition.tier) - 1] += 1
	_check(not invalid, "all bosses have distinct stable IDs, existing visuals, supported patterns and sane multipliers")
	_check(tier_counts == [4, 4, 4] and rare_counts == [1, 1, 1], "three tiers each contain three common bosses and one rare boss")
	_check(Catalog.by_id("missing").is_empty() and not Catalog.is_rare("missing"), "unknown identities have no definition or rarity")
	_check(Catalog.phase(0) == 1 and Catalog.phase(179.999) == 1 and Catalog.phase(180) == 2 \
		and Catalog.phase(419.999) == 2 and Catalog.phase(420) == 3, "tier phases change exactly at three and seven minutes")
	_check(Catalog.phase(NAN) == 1 and Catalog.phase(-100) == 1, "invalid or negative elapsed time stays in safe early phase")
	definitions[0].name = "mutated"
	var copy := Catalog.by_id("tinpot_tyrant")
	copy.name = "mutated twice"
	_check(Catalog.by_id("tinpot_tyrant").name == "Tinpot Tyrant", "callers cannot mutate the shared catalog")
	_test_repeatability()
	_test_distributions()
	print("Boss catalog tests: %d checks, %d failures" % [checks, failures])
	var audio := root.get_node_or_null("AudioManager")
	if audio != null and audio.has_method("stop_for_shutdown"):
		audio.stop_for_shutdown()
		await create_timer(0.35).timeout
	quit(0 if failures == 0 else 1)

func _test_repeatability() -> void:
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = 257091
	second.seed = 257091
	var same := true
	var last := ""
	for encounter: int in range(80):
		var picked := Catalog.choose(first, encounter * 45.0, last)
		var matched := Catalog.choose(second, encounter * 45.0, last)
		same = same and picked == matched
		last = picked.id
	_check(same and first.state == second.state, "equal Daily seed and encounter history produce identical sequences and RNG state")
	var restored := RandomNumberGenerator.new()
	restored.seed = first.seed
	restored.state = first.state
	_check(Catalog.choose(first, 500, last) == Catalog.choose(restored, 500, last), "resuming saved RNG state and previous ID preserves next encounter")
	var starts: Dictionary = {}
	for seed_value: int in range(64):
		first.seed = seed_value + 1
		starts[Catalog.choose(first, 45).id] = true
	_check(starts.size() >= 6, "different run seeds change opening boss and can produce rare visitors")
	var unrelated := RandomNumberGenerator.new()
	first.seed = 9182
	second.seed = 9182
	for encounter: int in range(40):
		unrelated.randf()
	_check(Catalog.choose(first, 100) == Catalog.choose(second, 100), "selection does not consume global or unrelated random streams")

func _test_distributions() -> void:
	for phase_index: int in range(3):
		var rng := RandomNumberGenerator.new()
		rng.seed = 190011 + phase_index
		var elapsed: float = [45.0, 240.0, 600.0][phase_index]
		var observed := [0, 0, 0]
		var rare := 0
		var seen: Dictionary = {}
		var last := ""
		var repeated := false
		for encounter: int in range(12000):
			var picked := Catalog.choose(rng, elapsed, last)
			repeated = repeated or picked.id == last
			observed[int(picked.tier) - 1] += 1
			rare += 1 if picked.rare else 0
			seen[picked.id] = true
			last = picked.id
		var expected := Catalog.tier_weights(elapsed)
		var proportions := true
		for tier: int in range(3):
			proportions = proportions and absf(observed[tier] / 12000.0 - expected[tier] / 100.0) < 0.025
		_check(proportions, "phase %d predominantly offers its tier at configured weights" % (phase_index + 1))
		_check(rare > 800 and rare < 2000 and seen.size() == 12, "phase %d can offer every boss, including rare bosses, with restrained rarity" % (phase_index + 1))
		_check(not repeated, "phase %d never immediately repeats the last boss" % (phase_index + 1))
