class_name Expedition
extends Node2D
## One expedition into a region: spawns, oil, haul, effects, end conditions.

const RARE_HP := {"normal": 1.0, "silver": 1.5, "gold": 2.0, "rainbow": 3.0}

var main: Node
var region_index := 0
var region: Dictionary
var nums: Dictionary
var arena: Arena
var player: Player
var lit_layer: CanvasLayer
var fx_layer: CanvasLayer
var hud: Hud
var camera: Camera2D
var creatures: Array[Creature] = []
var blocks: Array[Block] = []
var haul_creatures: Array = []
var haul_res := 0.0
var rare_count := 0
var thrown := 0
var hits := 0
var wall_hits := 0
var oil := 0.0
var oil_max := 0.0
var drain := 1.0
var wind := Vector2.ZERO
var light_scale := 1.0
var elapsed := 0.0
var ended := false
var camp_pos := Vector2.ZERO
var _spawn_acc := 0.0
var _block_acc := 0.0
var _trauma := 0.0
var _combo := 0
var _combo_t := 0.0
var _low_t := 0.0
var _burn_cd := 0.0
var _tut := -1
var creature_speed := 1.0
var _spore_t := 0.0
var _spores: Array = []


func _ready() -> void:
	region = DB.regions[region_index]
	nums = DB.region_numbers(region_index)
	GameState.in_expedition = true
	GameState.last_region = region_index
	arena = Arena.new()
	arena.generate(region, randi() % 2)
	var area := arena.size_px()

	var sky := ColorRect.new()
	sky.color = Color(region.colors.bg).darkened(0.25)
	sky.position = -area
	sky.size = area * 3
	sky.z_index = -20
	add_child(sky)
	for i in 2:
		var px := Parallax2D.new()
		px.scroll_scale = Vector2(0.3 + 0.25 * i, 0.5 + 0.25 * i)
		px.z_index = -10 + i
		var b := Backdrop.new()
		b.setup(Color(region.colors.bg if i == 0 else region.colors.mid), area, i, hash(region.id))
		px.add_child(b)
		add_child(px)
	add_child(arena)

	var cm := CanvasModulate.new()
	cm.color = Color(region.colors.light).lightened(0.45)
	if region.twist == "fog":
		cm.color = cm.color.darkened(0.35)
		light_scale = 0.8
	add_child(cm)

	lit_layer = CanvasLayer.new()
	lit_layer.follow_viewport_enabled = true
	lit_layer.layer = 1
	add_child(lit_layer)
	fx_layer = lit_layer
	var rims := Node2D.new()
	rims.draw.connect(func() -> void: arena.draw_rims(rims))
	lit_layer.add_child(rims)
	rims.modulate = Color(1, 1, 1, 0.85)

	camp_pos = arena.cell_center(arena.camp_cell)
	var fire := Sprite2D.new()
	fire.texture = DB.tex("campfire")
	fire.position = camp_pos + Vector2(0, 4)
	add_child(fire)
	var fire_light := PointLight2D.new()
	fire_light.texture = DB.glow_tex()
	fire_light.color = Color("#ff9a4a")
	fire_light.texture_scale = 2.2
	fire_light.energy = 1.3
	fire_light.position = camp_pos
	add_child(fire_light)

	player = Player.new()
	player.setup(self, camp_pos + Vector2(0, -16))
	add_child(player)
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(area.x)
	camera.limit_bottom = int(area.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)

	oil_max = GameState.stat("oil_max")
	oil = oil_max
	drain = GameState.stat("oil_drain") * float(region.oil_drain_mult)
	if region.twist == "underwater":
		player.speed_mult = 0.8
	_ambient()

	for i in int(GameState.stat("helper_moths")):
		var h := Helper.new()
		h.setup(self, "moth", i)
		lit_layer.add_child(h)
	for i in int(GameState.stat("helper_beetles")):
		var h := Helper.new()
		h.setup(self, "beetle", i)
		lit_layer.add_child(h)

	hud = Hud.new()
	hud.ex = self
	add_child(hud)

	for i in int(GameState.stat("creature_cap")):
		_spawn_creature()
	for i in int(GameState.stat("block_cap")) / 2 + 1:
		_spawn_block()
	hint(DB.region_name(region_index), Color(region.colors.accent))
	Audio.play_music("expedition")
	if GameState.totals.runs == 0 and region_index == 0:
		_tut = 0
		_tutorial_step()
	Audio.set_muffled(false)


