class_name CarSim
extends RefCounted

# The physics half of FUN_0003a330 in the original's own fixed point: position
# and speed are whole numbers with 4096 to the world unit, angles have 4096 to
# the turn, and x, y and height are the original's axes. Car keeps the port's
# side of the state and copies it in and out around frame().

const STEP := 0x10000
const CELL := 0x200000
const HALF_CELL := 0x100000
const NO_FLOOR := 0x400
const SURFACE_OUT := 2
const SURFACE_LOOSE := 6
const SURFACE_ICE := 8
const SURFACE_MUD := 10
const SURFACE_WATER := 12
const SURFACE_SPLASH := 14
const MAX_DROP := 0x80000
# FUN_0003a000: the six points of the body, in the car's own frame.
const BODY := [Vector3i(-28, -32, 79), Vector3i(28, -32, 79), Vector3i(28, -32, 0), Vector3i(28, -32, -79), Vector3i(-28, -32, -79), Vector3i(-28, -32, 0)]

var blocks: CollisionBlocks

# What the car keeps from frame to frame.
var pos := Vector3i.ZERO
var vel := Vector3i.ZERO
var heading := 0
var travel := 0
var tilt_x := 0
var tilt_y := 0
var fall := 0
var normal := Vector3i(0, 0, 0x1000)
var shove := Vector2i.ZERO
var grounded := 1
var air := 0
var slope_turn := 0
var slope_drift := 0
var speed := 0
var level_speed := 0
var wall := 0
var ramp := 0
var boost := 0
var surface := 0
var last_ground := 0
var steer_left := 0
var steer_right := 0
var unsteered := 0
var spin := 0
var turned := 0
var drag := 0
var grip := 0
var base_grip := 0
var engine := 0
var brake_force := 0
var turn_rate := 0

# What the frame is given.
var accel := 0
var brake := 0
var steer := 0
var opponent := false
var walls := true
var guarded := false
var held := false
var water := -1

# What the frame reports back.
var wrecked := false
var splashed := false
var landed := false
var bumped := false
var boosting := false
var spun := false
var hit_incidence := -1
var sparks: Array[Vector3i] = []

var points: Array[Vector3i] = [Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO, Vector3i.ZERO]
var move := Vector3i.ZERO
var left := Vector3i.ZERO
var kept := Vector3i.ZERO
var back_off := 0
var hit_normal := Vector3i.ZERO
var hit_heading := 0
var on_face := false
var snap := 0
var step_x := 0
var step_y := 0
var was_grounded := 0
var under := 0
# The tilt the frame's forces were laid on, and the tilt the motion was last
# aimed along.
var first_tilt_x := 0
var first_tilt_y := 0
var held_tilt_x := 0
var held_tilt_y := 0


func frame() -> void:
	wrecked = false
	splashed = false
	landed = false
	bumped = false
	boosting = false
	spun = false
	hit_incidence = -1
	sparks.clear()
	was_grounded = grounded
	check_column()
	var start_heading := heading & 0xfff
	place_points()
	turned = 0
	var q := measure_speed()
	if wall != 0:
		wall -= 1
		if wall > 0x10:
			wall = 0x10
	var thrust := throttle()
	heading &= 0xfff
	thrust = turn_wheel(thrust)
	var reverse := thrust < 1
	if reverse:
		thrust = -thrust
	if turned != 0:
		var drift := Fixed.short(0x1000 - normal.z >> 7)
		if ((fall - (Fixed.short(heading) - 0x400)) & 0xfff) > 0x7ff:
			drift = -drift
		heading = Fixed.short(heading + drift)
	else:
		settle_heading()
	heading &= 0xfff
	if start_heading != heading:
		place_points()
	held_tilt_x = tilt_x
	held_tilt_y = tilt_y
	var facing := travel
	if grounded == 1:
		facing = heading - slope_turn
	var push := Fixed.turn(Fixed.matrix(tilt_x, tilt_y, facing), thrust, 0, 0)
	var add := Vector3i(-push.y, push.x, push.z) if reverse else Vector3i(push.y, -push.x, -push.z)
	var k := mini(q * drag >> 15, 0x4000)
	var next := Vector3i(roll(vel.x - Fixed.shr(k * vel.x, 14)), roll(vel.y - Fixed.shr(k * vel.y, 14)), roll(vel.z - Fixed.shr(k * vel.z, 14))) + add
	if grounded != 0:
		next = tyres(next, q)
	if grounded == 1:
		var d := (fall - Fixed.short(heading)) & 0x7ff
		if d > 0x400:
			d = (0x400 - d) & 0x3ff
		if d > 0x100:
			var pull := d * 3
			next.x += Fixed.shr(normal.x * pull, 11)
			next.y += Fixed.shr(normal.y * pull, 11)
			next.z -= Fixed.shr((0x1000 - normal.z) * pull, 10)
	else:
		next.z -= 0x3000
		air += 1
		var rate := mini(air * air >> 2, 0x40)
		var slow := maxi(0x1000 - level_speed, 0)
		var lean := Fixed.turn(Fixed.matrix(0, 0, travel), (rate * slow >> 12) & 0xffff, 0, 0)
		tilt_y = clampi(wrap_angle(Fixed.short(tilt_y) - lean.x), -0x400, 0x400)
		tilt_x = clampi(wrap_angle(Fixed.short(tilt_x) + lean.y), -0x400, 0x400)
	kept = next
	first_tilt_x = held_tilt_x
	first_tilt_y = held_tilt_y
	move = next
	move.x += take_shove(0)
	move.y += take_shove(1)
	travel_frame()
	if speed < 8:
		travel = heading
	else:
		travel = course(kept.x, kept.y)
	if grounded == 1 and (tilt_x != first_tilt_x or tilt_y != first_tilt_y or wall == 8):
		var along := Vector3i(absi(kept.x), absi(kept.y), absi(kept.z))
		along += Vector3i(along.x >> 9, along.y >> 9, along.z >> 9)
		vel = aim(along, travel)
	else:
		vel = kept


