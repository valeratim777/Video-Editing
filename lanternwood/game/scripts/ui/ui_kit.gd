class_name UIKit
## Small helpers for building pixel-style UI in code.

const C_PANEL := Color("#141029e6")
const C_BORDER := Color("#5a4f8a")
const C_TEXT := Color("#f4f0ff")
const C_DIM := Color("#8c86b0")
const C_GOOD := Color("#7fe07a")
const C_BAD := Color("#ff6a6a")
const C_AMBER := Color("#ffc94d")
const CURRENCY_ICON := {"amber": "icon_coin", "wood": "icon_log", "crystal": "icon_gem", "pollen": "icon_star_gold"}


static func label(text: String, size := 11, color := C_TEXT, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color("#1a1020"))
		l.add_theme_constant_override("outline_size", 4)
	return l


static func panel_style(border := C_BORDER, bg := C_PANEL, radius := 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


static func panel(border := C_BORDER) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(border))
	return p


static func button(text: String, on_press: Callable, color := Color("#2e2752"), size := 11) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color
		if state == "hover":
			c = color.lightened(0.15)
		elif state == "pressed":
			c = color.darkened(0.2)
		elif state == "disabled":
			c = Color("#2a2733")
		var s := panel_style(c.lightened(0.35), c, 4)
		if state == "focus":
			s.bg_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(state, s)
	b.pressed.connect(func() -> void:
		Audio.play("tap")
		on_press.call())
	return b


static func icon(sprite_name: String, scale := 1.0) -> TextureRect:
	var r := TextureRect.new()
	r.texture = DB.tex(sprite_name)
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.custom_minimum_size = Vector2(16, 16) * scale
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r


## A row "[icon] 12.3K" bound to a wallet currency; call refresh via the returned label's meta.
static func currency_row(cur: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	h.add_child(icon(CURRENCY_ICON[cur]))
	var l := label(GameState.fmt(GameState.wallet[cur]), 12, C_AMBER if cur == "amber" else C_TEXT)
	l.name = "Value"
	h.add_child(l)
	h.set_meta("currency", cur)
	return h


static func pop(node: CanvasItem, amount := 1.25) -> void:
	if node is Control:
		(node as Control).pivot_offset = (node as Control).size / 2
	var tw := node.create_tween()
	node.scale = Vector2.ONE * amount
	tw.tween_property(node, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