func _process(delta: float) -> void:
	_shake_update(delta)
	if ended:
		return
	elapsed += delta
	oil -= drain * delta
	var near_camp := player.global_position.distance_to(camp_pos) < 40.0
	hud.show_return(near_camp and elapsed > 1.5)
	if near_camp and GameState.stat("camp_refill") >= 1.0:
		oil = minf(oil_max, oil + 8.0 * delta)
	if near_camp and elapsed > 1.5 and Input.is_action_just_pressed("interact"):
		finish(false)
		return
	if oil < oil_max * 0.25:
		_low_t -= delta
		if _low_t <= 0.0:
			Audio.play("low_oil")
			if _low_t > -1.0:
				Audio.set_muffled(true)
			hint(GameState.t("low_light"), Color("#ff9a6a"))
			_low_t = 3.0
	if oil <= 0.0:
		finish(true)
		return

	_spawn_acc += GameState.stat("spawn_rate") * delta
	while _spawn_acc >= 1.0:
		_spawn_acc -= 1.0
		if creatures.size() < int(GameState.stat("creature_cap")):
			_spawn_creature()
	_block_acc += GameState.stat("block_spawn_rate") * delta
	while _block_acc >= 1.0:
		_block_acc -= 1.0
		if blocks.size() < int(GameState.stat("block_cap")):
			_spawn_block()

	_combo_t -= delta
	if _combo_t <= 0.0:
		_combo = 0
	match region.twist:
		"sway":
			creature_speed = 1.0 + 1.2 * maxf(0.0, sin(elapsed * 0.7))
		"bouncy":
			_spore_update(delta)
		"wind":
			wind = Vector2(sin(elapsed * 0.45) * 70.0, 0)
		"burning":
			_burn_cd -= delta
			for c in creatures:
				if _burn_cd <= 0.0 and c.position.distance_to(player.global_position) < 11.0:
					oil -= 2.0
					player.velocity += (player.global_position - c.position).normalized() * 160.0
					shake(0.35)
					float_text(player.global_position + Vector2(0, -14), "-2", Color("#ff6a3d"), true)
					Audio.play("hit", 0.7)
					_burn_cd = 1.0


# --- Spawning ------------------------------------------------------------

func _spawn_creature() -> void:
	var pos := arena.random_open_point(player.global_position if player else Vector2.INF, 70.0)
	var r := randf()
	var rarity := "normal"
	var rb := GameState.stat("rainbow_chance")
	var gd := GameState.stat("gold_chance")
	if r < rb:
		rarity = "rainbow"
	elif r < rb + gd:
		rarity = "gold"
	elif r < rb + gd + GameState.stat("silver_chance"):
		rarity = "silver"
	var mult: float = 1.0 if rarity == "normal" else float(DB.economy.rarity[rarity].mult)
	var c := Creature.new()
	c.setup(self, pos, nums.hp * RARE_HP[rarity], nums.value * mult, rarity, Color(region.colors.accent),
			"creature_" + region.id)
	c.burns = region.twist == "burning"
	lit_layer.add_child(c)
	creatures.append(c)
	c.scale = Vector2.ZERO
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_block() -> void:
	if arena.floor_cells.is_empty():
		return
	for i in 20:
		var cell: Vector2i = arena.floor_cells[randi() % arena.floor_cells.size()]
		var taken := false
		for b in blocks:
			if absi(b.cell.x - cell.x) < 2 and absi(b.cell.y - cell.y) < 2:
				taken = true
		if taken or (player and arena.cell_center(cell).distance_to(player.global_position) < 40.0):
			continue
		var b := Block.new()
		b.setup(self, cell, nums.block_hp, "block_" + region.block)
		lit_layer.add_child(b)
		blocks.append(b)
		return


