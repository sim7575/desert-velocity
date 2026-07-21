extends Node

enum Screen {MENU, GARAGE, SETTINGS, GAME, GAME_OVER}

var screen: Screen = Screen.MENU
var save: Dictionary
var ui: CanvasLayer
var world: Node3D
var player: VehicleController
var camera: CameraController
var hud: GameHUD
var road: RoadManager
var audio := AudioManager.new()
var score: int = 0
var score_fraction: float = 0.0
var distance: float = 0.0
var fuel: float = 100.0
var health: float = 100.0
var multiplier: int = 1
var multiplier_time: float = 0.0
var offroad_time: float = 0.0
var collected: int = 0
var paused: bool = false
var garage_car: Node3D
var garage_camera: Camera3D
var run_mode:String="ENDURANCE"
var stage_time:float=0.0
var stage_penalty:float=0.0
var stage_checkpoint:int=0
var countdown:float=0.0
var stage_time_remaining:float=0.0
var stage_bonus_feedback_time:float=0.0
var stage_timeout_triggered:=false
var stage_difficulty_index:int=1
var difficulty_value_label:Label
var atmosphere_mode:int=0
var environment_resource:Environment
var sun_light:DirectionalLight3D
const STAGE_LENGTH:float=3200.0
const CHECKPOINT_DISTANCE:float=500.0
const STAGE_INITIAL_TIME:=90.0
const STAGE_CHECKPOINT_BONUS:=15.0
const STAGE_BONUS_FEEDBACK_DURATION:=1.0
const STAGE_DIFFICULTY_NAMES:=["FACILE","NORMALE","DIFFICILE"]
const STAGE_DIFFICULTY_INITIAL_TIMES:=[105.0,90.0,75.0]
const STAGE_DIFFICULTY_CHECKPOINT_BONUSES:=[18.0,15.0,12.0]
var stage_checkpoint_segments:=PackedInt32Array([9,19,29,39,49,59])

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	save = SaveManager.load_data()
	add_child(audio); audio.set_levels(float(save.music_volume),float(save.sfx_volume),bool(save.mute))
	show_menu()

func _exit_tree()->void:
	if is_instance_valid(audio):audio.shutdown()

func _setup_input() -> void:
	var bindings: Dictionary = {
		"accelerate":[KEY_W,KEY_UP], "brake":[KEY_S,KEY_DOWN],
		"steer_left":[KEY_A,KEY_LEFT], "steer_right":[KEY_D,KEY_RIGHT],
		"handbrake":[KEY_SPACE], "pause":[KEY_ESCAPE],
		"confirm":[KEY_ENTER], "camera_toggle":[KEY_C],
		"reset_vehicle":[KEY_R], "debug_overlay":[KEY_F3], "atmosphere_toggle":[KEY_F4]
	}
	for action: String in bindings:
		if not InputMap.has_action(action): InputMap.add_action(action, 0.2)
		if InputMap.action_get_events(action).is_empty():
			for keycode: Key in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = keycode
				InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	if screen == Screen.GAME and not paused:
		_update_game(delta)
	elif screen == Screen.GARAGE and garage_car != null:
		garage_car.rotation.y += delta * 0.35
	if Input.is_action_just_pressed("atmosphere_toggle") and world!=null:
		atmosphere_mode=(atmosphere_mode+1)%3;_apply_atmosphere()
	if Input.is_action_just_pressed("pause") and screen == Screen.GAME:
		set_pause(not paused)

func clear_scene() -> void:
	get_tree().paused = false; paused = false
	if is_instance_valid(ui): ui.queue_free()
	if is_instance_valid(world): world.queue_free()
	ui = null; world = null; player = null; hud = null; road = null; camera = null; garage_camera = null; difficulty_value_label = null

func make_ui() -> Control:
	ui = CanvasLayer.new(); add_child(ui)
	var root := Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); ui.add_child(root)
	var bg := ColorRect.new(); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color("17202a"); root.add_child(bg)
	return root

