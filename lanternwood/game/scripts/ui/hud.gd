class_name Hud
extends CanvasLayer
## Expedition HUD: oil bar, backpack, haul, hints, return button, pause, touch controls.

var ex: Expedition
var oil_bar: Control
var backpack_label: Label
var res_label: Label
var hint_label: Label
var return_btn: Button
var flash_rect: ColorRect
var touch: TouchControls
var pause_panel: PanelContainer
var _hint_tw: Tween


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	touch = TouchControls.new()
	touch.ex = ex
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(touch)

	var top := HBoxContainer.new()
	top.position = Vector2(6, 4)
	top.add_theme_constant_override("separation", 10)
	root.add_child(top)
	var bp := HBoxContainer.new()
	bp.add_child(UIKit.icon("icon_backpack"))
	backpack_label = UIKit.label("0/0", 12)
	bp.add_child(backpack_label)
	top.add_child(bp)
	var rs := HBoxContainer.new()
	rs.add_child(UIKit.icon(UIKit.CURRENCY_ICON[ex.nums.resource]))
	res_label = UIKit.label("+0", 12)
	rs.add_child(res_label)
	top.add_child(rs)

	oil_bar = Control.new()
	oil_bar.custom_minimum_size = Vector2(150, 14)
	oil_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	oil_bar.position = Vector2(-75, 6)
	oil_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oil_bar.draw.connect(_draw_oil)
	root.add_child(oil_bar)

	hint_label = UIKit.label("", 14)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint_label.position = Vector2(-160, 46)
	hint_label.size = Vector2(320, 20)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.modulate.a = 0.0
	root.add_child(hint_label)

	return_btn = UIKit.button(GameState.t("return"), func() -> void: ex.finish(false), Color("#7a3a1a"), 12)
	return_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	return_btn.position = Vector2(-50, 24)
	return_btn.custom_minimum_size = Vector2(100, 20)
	return_btn.visible = false
	root.add_child(return_btn)

	var pause := UIKit.button("II", _toggle_pause, Color("#2e2752"), 12)
	pause.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause.position = Vector2(-28, 4)
	pause.custom_minimum_size = Vector2(22, 20)
	root.add_child(pause)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	root.add_child(flash_rect)
	_build_pause(root)


func _process(_delta: float) -> void:
	backpack_label.text = "%d/%d" % [ex.haul_creatures.size(), ex.backpack_capacity()]
	backpack_label.add_theme_color_override("font_color", UIKit.C_BAD if ex.backpack_full() else UIKit.C_TEXT)
	res_label.text = "+" + GameState.fmt(ex.haul_res)
	oil_bar.queue_redraw()
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()


func _draw_oil() -> void:
	var f := clampf(ex.oil / maxf(1.0, ex.oil_max), 0.0, 1.0)
	var r := Rect2(Vector2(18, 3), Vector2(oil_bar.size.x - 18, 9))
	oil_bar.draw_texture(DB.tex("icon_lantern"), Vector2(0, -1))
	oil_bar.draw_rect(r.grow(2), Color("#1a1020"))
	oil_bar.draw_rect(r, Color("#3a2a4a"))
	var col := Color("#ffc94d").lerp(Color("#ff5a3d"), clampf((0.35 - f) / 0.35, 0.0, 1.0))
	if f < 0.25 and int(Time.get_ticks_msec() / 200) % 2 == 0:
		col = col.lightened(0.4)
	oil_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)
	oil_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * f, 2)), col.lightened(0.35))


func show_return(v: bool) -> void:
	if return_btn.visible != v:
		return_btn.visible = v
		if v:
			UIKit.pop(return_btn)


func hint(text: String, color := Color.WHITE) -> void:
	hint_label.text = text
	hint_label.add_theme_color_override("font_color", color)
	if _hint_tw:
		_hint_tw.kill()
	hint_label.modulate.a = 1.0
	UIKit.pop(hint_label, 1.3)
	_hint_tw = create_tween()
	_hint_tw.tween_interval(1.4)
	_hint_tw.tween_property(hint_label, "modulate:a", 0.0, 0.5)


func flash(color: Color) -> void:
	color.a *= float(GameState.settings.flash)
	flash_rect.color = color
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.3)


func bump_backpack() -> void:
	UIKit.pop(backpack_label, 1.35)


func bump_resource() -> void:
	UIKit.pop(res_label, 1.25)


func _build_pause(root: Control) -> void:
	pause_panel = UIKit.panel()
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-90, -60)
	pause_panel.custom_minimum_size = Vector2(180, 0)
	pause_panel.visible = false
	pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pause_panel.add_child(v)
	v.add_child(UIKit.button(GameState.t("resume"), _toggle_pause))
	v.add_child(UIKit.button(GameState.t("leave"), func() -> void:
		_toggle_pause()
		ex.finish(true), Color("#5a2a2a")))
	root.add_child(pause_panel)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _toggle_pause() -> void:
	pause_panel.visible = not pause_panel.visible
	get_tree().paused = pause_panel.visible
