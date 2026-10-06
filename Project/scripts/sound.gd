extends Node

# Samples from the original SOUND/GAME1 VAB. A tone is
# [vag, volume, bend down, bend up, center, shift]. Vag numbers are 1-based.
# FUN_00070ddc keys a tone at its center when it has an upward bend range and at
# note 64 otherwise. FUN_0008525c pitches that against center and shift, and
# FUN_000858f4 folds the request and the tone volume into the SPU level. Voice
# levels set after the key (FUN_00084834) are raw, out of 127.
# Music is the eight CD tracks. FUN_00071d10 picks one at random on boot. A track
# end, or the fade-out when leaving for a race, advances the index by one plus
# the display-buffer parity and wraps back to the first track.

const PROGRAMS := [
	[
		[25, 10, 8, 2, 84, 0],
		[26, 45, 2, 1, 50, 70],
		[24, 50, 16, 16, 77, 70],
		[25, 50, 16, 16, 77, 70],
		[34, 127, 16, 16, 77, 70],
		[5, 80, 0, 0, 77, 70],
		[6, 90, 0, 0, 77, 70],
		[7, 90, 0, 0, 77, 70],
		[8, 60, 0, 0, 77, 70],
		[9, 90, 0, 0, 77, 70],
		[10, 100, 0, 0, 84, 0],
		[11, 90, 0, 0, 74, 0],
		[12, 100, 0, 0, 77, 70],
		[13, 90, 0, 0, 60, 70],
		[14, 110, 0, 0, 77, 70],
		[29, 30, 0, 0, 77, 70],
	],
	[
		[1, 75, 0, 0, 77, 70],
		[2, 85, 0, 0, 77, 70],
		[3, 80, 0, 0, 77, 70],
		[4, 90, 0, 0, 80, 70],
		[15, 100, 0, 0, 77, 70],
		[16, 110, 0, 0, 77, 70],
		[17, 127, 0, 0, 77, 70],
		[28, 8, 0, 0, 77, 70],
		[18, 105, 0, 0, 84, 0],
		[19, 110, 0, 0, 84, 0],
		[20, 110, 0, 0, 84, 0],
		[21, 50, 0, 0, 77, 70],
		[22, 65, 0, 0, 84, 0],
		[23, 90, 0, 0, 84, 0],
		[27, 75, 0, 0, 77, 70],
		[30, 100, 0, 0, 77, 0],
	],
	[
		[31, 95, 0, 0, 84, 0],
		[32, 127, 0, 0, 84, 0],
		[33, 100, 16, 4, 88, 0],
		[35, 127, 0, 0, 84, 0],
		[36, 127, 0, 0, 84, 0],
	],
]
# GAME1.VB flags these vags to loop from their second ADPCM block.
const LOOPED := [13, 18, 19, 21, 22, 23, 25, 26, 28, 29, 33]
const LOOP_BEGIN := 28
const ONESHOTS := 16
const ENGINES := 8
const DRONES := 4
# FUN_00071cc0: node flag (node byte 0x1b) and program 1 tone of each node loop.
const NODE_LOOPS := [[1, 7], [0x40, 0xc], [2, 0xb], [0x80, 0xd], [4, 8]]
# DAT_000a6470 at the default SFX level: (100 - 25) * 127 / 100, capped at 95.
const ENGINE_CLAMP := 95
const REVERB_DEPTH := 0x40
const REVERB_STEP := 8
const MUSIC_TRACKS := 8
const MUSIC_FRAME := 1.0 / 30.0
const MUSIC_CEILING := 100