# FUN_0003a330 counts the frames since the wheel was last turned on every
# call, also while the car is wrecked or waiting for the start.
func count_unsteered() -> void:
	unsteered = unsteered + 1 if steer_left == 0 and steer_right == 0 else 0


# Two wrecks from where the car is over the track, both before it moves. A
# guarded car is wrecked unless some layer has a face in its bucket that the
# car is over, or no more than 0x20 under: that is driving off the edge of the
# modelled track. And a car in the air is wrecked once it is 0x14 under the
# highest face of the highest such layer, but not yet 0x40 under it.
func check_column() -> void:
	var gx := pos.x + blocks.offset_x
	var gy := pos.y + blocks.offset_y
	var column := (gx >> 21) + (gy >> 21) * blocks.width
	var x := ((gx >> 12) & 0x1ff) - 0x100
	var y := ((gy >> 12) & 0x1ff) - 0x100
	var height := pos.z >> 12
	if guarded:
		var over := false
		for i in blocks.layers:
			var low := column_edge(column + i * blocks.layer, x, y, false)
			if low != NO_FLOOR:
				over = height - (i * 0x200 + low) > -0x21
				if over:
					break
		if not over:
			wrecked = true
	if grounded == 0:
		for n in blocks.layers:
			var i := blocks.layers - 1 - n
			var high := column_edge(column + i * blocks.layer, x, y, true)
			if high != -1:
				under = height - (i * 0x200 + high)
				break
		if under < -0x14 and (under > -0x40 or pos.z < 0x8000):
			wrecked = true


# FUN_00044a88 and FUN_000443b8: the lowest or the highest face over a point of
# a cell, as a height above the bottom of the cell.
func column_edge(cell: int, x: int, y: int, highest: bool) -> int:
	var edge := -1 if highest else NO_FLOOR
	var block: CollisionBlocks.Block = blocks.block_at(cell)
	if block == null:
		return edge
	x = maxi(x, -0xff) if block.mirror_x else mini(x, 0xff)
	y = maxi(y, -0xff) if block.mirror_y else mini(y, 0xff)
	var bucket := block.bucket_x(x) * 4 + block.bucket_y(y)
	var verts := block.verts
	var faces := block.faces
	for quad in 2:
		var list: PackedInt32Array = block.quads[bucket] if quad == 1 else block.tris[bucket]
		for at in list:
			var f := at * CollisionBlocks.FACE
			var up := faces[f + CollisionBlocks.N1]
			if up == 0:
				continue
			var a := faces[f] * 3
			var b := faces[f + 1] * 3
			var c := faces[f + 2] * 3
			var d := faces[f + 3] * 3
			if not inside(quad == 1, verts[a], verts[a + 2], verts[b], verts[b + 2], verts[c], verts[c + 2], verts[d], verts[d + 2], -y, -x):
				continue
			var height := 0x100 - ((faces[f + CollisionBlocks.N0] * (y + verts[a]) + faces[f + CollisionBlocks.N2] * (x + verts[a + 2])) / up + verts[a + 1])
			if highest:
				edge = maxi(edge, height)
			else:
				edge = mini(edge, height)
	return edge


# Speed along the ground and in all, and the square of the speed over 2^17.
func measure_speed() -> int:
	var x := absi(vel.x)
	var y := absi(vel.y)
	var z := absi(vel.z)
	var shift := 0
	while x > 0x3fff or y > 0x3fff or z > 0x3fff:
		x >>= 1
		y >>= 1
		z >>= 1
		shift += 1
	var level := x * x + y * y
	level_speed = 0 if level == 0 else (Fixed.root(level) << shift) >> 6
	var all := level + z * z
	speed = 0 if all == 0 else (Fixed.root(all) << shift) >> 6
	return all >> maxi(17 - 2 * shift, 0)


func throttle() -> int:
	var thrust := 0
	if grounded != 1:
		return 0x1000 if level_speed < 0x400 else 0
	var driving := accel != 0 if opponent else accel != 0 and brake == 0
	if not driving:
		ramp = maxi(ramp - 1, 0)
		boost = 0
	else:
		var up := mini(ramp + 1, 0x10)
		if wall == 0:
			var power := 8000 if surface == SURFACE_ICE else engine
			if speed < 0x101:
				thrust = power & 0xffff
			else:
				var d := (Fixed.short(heading) - Fixed.short(travel)) & 0x7ff
				if d > 0x400:
					d = 0x800 - d
				thrust = (maxi((0x400 - d) * 2, 0x400) * power >> 11) & 0xffff
		var force := Fixed.short(thrust)
		if speed < 0x500:
			force = 0x7fff if force > 0x3fff else force << 1
		var drive := force * up
		if speed < 0x800 and (((tilt_x + 0xfe3f) & 0xffff) < 0xc7f or ((tilt_y - 0x1c1) & 0xffff) < 0xc7f):
			drive = (0x7fff if force > 0x3fff else force << 1) * up
		thrust = (drive >> 4) * accel / 7 & 0xffff
		if boost != 0:
			boost -= 1
			thrust = ((drive >> 4) + (drive >> 5)) & 0xffff
			boosting = true
		ramp = up
	if brake != 0:
		var braking := accel == 0 if opponent else accel == 0 or (steer != 7 and steer != -7)
		if braking:
			thrust = (thrust - brake_force * brake / 7) & 0xffff
	return Fixed.short(thrust)


func turn_wheel(thrust: int) -> int:
	if spin != 0:
		if not can_turn(true):
			spin = 0
			grip = 0
		else:
			var swing := spin
			if swing > 0x1f:
				swing = 0x40 - swing
			heading = Fixed.short(heading + swing * 0x20)
			turned = swing * 0x20
			spin -= 1
			spun = true
			grip = 0
		if spin == 0:
			grip = base_grip
		return thrust
	if steer < 1:
		steer_right = 0
	else:
		steer_right += 1
		if can_turn(true):
			var amount := wheel(steer_right, steer)
			turned = amount if away(amount) else -amount
			heading = Fixed.short(heading + amount)
			if speed < 500:
				thrust = Fixed.short(thrust + 0x600)
	if steer < 0:
		steer_left += 1
		if can_turn(false):
			var amount := wheel(steer_left, -steer)
			turned = -amount if away(amount) else amount
			heading = Fixed.short(heading - amount)
			if speed < 500:
				thrust = Fixed.short(thrust + 0x600)
	else:
		steer_left = 0
	return thrust


