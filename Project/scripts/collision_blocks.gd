class_name CollisionBlocks
extends RefCounted

# The original's collision data: the track is a grid of 512-unit cells, and a
# cell holds the faces that FUN_0003f31c and the wall tests look through, split
# over a 4 by 4 grid of 128-unit buckets, triangles apart from quads. A vertex
# is [-y, height running down from the middle of the cell, -x] within its cell.

const UNIT_METRES := 2.4 / 158.0
const FACE := 14
const TILT_X := 4
const TILT_Y := 5
const HEADING := 6
const TURN := 7
const N0 := 8
const N1 := 9
const N2 := 10
const DRIFT := 11
const SURFACE := 12
const WALL := 13


class Block:
	extends RefCounted
	var verts := PackedInt32Array()
	# Per face: four vertices, the x and y tilts, the heading of the fall line,
	# the heading offset, the normal as [y, height, x], the drift, the surface,
	# and the heading as the wall tests take it.
	var faces := PackedInt32Array()
	# The original stores a mirrored cell as its piece plus a mirror bit and
	# turns the point instead of the piece. The faces here are already turned,
	# but a point on a bucket edge has to pick the bucket the original would.
	var mirror_x := false
	var mirror_y := false


	func bucket_x(v: int) -> int:
		if mirror_x:
			return clampi(3 - (mini(0x100 - v, 0x1ff) >> 7), 0, 3)
		return clampi(mini(v + 0x100, 0x1ff) >> 7, 0, 3)


	func bucket_y(v: int) -> int:
		if mirror_y:
			return clampi(3 - (mini(0x100 - v, 0x1ff) >> 7), 0, 3)
		return clampi(mini(v + 0x100, 0x1ff) >> 7, 0, 3)
	var tris: Array[PackedInt32Array] = []
	var quads: Array[PackedInt32Array] = []


var width := 0
var depth := 0
var layers := 0
var layer := 0
var offset_x := 0
var offset_y := 0
var cells: Array[Block] = []


func block_at(cell: int) -> Block:
	if cell < 0 or cell >= cells.size():
		return null
	return cells[cell]


# blocks.bin, the original's own data as the exporter wrote it. The original
# keeps a mirrored cell as the same piece with a mirror bit, and turns the car's
# point and the numbers of the face it finds. Here each piece is turned once
# for every way it is used instead.
static func read(bytes: PackedByteArray) -> CollisionBlocks:
	var out := CollisionBlocks.new()
	out.width = bytes.decode_s32(0)
	out.depth = bytes.decode_s32(4)
	out.layers = bytes.decode_s32(8)
	out.layer = out.width * out.depth
	out.offset_x = (out.width >> 1) * CarSim.CELL
	out.offset_y = (out.depth >> 1) * CarSim.CELL
	var cell_count := out.layer * out.layers
	var at := 12 + cell_count * 2
	var pieces := {}
	var piece_count := bytes.decode_s32(at)
	at += 4
	for n in piece_count:
		var piece := {"id": bytes[at]}
		at += 1
		var vert_count := bytes.decode_s32(at)
		at += 4
		var verts := PackedInt32Array()
		verts.resize(vert_count * 3)
		for i in vert_count * 3:
			verts[i] = bytes.decode_s16(at + i * 2)
		at += vert_count * 6
		var face_count := bytes.decode_s32(at)
		at += 4
		var faces := PackedInt32Array()
		faces.resize(face_count * FACE)
		for i in face_count:
			var f := i * FACE
			for k in 4:
				faces[f + k] = bytes[at + k]
			for k in 8:
				faces[f + 4 + k] = bytes.decode_s16(at + 4 + k * 2)
			faces[f + SURFACE] = bytes[at + 20]
			faces[f + WALL] = faces[f + HEADING]
			at += 21
		var lists: Array[PackedInt32Array] = []
		for i in 32:
			var size := bytes.decode_s32(at)
			at += 4
			var list := PackedInt32Array()
			list.resize(size)
			for k in size:
				list[k] = bytes[at + k]
			at += size
			lists.append(list)
		piece.verts = verts
		piece.faces = faces
		piece.lists = lists
		pieces[piece.id] = piece
	var made := {}
	out.cells.resize(cell_count)
	for i in cell_count:
		var id := bytes[12 + i * 2]
		if id == 0xff or not pieces.has(id):
			continue
		var key := id * 4 + bytes[13 + i * 2]
		if not made.has(key):
			made[key] = turned(pieces[id], bytes[13 + i * 2])
		out.cells[i] = made[key]
	return out


