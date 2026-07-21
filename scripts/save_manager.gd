class_name SaveManager
extends RefCounted

const PATH: String = "user://desert_velocity.cfg"

static func load_data() -> Dictionary:
	var data: Dictionary = {"record":0,"vehicle":0,"volume":0.8,"music_volume":0.45,"sfx_volume":0.75,"mute":false,"graphics_quality":1}
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		data.record = int(config.get_value("game", "record", 0))
		data.vehicle = int(config.get_value("game", "vehicle", 0))
		data.volume = float(config.get_value("settings", "volume", 0.8))
		data.music_volume=float(config.get_value("settings","music_volume",.45)); data.sfx_volume=float(config.get_value("settings","sfx_volume",.75)); data.mute=bool(config.get_value("settings","mute",false))
		data.graphics_quality=int(config.get_value("settings","graphics_quality",1))
	return data

static func save_data(data: Dictionary) -> void:
	var config := ConfigFile.new()
	config.set_value("game", "record", int(data.get("record", 0)))
	config.set_value("game", "vehicle", int(data.get("vehicle", 0)))
	config.set_value("settings", "volume", float(data.get("volume", 0.8)))
	config.set_value("settings","music_volume",float(data.get("music_volume",.45))); config.set_value("settings","sfx_volume",float(data.get("sfx_volume",.75))); config.set_value("settings","mute",bool(data.get("mute",false)))
	config.set_value("settings","graphics_quality",int(data.get("graphics_quality",1)))
	config.save(PATH)