func wheel(hold: int, amount: int) -> int:
	var by := turn_rate
	if opponent:
		by = mini(hold * hold + 8, turn_rate)
	if amount != 7:
		by = turn_rate * amount / 6
	if accel == 7 and brake == 7:
		by += by / 2
	return by


func away(_amount: int) -> bool:
	return ((Fixed.short(travel) - Fixed.short(heading) + 0x3ff) & 0xffffffff) < 0x7ff


# With no steering the heading settles on the nearest eighth of a turn.
func settle_heading() -> void:
	var a := heading & 0x3fc
	if opponent:
		if a < 0x30:
			if a != 0:
				a -= 4
		elif a < 0xa0:
			if a >= 0x81:
				a -= 4
		elif a < 0x130:
			if a >= 0x101:
				a -= 4
		elif a < 0x1a0:
			if a >= 0x181:
				a -= 4
		elif a < 0x230:
			if a >= 0x201:
				a -= 4
		elif a < 0x2a0:
			if a >= 0x281:
				a -= 4
		elif a < 0x330:
			if a >= 0x301:
				a -= 4
		elif a < 0x3a0:
			if a >= 0x381:
				a -= 4
		elif a > 0x3c0:
			a += 4
	else:
		if speed < 0x201:
			return
		if a < 0xc0:
			a = 0 if a < 0xd else a - 0xc
		elif a < 0xf4:
			a += 0xc
		elif a < 0x140:
			a = 0x100 if a < 0x10d else a - 0xc
		elif a < 0x1f4:
			a += 0xc
		elif a < 0x2c0:
			a = 0x200 if a < 0x20d else a - 0xc
		elif a < 0x2f4 or a > 0x33f:
			a += 0xc
		else:
			a = 0x300 if a < 0x30d else a - 0xc
	heading = a + (heading & 0xc00)


func roll(v: int) -> int:
	if v < 0:
		v += 0x80
	var edge := v + 0x7f
	var out := v
	if v > 0:
		out = v - 0x80
		edge = v - 1
	if edge >= 0 and edge < 0xff:
		return 0
	return out


func wrap_angle(a: int) -> int:
	a &= 0xfff
	return a - 0x1000 if a > 0x800 else a


# Grip across the car and along it, both laid on the slope.
func tyres(next: Vector3i, q: int) -> Vector3i:
	var hold := grip
	if surface == SURFACE_MUD:
		next = Vector3i(Fixed.shr(next.x * 7, 3), Fixed.shr(next.y * 7, 3), Fixed.shr(next.z * 7, 3))
	if surface == SURFACE_ICE:
		hold = 0x38
	if unsteered != 0:
		hold = maxi(hold, unsteered << 3)
		if grip < hold and hold > 0x60:
			hold = 0x60
	var slip := Fixed.short(travel) - (Fixed.short(heading) - 0x400) + slope_turn
	var across := Fixed.rcos(slip)
	var quarter := q >> 2
	if across < -0x20 or across > 0x20:
		if across < 1:
			across = -(across * across >> 10)
			if across == 0:
				across = -1
		else:
			across = across * across >> 10
			if across == 0:
				across = 1
		var force := Fixed.shr(Fixed.shr(quarter * across, 12) * hold, 9)
		var way := 1
		if force < 0:
			force = -force
			way = -1
		force = maxi(force, hold)
		if q < 9:
			force = 0
		if force != 0:
			force = mini(force, speed)
			var flat := Fixed.turn(Fixed.matrix(0x400, heading - 0x400, 0), way * force, 0, 0)
			var laid := Fixed.turn(Fixed.matrix(tilt_x, tilt_y, 0), flat.x, flat.y, flat.z)
			next += Vector3i(laid.y * -4, laid.x * 4, laid.z * 4)
	var along := Fixed.csin(slip)
	var pull := 0
	if grip < 0x40:
		pull = Fixed.shr(Fixed.shr(quarter * along, 12) * grip, 9)
	else:
		pull = Fixed.shr(quarter * along, 15)
	var ahead := 1
	if pull < 0:
		pull = -pull
		ahead = -1
	pull = maxi(pull, grip << 3)
	if q > 4:
		var flat := Fixed.turn(Fixed.matrix(0x400, heading, 0), ahead * pull, 0, 0)
		var laid := Fixed.turn(Fixed.matrix(tilt_x, tilt_y, 0), flat.x, flat.y, flat.z)
		next += Vector3i(-laid.y, laid.x, laid.z)
	if accel == 0 and brake == 0:
		var rest := 0x40 if tilt_x == 0 and tilt_y == 0 else 0x10
		if speed < rest and speed != 0:
			next = Vector3i.ZERO
	return next


func take_shove(axis: int) -> int:
	var owed := shove[axis]
	if owed > 0:
		if owed < 0x4001:
			shove[axis] = 0
			return owed
		shove[axis] = owed - 0x4000
		return 0x4000
	if owed < 0:
		if owed < -0x4000:
			shove[axis] = owed + 0x4000
			return -0x4000
		shove[axis] = 0
		return -owed
	return 0


# The heading of a level motion.
func course(x: int, y: int) -> int:
	var out := 0
	if y < x:
		var s := 0x400
		if y != 0:
			var t := (x << 12) / y
			s = 0 if t == 0 else Fixed.short(Fixed.atan_ratio(t))
		if y < 1:
			if y == 0:
				out = 0x400 if x >= 0 else 0xc00
			else:
				out = -s
		else:
			out = 0x800 - s
	else:
		var s := 0x400
		if x != 0:
			var t := (y << 12) / x
			s = 0 if t == 0 else Fixed.short(Fixed.atan_ratio(t))
		s = 0x400 - s
		if x > 0:
			out = 0x800 - s
		elif x == 0:
			out = 0x800 if y >= 0 else 0
		else:
			out = -s
	return out & 0xfff


