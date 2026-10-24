class_name Creature
extends Node2D
## A glowing forest creature: wanders, takes "catch power" until caught.

const RARITY_TINT := {"normal": Color.WHITE, "silver": Color("#e4ecff"), "gold": Color("#ffd34d")}

var ex: Expedition
var hp := 1.0
var max_hp := 1.0
var value := 1.0
var rarity := "normal"
var accent := Color.WHITE
var vel := Vector2.ZERO
var target := Vector2.ZERO
var flash := 0.0
var t := 0.0
var burns := false
var _retarget := 0.0
var sprite: Sprite2D
var glow: Sprite2D


func setup(expedition: Expedition, pos: Vector2, hp_: float, value_: float, rarity_: String, accent_: Color, sprite_name: String) -> void:
	ex = expedition
	position = pos
	hp = hp_
	max_hp = hp_
	value = value_
	rarity = rarity_
	accent = accent_
	t = randf() * 10.0
	target = pos
	glow = Sprite2D.new()
	glow.texture = DB.glow_tex()
	glow.scale = Vector2.ONE * (0.22 if rarity == "normal" else 0.34)
	glow.modulate = Color(accent, 0.55)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = m
	add_child(glow)
	sprite = Sprite2D.new()
	sprite.texture = DB.tex(sprite_name)
	add_child(sprite)
	if rarity != "normal":
		glow.modulate = Color(RARITY_TINT.get(rarity, Color.WHITE), 0.75)


func _process(delta: float) -> void:
	t += delta
	_retarget -= delta
	if _retarget <= 0.0 or position.distance_to(target) < 6.0:
		target = ex.arena.random_open_point()
		_retarget = randf_range(2.0, 4.5)
	var desired := (target - position).normalized() * 22.0 * ex.creature_speed
	vel = vel.lerp(desired, 1.0 - exp(-1.5 * delta))
	var next := position + vel * delta
	if ex.arena.is_solid(ex.arena.to_cell(next)):
		_retarget = 0.0
		vel = -vel * 0.5
	else:
		position = next
	sprite.position.y = sin(t * 3.0) * 1.5
	sprite.flip_h = vel.x < 0
	flash = maxf(0.0, flash - delta * 6.0)
	var base: Color = RARITY_TINT.get(rarity, Color.WHITE)
	if rarity == "rainbow":
		base = Color.from_hsv(fmod(t * 0.4, 1.0), 0.45, 1.0)
		glow.modulate = Color(base, 0.8)
	sprite.modulate = base.lerp(Color(4, 4, 4), flash)
	glow.scale = Vector2.ONE * ((0.22 if rarity == "normal" else 0.34) + sin(t * 4.0) * 0.02)
	queue_redraw()


func hit(dmg: float, crit: bool) -> void:
	hp -= dmg
	flash = 1.0
	ex.float_text(position + Vector2(0, -10), GameState.fmt(dmg) + ("!" if crit else ""),
			Color("#ffd34d") if crit else Color.WHITE, crit)
	Audio.play("hit", 1.3 if crit else 1.0)
	if hp <= 0.0:
		ex.on_creature_caught(self)
		queue_free()


func _draw() -> void:
	if hp < max_hp and hp > 0.0:
		var w := 14.0
		var r := Rect2(-w / 2, -14, w, 3)
		draw_rect(r.grow(1), Color("#1a1020"))
		draw_rect(r, Color("#3a2a4a"))
		draw_rect(Rect2(r.position, Vector2(w * hp / max_hp, 3)), Color("#ff6a8a"))
