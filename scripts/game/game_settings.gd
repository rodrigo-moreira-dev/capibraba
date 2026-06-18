extends Node

var master_volume  := 1.0
var fullscreen     := false
var selected_mode  := "last_standing"
var selected_arena := "lava_flat"

const SAVE_PATH := "user://settings.cfg"


func _ready() -> void:
	_load()
	_apply()


func apply_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))


func apply_fullscreen(on: bool) -> void:
	fullscreen = on
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio",   "master",     master_volume)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	master_volume = cfg.get_value("audio",   "master",     1.0)
	fullscreen    = cfg.get_value("display", "fullscreen", false)


func _apply() -> void:
	apply_volume(master_volume)
	apply_fullscreen(fullscreen)
