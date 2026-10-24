class_name Player
extends CharacterBody2D
## The hedgehog: floats around (the lantern works like a tiny balloon), throws jars, sparks blocks.

var ex: Expedition
var sprite: Sprite2D
var light: PointLight2D
var beam: Line2D
var move_input := Vector2.ZERO
var sling_held := false
var drill_held := false
var ammo := 5
var reload_t := 0.0
var fire_cd := 0.0
var anim_t := 0.0
var squash := 0.0
var speed_mult := 1.0
var _full_hint_cd := 0.0


func setup(expedition: Expedition, pos: Vector2) -> void:
	ex = expedition
	position = pos
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6
	cs.shape = shape
	add_child(cs)
	sprite = Sprite2D.new()
	sprite.texture = DB.tex("hero_0")
	add_child(sprite)
	light = PointLight2D.new()
	light.texture = DB.glow_tex()
	light.color = Color("#ffd9a0")
	light.energy = 1.35
	light.position = Vector2(-1, -10)
	add_child(light)
	beam = Line2D.new()
	beam.width = 2.0
	beam.default_color = Color("#bfeaff")
	beam.visible = false
	ex.fx_layer.add_child(beam)
	ammo = int(GameState.stat("sling_ammo"))
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	var dir := move_input
	if dir.length() < 0.1:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var spd := GameState.stat("move_speed") * speed_mult
	velocity = velocity.lerp(dir * spd, 1.0 - exp(-9.0 * delta))
	velocity += ex.wind * delta * 0.6
	move_and_slide()
	anim_t += delta
	var moving := velocity.length() > 15.0
	sprite.texture = DB.tex("hero_1" if moving and int(anim_t * 8) % 2 == 0 else "hero_0")
	if absf(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0
	sprite.position.y = sin(anim_t * 3.0) * 1.5
	squash = maxf(0.0, squash - delta * 6.0)
	sprite.scale = Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.2)
	var oil_frac := ex.oil / maxf(1.0, ex.oil_max)
	light.texture_scale = lerpf(1.3, 3.4, clampf(oil_frac * 1.3, 0.0, 1.0)) * ex.light_scale
	light.energy = 1.35 if oil_frac > 0.25 else 0.9 + 0.45 * absf(sin(anim_t * 9.0))
	light.position.x = 5 if not sprite.flip_h else -5
	_tools(delta)


func _tools(delta: float) -> void:
	fire_cd -= delta
	_full_hint_cd -= delta
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = int(GameState.stat("sling_ammo"))
	var sling := sling_held or Input.is_action_pressed("sling")
	if sling and reload_t <= 0.0 and fire_cd <= 0.0:
		if ex.backpack_full():
			if _full_hint_cd <= 0.0:
				ex.hint(GameState.t("backpack_full"), Color("#ff9a6a"))
				Audio.play("deny")
				_full_hint_cd = 1.5
		else:
			var target := ex.nearest_creature(global_position, 200.0, true)
			if target:
				_throw(target)
	var drill := drill_held or Input.is_action_pressed("drill")
	var block: Block = ex.nearest_block(global_position, GameState.stat("drill_range") + 8.0) if drill else null
	beam.visible = block != null
	if block:
		var dps := GameState.stat("drill_dps")
		_beam_to(block.global_position)
		block.damage(dps * delta)
		var chain := int(GameState.stat("drill_chain"))
		var from := block
		var hit_blocks: Array = [block]
		for i in chain:
			var nb := ex.nearest_block(from.global_position, 56.0, hit_blocks)
			if nb == null:
				break
			nb.damage(dps * 0.5 * delta)
			hit_blocks.append(nb)
			from = nb
		if randf() < delta * 10.0:
			ex.sparks(block.global_position)
		Audio.play("spark", 1.0, -6.0)


func _throw(target: Creature) -> void:
	var speed := GameState.stat("sling_proj_speed")
	var to := target.position - global_position
	var lead := target.vel * (to.length() / speed)
	var dir := (to + lead).normalized()
	_spawn_jar(dir, speed)
	if randf() < GameState.stat("sling_multi_chance"):
		_spawn_jar(dir.rotated(randf_range(-0.25, 0.25)), speed)
	fire_cd = 1.0 / GameState.stat("sling_fire_rate")
	ammo -= 1
	squash = 1.0
	sprite.flip_h = dir.x < 0
	Audio.play("throw", 1.0, -3.0, 0.08)
	if ammo <= 0:
		reload_t = GameState.stat("sling_reload_time")


func _spawn_jar(dir: Vector2, speed: float) -> void:
	var dmg := GameState.stat("sling_damage")
	var crit := randf() < GameState.stat("sling_crit_chance")
	if crit:
		dmg *= GameState.stat("sling_crit_mult")
	var j := Jar.new()
	j.setup(ex, global_position + dir * 6.0, dir * speed, dmg, crit)
	ex.lit_layer.add_child(j)
	ex.thrown += 1


func _beam_to(p: Vector2) -> void:
	var a := global_position + Vector2(4 if not sprite.flip_h else -4, -2)
	var pts := PackedVector2Array([a])
	var n := 5
	for i in range(1, n):
		var q := a.lerp(p, float(i) / n)
		pts.append(q + Vector2(randf_range(-3, 3), randf_range(-3, 3)))
	pts.append(p)
	beam.points = pts
	beam.default_color = Color("#bfeaff") if randf() < 0.7 else Color.WHITE
