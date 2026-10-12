extends SceneTree
## Lossless nearest-neighbor atlas packing of the native Creature Mixer pixels.
## Preserves every original 8x PNG; minimizes texture changes and resident memory.

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	var roster = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters.json"))
	roster.append({"texture": "res://Assets/Monsters/creature-sheet (2).png"})
	var atlas = Image.create(960, 264, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for i in range(roster.size()):
		var source = Image.load_from_file(ProjectSettings.globalize_path(roster[i].texture))
		assert(source.get_size() == Vector2i(768, 192))
		source.resize(96, 24, Image.INTERPOLATE_NEAREST)
		atlas.blit_rect(source, Rect2i(0, 0, 96, 24), Vector2i((i % 10) * 96, int(i / 10) * 24))
	var result = atlas.save_png("res://Assets/Generated/monster_atlas.png")
	print("MONSTER_ATLAS_BUILD ", result, " · 101 creatures / four frames / 960x264 · original sheets preserved")
	root.get_node("AudioManager").stop_for_shutdown()
	await process_frame
	await process_frame
	quit(0 if result == OK else 1)
