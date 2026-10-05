class_name TrackCamera
extends Camera3D

# The original's 1-player race camera (FUN_00035c5c): it orbits a point above
# the car, with yaw, pitch and distance eased towards values stored per track
# node. Angles are kept in the original's convention, where a yaw of
# 0xc00 + heading looks along that heading.

const TICKS := Car.PHYSICS_TICKS_PER_GAME_FRAME
const YAW_RATE := 0x20 / float(TICKS)
const PITCH_RATE := 0x18 / float(TICKS)
const DISTANCE_RATE := 0x10 / float(TICKS)
const SIDE_RATE := 0x10 / float(TICKS)
const FOCUS_RATE := 0x60 * Car.UNIT_METRES / TICKS
const FOCUS_HEIGHT := 0x20 * Car.UNIT_METRES
const FLIP_TICKS := 0x23 * TICKS
const FALL_DEPTH := 0x60 * Car.UNIT_METRES
const DISTANCE_OFFSET := 0x1e
const PITCH_OFFSET := 0xcc
const START_DISTANCE := 0x480
const MIN_DISTANCE := 0x280
const FALL_PITCH := 0x334
const FALL_DISTANCE := 0x400
const EDGE_SWING := 0x180
const TIGHT_SWING := 0xc0
const OFF_TRACK_SWING := 0x400
const TYPE_TIGHT := 0xfd
const TYPE_EDGE := 0xfe
const SLOW_SPEED := 0x80
# The PS1 projects with H = 240 onto a 240-line screen.
const PSX_FOV := 53.13

enum { CAM_TYPE, CAM_YAW, CAM_PITCH, CAM_DISTANCE, CAM_EDGE }

var target: Car
var track: Track
var race: Race
var node := 0
var progress := 0.0
var yaw := 0.0
var pitch := 0.0
var distance := 0.0
var side := 0.0
var focus := Vector3.ZERO
var backwards := false
var flip_ticks := 0
var out_of_bounds := false
var enforce_bounds := true


func snap_to_target() -> void:
	fov = PSX_FOV
	update_node()
	var cam := camera_entry(node)
	yaw = cam[CAM_YAW] << 7
	pitch = cam[CAM_PITCH] << 3 if cam[CAM_PITCH] < 0x80 else 0
	distance = maxi(cam[CAM_DISTANCE] << 4, START_DISTANCE)
	side = 0.0
	backwards = false
	flip_ticks = 0
	out_of_bounds = false
	focus = target.global_position
	apply_transform()
	reset_physics_interpolation()


func _physics_process(_delta: float) -> void:
	if target.wreck_frames == 0:
		out_of_bounds = false
	elif not out_of_bounds:
		backwards = false
		flip_ticks = 0
		apply_transform()
		return

	update_node()
	var cam := camera_entry(node)
	var cam_next := camera_entry(node + 1)

	var facing_back := absi(wrapi(travel_heading() - int(track.node_data(node).heading), -2048, 2048)) > 0x400
	if facing_back == backwards:
		flip_ticks = 0
	else:
		flip_ticks += 1
		if flip_ticks > FLIP_TICKS:
			flip_ticks = 0
			backwards = facing_back
	var ahead := node - 4 if backwards else node + 3

	if not out_of_bounds and not target.grounded and target.global_position.y < target.last_ground_height - FALL_DEPTH:
		var fall_yaw := wrapi(0x400 + travel_heading(), 0, 4096)
		yaw = ease_angle(yaw, fall_yaw, YAW_RATE)
		pitch = move_toward(pitch, FALL_PITCH, PITCH_RATE)
		distance = move_toward(distance, FALL_DISTANCE, DISTANCE_RATE)
		follow(Vector3(target.global_position.x, focus.y, target.global_position.z))
		apply_transform()
		return

	var pos := Vector2(target.global_position.x, target.global_position.z)
	var a := track.gate_a(node).lerp(track.gate_a(node + 1), progress)
	var b := track.gate_b(node).lerp(track.gate_b(node + 1), progress)
	var across := b - a
	var lateral := 0.0
	if absf(across.x) < absf(across.y):
		lateral = (pos.y - a.y) / across.y * 0x1000
	else:
		lateral = (pos.x - a.x) / across.x * 0x1000
	var half_width := across.length() / Car.UNIT_METRES / 2.0

	var type: int = cam[CAM_TYPE]
	var margin := type << 7
	if type == TYPE_EDGE:
		margin = 0x380
	elif type == TYPE_TIGHT:
		margin = 0
	var road := track.across_gate(a, b, pos)
	if enforce_bounds and not target.puppet and not out_of_bounds and target.grounded and track.outside_road(road):
		target.wreck()
		out_of_bounds = true
	var swinging := true
	var swing := 0.0
	var outside := lateral < margin or lateral > 0x1000 - margin
	if out_of_bounds or lateral < -0x40 or lateral >= 0x1040:
		swing = OFF_TRACK_SWING
	elif outside and type == TYPE_EDGE and cam[CAM_EDGE] != 0:
		swing = minf(half_width, EDGE_SWING)
	elif outside and type == TYPE_TIGHT:
		swing = minf(half_width, TIGHT_SWING)
	else:
		swinging = false

	if not swinging:
		side = move_toward(side, 0.0, SIDE_RATE)
	elif lateral > margin:
		side = maxf(side - SIDE_RATE, -swing)
	else:
		side = minf(side + SIDE_RATE, swing)

	var from := node
	if type == TYPE_TIGHT or (type != TYPE_EDGE and not swinging):
		from = ahead
	var yaw_from: float = (camera_entry(from)[CAM_YAW] << 7) + side
	var yaw_to: float = (camera_entry(from + 1)[CAM_YAW] << 7) + side
	yaw = ease_angle(yaw, lerp_angle_units(yaw_from, yaw_to, progress), YAW_RATE)

	var pitch_target := lerpf(base_pitch(cam), base_pitch(cam_next), progress)
	pitch = move_toward(pitch, pitch_target, PITCH_RATE)

	var distance_target: int = cam[CAM_DISTANCE] << 4
	if type < TYPE_TIGHT:
		distance_target = maxi(distance_target, MIN_DISTANCE)
	distance = move_toward(distance, distance_target, DISTANCE_RATE)

	follow(target.global_position)
	apply_transform()


