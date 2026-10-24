class_name SkillTree
extends CanvasLayer
## Skill tree overlay shaped like a tree-trunk cross-section: pan, zoom, select, buy.

signal closed

const RING := 70.0
const NODE_R := 12.0
const SPAN := 56.0

var pos: Dictionary = {}
var selected := ""
var zoom := 1.0
var pan := Vector2.ZERO
var _view: Control
var _tip: PanelContainer
var _tip_icon: TextureRect
var _tip_name: Label
var _tip_level: Label
var _tip_desc: Label
var _tip_next: Label
var _tip_cost: HBoxContainer
var _buy: Button
var _wallet_box: HBoxContainer
var _touches: Dictionary = {}
var _drag_dist := 0.0
var _pinch_d := 0.0
var _anim: Dictionary = {}
var _t := 0.0


func _ready() -> void:
	layer = 20
	_layout()
	var bg := ColorRect.new()
	bg.color = Color("#0d0b1d")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_tree)
	_view.gui_input.connect(_on_input)
	add_child(_view)
	_build_ui()
	pan = Vector2(-80, 0)
	zoom = 0.85
	_select("first_light")
	GameState.wallet_changed.connect(_refresh)
	GameState.skills_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_t += delta
	for k in _anim.keys():
		_anim[k] -= delta
		if _anim[k] <= 0.0:
			_anim.erase(k)
	_view.queue_redraw()
	if Input.is_action_just_pressed("skills") or Input.is_action_just_pressed("pause"):
		close()


func close() -> void:
	closed.emit()
	queue_free()


# --- Layout --------------------------------------------------------------

func _layout() -> void:
	pos["first_light"] = Vector2.ZERO
	for child in DB.children["first_light"]:
		var ty: Dictionary = DB.type_of(DB.node_by_id[child])
		var a: float = DB.branches[ty.branch].angle
		_place(child, 1, a - SPAN / 2, a + SPAN / 2)


func _leaves(id: String) -> int:
	var k: Array = DB.children[id]
	if k.is_empty():
		return 1
	var n := 0
	for c in k:
		n += _leaves(c)
	return n


func _place(id: String, depth: int, a0: float, a1: float) -> void:
	var a := deg_to_rad((a0 + a1) / 2.0)
	pos[id] = Vector2(cos(a), -sin(a)) * depth * RING
	var kids: Array = DB.children[id]
	if kids.is_empty():
		return
	var total := float(_leaves(id))
	var cur := a0
	for c in kids:
		var share := (a1 - a0) * _leaves(c) / total
		_place(c, depth + 1, cur, cur + share)
		cur += share


func _visible(id: String) -> bool:
	return GameState.level(id) > 0 or GameState.is_available(id)


func _to_screen(p: Vector2) -> Vector2:
	return _view.size / 2 + pan + p * zoom


# --- Drawing -------------------------------------------------------------

func _draw_tree() -> void:
	var center := _to_screen(Vector2.ZERO)
	for i in range(1, 11):
		var col := Color("#2a2140") if i % 3 else Color("#3a2e58")
		_view.draw_arc(center, i * RING * zoom + RING * zoom * 0.5, 0, TAU, 96, Color(col, 0.55), 1.0)
	for n in DB.nodes:
		var id: String = n.id
		if n.parent == null or not _visible(id):
			continue
		var a := _to_screen(pos[n.parent])
		var b := _to_screen(pos[id])
		var ty: Dictionary = DB.type_of(n)
		var bcol := Color(DB.branches[ty.branch].color)
		if GameState.level(id) > 0:
			_view.draw_line(a, b, Color(bcol, 0.9), 2.0)
		else:
			_view.draw_dashed_line(a, b, Color(bcol, 0.45), 1.5, 4.0)
	for n in DB.nodes:
		var id: String = n.id
		if not _visible(id):
			continue
		_draw_node(n)


func _draw_node(n: Dictionary) -> void:
	var id: String = n.id
	var p := _to_screen(pos[id])
	var r := NODE_R * zoom
	var lvl := GameState.level(id)
	var mx := int(n.max)
	var ty: Dictionary = DB.type_of(n)
	var bcol := Color(DB.branches.get(ty.branch, {"color": "#ffd34d"}).color)
	var frame := Color("#5a5578")
	if lvl >= mx:
		frame = Color.from_hsv(fmod(_t * 0.25, 1.0), 0.55, 1.0)
	elif lvl > 0:
		frame = bcol
	elif GameState.can_buy(id):
		frame = Color("#9cffe9").lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 5.0))
	if _anim.has(id):
		r *= 1.0 + _anim[id] * 0.8
		_view.draw_arc(p, r + (0.5 - _anim[id]) * 40.0 * zoom, 0, TAU, 32, Color(frame, _anim[id] * 2.0), 2.0)
	_view.draw_circle(p, r + 2, Color("#1a1020"))
	_view.draw_circle(p, r, Color("#191430") if lvl == 0 else Color("#241d40"))
	_view.draw_arc(p, r, 0, TAU, 32, frame, 2.0 if id != selected else 3.0)
	if id == selected:
		_view.draw_arc(p, r + 4, _t * 2.0, _t * 2.0 + PI * 1.5, 24, Color.WHITE, 1.0)
	var tex := DB.tex("icon_" + ty.icon)
	var s := zoom * 1.0
	var tint := Color.WHITE if (lvl > 0 or GameState.can_buy(id)) else Color(0.55, 0.55, 0.7)
	if n.has("region"):
		tint = tint * Color(DB.regions[DB.region_index(n.region)].colors.accent)
	_view.draw_texture_rect(tex, Rect2(p - tex.get_size() * s / 2, tex.get_size() * s), false, tint)
	if mx > 1:
		var pips := mini(mx, 10)
		for i in pips:
			var on := i < lvl
			var q := p + Vector2((i - (pips - 1) / 2.0) * 3.0 * zoom, r + 4 * zoom)
			_view.draw_rect(Rect2(q - Vector2(1, 1) * zoom, Vector2(2, 2) * zoom), bcol if on else Color("#3a3358"))