# A motion of this size laid along the car's tilt on a level heading.
func aim(size: Vector3i, level: int) -> Vector3i:
	var shift := 0
	while size.x > 0x3fff or size.y > 0x3fff or size.z > 0x3fff:
		size = Vector3i(size.x >> 1, size.y >> 1, size.z >> 1)
		shift += 1
	var square := size.x * size.x + size.y * size.y + size.z * size.z
	var length := 0 if square == 0 else Fixed.root(square) << shift
	var m := Fixed.matrix(tilt_x, tilt_y, level)
	var scale := 1
	var grow := false
	if length < 0x4000:
		if length != 0:
			grow = true
			while length < 0x4000:
				length <<= 1
				scale <<= 1
	else:
		while length > 0x3fff:
			length >>= 1
			scale <<= 1
	var out := Fixed.turn(m, length & 0xffff, 0, 0)
	if grow:
		out = Vector3i(out.x / scale, out.y / scale, out.z / scale)
	else:
		out *= scale
	return Vector3i(out.y, -out.x, -out.z)


# FUN_0003a000.
func place_points() -> void:
	var flat := Fixed.matrix(0x400, heading - slope_turn, 0)
	var lean := Fixed.matrix(tilt_y, -tilt_x, 0)
	var m := PackedInt32Array()
	m.resize(9)
	for column in 3:
		var turned_column := Fixed.turn(lean, flat[column], flat[column + 3], flat[column + 6])
		m[column] = clampi(turned_column.x, -0x8000, 0x7fff)
		m[column + 3] = clampi(turned_column.y, -0x8000, 0x7fff)
		m[column + 6] = clampi(turned_column.z, -0x8000, 0x7fff)
	for i in 6:
		var p: Vector3i = BODY[i]
		points[i] = Fixed.turn(m, p.x, p.y, p.z)


func local(v: int) -> int:
	return (v & 0x1fffff) - HALF_CELL


func units(v: int) -> int:
	return Fixed.shr(v, 12)


# FUN_0003fbb8: a car only turns when no wall is within reach of the three
# points on the side that would swing out. A wall there pushes it off instead.
func can_turn(right: bool) -> bool:
	if not walls or blocks == null:
		return true
	var gx := pos.x + blocks.offset_x
	var gy := pos.y + blocks.offset_y
	var cell := (gx >> 21) + (gy >> 21) * blocks.width + (pos.z >> 21) * blocks.layer
	var y := units(local(gy))
	var z := units(HALF_CELL - (pos.z & 0x1fffff))
	step_x = 0x20000
	step_y = 0x20000
	var x := units(local(gx)) - 8
	if x < -0xff:
		x += 0x200
		cell -= 1
	var h := Fixed.short(heading)
	var first := 2
	if h >= 0x300:
		first = 1
		if h >= 0x500:
			first = 0
			if h > 0x7ff:
				first = 5
				if h > 0xaff:
					first = 4
					if h > 0xcff:
						first = 3
	if not right:
		first = (first + 3) % 6
	var touched := 0
	if wall_x(x, y, z, cell, 3, first, -1):
		touched |= 1
	x += 0x10
	if x > 0xff:
		x -= 0x200
		cell += 1
	if wall_x(x, y, z, cell, 3, (first + 3) % 6, 1):
		touched |= 2
	x -= 8
	if x < -0xff:
		x += 0x200
		cell -= 1
	y -= 8
	if y < -0xff:
		y += 0x200
		cell -= blocks.width
	first = 4
	if h > 0xff:
		first = 3
		if h > 0x3ff:
			first = 2
			if h > 0x6ff:
				first = 1
				if h > 0x8ff:
					first = 0
					if h >= 0xc00:
						first = 5
						if h > 0xeff:
							first = 4
	if not right:
		first = (first + 3) % 6
	if wall_y(x, y, z, cell, 3, first, -1):
		touched |= 4
	y += 0x10
	if y > 0xff:
		y -= 0x200
		cell += blocks.width
	if wall_y(x, y, z, cell, 3, (first + 3) % 6, 1):
		touched |= 8
	if touched == 0:
		return true
	if touched & 1:
		pos.x += 0x2000
		shove.x += 0x10000
	if touched & 2:
		pos.x -= 0x2000
		shove.x -= 0x10000
	if touched & 4:
		pos.y += 0x2000
		shove.y += 0x10000
	if touched & 8:
		pos.y -= 0x2000
		shove.y -= 0x10000
	wall = 8
	return false


