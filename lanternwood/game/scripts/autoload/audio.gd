extends Node
## Sound effects pool with per-sound throttling and random pitch.

const SOUNDS := ["throw", "hit", "catch", "rare", "break", "spark", "pickup", "coin", "sell", "buy", "deny",
		"low_oil", "unlock", "faint", "tap"]
const MIN_GAP := {"spark": 0.09, "pickup": 0.03, "hit": 0.03, "sell": 0.05, "coin": 0.06}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}


func _ready() -> void:
	for s in SOUNDS:
		_streams[s] = load("res://assets/sfx/%s.wav" % s)
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch := 1.0, volume_db := 0.0, vary := 0.05) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(sound, -10.0)) < float(MIN_GAP.get(sound, 0.0)):
		return
	_last[sound] = now
	var vol: float = GameState.settings.sfx
	if vol <= 0.01:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch * randf_range(1.0 - vary, 1.0 + vary)
	p.volume_db = volume_db + linear_to_db(vol)
	p.play()
