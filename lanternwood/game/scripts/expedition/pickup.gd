class_name Pickup
extends Node2D
## A resource bit that pops out of a block and flies to the player when in magnet range.

var ex: Expedition
var resource := "wood"
var amount := 1.0
var vel := Vector2.ZERO
var age := 0.0
var homing := false


func setup(expedition: Expedition, pos: Vector2, res: String, amt: float) -> void:
	ex = expedition
	position = pos
	resource = res
	amount = amt
	vel = Vector2(randf_range(-60, 60), randf_range(-90, -40))
	var s := Sprite2D.new()
	s.texture = DB.tex("pick_" + res)
	add_child(s)


func _process(delta: float) -> void:
	age += delta
	var p := ex.player
	var d := p.global_position.distance_to(global_position)
	if age > 0.35 and d < GameState.stat("pickup_range"):
		homing = true
	if homing:
		var dir := (p.global_position - global_position).normalized()
		vel = vel.lerp(dir * 260.0, 1.0 - exp(-8.0 * delta))
		if d < 8.0:
			ex.on_pickup(self)
			queue_free()
			return
	else:
		vel = vel.lerp(Vector2.ZERO, 1.0 - exp(-3.0 * delta))
		position.y += sin(age * 4.0) * 0.1
	position += vel * delta
	if age > 25.0:
		queue_free()
