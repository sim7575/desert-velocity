class_name RoadManager
extends Node3D

signal collectible_collected(kind: int, area: Area3D)

const ENVIRONMENT_V2_PLAYABLE_PILOT_PATH := "res://scenes/production_visual_pilot/environment/EnvironmentV2PlayableScenarioPilot.tscn"
const FULL_SPECIAL_STAGE_VISUAL_PATH := "res://scenes/production_visual_pilot/full_stage/FullSpecialStageVisualExpansion.tscn"
const ENDURANCE_G1F1_VISUAL_PATH := "res://scenes/production_visual_pilot/full_stage/EnduranceG1F1VisualAdapter.tscn"
static var use_environment_v2_playable_pilot := true
static var use_full_special_stage_visual_expansion := true

# Il gioco principale imposta questo override per rendere la scelta dello
# scenario indipendente dal veicolo e da eventuali flag statici usati nei test.
# Una stringa vuota conserva il percorso di fallback reversibile preesistente.
var stage_visual_profile_path: String = ""

var segments: Array[Node3D] = []
var player: Node3D
var road_mat: StandardMaterial3D
var sand_mat: StandardMaterial3D
var line_mat: StandardMaterial3D
var next_start := Vector3(0, 0, BalanceData.SEGMENT_LENGTH * 0.5)
var next_heading: float = 0.0
var sequence_index: int = 0
var stage_mode: bool = false
var stage_route: Array[Dictionary] = []
var environment_visual_pilot: Node3D
var curve_pattern: Array[float] = [
	0.0,0.0,0.0, .07,.10,.10,.07, 0.0,0.0,
	.11,.11,-.11,-.11,.10,-.10, 0.0,0.0,
	.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,.145,
	0.0,0.0,0.0,
	-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145,-.145
]

func setup(target: Node3D) -> void:
	player = target
	if stage_mode: stage_route=HandcraftedStage.route()
	road_mat = VehicleFactory.material(Color("30343b"))
	sand_mat = VehicleFactory.material(Color("c78945"))
	line_mat = VehicleFactory.material(Color("f2d36b"), 0.0, Color("6b551c"))
	for i in BalanceData.SEGMENT_COUNT:
		var segment := _create_segment(i)
		add_child(segment)
		_place_at_tail(segment)
		if stage_mode:_add_gameplay(segment)
		segments.append(segment)
	if use_environment_v2_playable_pilot and (stage_mode or not stage_visual_profile_path.is_empty()):
		var visual_path := stage_visual_profile_path
		if visual_path.is_empty():
			visual_path = FULL_SPECIAL_STAGE_VISUAL_PATH if use_full_special_stage_visual_expansion else ENVIRONMENT_V2_PLAYABLE_PILOT_PATH
		_attach_environment_visual_pilot(visual_path)

func _attach_environment_visual_pilot(visual_path: String = ENVIRONMENT_V2_PLAYABLE_PILOT_PATH) -> void:
	if not ResourceLoader.exists(visual_path):
		push_warning("Environment V2 playable pilot non disponibile: scenario originale conservato")
		return
	var packed := load(visual_path) as PackedScene
	if packed == null:
		push_warning("Environment V2 playable pilot non caricabile: scenario originale conservato")
		return
	environment_visual_pilot = packed.instantiate() as Node3D
	if environment_visual_pilot == null:
		push_warning("Environment V2 playable pilot non istanziabile: scenario originale conservato")
		return
	add_child(environment_visual_pilot)
	environment_visual_pilot.call("configure", self)

func stage_layout() -> Array[Dictionary]:
	# Preview e gameplay condividono deliberatamente questa stessa integrazione
	# cumulativa: nessuna mini-mappa con una route fittizia separata.
	var layout:Array[Dictionary]=[]
	var origin:=Vector3(0,0,BalanceData.SEGMENT_LENGTH*.5)
	var heading:=0.0
	for index in HandcraftedStage.route().size():
		var data:Dictionary=HandcraftedStage.route()[index]
		var curve:=float(data.get("curve",0.0)); var pitch:=float(data.get("pitch",0.0))
		var middle_heading:=heading+curve*.5; var basis:=Basis.from_euler(Vector3(pitch,middle_heading,0)); var forward:Vector3=-basis.z
		var center:=origin+forward*BalanceData.SEGMENT_LENGTH*.5
		layout.append({"index":index,"transform":Transform3D(basis,center),"start":origin,"end":origin+forward*BalanceData.SEGMENT_LENGTH,"yaw_start":heading,"yaw_end":heading+curve,"yaw_degrees":rad_to_deg(heading+curve),"pitch":pitch,"curve":curve,"note":str(data.get("note","")),"jump_kind":str(data.get("jump_kind",""))})
		origin+=forward*BalanceData.SEGMENT_LENGTH; heading+=curve
	return layout

