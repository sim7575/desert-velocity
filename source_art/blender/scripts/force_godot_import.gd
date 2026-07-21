@tool
extends EditorScript

func _run() -> void:
	var filesystem := get_editor_interface().get_resource_filesystem()
	print("FORCE_IMPORT_SCAN_BEGIN")
	filesystem.scan()
	await filesystem.filesystem_changed
	print("FORCE_IMPORT_SCAN_COMPLETE scanning=", filesystem.is_scanning())
	while filesystem.is_scanning():
		await Engine.get_main_loop().process_frame
	Engine.get_main_loop().quit()
