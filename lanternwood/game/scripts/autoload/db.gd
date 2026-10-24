extends Node
## Read-only game data: balance, regions, skill tree, sprite atlas. Loaded once from res://data.

var economy: Dictionary
var regions: Array
var acts: Array
var finale: Dictionary
var types: Dictionary
var branches: Dictionary
var nodes: Array
var node_by_id: Dictionary
var children: Dictionary

var _atlas: Texture2D
var _atlas_meta: Dictionary
var _tex_cache: Dictionary = {}
var _glow: Texture2D


func _ready() -> void:
	economy = _json("res://data/economy.json")
	var r: Dictionary = _json("res://data/regions.json")
	regions = r.regions
	acts = r.acts
	finale = r.finale
	var s: Dictionary = _json("res://data/skills.json")
	types = s.types
	branches = s.branches
	nodes = s.nodes
	for n in nodes:
		node_by_id[n.id] = n
		children[n.id] = []
	for n in nodes:
		if n.parent != null:
			children[n.parent].append(n.id)
	_atlas = load("res://assets/gen/atlas.png")
	_atlas_meta = _json("res://assets/gen/atlas.json")


func _json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "Missing data file " + path)
	return JSON.parse_string(f.get_as_text())


func tex(sprite_name: String) -> Texture2D:
	if _tex_cache.has(sprite_name):
		return _tex_cache[sprite_name]
	var m: Array = _atlas_meta.get(sprite_name, _atlas_meta["icon_star"])
	var t := AtlasTexture.new()
	t.atlas = _atlas
	t.region = Rect2(m[0], m[1], m[2], m[3])
	_tex_cache[sprite_name] = t
	return t


## Soft round light/glow texture shared by lights and additive glows.
func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.35))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


func region_index(id: String) -> int:
	for i in regions.size():
		if regions[i].id == id:
			return i
	return -1


func act_resource(r: int) -> String:
	return acts[int(regions[r].act)].resource


## Numbers for region r (0..8); same formulas as tools/economy_sim.py.
func region_numbers(r: int) -> Dictionary:
	var s: Dictionary = economy.region_scaling
	return {
		"value": s.creature_value.base * pow(s.creature_value.growth, r),
		"hp": s.creature_hp.base * pow(s.creature_hp.growth, r),
		"block_hp": s.block_hp.base * pow(s.block_hp.growth, r),
		"res_per_block": int(s.resource_per_block[r % 3]),
		"resource": act_resource(r),
	}


func node_cost(node: Dictionary, level: int) -> Array:
	var c: Array = node.cost
	return [c[0], roundf(float(c[1]) * pow(float(c[2]), level))]


func type_of(node: Dictionary) -> Dictionary:
	return types[node.type]


func region_name(r: int) -> String:
	return regions[r]["name_" + GameState.lang]


func node_name(node: Dictionary) -> String:
	var t := type_of(node)
	var s: String = t["name_" + GameState.lang]
	if node.has("region"):
		s = s.replace("{region}", region_name(region_index(node.region)))
	return s


func node_desc(node: Dictionary, level: int) -> String:
	var t := type_of(node)
	var s: String = t["desc_" + GameState.lang]
	if node.has("region"):
		s = s.replace("{region}", region_name(region_index(node.region)))
	return s.replace("{v}", fmt_effect(t, float(node.amount) * max(level, 1)))


func fmt_effect(t: Dictionary, v: float) -> String:
	match t.fmt:
		"pct", "pct_neg":
			return "%s%%" % _num(absf(v) * 100.0)
		"chance":
			return "%s%%" % _num(v * 100.0)
		"sec":
			return ("%s с" if GameState.lang == "ru" else "%ss") % _num(v)
		"px":
			return _num(v)
		"mult":
			return "x%s" % _num(v)
		"num":
			return _num(v)
	return ""


func _num(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return String.num(v, 2).rstrip("0").rstrip(".")
