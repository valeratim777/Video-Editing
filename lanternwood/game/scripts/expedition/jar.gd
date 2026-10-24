class_name Jar
extends Node2D
## Jar-net projectile thrown by the slingshot (or a helper moth).

var ex: Expedition
var vel := Vector2.ZERO
var dmg := 1.0
var crit := false
var life := 1.1
var homing := false
var spin := 0.0


func setup(expedition: Expedition, pos: Vector2, velocity: Vector2, damage: float, is_crit: bool, small := false) -> void:
	ex = expedition
	position = pos
	vel = velocity
	dmg = damage
	crit = is_crit
	homing = GameState.stat("sling_homing") >= 1.0
	spin = randf_range(-14, 14)
	var s := Sprite2D.new()
	s.texture = DB.tex("jar_small")
	if small:
		s.scale = Vector2(0.7, 0.7)
	if crit:
		s.modulate = Color(1.6, 1.4, 0.6)
	add_child(s)


func _process(delta: float) -> void:
	life -= delta
	rotation += spin * delta
	if homing:
		var c := ex.nearest_creature(position, 120.0)
		if c:
			var desired := (c.position - position).normalized() * vel.length()
			vel = vel.lerp(desired, 1.0 - exp(-6.0 * delta))
	vel += ex.wind * delta
	position += vel * delta
	for c in ex.creatures:
		if is_instance_valid(c) and c.position.distance_to(position) < 10.0:
			ex.puff(position, Color.WHITE)
			ex.hits += 1
			c.hit(dmg, crit)
			queue_free()
			return
	if life <= 0.0 or ex.arena.is_solid(ex.arena.to_cell(position)):
		if life > 0.0:
			ex.wall_hits += 1
		ex.puff(position, Color("#cfe8ff"), 4)
		queue_free()