func _process(_delta: float) -> void:
	if player == null or segments.is_empty(): return
	var first := segments[0]
	var local_player := first.to_local(player.global_position)
	var nearest:=_nearest_segment(player.global_position)
	if local_player.z < -BalanceData.SEGMENT_LENGTH * 0.8 and player.global_position.distance_to(first.global_position)>BalanceData.SEGMENT_LENGTH*1.35 and nearest!=first:
		segments.pop_front()
		_clear_spawns(first)
		_place_at_tail(first)
		_add_gameplay(first)
		segments.append(first)

func _place_at_tail(segment: Node3D) -> void:
	var route_data:Dictionary=stage_route[mini(sequence_index,stage_route.size()-1)] if stage_mode and not stage_route.is_empty() else {}
	var delta_heading: float = float(route_data.get("curve",curve_pattern[sequence_index % curve_pattern.size()]))
	var pitch:float=float(route_data.get("pitch",sin(sequence_index*.35)*.008))
	var segment_heading: float = next_heading + delta_heading * 0.5
	var segment_basis:=Basis.from_euler(Vector3(pitch,segment_heading,0))
	var forward := -segment_basis.z
	segment.global_position = next_start + forward * BalanceData.SEGMENT_LENGTH * 0.5
	segment.basis=segment_basis
	var stage_surface:String=str(route_data.get("surface","ASPHALT" if (sequence_index/5)%2==0 else "GRAVEL"))
	segment.set_meta("surface",stage_surface); segment.set_meta("route_index",sequence_index); segment.set_meta("curve_delta",delta_heading);segment.set_meta("pitch",pitch);segment.set_meta("note",str(route_data.get("note","")));segment.set_meta("jump_kind",str(route_data.get("jump_kind","")))
	var road_mesh:=segment.get_node_or_null("RoadSurface") as MeshInstance3D
	if road_mesh!=null: road_mesh.material_override=VehicleFactory.material(ArtDirection.ASPHALT if stage_surface=="ASPHALT" else ArtDirection.GRAVEL)
	_configure_stage_jump_profile(segment,str(route_data.get("jump_kind","")),stage_surface)
	next_start += forward * BalanceData.SEGMENT_LENGTH
	next_heading += delta_heading
	_decorate_route(segment,sequence_index,delta_heading)
	if environment_visual_pilot != null:
		environment_visual_pilot.call("update_segment_visual", segment, int(segment.get_meta("route_index", -1)))
	sequence_index += 1

func is_on_road(world_position: Vector3) -> bool:
	return absf(road_local_position(world_position).x) <= BalanceData.ROAD_HALF_WIDTH

func direction_to_center(world_position: Vector3) -> Vector3:
	var nearest := _nearest_segment(world_position)
	if nearest == null: return Vector3.ZERO
	var local := nearest.to_local(world_position)
	var center_world := nearest.to_global(Vector3(0, local.y, local.z))
	return world_position.direction_to(center_world)

func road_local_position(world_position: Vector3) -> Vector3:
	var nearest := _nearest_segment(world_position)
	return nearest.to_local(world_position) if nearest != null else Vector3(999, 0, 0)

func curve_direction_near(world_position: Vector3) -> Vector3:
	var nearest := _nearest_segment(world_position)
	return -nearest.global_transform.basis.z if nearest != null else Vector3.FORWARD

func surface_at(world_position: Vector3) -> String:
	var nearest:=_nearest_segment(world_position)
	if nearest==null:return "DEEP_SAND"
	var local:=nearest.to_local(world_position)
	if absf(local.x)<=BalanceData.ROAD_HALF_WIDTH:return str(nearest.get_meta("surface","ASPHALT"))
	return "DEEP_SAND" if absf(local.x)>BalanceData.SOFT_WORLD_LIMIT else "SAND"