# The stepped motion of FUN_0003a330: at most 16 units a step along the
# fastest axis, x and its wall test, y and its wall test, then the height and
# the floor. A wall or a hard landing turns the motion and starts it over, and
# a second one in the frame stops the car.
func travel_frame() -> void:
	var lx := local(pos.x + blocks.offset_x)
	var ly := local(pos.y + blocks.offset_y)
	var lz := HALF_CELL - (pos.z & 0x1fffff)
	var column := ((pos.x + blocks.offset_x) >> 21) + ((pos.y + blocks.offset_y) >> 21) * blocks.width
	var cell := column + (pos.z >> 21) * blocks.layer
	var h := Fixed.short(heading)
	var down_x := 3
	if h >= 0x300:
		down_x = 2
		if h > 0x4ff:
			down_x = 1
			if h > 0x7ff:
				down_x = 0
				if h >= 0xb00:
					down_x = 5
					if h > 0xcff:
						down_x = 4
	var down_y := 5
	if h >= 0x100 and h <= 0xf00:
		if h < 0x400:
			down_y = 4
		elif h < 0x700:
			down_y = 3
		elif h < 0x900:
			down_y = 2
		elif h < 0xc00:
			down_y = 1
		else:
			down_y = 0
	var hits := 0
	var step := Vector3i.ZERO
	while true:
		var size := Vector3i(absi(move.x), absi(move.y), absi(move.z))
		var lead := 0
		if size.x < size.y or size.x < size.z:
			if size.y < size.z:
				lead = 2
				if size.z > STEP:
					step = Vector3i(((size.x << 12) / size.z) << 4, ((size.y << 12) / size.z) << 4, STEP)
			else:
				lead = 1
				if size.y > STEP:
					step = Vector3i(((size.x << 12) / size.y) << 4, STEP, ((size.z << 12) / size.y) << 4)
		elif size.x > STEP:
			step = Vector3i(STEP, ((size.y << 12) / size.x) << 4, ((size.z << 12) / size.x) << 4)
		if size == Vector3i.ZERO:
			return
		if hits >= 2:
			move = Vector3i.ZERO
			return
		left = size
		var last := false
		var again := false
		while not last:
			if left[lead] <= STEP:
				step = left
				last = true
			step_x = step.x
			step_y = step.y
			var struck := false
			left.x -= step.x
			if move.x < 0:
				lx -= step.x
				pos.x -= step.x
				if lx < -0xfffff:
					lx += CELL
					cell -= 1
					column -= 1
				if wall_x(units(lx), units(ly), units(lz), cell, 4, down_x, -1):
					struck = true
					lx += back_off
					pos.x += back_off
					if lx > HALF_CELL:
						lx -= CELL
						cell += 1
						column += 1
			elif move.x > 0:
				lx += step.x
				pos.x += step.x
				if lx > HALF_CELL:
					lx -= CELL
					cell += 1
					column += 1
				if wall_x(units(lx), units(ly), units(lz), cell, 4, (down_x + 3) % 6, 1):
					struck = true
					lx -= back_off
					pos.x -= back_off
					if lx < -0xfffff:
						lx += CELL
						cell -= 1
						column -= 1
			left.y -= step.y
			if move.y < 0:
				ly -= step.y
				pos.y -= step.y
				if ly < -0xfffff:
					ly += CELL
					cell -= blocks.width
					column -= blocks.width
				if wall_y(units(lx), units(ly), units(lz), cell, 4, down_y, -1):
					struck = true
					ly += back_off
					pos.y += back_off
					if ly > HALF_CELL:
						ly -= CELL
						cell += blocks.width
						column += blocks.width
			elif move.y > 0:
				ly += step.y
				pos.y += step.y
				if ly > HALF_CELL:
					ly -= CELL
					cell += blocks.width
					column += blocks.width
				if wall_y(units(lx), units(ly), units(lz), cell, 4, (down_y + 3) % 6, 1):
					struck = true
					ly -= back_off
					pos.y -= back_off
					if ly < -0xfffff:
						ly += CELL
						cell -= blocks.width
						column -= blocks.width
			var was := grounded
			if struck:
				bumped = true
				wall = 8
				bounce()
				hits += 1
				again = true
				break
			left.z -= step.z
			if move.z < 0:
				lz += step.z
				pos.z -= step.z
				if lz > HALF_CELL:
					lz -= CELL
					cell -= blocks.layer
					if cell < 0:
						cell += blocks.layer
						lz = HALF_CELL
						left.z = 0
						pos.z = 0
			if move.z > 0:
				lz -= step.z
				pos.z += step.z
				if lz < -0xfffff:
					lz += CELL
					cell += blocks.layer
			grounded = 0
			var settle := held
			if not held:
				snap = 0x12 if move.z < 0 or was == 1 else 4
				if surface == SURFACE_LOOSE and was_grounded != 0:
					snap = 1
				var found := NO_FLOOR
				var lift := 0x100
				found = floor_in(cell, units(lx), units(ly), units(lz))
				if found == NO_FLOOR and lz > 0xf0000 and cell - blocks.layer >= 0:
					found = floor_in(cell - blocks.layer, units(lx), units(ly), units(lz) - 0x200)
					lift = -0x100
				if found == NO_FLOOR and lz < -0xf0000:
					found = floor_in(cell + blocks.layer, units(lx), units(ly), units(lz) + 0x200)
					lift = 0x300
				if found != NO_FLOOR:
					pos.z = (((pos.z >> 21) << 9) - (found - lift)) * 0x1000
					settle = true
				elif cell <= blocks.layer and pos.z == 0:
					settle = true
				elif water != -1 and pos.z <= water << 12:
					settle = true
					pos.z = (water << 12) - 1
				elif was == 1:
					last_ground = pos.z
			if settle:
				if water != -1 and pos.z < water << 12:
					pos.z = water << 12
					normal = Vector3i(0, 0, 0x1000)
					tilt_x = 0
					tilt_y = 0
					fall = 0
					slope_drift = 0
					slope_turn = 0
					surface = SURFACE_WATER
					kept.z = 0
					step.z = 0
					left.z = 0
					move.z = 0
				lz = HALF_CELL - (pos.z & 0x1fffff)
				grounded = 1
				air = 0
				cell = column + (pos.z >> 21) * blocks.layer
				if was == 0 and not land():
					hits += 1
					again = true
					break
				if held_tilt_x != tilt_x or held_tilt_y != tilt_y:
					if not last and was == 1:
						if hard(held_tilt_x, tilt_x) or hard(held_tilt_y, tilt_y):
							last_ground = pos.z
							land()
							hits += 1
							again = true
							break
					if not last and on_face:
						held_tilt_x = tilt_x
						held_tilt_y = tilt_y
						var rest := Vector3i(left.x + (left.x >> 9), left.y + (left.y >> 9), left.z + (left.z >> 9))
						var a := rest.x if move.x >= 0 else -rest.x
						var b := rest.y if move.y >= 0 else -rest.y
						var level := 0
						if b == 0:
							level = 0x400 if a >= 0 else 0xc00
						else:
							var t := (a << 12) / b
							var s := 0 if t == 0 else Fixed.short(Fixed.atan_ratio(t))
							level = -s if b < 1 else 0x800 - s
						move = aim(rest, level & 0xfff)
						again = true
						break
			if left == Vector3i.ZERO:
				return
		if not again:
			return


