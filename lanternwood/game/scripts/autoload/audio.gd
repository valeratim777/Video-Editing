extends Node
## Sound effects pool with per-sound throttling and random pitch.

const SOUNDS := ["throw", "hit", "catch", "rare", "break", "spark", "pickup", "coin", "sell", "buy", "deny",
		"low_oil", "unlock", "faint", "tap"]
const MIN_GAP := {"spark": 0.09, "pickup": 0.03, "hit": 0.03, "sell": 0.05, "coin": 0.06}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last: Dictionary = {}
var _music: Array[AudioStreamPlayer] = []
var _music_idx := 0
var _music_name := ""
var _lowpass: AudioEffectLowPassFilter
var _music_bus := 0


func _ready() -> void:
	for s in SOUNDS:
		_streams[s] = load("res://assets/sfx/%s.wav" % s)
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_bus = AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(_music_bus, "Music")
	_lowpass = AudioEffectLowPassFilter.new()
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)


## Crossfades to res://assets/music/<track>.mp3 (or .ogg); silently does nothing if the file is missing.
func play_music(track: String) -> void:
	if track == _music_name:
		return
	var stream: AudioStream = null
	for ext in ["mp3", "ogg"]:
		var path := "res://assets/music/%s.%s" % [track, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream == null:
		return
	_music_name = track
	if "loop" in stream:
		stream.loop = true
	var old := _music[_music_idx]
	_music_idx = 1 - _music_idx
	var cur := _music[_music_idx]
	cur.stream = stream
	cur.play()
	var target := linear_to_db(maxf(0.001, float(GameState.settings.music)) * 0.7)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cur, "volume_db", target, 1.2).from(-40.0)
	tw.tween_property(old, "volume_db", -80.0, 1.2)
	tw.chain().tween_callback(old.stop)


## Muffles the music (low light, pause menus).
func set_muffled(on: bool) -> void:
	create_tween().tween_property(_lowpass, "cutoff_hz", 700.0 if on else 20000.0, 0.6)


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
