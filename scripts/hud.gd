class_name GameHUD
extends CanvasLayer

var stats_label: Label
var message_label: Label
var fuel_bar: ProgressBar
var health_bar: ProgressBar
var turbo_bar: ProgressBar
var warning_label: Label
var debug_label: Label
var debug_visible: bool = false
var rally_label: Label
var pacenote_label: Label
var speed_value_label: Label
var turbo_state_label: Label
var turbo_was_available := false
var status_panel:Panel
var pace_panel:Panel
var rally_panel:Panel

const WARM_WHITE := Color("f5ead7")
const AMBER := Color("e5a33d")
const ANTHRACITE := Color(0.055, 0.060, 0.065, 0.86)

func _ready() -> void:
	var root := Control.new()
	root.name = "HUDV2SafeArea"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	status_panel = _panel(root, "StatusPanel", Vector2(20, 18), Vector2(335, 140))
	status_panel.visible=false
	stats_label = _label(status_panel, Vector2(14, 9), Vector2(307, 66), 14)
	stats_label.add_theme_color_override("font_color", WARM_WHITE)
	fuel_bar = _bar(status_panel, Vector2(14, 82), Color("d89a35"), "CARBURANTE")
	health_bar = _bar(status_panel, Vector2(14, 109), Color("45b978"), "INTEGRITÀ")

	pace_panel = _panel(root, "PacenotePanel", Vector2(410, 18), Vector2(430, 78))
	pace_panel.visible=false
	pacenote_label = _label(pace_panel, Vector2(10, 6), Vector2(410, 66), 22)
	pacenote_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pacenote_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pacenote_label.add_theme_color_override("font_color", Color("ffd67a"))

	rally_panel = _panel(root, "RallyPanel", Vector2(960, 18), Vector2(300, 138))
	rally_panel.visible=false
	rally_label = _label(rally_panel, Vector2(12, 8), Vector2(276, 122), 15)
	rally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rally_label.add_theme_color_override("font_color", WARM_WHITE)

	var speed_panel := _panel(root, "SpeedPanel", Vector2(20, 610), Vector2(210, 90))
	var speed_title := _label(speed_panel, Vector2(13, 7), Vector2(184, 18), 12)
	speed_title.text = "VELOCITÀ"
	speed_title.add_theme_color_override("font_color", Color("c6bba9"))
	speed_value_label = _label(speed_panel, Vector2(12, 21), Vector2(186, 58), 38)
	speed_value_label.text = "000  km/h"
	speed_value_label.add_theme_color_override("font_color", WARM_WHITE)

	var turbo_panel := _panel(root, "TurboPanel", Vector2(1040, 628), Vector2(220, 72))
	turbo_state_label = _label(turbo_panel, Vector2(12, 6), Vector2(196, 20), 13)
	turbo_state_label.text = "TURBO  INATTIVO"
	turbo_state_label.add_theme_color_override("font_color", Color("ffd27a"))
	turbo_bar = _wide_bar(turbo_panel, Vector2(12, 34), Vector2(196, 18), AMBER)

	message_label = _label(root, Vector2(390, 108), Vector2(500, 58), 24)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", WARM_WHITE)
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	message_label.add_theme_constant_override("shadow_offset_x", 2)
	message_label.add_theme_constant_override("shadow_offset_y", 2)

	warning_label = _label(root, Vector2(450, 634), Vector2(380, 50), 18)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", Color("ffd15c"))

	debug_label = _label(root, Vector2(925, 175), Vector2(330, 240), 14)
	debug_label.visible = false
	debug_label.add_theme_color_override("font_color", WARM_WHITE)

func _panel(parent: Control, node_name: String, position: Vector2, size: Vector2) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = ANTHRACITE
	style.border_color = Color(0.78, 0.52, 0.25, 0.70)
	style.set_border_width_all(1)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 5
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Control, position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", WARM_WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _bar(parent: Control, position: Vector2, color: Color, title: String) -> ProgressBar:
	var label := _label(parent, position, Vector2(98, 19), 11)
	label.text = title
	label.add_theme_color_override("font_color", Color("cfc4b1"))
	return _wide_bar(parent, position + Vector2(101, 1), Vector2(206, 16), color)

func _wide_bar(parent: Control, position: Vector2, size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = position
	bar.size = size
	bar.max_value = 100
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.02, 0.022, 0.025, 0.92)
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar

func update_values(score: int, distance: float, speed: int, fuel: float, health: float, multiplier: int, record: int, turbo: float) -> void:
	stats_label.text = "PUNTI  %07d   RECORD  %07d\nDISTANZA  %06dm\nVEL  %03d km/h   x%d" % [score, record, int(distance), speed, multiplier]
	status_panel.visible=not stats_label.text.strip_edges().is_empty()
	fuel_bar.value = fuel
	health_bar.value = health
	turbo_bar.value = turbo * 20.0
	speed_value_label.text = "%03d  km/h" % speed
	if turbo > 0.001:
		turbo_was_available = true
		turbo_state_label.text = "TURBO  ATTIVO" if turbo < 4.999 else "TURBO  PRONTO"
		turbo_state_label.add_theme_color_override("font_color", Color("ffd27a"))
	else:
		turbo_state_label.text = "TURBO  ESAURITO" if turbo_was_available else "TURBO  INATTIVO"
		turbo_state_label.add_theme_color_override("font_color", Color("e76b4b") if turbo_was_available else Color("b8ad9c"))

func flash_message(text_: String) -> void:
	message_label.modulate.a = 1.0
	message_label.scale = Vector2(0.92, 0.92)
	message_label.pivot_offset = message_label.size * 0.5
	message_label.text = text_
	var tween := create_tween()
	tween.tween_property(message_label, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.42)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.24)
	tween.tween_callback(func(): message_label.text = "")
	tween.tween_callback(func(): message_label.modulate.a = 1.0)

func damage_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, .08, .03, .3)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, .22)
	tween.tween_callback(flash.queue_free)

func update_offroad(is_offroad: bool, boundary: bool, direction: Vector3, vehicle: VehicleController) -> void:
	if Input.is_action_just_pressed("debug_overlay"):
		debug_visible = not debug_visible
		debug_label.visible = debug_visible
	var side: String = "◀" if direction.x < 0 else "▶"
	warning_label.text = ("TORNA IN PISTA  %s\nR — RIPOSIZIONA" % side) if boundary else (("FUORI PISTA  %s" % side) if is_offroad else "")
	if debug_visible:
		var seam := vehicle.road_manager.seam_debug_info(vehicle.global_position)
		var route_index := vehicle.road_manager.route_index_near(vehicle.global_position)
		var jump := vehicle.road_manager.jump_kind_near(vehicle.global_position)
		debug_label.text = "DEBUG F3\nSeg %d  yaw %+.1f°  quota %.2f\nVel %.2f  vert %.2f  %s\nAria %.2fs  picco %.2fm  salto %s\nCP %s  Floor:%s\nGiunzione %.1fm  ΔY:%.3f  Δ°:%.2f\nCollider: %s" % [route_index, rad_to_deg(vehicle.rotation.y), vehicle.global_position.y, vehicle.speed, vehicle.velocity.y, "ARIA" if vehicle.airborne else "TERRA", vehicle.air_time if vehicle.airborne else vehicle.last_air_time, vehicle.air_peak_height if vehicle.airborne else vehicle.last_air_peak_height, jump if not jump.is_empty() else "—", str(seam.get("current", "?")) + " → " + str(seam.get("next", "?")), "SI" if vehicle.is_on_floor() else "NO", float(seam.get("distance_to_seam", 0)), float(seam.get("vertical_delta", 0)), float(seam.get("angular_delta", 0)), vehicle.last_suspicious_collider]

func update_rally(enabled: bool, time: float, penalty: float, checkpoint: int, total: int, vehicle: VehicleController, note: Dictionary, bonus_seconds:int=0, mode_name:String="", difficulty_name:String="") -> void:
	if enabled:
		var bonus_text:="  +%ds"%bonus_seconds if bonus_seconds>0 else ""
		var difficulty_text:="DIFFICOLTÀ %s\n"%difficulty_name if not difficulty_name.is_empty() else ""
		rally_label.text = "%sTEMPO  %02d:%02d%s\nPENALITÀ  +%.1fs\nCP  %d/%d\nMARCIA  %d   RPM %d\n%s" % [difficulty_text, int(time) / 60, int(time)%60, bonus_text, penalty, checkpoint, total, vehicle.simulated_gear, int(vehicle.simulated_rpm), vehicle.surface]
		var note_text:=str(note.get("text","")).strip_edges()
		if note_text.is_empty():
			pacenote_label.text="PROVA SPECIALE\nPROSSIMO CP  %d/%d"%[mini(checkpoint+1,total),total]
		else:
			var arrow: String = "◀" if int(note.get("direction",0)) > 0 else ("▶" if int(note.get("direction",0)) < 0 else "▲")
			pacenote_label.text = "%s  %s\n%d m" % [arrow, note_text, int(note.get("distance",0.0))]
	else:
		pacenote_label.text="ENDURANCE\nMANTIENI CARBURANTE E INTEGRITÀ"
		rally_label.text="ENDURANCE\nMARCIA  %d   RPM %d\n%s\nBONUS E OSTACOLI"%[vehicle.simulated_gear,int(vehicle.simulated_rpm),vehicle.surface]
	pace_panel.visible=not pacenote_label.text.strip_edges().is_empty()
	rally_panel.visible=not rally_label.text.strip_edges().is_empty()
	pacenote_label.visible=pace_panel.visible
	rally_label.visible=rally_panel.visible