func hard(before: int, after: int) -> bool:
	return (((Fixed.short(before) - Fixed.short(after)) & 0xfff) - 0x281) & 0xffffffff <= 0xafe


# FUN_0003f31c: the first face of the bucket under the point that holds it
# from above and lies no more than 0x20 above it or the snap distance below.
func floor_in(cell: int, x: int, y: int, z: int) -> int:
	var block: CollisionBlocks.Block = blocks.block_at(cell)
	if block == null:
		return NO_FLOOR
	x = maxi(x, -0xff) if block.mirror_x else mini(x, 0xff)
	y = maxi(y, -0xff) if block.mirror_y else mini(y, 0xff)
	var px := -y
	var py := -x
	var bucket := block.bucket_x(x) * 4 + block.bucket_y(y)
	var verts := block.verts
	var faces := block.faces
	for quad in 2:
		var list: PackedInt32Array = block.quads[bucket] if quad == 1 else block.tris[bucket]
		for at in list:
			var f := at * CollisionBlocks.FACE
			var up := faces[f + CollisionBlocks.N1]
			if up == 0:
				continue
			var a := faces[f] * 3
			var b := faces[f + 1] * 3
			var c := faces[f + 2] * 3
			var ax := verts[a]
			var ay := verts[a + 2]
			if quad == 0:
				var first := Fixed.side(ax, ay, verts[b], verts[b + 2], px, py)
				var second := Fixed.side(verts[c], verts[c + 2], verts[b], verts[b + 2], px, py)
				if (second < 0 and first < 0) or (second > 0 and first > 0):
					continue
				var third := Fixed.side(verts[c], verts[c + 2], ax, ay, px, py)
				var held_side := first if first != 0 else -second
				if (third < 0 and held_side > 0) or (third > 0 and held_side < 0):
					continue
			else:
				var d := faces[f + 3] * 3
				var first := Fixed.side(ax, ay, verts[b], verts[b + 2], px, py)
				var second := Fixed.side(verts[d], verts[d + 2], verts[b], verts[b + 2], px, py)
				if (second < 0 and first < 0) or (second > 0 and first > 0):
					continue
				var third := Fixed.side(verts[d], verts[d + 2], verts[c], verts[c + 2], px, py)
				var held_side := first if first != 0 else -second
				if (third < 0 and held_side > 0) or (third > 0 and held_side < 0):
					continue
				var fourth := Fixed.side(ax, ay, verts[c], verts[c + 2], px, py)
				if (fourth < 0 and held_side < 0) or (fourth > 0 and held_side > 0):
					continue
			var height := (faces[f + CollisionBlocks.N0] * (y + ax) + faces[f + CollisionBlocks.N2] * (x + ay)) / up + verts[a + 1]
			var under := height - z
			if under > -0x20 and under <= snap:
				on_face = under < 2
				surface = faces[f + CollisionBlocks.SURFACE]
				normal = Vector3i(faces[f + CollisionBlocks.N2], faces[f + CollisionBlocks.N0], up)
				tilt_x = faces[f + CollisionBlocks.TILT_X]
				tilt_y = faces[f + CollisionBlocks.TILT_Y]
				fall = faces[f + CollisionBlocks.HEADING]
				slope_turn = faces[f + CollisionBlocks.TURN]
				slope_drift = faces[f + CollisionBlocks.DRIFT]
				return height
	return NO_FLOOR


# FUN_00040128 and FUN_00040f7c: has one of the body points passed a face
# during a step along x? way is -1 for a step down x.
func wall_x(x: int, y: int, z: int, cell: int, count: int, first: int, way: int) -> bool:
	if not walls:
		return false
	var lean := Fixed.short(tilt_x)
	for n in count:
		var point: Vector3i = points[(first + n) % 6]
		var at := cell
		var px := x + point.x
		var py := y + point.y
		var pz := z + point.z
		if px < -0x100:
			px += 0x200
			at -= 1
		elif px > 0xff:
			px -= 0x200
			at += 1
		if py < -0x100:
			py += 0x200
			at -= blocks.width
		elif py > 0xff:
			py -= 0x200
			at += blocks.width
		if pz < -0xff:
			pz += 0x200
			at += blocks.layer
		elif pz > 0x100:
			pz -= 0x200
			at -= blocks.layer
		var extra := 0
		while true:
			var block: CollisionBlocks.Block = blocks.block_at(at)
			if block != null and face_x(block, block.bucket_x(px + extra) * 4 + block.bucket_y(py), px, py, pz, lean, point, way):
				return true
			if extra != 0:
				break
			# A point that has just crossed a bucket edge also looks in the
			# bucket behind it, in the cell behind when that was a cell edge.
			if way < 0:
				if (px & 0x70) != 0x70:
					break
				extra = 0x40
				if px >= 0xf0:
					px -= 0x200
					at += 1
				elif block == null:
					break
			else:
				if (px & 0x70) != 0:
					break
				extra = -0x40
				if px <= -0xf0:
					px += 0x200
					at -= 1
				elif block == null:
					break
	return false


func face_x(block: CollisionBlocks.Block, bucket: int, px: int, py: int, pz: int, lean: int, point: Vector3i, way: int) -> bool:
	var verts := block.verts
	var faces := block.faces
	var sx := Fixed.short(-py)
	for quad in 2:
		var list: PackedInt32Array = block.quads[bucket] if quad == 1 else block.tris[bucket]
		for at in list:
			var f := at * CollisionBlocks.FACE
			var along := faces[f + CollisionBlocks.N2]
			if along == 0:
				continue
			if (((faces[f + CollisionBlocks.TILT_X] - lean) & 0xfff) - 0x201) & 0xffffffff >= 0xbff:
				continue
			var a := faces[f] * 3
			var b := faces[f + 1] * 3
			var c := faces[f + 2] * 3
			var ax := verts[a]
			var ay := verts[a + 1]
			if not inside(quad == 1, ax, ay, verts[b], verts[b + 1], verts[c], verts[c + 1], verts[faces[f + 3] * 3], verts[faces[f + 3] * 3 + 1], sx, pz):
				continue
			var depth := ((faces[f + CollisionBlocks.N0] * (ax + py) + faces[f + CollisionBlocks.N1] * (ay - pz)) / along + verts[a + 2] + px) * 0x1000
			if not passed(depth, step_x, way):
				continue
			if faces_point(faces[f + CollisionBlocks.WALL], point, way, false):
				strike(faces, f, point)
				return true
	return false