var streams: Array[AudioStreamWAV] = []
var loops: Array[AudioStreamWAV] = []
var oneshots: Array[AudioStreamPlayer] = []
var oneshot_cursor := 0
var sprays: Array[AudioStreamPlayer] = []
# Voices 1..8 carry each car's engine, voices 9..12 the race drones.
var engines: Array[AudioStreamPlayer] = []
var engine_notes := PackedInt32Array()
var drones: Array[AudioStreamPlayer] = []
var whines: Array[AudioStreamPlayer] = []
var node_loops: Array = []
var puffs: Array = []
var rain: AudioStreamPlayer
var reverb: AudioEffectReverb
var audio_race: Race
var frame_race: Race
# DAT_000a6e90: a one-shot was keyed this frame.
var keyed := false
var robin := 0
var appeared := -1
var puffed := -1
var picked := false
var beeps := 0
var reverb_depth := 0
# DAT_000a79b4, DAT_000a79d4, DAT_000a79f4, car+0x1f7710, DAT_0008dcdc, DAT_0008dcec, DAT_0008dd3c.
var engine_state := PackedInt32Array()
var engine_keyed := PackedInt32Array()
var engine_volume := PackedInt32Array()
var engine_bend := PackedInt32Array()
var drone_volume := PackedInt32Array()
var drone_rev := PackedInt32Array()
var sub_keyed := PackedByteArray()
var whine_volume := PackedInt32Array()
var loop_volume := PackedInt32Array()
var loop_fresh := PackedByteArray()
var line_armed := PackedByteArray()
var music: AudioStreamPlayer
var music_streams: Array[AudioStream] = []
var music_index := 0
var music_level := MUSIC_CEILING
var music_pick := true
var music_started := false
var music_fading := false
var music_ended := false
var music_parity := 0
var music_clock := 0.0
var race_audio := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 100
	if not Data.present():
		set_process(false)
		set_physics_process(false)
		return
	boot()


func boot() -> void:
	if not streams.is_empty():
		return
	set_process(true)
	set_physics_process(true)
	loops.resize(37)
	for i in 36:
		streams.append(load_wav(Data.path("res://audio/sfx/vag_%02d.wav" % [i + 1])))
	for vag in LOOPED:
		var looped := streams[vag - 1].duplicate() as AudioStreamWAV
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = LOOP_BEGIN
		looped.loop_end = looped.data.size() >> 1
		loops[vag] = looped
	for i in ONESHOTS:
		oneshots.append(add_voice())
	for i in ENGINES:
		engines.append(add_voice())
		sprays.append(add_voice())
		whines.append(add_voice())
		puffs.append(null)
	for i in DRONES:
		drones.append(add_voice())
	for k in NODE_LOOPS.size():
		var row: Array[AudioStreamPlayer] = []
		for i in ENGINES:
			row.append(add_voice())
		node_loops.append(row)
	loop_volume.resize(NODE_LOOPS.size() * ENGINES)
	rain = add_voice()
	engine_notes.resize(ENGINES)
	engine_state.resize(ENGINES)
	engine_keyed.resize(ENGINES)
	engine_volume.resize(ENGINES)
	engine_bend.resize(ENGINES)
	drone_volume.resize(ENGINES)
	drone_rev.resize(ENGINES)
	sub_keyed.resize(ENGINES)
	whine_volume.resize(ENGINES)
	loop_fresh.resize(ENGINES)
	line_armed.resize(ENGINES)
	# FUN_00070940: SsUtSetReverbType(4), Studio C, at depth 0. Every GAME1 tone
	# has the reverb bit, so the whole SFX bus takes it.
	reverb = AudioEffectReverb.new()
	reverb.room_size = 0.7
	reverb.damping = 0.5
	reverb.predelay_msec = 40.0
	reverb.dry = 1.0
	reverb.wet = 0.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), reverb)
	for track in MUSIC_TRACKS:
		music_streams.append(load_music(track))
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	music.finished.connect(note_music_ended)
	add_child(music)


func load_music(track: int) -> AudioStream:
	var ogg := "res://audio/music/track_%d.ogg" % [track + 2]
	if Data.exists(ogg):
		return AudioStreamOggVorbis.load_from_buffer(Data.bytes(ogg))
	var wav := "res://audio/music/track_%d.wav" % [track + 2]
	return AudioStreamWAV.load_from_buffer(Data.bytes(wav))


func add_voice() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "SFX"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	return player


func _process(delta: float) -> void:
	music_clock += delta
	var steps := 0
	while music_clock >= MUSIC_FRAME and steps < 4:
		music_clock -= MUSIC_FRAME
		music_frame()
		steps += 1
	if music_clock > MUSIC_FRAME:
		music_clock = 0.0


func silence_race() -> void:
	race_audio = false
	if streams.is_empty():
		return
	for player in oneshots:
		player.stop()
	for i in ENGINES:
		sprays[i].stop()
	stop_race_voices()
	audio_race = null
	reverb_depth = 0
	reverb.wet = 0.0