func title(root: Control, text_: String, subtitle: String) -> void:
	var label := Label.new(); label.text = text_; label.position = Vector2(0,70); label.size = Vector2(1280,90); label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 58); label.add_theme_color_override("font_color", Color("f4b942")); root.add_child(label)
	var sub := Label.new(); sub.text = subtitle; sub.position = Vector2(0,155); sub.size = Vector2(1280,45); sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20); root.add_child(sub)

func button(root: Control, text_: String, y: float, action: Callable) -> Button:
	var b := Button.new(); b.text = text_; b.position = Vector2(465,y); b.size = Vector2(350,58); b.add_theme_font_size_override("font_size", 22); b.pressed.connect(action); root.add_child(b); return b

func show_menu() -> void:
	audio.stop_game_audio()
	clear_scene(); screen = Screen.MENU; stage_difficulty_index=1
	var root := make_ui(); title(root,"DESERT VELOCITY","Guida arcade 3D • sabbia, turbo e sopravvivenza")
	button(root,"PROVA SPECIALE",225,func():run_mode="STAGE";show_garage()).grab_focus()
	button(root,"ENDURANCE",291,func():run_mode="ENDURANCE";show_garage())
	button(root,"GARAGE",357,show_garage)
	button(root,"IMPOSTAZIONI",423,show_settings)
	button(root,"COME SI GIOCA",489,show_help)
	button(root,"ESCI",555,func(): get_tree().quit())
	var help := Label.new(); help.text = "WASD / Frecce: guida    Spazio: freno a mano    C: telecamera    Esc: pausa"
	help.position = Vector2(0,675); help.size = Vector2(1280,35); help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(help)

func show_help() -> void:
	clear_scene()
	var root:=make_ui(); title(root,"COME SI GIOCA","Controlli, Prova Speciale ed Endurance")
	var info:=Label.new(); info.position=Vector2(105,198); info.size=Vector2(1070,400); info.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; info.add_theme_font_size_override("font_size",17)
	info.text="CONTROLLI\nFrecce o WASD: guida   •   Spazio: freno a mano   •   Esc: pausa   •   R: riposiziona\nTurbo: raccogli il bonus azzurro (attivazione automatica)   •   C: camera   •   F3: telemetria\n\nPROVA SPECIALE\nRaggiungi i checkpoint prima che il tempo scada: ogni checkpoint aggiunge tempo.\nCompleta CP 1–6 e attraversa il traguardo.\n\nENDURANCE\nMantieni carburante e integrità. Evita gli ostacoli e raccogli i bonus.\nAumenta il moltiplicatore per migliorare il punteggio.\n\nOSTACOLI: barriere, massi, casse, relitti e buche.\nBONUS: ROSSO carburante • GIALLO punti • VERDE riparazione • AZZURRO turbo • VIOLA moltiplicatore.\nR: -250 punti, -8 integrità."
	root.add_child(info); button(root,"INDIETRO",620,show_menu).grab_focus()

func show_settings() -> void:
	clear_scene(); screen = Screen.SETTINGS
	var root := make_ui(); title(root,"IMPOSTAZIONI","Volume generale e salvataggio locale")
	var slider := HSlider.new(); slider.position = Vector2(390,255); slider.size = Vector2(500,40); slider.min_value = 0; slider.max_value = 1; slider.step = .05; slider.value = float(save.music_volume); root.add_child(slider)
	var sfx_slider:=HSlider.new(); sfx_slider.position=Vector2(390,335); sfx_slider.size=Vector2(500,40); sfx_slider.min_value=0; sfx_slider.max_value=1; sfx_slider.step=.05; sfx_slider.value=float(save.sfx_volume); root.add_child(sfx_slider)
	var mute:=CheckButton.new(); mute.text="MUTO"; mute.position=Vector2(580,395); mute.button_pressed=bool(save.mute); root.add_child(mute)
	var quality:=OptionButton.new();quality.position=Vector2(515,435);quality.size=Vector2(250,42);quality.add_item("GRAFICA BASSA");quality.add_item("GRAFICA MEDIA");quality.add_item("GRAFICA ALTA");quality.selected=int(save.graphics_quality);root.add_child(quality)
	var value_label := Label.new(); value_label.position = Vector2(0,300); value_label.size = Vector2(1280,35); value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; root.add_child(value_label)
	var update := func(_value: float): value_label.text = "MUSICA %d%%     EFFETTI %d%%" % [int(slider.value*100),int(sfx_slider.value*100)]; save.music_volume=slider.value; save.sfx_volume=sfx_slider.value; save.mute=mute.button_pressed;save.graphics_quality=quality.selected; audio.set_levels(slider.value,sfx_slider.value,mute.button_pressed)
	slider.value_changed.connect(update); sfx_slider.value_changed.connect(update); mute.toggled.connect(func(_v:bool):update.call(0));quality.item_selected.connect(func(_i:int):update.call(0)); update.call(0)
	button(root,"SALVA E INDIETRO",510,func(): SaveManager.save_data(save); show_menu()).grab_focus()

