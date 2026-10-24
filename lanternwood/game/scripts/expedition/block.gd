class_name Block
extends Node2D
## A breakable resource block (stump / crystal / star-bud). Cracks as it takes damage.

var ex: Expedition
var hp := 1.0
var max_hp := 1.0
var cell := Vector2i.ZERO
var shake := 0.0
var sprite: Sprite2D


func setup(expedition: Expedition, c: Vector2i, hp_: float, sprite_name: String) -> void:
	ex = expedition
	cell = c
	position = ex.arena.cell_center(c)
	hp = hp_
	max_hp = hp_
	sprite = Sprite2D.new()
	sprite.texture = DB.tex(sprite_name)
	sprite.offset.y = 8 - sprite.texture.get_height() / 2.0
	add_child(sprite)
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func damage(amount: float) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	shake = 0.12
	queue_redraw()
	if hp <= 0.0:
		ex.on_block_broken(self)
		queue_free()


func _process(delta: float) -> void:
	if shake > 0.0:
		shake -= delta
		sprite.position = Vector2(randf_range(-1, 1), randf_range(-1, 1))
	else:
		sprite.position = Vector2.ZERO


func _draw() -> void:
	var dmg := 1.0 - hp / max_hp
	if dmg <= 0.05:
		return
	var c := Color("#1a1020")
	draw_line(Vector2(-1, -2), Vector2(2, 3), c, 1.0)
	if dmg > 0.35:
		draw_line(Vector2(2, 3), Vector2(-3, 6), c, 1.0)
		draw_line(Vector2(-1, -2), Vector2(-5, -1), c, 1.0)
	if dmg > 0.7:
		draw_line(Vector2(2, 3), Vector2(6, 1), c, 1.0)
		draw_line(Vector2(-5, -1), Vector2(-6, 4), c, 1.0)
	var w := 14.0
	var r := Rect2(-w / 2, -12, w, 2)
	draw_rect(r.grow(1), Color("#1a1020"))
	draw_rect(Rect2(r.position, Vector2(w * hp / max_hp, 2)), Color("#7ad0ff"))
