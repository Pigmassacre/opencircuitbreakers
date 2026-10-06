class_name Battle
extends Node

# Battle mode: FUN_00024bc4 sets it up, FUN_0006c6c8 runs two players and
# FUN_0006de3c three or four. Everyone shares one screen; once the field spreads
# past the threshold the last car is blown up. With two players the leader then
# takes the round and a point. With more, players go out one by one and score
# 0, 1, 2... in the order they went out, the round winner one more. Every round
# restarts side by side at the leader's node until someone reaches the target.
# Distances are original units.

const TICKS := Car.PHYSICS_TICKS_PER_GAME_FRAME
const TARGETS := [0, 0, 8, 12, 16]
const THRESHOLD := 0x150
const EXPERT_THRESHOLD := 0x100
const MIN_SPREAD := 0x3f
const FALL_DEPTH := 0x20 * Car.UNIT_METRES
const RANK_OUT := 0x7ffffff
const DOWN_FRAMES := 10
const WINNER_FRAME := 0x14
const FLY_FRAME := 0x30
const WAIT_FRAME := 0x31
const GRID_FRAME := 0x32
const RESUME_FRAME := 0x4a
const MATCH_CHEER_FRAME := 0x20
const MATCH_EXIT_FRAME := 0x40
const WIDE_GATE := 0x9000
const WIDE_SIDE := 0xc40
const MAX_ZOOM := 0x294
const DOWN_ZOOM := 0x100
# a6ef0 = zoom + 0xd6c, against 0xccc for the 1-player camera's PITCH_OFFSET.
const PITCH_OFFSET := 0xa0
const YAW_RATE := 0x10
const ZOOM_RATE := 0xc
const DISTANCE_RATE := 0x30
const DISTANCE_BASE := 0x200
const FIXED_ZOOM_DISTANCE := 0x40

enum { CAM_YAW, CAM_PITCH, CAM_DISTANCE }

static var players := 0
static var target := 8
static var pickups := 1
static var experts := PackedByteArray([0, 0, 0, 0])
static var wins := PackedInt32Array([0, 0, 0, 0])
static var models := PackedInt32Array([0, 1, 2, 5])
static var devices := PackedInt32Array([0, 1, 2, 3])

var track: Track
var race: Race
var cars: Array[Car] = []
var camera: BattleCamera
var points := PackedInt32Array()
var round_points := PackedInt32Array()
var score_from := PackedInt32Array()
var score_serial := 0
var out := PackedByteArray()
var order := PackedInt32Array()
var remaining := 0
var next_points := 0
var round_frame := 0
var round_winner := 0
var match_winner := -1
var match_frames := 0
var down_frames := 0
var grid_turn := 0
var spread := 0
var threshold := THRESHOLD
var fixed_zoom := false
var box := AABB()
var down := PackedByteArray()
var aiming := false
var lane_turn := 0
var expert_turn := 0
var forward := false


func start(race_track: Track, race_state: Race, racers: Array[Car], battle_camera: BattleCamera) -> void:
	track = race_track
	race = race_state
	cars = racers
	camera = battle_camera
	for i in cars.size():
		cars[i].battle = self
		points.append(0)
		round_points.append(0)
		out.append(0)
		order.append(i)
	remaining = cars.size()
	for i in cars.size():
		place(i, 0)
	round_frame = GRID_FRAME
	update_held()
	box = focus_box(cars, PackedByteArray([0, 0, 0, 0]))
	camera.cars = cars
	camera.ignored.resize(cars.size())
	camera.tracking = true
	var cam := camera_entry(0)
	camera.yaw_target = cam[CAM_YAW] << 7
	camera.zoom_target = pitch_tweak(0) + 0x80
	camera.distance_target = (cam[CAM_DISTANCE] << 4) + 0x380
	camera.focus_target = box.get_center()
	camera.node = 0
	camera.snap()


