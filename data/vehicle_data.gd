class_name VehicleData
extends RefCounted

const VEHICLES: Array[Dictionary] = [
	{"name":"Desert Stallion 65","color":Color("d94b2b"),"accent":Color("17191f"),"max_speed":48.0,"accel":22.0,"brake":24.0,"engine_brake":3.2,"mass":1420.0,"steer":1.72,"steer_response":3.3,"road_grip":8.2,"sand_grip":5.4,"handbrake_grip":3.0,"grip_recovery":3.0,"max_slip":0.46,"power_rating":9,"weight_rating":8,"brake_rating":6,"stability_rating":5,"oversteer_rating":7,"difficulty_rating":8,"control_rating":6,"description":"Rally storica pesante e potente: veloce, frenata lunga e sovrasterzo progressivo."},
	{"name":"Bavarian GT-R","color":Color("2878d0"),"accent":Color("f0b429"),"max_speed":44.0,"accel":20.0,"brake":31.0,"engine_brake":4.2,"mass":1260.0,"steer":1.58,"steer_response":4.8,"road_grip":11.0,"sand_grip":7.2,"handbrake_grip":4.5,"grip_recovery":5.4,"max_slip":0.30,"power_rating":7,"weight_rating":6,"brake_rating":9,"stability_rating":9,"oversteer_rating":3,"difficulty_rating":5,"control_rating":9,"description":"Rally GT moderna: frenata efficace, cambi di direzione precisi e stabilità elevata."}
]

static func get_vehicle(index: int) -> Dictionary:
	return VEHICLES[clampi(index, 0, VEHICLES.size() - 1)].duplicate(true)
