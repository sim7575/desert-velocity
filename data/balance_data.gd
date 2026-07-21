class_name BalanceData
extends RefCounted

const ROAD_HALF_WIDTH: float = 8.5
const SEGMENT_LENGTH: float = 52.0
const SEGMENT_COUNT: int = 9
const START_FUEL: float = 100.0
const START_HEALTH: float = 100.0
const FUEL_DRAIN: float = 0.72
const OFFROAD_DAMAGE_DELAY: float = 3.0
const OFFROAD_DAMAGE_RATE: float = 3.0
const SOFT_WORLD_LIMIT: float = 22.0
const HARD_WORLD_LIMIT: float = 42.0
const RESET_HEALTH_PENALTY: float = 8.0
const RESET_SCORE_PENALTY: int = 250

const SURFACES: Dictionary = {
	"ASPHALT":{"long_grip":1.0,"lat_grip":1.0,"accel":1.0,"brake":1.0,"drag":1.0,"roughness":0.05},
	"GRAVEL":{"long_grip":0.82,"lat_grip":0.78,"accel":0.88,"brake":0.78,"drag":1.18,"roughness":0.38},
	"SAND":{"long_grip":0.66,"lat_grip":0.62,"accel":0.72,"brake":0.62,"drag":1.45,"roughness":0.62},
	"DEEP_SAND":{"long_grip":0.44,"lat_grip":0.48,"accel":0.52,"brake":0.48,"drag":2.05,"roughness":0.88}
}