func _physics_process(_delta: float) -> void:
	if Net.puppet():
		return
	if Engine.get_physics_frames() % TICKS != 0:
		if aiming:
			aim()
		return
	aiming = false
	if down_frames > 0:
		down_frames -= 1
		if down_frames == 0:
			restart_active()
	down = PackedByteArray()
	down.resize(cars.size())
	if round_frame == 0:
		rank()
		for i in cars.size():
			if out[i] == 0 and cars[i].grounded and cars[i].wreck_frames == 0:
				var at := cars[i].global_position
				var node := race.nodes[i]
				var along := track.segment_progress(node, at)
				var edge_a := track.gate_a(node).lerp(track.gate_a(node + 1), along)
				var edge_b := track.gate_b(node).lerp(track.gate_b(node + 1), along)
				if track.outside_road(track.across_gate(edge_a, edge_b, Vector2(at.x, at.z))):
					cars[i].wreck()
		var wrecks := 0
		for i in cars.size():
			down[i] = 1 if fallen(i) or wrecked(i) else 0
			wrecks += 1 if wrecked(i) else 0
		if down.count(0) > 0:
			box = focus_box(cars, down)
		camera.ignored = down
		if wrecks == cars.size():
			if down_frames == 0:
				down_frames = DOWN_FRAMES
				for i in cars.size():
					if out[i] == 0:
						cars[i].wreck_frames = 0
						cars[i].wreck()
			update_held()
			return
	elif not sequence():
		update_held()
		return

	measure_spread()
	update_threshold()
	if round_frame == 0:
		if cars.size() == 2:
			duel()
		elif spread >= threshold:
			eliminate(order[remaining - 1])
	update_camera()
	update_held()
	aiming = round_frame == 0 or round_frame >= GRID_FRAME


# The cars move every tick, so the camera aims at them every tick too; the game
# logic above still only samples the spread once a game frame.
func aim() -> void:
	if down.count(0) > 0:
		box = focus_box(cars, down)
	measure_spread()
	update_camera()


func update_held() -> void:
	for i in cars.size():
		var car := cars[i]
		car.respawn_held = out[i] == 1 or round_frame != 0
		car.frozen = round_frame != 0
		car.visible = not (car.respawn_held and car.wreck_frames > 0)


# FUN_00060068: track position only, with no laps; cars just past the start
# line stay ahead of those still coming up to it.
func rank() -> void:
	var count := track.nodes.size()
	var early := 0
	var late := 0
	for i in cars.size():
		if out[i] == 0:
			if race.nodes[i] < count / 3:
				early += 1
			elif race.nodes[i] > count * 2 / 3:
				late += 1
	var wrapped := early > 0 and late > 0
	var keys := PackedInt64Array()
	for i in cars.size():
		if out[i] == 1:
			keys.append(RANK_OUT)
			continue
		var node := race.nodes[i]
		var behind := 1000 if wrapped and node > count / 2 else 0
		var past := 0
		if track.nodes[node].enabled:
			var cross := track.gate_cross(node, track.to_units(cars[i].global_position))
			past = 0xbfff - clampi(-cross / 4, -0x3fff, 0x3fff)
		keys.append((1000 - node + behind) * 0x10000 + race.node_frames[i] + past)
	var sorted: Array[int] = []
	for i in cars.size():
		sorted.append(i)
	sorted.sort_custom(func(a: int, b: int) -> bool: return keys[a] < keys[b] or (keys[a] == keys[b] and a < b))
	order = PackedInt32Array(sorted)


func fallen(i: int) -> bool:
	var car := cars[i]
	return not car.grounded and car.global_position.y < car.last_ground_height - FALL_DEPTH


func wrecked(i: int) -> bool:
	return cars[i].wreck_frames > 0


