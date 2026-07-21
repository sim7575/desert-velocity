extends Area3D

func _process(delta: float) -> void:
	rotation.y += delta * 1.8
	position.y += sin(Time.get_ticks_msec() * 0.004 + position.z) * delta * 0.12

