extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var appdata := OS.get_environment("APPDATA")
	_check("desert_velocity_g1b" in appdata.to_lower(), "test is not running inside isolated APPDATA")
	var save_path := ProjectSettings.globalize_path(SaveManager.PATH)
	_check("desert_velocity_g1b" in save_path.to_lower(), "SaveManager path escaped isolated test storage")
	if FileAccess.file_exists(SaveManager.PATH):
		DirAccess.remove_absolute(save_path)
	var defaults := SaveManager.load_data()
	_check(defaults.record == 0 and defaults.vehicle == 0, "missing-file defaults changed")
	_check(is_equal_approx(float(defaults.music_volume), 0.45) and is_equal_approx(float(defaults.sfx_volume), 0.75), "missing-file settings defaults changed")
	var fixture := defaults.duplicate(true)
	fixture.record = 777
	fixture.vehicle = 1
	fixture.music_volume = 0.25
	fixture.sfx_volume = 0.65
	fixture.mute = true
	fixture.graphics_quality = 2
	SaveManager.save_data(fixture)
	var loaded := SaveManager.load_data()
	_check(loaded.record == 777 and loaded.vehicle == 1, "record/vehicle round trip failed")
	_check(is_equal_approx(float(loaded.music_volume), 0.25) and is_equal_approx(float(loaded.sfx_volume), 0.65), "settings round trip failed")
	_check(bool(loaded.mute) and int(loaded.graphics_quality) == 2, "mute/quality round trip failed")
	var manager: Node = load("res://scripts/game_manager.gd").new()
	root.add_child(manager)
	await process_frame
	manager.save.record = 777
	manager.score = 888
	manager.show_game_over()
	await process_frame
	_check(int(SaveManager.load_data().record) == 888, "new record was not persisted")
	manager.score = 100
	manager.save.record = 888
	manager.show_game_over()
	await process_frame
	_check(int(SaveManager.load_data().record) == 888, "lower score overwrote record")
	var invalid := FileAccess.open(SaveManager.PATH, FileAccess.WRITE)
	invalid.store_string("not a valid ConfigFile")
	invalid.close()
	var recovered := SaveManager.load_data()
	_check(recovered.record == 0 and recovered.vehicle == 0, "invalid-file fallback changed")
	if FileAccess.file_exists(SaveManager.PATH):
		DirAccess.remove_absolute(save_path)
	manager.queue_free()
	for _frame in 4:
		await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("GAMEPLAY_SAVE_ISOLATION_RESULT PASS")
	else:
		for failure in failures:
			printerr("GAMEPLAY_SAVE_ISOLATION_FAIL ", failure)
		print("GAMEPLAY_SAVE_ISOLATION_RESULT FAIL count=", failures.size())
	quit(0 if failures.is_empty() else 1)
