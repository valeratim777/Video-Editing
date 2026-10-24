class_name Arena
extends Node2D
## Procedural blocky arena: tile grid, stair-stepped terrain with bright rims, collision, spawn queries.

const T := 16

var w := 46
var h := 26
var solid := PackedByteArray()
var colors: Dictionary
var camp_cell := Vector2i(5, 10)
var open_cells: Array[Vector2i] = []
var floor_cells: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()


func generate(region: Dictionary, variant: int) -> void:
	colors = region.colors
	rng.seed = hash(str(region.id) + str(variant))
	var layout: String = region.layout
	w = 44 + rng.randi_range(0, 8)
	h = 30 if layout == "shafts" else 26
	solid.resize(w * h)
	solid.fill(0)
	_borders()
	match layout:
		"bowl":
			_blobs(rng.randi_range(3, 5))
		"ledges":
			_ledges(rng.randi_range(5, 8))
		"shafts":
			_pillars(rng.randi_range(3, 5))
	_place_camp()
	_fill_unreachable()
	_collect_cells()
	_build_collision()
	queue_redraw()


func is_solid(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return true
	return solid[c.y * w + c.x] == 1


func _put(x: int, y: int, v := 1) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		solid[y * w + x] = v


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func size_px() -> Vector2:
	return Vector2(w * T, h * T)


func has_los(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 6.0)
	for i in range(1, n):
		if is_solid(to_cell(a.lerp(b, float(i) / n))):
			return false
	return true


func random_open_point(min_dist_from: Vector2 = Vector2.INF, min_dist := 0.0) -> Vector2:
	for i in 30:
		var c: Vector2i = open_cells[rng.randi() % open_cells.size()]
		var p := cell_center(c)
		if min_dist_from == Vector2.INF or p.distance_to(min_dist_from) >= min_dist:
			return p
	return cell_center(open_cells[0])


# --- Generation ----------------------------------------------------------

func _borders() -> void:
	var f := rng.randi_range(2, 4)
	var c := rng.randi_range(1, 3)
	for x in w:
		if rng.randf() < 0.4:
			f = clampi(f + rng.randi_range(-1, 1), 2, 5)
		if rng.randf() < 0.4:
			c = clampi(c + rng.randi_range(-1, 1), 1, 4)
		for y in c:
			_put(x, y)
		for y in range(h - f, h):
			_put(x, y)
	var lw := 2
	var rw := 2
	for y in h:
		if rng.randf() < 0.3:
			lw = clampi(lw + rng.randi_range(-1, 1), 1, 4)
		if rng.randf() < 0.3:
			rw = clampi(rw + rng.randi_range(-1, 1), 1, 4)
		for x in lw:
			_put(x, y)
		for x in rw:
			_put(w - 1 - x, y)


func _blobs(n: int) -> void:
	for i in n:
		var cx := rng.randi_range(12, w - 6)
		var cy := rng.randi_range(6, h - 8)
		var rx := rng.randi_range(2, 4)
		var ry := rng.randi_range(1, 3)
		for y in range(cy - ry, cy + ry + 1):
			var span := rx - absi(y - cy) / 2 + rng.randi_range(-1, 0)
			for x in range(cx - span, cx + span + 1):
				_put(x, y)


func _ledges(n: int) -> void:
	for i in n:
		var len := rng.randi_range(4, 9)
		var x0 := rng.randi_range(10, w - len - 3)
		var y0 := rng.randi_range(6, h - 6)
		var th := rng.randi_range(1, 2)
		for x in range(x0, x0 + len):
			for y in range(y0, y0 + th):
				_put(x, y)
		if rng.randf() < 0.5:
			_put(x0 + len / 2, y0 + th)


func _pillars(n: int) -> void:
	var step := (w - 14) / n
	for i in n:
		var x0 := 12 + i * step + rng.randi_range(-1, 1)
		var pw := rng.randi_range(2, 3)
		var from_top := i % 2 == 0
		var ln := int(h * rng.randf_range(0.45, 0.65))
		for x in range(x0, x0 + pw):
			for k in ln:
				var y := k if from_top else h - 1 - k
				_put(x + (k / 4) % 2 * int(rng.randf() < 0.2), y)


func _place_camp() -> void:
	var x := 6
	var y := h - 2
	while y > 2 and is_solid(Vector2i(x, y)):
		y -= 1
	camp_cell = Vector2i(x, y)
	for cx in range(x - 2, x + 3):
		for cy in range(y - 4, y + 1):
			if cx > 1:
				_put(cx, cy, 0)
	for cx in range(x - 2, x + 3):
		_put(cx, y + 1)


func _fill_unreachable() -> void:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = [camp_cell]
	seen[camp_cell.y * w + camp_cell.x] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n: Vector2i = c + d
			if is_solid(n) or seen[n.y * w + n.x] == 1:
				continue
			seen[n.y * w + n.x] = 1
			stack.append(n)
	for i in w * h:
		if solid[i] == 0 and seen[i] == 0:
			solid[i] = 1


func _collect_cells() -> void:
	open_cells.clear()
	floor_cells.clear()
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if is_solid(c):
				continue
			var clear := true
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if is_solid(c + d):
					clear = false
			if clear:
				open_cells.append(c)
			if is_solid(c + Vector2i.DOWN) and absi(x - camp_cell.x) > 5:
				floor_cells.append(c)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for y in h:
		var x := 0
		while x < w:
			if not is_solid(Vector2i(x, y)):
				x += 1
				continue
			var x0 := x
			while x < w and is_solid(Vector2i(x, y)):
				x += 1
			var shape := RectangleShape2D.new()
			shape.size = Vector2((x - x0) * T, T)
			var cs := CollisionShape2D.new()
			cs.shape = shape
			cs.position = Vector2((x0 + x) * T / 2.0, y * T + T / 2.0)
			body.add_child(cs)


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	var fill := Color(colors.fill)
	var dot := fill.darkened(0.25)
	var dot2 := fill.lightened(0.08)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not is_solid(c):
				continue
			var r := Rect2(x * T, y * T, T, T)
			draw_rect(r, fill)
			var hsh := (x * 73856093) ^ (y * 19349663)
			if hsh % 3 == 0:
				draw_circle(r.position + Vector2(4 + hsh % 7, 4 + (hsh >> 3) % 7), 1.5, dot)
			if hsh % 5 == 0:
				draw_rect(Rect2(r.position + Vector2(9, 10), Vector2(2, 2)), dot2)


## Bright terrain rims live on the lit layer, so they glow in the dark like moss.
func draw_rims(ci: CanvasItem) -> void:
	var rim := Color(colors.rim)
	var rim_dark := rim.darkened(0.45)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not is_solid(c):
				continue
			var p := Vector2(x * T, y * T)
			if not is_solid(c + Vector2i.UP):
				ci.draw_rect(Rect2(p + Vector2(0, -4), Vector2(T, 3)), Color(rim, 0.15))
				ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(T, 5)), rim)
				ci.draw_rect(Rect2(p + Vector2(0, -1), Vector2(T, 1)), rim.lightened(0.4))
				ci.draw_rect(Rect2(p + Vector2(0, 4), Vector2(T, 1)), rim_dark)
				if (x * 31 + y) % 4 == 0:
					ci.draw_rect(Rect2(p + Vector2(3, -3), Vector2(2, 2)), rim)
			if not is_solid(c + Vector2i.DOWN):
				ci.draw_rect(Rect2(p + Vector2(0, T - 2), Vector2(T, 2)), rim_dark)
			if not is_solid(c + Vector2i.LEFT):
				ci.draw_rect(Rect2(p + Vector2(-1, 0), Vector2(3, T)), rim.darkened(0.15))
			if not is_solid(c + Vector2i.RIGHT):
				ci.draw_rect(Rect2(p + Vector2(T - 2, 0), Vector2(3, T)), rim.darkened(0.15))