# --- Input ---------------------------------------------------------------

func _on_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touches[e.index] = e.position
			_drag_dist = 0.0
			if _touches.size() == 2:
				_pinch_d = _pinch_distance()
		else:
			if _touches.size() == 1 and _drag_dist < 6.0:
				_tap(e.position)
			_touches.erase(e.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _touches.has(d.index):
			return
		if _touches.size() == 1:
			pan += d.relative
			_drag_dist += d.relative.length()
		elif _touches.size() == 2:
			_touches[d.index] = d.position
			var nd := _pinch_distance()
			if _pinch_d > 0.0:
				_zoom_by(nd / _pinch_d)
			_pinch_d = nd
			_drag_dist = 99.0
			return
		_touches[d.index] = d.position
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / 1.1)


func _pinch_distance() -> float:
	var v: Array = _touches.values()
	return (v[0] as Vector2).distance_to(v[1])


func _zoom_by(f: float) -> void:
	zoom = clampf(zoom * f, 0.5, 2.2)


func _tap(screen: Vector2) -> void:
	var best := ""
	var bd := NODE_R * zoom + 6.0
	for n in DB.nodes:
		if not _visible(n.id):
			continue
		var d := _to_screen(pos[n.id]).distance_to(screen)
		if d < bd:
			bd = d
			best = n.id
	if best != "":
		Audio.play("tap")
		_select(best)


# --- Tooltip -------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_wallet_box = HBoxContainer.new()
	_wallet_box.position = Vector2(6, 4)
	_wallet_box.add_theme_constant_override("separation", 10)
	root.add_child(_wallet_box)
	var title := UIKit.label(GameState.t("skills"), 14, UIKit.C_AMBER)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-60, 4)
	root.add_child(title)
	var close_btn := UIKit.button("X", close, Color("#5a2a2a"), 12)
	close_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	close_btn.position = Vector2(-28, 4)
	close_btn.custom_minimum_size = Vector2(22, 20)
	root.add_child(close_btn)

	_tip = UIKit.panel(Color("#7a6fb0"))
	_tip.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_tip.offset_left = -176
	_tip.offset_right = -6
	_tip.offset_top = 30
	_tip.offset_bottom = -8
	root.add_child(_tip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_tip.add_child(v)
	var head := HBoxContainer.new()
	_tip_icon = UIKit.icon("icon_lantern", 2.0)
	head.add_child(_tip_icon)
	var hv := VBoxContainer.new()
	_tip_name = UIKit.label("", 12, UIKit.C_AMBER)
	_tip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_name.custom_minimum_size = Vector2(120, 0)
	_tip_level = UIKit.label("", 10, UIKit.C_DIM)
	hv.add_child(_tip_name)
	hv.add_child(_tip_level)
	head.add_child(hv)
	v.add_child(head)
	_tip_desc = UIKit.label("", 10)
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(156, 0)
	v.add_child(_tip_desc)
	_tip_next = UIKit.label("", 10, UIKit.C_GOOD)
	_tip_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_next.custom_minimum_size = Vector2(156, 0)
	v.add_child(_tip_next)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	_tip_cost = HBoxContainer.new()
	_tip_cost.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_tip_cost)
	_buy = UIKit.button(GameState.t("buy"), _on_buy, Color("#2f6b3a"), 13)
	_buy.custom_minimum_size = Vector2(0, 26)
	v.add_child(_buy)


func _select(id: String) -> void:
	selected = id
	_refresh()


func _refresh() -> void:
	for c in _wallet_box.get_children():
		c.queue_free()
	for cur in DB.economy.currencies:
		if cur == "amber" or GameState.wallet[cur] > 0.0:
			_wallet_box.add_child(UIKit.currency_row(cur))
	if selected == "":
		return
	var n: Dictionary = DB.node_by_id[selected]
	var ty := DB.type_of(n)
	var lvl := GameState.level(selected)
	var mx := int(n.max)
	_tip_icon.texture = DB.tex("icon_" + ty.icon)
	_tip_name.text = DB.node_name(n)
	_tip_level.text = "%s %d / %d" % [GameState.t("level"), lvl, mx]
	_tip_desc.text = DB.node_desc(n, lvl) if lvl > 0 or ty.fmt in ["none", "unlock"] else ""
	_tip_next.text = ("-> " + DB.node_desc(n, lvl + 1)) if lvl < mx and not ty.fmt in ["none", "unlock"] else ""
	for c in _tip_cost.get_children():
		c.queue_free()
	if lvl >= mx:
		_buy.text = GameState.t("maxed")
		_buy.disabled = true
		return
	var cost := GameState.next_cost(selected)
	_tip_cost.add_child(UIKit.icon(UIKit.CURRENCY_ICON[cost[0]]))
	var ok := GameState.can_buy(selected)
	_tip_cost.add_child(UIKit.label(GameState.fmt(cost[1]), 13, UIKit.C_GOOD if ok else UIKit.C_BAD))
	_buy.text = GameState.t("buy")
	_buy.disabled = not GameState.is_available(selected)


func _on_buy() -> void:
	var id := selected
	if GameState.buy(id):
		var n: Dictionary = DB.node_by_id[id]
		var big: bool = n.type.begins_with("path") or GameState.is_maxed(id)
		Audio.play("unlock" if big else "buy")
		_anim[id] = 0.5
	else:
		Audio.play("deny")
		UIKit.pop(_tip_cost, 1.3)