# --- Queries -------------------------------------------------------------

func nearest_creature(pos: Vector2, max_dist: float, need_los := false) -> Creature:
	var best: Creature = null
	var bd := max_dist
	for c in creatures:
		var d := c.position.distance_to(pos)
		if d < bd and (not need_los or arena.has_los(pos, c.position)):
			bd = d
			best = c
	return best


func nearest_block(pos: Vector2, max_dist: float, exclude: Array = []) -> Block:
	var best: Block = null
	var bd := max_dist
	for b in blocks:
		if b in exclude:
			continue
		var d := b.global_position.distance_to(pos)
		if d < bd:
			bd = d
			best = b
	return best


func backpack_capacity() -> int:
	return int(GameState.stat("inv_slots")) * int(GameState.stat("slot_capacity"))


func backpack_full() -> bool:
	return haul_creatures.size() >= backpack_capacity()


# --- Events --------------------------------------------------------------

func on_creature_caught(c: Creature) -> void:
	creatures.erase(c)
	_combo += 1
	_combo_t = 2.0
	haul_creatures.append(c.value)
	if randf() < GameState.stat("double_catch"):
		haul_creatures.append(c.value)
		float_text(c.position + Vector2(0, -20), "x2", Color("#7fe07a"), true)
	oil = minf(oil_max, oil + GameState.stat("oil_per_catch"))
	burst(c.position, c.accent, 14, 90.0)
	_fly_to_player(c)
	if c.rarity != "normal":
		rare_count += 1
		Audio.play("rare")
		hint(GameState.t("rare"), Color("#ffd34d"))
		hud.flash(Color(1, 0.95, 0.6, 0.35))
		hitstop(0.08)
		shake(0.45)
	else:
		Audio.play("catch", 1.0 + mini(_combo, 12) * 0.06, -2.0, 0.0)
		shake(0.12)
	hud.bump_backpack()
	if _tut == 0:
		_tut = 1
		_tutorial_step()


func on_block_broken(b: Block) -> void:
	blocks.erase(b)
	var amount: float = nums.res_per_block * GameState.stat("resource_mult")
	var n := clampi(int(ceil(amount)), 1, 8)
	for i in n:
		var p := Pickup.new()
		p.setup(self, b.global_position + Vector2(0, -4), nums.resource, amount / n)
		lit_layer.add_child(p)
	var col := {"wood": Color("#d9a066"), "crystal": Color("#7ad0ff"), "pollen": Color("#ffd34d")}
	burst(b.global_position, col.get(nums.resource, Color.WHITE), 18, 110.0)
	Audio.play("break")
	shake(0.3)
	if randf() < GameState.stat("drill_burst_chance"):
		puff(b.global_position, Color("#ffb84d"), 20)
		for other in blocks.duplicate():
			if other.global_position.distance_to(b.global_position) < 44.0:
				other.damage(other.max_hp * 0.5)


func on_pickup(p: Pickup) -> void:
	haul_res += p.amount
	if _tut == 1:
		_tut = 2
		_tutorial_step()
	Audio.play("pickup", 1.0 + randf() * 0.2)
	hud.bump_resource()


func finish(fainted: bool) -> void:
	if ended:
		return
	ended = true
	GameState.in_expedition = false
	var kept: Array = haul_creatures.duplicate()
	var res := haul_res
	if fainted:
		var keep := clampf(GameState.stat("keep_on_faint"), 0.0, 1.0)
		kept.shuffle()
		kept = kept.slice(0, int(floor(kept.size() * keep)))
		res *= keep
		Audio.play("faint")
		player.sprite.texture = DB.tex("icon_shield")
		shake(0.5)
	GameState.queue_creatures(kept)
	GameState.add(nums.resource, res)
	GameState.totals.runs += 1
	GameState.totals.caught += kept.size()
	GameState.totals.rare += rare_count
	GameState.save_game()
	var summary := {
		"region": region_index, "fainted": fainted, "time": elapsed, "caught": kept.size(),
		"lost": haul_creatures.size() - kept.size(), "rare": rare_count, "resource": nums.resource, "res": res,
		"value": kept.reduce(func(a, v): return a + float(v), 0.0) * GameState.stat("value_mult"),
	}
	await get_tree().create_timer(0.9 if fainted else 0.3).timeout
	main.show_results(summary)


