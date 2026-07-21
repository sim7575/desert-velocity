extends Node3D

var checkpoint_segments:=PackedInt32Array([9,19,29,39,49,59])

func _ready()->void:
	var environment:=WorldEnvironment.new(); var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=Color("151c22"); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color("b8c4cc"); env.ambient_light_energy=.8; environment.environment=env; add_child(environment)
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-58,-28,0); light.light_energy=1.5; add_child(light)
	var layout:=RoadManager.new().stage_layout()
	for item:Dictionary in layout: _draw_segment(item)
	_draw_marker(layout[0].start,"PARTENZA",Color("55d8ff"),5.0)
	_draw_marker(layout[layout.size()-1].end,"TRAGUARDO",Color("ffcf4c"),5.0)
	for checkpoint in checkpoint_segments: _draw_marker(layout[checkpoint].end,"CP %d/6"%((checkpoint_segments.find(checkpoint))+1),Color("55e58d"),3.2)
	var cam:=Camera3D.new(); cam.position=Vector3(0,310,35); cam.rotation_degrees=Vector3(-90,0,0); add_child(cam)

func _draw_segment(item:Dictionary)->void:
	var transform:Transform3D=item.transform; var line:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(.7,.14,BalanceData.SEGMENT_LENGTH); line.mesh=box; line.global_transform=transform; line.material_override=VehicleFactory.material(Color("e7b34c"),.15,Color("ffd466")); add_child(line)
	var direction:=MeshInstance3D.new(); var arrow:=BoxMesh.new(); arrow.size=Vector3(2.3,.2,5.0); direction.mesh=arrow; direction.global_transform=transform; direction.position+=(-transform.basis.z)*12+Vector3.UP*.16; direction.material_override=VehicleFactory.material(Color("60cbe5"),.1,Color("60cbe5")); add_child(direction)
	var label:Label3D=Label3D.new(); label.text="%02d  yaw %+.1f°  h %+.1f"%[int(item.index),float(item.yaw_degrees),transform.origin.y]; label.font_size=28; label.outline_size=4; label.modulate=Color.WHITE; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.position=transform.origin+Vector3.UP*3.0; add_child(label)
	var jump:=str(item.jump_kind); if not jump.is_empty(): _draw_marker(transform.origin,jump,Color("ff745d"),4.2)

func _draw_marker(world_position:Vector3,text_:String,color:Color,height:float)->void:
	var marker:=MeshInstance3D.new(); var cylinder:=CylinderMesh.new(); cylinder.top_radius=.55; cylinder.bottom_radius=.55; cylinder.height=height; marker.mesh=cylinder; marker.material_override=VehicleFactory.material(color,.15,color); marker.position=world_position+Vector3.UP*height*.5; add_child(marker)
	var label:=Label3D.new(); label.text=text_; label.font_size=42; label.outline_size=5; label.modulate=color; label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label.position=world_position+Vector3.UP*(height+1.5); add_child(label)
