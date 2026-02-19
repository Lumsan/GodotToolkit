# addons/character_toolkit/helpers/audio_manager.gd
class_name AudioManager
extends Node

@export var sfx_pool_size: int = 16
@export var sfx_3d_pool_size: int = 16
@export var default_3d_max_distance: float = 30.0

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_3d_pool: Array[AudioStreamPlayer3D] = []
var _music_player: AudioStreamPlayer
var _music_tween: Tween

func _ready() -> void:
	for i in sfx_pool_size:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)

	for i in sfx_3d_pool_size:
		var player := AudioStreamPlayer3D.new()
		player.bus = "SFX"
		player.max_distance = default_3d_max_distance
		add_child(player)
		_sfx_3d_pool.append(player)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)

# ══════════════════════════════════════
#  2D Sound Effects
# ══════════════════════════════════════

func play_sfx(stream: AudioStream, volume_db: float = 0.0,
		pitch: float = 1.0, polyphony: int = 1) -> AudioStreamPlayer:
	if not stream:
		return null
	var player := _get_available_2d()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_polyphony = polyphony
	player.play()
	return player

func play_sfx_varied(stream: AudioStream, volume_db: float = 0.0,
		pitch_min: float = 0.9, pitch_max: float = 1.1,
		polyphony: int = 1) -> AudioStreamPlayer:
	return play_sfx(stream, volume_db, randf_range(pitch_min, pitch_max), polyphony)

func play_sfx_random(streams: Array[AudioStream], volume_db: float = 0.0,
		pitch_min: float = 0.9, pitch_max: float = 1.1,
		polyphony: int = 1) -> AudioStreamPlayer:
	if streams.is_empty():
		return null
	return play_sfx_varied(streams.pick_random(), volume_db,
		pitch_min, pitch_max, polyphony)

## Play only a portion of a sound (start_time to end_time in seconds).
func play_sfx_clipped(stream: AudioStream, start_time: float,
		end_time: float, volume_db: float = 0.0,
		pitch: float = 1.0) -> AudioStreamPlayer:
	if not stream:
		return null
	var player := _get_available_2d()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_polyphony = 1
	player.play(start_time)

	# Stop after the clip duration
	var duration := (end_time - start_time) / pitch
	if duration > 0.0:
		_stop_after(player, duration)

	return player

# ══════════════════════════════════════
#  3D Sound Effects
# ══════════════════════════════════════

func play_sfx_3d(stream: AudioStream, position: Vector3,
		volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = -1.0,
		polyphony: int = 1) -> AudioStreamPlayer3D:
	if not stream:
		return null
	var player := _get_available_3d()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = max_distance if max_distance > 0.0 else default_3d_max_distance
	player.max_polyphony = polyphony
	player.global_position = position
	player.play()
	return player

func play_sfx_3d_varied(stream: AudioStream, position: Vector3,
		volume_db: float = 0.0, pitch_min: float = 0.9,
		pitch_max: float = 1.1, max_distance: float = -1.0,
		polyphony: int = 1) -> AudioStreamPlayer3D:
	return play_sfx_3d(stream, position, volume_db,
		randf_range(pitch_min, pitch_max), max_distance, polyphony)

func play_sfx_3d_random(streams: Array[AudioStream], position: Vector3,
		volume_db: float = 0.0, pitch_min: float = 0.9,
		pitch_max: float = 1.1, max_distance: float = -1.0,
		polyphony: int = 1) -> AudioStreamPlayer3D:
	if streams.is_empty():
		return null
	return play_sfx_3d_varied(streams.pick_random(), position,
		volume_db, pitch_min, pitch_max, max_distance, polyphony)

## Play only a portion of a 3D sound.
func play_sfx_3d_clipped(stream: AudioStream, position: Vector3,
		start_time: float, end_time: float,
		volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = -1.0) -> AudioStreamPlayer3D:
	if not stream:
		return null
	var player := _get_available_3d()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = max_distance if max_distance > 0.0 else default_3d_max_distance
	player.max_polyphony = 1
	player.global_position = position
	player.play(start_time)

	var duration := (end_time - start_time) / pitch
	if duration > 0.0:
		_stop_after(player, duration)

	return player

# ══════════════════════════════════════
#  3D Attached (follows a node)
# ══════════════════════════════════════

func play_sfx_attached(stream: AudioStream, target: Node3D,
		volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = -1.0) -> AudioStreamPlayer3D:
	if not stream or not target:
		return null
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.max_distance = max_distance if max_distance > 0.0 else default_3d_max_distance
	player.bus = "SFX"
	target.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return player

# ══════════════════════════════════════
#  Music
# ══════════════════════════════════════

func play_music(stream: AudioStream, fade_duration: float = 1.0,
		volume_db: float = 0.0) -> void:
	if not stream:
		return
	if _music_player.stream == stream and _music_player.playing:
		return

	if _music_tween:
		_music_tween.kill()

	if _music_player.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", -40.0, fade_duration)
		_music_tween.tween_callback(func():
			_music_player.stream = stream
			_music_player.volume_db = -40.0
			_music_player.play()
		)
		_music_tween.tween_property(_music_player, "volume_db", volume_db, fade_duration)
	else:
		_music_player.stream = stream
		_music_player.volume_db = -40.0
		_music_player.play()
		_music_tween = create_tween()
		_music_tween.tween_property(_music_player, "volume_db", volume_db, fade_duration)

func stop_music(fade_duration: float = 1.0) -> void:
	if not _music_player.playing:
		return

	if _music_tween:
		_music_tween.kill()

	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, fade_duration)
	_music_tween.tween_callback(_music_player.stop)

func pause_music() -> void:
	_music_player.stream_paused = true

func resume_music() -> void:
	_music_player.stream_paused = false

var is_music_playing: bool:
	get:
		return _music_player.playing and not _music_player.stream_paused

# ══════════════════════════════════════
#  Bus Control
# ══════════════════════════════════════

func set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(value))

func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))

func set_bus_mute(bus_name: String, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_mute(index, muted)

# ══════════════════════════════════════
#  Pool Management
# ══════════════════════════════════════

func _get_available_2d() -> AudioStreamPlayer:
	for player in _sfx_pool:
		if not player.playing:
			return player

	var oldest: AudioStreamPlayer = _sfx_pool[0]
	var most_progress: float = 0.0

	for player in _sfx_pool:
		if not player.stream:
			oldest = player
			break
		var length := player.stream.get_length()
		if length <= 0.0:
			continue
		var progress := player.get_playback_position() / length
		if progress > most_progress:
			most_progress = progress
			oldest = player

	oldest.stop()
	return oldest

func _get_available_3d() -> AudioStreamPlayer3D:
	for player in _sfx_3d_pool:
		if not player.playing:
			return player

	var oldest: AudioStreamPlayer3D = _sfx_3d_pool[0]
	var most_progress: float = 0.0

	for player in _sfx_3d_pool:
		if not player.stream:
			oldest = player
			break
		var length := player.stream.get_length()
		if length <= 0.0:
			continue
		var progress := player.get_playback_position() / length
		if progress > most_progress:
			most_progress = progress
			oldest = player

	oldest.stop()
	return oldest

# ══════════════════════════════════════
#  Clipping Helper
# ══════════════════════════════════════

func _stop_after(player: Node, duration: float) -> void:
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		if is_instance_valid(player) and player.playing:
			player.stop()
	)
	
