extends Node
## Mutable player state: wallet, skill levels, market, settings, save/load.
## Stat formulas mirror tools/economy_sim.py — keep them in sync.

signal wallet_changed
signal skills_changed
signal sold(value: float)

const SAVE_PATH := "user://save.json"
const OFFLINE_CAP_SECONDS := 8 * 3600

const UI := {
	"en": {
		"market": "Market", "skills": "Skill Tree", "expedition": "Expedition", "choose_region": "Choose a region",
		"locked": "Locked", "per_creature": "each", "selling": "Selling", "queue_empty": "Nothing to sell",
		"return": "Return", "backpack_full": "Backpack full!", "low_light": "Light is running out!",
		"results": "Expedition over", "fainted": "Your light went out... you curled up and lost part of the haul.",
		"caught": "Caught", "time": "Time", "continue": "Continue", "buy": "Buy", "maxed": "MAX",
		"level": "Lvl", "close": "Close", "offline": "While you slept the market earned", "settings": "Settings",
		"shake": "Screen shake", "flash": "Flashes", "sfx": "Sound", "leave": "Leave expedition", "resume": "Resume",
		"rare": "Rare!", "the_end": "The forest shines again. Burr curls up under the World Tree and falls asleep.",
		"thanks": "Thank you for playing!", "next": "Next", "new_region": "New region unlocked!",
	},
	"ru": {
		"market": "Рынок", "skills": "Дерево навыков", "expedition": "Поход", "choose_region": "Выбери регион",
		"locked": "Закрыто", "per_creature": "за штуку", "selling": "Продаётся", "queue_empty": "Нечего продавать",
		"return": "Вернуться", "backpack_full": "Рюкзак полон!", "low_light": "Свет заканчивается!",
		"results": "Поход окончен", "fainted": "Фонарь погас... ёжик свернулся клубком и растерял часть добычи.",
		"caught": "Поймано", "time": "Время", "continue": "Дальше", "buy": "Купить", "maxed": "МАКС",
		"level": "Ур.", "close": "Закрыть", "offline": "Пока ты спал, рынок заработал", "settings": "Настройки",
		"shake": "Тряска экрана", "flash": "Вспышки", "sfx": "Звук", "leave": "Покинуть поход", "resume": "Продолжить",
		"rare": "Редкое!", "the_end": "Лес снова светится. Ёжик сворачивается клубком у Мирового древа и засыпает.",
		"thanks": "Спасибо за игру!", "next": "Дальше", "new_region": "Открыт новый регион!",
	},
}

var wallet: Dictionary = {}
var levels: Dictionary = {}
var market_queue: Array = []
var sell_progress := 0.0
var stats: Dictionary = {}
var lang := "en"
var settings := {"shake": 1.0, "flash": 1.0, "sfx": 1.0, "music": 0.8}
var totals := {"runs": 0, "caught": 0, "rare": 0, "play_time": 0.0}
var finished := false
var last_region := 0
var in_expedition := false
var offline_income := 0.0

var _save_timer := 0.0
var _dirty := false


func _ready() -> void:
	lang = "ru" if OS.get_locale_language() == "ru" else "en"
	_setup_input()
	reset()
	load_game()
	recompute()


func t(key: String) -> String:
	return UI[lang].get(key, key)


func reset() -> void:
	wallet = {}
	for c in DB.economy.currencies:
		wallet[c] = 0.0
	levels = {}
	for n in DB.nodes:
		levels[n.id] = 0
	levels["first_light"] = 1
	market_queue = []
	sell_progress = 0.0
	finished = false
	last_region = 0
	totals = {"runs": 0, "caught": 0, "rare": 0, "play_time": 0.0}


# --- Stats ---------------------------------------------------------------

func compute_stats(lv: Dictionary) -> Dictionary:
	var base: Dictionary = DB.economy.base_stats
	var floor_: Dictionary = DB.economy.stat_floor
	var add := {}
	var pct := {}
	for k in base:
		add[k] = 0.0
		pct[k] = 0.0
	for id in lv:
		var l: int = lv[id]
		if l <= 0:
			continue
		var node: Dictionary = DB.node_by_id[id]
		var ty: Dictionary = DB.type_of(node)
		var stat = ty.get("stat")
		if stat == null:
			continue
		if ty.mode == "add":
			add[stat] += float(node.amount) * l
		else:
			pct[stat] += float(node.amount) * l
	var out := {}
	for k in base:
		var v: float = (float(base[k]) + add[k]) * maxf(0.0, 1.0 + pct[k])
		if floor_.has(k):
			v = maxf(v, float(floor_[k]) * float(base[k]))
		out[k] = v
	return out


