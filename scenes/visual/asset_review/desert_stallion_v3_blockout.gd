class_name DesertStallionV3Blockout
extends Node3D

const WHEEL_CENTERS := {
	"Wheel_FL": Vector3(-0.94, 0.51, -1.47),
	"Wheel_FR": Vector3(0.94, 0.51, -1.47),
	"Wheel_RL": Vector3(-0.94, 0.51, 1.47),
	"Wheel_RR": Vector3(0.94, 0.51, 1.47),
}

@onready var model: Node3D = $DesertStallionV3BlockoutModel

func _ready() -> void:
	model.rotation.y = PI
	_swap_wheel_names_for_model_rotation()
	for wheel_name in WHEEL_CENTERS:
		_mark_wheel_pivot(wheel_name, WHEEL_CENTERS[wheel_name])
	set_meta("stallion_v3_blockout", true)
	set_meta("visual_model_path", "res://assets/models/vehicles/desert_stallion_v3_blockout.glb")

func _swap_wheel_names_for_model_rotation() -> void:
	for pair in [["Wheel_FL", "Wheel_FR"], ["Wheel_RL", "Wheel_RR"]]:
		var left := model.find_child(pair[0], true, false)
		var right := model.find_child(pair[1], true, false)
		if left == null or right == null:
			continue
		left.name = pair[0] + "_Swap"
		right.name = pair[0]
		left.name = pair[1]

func _mark_wheel_pivot(wheel_name: String, desired_center: Vector3) -> void:
	var wheel := model.find_child(wheel_name, true, false) as Node3D
	if wheel == null:
		return
	wheel.set_meta("vehicle_wheel", true)
	wheel.set_meta("front_wheel", wheel_name in ["Wheel_FL", "Wheel_FR"])
	wheel.set_meta("desired_center", desired_center)

func wheel_pivots_valid() -> bool:
	for wheel_name in WHEEL_CENTERS:
		var wheel := model.find_child(wheel_name, true, false) as Node3D
		if wheel == null or not bool(wheel.get_meta("vehicle_wheel", false)):
			return false
		if (wheel.position - Vector3(-WHEEL_CENTERS[wheel_name].x, WHEEL_CENTERS[wheel_name].y, -WHEEL_CENTERS[wheel_name].z)).length() > 0.01:
			return false
	return true
