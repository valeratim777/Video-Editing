class_name Backdrop
extends Node2D
## One parallax layer of soft silhouettes (trees, hills) in the region's background hue.

var color: Color
var span: Vector2
var depth := 0
var seed_ := 1


func setup(c: Color, area: Vector2, layer_depth: int, s: int) -> void:
	color = c
	span = area
	depth = layer_depth
	seed_ = s
	queue_redraw()


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ + depth * 101
	var base_y := span.y * (0.35 + 0.18 * depth)
	var x := -span.x * 0.5
	while x < span.x * 1.5:
		var tw := rng.randf_range(30, 70) * (1.0 + depth * 0.4)
		var th := rng.randf_range(80, 200) * (1.0 + depth * 0.3)
		# trunk
		draw_rect(Rect2(x + tw * 0.42, base_y - th * 0.4, tw * 0.16, th + span.y), color)
		# blocky canopy (stair-stepped, like the terrain)
		var top := base_y - th
		var steps := 4
		for i in steps:
			var ww := tw * (0.5 + 0.5 * float(i + 1) / steps)
			draw_rect(Rect2(x + (tw - ww) / 2.0, top + i * th * 0.12, ww, th * 0.14), color)
		x += tw * rng.randf_range(0.7, 1.3)
	draw_rect(Rect2(-span.x * 0.5, base_y, span.x * 2, span.y * 2), color)
