class_name Village
extends Node2D
## The treehouse village hub: market (sells over time), skill shrine, campfire with region select.

const MARKET_POS := Vector2(118, 268)
const SHRINE_POS := Vector2(330, 250)
const FIRE_POS := Vector2(540, 282)

var main: Node
var ui: CanvasLayer
var _wallet_box: HBoxContainer
var _market_label: Label
var _market_bar: ProgressBar
var _regions_panel: PanelContainer
var _settings_panel: PanelContainer
var _stars: Array = []
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 70:
		_stars.append([Vector2(rng.randf_range(0, 640), rng.randf_range(0, 200)), rng.randf_range(0, TAU), rng.randf_range(0.5, 1.5)])
	ui = CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	_build_ui()
	GameState.sold.connect(_on_sold)
	GameState.wallet_changed.connect(_refresh_wallet)
	GameState.skills_changed.connect(queue_redraw)
	if GameState.offline_income > 0.0:
		_toast("%s +%s" % [GameState.t("offline"), GameState.fmt(GameState.offline_income)])
		GameState.offline_income = 0.0
	if GameState.finished:
		_ending()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var q := GameState.market_queue.size()
	_market_label.text = "%s: %d" % [GameState.t("selling"), q] if q > 0 else GameState.t("queue_empty")
	_market_bar.value = GameState.sell_progress * 100.0 if q > 0 else 0.0
	if _regions_panel.visible or _settings_panel.visible or get_tree().paused:
		return
	if Input.is_action_just_pressed("skills"):
		main.open_skill_tree()
	elif Input.is_action_just_pressed("interact"):
		main.start_expedition(GameState.last_region)


# --- Drawing -------------------------------------------------------------

func _draw() -> void:
	for i in 12:
		draw_rect(Rect2(0, i * 30, 640, 30), Color("#0b0a1a").lerp(Color("#22305a"), i / 11.0))
	for s in _stars:
		var a: float = 0.35 + 0.35 * sin(_t * s[2] + s[1])
		draw_rect(Rect2(s[0], Vector2(1, 1)), Color(1, 1, 0.9, a))
	draw_circle(Vector2(560, 56), 16, Color("#fff2c0"))
	draw_circle(Vector2(566, 52), 14, Color("#22305a").lerp(Color("#0b0a1a"), 0.3))
	_draw_trees(Color("#16203a"), 150, 0.8, 3)
	_draw_trees(Color("#1b2846"), 200, 1.0, 7)
	# giant tree
	var trunk := Color("#2a1f2e")
	draw_rect(Rect2(290, 40, 80, 300), trunk)
	draw_rect(Rect2(270, 120, 120, 14), trunk)
	draw_rect(Rect2(230, 170, 200, 12), trunk)
	draw_rect(Rect2(250, 90, 160, 10), trunk)
	for b in [[Vector2(140, 60), 120], [Vector2(410, 70), 130], [Vector2(200, 20), 260]]:
		draw_rect(Rect2(b[0], Vector2(b[1], 40)), Color("#1f3326"))
		draw_rect(Rect2(b[0] + Vector2(10, -12), Vector2(b[1] - 20, 14)), Color("#1f3326"))
	# houses on branches; windows light up as regions open
	var lit := GameState.act_unlocked_count()
	var houses := [Vector2(238, 150), Vector2(392, 150), Vector2(270, 100), Vector2(360, 70), Vector2(300, 20),
			Vector2(214, 196), Vector2(412, 196), Vector2(250, 60), Vector2(380, 104)]
	for i in houses.size():
		_house(houses[i], i < lit)
	# ground
	var ground_y := 296.0
	draw_rect(Rect2(0, ground_y, 640, 80), Color("#241c30"))
	draw_rect(Rect2(0, ground_y - 2, 640, 4), Color("#7fd67a"))
	draw_rect(Rect2(0, ground_y + 2, 640, 1), Color("#3f7a46"))
	# stations
	_glow(MARKET_POS + Vector2(0, -20), Color("#ffc94d"), 0.6)
	_tex_scaled("icon_stall", MARKET_POS + Vector2(0, -16), 3.0)
	_glow(SHRINE_POS, Color("#9cffe9"), 0.9 + 0.08 * sin(_t * 2.0))
	_tex_scaled("icon_tree", SHRINE_POS + Vector2(0, 10), 4.0)
	_glow(FIRE_POS, Color("#ff9a4a"), 0.8 + 0.1 * sin(_t * 9.0))
	_tex_scaled("campfire", FIRE_POS, 2.0)
	var hero := "hero_1" if int(_t * 2.0) % 6 == 0 else "hero_0"
	_tex_scaled(hero, FIRE_POS + Vector2(-34, 2 + sin(_t * 2.0)), 2.0)


