class_name Autopilot
extends RefCounted

# Port of the single-player AI (FUN_00029494), driving a car through the same
# digital inputs as the pad. Headings here are the original's (the negated
# port heading) and speeds are the physics' |vel| / 64.
#
# During the track's start phase FUN_000373d4 chases a point on the node line
# with boosted handling. After it FUN_00033934 picks a heading from the node the
# car is on, blends in a lane change to block or pass the player, and brakes
# down to the section's target speed from the per-car table in the .TRK.

const STUCK_FRAMES := 100
const BLOCK_PERIOD := 0x40
const ACCEL := 0x10
const ACCEL_START := 0x20
const BRAKE := 0x40
const STEER_RIGHT := 0x400
const STEER_LEFT := 0x800

var target := 0
var target_speed := 0
var aim := 0
var stuck_frames := 0
var stuck_node := -1
var block_frames := 0
var shot_cooldown := 0
var bits := 0


static func base_handling(car: Car) -> Array:
	return Car.HANDLING[car.handling]


static func speed(car: Car) -> int:
	return int(car.vel.length() / 64.0)


static func heading_of(car: Car) -> int:
	return -car.heading & 0xfff


static func node_heading(track: Track, index: int) -> int:
	return -int(track.nodes[index].heading) & 0xfff


# FUN_00029494 puts the track's handling back every frame once the start phase
# is over, before the item effects and the AI adjust it.
func restore_handling(car: Car) -> void:
	if car.items.race.ai_frame != car.track.ai_start[1]:
		return
	var base := base_handling(car)
	car.drag = base[0]
	car.grip = base[1]
	car.engine = base[2]
	car.brake = base[3]
	car.turn_rate = base[4]


func drive(car: Car) -> void:
	var race := car.items.race
	var i := race.cars.find(car)
	var at := race.nodes[i]
	var started := race.ai_frame == car.track.ai_start[1]
	var changed := race.node_changed[i] == 1 or started
	bits = 0
	car.fire_input = false
	if not changed or at == stuck_node:
		stuck_frames += 1
		if stuck_frames > STUCK_FRAMES:
			stuck_frames = 0
			car.wreck()
	else:
		stuck_frames = 0
		stuck_node = at
	if car.wreck_frames == 0:
		if started:
			race_phase(car, race, i, at, changed)
		else:
			start_phase(car, race, i, at)
	car.accel_input = 7 if bits & (ACCEL | ACCEL_START) else 0
	car.brake_input = 7 if bits & BRAKE else 0
	car.steer_input = 0
	if bits & STEER_LEFT:
		car.steer_input = 7
	if bits & STEER_RIGHT:
		car.steer_input = -7