# FUN_0006f748 / FUN_0006f580: the box around every car still on the track.
static func focus_box(racers: Array[Car], skip: PackedByteArray) -> AABB:
	var result := AABB()
	var first := true
	for i in racers.size():
		if skip[i] == 0:
			if first:
				result = AABB(racers[i].global_position, Vector3.ZERO)
				first = false
			else:
				result = result.expand(racers[i].global_position)
	return result


func units_apart(a: Vector3, b: Vector3) -> int:
	var d := Vector2(b.x - a.x, b.z - a.z) / Car.UNIT_METRES
	return int(d.length()) / 3


func measure_spread() -> void:
	if cars.size() == 2:
		spread = units_apart(cars[0].global_position, cars[1].global_position)
	else:
		spread = maxi(units_apart(box.position, box.end), MIN_SPREAD)


# FUN_0006d418: all Experts play to a shorter spread with the camera pulled
# fully out; in a duel a Normal player leading an Expert does too.
func update_threshold() -> void:
	threshold = THRESHOLD
	fixed_zoom = false
	if experts.slice(0, cars.size()).count(0) == 0:
		threshold = EXPERT_THRESHOLD
		fixed_zoom = true
	elif cars.size() == 2 and experts[order[0]] == 0 and experts[order[1]] == 1:
		threshold = EXPERT_THRESHOLD


func duel() -> void:
	var leader := order[0]
	if spread >= threshold and down[leader] == 0:
		blow_up(order[1])
		round_points[leader] = 1
		end_round(leader)


# FUN_0006f910: the last car still in goes out with the next score up; with two
# left the leader takes the round, unless it is down itself.
func eliminate(last: int) -> void:
	if remaining == 2:
		if down[order[0]] == 1:
			return
		round_points[last] = next_points
		round_points[order[0]] = next_points + 1
		next_points = 0
		end_round(order[0])
	else:
		round_points[last] = next_points
		next_points += 1
	out[last] = 1
	blow_up(last)
	remaining -= 1


func blow_up(i: int) -> void:
	cars[i].wreck()


# FUN_0006d808. The winner leaves through the respawn grid, not the wreck burst.
func vanish(i: int) -> void:
	var car := cars[i]
	if car.wreck_frames != 0:
		return
	car.wreck_frames = 1
	car.vel = Vector3.ZERO
	Sound.stop_engine(car)
	Fx.appear(car)


func end_round(winner: int) -> void:
	score_from = points.duplicate()
	score_serial += 1
	camera.tracking = false
	round_frame = 1
	round_winner = winner


func score() -> void:
	for i in cars.size():
		points[i] += round_points[i]
		if points[i] >= target and i != round_winner:
			points[i] = target - 1
	for i in cars.size():
		if points[i] >= target:
			points[i] = target
			match_winner = i


# The round-end counter: the winner shows, vanishes at 0x14, the camera flies to
# the restart node and everyone restarts there at 0x32, held until 0x4a. A won
# match holds on the winner instead and then returns to the menu. Returns
# whether the frame carries on with the spread and camera updates.
func sequence() -> bool:
	round_frame += 1
	if round_frame == 2:
		score()
	if round_frame < WINNER_FRAME:
		# Every fourth frame until the vanish, and not once the match is won.
		if match_winner < 0 and (round_frame & 3) == 0:
			Fx.winner_swirls(round_winner)
		return false
	if round_frame == WINNER_FRAME:
		if match_winner >= 0:
			match_frames += 1
			if match_frames == MATCH_CHEER_FRAME:
				vanish(match_winner)
			if match_frames == MATCH_EXIT_FRAME:
				finish_match(true)
				return false
			round_frame = WINNER_FRAME - 1
			return false
		vanish(round_winner)
	if round_frame < FLY_FRAME:
		return false
	if round_frame == FLY_FRAME:
		forward = past_jump(race.nodes[order[0]])
		camera.focus_target = track.node_transform(clear_jumps(grid_node()), 0.5).origin
		forward = false
		return false
	if round_frame == WAIT_FRAME:
		if not camera.arrived():
			round_frame = FLY_FRAME
		return false
	if round_frame == GRID_FRAME:
		restart_all()
	box = focus_box(cars, PackedByteArray([0, 0, 0, 0]))
	camera.ignored.fill(0)
	camera.tracking = true
	camera.focus_target = box.get_center()
	camera.focus = camera.focus_target
	if round_frame == RESUME_FRAME:
		round_frame = 0
	return true


