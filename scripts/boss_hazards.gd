extends RefCounted
## Telegraphs and collision share the same geometry, including the pulse's gap.

const MAX_HAZARDS := 24

static func make(kind: String, position: Vector2, damage: float, aim: Vector2 = Vector2.DOWN) -> Dictionary:
	var warning := 0.9
	var duration := 2.3 if kind == "fire" else 0.55 if kind == "quake" else 1.65
	return {"kind": kind, "pos": position, "aim": aim.normalized(), "age": 0.0,
		"warning": warning, "duration": duration, "damage": damage, "radius": 72.0,
		"size": Vector2(116, 420), "gap_angle": aim.angle(), "gap_half": 0.78}

static func active(hazard: Dictionary) -> bool:
	return float(hazard.age) >= float(hazard.warning) and float(hazard.age) < float(hazard.warning) + float(hazard.duration)

static func pulse_radius(hazard: Dictionary) -> float:
	return 42.0 + maxf(0.0, float(hazard.age) - float(hazard.warning)) * 215.0

static func contains(hazard: Dictionary, point: Vector2, player_radius: float = 13.0) -> bool:
	if not active(hazard): return false
	var offset: Vector2 = point - Vector2(hazard.pos)
	match str(hazard.kind):
		"fire": return offset.length() < float(hazard.radius) + player_radius
		"quake":
			var local := offset.rotated(-Vector2(hazard.aim).angle() + PI * 0.5)
			var half: Vector2 = Vector2(hazard.size) * 0.5 + Vector2.ONE * player_radius
			return absf(local.x) < half.x and absf(local.y) < half.y
		"pulse":
			if absf(offset.length() - pulse_radius(hazard)) > 12.0 + player_radius: return false
			return absf(wrapf(offset.angle() - float(hazard.gap_angle), -PI, PI)) > float(hazard.gap_half)
	return false

static func draw(canvas: CanvasItem, hazard: Dictionary) -> void:
	var position: Vector2 = hazard.pos
	var warning: bool = float(hazard.age) < float(hazard.warning)
	var progress := clampf(float(hazard.age) / float(hazard.warning), 0.0, 1.0)
	var color := Color("ff8a42") if hazard.kind == "fire" else Color("ffc77d") if hazard.kind == "quake" else Color("a1edff")
	var fill := Color(color, 0.11 + progress * 0.12 if warning else 0.32)
	var outline := Color(color, 0.65 if warning else 1.0)
	match str(hazard.kind):
		"fire":
			canvas.draw_circle(position, float(hazard.radius), fill)
			canvas.draw_arc(position, float(hazard.radius), 0, TAU, 40, outline, 3)
			if warning:
				canvas.draw_arc(position, float(hazard.radius) * progress, 0, TAU, 32, outline, 2)
			else:
				for i in range(7):
					var spark := position + Vector2.from_angle(i * TAU / 7 + float(hazard.age)) * (20 + i % 3 * 12)
					canvas.draw_circle(spark, 5 + i % 3, Color("ffe4a0"))
		"quake":
			var half: Vector2 = Vector2(hazard.size) * 0.5
			var angle := Vector2(hazard.aim).angle() - PI * 0.5
			var corners := PackedVector2Array()
			for vertex in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
				corners.append(position + vertex.rotated(angle))
			canvas.draw_colored_polygon(corners, fill)
			corners.append(corners[0])
			canvas.draw_polyline(corners, outline, 3)
			if not warning:
				for i in range(5):
					var a := position + Vector2(-half.x * 0.75, (i - 2) * 72).rotated(angle)
					var b := position + Vector2(half.x * 0.75, (i - 2) * 72 + 25).rotated(angle)
					canvas.draw_line(a, b, Color("fff0c0"), 4)
		"pulse":
			var radius := 42.0 if warning else pulse_radius(hazard)
			var gap := float(hazard.gap_angle)
			var half := float(hazard.gap_half)
			canvas.draw_arc(position, radius, gap + half, gap + TAU - half, 48, outline, 5 if warning else 12)
			if warning:
				for sign_value in [-1, 1]:
					canvas.draw_line(position, position + Vector2.from_angle(gap + half * sign_value) * 125, Color(color, 0.45), 2)
