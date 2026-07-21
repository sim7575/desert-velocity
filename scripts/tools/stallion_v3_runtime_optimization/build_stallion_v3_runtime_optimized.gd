extends SceneTree

const SOURCE_PATH := "res://assets/models/vehicles/desert_stallion_v3_lod1.glb"
const OUTPUT_PATH := "res://scenes/visual/production/runtime_optimized/stallion_v3_lod1_runtime_optimized.scn"
const WHEEL_NAMES := ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
const SURFACE_CATEGORIES := {
	"V3_BodyShell": ["paint"],
	"V3_CanopyFrame": ["paint"],
	"V3_Glass": ["glass"],
	"V3_MuscularFenders": ["paint"],
	"Wheel_FL_Geometry": ["rubber", "metal"],
	"Wheel_FR_Geometry": ["rubber", "metal"],
	"Wheel_RL_Geometry": ["rubber", "metal"],
	"Wheel_RR_Geometry": ["rubber", "metal"],
	"V3_VisibleSuspension": ["metal", "light", "dark"],
	"V3_RollCage": ["metal"],
	"V3_UnderbodySkid": ["metal"],
	"V3_FunctionalDetails": ["dark", "light", "accent", "metal", "paint"],
	"V3_Interior": ["dark", "accent", "metal", "light"],
	"V3_FinalFunctionalDetail": ["paint", "metal", "dark"],
}

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var source_scene := load(SOURCE_PATH) as PackedScene
	if source_scene == null:
		_fail("source LOD1 could not be loaded")
		return
	var source := source_scene.instantiate() as Node3D
	_swap_wheel_names(source)
	var tools: Dictionary = {}
	for child in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null or _belongs_to_wheel(mesh_instance):
			continue
		var relative_transform := _transform_relative_to(mesh_instance, source)
		for surface in mesh_instance.mesh.get_surface_count():
			var category := _surface_category(mesh_instance.name, surface)
			if not tools.has(category):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[category] = tool
			(tools[category] as SurfaceTool).append_from(mesh_instance.mesh, surface, relative_transform)
	var optimized := Node3D.new()
	optimized.name = "StallionV3LOD1RuntimeOptimized"
	for category in tools:
		var merged := MeshInstance3D.new()
		merged.name = "RuntimeStatic_%s" % category
		merged.mesh = (tools[category] as SurfaceTool).commit()
		merged.mesh.resource_name = "StallionV3LOD1_%s" % category
		optimized.add_child(merged)
		merged.owner = optimized
	for wheel_name in WHEEL_NAMES:
		var wheel := source.find_child(wheel_name, true, false) as Node3D
		if wheel == null:
			_fail("missing wheel %s" % wheel_name)
			return
		var wheel_copy := wheel.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as Node3D
		wheel_copy.name = wheel_name
		wheel_copy.transform = _transform_relative_to(wheel, source)
		wheel_copy.set_meta("vehicle_wheel", true)
		wheel_copy.set_meta("front_wheel", wheel_name in ["Wheel_FL", "Wheel_FR"])
		optimized.add_child(wheel_copy)
		_set_owner_recursive(wheel_copy, optimized)
	var mesh_count := optimized.find_children("*", "MeshInstance3D", true, false).size()
	var surface_count := _surface_count(optimized)
	var triangle_count := _triangle_count(optimized)
	if mesh_count != 10 or surface_count != 14 or triangle_count != 27670:
		_fail("generated counts differ: meshes=%d surfaces=%d triangles=%d" % [mesh_count, surface_count, triangle_count])
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var packed := PackedScene.new()
	if packed.pack(optimized) != OK:
		_fail("optimized scene could not be packed")
		return
	var save_error := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_error != OK:
		_fail("optimized scene could not be saved: %d" % save_error)
		return
	print("STALLION_V3_RUNTIME_BUILD_RESULT PASS meshes=%d surfaces=%d triangles=%d output=%s" % [mesh_count, surface_count, triangle_count, OUTPUT_PATH])
	source.free()
	optimized.free()
	tools.clear()
	for _frame in 4:
		await process_frame
	quit(0)

func _surface_category(mesh_name: String, surface: int) -> String:
	var slots: Array = SURFACE_CATEGORIES.get(mesh_name, [])
	return str(slots[surface]) if surface >= 0 and surface < slots.size() else "dark"

func _belongs_to_wheel(node: Node) -> bool:
	var current := node.get_parent()
	while current != null:
		if current.name in WHEEL_NAMES:
			return true
		current = current.get_parent()
	return false

func _transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var result := node.transform
	var current := node.get_parent()
	while current != null and current != ancestor:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result

func _swap_wheel_names(model: Node) -> void:
	for pair in [["Wheel_FL", "Wheel_FR"], ["Wheel_RL", "Wheel_RR"]]:
		var left := model.find_child(pair[0], true, false)
		var right := model.find_child(pair[1], true, false)
		if left == null or right == null:
			continue
		left.name = pair[0] + "_Swap"
		right.name = pair[0]
		left.name = pair[1]

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)

func _surface_count(root_node: Node) -> int:
	var total := 0
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh != null:
			total += mesh_instance.mesh.get_surface_count()
	return total

func _triangle_count(root_node: Node) -> int:
	var total := 0
	for child in root_node.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			total += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total

func _fail(message: String) -> void:
	printerr("STALLION_V3_RUNTIME_BUILD_FAIL ", message)
	quit(1)