func recompute() -> void:
	stats = compute_stats(levels)
	skills_changed.emit()


func stat(key: String) -> float:
	return stats.get(key, 0.0)


# --- Skill tree ----------------------------------------------------------

func level(id: String) -> int:
	return levels.get(id, 0)


func is_available(id: String) -> bool:
	var p = DB.node_by_id[id].parent
	return p == null or level(p) > 0


func is_maxed(id: String) -> bool:
	return level(id) >= int(DB.node_by_id[id].max)


func next_cost(id: String) -> Array:
	return DB.node_cost(DB.node_by_id[id], level(id))


func can_buy(id: String) -> bool:
	if not is_available(id) or is_maxed(id):
		return false
	var c := next_cost(id)
	return wallet[c[0]] >= c[1]


func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	var c := next_cost(id)
	wallet[c[0]] -= c[1]
	levels[id] += 1
	if DB.node_by_id[id].type == "path_final":
		finished = true
	recompute()
	wallet_changed.emit()
	mark_dirty()
	return true


func is_region_unlocked(r: int) -> bool:
	var u = DB.regions[r].unlock
	return u == null or level(u) > 0


func act_unlocked_count() -> int:
	var n := 0
	for r in DB.regions.size():
		if is_region_unlocked(r):
			n += 1
	return n


# --- Wallet & market -----------------------------------------------------

func add(cur: String, amount: float) -> void:
	wallet[cur] += amount
	wallet_changed.emit()
	mark_dirty()


func queue_creatures(values: Array) -> void:
	market_queue.append_array(values)
	mark_dirty()


func market_rate() -> float:
	return stat("market_slots") / stat("market_sell_time")


func _process(delta: float) -> void:
	totals.play_time += delta
	var mult := stat("night_shift") if in_expedition else 1.0
	if not market_queue.is_empty() and mult > 0.0:
		sell_progress += delta * market_rate() * mult
		while sell_progress >= 1.0 and not market_queue.is_empty():
			sell_progress -= 1.0
			_sell_one()
		if market_queue.is_empty():
			sell_progress = 0.0
	if _dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_game()


func _sell_one() -> void:
	var v: float = float(market_queue.pop_front()) * stat("value_mult")
	if randf() < stat("market_extra_chance"):
		v *= 2.0
	wallet.amber += v
	sold.emit(v)
	wallet_changed.emit()
	mark_dirty()


func _offline_sell(seconds: float) -> float:
	var n := mini(market_queue.size(), int(seconds * market_rate()))
	var total := 0.0
	for i in n:
		total += float(market_queue[i]) * stat("value_mult") * (1.0 + stat("market_extra_chance"))
	market_queue = market_queue.slice(n)
	wallet.amber += total
	return total


# --- Save / load ---------------------------------------------------------

func mark_dirty() -> void:
	if not _dirty:
		_save_timer = 2.0
	_dirty = true


func save_game() -> void:
	_dirty = false
	var lv := {}
	for id in levels:
		if levels[id] > 0:
			lv[id] = levels[id]
	var data := {
		"version": 1, "time": Time.get_unix_time_from_system(), "wallet": wallet, "levels": lv,
		"market_queue": market_queue, "totals": totals, "settings": settings, "finished": finished,
		"last_region": last_region, "lang": lang,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	for c in data.get("wallet", {}):
		wallet[c] = float(data.wallet[c])
	for id in data.get("levels", {}):
		if levels.has(id):
			levels[id] = int(data.levels[id])
	market_queue = data.get("market_queue", [])
	for k in data.get("totals", {}):
		totals[k] = data.totals[k]
	for k in data.get("settings", {}):
		settings[k] = data.settings[k]
	finished = data.get("finished", false)
	last_region = int(data.get("last_region", 0))
	lang = data.get("lang", lang)
	recompute()
	var away: float = clampf(Time.get_unix_time_from_system() - float(data.get("time", 0)), 0, OFFLINE_CAP_SECONDS)
	offline_income = _offline_sell(away)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


# --- Formatting & input --------------------------------------------------

func fmt(x: float) -> String:
	var units := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var i := 0
	while absf(x) >= 1000.0 and i < units.size() - 1:
		x /= 1000.0
		i += 1
	if i == 0:
		return str(int(floorf(x)))
	return ("%.2f" if absf(x) < 10 else ("%.1f" if absf(x) < 100 else "%.0f")) % x + units[i]


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN], "sling": [KEY_J, KEY_Z], "drill": [KEY_K, KEY_X],
		"interact": [KEY_E, KEY_SPACE], "skills": [KEY_TAB], "pause": [KEY_ESCAPE],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