func show_garage() -> void:
	clear_scene(); screen = Screen.GARAGE; _build_environment(true)
	ui = CanvasLayer.new(); add_child(ui)
	var panel := ColorRect.new(); panel.name="GarageInfoPanel"; panel.color = Color(0.02,0.03,0.05,.82); panel.position=Vector2(24,28); panel.size=Vector2(390,664); ui.add_child(panel)
	var preview_safe_area:=ColorRect.new();preview_safe_area.name="GaragePreviewSafeArea";preview_safe_area.mouse_filter=Control.MOUSE_FILTER_IGNORE;preview_safe_area.color=Color(0,0,0,0);preview_safe_area.position=Vector2(438,28);preview_safe_area.size=Vector2(818,664);ui.add_child(preview_safe_area)
	var name_label := Label.new(); name_label.name="GarageVehicleName"; name_label.position=Vector2(48,55); name_label.size=Vector2(342,92); name_label.add_theme_font_size_override("font_size",30); name_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; ui.add_child(name_label)
	var detail := Label.new(); detail.name="GarageVehicleDetails"; detail.position=Vector2(48,157); detail.size=Vector2(342,270 if run_mode=="STAGE" else 292); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; detail.add_theme_font_size_override("font_size",15 if run_mode=="STAGE" else 18); ui.add_child(detail)
	var refresh := func():
		if is_instance_valid(garage_car): garage_car.queue_free()
		var d := VehicleData.get_vehicle(int(save.vehicle)); name_label.text=str(d.name); detail.text="%s\n\nPotenza       %d / 10\nPeso          %d / 10\nGrip          %d / 10\nFrenata       %d / 10\nStabilità     %d / 10\nSovrasterzo   %d / 10\nDifficoltà    %d / 10" % [d.description,int(d.power_rating),int(d.weight_rating),clampi(int(d.road_grip),1,10),int(d.brake_rating),int(d.stability_rating),int(d.oversteer_rating),int(d.difficulty_rating)]
		garage_car=VehicleFactory.create_vehicle(int(save.vehicle)); garage_car.name="GarageVehiclePreview"; garage_car.position=Vector3(2.8,.15,0); garage_car.rotation.y=-0.35; world.add_child(garage_car)
	refresh.call()
	if run_mode=="STAGE":
		var difficulty_prev:=Button.new();difficulty_prev.name="DifficultyPrevious";difficulty_prev.text="◀";difficulty_prev.position=Vector2(48,488);difficulty_prev.size=Vector2(52,48);difficulty_prev.tooltip_text="Difficoltà precedente";ui.add_child(difficulty_prev)
		difficulty_value_label=Label.new();difficulty_value_label.name="DifficultyValue";difficulty_value_label.position=Vector2(104,488);difficulty_value_label.size=Vector2(230,48);difficulty_value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;difficulty_value_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;difficulty_value_label.add_theme_font_size_override("font_size",15);difficulty_value_label.add_theme_color_override("font_color",Color("f4b942"));ui.add_child(difficulty_value_label)
		var difficulty_next:=Button.new();difficulty_next.name="DifficultyNext";difficulty_next.text="▶";difficulty_next.position=Vector2(338,488);difficulty_next.size=Vector2(52,48);difficulty_next.tooltip_text="Difficoltà successiva";ui.add_child(difficulty_next)
		difficulty_prev.pressed.connect(func():_cycle_stage_difficulty(-1))
		difficulty_next.pressed.connect(func():_cycle_stage_difficulty(1))
		_refresh_difficulty_selector()
	var prev := Button.new(); prev.text="◀ PRECEDENTE"; prev.position=Vector2(48,438 if run_mode=="STAGE" else 486); prev.size=Vector2(164,44 if run_mode=="STAGE" else 52); ui.add_child(prev)
	var next := Button.new(); next.text="SUCCESSIVA ▶"; next.position=Vector2(222,438 if run_mode=="STAGE" else 486); next.size=Vector2(168,44 if run_mode=="STAGE" else 52); ui.add_child(next)
	prev.pressed.connect(func(): save.vehicle=(int(save.vehicle)+1)%2; refresh.call())
	next.pressed.connect(func(): save.vehicle=(int(save.vehicle)+1)%2; refresh.call())
	var play := Button.new(); play.text="CONFERMA E PARTI"; play.position=Vector2(48,552); play.size=Vector2(342,58); play.add_theme_font_size_override("font_size",20); ui.add_child(play); play.pressed.connect(start_game); play.grab_focus()
	var back := Button.new(); back.text="MENU"; back.position=Vector2(48,620); back.size=Vector2(342,42); ui.add_child(back); back.pressed.connect(show_menu)

