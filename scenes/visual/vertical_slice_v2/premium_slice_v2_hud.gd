class_name PremiumSliceV2HUD
extends CanvasLayer

class HUDSurface extends Control:
	var ratio := 0.0
	var boost := 0.0
	func _draw() -> void:
		var sand := Color("d8b476")
		var amber := Color("ef9c45")
		var red := Color("be4c36")
		draw_polyline(PackedVector2Array([Vector2(46, 668), Vector2(58, 642), Vector2(178, 642)]), sand, 1.6, true)
		draw_arc(Vector2(1120, 650), 62, PI, TAU, 28, Color(0.08, 0.09, 0.10, 0.52), 6.0, true)
		draw_arc(Vector2(1120, 650), 62, PI, PI + PI * boost, 28, amber.lerp(red, boost), 6.0, true)
		draw_polyline(PackedVector2Array([Vector2(430, 51), Vector2(458, 42), Vector2(822, 42), Vector2(850, 51)]), Color(0.92, 0.78, 0.52, 0.68), 1.2, true)
		for index in 16:
			var x := 464.0 + index * 22.0
			var active := float(index) / 15.0 <= ratio
			var color := amber if active else Color(0.12, 0.13, 0.14, 0.50)
			draw_colored_polygon(PackedVector2Array([Vector2(x, 60), Vector2(x + 15, 60), Vector2(x + 12, 65), Vector2(x - 3, 65)]), color)
	func set_values(progress_value: float, boost_value: float) -> void:
		ratio = progress_value; boost = boost_value; queue_redraw()

var surface: HUDSurface
var speed_label: Label
var unit_label: Label
var cue_label: Label
var boost_label: Label

func _ready() -> void:
	surface = HUDSurface.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(surface)
	speed_label = _label(Vector2(60, 604), Vector2(150, 50), 36, Color("f2e6cf"), HORIZONTAL_ALIGNMENT_LEFT)
	unit_label = _label(Vector2(62, 650), Vector2(80, 20), 11, Color("d8b476"), HORIZONTAL_ALIGNMENT_LEFT); unit_label.text = "KM/H"
	cue_label = _label(Vector2(430, 14), Vector2(420, 26), 14, Color("f1d09b"), HORIZONTAL_ALIGNMENT_CENTER)
	boost_label = _label(Vector2(1068, 626), Vector2(104, 20), 11, Color("ef9c45"), HORIZONTAL_ALIGNMENT_CENTER); boost_label.text = "BOOST"

func _label(position_value: Vector2, size_value: Vector2, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.position = position_value; label.size = size_value
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	label.add_theme_constant_override("shadow_offset_x", 2); label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label

func update_hud(ratio: float, speed_kmh: int, boost: float) -> void:
	speed_label.text = "%03d" % speed_kmh
	surface.set_values(ratio, boost)
	boost_label.modulate = Color.WHITE if boost > 0.08 else Color(0.75, 0.70, 0.62, 0.76)
	if ratio < 0.16: cue_label.text = "CURVA  ›  TRAIETTORIA ESTERNA"
	elif ratio < 0.31: cue_label.text = "SORPASSO  ›  MANTIENI LA LINEA"
	elif ratio < 0.47: cue_label.text = "DISCESA  ›  CANYON"
	elif ratio < 0.62: cue_label.text = "OSTACOLO  ›  SINISTRA"
	elif ratio < 0.73: cue_label.text = "DOSSO  ›  ALLEGGERISCI"
	elif ratio < 0.88: cue_label.text = "BOOST  ›  POTENZA MECCANICA"
	else: cue_label.text = "ARCO  ›  USCITA"