func _draw_trees(c: Color, base_y: float, scale_: float, seed_: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var x := -20.0
	while x < 660:
		var tw := rng.randf_range(24, 50) * scale_
		var th := rng.randf_range(60, 130) * scale_
		draw_rect(Rect2(x + tw * 0.42, base_y - th * 0.5, tw * 0.16, 300), c)
		for i in 4:
			var ww := tw * (0.5 + 0.125 * (i + 1))
			draw_rect(Rect2(x + (tw - ww) / 2.0, base_y - th + i * th * 0.12, ww, th * 0.14), c)
		x += tw * rng.randf_range(0.8, 1.2)
	draw_rect(Rect2(0, base_y, 640, 200), c)


func _house(p: Vector2, lit: bool) -> void:
	draw_rect(Rect2(p + Vector2(-12, -14), Vector2(24, 16)), Color("#4a3428") if lit else Color("#2e2430"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-15, -14), p + Vector2(15, -14), p + Vector2(0, -26)]),
			Color("#7a3a3a") if lit else Color("#3a2a36"))
	var w := Color("#ffd27a") if lit else Color("#1a1424")
	draw_rect(Rect2(p + Vector2(-7, -9), Vector2(5, 5)), w)
	draw_rect(Rect2(p + Vector2(3, -9), Vector2(5, 5)), w)
	if lit:
		_glow(p + Vector2(0, -6), Color("#ffb84d"), 0.25)


func _glow(p: Vector2, c: Color, s: float) -> void:
	var tex := DB.glow_tex()
	var size := tex.get_size() * s
	draw_texture_rect(tex, Rect2(p - size / 2, size), false, Color(c, 0.35))


func _tex_scaled(sprite_name: String, p: Vector2, s: float) -> void:
	var tex := DB.tex(sprite_name)
	var size := tex.get_size() * s
	draw_texture_rect(tex, Rect2(p - Vector2(size.x / 2, size.y), size), false)


