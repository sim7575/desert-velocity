class_name AudioManager
extends Node

var music_volume: float = 0.45
var sfx_volume: float = 0.75
var muted: bool = false
var engine_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var surface_player:AudioStreamPlayer
var short_event_counts:Dictionary={}
var short_event_total:=0
var max_short_streams_simultaneous:=0
var last_short_event:=""
var vehicle_profile:=0
var audio_rpm:=950.0
var last_gear:=1
var shift_dip_time:=0.0
var gear_shift_count:=0
var last_engine_pitch:=.72
var peak_engine_pitch:=.72
var minimum_engine_pitch:=10.0

func _ready() -> void:
	engine_player=_player("Engine"); music_player=_player("Music"); sfx_player=_player("SFX");surface_player=_player("SurfaceLoop")
	_apply_levels()

func start_game_audio()->void:
	if engine_player.stream==null:engine_player.stream=_engine_loop(vehicle_profile)
	if music_player.stream==null:music_player.stream=_tone(2.4,110.0,.16,true,1.5)
	if surface_player.stream==null:surface_player.stream=_tone(1.0,70.0,.10,true,1.5)
	engine_player.play();music_player.play();surface_player.play()

func configure_vehicle(index:int)->void:
	vehicle_profile=clampi(index,0,1);audio_rpm=900.0 if vehicle_profile==0 else 1050.0;last_gear=1;shift_dip_time=0.0;gear_shift_count=0
	if is_instance_valid(engine_player):
		engine_player.stop();engine_player.stream=_engine_loop(vehicle_profile)

func _engine_loop(profile:int)->AudioStreamWAV:
	var rate:=22050;var count:=rate;var bytes:=PackedByteArray();bytes.resize(count*2);var frequency:=64.0 if profile==0 else 76.0
	for i in count:
		var phase:=TAU*frequency*float(i)/rate;var modulation:=1.0+.045*sin(TAU*2.0*float(i)/rate)
		var sample:float
		if profile==0:sample=(sin(phase)*.50+sin(phase*.5)*.27+sin(phase*2.0)*.15+sin(phase*3.0)*.07)*modulation
		else:sample=(sin(phase)*.58+sin(phase*.5)*.16+sin(phase*2.0)*.18+sin(phase*3.0)*.05)*modulation
		bytes.encode_s16(i*2,int(clampf(sample*.50,-.92,.92)*32767.0))
	var wav:=AudioStreamWAV.new();wav.format=AudioStreamWAV.FORMAT_16_BITS;wav.mix_rate=rate;wav.stereo=false;wav.data=bytes;wav.loop_mode=AudioStreamWAV.LOOP_FORWARD;wav.loop_end=count;return wav

func stop_game_audio()->void:
	if is_instance_valid(engine_player):engine_player.stop();engine_player.stream=null
	if is_instance_valid(music_player):music_player.stop();music_player.stream=null
	if is_instance_valid(surface_player):surface_player.stop();surface_player.stream=null

func _player(label: String) -> AudioStreamPlayer:
	var player:=AudioStreamPlayer.new(); player.name=label; add_child(player); return player

func _tone(duration: float, frequency: float, amplitude: float, looped: bool=false, harmonic: float=0.0) -> AudioStreamWAV:
	var rate:=22050; var count:=int(duration*rate); var bytes:=PackedByteArray(); bytes.resize(count*2)
	for i in count:
		var phase:=TAU*frequency*float(i)/rate
		var sample:=sin(phase)+sin(phase*harmonic)*.28 if harmonic>0 else sin(phase)
		var envelope:=1.0 if looped else sin(PI*float(i)/count)
		bytes.encode_s16(i*2,int(clampf(sample*amplitude*envelope,-1.0,1.0)*32767.0))
	var wav:=AudioStreamWAV.new(); wav.format=AudioStreamWAV.FORMAT_16_BITS; wav.mix_rate=rate; wav.stereo=false; wav.data=bytes
	if looped: wav.loop_mode=AudioStreamWAV.LOOP_FORWARD; wav.loop_end=count
	return wav

func set_levels(music: float, sfx: float, mute: bool) -> void:
	music_volume=clampf(music,0,1); sfx_volume=clampf(sfx,0,1); muted=mute; _apply_levels()

func _apply_levels() -> void:
	if not is_instance_valid(music_player): return
	music_player.volume_db=linear_to_db(maxf(music_volume if not muted else .001,.001))
	engine_player.volume_db=linear_to_db(maxf(sfx_volume*.58 if not muted else .001,.001))
	sfx_player.volume_db=linear_to_db(maxf(sfx_volume if not muted else .001,.001))
	surface_player.volume_db=-80.0