# FUN_00041db8 and FUN_00042cf0, the same along y.
func wall_y(x: int, y: int, z: int, cell: int, count: int, first: int, way: int) -> bool:
	if not walls:
		return false
	var lean := Fixed.short(tilt_y)
	for n in count:
		var point: Vector3i = points[(first + n) % 6]
		var at := cell
		var px := x + point.x
		var py := y + point.y
		var pz := z + point.z
		if px < -0x100:
			px += 0x200
			at -= 1
		elif px > 0xff:
			px -= 0x200
			at += 1
		if py < -0x100:
			py += 0x200
			at -= blocks.width
		elif py > 0xff:
			py -= 0x200
			at += blocks.width
		if pz < -0xff:
			pz += 0x200
			at += blocks.layer
		elif pz > 0x100:
			pz -= 0x200
			at -= blocks.layer
		var extra := 0
		while true:
			var block: CollisionBlocks.Block = blocks.block_at(at)
			if block != null and face_y(block, block.bucket_x(px) * 4 + block.bucket_y(py + extra), px, py, pz, lean, point, way):
				return true
			if extra != 0:
				break
			if way < 0:
				if (py & 0x70) != 0x70:
					break
				extra = 0x40
				if py >= 0xf0:
					py -= 0x200
					at += blocks.width
				elif block == null:
					break
			else:
				if (py & 0x70) != 0:
					break
				extra = -0x40
				if py <= -0xf0:
					py += 0x200
					at -= blocks.width
				elif block == null:
					break
	return false


func face_y(block: CollisionBlocks.Block, bucket: int, px: int, py: int, pz: int, lean: int, point: Vector3i, way: int) -> bool:
	var verts := block.verts
	var faces := block.faces
	var sx := Fixed.short(-px)
	for quad in 2:
		var list: PackedInt32Array = block.quads[bucket] if quad == 1 else block.tris[bucket]
		for at in list:
			var f := at * CollisionBlocks.FACE
			var along := faces[f + CollisionBlocks.N0]
			if along == 0:
				continue
			if (((faces[f + CollisionBlocks.TILT_Y] - lean) & 0xfff) - 0x201) & 0xffffffff >= 0xbff:
				continue
			var a := faces[f] * 3
			var b := faces[f + 1] * 3
			var c := faces[f + 2] * 3
			var ax := verts[a + 2]
			var ay := verts[a + 1]
			if not inside(quad == 1, ax, ay, verts[b + 2], verts[b + 1], verts[c + 2], verts[c + 1], verts[faces[f + 3] * 3 + 2], verts[faces[f + 3] * 3 + 1], sx, pz):
				continue
			var depth := ((faces[f + CollisionBlocks.N2] * (ax + px) + faces[f + CollisionBlocks.N1] * (ay - pz)) / along + verts[a] + py) * 0x1000
			if not passed(depth, step_y, way):
				continue
			if faces_point(faces[f + CollisionBlocks.WALL], point, way, true):
				strike(faces, f, point)
				return true
	return false


# Is the point within the face, seen along the axis of the step?
func inside(quad: bool, ax: int, ay: int, bx: int, by: int, cx: int, cy: int, dx: int, dy: int, px: int, py: int) -> bool:
	var first := Fixed.side(ax, ay, bx, by, px, py)
	if not quad:
		var second := Fixed.side(cx, cy, bx, by, px, py)
		if (second < 0 and first < 0) or (second > 0 and first > 0):
			return false
		var held_side := first if first != 0 else -second
		var third := Fixed.side(cx, cy, ax, ay, px, py)
		return not ((third < 0 and held_side > 0) or (third > 0 and held_side < 0))
	var second := Fixed.side(dx, dy, bx, by, px, py)
	if (second < 0 and first < 0) or (second > 0 and first > 0):
		return false
	var held_side := first if first != 0 else -second
	var third := Fixed.side(dx, dy, cx, cy, px, py)
	if (third < 0 and held_side > 0) or (third > 0 and held_side < 0):
		return false
	var fourth := Fixed.side(ax, ay, cx, cy, px, py)
	return not ((fourth < 0 and held_side < 0) or (fourth > 0 and held_side > 0))


# The point is past the face by no more than the step and a unit. The car
# then backs off by the step less the overshoot, and two units more.
func passed(depth: int, step: int, way: int) -> bool:
	if way < 0:
		if depth >= 1:
			return false
		depth += step
		if depth + 0x1000 < 0:
			return false
		back_off = depth + 0x2000
		return true
	if depth < 0:
		return false
	depth -= step
	if depth - 0x1000 >= 1:
		return false
	back_off = 0x2000 - depth
	return true


# Only a point on the side of the car that faces the wall is stopped by it.
func faces_point(face_heading: int, point: Vector3i, way: int, along_y: bool) -> bool:
	var a := face_heading & 0xfff
	if along_y:
		if a > 0x7ff:
			a -= 0x800
	else:
		if a >= 0x400 and a <= 0xc00:
			a -= 0x800
		a &= 0xfff
	var sx := Fixed.short(Fixed.shr(Fixed.rsin(a), 5))
	var sy := Fixed.short(Fixed.shr(Fixed.rcos(a), 5))
	var toward := Fixed.side(sx, sy, Fixed.short(point.x), Fixed.short(-point.y), 0, 0)
	return toward > 0 if way < 0 else toward < 0