func stop_race_voices() -> void:
	for i in ENGINES:
		silence_car(i)
	for player in drones:
		player.stop()
	rain.stop()


func silence_car(c: int) -> void:
	engines[c].stop()
	whines[c].stop()
	for row: Array[AudioStreamPlayer] in node_loops:
		row[c].stop()
	engine_state[c] = 0
	engine_keyed[c] = 0
	sub_keyed[c] = 0
	whine_volume[c] = 0
	for k in NODE_LOOPS.size():
		loop_volume[k * ENGINES + c] = 0
	loop_fresh[c] = 0


# FUN_00070940 at the start of a race. The four drones are keyed silent at
# their center note by FUN_00071b1c and only ever change level and bend.
func begin_race(race: Race) -> void:
	stop_race_voices()
	audio_race = race
	robin = 0
	beeps = 0
	appeared = -1
	puffed = -1
	picked = false
	for c in ENGINES:
		engine_bend[c] = 0 if c < DRONES else 0x4d
		drone_volume[c] = 0
		drone_rev[c] = 0
		line_armed[c] = 0
		puffs[c] = null
	var info: Array = PROGRAMS[0][3]
	for player in drones:
		player.stream = loops[int(info[0])]
		player.volume_db = linear_to_db(0.0)
		player.pitch_scale = note_pitch(int(info[4]), int(info[5]), tone_note(info))
		player.play()


func effect(program: int, tone: int, volume := -1, note := 0) -> AudioStreamPlayer:
	if not race_audio:
		return null
	var player := play_effect(program, tone, volume, note)
	if player and Net.in_match and multiplayer.is_server():
		Net.share_effect.rpc(program, tone, volume, note)
	return player


# FUN_00070bcc and FUN_00070cb8 key at FUN_00070ddc's note plus an offset.
func play_effect(program: int, tone: int, volume := -1, note := 0) -> AudioStreamPlayer:
	if streams.is_empty():
		return null
	var info: Array = PROGRAMS[program][tone]
	var tone_vol: int = info[1]
	var requested := tone_vol if volume < 0 else volume
	if requested <= 0 or tone_vol <= 0:
		return null
	var player := oneshots[oneshot_cursor]
	oneshot_cursor = (oneshot_cursor + 1) % ONESHOTS
	player.stream = streams[int(info[0]) - 1]
	player.pitch_scale = note_pitch(int(info[4]), int(info[5]), tone_note(info) + note)
	player.volume_db = linear_to_db(spu_amplitude(requested, tone_vol))
	player.play()
	keyed = true
	return player


# FUN_00072e58: the tone's volume times the car's distance scale.
func scaled(program: int, tone: int, car: Car, volume_tone := tone, note := 0) -> void:
	effect(program, tone, maxi(int(PROGRAMS[program][volume_tone][1]) * car.volume_scale() / 100, 0), note)


# FUN_0007202c plays program 2 tone 1 on a car's first frame on surface 4,
# unless its last spray is still sounding.
func spray(car: Car) -> void:
	if not race_audio or car.spray_frames != 1:
		return
	var player := sprays[car.items.race.cars.find(car)]
	if player.playing:
		return
	var info: Array = PROGRAMS[2][1]
	var volume := maxi(int(info[1]) * car.volume_scale() / 100, 0)
	if volume == 0:
		return
	player.stream = streams[int(info[0]) - 1]
	player.pitch_scale = note_pitch(int(info[4]), int(info[5]))
	player.volume_db = linear_to_db(spu_amplitude(volume, int(info[1])))
	player.play()
	keyed = true
	if Net.in_match and multiplayer.is_server():
		Net.share_effect.rpc(2, 1, volume, 0)


func ui() -> void:
	if not play_effect(0, 11):
		return
	if Net.in_match and multiplayer.is_server():
		Net.share_effect.rpc(0, 11, -1, 0)


# DAT_000a7418: the audio frame runs the engines and the round robin over all
# eight cars with one human, otherwise over the humans only.
func sound_cars(race: Race) -> int:
	var humans := Car.humans_in(race.cars)
	return mini(ENGINES if humans == 1 else humans, race.cars.size())


func car_speed(car: Car) -> int:
	return int(car.vel.length() / 64.0)


func tone_note(info: Array) -> int:
	return int(info[4]) if int(info[3]) != 0 else 64


