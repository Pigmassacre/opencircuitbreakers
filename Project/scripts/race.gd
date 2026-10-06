class_name Race
extends Node

# Lap logic of FUN_00037d64 and positions of FUN_00060684. Nodes are grouped into
# checkpoint blocks of 16; a block only counts once the previous one has, and a
# lap is done when the car reaches node 0 or 1 with every block visited.

const LAPS := 3
const BLOCK_SHIFT := 4
const BLOCKS := 32
# FUN_00028fbc stores one input sample per frame and gives up at this count.
const TAPE_LIMIT := 0x1d4c

var track: Track
var cars: Array[Car] = []
var player := 0
var nodes := PackedInt32Array()
# FUN_00037d64 writes this only when the live node changes while the car is
# grounded and not wrecked. Respawn uses it, so a nearby segment cannot steal it.
var respawn_nodes := PackedInt32Array()
var node_frames := PackedInt32Array()
var laterals := PackedInt32Array()
var edges := PackedInt32Array()
var node_changed := PackedByteArray()
var laps := LAPS
var laps_left := PackedInt32Array()
var visited: Array[PackedByteArray] = []
var places := PackedInt32Array()
var lap_started := PackedFloat64Array()
var finish_time := PackedFloat64Array()
var new_best := false
var new_place := false
var lap_times: Array[PackedFloat64Array] = []
var time := 0.0
var frame := 0
# Driving frames since the flag, for the time-trial ghost tape.
var time_trial := false
var trial_frame := -1
var ghost_tape := PackedByteArray()
var trial_tapes: Array[PackedByteArray] = []
var trial_capped := PackedByteArray()
var trial_saved := PackedByteArray()
# FUN_00026628 / FUN_000370d8: the AI's start phase counter, which stops at the
# track's start length, and its hold-off after it.
var ai_frame := 0
var ai_hold := 0x4b
var endless := false
# FUN_00035554 / FUN_0003a330. countdown counts down from 0x14, then each of
# '3','2','1',GO holds while count_tick climbs from 0x18 to 0x88. Cars stay
# staged until their release frame, and everyone goes once countdown hits 0.
var countdown := 0
var count_tick := 0x18
var count_char := 0x33
var count_slide := 0
# DAT_000a71b4, the digit's slide-in x. FUN_00035554 raises DAT_000a74a0 for
# the countdown beep when it reads 0x120.
var count_x := 0x280
var count_beep := false
var start_frame := 0
# DAT_000a6de8: FUN_00037d64 found the car on node 0 or 1.
var line_crossed := PackedByteArray()
# DAT_000a7200: everyone drives model 8 with no items, and bumps kick twice as hard.
var bumper := false
var bumper_held := false


func start(race_track: Track, racers: Array[Car], player_index: int) -> void:
	track = race_track
	cars = racers
	player = player_index
	for car in cars:
		var node := track.nearest_node(car.global_position)
		nodes.append(node)
		respawn_nodes.append(node)
		node_frames.append(0)
		laterals.append(0x800)
		edges.append(0x800)
		node_changed.append(1)
		line_crossed.append(0)
		laps_left.append(LAPS)
		var blocks := PackedByteArray()
		blocks.resize(BLOCKS)
		visited.append(blocks)
		places.append(0)
		lap_started.append(0.0)
		finish_time.append(-1.0)
		lap_times.append(PackedFloat64Array())
	update_places()


func arm_start() -> void:
	countdown = 0x14
	count_tick = 0x18
	count_char = 0x33
	count_slide = 0
	count_x = 0x280
	start_frame = 0
	refresh_staged()


# Car 0 calls this on the game frame, before any car integrates, matching the
# original order: the countdown steps, cars read it, then the frame counter moves.
func begin_game_frame() -> void:
	if countdown == 0:
		if time_trial:
			trial_frame += 1
	if countdown == 0 and count_slide == 0:
		return
	if countdown == 1:
		toggle_bumper()
	var counting := countdown != 0
	step_countdown()
	refresh_staged()
	if counting:
		start_frame += 1
	if time_trial and counting and countdown == 0:
		trial_frame = 0


func step_countdown() -> void:
	if count_x == 0x120:
		count_beep = true
	if count_slide != 0:
		if count_slide + 1 != 12:
			count_slide += 1
		else:
			count_slide = 0
		return
	if countdown > 1:
		countdown -= 1
		return
	count_tick += 6
	count_x = maxi(count_x - 0x20, 0x100)
	if count_tick < 0x88:
		return
	count_char -= 1
	if count_char == 0x2f:
		countdown = 0
		count_slide = 1
		return
	count_tick = 0x18
	count_x = 0x280


# FUN_0003574c, while the countdown digits show: car 0's pad going to exactly
# Left and Circle flips bumper cars, with more than one human, outside a
# submarine world and a time trial.
func toggle_bumper() -> void:
	if Car.humans_in(cars) < 2 or time_trial or cars[0].vehicle_kind == Car.VEHICLE_SUB:
		return
	var held := cars[0].bumper_pressed()
	if held and not bumper_held:
		bumper = not bumper
	bumper_held = held