func stage_difficulty_name()->String:
	return STAGE_DIFFICULTY_NAMES[clampi(stage_difficulty_index,0,STAGE_DIFFICULTY_NAMES.size()-1)]

func stage_initial_time()->float:
	return STAGE_DIFFICULTY_INITIAL_TIMES[clampi(stage_difficulty_index,0,STAGE_DIFFICULTY_INITIAL_TIMES.size()-1)]

func stage_checkpoint_bonus()->float:
	return STAGE_DIFFICULTY_CHECKPOINT_BONUSES[clampi(stage_difficulty_index,0,STAGE_DIFFICULTY_CHECKPOINT_BONUSES.size()-1)]

func _cycle_stage_difficulty(direction:int)->void:
	if run_mode!="STAGE":return
	stage_difficulty_index=posmod(stage_difficulty_index+direction,STAGE_DIFFICULTY_NAMES.size())
	_refresh_difficulty_selector()

func _refresh_difficulty_selector()->void:
	if is_instance_valid(difficulty_value_label):difficulty_value_label.text="DIFFICOLTÀ\n"+stage_difficulty_name()

func _build_environment(garage: bool = false) -> void:
	world = Node3D.new(); add_child(world)
	var env_node := WorldEnvironment.new();environment_resource=Environment.new();environment_resource.background_mode=Environment.BG_COLOR;environment_resource.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment_resource.fog_enabled=true;env_node.environment=environment_resource;world.add_child(env_node)
	sun_light=DirectionalLight3D.new();sun_light.shadow_enabled=true;world.add_child(sun_light);_apply_atmosphere()
	if garage:
		var platform := MeshInstance3D.new(); var cylinder:=CylinderMesh.new(); cylinder.top_radius=4.6; cylinder.bottom_radius=4.9; cylinder.height=.45; platform.mesh=cylinder; platform.material_override=VehicleFactory.material(Color("252932"),.65); platform.position=Vector3(2.8,-.2,0); world.add_child(platform)
		garage_camera=Camera3D.new(); garage_camera.name="GaragePreviewCamera"; garage_camera.position=Vector3(10.4,4.4,10.8); garage_camera.fov=43.0; garage_camera.h_offset=-2.50; world.add_child(garage_camera); garage_camera.look_at(Vector3(2.8,.9,0))

func _apply_atmosphere()->void:
	if environment_resource==null or sun_light==null:return
	var skies:Array[Color]=[ArtDirection.SKY_CLEAR,ArtDirection.SKY_SUNSET,Color("8d8175")];var fogs:Array[Color]=[Color("dca66e"),Color("c86f48"),Color("a98767")]
	environment_resource.background_color=skies[atmosphere_mode];environment_resource.ambient_light_color=Color("ffd19a") if atmosphere_mode<2 else Color("c6b29d");environment_resource.ambient_light_energy=.52 if atmosphere_mode!=1 else .42;environment_resource.fog_light_color=fogs[atmosphere_mode];environment_resource.fog_density=[.0025,.004,.008][atmosphere_mode]
	sun_light.light_color=[Color("ffe0ad"),Color("ff9a55"),Color("d8c0a1")][atmosphere_mode];sun_light.light_energy=[1.25,1.05,.72][atmosphere_mode];sun_light.rotation_degrees=Vector3(-55,-25,0) if atmosphere_mode==0 else Vector3(-18,-45,0)
	sun_light.shadow_enabled=int(save.get("graphics_quality",1))>0

