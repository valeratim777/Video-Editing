class_name Helper
extends Node2D
## A friend that follows the hedgehog: moths throw small jars at creatures, beetles mine blocks.

var ex: Expedition
var kind := "moth"
var idx := 0
var cd := 0.0
var t := 0.0


func setup(expedition: Expedition, helper_kind: String, index: int) -> void:
	ex = expedition
	kind = helper_kind
	idx = index
	var s := Sprite2D.new()
	s.texture = DB.tex("helper_" + kind)
	add_child(s)
	position = ex.player.global_position


func _process(delta: float) -> void:
	t += delta
	cd -= delta
	var p := ex.player.global_position
	var power := GameState.stat("helper_damage")
	if kind == "moth":
		var a := t * 2.0 + idx * PI
		position = position.lerp(p + Vector2(cos(a) * 18, sin(a) * 10 - 8), 1.0 - exp(-6.0 * delta))
		if cd <= 0.0:
			var c := ex.nearest_creature(position, 150.0, true)
			if c and not ex.backpack_full():
				var dir := (c.position - position).normalized()
				var j := Jar.new()
				j.setup(ex, position, dir * 200.0, GameState.stat("sling_damage") * 0.5 * power, false, true)
				ex.lit_layer.add_child(j)
				cd = 1.0
	else:
		var b := ex.nearest_block(position, 220.0)
		var goal := b.global_position + Vector2(-10 + idx * 20, -6) if b else p + Vector2(-14 - idx * 10, 4)
		position = position.lerp(goal, 1.0 - exp(-3.0 * delta))
		if b and position.distance_to(b.global_position) < 22.0:
			b.damage(GameState.stat("drill_dps") * 0.5 * power * delta)
			if randf() < delta * 6.0:
				ex.sparks(b.global_position)
	scale.x = -1.0 if position.x > p.x and kind == "beetle" else 1.0
