extends Node
## Scene switcher with a fade transition: village <-> expedition -> results.

var current: Node
var overlay: Node
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color("#0d0b1d")
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_set_scene(_make_village())
	create_tween().tween_property(_fade, "color:a", 0.0, 0.4)


func _make_village() -> Node:
	var v := Village.new()
	v.main = self
	return v


func _set_scene(n: Node) -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	if current:
		current.queue_free()
	current = n
	add_child(n)


func _transition(make: Callable) -> void:
	if _busy:
		return
	_busy = true
	get_tree().paused = false
	Engine.time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.22)
	await tw.finished
	_set_scene(make.call())
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.3)
	_busy = false


func show_village() -> void:
	_transition(_make_village)


func start_expedition(region_index: int) -> void:
	if not GameState.is_region_unlocked(region_index):
		region_index = 0
	_transition(func() -> Node:
		var e := Expedition.new()
		e.main = self
		e.region_index = region_index
		return e)


func show_results(summary: Dictionary) -> void:
	_transition(func() -> Node:
		var r := Results.new()
		r.main = self
		r.summary = summary
		return r)


func open_skill_tree() -> void:
	if overlay:
		return
	var st := SkillTree.new()
	st.closed.connect(func() -> void: overlay = null)
	overlay = st
	add_child(st)
	Audio.play("tap")