# A piece as it lies in a cell with these mirror bits: bit 0 mirrors x, bit 1 y.
static func turned(piece: Dictionary, flags: int) -> Block:
	var block := Block.new()
	block.mirror_x = (flags & 1) != 0
	block.mirror_y = (flags & 2) != 0
	block.verts = (piece.verts as PackedInt32Array).duplicate()
	block.faces = (piece.faces as PackedInt32Array).duplicate()
	for i in block.verts.size() / 3:
		if block.mirror_y:
			block.verts[i * 3] = -block.verts[i * 3]
		if block.mirror_x:
			block.verts[i * 3 + 2] = -block.verts[i * 3 + 2]
	for i in block.faces.size() / FACE:
		var f := i * FACE
		var heading := block.faces[f + HEADING]
		if block.mirror_x:
			block.faces[f + N2] = -block.faces[f + N2]
			block.faces[f + TILT_X] = -block.faces[f + TILT_X]
			block.faces[f + DRIFT] = 0x800 - block.faces[f + DRIFT]
			block.faces[f + HEADING] = heading - 0x800 if block.mirror_y else 0x800 - heading
		elif block.mirror_y:
			block.faces[f + HEADING] = -heading
		if block.mirror_y:
			block.faces[f + N0] = -block.faces[f + N0]
			block.faces[f + TILT_Y] = -block.faces[f + TILT_Y]
		if block.mirror_x != block.mirror_y:
			block.faces[f + TURN] = -block.faces[f + TURN]
			block.faces[f + WALL] = -heading
	var lists: Array[PackedInt32Array] = piece.lists
	for bx in 4:
		for by in 4:
			var from := (3 - bx if block.mirror_x else bx) * 4 + (3 - by if block.mirror_y else by)
			block.tris.append(lists[from * 2])
			block.quads.append(lists[from * 2 + 1])
	return block


# Blocks from a triangle list: collision.bin, a level the editor compiled, or
# a custom tileset. Positions are nine floats a triangle in the port's metres.
# The exporter writes a quad of the original as two triangles that share an
# edge, [a, b, c] and [b, d, c], and those are joined again here. The numbers
# the original stores with a face are worked out from its plane the way its
# own data follows from it: tilts and headings with the arctangent of
# FUN_00080918, the heading offset as sin(tilt x) * tilt y * cos(tilt y).
static func build(positions: PackedFloat32Array, kinds: PackedByteArray) -> CollisionBlocks:
	var out := CollisionBlocks.new()
	var count := kinds.size()
	var points := PackedInt32Array()
	points.resize(count * 9)
	var low := Vector3i(1 << 30, 1 << 30, 1 << 30)
	var high := -low
	for i in count * 3:
		var x := roundi(positions[i * 3] / UNIT_METRES)
		var h := roundi(positions[i * 3 + 1] / UNIT_METRES)
		var y := roundi(positions[i * 3 + 2] / UNIT_METRES)
		points[i * 3] = x
		points[i * 3 + 1] = y
		points[i * 3 + 2] = h
		low = Vector3i(mini(low.x, x), mini(low.y, y), mini(low.z, h))
		high = Vector3i(maxi(high.x, x), maxi(high.y, y), maxi(high.z, h))
	if count == 0:
		low = Vector3i.ZERO
		high = Vector3i.ZERO
	# The original has solid ground at height 0 under its lowest layer, so the
	# layers only start lower than that when the track itself does.
	var first := Vector3i(floori(low.x / 512.0) - 1, floori(low.y / 512.0) - 1, mini(floori(low.z / 512.0), 0))
	var last := Vector3i(floori(high.x / 512.0) + 1, floori(high.y / 512.0) + 1, floori(high.z / 512.0) + 1)
	out.width = last.x - first.x + 1
	out.depth = last.y - first.y + 1
	out.layers = last.z - first.z + 1
	out.layer = out.width * out.depth
	out.offset_x = -first.x * CarSim.CELL
	out.offset_y = -first.y * CarSim.CELL
	out.offset_z = -first.z * CarSim.CELL
	out.cells.resize(out.layer * out.layers)
	var i := 0
	while i < count:
		var a := Vector3i(points[i * 9], points[i * 9 + 1], points[i * 9 + 2])
		var b := Vector3i(points[i * 9 + 3], points[i * 9 + 4], points[i * 9 + 5])
		var c := Vector3i(points[i * 9 + 6], points[i * 9 + 7], points[i * 9 + 8])
		var d := a
		var quad := false
		if i + 1 < count and kinds[i + 1] == kinds[i]:
			var j := (i + 1) * 9
			if Vector3i(points[j], points[j + 1], points[j + 2]) == b and Vector3i(points[j + 6], points[j + 7], points[j + 8]) == c:
				d = Vector3i(points[j + 3], points[j + 4], points[j + 5])
				var lift := d - a
				var plane := cross(b - a, c - a)
				quad = lift.x * plane.x + lift.y * plane.y + lift.z * plane.z == 0
		out.add_face(a, b, c, d, quad, kinds[i], first)
		i += 2 if quad else 1
	return out


var offset_z := 0


