class_name Results
extends CanvasLayer
## End-of-expedition summary.

var main: Node
var summary: Dictionary


func _ready() -> void:
	layer = 15
	var bg := ColorRect.new()
	bg.color = Color("#0d0b1dee")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var p := UIKit.panel(UIKit.C_AMBER if not summary.fainted else UIKit.C_BAD)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-140, -100)
	p.custom_minimum_size = Vector2(280, 200)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var title := UIKit.label(GameState.t("results"), 15, UIKit.C_AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(UIKit.label(DB.region_name(summary.region), 11, Color(DB.regions[summary.region].colors.accent)))
	if summary.fainted:
		var f := UIKit.label(GameState.t("fainted"), 10, UIKit.C_BAD)
		f.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		f.custom_minimum_size = Vector2(260, 0)
		v.add_child(f)
	var secs := int(summary.time)
	_row(v, "icon_clock", "%s  %d:%02d" % [GameState.t("time"), secs / 60, secs % 60])
	var caught := "%s  %d" % [GameState.t("caught"), summary.caught]
	if summary.rare > 0:
		caught += "  (+%d ★)" % summary.rare
	_row(v, "icon_jar", caught)
	_row(v, "icon_coin", "≈ " + GameState.fmt(summary.value))
	_row(v, UIKit.CURRENCY_ICON[summary.resource], "+" + GameState.fmt(summary.res))
	var b := UIKit.button(GameState.t("continue"), func() -> void: main.show_village(), Color("#2f6b3a"), 13)
	b.custom_minimum_size = Vector2(0, 26)
	v.add_child(b)
	p.scale = Vector2(0.8, 0.8)
	p.pivot_offset = p.custom_minimum_size / 2
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("coin" if not summary.fainted else "deny")


func _row(v: VBoxContainer, icon_name: String, text: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(UIKit.icon(icon_name))
	h.add_child(UIKit.label(text, 12))
	v.add_child(h)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("interact"):
		main.show_village()