func pacenote_near(world_position: Vector3) -> Dictionary:
	var nearest:=_nearest_segment(world_position)
	if nearest==null:return {"text":"ATTENZIONE","distance":0.0,"direction":0}
	var idx:=segments.find(nearest); var target:=segments[mini(idx+2,segments.size()-1)]
	var curve:float=float(target.get_meta("curve_delta",0.0)); var text_:String=str(target.get_meta("note",""));var direction:=0
	if text_.is_empty():text_="RETTILINEO LUNGO"
	if absf(curve)>.13: direction=1 if curve>0 else -1
	elif absf(curve)>.085: direction=1 if curve>0 else -1
	elif absf(curve)>.035: direction=1 if curve>0 else -1
	return {"text":text_,"distance":world_position.distance_to(target.global_position),"direction":direction}

func jump_kind_near(world_position:Vector3)->String:
	var nearest:=_nearest_segment(world_position)
	return str(nearest.get_meta("jump_kind","")) if nearest!=null else ""

func safe_transform_near(world_position: Vector3) -> Transform3D:
	var nearest := _nearest_segment(world_position)
	if nearest == null: return Transform3D(Basis.IDENTITY, Vector3(0,.1,0))
	var local := nearest.to_local(world_position)
	local.x = 0.0
	local.y = 0.1
	local.z = clampf(local.z, -BalanceData.SEGMENT_LENGTH*.42, BalanceData.SEGMENT_LENGTH*.42)
	var origin := nearest.to_global(local)
	return Transform3D(nearest.global_transform.basis.orthonormalized(), origin)

func segment_name_near(world_position: Vector3) -> String:
	var nearest := _nearest_segment(world_position)
	return str(nearest.name) if nearest != null else "NESSUNO"

func route_index_near(world_position:Vector3)->int:
	var nearest:=_nearest_segment(world_position)
	return int(nearest.get_meta("route_index",-1)) if nearest!=null else -1

func seam_debug_info(world_position:Vector3)->Dictionary:
	var current:=_nearest_segment(world_position)
	if current==null:return {}
	var idx:=segments.find(current);var next:=segments[mini(idx+1,segments.size()-1)];var local:=current.to_local(world_position)
	var current_end:=current.to_global(Vector3(0,0,-BalanceData.SEGMENT_LENGTH*.5));var next_start_pos:=next.to_global(Vector3(0,0,BalanceData.SEGMENT_LENGTH*.5))
	return {"current":str(current.name),"next":str(next.name),"distance_to_seam":absf(local.z+BalanceData.SEGMENT_LENGTH*.5),"current_end":current_end,"next_start":next_start_pos,"vertical_delta":next_start_pos.y-current_end.y,"angular_delta":rad_to_deg(current.global_transform.basis.z.angle_to(next.global_transform.basis.z))}

func is_point_near_active(world_position: Vector3) -> bool:
	var nearest := _nearest_segment(world_position)
	if nearest == null: return false
	var local := nearest.to_local(world_position)
	return absf(local.x)<BalanceData.ROAD_HALF_WIDTH and absf(local.z)<BalanceData.SEGMENT_LENGTH*.6

func _nearest_segment(world_position: Vector3) -> Node3D:
	var best: Node3D
	var best_distance := INF
	for segment in segments:
		var local := segment.to_local(world_position)
		var dz: float = maxf(absf(local.z) - BalanceData.SEGMENT_LENGTH * 0.5, 0.0)
		var distance: float = absf(local.x) + dz * 2.0
		if distance < best_distance:
			best_distance = distance
			best = segment
	return best