func start_game() -> void:
	SaveManager.save_data(save); clear_scene(); screen=Screen.GAME;audio.configure_vehicle(int(save.vehicle));audio.start_game_audio(); _build_environment()
	player=VehicleController.new(); player.setup(int(save.vehicle)); player.position=Vector3(0,.05,8); world.add_child(player)
	player.set_effect_quality(int(save.graphics_quality))
	road=RoadManager.new();road.stage_mode=run_mode=="STAGE"
	# Il profilo normale è esplicito e non dipende dall'auto. I flag disattivati
	# restano un opt-in tecnico per i test dei fallback legacy.
	if road.stage_mode and RoadManager.use_environment_v2_playable_pilot and RoadManager.use_full_special_stage_visual_expansion:
		road.stage_visual_profile_path=RoadManager.FULL_SPECIAL_STAGE_VISUAL_PATH
	elif not road.stage_mode and RoadManager.use_environment_v2_playable_pilot and RoadManager.use_full_special_stage_visual_expansion:
		road.stage_visual_profile_path=RoadManager.ENDURANCE_G1F1_VISUAL_PATH
	world.add_child(road); road.setup(player)
	player.road_manager=road
	road.collectible_collected.connect(_collect)
	camera=CameraController.new(); camera.target=player; camera.road_manager=road; camera.position=Vector3(0,5,16); world.add_child(camera)
	hud=GameHUD.new(); add_child(hud); ui=hud
	player.crashed.connect(_on_crash); player.offroad_changed.connect(func(value: bool): hud.flash_message("FUORI STRADA — RIENTRA!" if value else "DI NUOVO SULL'ASFALTO"))
	player.repositioned.connect(_on_repositioned)
	score=0; score_fraction=0.0; distance=0; fuel=BalanceData.START_FUEL; health=BalanceData.START_HEALTH; multiplier=1; multiplier_time=0; offroad_time=0; collected=0; stage_time=0; stage_penalty=0; stage_checkpoint=0;stage_time_remaining=stage_initial_time();stage_bonus_feedback_time=0.0;stage_timeout_triggered=false
	countdown=4.0 if run_mode=="STAGE" else 0.0; player.controls_enabled=countdown<=0
	if run_mode=="STAGE":audio.play("start")