func _tutorial_step() -> void:
	var key: String = ["tut_catch", "tut_mine", "tut_return"][_tut]
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(hud):
		hint(GameState.t(key), Color("#9cffe9"))


## Glowshroom Hollow: spore clouds drift in and slow the hedgehog down.
func _spore_update(delta: float) -> void:
	_spore_t -= delta
	if _spore_t <= 0.0:
		_spore_t = 3.5
		var p := arena.random_open_point(player.global_position, 40.0)
		_spores.append([p, 6.0])
		var cloud := CPUParticles2D.new()
		cloud.amount = 24
		cloud.lifetime = 2.0
		cloud.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		cloud.emission_sphere_radius = 22.0
		cloud.spread = 180
		cloud.gravity = Vector2.ZERO
		cloud.initial_velocity_min = 2
		cloud.initial_velocity_max = 8
		cloud.scale_amount_max = 3.0
		cloud.color = Color("#ff8cf0", 0.5)
		cloud.position = p
		fx_layer.add_child(cloud)
		get_tree().create_timer(6.0).timeout.connect(cloud.queue_free)
	var slowed := false
	for s in _spores:
		s[1] -= delta
		if s[1] > 0.0 and (s[0] as Vector2).distance_to(player.global_position) < 30.0:
			slowed = true
	_spores = _spores.filter(func(s): return s[1] > 0.0)
	if slowed and player.speed_mult > 0.6:
		hint(GameState.t("spores"), Color("#ff8cf0"))
	player.speed_mult = 0.5 if slowed else 1.0


# --- Effects -------------------------------------------------------------

func _ambient() -> void:
	var p := CPUParticles2D.new()
	var area := arena.size_px()
	p.amount = 40
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = area / 2
	p.position = area / 2
	p.direction = Vector2.UP
	p.spread = 60
	p.gravity = Vector2(0, -6 if region.twist == "underwater" else 0)
	p.initial_velocity_min = 3
	p.initial_velocity_max = 10
	p.scale_amount_min = 1
	p.scale_amount_max = 2
	p.color = Color(region.colors.accent, 0.55)
	lit_layer.add_child(p)


func burst(pos: Vector2, color: Color, n := 10, speed := 80.0, life := 0.5) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = n
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 180
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 140)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.5
	p.color = color
	p.position = pos
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


func puff(pos: Vector2, color: Color, n := 7) -> void:
	burst(pos, color, n, 45.0, 0.3)


func sparks(pos: Vector2) -> void:
	burst(pos, Color("#bfeaff"), 4, 70.0, 0.25)


func _fly_to_player(c: Creature) -> void:
	var s := Sprite2D.new()
	s.texture = c.sprite.texture
	s.modulate = c.sprite.modulate
	s.position = c.position
	fx_layer.add_child(s)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position", player.global_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(s, "scale", Vector2(0.3, 0.3), 0.35)
	tw.chain().tween_callback(s.queue_free)


func float_text(pos: Vector2, text: String, color := Color.WHITE, big := false) -> void:
	var l := UIKit.label(text, 12 if big else 9, color)
	l.position = pos - Vector2(20, 8)
	l.size = Vector2(40, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx_layer.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 16, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


func hint(text: String, color := Color.WHITE) -> void:
	if hud:
		hud.hint(text, color)


func shake(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount * float(GameState.settings.shake))


func _shake_update(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	if camera:
		var s := _trauma * _trauma * 7.0
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))


func hitstop(duration: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