# --- UI --------------------------------------------------------------------

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	_wallet_box = HBoxContainer.new()
	_wallet_box.position = Vector2(6, 4)
	_wallet_box.add_theme_constant_override("separation", 10)
	root.add_child(_wallet_box)
	_refresh_wallet()
	var gear := UIKit.button("=", func() -> void: _settings_panel.visible = not _settings_panel.visible, Color("#2e2752"), 12)
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.position = Vector2(-28, 4)
	gear.custom_minimum_size = Vector2(22, 20)
	root.add_child(gear)

	var market := VBoxContainer.new()
	market.position = MARKET_POS + Vector2(-60, 8)
	market.custom_minimum_size = Vector2(120, 0)
	root.add_child(market)
	var ml := UIKit.label(GameState.t("market"), 12, UIKit.C_AMBER)
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market.add_child(ml)
	_market_label = UIKit.label("", 10)
	_market_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	market.add_child(_market_label)
	_market_bar = ProgressBar.new()
	_market_bar.show_percentage = false
	_market_bar.custom_minimum_size = Vector2(100, 6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#ffc94d")
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color("#2a2140")
	_market_bar.add_theme_stylebox_override("fill", fill)
	_market_bar.add_theme_stylebox_override("background", bgs)
	market.add_child(_market_bar)

	var skills := UIKit.button(GameState.t("skills"), func() -> void: main.open_skill_tree(), Color("#1f5a5a"), 13)
	skills.position = SHRINE_POS + Vector2(-60, 54)
	skills.custom_minimum_size = Vector2(120, 26)
	root.add_child(skills)
	var go := UIKit.button(GameState.t("expedition"), _open_regions, Color("#7a3a1a"), 13)
	go.position = FIRE_POS + Vector2(-60, 22)
	go.custom_minimum_size = Vector2(120, 26)
	root.add_child(go)
	_build_regions(root)
	_build_settings(root)


func _refresh_wallet() -> void:
	for c in _wallet_box.get_children():
		c.queue_free()
	for cur in DB.economy.currencies:
		if cur == "amber" or GameState.wallet[cur] > 0.0:
			_wallet_box.add_child(UIKit.currency_row(cur))


func _on_sold(v: float) -> void:
	Audio.play("sell", 1.0 + randf() * 0.1, -4.0)
	var l := UIKit.label("+" + GameState.fmt(v), 10, UIKit.C_AMBER)
	l.position = MARKET_POS + Vector2(randf_range(-20, 10), -50)
	ui.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 22, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _open_regions() -> void:
	_regions_panel.visible = true
	UIKit.pop(_regions_panel, 1.05)


func _build_regions(root: Control) -> void:
	_regions_panel = UIKit.panel(Color("#7a6fb0"))
	_regions_panel.set_anchors_preset(Control.PRESET_CENTER)
	_regions_panel.position = Vector2(-250, -150)
	_regions_panel.custom_minimum_size = Vector2(500, 300)
	_regions_panel.visible = false
	root.add_child(_regions_panel)
	var v := VBoxContainer.new()
	_regions_panel.add_child(v)
	var head := HBoxContainer.new()
	var title := UIKit.label(GameState.t("choose_region"), 13, UIKit.C_AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.button("X", func() -> void: _regions_panel.visible = false, Color("#5a2a2a")))
	v.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for r in DB.regions.size():
		grid.add_child(_region_card(r))


func _region_card(r: int) -> Control:
	var reg: Dictionary = DB.regions[r]
	var open := GameState.is_region_unlocked(r)
	var nums := DB.region_numbers(r)
	var b := Button.new()
	b.custom_minimum_size = Vector2(158, 80)
	b.disabled = not open
	var col := Color(reg.colors.accent) if open else Color("#3a3550")
	b.add_theme_stylebox_override("normal", UIKit.panel_style(col.darkened(0.2), Color(reg.colors.bg)))
	b.add_theme_stylebox_override("hover", UIKit.panel_style(col, Color(reg.colors.mid)))
	b.add_theme_stylebox_override("pressed", UIKit.panel_style(col, Color(reg.colors.bg).darkened(0.2)))
	b.add_theme_stylebox_override("disabled", UIKit.panel_style(Color("#3a3550"), Color("#141029")))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = Vector2(6, 6)
	b.add_child(h)
	var ic := UIKit.icon("creature_" + reg.id, 2.0)
	ic.modulate = Color.WHITE if open else Color(0.3, 0.3, 0.4)
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	var name_l := UIKit.label(DB.region_name(r), 11, Color(reg.colors.accent) if open else UIKit.C_DIM)
	name_l.custom_minimum_size = Vector2(110, 0)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(name_l)
	if open:
		var vrow := HBoxContainer.new()
		vrow.add_child(UIKit.icon("icon_coin"))
		vrow.add_child(UIKit.label("%s %s" % [GameState.fmt(nums.value * GameState.stat("value_mult")), GameState.t("per_creature")], 10))
		tv.add_child(vrow)
		var rrow := HBoxContainer.new()
		rrow.add_child(UIKit.icon(UIKit.CURRENCY_ICON[nums.resource]))
		tv.add_child(rrow)
	else:
		tv.add_child(UIKit.label(GameState.t("locked"), 10, UIKit.C_DIM))
	b.pressed.connect(func() -> void:
		Audio.play("tap")
		main.start_expedition(r))
	return b


func _build_settings(root: Control) -> void:
	_settings_panel = UIKit.panel(Color("#7a6fb0"))
	_settings_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_settings_panel.position = Vector2(-190, 28)
	_settings_panel.custom_minimum_size = Vector2(180, 0)
	_settings_panel.visible = false
	root.add_child(_settings_panel)
	var v := VBoxContainer.new()
	_settings_panel.add_child(v)
	for key in ["sfx", "shake", "flash"]:
		v.add_child(UIKit.label(GameState.t(key), 10))
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.1
		s.value = float(GameState.settings[key])
		s.custom_minimum_size = Vector2(160, 14)
		s.value_changed.connect(func(val: float) -> void:
			GameState.settings[key] = val
			GameState.mark_dirty())
		v.add_child(s)
	var lang_btn := UIKit.button("EN / RU", func() -> void:
		GameState.lang = "ru" if GameState.lang == "en" else "en"
		GameState.mark_dirty()
		main.show_village())
	v.add_child(lang_btn)


func _toast(text: String) -> void:
	var p := UIKit.panel(UIKit.C_AMBER)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position = Vector2(-150, 40)
	p.custom_minimum_size = Vector2(300, 0)
	var l := UIKit.label(text, 11, UIKit.C_AMBER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	ui.add_child(p)
	Audio.play("coin")
	var tw := p.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func _ending() -> void:
	var p := UIKit.panel(UIKit.C_AMBER)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-170, -70)
	p.custom_minimum_size = Vector2(340, 140)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var l := UIKit.label(GameState.t("the_end"), 12)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(320, 0)
	v.add_child(l)
	v.add_child(UIKit.label(GameState.t("thanks"), 13, UIKit.C_AMBER))
	var mins := int(GameState.totals.play_time / 60.0)
	v.add_child(UIKit.label("%d min · %d runs · %d caught" % [mins, GameState.totals.runs, GameState.totals.caught], 10, UIKit.C_DIM))
	v.add_child(UIKit.button(GameState.t("continue"), p.queue_free))
	ui.add_child(p)