func camera_entry(index: int) -> Array:
	return track.node_data(index).camera


static func settled_pitch(type: int, tweak: int) -> float:
	var base := 0xb0
	if type == TYPE_EDGE:
		base = 0
	elif type == TYPE_TIGHT:
		base = 0x60
	return base + (tweak * 8 if tweak < 0x80 else (tweak - 0x80) * -8)


static func preview_shot(yaw_byte: int, pitch_byte: int, distance_byte: int, type: int, focus: Vector3) -> Dictionary:
	var yaw := float(yaw_byte << 7)
	var pitch := settled_pitch(type, pitch_byte)
	var distance := distance_byte << 4
	if type < TYPE_TIGHT:
		distance = maxi(distance, MIN_DISTANCE)
	var view := Basis(Vector3.UP, (yaw - 0xc00) * Car.ANGLE_TO_RAD) * Basis(Vector3.RIGHT, -(pitch + PITCH_OFFSET) * Car.ANGLE_TO_RAD)
	var look := focus + Vector3.UP * FOCUS_HEIGHT
	var eye := look + view.z * float(distance - DISTANCE_OFFSET) * Car.UNIT_METRES
	return {"eye": eye, "look": look, "forward": -view.z, "up": view.y, "right": view.x}


func base_pitch(cam: Array) -> float:
	return settled_pitch(int(cam[CAM_TYPE]), int(cam[CAM_PITCH]))


func travel_heading() -> int:
	var horizontal := Vector2(target.vel.x, target.vel.z)
	if target.vel.length() / 64.0 < SLOW_SPEED or horizontal.is_zero_approx():
		return target.heading
	return wrapi(roundi(atan2(-horizontal.x, -horizontal.y) / Car.ANGLE_TO_RAD), 0, 4096)


# FUN_00034cb4: the segment starts at the car's race node once past its gate,
# otherwise at the node before.
func update_node() -> void:
	var race_node: int = race.nodes[race.cars.find(target)]
	node = race_node
	if track.gate_cross(race_node, track.to_units(target.global_position)) >= 0:
		node = wrapi(race_node - 1, 0, track.nodes.size())
	progress = track.segment_progress(node, target.global_position)


func follow(point: Vector3) -> void:
	focus = Vector3(
		move_toward(focus.x, point.x, FOCUS_RATE),
		move_toward(focus.y, point.y, FOCUS_RATE),
		move_toward(focus.z, point.z, FOCUS_RATE))


func ease_angle(from: float, to: float, rate: float) -> float:
	return wrapf(from + clampf(wrapf(to - from, -2048.0, 2048.0), -rate, rate), 0.0, 4096.0)


func lerp_angle_units(from: float, to: float, weight: float) -> float:
	return wrapf(from + wrapf(to - from, -2048.0, 2048.0) * weight, 0.0, 4096.0)


func apply_transform() -> void:
	var view := Basis(Vector3.UP, (yaw - 0xc00) * Car.ANGLE_TO_RAD) * Basis(Vector3.RIGHT, -(pitch + PITCH_OFFSET) * Car.ANGLE_TO_RAD)
	var eye := focus + Vector3.UP * FOCUS_HEIGHT + view.z * (distance - DISTANCE_OFFSET) * Car.UNIT_METRES
	global_transform = Transform3D(view, eye)