# The heading a normal leans toward, from its y and x parts.
static func level_heading(n0: int, n2: int) -> int:
	if n2 == 0:
		if n0 == 0:
			return 0
		return 0x400 if n0 > 0 else 0xc00
	var heading := 0 if n0 == 0 else Fixed.atan_ratio((n0 << 12) / n2)
	if n2 < 0:
		heading += 0x800
	return heading & 0xfff


static func cross(a: Vector3i, b: Vector3i) -> Vector3i:
	return Vector3i(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)


func add_face(a: Vector3i, b: Vector3i, c: Vector3i, d: Vector3i, quad: bool, kind: int, first: Vector3i) -> void:
	# The original keeps a normal as [y, height, x], and a floor's points up.
	var edge := cross(b - a, c - a)
	var n := Vector3(edge.y, edge.z, edge.x)
	if n == Vector3.ZERO:
		return
	n = n.normalized() * 4096.0
	var n0 := int(n.x)
	var n1 := int(n.y)
	var n2 := int(n.z)
	if n1 < 0:
		n0 = -n0
		n1 = -n1
		n2 = -n2
	var tilt_x := 0
	var tilt_y := 0
	var turn := 0
	var drift := 1023
	if n1 == 0:
		tilt_x = 0 if n2 == 0 else (0x400 if n2 > 0 else 0xc00)
		tilt_y = 0 if n0 == 0 else (0x400 if n0 > 0 else 0xc00)
	else:
		tilt_x = 0 if n2 == 0 else Fixed.atan_ratio((n2 << 12) / n1) & 0xfff
		tilt_y = 0 if n0 == 0 else Fixed.atan_ratio((n0 << 12) / n1) & 0xfff
		var ax := tilt_x - 0x1000 if tilt_x >= 0x800 else tilt_x
		var ay := tilt_y - 0x1000 if tilt_y >= 0x800 else tilt_y
		turn = (absi(Fixed.rsin(ax)) * absi(ay) >> 12) * absi(Fixed.rcos(ay)) >> 12
		drift = Fixed.atan_ratio((int(sqrt(float(n0 * n0 + n2 * n2))) << 12) / n1)
	var heading := level_heading(n0, n2)
	var low := Vector3i(mini(mini(a.x, b.x), c.x), mini(mini(a.y, b.y), c.y), mini(mini(a.z, b.z), c.z))
	var high := Vector3i(maxi(maxi(a.x, b.x), c.x), maxi(maxi(a.y, b.y), c.y), maxi(maxi(a.z, b.z), c.z))
	if quad:
		low = Vector3i(mini(low.x, d.x), mini(low.y, d.y), mini(low.z, d.z))
		high = Vector3i(maxi(high.x, d.x), maxi(high.y, d.y), maxi(high.z, d.z))
	var corners: Array[Vector3i] = [a, b, c, d]
	for cz in range(span_first(low.z, high.z, 512), span_last(low.z, high.z, 512) + 1):
		for cy in range(span_first(low.y, high.y, 512), span_last(low.y, high.y, 512) + 1):
			for cx in range(span_first(low.x, high.x, 512), span_last(low.x, high.x, 512) + 1):
				var at := (cx - first.x) + (cy - first.y) * width + (cz - first.z) * layer
				var block := cells[at]
				if block == null:
					block = Block.new()
					for k in 16:
						block.tris.append(PackedInt32Array())
						block.quads.append(PackedInt32Array())
					cells[at] = block
				var centre := Vector3i(cx * 512 + 256, cy * 512 + 256, cz * 512 + 256)
				var index := block.faces.size() / FACE
				var base := block.verts.size() / 3
				for corner in corners:
					block.verts.append(centre.y - corner.y)
					block.verts.append(centre.z - corner.z)
					block.verts.append(centre.x - corner.x)
				block.faces.append_array(PackedInt32Array([base, base + 1, base + 2, base + 3, tilt_x, tilt_y, heading, turn, n0, n1, n2, drift, kind, heading]))
				var from := Vector3i(low.x - centre.x + 256, low.y - centre.y + 256, 0)
				var to := Vector3i(high.x - centre.x + 256, high.y - centre.y + 256, 0)
				for bx in range(maxi(span_first(from.x, to.x, 128), 0), mini(span_last(from.x, to.x, 128), 3) + 1):
					for by in range(maxi(span_first(from.y, to.y, 128), 0), mini(span_last(from.y, to.y, 128), 3) + 1):
						if quad:
							block.quads[bx * 4 + by].append(index)
						else:
							block.tris[bx * 4 + by].append(index)


# The cells of this size a span reaches into. A span that only touches a cell
# edge is not in that cell, but one that lies on the edge is in both.
static func span_first(low: int, high: int, size: int) -> int:
	var cell := floori(float(low) / size)
	if low == high and low % size == 0:
		return cell - 1
	return cell


static func span_last(low: int, high: int, size: int) -> int:
	if high % size == 0 and low != high:
		return floori(float(high) / size) - 1
	return floori(float(high) / size)
