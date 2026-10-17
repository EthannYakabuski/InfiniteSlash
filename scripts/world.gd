extends Node2D
## A deterministic, bounded scrolling arena built from the supplied Kenney tiles.

const TILE := 64.0
const SCROLL_SPEED := 43.0
const THEMES := [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.80, 0.66),
	Color(0.63, 0.75, 0.91),
]

var elapsed := 0.0
var level := 1
var _textures: Dictionary = {}
var _atlases: Dictionary = {}
var _size := Vector2(540, 960)
var _scroll := 0.0


func _ready() -> void:
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in [0, 1, 2, 3, 4, 5, 7, 10, 24, 25, 26, 28, 29, 43, 76, 79, 99, 100, 101, 109, 111, 112, 113]:
		_cache("town", index)
	for index in [27, 39, 77, 78, 83, 85, 89]:
		_cache("farm", index)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func reset() -> void:
	elapsed = 0.0
	level = 1
	_scroll = 0.0
	queue_redraw()


func advance(_delta: float, run_elapsed: float, run_level: int = 1) -> void:
	elapsed = maxf(0.0, run_elapsed)
	level = maxi(1, run_level)
	_scroll = elapsed * SCROLL_SPEED
	queue_redraw()


static func night_amount(run_elapsed: float) -> float:
	var time := fposmod(run_elapsed, 180.0)
	if time < 65.0: return 0.0
	if time < 85.0: return smoothstep(65.0, 85.0, time)
	if time < 150.0: return 1.0
	return 1.0 - smoothstep(150.0, 180.0, time)


static func is_night(run_elapsed: float) -> bool:
	var time := fposmod(run_elapsed, 180.0)
	return time >= 85.0 and time < 150.0


func _on_resize() -> void:
	_size = get_viewport_rect().size
	queue_redraw()


func _cache(pack: String, index: int) -> void:
	var folder := "Town" if pack == "town" else "Farm"
	if not _atlases.has(pack):
		var atlas_path := "res://Assets/%s/Tilemap/tilemap_packed.png" % folder
		if ResourceLoader.exists(atlas_path): _atlases[pack] = load(atlas_path)
	if _atlases.has(pack): return
	var path := "res://Assets/%s/Tiles/tile_%04d.png" % [folder, index]
	if ResourceLoader.exists(path):
		_textures["%s_%d" % [pack, index]] = load(path)


func _tile(pack: String, index: int, where: Vector2, tint: Color, scale_factor := 1.0) -> void:
	if _atlases.has(pack):
		var source := Rect2(Vector2((index % 12) * 16, int(index / 12) * 16), Vector2(16, 16))
		draw_texture_rect_region(_atlases[pack], Rect2(where, Vector2.ONE * TILE * scale_factor), source, tint)
		return
	var texture: Texture2D = _textures.get("%s_%d" % [pack, index])
	if texture != null:
		draw_texture_rect(texture, Rect2(where, Vector2.ONE * TILE * scale_factor), false, tint)


func _noise(row: int, salt: int) -> int:
	return absi(((row * 73856093) ^ (salt * 19349663)) % 1000003)


func _draw() -> void:
	var night := night_amount(elapsed)
	var keep := level >= 50
	var chapter := int(elapsed / 180.0) % 3
	var tint: Color = Color(0.96, 0.91, 1.0) if keep else THEMES[chapter]
	tint = tint.lerp(Color(0.31, 0.38, 0.65) if keep else Color(0.28, 0.35, 0.61), night)
	draw_rect(Rect2(Vector2.ZERO, _size), Color("aeb3c9") * tint if keep else Color(0.49, 0.74, 0.37) * tint)
	var first_row := int(floor(-_scroll / TILE)) - 1
	var row_count := int(ceil(_size.y / TILE)) + 3
	var columns := int(ceil(_size.x / TILE)) + 1
	var road_left := floorf((_size.x - TILE * 3.0) * 0.5 / 4.0) * 4.0
	for row_offset in range(row_count):
		var row := first_row + row_offset
		var y := row * TILE + _scroll
		for column in range(columns):
			var tile_pos := Vector2(column * TILE, y)
			_tile("town", 109 if keep else 0, tile_pos, tint)
			var detail := _noise(row, column + 21) % 21
			if keep and detail == 0:
				_tile("town", 43, tile_pos, Color(tint, 0.34))
			elif not keep and detail < 3:
				_tile("town", 1 if detail < 2 else 2, tile_pos, tint)
		_tile("town", 43 if keep else 24, Vector2(road_left, y), tint)
		_tile("town", 43 if keep else 25, Vector2(road_left + TILE, y), tint)
		_tile("town", 43 if keep else 26, Vector2(road_left + TILE * 2.0, y), tint)
		if _noise(row, 84) % 10 == 0:
			_tile("town", 43, Vector2(road_left + TILE, y), tint)
		# Scenery stays on the sides, leaving the moving combat lane uncluttered.
		for side in range(2):
			var choice := _noise(row, side + 44)
			var x := -20.0 if side == 0 else _size.x - 42.0
			if keep:
				_tile("town", 99 + posmod(row, 3), Vector2(x, y), tint)
				if posmod(row, 7) == 0:
					_tile("town", 111 if side == 0 else 113, Vector2(x + (22 if side == 0 else -22), y), tint)
				if posmod(row, 4) == 0:
					_tile("farm", 89, Vector2(x + (58 if side == 0 else -30), y + 25), tint, 0.72)
				if posmod(row, 5) == 0: _torch(Vector2(x + 30, y + 26), night)
				continue
			var tree_index := 4 if chapter != 1 else 3
			if choice % 3 == 0:
				_tile("town", tree_index, Vector2(x, y - 14.0), tint, 1.30)
			elif choice % 7 == 0:
				_tile("farm", 27, Vector2(x, y), tint, 1.10)
			if row % 3 == 0:
				var props := [39, 77, 78, 83, 89]
				var prop: int = props[choice % props.size()]
				var prop_x := 64.0 + float(choice % 24) if side == 0 else _size.x - 128.0 + float(choice % 24)
				_tile("farm", prop, Vector2(prop_x, y + 18.0), tint, 0.70)
			if night > 0.2 and posmod(row, 6) == 0:
				_torch(Vector2(x + 30, y + 26), night)
	# Soft side shade adds depth without obscuring projectile edges.
	draw_rect(Rect2(0, 0, 14, _size.y), Color(0.10, 0.16, 0.13, 0.19))
	draw_rect(Rect2(_size.x - 14, 0, 14, _size.y), Color(0.10, 0.16, 0.13, 0.19))
	if night > 0.01:
		# Ground lighting changes strongly; combat sprites and HUD retain contrast.
		for i in range(14):
			var point := Vector2(28 + _noise(i, 3) % maxi(1, int(_size.x - 56)), 165 + _noise(i, 9) % maxi(1, int(_size.y - 210)))
			draw_circle(point, 1.5, Color(0.72, 0.87, 1.0, night * (0.25 + 0.22 * sin(elapsed * 1.7 + i))))


func _torch(position: Vector2, night: float) -> void:
	draw_circle(position, 28, Color(1.0, 0.57, 0.20, 0.06 + night * 0.08))
	draw_rect(Rect2(position + Vector2(-3, 0), Vector2(6, 18)), Color("5d4450"))
	draw_circle(position, 5.5 + sin(elapsed * 9.0 + position.y) * 0.8, Color("ffb75c"))
	draw_circle(position + Vector2(0, -2), 2.8, Color("fff1b1"))