func finish_match(completed := false) -> void:
	var winner := match_winner
	if winner < 0:
		var best := 0
		for i in cars.size():
			if points[i] > best:
				best = points[i]
				winner = i
	if winner >= 0:
		wins[winner] += 1
	if completed:
		if Net.in_match:
			Net.prompt_rematch.rpc(wins)
		else:
			(get_parent() as Session).show_rematch()
		return
	if Net.in_match:
		Net.end_match.rpc(wins)
		return
	Session.time_trial = false
	if Session.editor_return != "":
		Wipe.to(Session.editor_return)
		return
	MainMenu.start_page = MainMenu.PAGE_MULTIPLAYER
	Wipe.to(MainMenu.SCENE)


# FUN_0006d9a0 / FUN_0006d8b4.
func restart_all() -> void:
	remaining = cars.size()
	out.fill(0)
	round_points.fill(0)
	next_points = 0
	grid_turn = (grid_turn + 1) % cars.size()
	forward = past_jump(race.nodes[order[0]])
	var node := grid_node()
	for i in cars.size():
		order[i] = i
		place(i, node)
	forward = false


# Everyone still in was wrecked at once: they restart together at the leader.
func restart_active() -> void:
	grid_turn = (grid_turn + 1) % cars.size()
	var node := grid_node()
	for i in cars.size():
		if out[i] == 0:
			place(i, node)


# FUN_0006dae4: three cars need a node wide enough to fit side by side.
func grid_node() -> int:
	var node := track.nearest_node(cars[order[0]].last_ground_position)
	if remaining == 3 or (remaining == 1 and cars.size() == 3):
		while not wide(node):
			node = wrapi(node + 1, 0, track.nodes.size())
	return node


func wide(node: int) -> bool:
	var u: Array = track.nodes[node].units
	var across := Vector2(u[3] - u[5], u[4] - u[6]).length_squared()
	var left := Vector2(u[7] - u[3], u[8] - u[4]).length_squared()
	var right := Vector2(u[5] - u[9], u[6] - u[10]).length_squared()
	return across > WIDE_GATE and left > WIDE_SIDE and right > WIDE_SIDE


func place(i: int, node: int) -> void:
	var at := grid_slot(i, node)
	cars[i].teleport(at[1], at[0])
	race.nodes[i] = at[0]
	cars[i].begin_appear()


func respawn(car: Car) -> void:
	var i := cars.find(car)
	var at := grid_slot(i, track.nearest_node(car.last_ground_position))
	race.nodes[i] = at[0]
	car.teleport(at[1], at[0])


# FUN_0007080c: a leader stopped past the middle of a jump restarts after it.
func past_jump(node: int) -> bool:
	for range_pair: Array in track.respawn_ranges:
		var start: int = range_pair[0]
		var end: int = range_pair[1]
		if start < node and node <= end:
			return node > (start + end) >> 1
	return false


# A node inside a jump, or just past one, moves to the jump's start, or two past
# its end when restarting forward.
func clear_jumps(node: int) -> int:
	var count := track.nodes.size()
	var moved := true
	while moved:
		moved = false
		var back := wrapi(node - 2, 0, count)
		for range_pair: Array in track.respawn_ranges:
			var start: int = range_pair[0]
			var end: int = range_pair[1]
			if (start < node and node <= end) or (start < back and back < end):
				node = wrapi(end + 2, 0, count) if forward else start
				moved = true
				break
	return node