func _create_segment(seed_index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "RoadSegment%02d" % seed_index
	var ground := StaticBody3D.new(); ground.name="DriveGround"; root.add_child(ground)
	# Un solo piano collisione continuo: evita il gradino invisibile che bloccava il rientro.
	_add_box(root, Vector3(100, 0.06, BalanceData.SEGMENT_LENGTH+.25), Vector3(0, -0.03, 0), sand_mat, false)
	_add_drive_surface(ground,50.0,BalanceData.SEGMENT_LENGTH*.5)
	var road_surface:=_add_box(root, Vector3(BalanceData.ROAD_HALF_WIDTH * 2.0, 0.035, BalanceData.SEGMENT_LENGTH), Vector3(0, 0.018, 0), road_mat, false); road_surface.name="RoadSurface"
	for x: float in [-BalanceData.ROAD_HALF_WIDTH + 0.35, BalanceData.ROAD_HALF_WIDTH - 0.35]:
		_add_box(root, Vector3(0.2, 0.035, BalanceData.SEGMENT_LENGTH - 0.8), Vector3(x, 0.04, 0), line_mat, false)
	for z: float in [-20.0, -10.0, 0.0, 10.0, 20.0]:
		_add_box(root, Vector3(0.16, 0.03, 4.8), Vector3(0, 0.05, z), line_mat, false)
	for z: float in [-20.0,-8.0,8.0,20.0]:
		for x: float in [-9.4,9.4]:
			var post:=Node3D.new(); post.position=Vector3(x,0,z); root.add_child(post)
			_add_box(post,Vector3(.16,1.25,.16),Vector3(0,.62,0),VehicleFactory.material(Color("eeeeea")),false)
			_add_box(post,Vector3(.23,.28,.08),Vector3(0,1.05,-.08),VehicleFactory.material(Color("ffb32b"),0,Color("ff8a1d")),false)
	_add_scenery(root, seed_index)
	if not stage_mode:_add_gameplay(root)
	return root

func _clear_spawns(segment: Node3D) -> void:
	for child in segment.get_children():
		if child.is_in_group("spawned") or child.is_in_group("route_detail") or child.is_in_group("stage_jump_geometry"): child.queue_free()

func _configure_stage_jump_profile(segment:Node3D,jump_kind:String,stage_surface:String)->void:
	# Il piano originale rimane per i segmenti normali. Nei tre salti viene
	# disattivato e sostituito da vertici e collisione generati dallo stesso profilo.
	for child in segment.get_children():
		if child.is_in_group("stage_jump_geometry"): child.queue_free()
	var road_mesh:=segment.get_node_or_null("RoadSurface") as MeshInstance3D
	var ground:=segment.get_node_or_null("DriveGround") as StaticBody3D
	var flat_shape:=ground.get_node_or_null("ContinuousDriveSurface") as CollisionShape3D if ground!=null else null
	if jump_kind.is_empty():
		if road_mesh!=null: road_mesh.visible=true
		if flat_shape!=null: flat_shape.disabled=false
		return
	if road_mesh!=null: road_mesh.visible=false
	if flat_shape!=null: flat_shape.disabled=true
	var profile:=_jump_profile(jump_kind)
	var geometry:=Node3D.new(); geometry.name="StageJump_%s"%jump_kind; geometry.add_to_group("stage_jump_geometry"); segment.add_child(geometry)
	var mesh:=MeshInstance3D.new(); mesh.name="ProfiledRoad"; mesh.mesh=_profile_mesh(profile); mesh.material_override=VehicleFactory.material(ArtDirection.ASPHALT if stage_surface=="ASPHALT" else ArtDirection.GRAVEL); geometry.add_child(mesh)
	var body:=StaticBody3D.new(); body.name="ProfiledDriveGround"; geometry.add_child(body)
	var collision:=CollisionShape3D.new(); collision.name="ProfiledDriveSurface"; collision.shape=_profile_collision(profile); body.add_child(collision)

func _jump_profile(jump_kind:String)->PackedVector2Array:
	# x = coordinata longitudinale locale, y = quota locale. Ogni profilo
	# termina a zero: nessun gradino o piano sovrapposto alle giunzioni.
	match jump_kind:
		"DOSSO": return PackedVector2Array([Vector2(-26,0),Vector2(-14,0),Vector2(-8,.28),Vector2(-2,.78),Vector2(3,.80),Vector2(9,.30),Vector2(15,0),Vector2(26,0)])
		# Il veicolo percorre il profilo da +26 verso -26. Il breve labbro e la
		# discesa successiva all'apice impediscono al corpo di seguire il collider
		# con la sola velocità verticale di contatto: il distacco resta geometrico.
		"CRESTA": return PackedVector2Array([Vector2(-26,0),Vector2(-18,.03),Vector2(-11,.08),Vector2(-4,.12),Vector2(0,.16),Vector2(3,.28),Vector2(5,3.02),Vector2(8,3.18),Vector2(11,2.20),Vector2(17,.62),Vector2(23,.08),Vector2(26,0)])
		"RAMPA": return PackedVector2Array([Vector2(-26,0),Vector2(-18,.03),Vector2(-11,.10),Vector2(-4,.16),Vector2(0,.22),Vector2(3,.38),Vector2(5,2.28),Vector2(8,2.42),Vector2(11,1.78),Vector2(17,.48),Vector2(23,.06),Vector2(26,0)])
	return PackedVector2Array()

func _profile_mesh(profile:PackedVector2Array)->ArrayMesh:
	var vertices:=PackedVector3Array(); var indices:=PackedInt32Array(); var half_width:=BalanceData.ROAD_HALF_WIDTH
	for point in profile:
		vertices.append(Vector3(-half_width,point.y,point.x)); vertices.append(Vector3(half_width,point.y,point.x))
	for i in range(profile.size()-1):
		var a:=i*2; indices.append_array(PackedInt32Array([a,a+1,a+3,a,a+3,a+2]))
	var arrays:=[]; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX]=vertices; arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays); return mesh

