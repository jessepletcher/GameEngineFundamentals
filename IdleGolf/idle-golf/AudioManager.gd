extends Node

# All game sounds
var _sounds := {
	"hit": preload("res://GolfHit.mp3"),
	"flag": preload("res://FlagHit.mp3"),
	"flag_stick": preload("res://FlagStickHit.mp3"),
	"destroy": preload("res://Destruction.mp3"),
	"button": preload("res://ButtonPress.mp3"),
	"blink": preload("res://Blink.mp3"),
	"bell": preload("res://BellSound.mp3"),
	"casino": preload("res://Casino2.mp3"),
	"coin": preload("res://Coin.mp3"),
	"thud": preload("res://Thud.mp3"),
	"beep": preload("res://Beep.mp3"),
	"firework": preload("res://Firework.mp3"),
}

# Volume controls (0.0 to 1.0) — edit in Project > AutoLoad > AudioManager node inspector
@export_range(0.0, 1.0) var hit_volume := .03
@export_range(0.0, 1.0) var flag_volume := 0.01
@export_range(0.0, 1.0) var flag_stick_volume := 0.05
@export_range(0.0, 1.0) var destroy_volume := .012
@export_range(0.0, 1.0) var button_volume := .5
@export_range(0.0, 1.0) var blink_volume := 0.05
@export_range(0.0, 1.0) var bell_volume := 0.5
@export_range(0.0, 1.0) var casino_volume := 0.05
@export_range(0.0, 1.0) var coin_volume := 0.10
@export_range(0.0, 1.0) var thud_volume := 0.1
@export_range(0.0, 1.0) var beep_volume := 0.025
@export_range(0.0, 1.0) var firework_volume := 0.1
@export_range(0.0, 1.0) var music_volume := 0.05
@export_range(0.0, 1.0) var ambience_volume := 0.3

var sfx_muted := false
var music_muted := false

var _player_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE := 8
const MAX_TEMP_PLAYERS := 12
var _temp_players: Array[AudioStreamPlayer] = []

var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer

var _volume_map := {}
var _cleaned_up := false

func _ready() -> void:
	_volume_map = {
		"hit": func(): return hit_volume,
		"flag": func(): return flag_volume,
		"flag_stick": func(): return flag_stick_volume,
		"destroy": func(): return destroy_volume,
		"button": func(): return button_volume,
		"blink": func(): return blink_volume,
		"bell": func(): return bell_volume,
		"casino": func(): return casino_volume,
		"coin": func(): return coin_volume,
		"thud": func(): return thud_volume,
		"beep": func(): return beep_volume,
		"firework": func(): return firework_volume,
	}

	# build player pool
	for i in POOL_SIZE:
		var p = AudioStreamPlayer.new()
		add_child(p)
		_player_pool.append(p)

	# music
	music_player = AudioStreamPlayer.new()
	add_child(music_player)

	# ambience
	ambience_player = AudioStreamPlayer.new()
	add_child(ambience_player)

func play_sfx(sound_name: String, pitch_scale: float = 1.0) -> void:
	if _is_headless():
		return
	if sfx_muted:
		return
	if not _sounds.has(sound_name):
		push_warning("AudioManager: unknown sound '%s'" % sound_name)
		return

	var player = _get_free_player()
	if not player:
		return

	var vol = _volume_map[sound_name].call() if _volume_map.has(sound_name) else 1.0
	player.stream = _sounds[sound_name]
	player.volume_db = _volume_to_db(vol)
	player.pitch_scale = pitch_scale
	player.play()

func play_music(stream: AudioStream) -> void:
	if _is_headless():
		return
	music_player.stream = stream
	music_player.volume_db = _volume_to_db(music_volume)
	if not music_muted:
		music_player.play()

func play_ambience(stream: AudioStream) -> void:
	if _is_headless():
		return
	ambience_player.stream = stream
	ambience_player.volume_db = _volume_to_db(ambience_volume)
	if not music_muted:
		ambience_player.play()

func cleanup_audio() -> void:
	if _cleaned_up:
		return
	_cleaned_up = true
	_stop_and_clear_player(music_player)
	_stop_and_clear_player(ambience_player)
	for player in _player_pool:
		_stop_and_clear_player(player)
	for player in _temp_players:
		_stop_and_clear_player(player)
	_sounds.clear()

func _exit_tree() -> void:
	cleanup_audio()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		cleanup_audio()

func toggle_sfx_mute() -> void:
	sfx_muted = !sfx_muted

func toggle_music_mute() -> void:
	music_muted = !music_muted
	music_player.stream_paused = music_muted
	ambience_player.stream_paused = music_muted

func set_sfx_ducked(ducked: bool) -> void:
	if ducked:
		AudioServer.set_bus_volume_db(0, -20.0)
	else:
		AudioServer.set_bus_volume_db(0, 0.0)

func _get_free_player() -> AudioStreamPlayer:
	for p in _player_pool:
		if not p.playing:
			return p
	if _temp_players.size() >= MAX_TEMP_PLAYERS:
		return null
	var p := AudioStreamPlayer.new()
	add_child(p)
	_temp_players.append(p)
	p.finished.connect(_on_temp_player_finished.bind(p))
	return p

func _on_temp_player_finished(player: AudioStreamPlayer) -> void:
	_temp_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()

func _stop_and_clear_player(player: AudioStreamPlayer) -> void:
	if not player:
		return
	player.stop()
	player.stream = null

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _volume_to_db(vol: float) -> float:
	if vol <= 0.0:
		return -80.0
	return linear_to_db(vol)