func strike(faces: PackedInt32Array, f: int, point: Vector3i) -> void:
	if faces[f + CollisionBlocks.SURFACE] == SURFACE_OUT:
		surface = 0
		wrecked = true
	hit_normal = Vector3i(faces[f + CollisionBlocks.N2], faces[f + CollisionBlocks.N0], faces[f + CollisionBlocks.N1])
	hit_heading = faces[f + CollisionBlocks.WALL] & 0xfff
	if speed > 0x200:
		sparks.append(point)


# FUN_00043c1c: the speed and what is left of the motion are both turned about
# the level heading of the wall, and lose more the squarer the hit.
func bounce() -> void:
	if grounded == 0 and last_ground - pos.z > MAX_DROP:
		wrecked = true
		return
	if kept == Vector3i.ZERO:
		return
	var along := kept
	while absi(along.x) > 0x3fff or absi(along.y) > 0x3fff or absi(along.z) > 0x3fff:
		along = Vector3i(along.x / 2, along.y / 2, along.z / 2)
	along = Fixed.normal(along)
	var into := mini(absi(Fixed.shr(hit_normal.y * along.y + hit_normal.z * along.z + hit_normal.x * along.x, 12)), 0x1000)
	hit_incidence = into
	var keep := mini(0x1400 - into, 0x1000) >> 1
	var a := hit_heading & 0xfff
	if a >= 0x401 and a <= 0x7ff:
		a += 0x800
	var m := Fixed.matrix(0, 0x400, Fixed.short(a) * -2)
	var size := maxi(absi(kept.x), maxi(absi(kept.z), absi(kept.y)))
	var scale := 1
	while size > 0x3fff:
		kept = Vector3i(kept.x / 2, kept.y / 2, kept.z / 2)
		scale <<= 1
		size >>= 1
	if scale == 1:
		while size < 0x2000:
			kept = Vector3i(kept.x << 1, kept.y << 1, kept.z << 1)
			size <<= 1
	scale = maxi(scale, 3)
	var out := Fixed.turn(m, kept.x, kept.y, -kept.z)
	var by := scale * keep
	kept = Vector3i(Fixed.shr(by * out.z, 11), Fixed.shr(by * out.y, 11), Fixed.shr(-out.x * by, 11))
	var rest := Vector3i(-left.x if move.x < 0 else left.x, -left.y if move.y < 0 else left.y, -left.z if move.z < 0 else left.z)
	size = maxi(absi(rest.x), maxi(absi(rest.z), absi(rest.y)))
	scale = 1
	while size > 0x3fff:
		rest = Vector3i(rest.x / 2, rest.y / 2, rest.z / 2)
		scale <<= 1
		size >>= 1
	out = Fixed.turn(m, rest.x, rest.y, -rest.z)
	by = scale * keep
	move = Vector3i(Fixed.shr(by * out.z, 11), Fixed.shr(by * out.y, 11), Fixed.shr(-out.x * by, 11))


func climb(rise: int, run: int) -> int:
	if run == 0:
		return 0x400
	var t := (rise << 12) / run
	return 0 if t == 0 else Fixed.short(Fixed.atan_ratio(t))


# FUN_0003ea8c: a drop of more than 0x80 units wrecks the car. A steep impact
# turns the speed about the floor, and a strong enough one throws the car back
# into the air. False when the motion has to start over.
func land() -> bool:
	landed = true
	var climb_y := climb(kept.z, kept.y)
	var climb_x := climb(kept.z, kept.x)
	var along := kept
	while absi(along.x) > 0x3fff or absi(along.y) > 0x3fff or absi(along.z) > 0x3fff:
		along = Vector3i(along.x / 2, along.y / 2, along.z / 2)
	along = Fixed.normal(along)
	var into := Fixed.shr(normal.y * along.y + normal.z * along.z + normal.x * along.x, 12)
	if last_ground - pos.z > MAX_DROP:
		if surface == SURFACE_SPLASH:
			splashed = true
		else:
			wrecked = true
		move = Vector3i.ZERO
		return false
	if into >= -0x5ff:
		return true
	var m := Fixed.matrix((Fixed.short(tilt_x) + climb_x - 0x800) * -2, (-(climb_y - 0x400) - Fixed.short(tilt_y)) * -2, 0)
	var size := maxi(absi(kept.x), maxi(absi(kept.y), absi(kept.z)))
	var scale := 1
	while size > 0x3fff:
		kept = Vector3i(kept.x / 2, kept.y / 2, kept.z / 2)
		scale <<= 1
		size >>= 1
	var out := Fixed.turn(m, kept.y, kept.x, kept.z)
	kept = Vector3i(scale * out.y, -out.x * scale, scale * out.z)
	first_tilt_x = tilt_x
	first_tilt_y = tilt_y
	held_tilt_x = tilt_x
	held_tilt_y = tilt_y
	kept.z = Fixed.shr((0x1000 - absi(climb_x) - absi(climb_y)) * kept.z, 12)
	if kept.z <= 0x3fff:
		return true
	grounded = 0
	move = Vector3i(-left.x if move.x < 0 else left.x, -left.y if move.y < 0 else left.y, -left.z if move.z < 0 else left.z)
	climb_y = climb(move.z, move.y)
	climb_x = climb(move.z, move.x)
	m = Fixed.matrix((Fixed.short(tilt_x) + climb_x - 0x800) * -2, (-(climb_y - 0x400) - Fixed.short(tilt_y)) * -2, 0)
	climb_y += Fixed.short(tilt_y)
	climb_x += Fixed.short(tilt_x)
	size = maxi(absi(move.x), maxi(absi(move.y), absi(move.z)))
	scale = 1
	while size > 0x3fff:
		move = Vector3i(move.x / 2, move.y / 2, move.z / 2)
		scale <<= 1
		size >>= 1
	out = Fixed.turn(m, move.y, move.x, move.z)
	move = Vector3i(scale * out.y, -out.x * scale, scale * out.z)
	move.z = Fixed.shr((0x1000 - absi(climb_x) - absi(climb_y)) * move.z, 12)
	return false
