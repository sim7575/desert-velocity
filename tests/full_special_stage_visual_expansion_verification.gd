extends SceneTree

const CHECKPOINTS := [9, 19, 29, 39, 49, 59]

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var route := HandcraftedStage.route()
	_check(route.size() == 64, "route segment count changed")
	_check(is_equal_approx(route.size() * BalanceData.SEGMENT_LENGTH, 3328.0), "effective route length changed")
	var origin := Vector3(0, 0, BalanceData.SEGMENT_LENGTH * 0.5)
	var heading := 0.0
	var surface_counts := {"ASPHALT": 0, "GRAVEL": 0, "SAND": 0, "DEEP_SAND": 0}
	var obstacle_count := 0
	var jump_count := 0
	var minimum_altitude := origin.y
	var maximum_altitude := origin.y
	for index in route.size():
		var data: Dictionary = route[index]
		var curve := float(data.get("curve", 0.0))
		var pitch := float(data.get("pitch", 0.0))
		var middle_heading := heading + curve * 0.5
		var basis := Basis.from_euler(Vector3(pitch, middle_heading, 0))
		var forward := -basis.z
		var center := origin + forward * BalanceData.SEGMENT_LENGTH * 0.5
		var end := origin + forward * BalanceData.SEGMENT_LENGTH
		var surface := str(data.get("surface", "GRAVEL"))
		surface_counts[surface] = int(surface_counts.get(surface, 0)) + 1
		var obstacles := 2 if absf(curve) > 0.12 else 0
		obstacle_count += obstacles
		var jump_kind := str(data.get("jump_kind", ""))
		if not jump_kind.is_empty():
			jump_count += 1
		var checkpoint := CHECKPOINTS.find(index) + 1 if index in CHECKPOINTS else 0
		minimum_altitude = minf(minimum_altitude, end.y)
		maximum_altitude = maxf(maximum_altitude, end.y)
		print("SEG %02d DIST %04d-%04d DIR %s YAW %+.2f CURVE %+.3f ALT %.2f->%.2f PITCH %+.3f SURFACE %s CP %d OBST %d JUMP %s NOTE %s" % [index, int(index * BalanceData.SEGMENT_LENGTH), int((index + 1) * BalanceData.SEGMENT_LENGTH), _direction_name(heading + curve), rad_to_deg(heading + curve), curve, origin.y, end.y, pitch, surface, checkpoint, obstacles, jump_kind if not jump_kind.is_empty() else "-", str(data.get("note", ""))])
		origin = end
		heading += curve
	_check(int(surface_counts["ASPHALT"]) == 17, "asphalt segment count changed")
	_check(int(surface_counts["GRAVEL"]) == 47, "gravel segment count changed")
	_check(jump_count == 4, "G1-G jump inventory changed")
	_check(obstacle_count == 40, "G1-G deterministic obstacle count changed")
	print("SUMMARY length=3328 segments=64 checkpoints=6 asphalt=%d gravel=%d sand_logic=offroad deep_sand_logic=far_offroad obstacles=%d jumps=%d altitude_min=%.2f altitude_max=%.2f elevation_range=%.2f" % [int(surface_counts["ASPHALT"]), int(surface_counts["GRAVEL"]), obstacle_count, jump_count, minimum_altitude, maximum_altitude, maximum_altitude - minimum_altitude])
	print("FULL_SPECIAL_STAGE_BASELINE_RESULT %s" % ("PASS" if failures.is_empty() else "FAIL"))
	for failure in failures:
		printerr("G1F_BASELINE_FAIL ", failure)
	quit(0 if failures.is_empty() else 1)

func _direction_name(yaw: float) -> String:
	var normalized := fposmod(rad_to_deg(yaw), 360.0)
	if normalized < 22.5 or normalized >= 337.5:
		return "N"
	if normalized < 67.5:
		return "NE"
	if normalized < 112.5:
		return "E"
	if normalized < 157.5:
		return "SE"
	if normalized < 202.5:
		return "S"
	if normalized < 247.5:
		return "SW"
	if normalized < 292.5:
		return "W"
	return "NW"

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
