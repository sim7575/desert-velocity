extends Node3D

const WIDTH:=12.0
var car:VehicleController
var selected:=0
func _ready()->void:
	for action in ["accelerate","brake","steer_left","steer_right","handbrake","reset_vehicle","camera_toggle"]:
		if not InputMap.has_action(action):InputMap.add_action(action)
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color("91a5bd");env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_energy=.75
	var world:=WorldEnvironment.new();world.environment=env;add_child(world)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);sun.light_energy=1.25;sun.shadow_enabled=true;add_child(sun)
	var camera:=CameraController.new();camera.name="JumpCamera";camera.position=Vector3(0,5,12);add_child(camera)
	_make_surface("Approach",[Vector2(80,0),Vector2(48,0)],Color("3b4148"));_make_surface("Dosso",[Vector2(48,0),Vector2(42,.22),Vector2(38,.62),Vector2(34,.82),Vector2(30,.62),Vector2(26,.20),Vector2(22,0)],Color("5a5145"));_make_surface("Cresta",[Vector2(22,0),Vector2(16,.24),Vector2(10,.78),Vector2(4,1.32),Vector2(-1,1.28),Vector2(-5,.75),Vector2(-9,.15),Vector2(-14,0)],Color("6a5a42"));_make_surface("Rampa",[Vector2(-14,0),Vector2(-20,.18),Vector2(-25,.72),Vector2(-30,1.35),Vector2(-34,1.62),Vector2(-38,1.22),Vector2(-43,.42),Vector2(-48,0)],Color("735b39"));_make_surface("Landing",[Vector2(-48,0),Vector2(-100,0)],Color("3b4148"))
	_spawn_car()
func _make_surface(name_:String,profile:Array[Vector2],color:Color)->void:
	var vertices:=PackedVector3Array();var faces:=PackedInt32Array()
	for point in profile:vertices.append(Vector3(-WIDTH*.5,point.y,point.x));vertices.append(Vector3(WIDTH*.5,point.y,point.x))
	for i in profile.size()-1:
		var a:=i*2;faces.append_array(PackedInt32Array([a,a+1,a+3,a,a+3,a+2]))
	var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_INDEX]=faces
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var body:=StaticBody3D.new();body.name=name_;add_child(body)
	var visible:=MeshInstance3D.new();visible.mesh=mesh;var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=.88;visible.material_override=mat;body.add_child(visible)
	var shape:=CollisionShape3D.new();var concave:=ConcavePolygonShape3D.new();var collision_faces:=PackedVector3Array()
	for idx in faces:collision_faces.append(vertices[idx])
	concave.set_faces(collision_faces);shape.shape=concave;body.add_child(shape)
func _spawn_car()->void:
	if car:car.queue_free()
	car=VehicleController.new();car.setup(selected);car.position=Vector3(0,.8,70);add_child(car);(get_node("JumpCamera") as CameraController).target=car
func _unhandled_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_1:selected=0;_spawn_car()
		elif event.keycode==KEY_2:selected=1;_spawn_car()
		elif event.keycode==KEY_R:car.position=Vector3(0,.8,70);car.velocity=Vector3.ZERO;car.speed=0
