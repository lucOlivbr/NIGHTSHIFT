extends Node
## Three prerecorded loops; synthesis happens offline, never in the game loop.
## Add this node to start playback. Call toggle_music() from the main input handler.

signal music_mute_changed(is_muted: bool)

const MUSIC_PATH := "res://assets/audio/nightshift_noir.wav"
const RAIN_PATH := "res://assets/audio/rain_loop.wav"
const CITY_PATH := "res://assets/audio/city_night_loop.wav"
const SILENCE_DB := -60.0
const MUSIC_GAIN_DB := 0.0
const RAIN_GAIN_DB := -4.0
const CITY_GAIN_DB := -3.0
const FADE_IN_SECONDS := 2.8
const MUSIC_FADE_SECONDS := 0.35

var music_muted := false
var _music_player: AudioStreamPlayer
var _music_tween: Tween
var _ambience_tweens: Array[Tween] = []
var _event_players: Array[AudioStreamPlayer] = []
var _event_streams: Dictionary = {}
var _event_cursor := 0
var _wheels: AudioStreamPlayer
var _escape_mode := false
var _last_notice := -10000


func _ready() -> void:
	name = "NightAudio"
	# The saved layout supplies the limiter and mix. These fallbacks also allow
	# this node to work when instantiated in an isolated preview scene.
	_ensure_bus(&"Music", -7.0)
	_ensure_bus(&"Ambience", -5.0)
	_music_player = _make_player("NoirMusic", MUSIC_PATH, &"Music")
	var rain_player := _make_player("Rain", RAIN_PATH, &"Ambience")
	var city_player := _make_player("NightCity", CITY_PATH, &"Ambience")
	if _music_player != null:
		if music_muted:
			_music_player.stream_paused = true
		else:
			_fade_music(FADE_IN_SECONDS)
	_fade_ambience(rain_player, RAIN_GAIN_DB)
	_fade_ambience(city_player, CITY_GAIN_DB)
	for index in 2:
		var event_player := AudioStreamPlayer.new()
		event_player.name = "ActionCue%d" % index
		event_player.bus = &"Ambience"
		event_player.volume_db = -5
		add_child(event_player)
		_event_players.append(event_player)
	for cue in ["door", "parcel", "mount", "noticed", "alarm", "win"]:
		_event_streams[cue] = load("res://assets/audio/actions/" + cue + ".wav")
	_wheels = _make_player("SkateWheels", "res://assets/audio/actions/wheels.wav", &"Ambience")
	_wheels.volume_db = SILENCE_DB

func _process(delta: float) -> void:
	var rider = get_parent().player
	if rider == null or _wheels == null:
		return
	var rolling: bool = rider.is_skating and rider.controls_enabled and rider.camera_rig.mouse_captured and rider.is_on_floor()
	var speed: float = rider.horizontal_speed if rolling else 0.0
	var gain := lerpf(-30.0, -8.0, clampf(speed / 9.0, 0, 1)) if speed > 0.3 else SILENCE_DB
	_wheels.volume_db = lerpf(_wheels.volume_db, gain, 1.0-exp(-12.0*delta))
	_wheels.pitch_scale = lerpf(0.8, 1.45, clampf(speed / 9.0, 0, 1))

func play_event(cue: String) -> void:
	if not _event_streams.has(cue):
		return
	if cue == "noticed":
		if Time.get_ticks_msec() - _last_notice < 3500:
			return
		_last_notice = Time.get_ticks_msec()
	var player := _event_players[_event_cursor % _event_players.size()]
	_event_cursor += 1
	player.stream = _event_streams[cue]
	player.play()

func set_escape_mode(active: bool) -> void:
	_escape_mode = active
	if _music_player != null:
		_music_player.pitch_scale = 1.03 if active else 1.0
		_fade_music(0.8)


func _exit_tree() -> void:
	stop_audio()


func stop_audio() -> void:
	# Release players and streams before the audio server shuts down. The
	# mixer can finish an already queued buffer without retaining these nodes.
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null
	for tween in _ambience_tweens:
		if tween.is_valid():
			tween.kill()
	_ambience_tweens.clear()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_music_player = null


func toggle_music() -> void:
	set_music_muted(not music_muted)


func set_music_muted(is_muted: bool) -> void:
	if music_muted == is_muted:
		return
	music_muted = is_muted
	if is_inside_tree() and _music_player != null:
		_fade_music(MUSIC_FADE_SECONDS)
	music_mute_changed.emit(music_muted)


func _fade_music(duration: float) -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if not music_muted:
		_music_player.stream_paused = false
	_music_tween = create_tween()
	_music_tween.tween_property(
		_music_player, "volume_db", SILENCE_DB if music_muted else MUSIC_GAIN_DB + (2.0 if _escape_mode else 0.0), duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if music_muted:
		# Pause after the fade so M fully silences only the soundtrack. Resuming
		# keeps its position; the two ambient loops continue uninterrupted.
		_music_tween.tween_callback(_pause_music)


func _pause_music() -> void:
	if music_muted:
		_music_player.stream_paused = true


func _fade_ambience(player: AudioStreamPlayer, target_db: float) -> void:
	if player == null:
		return
	var tween := create_tween()
	_ambience_tweens.append(tween)
	tween.tween_property(player, "volume_db", target_db, FADE_IN_SECONDS).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)


func _make_player(node_name: String, path: String, bus_name: StringName) -> AudioStreamPlayer:
	var stream := _load_loop(path)
	if stream == null:
		push_error("NIGHTSHIFT: could not load audio loop: " + path)
		return null
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = stream
	player.bus = bus_name
	player.max_polyphony = 1
	player.volume_db = SILENCE_DB
	add_child(player)
	player.play()
	return player


func _load_loop(path: String) -> AudioStreamWAV:
	var stream: AudioStreamWAV
	if FileAccess.file_exists(path):
		# Source WAVs also work before the editor has built its import cache.
		# Exported builds use the imported resource when source WAVs are absent.
		stream = AudioStreamWAV.load_from_file(path)
	elif ResourceLoader.exists(path):
		stream = load(path) as AudioStreamWAV
	if stream == null:
		return null
	# Use a private resource, preserving the source import and editor preview.
	stream = stream.duplicate() as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	return stream


func _ensure_bus(bus_name: StringName, volume_db: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_db(index, volume_db)