func set_level(player: AudioStreamPlayer, volume: int) -> void:
	player.volume_db = linear_to_db(clampf(volume / 127.0, 0.0, 1.0))


# FUN_00073d58 then FUN_00074028. The submarine world keeps one looping voice
# (FUN_00074d00). Cars and boats key the one-shot gear sweep, program 0 tone 2,
# up to three times a note lower each, while the tone 3 drone carries the
# revs. Single-player AI cars only sweep, above speed 0x259.
func car_frame(car: Car) -> void:
	if not race_audio:
		return
	var race := car.items.race
	if race != audio_race:
		begin_race(race)
	frame_race = race
	var c := race.cars.find(car)
	if c >= sound_cars(race):
		return
	var humans := Car.humans_in(race.cars)
	engine_level(car, c, humans)
	if car.vehicle_kind == Car.VEHICLE_SUB:
		sub_engine(car, c)
		return
	if humans == 1 and c > 0:
		if car_speed(car) < 0x259:
			engine_idle(c)
			engine_keyed[c] = 0
		else:
			engine_gear(c)
			engine_keyed[c] = 1
	elif car.thrust_ramp == 0:
		if engine_idle(c) != 0:
			drone_frame(car, c, -2)
		engine_keyed[c] = 0
	else:
		if engine_state[c] == 0:
			if drone_rev[c] > 0x59:
				engine_gear(c)
				engine_keyed[c] = 1
		elif car.thrust_ramp > 0xf:
			engine_gear(c)
			engine_keyed[c] = 1
		drone_frame(car, c, c + 2)
	if engine_state[c] != 0:
		engine_pitch(car, c)


# FUN_00073d58: the gear voice level is program 0 tone 1's volume at the
# engine scale, less DAT_000a6470 * 24 / 127, or halved for an AI car.
func engine_level(car: Car, c: int, humans: int) -> void:
	var vol: int = int(PROGRAMS[0][1][1]) * car.engine_scale() / 100
	if humans == 1 and c > 0:
		vol >>= 1
	else:
		vol -= ENGINE_CLAMP * 0x18 / 0x7f
	if vol < 6:
		vol = 0
	if car.wreck_count() > 10:
		vol = 0
		engine_bend[c] = 0
	engine_volume[c] = vol
	set_level(engines[c], vol)


func sub_engine(car: Car, c: int) -> void:
	var info: Array = PROGRAMS[2][2]
	var spd := car_speed(car)
	engine_bend[c] = (spd >> 8) + (spd >> 7) + (spd >> 5)
	var player := engines[c]
	if sub_keyed[c] == 0:
		player.stream = loops[int(info[0])]
		player.play()
		sub_keyed[c] = 1
	player.pitch_scale = bend_scale(engine_bend[c], int(info[2]), int(info[3])) * note_pitch(int(info[4]), int(info[5]), tone_note(info))
	set_level(player, (int(info[1]) - 15) * car.engine_scale() / 100)


# FUN_0007441c: off the throttle the sweep is cut, and once it is silent the
# gear count starts over.
func engine_idle(c: int) -> int:
	if engine_keyed[c] == 1:
		engines[c].stop()
	if engines[c].playing:
		return 0
	if engine_state[c] < 4:
		engine_state[c] = 0
		return 1
	return 0


# FUN_00074310
func engine_gear(c: int) -> void:
	var state := engine_state[c]
	if engines[c].playing or state >= 3:
		return
	var info: Array = PROGRAMS[0][2]
	engine_notes[c] = tone_note(info) + 3 - state
	engines[c].stream = streams[int(info[0]) - 1]
	set_level(engines[c], engine_volume[c])
	engines[c].play()
	engine_state[c] = state + 1


# FUN_000744e0. The drone fades out under the first two sweeps and back in
# on alternate frames after the third, never above the gear voice level.
func drone_frame(car: Car, c: int, delta: int) -> void:
	var wrecked := car.wreck_count() != 0
	var spd := car_speed(car)
	var revs := (spd >> 8) + (spd >> 7) + (spd >> 6)
	if engine_state[c] == 3:
		drone_rev[c] = 0 if wrecked else revs
		bend_drone(c)
	else:
		if wrecked:
			drone_rev[c] = 0
		bend_drone(c)
		drone_rev[c] += delta
	var state := engine_state[c]
	if state == 1 or state == 2:
		drone_volume[c] = maxi(drone_volume[c] - 1, 0)
		set_level(drones[c], drone_volume[c])
		if state == 1:
			set_level(engines[c], engine_volume[c] - (drone_volume[c] >> 1))
		drone_rev[c] = 0 if wrecked else revs
	elif state == 0 or state == 3:
		set_level(drones[c], engine_volume[c] if state == 0 else drone_volume[c])
		if music_parity != 0:
			drone_volume[c] += 1
		drone_volume[c] = mini(drone_volume[c], engine_volume[c])
	drone_rev[c] = clampi(drone_rev[c], 0, 0x5a)