# FUN_000373d4: aims at the next node, or the average heading of the next one
# and one or two further at speed, bending towards that node's point the
# further away the car is. Engines scale down with the car's slot.
func start_phase(car: Car, race: Race, i: int, at: int) -> void:
	var track := car.track
	var base := base_handling(car)
	var count := track.nodes.size()
	var spd := speed(car)
	var ahead := (at + 1) % count
	var first := node_heading(track, ahead)
	var t := first
	if spd > 0x600:
		ahead = (ahead + 1) % count
		if spd > 0x800:
			ahead = (ahead + 1) % count
		var later := node_heading(track, ahead)
		if later - first + 0x800 > 0x1000 or later - first + 0x800 < 0:
			later += 0x1000
		t = (first + later) / 2
	t &= 0xfff
	var straight: int = track.nodes[at].ai[0]
	var k := 0 if i == 7 else -i
	car.brake = base[3] * 2
	car.turn_rate = base[4]
	if straight < 0x40:
		car.grip = 0x100
		car.drag = 4
		car.turn_rate = 0x60
		var pull := 0x17 if car.vehicle_kind == Car.VEHICLE_BOAT else 0x10
		car.engine = (k + pull) * base[2] >> 3
	else:
		car.grip = base[1] * 3
		car.drag = base[0] * 2 / 5
		car.engine = base[2] * 6 >> 2
	if race.ai_frame < track.ai_start[0]:
		car.engine = car.engine * (k + 0x17) >> 4
	else:
		car.engine = car.engine * (k + 0x47) >> 6

	var p := track.to_units(car.global_position)
	var u: Array = track.nodes[ahead].units
	var dx: int = p.x - u[0]
	var dy: int = p.y - u[1]
	var to_node := roundi(atan2(dy, dx) * 4096.0 / TAU) + 0xc00 & 0xfff
	var err := (t - to_node) & 0xfff
	if err > 0x800:
		err -= 0x1000
	var dist := (dx * dx + dy * dy) >> 4
	if dist < 0x280:
		if straight != 0:
			t = aim
	else:
		var w := err * dist * 4 if dist * 4 <= 0x4000 else err * 0x4000
		t = (t - (w + (0x3fff if w < 0 else 0) >> 14)) & 0xfff
	aim = t

	var diff := (t - heading_of(car)) & 0xfff
	if diff >= 9 and diff <= 0xff7:
		bits = STEER_LEFT if diff <= 0x800 else STEER_RIGHT
	car.engine = mini(car.engine, 0x7fff)
	var off := diff if diff <= 0x800 else 0xfff - diff
	if off < 0x40:
		bits |= ACCEL_START
	elif off > 0xdf:
		car.grip = 0x180
		car.vel *= 31.0 / 32.0 if off < 0x109 else 3.0 / 4.0
		bits |= BRAKE if spd > 0x700 else ACCEL_START | BRAKE
	else:
		bits |= ACCEL_START | BRAKE
	if dist > 0x800 and spd > 0x800 and straight < 0x20:
		bits = bits & ~ACCEL_START | BRAKE


# FUN_00033934. Node bytes 0x18 and 0x19 sum to how straight the track is;
# below the section's threshold (or with no straight left) the AI gets triple
# grip and half again the engine.
func race_phase(car: Car, race: Race, i: int, at: int, changed: bool) -> void:
	var track := car.track
	var ai: Array = track.nodes[at].ai
	var heading := node_heading(track, at)
	var twist: int = ai[0] + ai[1]
	var threshold := track.ai_thresholds[i][ai[3]]
	var section_speed := track.ai_speeds[i][ai[3]]
	if not car.item_active:
		var base := base_handling(car)
		if twist < threshold or ai[0] == 0:
			car.grip = base[1] * 3
			car.drag = base[0] * 2 / 5
			car.engine = base[2] * 6 >> 2
		else:
			car.grip = base[1]
			car.drag = base[0]
			car.engine = base[2]

	if track.cell_kind(car.global_position) == 1:
		steer(car, twist, threshold)
		return
	if car.wall_frames != 0:
		var d := absi(heading_of(car) - heading)
		if d > 0x800:
			d = 0x1000 - d
		target = heading
		if d <= 0x300:
			target = (heading - 0x100 if race.edges[i] == -2 else heading + 0x100) & 0xfff
		steer_ahead(car)
		return
	if race.ai_hold != 0:
		if i == 1:
			race.ai_hold -= 1
		if car.item_total != 0:
			use_items(car)
	elif not car.item_active:
		var lane := lane_change(car, race, i, at, heading, twist, threshold)
		if lane != 0:
			if lane >= 2 and car.item_total != 0:
				use_items(car)
			steer_ahead(car)
			return
		if car.item_total != 0:
			use_items(car)
	if changed:
		var next := node_heading(track, (at + 1) % track.nodes.size())
		if race.edges[i] < 0:
			off_track(race, i, ai, heading, next, twist, threshold, section_speed)
		else:
			on_track(car, race, i, ai, heading, next, twist, threshold, section_speed)
	steer(car, twist, threshold)