func _profile_collision(profile:PackedVector2Array)->ConcavePolygonShape3D:
	var faces:=PackedVector3Array(); var half_width:=BalanceData.ROAD_HALF_WIDTH
	for i in range(profile.size()-1):
		var a:=Vector3(-half_width,profile[i].y,profile[i].x); var b:=Vector3(half_width,profile[i].y,profile[i].x)
		var c:=Vector3(-half_width,profile[i+1].y,profile[i+1].x); var d:=Vector3(half_width,profile[i+1].y,profile[i+1].x)
		faces.append_array(PackedVector3Array([a,b,d,a,d,c]))
	var shape:=ConcavePolygonShape3D.new(); shape.set_faces(faces); shape.backface_collision=true; return shape

func _decorate_route(root:Node3D,index:int,curve:float)->void:
	if not stage_mode:return
	if index in [0,9,19,29,39,49,59,63]:
		var arch:=Node3D.new();arch.add_to_group("route_detail");root.add_child(arch);arch.position=Vector3(0,0,-18)
		var color:=ArtDirection.HAZARD if index not in [0,63] else ArtDirection.RALLY_RED
		_add_box(arch,Vector3(.55,5,.55),Vector3(-8.8,2.5,0),VehicleFactory.material(color),false);_add_box(arch,Vector3(.55,5,.55),Vector3(8.8,2.5,0),VehicleFactory.material(color),false);_add_box(arch,Vector3(18.1,.6,.6),Vector3(0,4.8,0),VehicleFactory.material(color),false)
	if absf(curve)>.12:
		for side:float in [-1,1]:
			for j in 4:
				var person:=Node3D.new();person.add_to_group("route_detail");root.add_child(person);person.position=Vector3(side*(13+j*1.3),0,-12+j*5)
				_add_box(person,Vector3(.45,1.35,.35),Vector3(0,.68,0),VehicleFactory.material(Color("304d6d") if j%2==0 else Color("a34332")),false);_add_box(person,Vector3(.38,.38,.38),Vector3(0,1.55,0),VehicleFactory.material(Color("c68b62")),false)

func _add_gameplay(root: Node3D) -> void:
	if stage_mode:
		var index:int=int(root.get_meta("route_index",0))
		if index%8==4:_make_collectible(root,Vector3(0,1.35,0),2 if index%16==4 else 3)
		if absf(float(root.get_meta("curve_delta",0)))>.12:
			_make_obstacle(root,Vector3(-7.1,0,8),1);_make_obstacle(root,Vector3(7.1,0,-8),1)
		return
	var lanes: Array[float] = [-5.5, 0.0, 5.5]; lanes.shuffle()
	if randf() < 0.82: _make_obstacle(root, Vector3(lanes[0], 0, randf_range(-19, 8)), randi() % 6)
	if randf() < 0.68: _make_collectible(root, Vector3(lanes[1], 1.35, randf_range(-20, 18)), randi() % 5)

func _make_obstacle(root: Node3D, pos: Vector3, kind: int) -> void:
	var body := StaticBody3D.new(); body.add_to_group("obstacle"); body.add_to_group("spawned"); body.set_meta("damage", 10.0 + kind * 2.0); body.position = pos; root.add_child(body)
	var sizes: Array[Vector3] = [Vector3(2.4,1.5,2.1),Vector3(4.0,1.25,0.8),Vector3(2.8,0.35,2.8),Vector3(2.7,1.6,4.3),Vector3(1.8,1.8,1.8),Vector3(3.0,0.85,2.0)]
	var colors: Array[Color] = [Color("6e5141"),Color("9b9b91"),Color("332f2b"),Color("66554c"),Color("704b2a"),Color("5b5851")]
	_add_box(body, sizes[kind], Vector3(0, sizes[kind].y * 0.5, 0), VehicleFactory.material(colors[kind]), true)
	if kind in [1, 5]:
		var stripe := VehicleFactory.material(Color("d5a62b"))
		for x: float in [-1.2, 0.0, 1.2]: _add_box(body, Vector3(.45,.12,.84), Vector3(x,sizes[kind].y+.07,0), stripe, false)

