extends Node
## Headless smoke + logic tests.
## Run: godot --headless --path game res://tests/test_runner.tscn
## Prints "TESTS PASSED" / "TESTS FAILED" and exits with 0 / 1.

var failures: Array[String] = []
var main: Node


func check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)
		printerr("FAIL: ", what)


func _ready() -> void:
	GameState.reset()
	GameState.recompute()
	_unit_tests()
	await _smoke_test()
	_parity_dump()
	print("TESTS PASSED" if failures.is_empty() else "TESTS FAILED: %d" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)


func _unit_tests() -> void:
	check(DB.regions.size() == 9, "9 regions")
	check(DB.nodes.size() > 50, "skill nodes loaded")
	check(GameState.level("first_light") == 1, "root node owned on new game")
	check(is_equal_approx(GameState.stat("oil_max"), 25.0), "base oil")
	check(GameState.fmt(1234.0) == "1.23K", "fmt K: " + GameState.fmt(1234.0))
	check(GameState.fmt(56_700_000.0) == "56.7M", "fmt M: " + GameState.fmt(56_700_000.0))
	check(not GameState.can_buy("sling_1"), "cannot buy without amber")
	GameState.wallet.amber = 100.0
	check(GameState.buy("sling_1"), "buy sling_1")
	check(is_equal_approx(GameState.stat("sling_damage"), 2.0), "sling damage +1")
	check(is_equal_approx(GameState.wallet.amber, 95.0), "paid 5 amber")
	check(GameState.next_cost("sling_1")[1] == 8.0, "cost grows x1.6 -> 8")
	check(not GameState.can_buy("sling_2") or GameState.is_available("sling_2"), "child available after parent")
	check(not GameState.is_region_unlocked(1), "cloud forest locked")
	GameState.wallet.amber = 1000.0
	check(GameState.buy("path_cloud"), "buy path")
	check(GameState.is_region_unlocked(1), "cloud forest unlocked")
	var n := DB.region_numbers(3)
	check(is_equal_approx(n.value, 54.0), "region 4 creature value 2*3^3")
	GameState.reset()
	GameState.recompute()


func _smoke_test() -> void:
	main = load("res://scripts/main.gd").new()
	add_child(main)
	await _frames(30)
	check(main.current is Village, "starts in village")
	main.open_skill_tree()
	await _frames(10)
	check(main.overlay is SkillTree, "skill tree opens")
	main.overlay.close()
	await _frames(5)

	main.start_expedition(0)
	await _frames(40)
	var ex: Expedition = main.current
	check(ex is Expedition, "expedition started")
	check(ex.creatures.size() > 0, "creatures spawned")
	check(ex.blocks.size() > 0, "blocks spawned")
	ex.oil = 999.0
	ex.oil_max = 999.0
	# bot: hop next to a target (no pathfinding needed), hold the right tool
	for i in 24:
		var mining := i % 3 == 2
		ex.player.sling_held = not mining
		ex.player.drill_held = mining
		var target: Node2D = ex.nearest_block(ex.player.global_position, 9999.0) if mining else ex.nearest_creature(ex.player.global_position, 9999.0)
		if target:
			ex.player.global_position = target.global_position + (Vector2(0, -18) if mining else Vector2(-40, 0))
			ex.player.velocity = Vector2.ZERO
		await _secs(1.6 if mining else 0.6)
	print("bot haul: creatures=%d resource=%.1f thrown=%d hits=%d wall=%d" % [ex.haul_creatures.size(), ex.haul_res, ex.thrown, ex.hits, ex.wall_hits])
	check(ex.haul_creatures.size() > 0, "bot caught creatures")
	check(ex.haul_res > 0.0, "bot mined resources")
	ex.finish(false)
	await _secs(1.2)
	check(main.current is Results, "results shown")
	check(GameState.market_queue.size() > 0, "creatures queued at market")
	check(GameState.wallet.wood > 0.0, "wood added")
	main.show_village()
	await _frames(40)
	var before: float = GameState.wallet.amber
	await _secs(2.0)
	check(GameState.wallet.amber > before, "market sells over time")

	# faint path keeps half
	main.start_expedition(0)
	await _frames(40)
	ex = main.current
	for i in 6:
		ex.haul_creatures.append(2.0)
	ex.oil = 0.0
	await _secs(2.0)
	check(main.current is Results and main.current.summary.fainted, "faint ends expedition")
	check(main.current.summary.caught == 3, "faint keeps 50%")


func _parity_dump() -> void:
	# Stats for a fixed set of levels; tools/check_parity.py compares with the Python simulator.
	var lv := {}
	for n in DB.nodes:
		lv[n.id] = mini(3, int(n.max))
	var s := GameState.compute_stats(lv)
	var f := FileAccess.open("user://parity.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"levels": lv, "stats": s}))
	print("PARITY_FILE ", ProjectSettings.globalize_path("user://parity.json"))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
