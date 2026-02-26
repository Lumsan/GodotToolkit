extends Node

## Add as Autoload named "SettingsManager"
## Handles saving/loading all settings

const SETTINGS_PATH = "user://settings.cfg"

signal settings_changed(category: String, key: String, value: Variant)

var _settings: Dictionary = {}
var _config: ConfigFile

func _ready() -> void:
	_config = ConfigFile.new()
	load_settings()

func load_settings() -> void:
	var err = _config.load(SETTINGS_PATH)
	if err != OK:
		# First run, use defaults
		_apply_defaults()
		return
	
	# Load all sections
	for section in _config.get_sections():
		_settings[section] = {}
		for key in _config.get_section_keys(section):
			_settings[section][key] = _config.get_value(section, key)
	
	_apply_all_settings()

func save_settings() -> void:
	for section in _settings:
		for key in _settings[section]:
			_config.set_value(section, key, _settings[section][key])
	
	_config.save(SETTINGS_PATH)

func get_setting(category: String, key: String, default: Variant = null) -> Variant:
	if _settings.has(category) and _settings[category].has(key):
		return _settings[category][key]
	return default

func set_setting(category: String, key: String, value: Variant) -> void:
	if not _settings.has(category):
		_settings[category] = {}
	
	_settings[category][key] = value
	settings_changed.emit(category, key, value)
	
	# Apply immediately
	_apply_setting(category, key, value)
	
	# Auto-save (consider debouncing for performance)
	save_settings()

func _apply_defaults() -> void:
	# Audio defaults
	set_setting("audio", "master_volume", 80.0)
	set_setting("audio", "music_volume", 70.0)
	set_setting("audio", "sfx_volume", 100.0)
	
	# Graphics defaults
	set_setting("graphics", "fullscreen", false)
	set_setting("graphics", "vsync", true)
	
	# Gameplay defaults
	set_setting("gameplay", "screenshake", true)
	set_setting("gameplay", "tutorials", true)

func _apply_all_settings() -> void:
	for category in _settings:
		for key in _settings[category]:
			_apply_setting(category, key, _settings[category][key])

func _apply_setting(category: String, key: String, value: Variant) -> void:
	match category:
		"audio":
			_apply_audio_setting(key, value)
		"graphics":
			_apply_graphics_setting(key, value)

func _apply_audio_setting(key: String, value: Variant) -> void:
	var bus_name := ""
	match key:
		"master_volume":
			bus_name = "Master"
		"music_volume":
			bus_name = "Music"
		"sfx_volume":
			bus_name = "SFX"
	
	if bus_name:
		var bus_idx = AudioServer.get_bus_index(bus_name)
		if bus_idx >= 0:
			var db = linear_to_db(value / 100.0)
			AudioServer.set_bus_volume_db(bus_idx, db)

func _apply_graphics_setting(key: String, value: Variant) -> void:
	match key:
		"fullscreen":
			if value:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		"vsync":
			DisplayServer.window_set_vsync_mode(
				DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
			)
