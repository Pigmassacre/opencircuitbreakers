class_name Fixed
extends RefCounted

# The fixed-point maths of the PS1 library the original is built on: 4096 is
# one, and also a full turn. FUN_0003a330 and the functions it calls are
# written against these, so the port's car update uses them unchanged.

static var quarter := PackedInt32Array()
static var roots := PackedInt32Array()
static var inverse_roots := PackedInt32Array()
# The arctangent steps of FUN_00080918 and FUN_000807f8.
const TURNS := [511, 302, 159, 81, 41, 20, 10, 5, 3, 1, 0, 0]


static func _static_init() -> void:
	quarter.resize(1025)
	for i in 1025:
		quarter[i] = roundi(sin(i * TAU / 4096.0) * 4096.0)
	roots.resize(192)
	inverse_roots.resize(192)
	for i in 192:
		roots[i] = int(sqrt(float(i + 64)) * 512.0)
		inverse_roots[i] = int(32768.0 / sqrt(float(i + 64)))


static func short(v: int) -> int:
	v &= 0xffff
	return v - 0x10000 if v >= 0x8000 else v


# C division by a power of two rounds toward zero.
static func shr(v: int, bits: int) -> int:
	if v < 0:
		v += (1 << bits) - 1
	return v >> bits


static func wave(p: int) -> int:
	if p < 0x401:
		return quarter[p]
	if p < 0x801:
		return quarter[0x800 - p]
	if p < 0xc01:
		return -quarter[p - 0x800]
	return -quarter[0x1000 - p]


# FUN_00080398.
static func rsin(a: int) -> int:
	if a < 0:
		return -wave(-a & 0xfff)
	return wave(a & 0xfff)


# FUN_00080468.
static func rcos(a: int) -> int:
	if a < 0:
		a = -a
	a &= 0xfff
	if a < 0x401:
		return quarter[0x400 - a]
	if a < 0x801:
		return -quarter[a - 0x400]
	if a < 0xc01:
		return -quarter[0xc00 - a]
	return quarter[a - 0xc00]


# FUN_000807f8: the sine of an angle below a quarter turn, by rotation steps.
static func step_sine(a: int) -> int:
	var x := 0x9b7
	var y := 0
	var z := a
	for i in 6:
		var nx := x
		var ny := y
		if z < 0:
			nx = x + (y >> i)
			ny = y - (x >> i)
			z += TURNS[i]
		else:
			nx = x - (y >> i)
			ny = y + (x >> i)
			z -= TURNS[i]
		x = nx
		y = ny
	return y + (z * x >> 12)


# FUN_000806b8.
static func csin(a: int) -> int:
	if a >= 0:
		var u := a & 0xfff
		if u < 0x400:
			return step_sine(u)
		if u < 0x800:
			return step_sine(0x7ff - u)
		if u < 0xc00:
			return -step_sine(u - 0x800)
		return -step_sine(0xfff - u)
	var v := -a & 0xfff
	if v < 0x400:
		return -step_sine(v)
	if v < 0x800:
		return -step_sine(0x7ff - v)
	if v < 0xc00:
		return step_sine(v - 0x800)
	return step_sine(0xfff - v)


# FUN_00080918: the arctangent of a 4096-scaled ratio.
static func atan_ratio(t: int) -> int:
	var x := 0x1000
	var y := t
	var z := 0
	for i in 12:
		var nx := x
		var ny := y
		if y < 0:
			nx = x - (y >> i)
			ny = y + (x >> i)
			z -= TURNS[i]
		else:
			nx = x + (y >> i)
			ny = y - (x >> i)
			z += TURNS[i]
		x = nx
		y = ny
	return z


static func leading_zeros(v: int) -> int:
	if v <= 0:
		return 32 if v == 0 else 0
	var n := 0
	var bit := 0x80000000
	while (v & bit) == 0:
		n += 1
		bit >>= 1
	return n


# FUN_00080a78.
static func root(v: int) -> int:
	var lz := leading_zeros(v)
	if lz == 32:
		return 0
	lz &= ~1
	var m := v >> (24 - lz) if lz < 24 else v << (lz - 24)
	return (roots[m - 0x40] << ((31 - lz) >> 1)) >> 12


# FUN_00080ba8: a vector whose parts are below 0x4000, brought to length 4096.
static func normal(v: Vector3i) -> Vector3i:
	var sum := v.x * v.x + v.y * v.y + v.z * v.z
	if sum <= 0:
		return Vector3i.ZERO
	var lz := leading_zeros(sum) & ~1
	var down := (31 - lz) >> 1
	var m := sum >> (24 - lz) if lz < 24 else sum << (lz - 24)
	var scale := inverse_roots[m - 0x40]
	return Vector3i(scale * v.x >> down, scale * v.y >> down, scale * v.z >> down)


# FUN_00081248: the rotation matrix of three angles, as nine 16-bit numbers.
static func matrix(a: int, b: int, c: int) -> PackedInt32Array:
	a = short(a)
	b = short(b)
	c = short(c)
	var s0 := rsin(a)
	var c0 := rcos(a)
	var s1 := rsin(b)
	var c1 := rcos(b)
	var s2 := rsin(c)
	var c2 := rcos(c)
	var m := PackedInt32Array()
	m.resize(9)
	m[2] = short(s1)
	m[5] = short(-(c1 * s0) >> 12)
	m[8] = short(c1 * c0 >> 12)
	m[0] = short(c2 * c1 >> 12)
	m[1] = short(-(s2 * c1) >> 12)
	var t := c2 * -s1 >> 12
	m[3] = short((s2 * c0 >> 12) - (t * s0 >> 12))
	m[6] = short((s2 * s0 >> 12) + (t * c0 >> 12))
	var u := s2 * -s1 >> 12
	m[4] = short((c2 * c0 >> 12) + (u * s0 >> 12))
	m[7] = short((c2 * s0 >> 12) - (u * c0 >> 12))
	return m


# The matrix times a vector of 16-bit parts, as the GTE gives it.
static func turn(m: PackedInt32Array, x: int, y: int, z: int) -> Vector3i:
	x = short(x)
	y = short(y)
	z = short(z)
	return Vector3i((m[0] * x + m[1] * y + m[2] * z) >> 12, (m[3] * x + m[4] * y + m[5] * z) >> 12, (m[6] * x + m[7] * y + m[8] * z) >> 12)


# Which side of the line from point 0 to point 1 point 2 lies on.
static func side(x0: int, y0: int, x1: int, y1: int, x2: int, y2: int) -> int:
	return x0 * y1 + x1 * y2 + x2 * y0 - x0 * y2 - x1 * y0 - x2 * y1
