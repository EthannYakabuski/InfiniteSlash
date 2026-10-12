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
var _textures: Dictionary = {}
var _size := Vector2(540, 960)
var _scroll := 0.0


func _ready() -> void:
	z_index = -100
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for index in [0, 1, 2, 3, 4, 5, 7, 10, 24, 25, 26, 28, 29, 43]:
		_cache("town", index)
	for index in [27, 39, 77, 78, 83, 85, 89]:
		_cache("farm", index)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func reset() -> void:
	elapsed = 0.0
	_scroll = 0.0
	queue_redraw()


func advance(_delta: float, run_elapsed: float) -> void:
	elapsed = maxf(0.0, run_elapsed)
	_scroll = elapsed * SCROLL_SPEED
	queue_redraw()


func _on_resize() -> void:
	_size = get_viewport_rect().size
	queue_redraw()


func _cache(pack: String, index: int) -> void:
	var folder := "Town" if pack == "town" else "Farm"
	var path := "res://Assets/%s/Tiles/tile_%04d.png" % [folder, index]
	if ResourceLoader.exists(path):
		_textures["%s_%d" % [pack, index]] = load(path)


func _tile(pack: String, index: int, where: Vector2, tint: Color, scale_factor := 1.0) -> void:
	var texture: Texture2D = _textures.get("%s_%d" % [pack, index])
	if texture != null:
		draw_texture_rect(texture, Rect2(where, Vector2.ONE * TILE * scale_factor), false, tint)


func _noise(row: int, salt: int) -> int:
	return absi(((row * 73856093) ^ (salt * 19349663)) % 1000003)


func _draw() -> void:
	var chapter := int(elapsed / 150.0) % 3
	var chapter_time := fmod(elapsed, 150.0)
	var tint: Color = THEMES[chapter]
	if chapter_time > 142.0:
		tint = tint.lerp(THEMES[(chapter + 1) % 3], (chapter_time - 142.0) / 8.0)
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.49, 0.74, 0.37) * tint)
	var first_row := int(floor(-_scroll / TILE)) - 1
	var row_count := int(ceil(_size.y / TILE)) + 3
	var columns := int(ceil(_size.x / TILE)) + 1
	var road_left := floorf((_size.x - TILE * 3.0) * 0.5 / 4.0) * 4.0
	for row_offset in range(row_count):
		var row := first_row + row_offset
		var y := row * TILE + _scroll
		for column in range(columns):
			var tile_pos := Vector2(column * TILE, y)
			_tile("town", 0, tile_pos, tint)
			var detail := _noise(row, column + 21) % 21
			if detail < 3:
				_tile("town", 1 if detail < 2 else 2, tile_pos, tint)
		_tile("town", 24, Vector2(road_left, y), tint)
		_tile("town", 25, Vector2(road_left + TILE, y), tint)
		_tile("town", 26, Vector2(road_left + TILE * 2.0, y), tint)
		if _noise(row, 84) % 10 == 0:
			_tile("town", 43, Vector2(road_left + TILE, y), tint)
		# Scenery stays on the sides, leaving the moving combat lane uncluttered.
		for side in range(2):
			var choice := _noise(row, side + 44)
			var x := -20.0 if side == 0 else _size.x - 42.0
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
	# Soft side shade adds depth without obscuring projectile edges.
	draw_rect(Rect2(0, 0, 14, _size.y), Color(0.10, 0.16, 0.13, 0.19))
	draw_rect(Rect2(_size.x - 14, 0, 14, _size.y), Color(0.10, 0.16, 0.13, 0.19))
