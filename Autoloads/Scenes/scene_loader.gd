extends Node

## Add this as an Autoload named "SceneLoader"

signal load_started
signal load_progress(progress: float)
signal load_finished

var _loading_screen_instance: Control
var _target_scene: String
var _minimum_load_time: float
var _load_start_time: float

func load_scene(scene_path: String, loading_screen_path: String = "", min_time: float = 0.5) -> void:
	_target_scene = scene_path
	_minimum_load_time = min_time
	_load_start_time = Time.get_ticks_msec() / 1000.0
	
	# Show loading screen
	if not loading_screen_path.is_empty():
		var loading_scene = load(loading_screen_path)
		_loading_screen_instance = loading_scene.instantiate()
		get_tree().root.add_child(_loading_screen_instance)
		
		# Connect progress signal if loading screen supports it
		if _loading_screen_instance.has_method("set_progress"):
			load_progress.connect(_loading_screen_instance.set_progress)
	
	load_started.emit()
	
	# Start threaded loading
	ResourceLoader.load_threaded_request(scene_path)
	set_process(true)

func _process(_delta: float) -> void:
	var progress: Array = []
	var status = ResourceLoader.load_threaded_get_status(_target_scene, progress)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			load_progress.emit(progress[0])
		
		ResourceLoader.THREAD_LOAD_LOADED:
			# Ensure minimum load time has passed
			var elapsed = Time.get_ticks_msec() / 1000.0 - _load_start_time
			if elapsed < _minimum_load_time:
				return
			
			var scene = ResourceLoader.load_threaded_get(_target_scene)
			_finish_loading(scene)
		
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Failed to load scene: " + _target_scene)
			_cleanup_loading_screen()
			set_process(false)

func _finish_loading(scene: PackedScene) -> void:
	set_process(false)
	load_finished.emit()
	
	_cleanup_loading_screen()
	get_tree().change_scene_to_packed(scene)

func _cleanup_loading_screen() -> void:
	if _loading_screen_instance:
		_loading_screen_instance.queue_free()
		_loading_screen_instance = null