func _update_game(delta: float) -> void:
	if player == null: return
	if countdown>0:
		countdown=maxf(0,countdown-delta); player.controls_enabled=countdown<=0
		hud.message_label.text="VIA!" if countdown<=0 else str(ceili(countdown))
		if Input.is_action_pressed("accelerate"):stage_penalty+=delta*.5
		return
	audio.update_engine(player.speed,Input.get_axis("brake","accelerate"),player.offroad,player.slip_angle>.12,player.surface,player.simulated_rpm,player.simulated_gear,player.airborne,player.turbo_time>0.0,int(save.vehicle),delta)
	distance += maxf(player.speed,0.0)*delta; fuel=maxf(0.0,fuel-BalanceData.FUEL_DRAIN*delta*(0.3+absf(player.speed)/40.0))
	if run_mode=="STAGE":
		stage_time+=delta;stage_time_remaining=maxf(0.0,stage_time_remaining-delta);stage_bonus_feedback_time=maxf(0.0,stage_bonus_feedback_time-delta)
		# Checkpoint geometrici: il progresso dipende dai segmenti della route reale.
		var route_index:=road.route_index_near(player.global_position)
		if stage_checkpoint<stage_checkpoint_segments.size() and route_index>=stage_checkpoint_segments[stage_checkpoint] and road.is_point_near_active(player.global_position):
			stage_checkpoint+=1
			if stage_checkpoint<6:
				var checkpoint_bonus:=stage_checkpoint_bonus();stage_time_remaining+=checkpoint_bonus;stage_bonus_feedback_time=STAGE_BONUS_FEEDBACK_DURATION;hud.flash_message("CP %02d  +%ds"%[stage_checkpoint,int(checkpoint_bonus)])
			else:hud.flash_message("CHECKPOINT 6/6")
			audio.play("checkpoint")
		if player.offroad and player.offroad_duration>3:stage_penalty+=delta*.35
		if stage_checkpoint>=6 and route_index>=63:show_stage_results();return
		if stage_time_remaining<=0.0:show_stage_timeout();return
	_accrue_driving_score(player.speed,delta)
	if multiplier_time>0: multiplier_time-=delta
	else: multiplier=1
	if player.offroad:
		offroad_time+=delta
		if offroad_time>BalanceData.OFFROAD_DAMAGE_DELAY: health=maxf(0,health-BalanceData.OFFROAD_DAMAGE_RATE*delta)
	else: offroad_time=0
	hud.update_values(score,distance,player.speed_kmh(),fuel,health,multiplier,int(save.record),player.turbo_time)
	hud.update_offroad(player.offroad,player.soft_boundary,player.road_manager.direction_to_center(player.global_position),player)
	hud.update_rally(run_mode=="STAGE",stage_time_remaining,stage_penalty,stage_checkpoint,6,player,road.pacenote_near(player.global_position),int(stage_checkpoint_bonus()) if stage_bonus_feedback_time>0.0 else 0,run_mode,stage_difficulty_name() if run_mode=="STAGE" else "")
	if fuel<=0 or health<=0: show_game_over()

func _accrue_driving_score(speed_value:float,delta:float)->void:
	# Preserve the original theoretical rate while carrying sub-point fractions
	# across frames instead of discarding them at every update.
	score_fraction+=absf(speed_value)*maxf(delta,0.0)*float(multiplier)*0.8
	var whole_points:=int(floor(score_fraction))
	if whole_points<=0:return
	score+=whole_points
	score_fraction-=float(whole_points)

func _collect(kind: int, area: Area3D) -> void:
	if not is_instance_valid(area) or area.is_queued_for_deletion(): return
	var names:Array[String]=["+25 CARBURANTE","+500 PUNTI","+25 INTEGRITÀ","TURBO!","MOLTIPLICATORE x2"]
	match kind:
		0: fuel=minf(100,fuel+25)
		1: score+=500*multiplier
		2: health=minf(100,health+25)
		3: player.activate_turbo()
		4: multiplier=2; multiplier_time=10
	collected+=1; hud.flash_message(names[kind]); audio.play("turbo" if kind==3 else "collect"); area.queue_free()

func _on_crash(damage: float) -> void:
	health=maxf(0,health-damage); camera.bump(.45); hud.flash_message("IMPATTO  -%d INTEGRITÀ" % int(damage));hud.damage_flash();audio.play("collision");_spawn_sparks(); stage_penalty+=2.0 if run_mode=="STAGE" and damage>=14 else 0.0
	player.damage_level=1.0-health/100.0

func _on_repositioned(automatic: bool) -> void:
	health=maxf(1.0,health-BalanceData.RESET_HEALTH_PENALTY)
	score=maxi(0,score-BalanceData.RESET_SCORE_PENALTY)
	hud.flash_message("LIMITE DEL MONDO — VEICOLO RIPOSIZIONATO" if automatic else "VEICOLO RIPOSIZIONATO  -250 PUNTI")
	camera.bump(.22)
	if run_mode=="STAGE":stage_penalty+=5.0

func show_stage_results() -> void:
	player.controls_enabled=false;audio.play("finish"); var final_time:=stage_time+stage_penalty; clear_scene(); screen=Screen.GAME_OVER
	var root:=make_ui(); title(root,"PROVA COMPLETATA","TEMPO UFFICIALE  %02d:%05.2f"%[int(final_time)/60,fmod(final_time,60)])
	var result:=Label.new(); result.text="TEMPO GUIDATO  %02d:%05.2f\nPENALITÀ  +%.1fs\nCHECKPOINT  %d/6\nINTEGRITÀ  %d%%"%[int(stage_time)/60,fmod(stage_time,60),stage_penalty,stage_checkpoint,int(health)]; result.position=Vector2(0,245); result.size=Vector2(1280,170); result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; result.add_theme_font_size_override("font_size",25); root.add_child(result)
	button(root,"RIPROVA",460,func():run_mode="STAGE";start_game()).grab_focus();button(root,"MENU",535,show_menu)