# FUN_000388c4 with the battle layout (DAT_000a7244 = 1). With everyone still in,
# slots go by player and the round's grid turn: two cars a quarter in from each
# side, three across the whole node, four in two rows. With all four in but
# Experts and Normals mixed, each group alternates its own lanes. Once someone
# is out, respawns cycle through the lanes of the cars still in. Experts go two
# nodes back (FUN_000398c4) unless everyone still in is an Expert.
func grid_slot(i: int, node: int) -> Array:
	var n := cars.size()
	var scattered := remaining != n
	var group := n
	if scattered:
		group = maxi(remaining, 1)
		lane_turn += 1
		while lane_turn > group:
			lane_turn -= group
	if group == 4:
		group = 0
		for j in n:
			if experts[j] == experts[i]:
				group += 1
	node = clear_jumps(node)
	var lane := 0.0
	if group == 4:
		var slot := (i + grid_turn) % 4
		lane = 0.25 + 0.5 * slot
		if slot > 1:
			node -= 1
			lane = slot - 2
	elif group == 3:
		var turn := i
		if scattered:
			turn = lane_turn
		elif n != 3:
			lane_turn += 1
			while lane_turn > 2:
				lane_turn -= 3
			turn = lane_turn
		lane = 0.5 * ((turn + grid_turn) % 3)
		node = set_back(i, node)
	else:
		var turn := i
		if scattered:
			turn = lane_turn
		elif n != 2 and group != 1:
			if experts[i] == 0:
				lane_turn += 1
				while lane_turn > 1:
					lane_turn -= 2
				turn = lane_turn
			else:
				expert_turn += 1
				while expert_turn > 1:
					expert_turn -= 2
				turn = expert_turn
		lane = 0.25 + 0.5 * ((turn + grid_turn) % 2)
		node = set_back(i, node)
	node = wrapi(node, 0, track.nodes.size())
	return [node, track.node_transform(node, lane)]


func set_back(i: int, node: int) -> int:
	return node - 2 if experts[i] == 1 and not experts_only() else node


func experts_only() -> bool:
	for i in cars.size():
		if out[i] == 0 and experts[i] == 0:
			return false
	return true


func camera_entry(node: int) -> Array:
	return track.node_data(node).battle_camera


func pitch_tweak(node: int) -> int:
	var tweak: int = camera_entry(node)[CAM_PITCH]
	return tweak << 3 if tweak < 0x80 else 0


# The ends of both battle functions: yaw follows the node halfway between the
# leader and the last car, pitch and distance open up with the spread.
func update_camera() -> void:
	var count := track.nodes.size()
	var leader := order[0]
	var last := order[remaining - 1] if cars.size() > 2 else order[1]
	var a := race.nodes[leader] + 4
	var b := race.nodes[last] + 4
	var sum := a + b
	if absi(a - b) >= count >> 1:
		sum += count
	var node := wrapi(sum >> 1, 0, count)
	for i in cars.size():
		if cars[i].held:
			node = race.nodes[i]
	camera.node = node
	camera.yaw_target = camera_entry(node)[CAM_YAW] << 7

	var base := spread
	var zoom := spread + pitch_tweak(race.nodes[last])
	if cars.size() == 2:
		zoom = spread + pitch_tweak(race.nodes[leader])
		if down.count(1) > 0:
			base = maxi(spread, DOWN_ZOOM)
			zoom = base
	zoom = mini(zoom, MAX_ZOOM)
	if fixed_zoom:
		zoom = MAX_ZOOM
	camera.zoom_target = zoom

	var distance := base * 3 + DISTANCE_BASE if cars.size() == 2 else base * 5 / 2 + DISTANCE_BASE
	distance = maxi(distance, camera_entry(node)[CAM_DISTANCE] << 4)
	if fixed_zoom:
		distance += FIXED_ZOOM_DISTANCE
	camera.distance_target = distance