func bend_drone(c: int) -> void:
	var info: Array = PROGRAMS[0][3]
	drones[c].pitch_scale = bend_scale(drone_rev[c], int(info[2]), int(info[3])) * note_pitch(int(info[4]), int(info[5]), tone_note(info))


# FUN_00074864: the sweep bends up 5 a frame in the air and down 5 on the
# ground, between 0x4d and 0x5a. Topping out in the air rearms the second gear.
func engine_pitch(car: Car, c: int) -> void:
	engine_bend[c] += -5 if car.grounded else 5
	if engine_bend[c] > 0x5a and engine_state[c] != 4:
		engine_bend[c] = 0x5a
		engine_state[c] = 1
	engine_bend[c] = maxi(engine_bend[c], 0x4d)
	var info: Array = PROGRAMS[0][2]
	engines[c].pitch_scale = bend_scale(engine_bend[c], int(info[2]), int(info[3])) * note_pitch(int(info[4]), int(info[5]), engine_notes[c])
	if car_speed(car) < 300:
		engine_state[c] = 0
	if drone_rev[c] < 0x19 and engine_state[c] == 4:
		engine_state[c] = 0


func stop_engine(car: Car) -> void:
	if car.items.race != audio_race:
		return
	var c := car.items.race.cars.find(car)
	silence_car(c)
	if c < DRONES:
		set_level(drones[c], 0)


func appear(car: Car) -> void:
	var c := car.items.race.cars.find(car)
	if c < sound_cars(car.items.race):
		appeared = c


func puff(car: Car) -> void:
	puffed = car.items.race.cars.find(car)


func pickup() -> void:
	picked = true


# FUN_000717f4 after every car has run its frame. One-shots keyed earlier in
# the frame hold back the round robin, the rain and the item tones.
func _physics_process(_delta: float) -> void:
	if frame_race == null:
		return
	var race := frame_race
	frame_race = null
	var count := sound_cars(race)
	robin += 1
	if robin > count - 1:
		robin = 0
	step_reverb(race)
	if not Net.puppet():
		appear_tone(race)
		puff_tone(race)
		countdown_beep(race)
	if not keyed:
		if robin < count:
			car_loops(race, robin)
		rain_loop(race)
		if not Net.puppet():
			item_tones(race)
	for c in count:
		if race.cars[c].frozen:
			stop_engine(race.cars[c])
	keyed = false
	appeared = -1
	puffed = -1


# FUN_00071104 / FUN_00071168: reverb depth climbs by 8 to 0x40 while car 0's
# node has flag 0x20 or in the submarine world, and falls by 8 otherwise.
func step_reverb(race: Race) -> void:
	var flags: int = race.track.nodes[race.nodes[0]].flags
	if (flags & 0x20) != 0 or race.cars[0].vehicle_kind == Car.VEHICLE_SUB:
		reverb_depth = mini(reverb_depth + REVERB_STEP, REVERB_DEPTH)
	else:
		reverb_depth = maxi(reverb_depth - REVERB_STEP, 0)
	reverb.wet = reverb_depth / 127.0


# FUN_00072160: FUN_0002ad40 left DAT_000a6b10 at the car's index plus one.
func appear_tone(race: Race) -> void:
	if appeared >= 0:
		scaled(0, 6, race.cars[appeared])


# FUN_00072394: the car-world drift puff (DAT_000a6e38) over a node with flag 8
# or 0x10, once the last one has finished, loud enough after losing 0x19.
func puff_tone(race: Race) -> void:
	if puffed < 0:
		return
	var last: AudioStreamPlayer = puffs[puffed]
	if last and last.playing:
		return
	var vol := int(PROGRAMS[0][9][1]) * race.cars[puffed].volume_scale() / 100 - 0x19
	if vol <= 0x1d:
		return
	var flags: int = race.track.nodes[race.nodes[puffed]].flags
	if (flags & 8) != 0:
		puffs[puffed] = effect(0, 9, vol)
	if (flags & 0x10) != 0:
		puffs[puffed] = effect(0, 8, vol)