# FUN_0003a330 holds every car for the whole countdown with more than one human
# or in a time trial; otherwise the cars leave one by one.
func refresh_staged() -> void:
	var together := time_trial or Car.humans_in(cars) > 1
	for i in cars.size():
		if together:
			cars[i].staged = countdown != 0
		else:
			cars[i].staged = countdown != 0 and start_gap(i) < 0x60 - start_frame


# Car 7 leaves first and car 0 last. The table is the placement order with those
# two slots swapped, so the gap is measured in that order.
func start_gap(i: int) -> int:
	var u := i
	if i == 7:
		u = 0
	elif i == 0:
		u = 7
	return (7 - u) * 8


func _physics_process(delta: float) -> void:
	if Net.puppet():
		return
	if countdown == 0:
		time += delta
	if Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME == 0:
		frame += 1
		if countdown == 0 and track.ai_race and ai_frame < track.ai_start[1]:
			ai_frame += 1
		for i in cars.size():
			update_node(i)
		if finish_time[player] < 0.0:
			update_places()


func update_node(i: int) -> void:
	node_changed[i] = 0
	var node := track.lookup_node(cars[i].global_position, nodes[i])
	if node == -1:
		return
	var block := node >> BLOCK_SHIFT
	if block == 0 or visited[i][block - 1] == 1:
		visited[i][block] = 1
		if node < 2:
			line_crossed[i] = 1
		if node < 2 and all_visited(i, (track.nodes.size() - 1) >> BLOCK_SHIFT):
			visited[i].fill(0)
			complete_lap(i)
	if node != nodes[i]:
		nodes[i] = node
		node_frames[i] = frame & 0xff
		laterals[i] = track.gate_fraction
		edges[i] = track.edge_fraction
		node_changed[i] = 1
		if cars[i].grounded and cars[i].wreck_frames == 0:
			respawn_nodes[i] = node


func all_visited(i: int, blocks: int) -> bool:
	for b in blocks:
		if visited[i][b] != 1:
			return false
	return true


func complete_lap(i: int) -> void:
	if endless or laps_left[i] == 0:
		return
	laps_left[i] -= 1
	lap_times[i].append(time - lap_started[i])
	lap_started[i] = time
	if laps_left[i] == 0:
		finish_time[i] = time


# Distance still to go, in nodes scaled by 0x10000, then the frame the car reached
# its node and how far it is past that node's gate. Lower is further ahead.
func rank_key(i: int) -> int:
	if finish_time[i] >= 0.0:
		return int(finish_time[i] * 1000.0) - 0x7fffffff
	var count := track.nodes.size()
	var node := nodes[i]
	var laps := laps_left[i]
	if not all_visited(i, (node + 8) >> BLOCK_SHIFT):
		laps += 1
	var past := 0
	if track.nodes[node].enabled:
		var cross := track.gate_cross(node, track.to_units(cars[i].global_position))
		past = 0xbfff - clampi(-cross / 4, -0x3fff, 0x3fff)
	return (count - node + laps * count) * 0x10000 + node_frames[i] + past


func update_places() -> void:
	var keys := PackedInt64Array()
	for i in cars.size():
		keys.append(rank_key(i))
	for i in cars.size():
		var ahead := 0
		for j in cars.size():
			if keys[j] < keys[i] or (keys[j] == keys[i] and j < i):
				ahead += 1
		places[i] = ahead + 1


func ghost_sample(frame: int) -> Vector3i:
	var at := frame * 2
	if frame < 0 or at + 1 >= ghost_tape.size():
		return Vector3i.ZERO
	return Vector3i(ghost_tape[at] & 7, (ghost_tape[at] >> 4) & 7, int(ghost_tape[at + 1]) - 7)


func prepare_trial(humans: int) -> void:
	time_trial = true
	# FUN_00025c54 sets laps left (0x1f76f0) to 1. FUN_000595c8 draws that as 1/1.
	laps = 1
	for i in laps_left.size():
		laps_left[i] = laps
	trial_tapes.clear()
	trial_capped.resize(humans)
	trial_saved.resize(humans)
	trial_capped.fill(0)
	trial_saved.fill(0)
	for _i in humans:
		trial_tapes.append(PackedByteArray())


func note_trial(index: int, accel: int, brake: int, steer: int) -> void:
	if index < 0 or index >= trial_tapes.size() or trial_capped[index] == 1:
		return
	if trial_frame < 0 or finish_time[index] >= 0.0:
		return
	if trial_frame >= TAPE_LIMIT:
		trial_capped[index] = 1
		return
	var tape := trial_tapes[index]
	var at := trial_frame * 2
	if tape.size() < at + 2:
		tape.resize(at + 2)
	tape[at] = (accel & 7) | ((brake & 7) << 4)
	tape[at + 1] = clampi(steer, -7, 7) + 7


func lap(i: int) -> int:
	return mini(laps - laps_left[i] + 1, laps)


func lap_time(i: int) -> float:
	return (finish_time[i] if finish_time[i] >= 0.0 else time) - lap_started[i]


func race_time(i: int) -> float:
	return finish_time[i] if finish_time[i] >= 0.0 else time


func place(i: int) -> int:
	return places[i]
