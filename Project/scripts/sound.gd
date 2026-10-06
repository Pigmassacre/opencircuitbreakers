extends Node

# Samples from the original SOUND/GAME1 VAB. A tone is
# [vag, volume, bend down, bend up, center, shift]. Vag numbers are 1-based.
# One-shots are keyed at note 64. FUN_0008525c pitches that against center and
# shift, and FUN_000858f4 folds the request and the tone volume into the SPU level.
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
const ENGINE_LOOP := [24, 25, 33]
const ONESHOTS := 16
const ENGINES := 8
const MUSIC_TRACKS := 8
const MUSIC_FRAME := 1.0 / 30.0
const MUSIC_CEILING := 100

var streams: Array[AudioStreamWAV] = []
var engine_loops: Array[AudioStreamWAV] = []
var oneshots: Array[AudioStreamPlayer] = []
var oneshot_cursor := 0
var engines: Array[AudioStreamPlayer] = []
var sprays: Array[AudioStreamPlayer] = []
var voice_car: Array = []
var voice_tone: Array[int] = []
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
	if not Data.present():
		set_process(false)
		return
	boot()


func boot() -> void:
	if not streams.is_empty():
		return
	set_process(true)
	engine_loops.resize(37)
	for i in 36:
		streams.append(load_wav(Data.path("res://audio/sfx/vag_%02d.wav" % [i + 1])))
	for vag in ENGINE_LOOP:
		var looped := streams[vag - 1].duplicate() as AudioStreamWAV
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 28
		looped.loop_end = looped.data.size() >> 1
		engine_loops[vag] = looped
	for i in ONESHOTS:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		oneshots.append(player)
	for i in ENGINES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(player)
		engines.append(player)
		var spray := AudioStreamPlayer.new()
		spray.bus = "SFX"
		spray.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(spray)
		sprays.append(spray)
		voice_car.append(null)
		voice_tone.append(-1)
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


func _process(delta: float) -> void:
	for i in ENGINES:
		# A freed car can sit in this untyped slot after the race scene is dropped.
		# Reading it into a Car variable is the error, so validity comes first.
		if is_instance_valid(voice_car[i]):
			var car: Car = voice_car[i]
			if car.is_inside_tree() and not car.frozen and car.wreck_frames == 0:
				continue
		elif voice_tone[i] == -1:
			continue
		engines[i].stop()
		voice_car[i] = null
		voice_tone[i] = -1
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
	for player in oneshots:
		player.stop()
	for i in engines.size():
		engines[i].stop()
		sprays[i].stop()
		voice_car[i] = null
		voice_tone[i] = -1


func effect(program: int, tone: int, volume := -1) -> void:
	if not race_audio:
		return
	if not play_effect(program, tone, volume):
		return
	if Net.in_match and multiplayer.is_server():
		Net.share_effect.rpc(program, tone, volume)


func play_effect(program: int, tone: int, volume := -1) -> bool:
	if streams.is_empty():
		return false
	var info: Array = PROGRAMS[program][tone]
	var tone_vol: int = info[1]
	var requested := tone_vol if volume < 0 else volume
	if requested <= 0 or tone_vol <= 0:
		return false
	var player := oneshots[oneshot_cursor]
	oneshot_cursor = (oneshot_cursor + 1) % ONESHOTS
	player.stream = streams[int(info[0]) - 1]
	player.pitch_scale = note_pitch(int(info[4]), int(info[5]))
	player.volume_db = linear_to_db(spu_amplitude(requested, tone_vol))
	player.play()
	return true


# FUN_00072e58: the tone's volume times the car's distance scale.
func scaled(program: int, tone: int, car: Car, volume_tone := tone) -> void:
	effect(program, tone, maxi(int(PROGRAMS[program][volume_tone][1]) * car.volume_scale() / 100, 0))


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
	if Net.in_match and multiplayer.is_server():
		Net.share_effect.rpc(2, 1, volume)


func ui() -> void:
	if not play_effect(0, 11):
		return
	if Net.in_match and multiplayer.is_server():
		Net.share_effect.rpc(0, 11, -1)


func car_frame(car: Car) -> void:
	if not race_audio:
		return
	if car.wreck_frames > 0:
		stop_engine(car)
		return
	# FUN_00074028. Battle is program 0 tone 0. A submarine race is program 2
	# tone 2. Boats share the car race engine, program 0 tone 2.
	var program := 0 if car.battle else 2
	var tone := 0 if car.battle else 2
	var bend_shift := 5
	if not car.battle and car.vehicle_kind == Car.VEHICLE_BOAT:
		program = 0
		tone = 2
		bend_shift = 6
	var info: Array = PROGRAMS[program][tone]
	var slot := slot_for(car)
	var player := engines[slot]
	var key := program * 16 + tone
	if voice_tone[slot] != key:
		voice_tone[slot] = key
		player.stream = engine_loops[int(info[0])]
		player.play()
	# FUN_00074d00 then scales the level by the car's engine distance scale.
	var vol: int = int(info[1])
	if car.battle:
		vol += 10
	elif car.vehicle_kind != Car.VEHICLE_BOAT:
		vol -= 15
	vol = vol * car.engine_scale() / 100
	player.volume_db = linear_to_db(clampf(vol / 127.0, 0.0, 1.0))
	var spd := int(car.vel.length() / 64.0)
	player.pitch_scale = bend_scale((spd >> 8) + (spd >> 7) + (spd >> bend_shift), int(info[2]), int(info[3])) * note_pitch(int(info[4]), int(info[5]))


func stop_engine(car: Car) -> void:
	for i in ENGINES:
		if voice_car[i] == car:
			engines[i].stop()
			voice_car[i] = null
			voice_tone[i] = -1


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


func slot_for(car: Car) -> int:
	var free := -1
	for i in ENGINES:
		if voice_car[i] == car:
			return i
		if free < 0 and voice_car[i] == null:
			free = i
	voice_car[free] = car
	voice_tone[free] = -1
	return free


# FUN_0008525c. Note 64 against the tone's center, plus shift in sixteenths of a semitone.
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