func update_engine(speed: float, throttle: float, offroad: bool, drifting: bool, surface:String="ASPHALT", rpm:float=-1.0, gear:int=1, airborne:bool=false, boost:bool=false, vehicle_index:int=-1, delta:float=1.0/60.0) -> void:
	if not is_instance_valid(engine_player): return
	if vehicle_index>=0 and vehicle_index!=vehicle_profile:configure_vehicle(vehicle_index);engine_player.play()
	var target_rpm:=rpm if rpm>=0.0 else lerpf(950.0,6200.0,clampf(absf(speed)/44.0,0.0,1.0))
	var response:=2.15 if target_rpm>audio_rpm else 4.8
	audio_rpm=lerpf(audio_rpm,target_rpm,1.0-exp(-response*maxf(delta,.0001)))
	if gear!=last_gear:
		shift_dip_time=.19;gear_shift_count+=1;last_gear=gear
	shift_dip_time=maxf(0.0,shift_dip_time-delta)
	var normalized:=clampf((audio_rpm-900.0)/6500.0,0.0,1.0)
	var pitch_min:=.70 if vehicle_profile==0 else .76;var pitch_max:=1.42 if vehicle_profile==0 else 1.50
	var shift_dip:=sin((shift_dip_time/.19)*PI)*.15 if shift_dip_time>0.0 else 0.0
	var target_pitch:=lerpf(pitch_min,pitch_max,pow(normalized,.78))-shift_dip+(.035 if boost else 0.0)
	engine_player.pitch_scale=clampf(target_pitch,.62,1.54);last_engine_pitch=engine_player.pitch_scale;peak_engine_pitch=maxf(peak_engine_pitch,last_engine_pitch);minimum_engine_pitch=minf(minimum_engine_pitch,last_engine_pitch)
	var load:=clampf(maxf(throttle,0.0),0.0,1.0);var engine_level:=(.28+normalized*.21+load*.16+(.035 if boost else 0.0))*(.72 if airborne else 1.0)
	engine_player.volume_db=linear_to_db(maxf(engine_level*(sfx_volume if not muted else .001),.001))
	# Superficie continua su player dedicato: nessun tono breve viene riavviato
	# a ogni termine stream, causa del precedente tic periodico su ghiaia.
	var texture_level:=.0
	if offroad:texture_level=.11
	elif drifting:texture_level=.075
	elif surface=="GRAVEL":texture_level=.045
	surface_player.volume_db=linear_to_db(maxf(texture_level*(sfx_volume if not muted else .001),.001))
	surface_player.pitch_scale=.88+clampf(absf(speed)/80.0,0.0,.35)

func play(event_name: String) -> void:
	match event_name:
		"collision": _play_tone(48,.28,.58)
		"collect": _play_tone(660,.16,.32)
		"turbo": _play_tone(310,.42,.34)
		"game_over": _play_tone(82,.8,.32)
		"start": _play_tone(520,.22,.34)
		"checkpoint": _play_tone(780,.18,.30)
		"finish": _play_tone(940,.55,.34)
		"menu": _play_tone(440,.10,.20)
		_: _play_tone(220,.10,.18)

func _play_tone(frequency: float, duration: float, amplitude: float) -> void:
	if muted or not is_instance_valid(sfx_player): return
	short_event_total+=1;last_short_event="%.0fHz/%.2fs"%[frequency,duration];short_event_counts[last_short_event]=int(short_event_counts.get(last_short_event,0))+1
	sfx_player.stream=_tone(duration,frequency,amplitude,false,1.51); sfx_player.play()
	max_short_streams_simultaneous=maxi(max_short_streams_simultaneous,1)

func set_paused(value: bool) -> void:
	engine_player.stream_paused=value
	surface_player.stream_paused=value
	music_player.volume_db=linear_to_db(maxf(music_volume*(.35 if value else 1.0),.001))

func shutdown()->void:
	for player in [engine_player,music_player,sfx_player,surface_player]:
		if is_instance_valid(player):
			player.stop();player.stream=null
			if player.get_parent()==self:remove_child(player)
			player.free()
	engine_player=null;music_player=null;sfx_player=null;surface_player=null

func diagnostic_snapshot()->Dictionary:
	var active:=0
	for player in [engine_player,music_player,sfx_player,surface_player]:
		if is_instance_valid(player) and player.playing:active+=1
	return {"players":4,"active_players":active,"short_event_total":short_event_total,"short_event_counts":short_event_counts.duplicate(),"max_short_streams_simultaneous":max_short_streams_simultaneous,"last_short_event":last_short_event,"surface_loop":is_instance_valid(surface_player) and surface_player.playing,"surface_loop_mode":(surface_player.stream as AudioStreamWAV).loop_mode if is_instance_valid(surface_player) and surface_player.stream is AudioStreamWAV else -1,"vehicle_profile":"STALLION_ROUGH" if vehicle_profile==0 else "BAVARIAN_COMPACT","audio_rpm":audio_rpm,"engine_pitch":last_engine_pitch,"minimum_engine_pitch":minimum_engine_pitch,"peak_engine_pitch":peak_engine_pitch,"gear_shift_count":gear_shift_count,"shift_dip_time":shift_dip_time}

func _exit_tree()->void:
	shutdown()
