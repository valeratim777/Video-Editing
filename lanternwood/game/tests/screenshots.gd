extends Node
## Renders a few screens to docs/img/screens/ (needs a real display, e.g. xvfb-run).
## Run: xvfb-run godot --path game res://tests/screenshots.tscn

var main: Node
var out_dir := ""


func _ready() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/img/screens")
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.reset()
	for id in ["sling_1", "sling_2", "sling_5", "drill_1", "lan_1", "lan_2", "econ_1", "wild_1", "path_cloud", "path_caves", "path_mangrove"]:
		GameState.levels[id] = 1
	GameState.wallet = {"amber": 1234.0, "wood": 56.0, "crystal": 0.0, "pollen": 0.0}
	GameState.market_queue = [2.0, 2.0, 2.0, 2.0, 2.0, 6.0, 6.0]
	GameState.recompute()
	main = load("res://scripts/main.gd").new()
	add_child(main)
	await _secs(1.2)
	await _shot("village")
	main.open_skill_tree()
	await _secs(0.6)
	await _shot("skill_tree")
	main.overlay.close()
	for r in [0, 1, 3]:
		main.start_expedition(r)
		await _secs(1.5)
		var ex: Expedition = main.current
		ex.oil = ex.oil_max * 0.8
		ex.player.sling_held = true
		var c := ex.nearest_creature(ex.player.global_position, 9999.0)
		if c:
			ex.player.global_position = c.position + Vector2(-50, 10)
		await _secs(1.2)
		await _shot("expedition_%d" % r)
		ex.player.sling_held = false
	get_tree().quit()


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_NEAREST)
	img.save_png(out_dir.path_join(shot_name + ".png"))
	print("saved ", shot_name)


func _secs(s: float) -> void:
	await get_tree().create_timer(s).timeout