# FUN_00075118: a beep as each countdown digit slides in, the last a third higher.
func countdown_beep(race: Race) -> void:
	if race.countdown > 1:
		beeps = 0
	if race.count_beep:
		beeps += 1
		if beeps < 4:
			effect(0, 0xb, 100)
		else:
			effect(0, 0xb, 100, 4)
			beeps = 0
	race.count_beep = false


# FUN_00071cc0 for one car a frame.
func car_loops(race: Race, c: int) -> void:
	var car := race.cars[c]
	if car.frozen:
		return
	var flags: int = race.track.nodes[race.nodes[c]].flags
	var spd := car_speed(car)
	for k in NODE_LOOPS.size():
		node_loop(car, c, k, flags, spd)
	if car.vehicle_kind == Car.VEHICLE_BOAT:
		whine(car, c, spd)


# FUN_000731c4, FUN_0007335c, FUN_000735bc, FUN_00073748, FUN_000738c8. Each
# loop starts at its tone volume on a flagged node; the first two need speed
# above 500, the second also needs the car on screen outside the boat world
# and adds program 1 tone 0xe on the next pass. FUN_00073b08 then rises 5
# toward the tone volume while on, falls 10 when not, 10 more off the ground
# or wrecked, and keeps the distance-scaled level.
func node_loop(car: Car, c: int, k: int, flags: int, spd: int) -> void:
	if keyed:
		return
	var flag: int = NODE_LOOPS[k][0]
	var info: Array = PROGRAMS[1][NODE_LOOPS[k][1]]
	var top: int = info[1]
	var player: AudioStreamPlayer = node_loops[k][c]
	var i := k * ENGINES + c
	var fast := k < 2
	if k == 1:
		if car.vehicle_kind == Car.VEHICLE_BOAT or not car.on_screen:
			return
		if loop_fresh[c] == 1 and loop_volume[i] > 5:
			scaled(1, 0xe, car)
			loop_fresh[c] = 0
	if k == 2 and c > 1:
		return
	var here := (flags & flag) != 0
	if here and not player.playing and (not fast or spd > 500):
		loop_volume[i] = top
		player.stream = loops[int(info[0])]
		player.pitch_scale = note_pitch(int(info[4]), int(info[5]), tone_note(info))
		player.play()
		keyed = true
		if k == 1:
			loop_fresh[c] = 1
	if not player.playing:
		return
	var vol := loop_volume[i]
	if here and (not fast or spd >= 0x1f5):
		vol = mini(vol + 5, top)
	else:
		vol -= 10
	if not car.grounded or car.wreck_count() != 0:
		vol -= 10
	vol = vol * car.volume_scale() / 100
	if vol <= 0:
		loop_volume[i] = 0
		player.stop()
		return
	loop_volume[i] = vol
	set_level(player, vol)


# FUN_000749bc: program 0 tone 0xf over 2000, fading 10 a pass toward the tone
# volume while grounded and fast, at the engine scale.
func whine(car: Car, c: int, spd: int) -> void:
	if keyed:
		return
	var info: Array = PROGRAMS[0][0xf]
	var top: int = info[1]
	var scale := car.engine_scale()
	var player := whines[c]
	if spd > 2000 and not player.playing and scale != 0:
		whine_volume[c] = top - 5
		player.stream = loops[int(info[0])]
		player.pitch_scale = note_pitch(int(info[4]), int(info[5]), tone_note(info))
		player.play()
		keyed = true
	if not car.grounded or car.wreck_count() != 0 or spd < 2000:
		whine_volume[c] = maxi(whine_volume[c] - 10, 0)
	else:
		whine_volume[c] = mini(whine_volume[c] + 10, top)
	whine_volume[c] = whine_volume[c] * scale / 100
	if whine_volume[c] < 1:
		whine_volume[c] = 0
		player.stop()
		return
	set_level(player, whine_volume[c])