func show_stage_timeout()->void:
	stage_timeout_triggered=true;player.controls_enabled=false;clear_scene();screen=Screen.GAME_OVER
	var root:=make_ui();title(root,"TEMPO SCADUTO","Raggiungi il prossimo checkpoint prima che il tempo arrivi a zero")
	var result:=Label.new();result.text="CHECKPOINT  %d/6\nTEMPO RESIDUO  00:00\nPENALITÀ  +%.1fs"%[stage_checkpoint,stage_penalty];result.position=Vector2(0,260);result.size=Vector2(1280,130);result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;result.add_theme_font_size_override("font_size",25);root.add_child(result)
	button(root,"RIPROVA",460,func():run_mode="STAGE";start_game()).grab_focus();button(root,"MENU",535,show_menu)

func _spawn_sparks()->void:
	if player==null:return
	var sparks:=CPUParticles3D.new();sparks.one_shot=true;sparks.amount=14;sparks.lifetime=.38;sparks.explosiveness=.95;sparks.direction=Vector3(0,1,0);sparks.spread=75;sparks.initial_velocity_min=3;sparks.initial_velocity_max=7;sparks.gravity=Vector3(0,-9,0);sparks.color=Color("ffb12b");sparks.position=player.position+Vector3.UP*.7;world.add_child(sparks);sparks.emitting=true
	var tween:=sparks.create_tween();tween.tween_interval(.6);tween.tween_callback(sparks.queue_free)

func set_pause(value: bool) -> void:
	paused=value; get_tree().paused=value
	audio.set_paused(value)
	if value:
		var overlay:=ColorRect.new(); overlay.name="PauseOverlay"; overlay.color=Color(0,0,0,.75); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); hud.add_child(overlay)
		var label:=Label.new(); label.text="PAUSA\n\nEsc — riprendi\nR — ricomincia\nM — menu"; label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.add_theme_font_size_override("font_size",28); overlay.add_child(label)
	else:
		var overlay:=hud.get_node_or_null("PauseOverlay")
		if overlay: overlay.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if screen==Screen.GAME and paused and event is InputEventKey and event.pressed:
		if event.physical_keycode==KEY_R: start_game()
		elif event.physical_keycode==KEY_M: show_menu()
	if screen==Screen.GARAGE and event is InputEventKey and event.pressed:
		if event.physical_keycode in [KEY_A,KEY_D]: save.vehicle=(int(save.vehicle)+1)%2; show_garage()
		elif run_mode=="STAGE" and event.physical_keycode==KEY_LEFT:_cycle_stage_difficulty(-1);get_viewport().set_input_as_handled()
		elif run_mode=="STAGE" and event.physical_keycode==KEY_RIGHT:_cycle_stage_difficulty(1);get_viewport().set_input_as_handled()

func show_game_over() -> void:
	audio.play("game_over")
	var new_record: bool=score>int(save.record)
	if new_record: save.record=score; SaveManager.save_data(save)
	clear_scene(); screen=Screen.GAME_OVER
	var root:=make_ui(); title(root,"FINE CORSA","NUOVO RECORD!" if new_record else "Il deserto ha vinto questa volta")
	var result:=Label.new(); result.text="PUNTEGGIO  %d\nDISTANZA  %dm\nOGGETTI RACCOLTI  %d\nRECORD  %d" % [score,int(distance),collected,int(save.record)]; result.position=Vector2(0,220); result.size=Vector2(1280,170); result.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; result.add_theme_font_size_override("font_size",25); root.add_child(result)
	button(root,"RIPROVA",425,start_game).grab_focus(); button(root,"GARAGE",497,show_garage); button(root,"MENU",569,show_menu)
