class_name PremiumSliceHUD
extends CanvasLayer

var speed_label: Label
var speed_unit: Label
var phase_label: Label
var progress_bar: ProgressBar
var boost_bar: ProgressBar
var boost_label: Label

func _ready() -> void:
	speed_label = Label.new()
	speed_label.position = Vector2(42, 612)
	speed_label.size = Vector2(140, 54)
	speed_label.add_theme_font_size_override("font_size", 36)
	speed_label.add_theme_color_override("font_color", Color("f4e5cc"))
	speed_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.62))
	speed_label.add_theme_constant_override("shadow_offset_x", 2)
	speed_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(speed_label)
	speed_unit = Label.new()
	speed_unit.text = "KM/H"
	speed_unit.position = Vector2(46, 660)
	speed_unit.add_theme_font_size_override("font_size", 12)
	speed_unit.add_theme_color_override("font_color", Color("d9b77e"))
	add_child(speed_unit)
	phase_label = Label.new()
	phase_label.position = Vector2(390, 28)
	phase_label.size = Vector2(500, 34)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_label.add_theme_font_size_override("font_size", 16)
	phase_label.add_theme_color_override("font_color", Color("e7c48e"))
	phase_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	add_child(phase_label)
	progress_bar = ProgressBar.new()
	progress_bar.position = Vector2(430, 68)
	progress_bar.size = Vector2(420, 5)
	progress_bar.max_value = 1.0
	progress_bar.show_percentage = false
	var background := StyleBoxFlat.new(); background.bg_color = Color(0.025, 0.03, 0.04, 0.58); background.corner_radius_top_left = 2; background.corner_radius_top_right = 2; background.corner_radius_bottom_left = 2; background.corner_radius_bottom_right = 2
	var fill := StyleBoxFlat.new(); fill.bg_color = Color("e2a14f"); fill.corner_radius_top_left = 2; fill.corner_radius_top_right = 2; fill.corner_radius_bottom_left = 2; fill.corner_radius_bottom_right = 2
	progress_bar.add_theme_stylebox_override("background", background)
	progress_bar.add_theme_stylebox_override("fill", fill)
	add_child(progress_bar)
	boost_label = Label.new()
	boost_label.text = "BOOST"
	boost_label.position = Vector2(1124, 644)
	boost_label.add_theme_font_size_override("font_size", 12)
	boost_label.add_theme_color_override("font_color", Color("8fe8ff"))
	add_child(boost_label)
	boost_bar = ProgressBar.new()
	boost_bar.position = Vector2(936, 672)
	boost_bar.size = Vector2(302, 7)
	boost_bar.max_value = 1.0
	boost_bar.show_percentage = false
	var boost_background := StyleBoxFlat.new(); boost_background.bg_color = Color(0.025, 0.04, 0.055, 0.66); boost_background.corner_radius_top_left = 3; boost_background.corner_radius_top_right = 3; boost_background.corner_radius_bottom_left = 3; boost_background.corner_radius_bottom_right = 3
	var boost_fill := StyleBoxFlat.new(); boost_fill.bg_color = Color("52d8f2"); boost_fill.corner_radius_top_left = 3; boost_fill.corner_radius_top_right = 3; boost_fill.corner_radius_bottom_left = 3; boost_fill.corner_radius_bottom_right = 3
	boost_bar.add_theme_stylebox_override("background", boost_background)
	boost_bar.add_theme_stylebox_override("fill", boost_fill)
	add_child(boost_bar)

func update_structure(ratio: float, speed_kmh: int) -> void:
	update_visual(ratio, speed_kmh, 0.0)

func update_visual(ratio: float, speed_kmh: int, boost: float) -> void:
	progress_bar.value = ratio
	boost_bar.value = boost
	speed_label.text = "%03d" % speed_kmh
	boost_label.modulate = Color.WHITE if boost > 0.05 else Color(0.62, 0.75, 0.80, 0.78)
	if ratio < 0.28: phase_label.text = "CURVA AMPIA  ·  TIENI LA TRAIETTORIA"
	elif ratio < 0.56: phase_label.text = "DISCESA  ·  SORPASSO"
	elif ratio < 0.68: phase_label.text = "ROCCE  ·  MANOVRA A SINISTRA"
	elif ratio < 0.72 and boost < 0.1: phase_label.text = "DOSSO  ·  PREPARA IL BOOST"
	else: phase_label.text = "BOOST  ·  USCITA CANYON"