# On a straight with both tilts within 0x100: just ahead of the player, the
# car swerves towards the player's lane for part of every 64 frames (longer for
# the lower slots); up to four nodes behind, it heads for the other side.
func lane_change(car: Car, race: Race, i: int, at: int, heading: int, twist: int, threshold: int) -> int:
	var tilt := car.tilts_of(car.floor_normal) if car.grounded else car.air_tilt
	var level := 0x100 * Car.ANGLE_TO_RAD
	if twist < threshold * 2 or absf(tilt.x) > level or absf(tilt.y) > level:
		return 0
	var player_node := race.nodes[race.player]
	var player_lane := race.laterals[race.player]
	var lane := race.laterals[i]
	if player_node <= at:
		if at > player_node + 3:
			return 0
		if block_frames == 0 or block_frames > BLOCK_PERIOD:
			block_frames = BLOCK_PERIOD
		var mode := 0
		if block_frames <= (0x38 if i == 7 else (8 - i) * 8):
			if lane + 0x60 < player_lane:
				if lane < 0xc01:
					target = (heading + 0x80) & 0xfff
					mode = 2
			elif player_lane < lane - 0x60 and lane > 0x3ff:
				target = (heading - 0x80) & 0xfff
				mode = 2
		block_frames -= 1
		return mode
	if at < player_node - 4:
		return 0
	target = heading
	if player_lane < 0x801:
		if lane < 0x880:
			target = (heading + 0x80) & 0xfff
	elif lane > 0x780:
		target = (heading - 0x80) & 0xfff
	return 3


# FUN_00034afc: in corners the node's turn-in offset (byte 0x1a), halved below
# 1000 and dropped below 500; at the end of a straight the next node's
# heading; on a long straight, a drift back between 0x680 and 0x980 of the
# edge line.
func on_track(car: Car, race: Race, i: int, ai: Array, heading: int, next: int, twist: int, threshold: int, section_speed: int) -> void:
	var spd := speed(car)
	var t := heading
	if twist < threshold:
		var offset: int = ai[2] * 0x80
		if offset > 0x800:
			offset -= 0x1000
		if spd < 1000:
			offset = 0 if spd < 500 else offset / 2
		t = (offset + heading) & 0xfff
	elif ai[0] == 0:
		if spd > 499:
			t = next
	elif ai[0] > 0x40 and race.ai_hold == 0:
		if race.edges[i] < 0x680:
			t = (heading + 0x40) & 0xfff
		elif race.edges[i] >= 0x981:
			t = (heading - 0x40) & 0xfff
	target = t
	target_speed = section_speed


# FUN_0003496c: past an edge, turn back in by 0xa0 plus 0xc0 more near a gate
# end, slowing to half (three quarters mid-gate) of the section speed. In a
# corner the turn-in offset is added, or the next node's heading taken when
# the car went off on the outside.
func off_track(race: Race, i: int, ai: Array, heading: int, next: int, twist: int, threshold: int, section_speed: int) -> void:
	var lane := race.laterals[i]
	var edge := race.edges[i]
	var offset := 0
	var half := true
	if lane < 0x181:
		offset = 0xc0
	elif lane < 0xe80:
		half = false
	else:
		offset = -0xc0
	var h := heading
	if twist <= threshold:
		var turn: int = ai[2] * 0x80
		var negative := turn > 0x800
		if negative:
			turn -= 0x1000
		offset += turn
		if (negative and edge == -1) or (not negative and edge == -2):
			offset = -0xa0 if negative else 0xa0
			h = next
	offset += 0xa0 if edge == -1 else -0xa0
	target = (offset + h) & 0xfff
	target_speed = section_speed >> 1 if half else (section_speed >> 2) * 3


# Steering towards the target within half the turn rate either side.
func steer_bits(car: Car) -> int:
	var h := heading_of(car)
	var tolerance := car.turn_rate >> 1
	if target == 0:
		if h >= 0x1000 - tolerance or h <= tolerance:
			return 0
	elif h >= target - tolerance and h <= target + tolerance:
		return 0
	if target < h:
		return STEER_RIGHT if h - target <= 0x800 else STEER_LEFT
	return STEER_LEFT if target - h <= 0x800 else STEER_RIGHT