# FUN_00073c60: rain (weather 2) keeps program 1 tone 9 at its volume plus 0x11.
func rain_loop(race: Race) -> void:
	if race.track.weather != 2:
		return
	var info: Array = PROGRAMS[1][9]
	if not rain.playing:
		rain.stream = loops[int(info[0])]
		rain.pitch_scale = note_pitch(int(info[4]), int(info[5]), tone_note(info))
		rain.play()
		keyed = true
	set_level(rain, int(info[1]) + 0x11)


# FUN_00072864 past the item timers: a pickup (DAT_000a6e84) at car 0's scale,
# the slowdown at 1 and 0x5a, the start boost at 0x32 and 0x19, and the line
# tone when a car reaches node 0 or 1 (DAT_000a6de8) after a respawn node past 0.
func item_tones(race: Race) -> void:
	if picked:
		picked = false
		scaled(1, 10, race.cars[0])
	for c in race.cars.size():
		var car := race.cars[c]
		car.items.item_sounds(car)
		if car.slow_frames == 1 or car.slow_frames == 0x5a:
			scaled(1, 5, car)
		if car.boost_pressed and (car.boost_frames == 0x19 or car.boost_frames == 0x32):
			scaled(1, 2, car)
		if race.respawn_nodes[c] > 0:
			line_armed[c] = 1
			race.line_crossed[c] = 0
		if race.line_crossed[c] == 1 and line_armed[c] == 1:
			scaled(1, 10, car, 10, 5)
			race.line_crossed[c] = 0
			line_armed[c] = 0


# FUN_00071d10. The race loop is the only place the original updates this, and
# the front end runs inside that loop, so the menu and the race share it.
func music_frame() -> void:
	music_parity = 1 - music_parity
	if get_tree().paused and not music_fading:
		return
	if music_pick:
		music_pick = false
		music_index = randi() & 7
		if music_index >= MUSIC_TRACKS:
			music_index = 0
	if music_fading:
		fade_music()
		return
	if music_ended:
		music_ended = false
		music_started = false
		step_track()
	if not music_started:
		begin_music()
	if music_level < MUSIC_CEILING:
		music_level = mini(music_level + 5, MUSIC_CEILING)
	apply_music_volume()


func depart(then: Callable) -> void:
	if music_fading:
		return
	music_fading = true
	if then.is_valid():
		then.call()


func note_music_ended() -> void:
	if not music_started:
		return
	music_ended = true


func begin_music() -> void:
	apply_music_volume()
	music.stream = music_streams[music_index]
	music.play()
	music_started = true


func step_track() -> void:
	music_index += 1 + music_parity
	if music_index >= MUSIC_TRACKS:
		music_index = 0


# FUN_000712b8. Volume steps down by 5 until it drops under 20, then the playlist advances.
func fade_music() -> void:
	if music_level < 0x14:
		if music_level != 0:
			music_level = 0
			apply_music_volume()
			music_started = false
			music.stop()
			music_ended = false
			step_track()
		music_fading = false
		return
	music_level -= 5
	apply_music_volume()


func apply_music_volume() -> void:
	var mixed := int((music_level - 0x19) * 0x7f / 100.0)
	if mixed < 0:
		mixed = 0
	music.volume_db = linear_to_db(mixed / 127.0)


# FUN_0008525c. The note against the tone's center, plus shift in sixteenths of a semitone.
func note_pitch(center: int, shift: int, note := 64) -> float:
	var fine := shift >> 3
	var carry := 0
	if fine > 15:
		fine -= 16
		carry = 1
	return pow(2.0, (float(note - center + carry) + float(fine) / 16.0) / 12.0)


# FUN_000858f4. Both masters are 127, so the level is the request times the tone volume, squared.
func spu_amplitude(requested: int, tone_vol: int) -> float:
	var lin := int(float(requested * 127 * 0x3fff) / float(0x3f01))
	lin = int(float(lin * 127 * tone_vol) / float(0x3f01))
	return float(int(float(lin * lin) / float(0x3fff))) / float(0x3fff)


func bend_scale(bend: int, down: int, up: int) -> float:
	var delta := bend - 64
	var semis := float(delta) * (up if delta >= 0 else down) / 63.0
	return pow(2.0, semis / 12.0)


func load_wav(path: String) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 44100
	stream.stereo = false
	stream.data = bytes.slice(44)
	return stream