func _make_collectible(root: Node3D, pos: Vector3, kind: int) -> void:
	var area := Area3D.new(); area.add_to_group("collectible"); area.add_to_group("spawned"); area.set_meta("kind", kind); area.collision_layer=4; area.collision_mask=2; area.position=pos; root.add_child(area)
	var shape := CollisionShape3D.new(); var sphere := SphereShape3D.new(); sphere.radius=.9; shape.shape=sphere; area.add_child(shape)
	var colors: Array[Color]=[Color("ef4938"),Color("ffd43b"),Color("5ee08d"),Color("25d9f2"),Color("c68cff")]
	var mesh := MeshInstance3D.new(); var box := BoxMesh.new(); box.size=Vector3(.8,1.2,.45); mesh.mesh=box; mesh.material_override=VehicleFactory.material(colors[kind],.25,colors[kind]); area.add_child(mesh)
	var ring := MeshInstance3D.new(); var torus:=TorusMesh.new(); torus.inner_radius=.78; torus.outer_radius=.93; ring.mesh=torus; ring.rotation.x=PI/2; ring.material_override=VehicleFactory.material(colors[kind],.1,colors[kind]); area.add_child(ring)
	var light:=OmniLight3D.new(); light.light_color=colors[kind]; light.light_energy=1.8; light.omni_range=3.2; area.add_child(light)
	area.set_script(load("res://scripts/spin_collectible.gd"))
	area.body_entered.connect(func(body: Node3D):
		if body is VehicleController: collectible_collected.emit(kind,area)
	)

func _add_scenery(root: Node3D, seed_index: int) -> void:
	for side: float in [-1.0,1.0]:
		for j in 3:
			var deco:=Node3D.new(); deco.position=Vector3(side*(15+j*9+fmod(seed_index*3,5)),-.02,-18+j*17); root.add_child(deco)
			if (seed_index+j)%3==0:
				var cactus:=VehicleFactory.material(Color("477447")); _add_box(deco,Vector3(.65,3.8,.65),Vector3(0,1.9,0),cactus,false); _add_box(deco,Vector3(1.7,.55,.55),Vector3(side*.55,2.2,0),cactus,false)
			else:
				_add_box(deco,Vector3(2.5+j,1.4+j*.45,2.2),Vector3(0,.7,0),VehicleFactory.material(Color("8d6042")),false)
				var bush:=VehicleFactory.material(Color("665038")); _add_box(deco,Vector3(1.5,.14,.14),Vector3(side*2,.25,1),bush,false); _add_box(deco,Vector3(.14,.9,.14),Vector3(side*2,.4,1),bush,false)
			if j==2:
				var dune:=MeshInstance3D.new(); var sphere:=SphereMesh.new(); sphere.radius=8; sphere.height=5; sphere.radial_segments=12; sphere.rings=6; dune.mesh=sphere; dune.scale=Vector3(1.8,.55,1); dune.position=Vector3(side*12,-1.8,4); dune.material_override=VehicleFactory.material(Color("bd7e3e")); deco.add_child(dune)

func _add_box(parent: Node, size: Vector3, pos: Vector3, mat: Material, collision: bool) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=size; mesh.mesh=box; mesh.position=pos; mesh.material_override=mat; parent.add_child(mesh)
	if collision and parent is CollisionObject3D:
		var shape:=CollisionShape3D.new(); var box_shape:=BoxShape3D.new(); box_shape.size=size; shape.shape=box_shape; shape.position=pos; parent.add_child(shape)
	return mesh

func _add_drive_surface(body:StaticBody3D,half_width:float,half_length:float)->void:
	# Superficie top-only: nessuna faccia terminale/verticale può colpire il veicolo.
	var points:=PackedVector3Array([
		Vector3(-half_width,0,-half_length),Vector3(half_width,0,half_length),Vector3(half_width,0,-half_length),
		Vector3(-half_width,0,-half_length),Vector3(-half_width,0,half_length),Vector3(half_width,0,half_length)
	])
	var shape_data:=ConcavePolygonShape3D.new();shape_data.set_faces(points);shape_data.backface_collision=true
	var shape:=CollisionShape3D.new();shape.name="ContinuousDriveSurface";shape.shape=shape_data;body.add_child(shape)
