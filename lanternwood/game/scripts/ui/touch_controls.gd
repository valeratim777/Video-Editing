class_name TouchControls
extends Control
## Multi-touch controls: floating joystick on the left half, hold-buttons for slingshot and pick.

const STICK_R := 26.0
const BTN_R := 22.0

var ex: Expedition
var _stick_id := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _btn_id := {"sling": -1, "drill": -1}


func _btn_center(b: String) -> Vector2:
	return Vector2(size.x - 40, size.y - 44) if b == "sling" else Vector2(size.x - 92, size.y - 30)


func _input(event: InputEvent) -> void:
	if get_tree().paused or ex == null or ex.ended:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			for b in _btn_id:
				if _btn_id[b] == -1 and e.position.distance_to(_btn_center(b)) < BTN_R + 8:
					_btn_id[b] = e.index
					_set_held(b, true)
					queue_redraw()
					return
			if _stick_id == -1 and e.position.x < size.x * 0.5 and e.position.y > 40:
				_stick_id = e.index
				_origin = e.position
				_knob = e.position
		else:
			if e.index == _stick_id:
				_stick_id = -1
				ex.player.move_input = Vector2.ZERO
			for b in _btn_id:
				if _btn_id[b] == e.index:
					_btn_id[b] = -1
					_set_held(b, false)
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_id:
			_knob = d.position
			var v := _knob - _origin
			if v.length() > STICK_R:
				_origin = _knob - v.normalized() * STICK_R
				v = _knob - _origin
			ex.player.move_input = v / STICK_R
			queue_redraw()


func _set_held(b: String, held: bool) -> void:
	if b == "sling":
		ex.player.sling_held = held
	else:
		ex.player.drill_held = held


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var base := _origin if _stick_id != -1 else Vector2(56, size.y - 52)
	var knob := _knob if _stick_id != -1 else base
	draw_circle(base, STICK_R + 4, Color(0, 0, 0, 0.25))
	draw_arc(base, STICK_R + 4, 0, TAU, 32, Color(1, 1, 1, 0.25), 2.0)
	draw_circle(knob, 11, Color(1, 1, 1, 0.35 if _stick_id != -1 else 0.15))
	for b in _btn_id:
		var c := _btn_center(b)
		var held: bool = _btn_id[b] != -1 or Input.is_action_pressed(b)
		draw_circle(c, BTN_R, Color(0.08, 0.06, 0.16, 0.7))
		draw_arc(c, BTN_R, 0, TAU, 32, Color("#9cffe9") if b == "sling" else Color("#7ad0ff"), 2.0 if not held else 3.5)
		var tex := DB.tex("icon_slingshot" if b == "sling" else "icon_pick")
		var s := 2.0 if not held else 1.8
		draw_texture_rect(tex, Rect2(c - tex.get_size() * s / 2, tex.get_size() * s), false)
		if b == "sling" and ex.player:
			var p := ex.player
			var frac := float(p.ammo) / maxf(1.0, GameState.stat("sling_ammo"))
			if p.reload_t > 0.0:
				frac = 1.0 - p.reload_t / maxf(0.01, GameState.stat("sling_reload_time"))
				draw_arc(c, BTN_R + 4, -PI / 2, -PI / 2 + TAU * frac, 32, Color("#ff9a6a"), 3.0)
			else:
				draw_arc(c, BTN_R + 4, -PI / 2, -PI / 2 + TAU * frac, 32, Color("#ffd34d"), 3.0)
