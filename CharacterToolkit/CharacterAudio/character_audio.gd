# components/audio/character_audio.gd
class_name CharacterAudio
extends Node

@export var priority: int = 50

@export_group("Sound Streams")
@export var jump_sounds: Array[AudioStream] = []
@export var land_sounds: Array[AudioStream] = []
@export var footstep_sounds: Array[AudioStream] = []
@export var sprint_footstep_sounds: Array[AudioStream] = []
@export var crouch_footstep_sounds: Array[AudioStream] = []

@export_group("Footstep Timing")
@export var footstep_interval: float = 2.0
@export var sprint_footstep_interval: float = 1.5
@export var crouch_footstep_interval: float = 3.0

@export_group("Volume")
@export_range(-40.0, 10.0) var footstep_volume_db: float = -10.0
@export_range(-40.0, 10.0) var sprint_volume_db: float = -8.0
@export_range(-40.0, 10.0) var crouch_volume_db: float = -20.0
@export_range(-40.0, 10.0) var jump_volume_db: float = -5.0
@export_range(-40.0, 10.0) var land_volume_db: float = -5.0

var _distance_traveled: float = 0.0
var _last_position: Vector3
var _character: CharacterBody3D

func _ready() -> void:
	_character = _find_character_body()
	if _character:
		_last_position = _character.global_position
	call_deferred("_connect_signals")

func _find_character_body() -> CharacterBody3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _connect_signals() -> void:
	if not _character:
		return
	var data: CharacterData = _character.get("data")
	if not data:
		return
	if not data.jumped.is_connected(_on_jumped):
		data.jumped.connect(_on_jumped)
	if not data.landed.is_connected(_on_landed):
		data.landed.connect(_on_landed)

func post_process(data: CharacterData, _delta: float) -> void:
	if not _character or not _character.is_inside_tree():
		return

	if not data.is_on_floor:
		_distance_traveled = 0.0
		_last_position = _character.global_position
		return

	var current_pos := _character.global_position
	var moved := Vector2(
		current_pos.x - _last_position.x,
		current_pos.z - _last_position.z
	)
	_distance_traveled += moved.length()
	_last_position = current_pos

	var interval := footstep_interval
	if data.is_crouching:
		interval = crouch_footstep_interval
	elif data.is_sprinting:
		interval = sprint_footstep_interval

	if _distance_traveled >= interval and data.horizontal_speed > 0.5:
		_play_footstep(data)
		_distance_traveled = 0.0

func _play_footstep(data: CharacterData) -> void:
	var sounds := footstep_sounds
	var volume := footstep_volume_db

	if data.is_crouching and not crouch_footstep_sounds.is_empty():
		sounds = crouch_footstep_sounds
		volume = crouch_volume_db
	elif data.is_sprinting and not sprint_footstep_sounds.is_empty():
		sounds = sprint_footstep_sounds
		volume = sprint_volume_db

	if sounds.is_empty():
		return

	Audio.play_sfx_3d_random(sounds, _character.global_position, volume)

func _on_jumped() -> void:
	if not jump_sounds.is_empty() and _character:
		Audio.play_sfx_3d_random(jump_sounds, _character.global_position, jump_volume_db)

func _on_landed() -> void:
	if not land_sounds.is_empty() and _character:
		Audio.play_sfx_3d_random(land_sounds, _character.global_position, land_volume_db)