# FUN_0003486c: steer and keep the throttle open.
func steer_ahead(car: Car) -> void:
	bits |= steer_bits(car) | ACCEL


# FUN_000345d8: accelerate up to the target speed and brake above it; while
# turning on a straight with more than 0x200 to go, only below 500; with the
# track well past the threshold, always.
func steer(car: Car, twist: int, threshold: int) -> void:
	var spd := speed(car)
	var turn := steer_bits(car)
	bits |= turn
	var accel := twist - threshold > 0x32 or spd <= target_speed
	if turn != 0:
		var h := heading_of(car)
		var d := h - target if target < h else target - h
		if threshold < twist:
			if d <= 0x200:
				accel = twist - threshold > 0x32 or spd < target_speed
			else:
				accel = spd < 500
		else:
			accel = spd < target_speed
	bits |= ACCEL if accel else BRAKE


# FUN_0003403c: the original AI fires its selected item at the player when the
# track ahead is straight enough (node byte 0x18), it faces along the track,
# sits away from the edges and the player is in reach.
func use_items(car: Car) -> void:
	var race := car.items.race
	var me := race.cars.find(car)
	var player := race.player
	if me == player:
		return
	if shot_cooldown != 0:
		shot_cooldown = 0x18 if shot_cooldown >= 0x1a else shot_cooldown - 1
	if car.item_active:
		return
	var at: int = race.nodes[me]
	var info: Dictionary = car.track.nodes[at]
	var straight: int = info.ai[0]
	var lateral := race.laterals[me]
	var last_lap := race.laps_left[me] == 1 and car.item_total >= 2
	var fire := false
	match car.selected_item:
		Items.SHRINK, Items.STILTS:
			fire = straight >= 0xa0 and facing(car, info, 0xc0) and centred(lateral, 0x200)
		Items.GROW:
			fire = facing(car, info, 0x100) and centred(lateral, 0x200) and (last_lap or player_within(race, at, 0, 2))
		Items.ROCKET:
			fire = facing(car, info, 0x20) and straight >= 0xa0 and centred(lateral, 0x400)
		Items.REPULSOR:
			fire = last_lap or player_within(race, at, -2, 0)
		Items.OIL, Items.CLOUD, Items.GLUE:
			fire = player_within(race, at, -4, -1) and beside(race, lateral, 0x200)
		Items.UNUSED:
			fire = true
		Items.BOMB:
			fire = straight >= 100 and facing(car, info, 0x80) and centred(lateral, 0x200) and player_within(race, at, 1, 5) and beside(race, lateral, 0x200)
		Items.SHOT:
			fire = shot_cooldown == 0 and facing(car, info, 0x60) and player_within(race, at, 1, 4) and beside(race, lateral, 0x180)
			if fire:
				shot_cooldown = 0x19
		Items.BOUNCE:
			if straight >= 100 and facing(car, info, 0x80) and centred(lateral, 0x200):
				var ahead := wrapi(at + (10 if race.laps_left[me] == 1 else 20), 0, car.track.nodes.size())
				fire = race.places[player] < race.places[me] and ahead <= race.nodes[player]
				fire = fire or (player_within(race, at, 1, 4) and beside(race, lateral, 0x180))
	car.fire_input = fire


func facing(car: Car, info: Dictionary, tolerance: int) -> bool:
	return absi(wrapi(car.heading - int(info.heading), -2048, 2048)) <= tolerance


func centred(lateral: int, margin: int) -> bool:
	return lateral >= margin and lateral <= 0x1000 - margin


func player_within(race: Race, at: int, first: int, last: int) -> bool:
	var count := race.track.nodes.size()
	var lo := wrapi(at + first, 0, count)
	var hi := wrapi(at + last, 0, count)
	var p := race.nodes[race.player]
	if lo < hi:
		return p >= lo and p <= hi
	return p >= lo or p <= hi


func beside(race: Race, lateral: int, margin: int) -> bool:
	return absi(race.laterals[race.player] - lateral) <= margin
