extends SceneTree

const UNIT := 2.4 / 158.0
const SCALE := 512.0 * UNIT
const UP_CELL := 0.35
const ATLAS_GUTTER := 2

static var maps := {}


func _init() -> void:
	var err := bake_cli()
	if err != "":
		print(err)
		quit(1)
		return
	quit()


static func bake_cli() -> String:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		var root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("CustomTilesets")
		return bake_folder(root, ProjectSettings.globalize_path("res://tilesets"))
	var src := String(args[0])
	var out := ""
	if args.size() >= 2:
		out = String(args[1])
	else:
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src.path_join("tileset.json")))
		var id := String(spec.id) if spec.has("id") else src.get_file()
		out = ProjectSettings.globalize_path("res://tilesets").path_join(id)
	return bake(src, out)


static func bake_folder(root: String, dest: String) -> String:
	if not DirAccess.dir_exists_absolute(root):
		return "Missing " + root
	var names := DirAccess.get_directories_at(root)
	var baked := 0
	for name in names:
		var src := root.path_join(String(name))
		if not FileAccess.file_exists(src.path_join("tileset.json")):
			continue
		var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src.path_join("tileset.json")))
		if not spec.has("models"):
			continue
		var id := String(spec.id) if spec.has("id") else String(name)
		var message := bake(src, dest.path_join(id))
		if message != "":
			return message
		baked += 1
	if baked == 0:
		return "No tileset sources in " + root
	return ""


static func bake(src: String, out: String) -> String:
	var manifest := src.path_join("tileset.json")
	if not FileAccess.file_exists(manifest):
		return "Missing " + manifest
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var models: Array = spec.models
	DirAccess.make_dir_recursive_absolute(out)
	var meshes: Array = []
	var tiles: Array = []
	var megas := 0
	for raw in models:
		var entry: Dictionary = raw
		var file_name := String(entry.file)
		var stem := file_name.get_file().get_basename()
		var loaded := load_obj(src.path_join(file_name))
		var tris: Array = loaded.tris
		if tris.is_empty():
			return "No triangles in " + file_name
		if entry.has("offset"):
			var off: Array = entry.offset
			shift(tris, Vector3(float(off[0]), float(off[1]), float(off[2])))
		var split := bool(entry.cells) if entry.has("cells") else false
		var deck := bool(entry.deck) if entry.has("deck") else false
		var piece_cells: Array = slice_model(tris, split, deck)
		if piece_cells.is_empty():
			return "No cells in " + file_name
		var color: Array = loaded.color
		var first := meshes.size()
		for cell in piece_cells:
			meshes.append(cell.tris)
		var tile := {
			"name": String(entry.name) if entry.has("name") else pretty(stem),
			"group": int(entry.group) if entry.has("group") else group_of(stem),
			"color": [int(color[0]), int(color[1]), int(color[2])],
		}
		if piece_cells.size() == 1:
			tile.mesh = first
		else:
			var listed: Array = []
			for i in piece_cells.size():
				var cell: Dictionary = piece_cells[i]
				listed.append({"dx": int(cell.dx), "dz": int(cell.dz), "mesh": first + i})
			tile.cells = listed
			megas += 1
			print("%s  %d cells" % [tile.name, piece_cells.size()])
		tiles.append(tile)
	var atlas := build_atlas(meshes)
	var atlas_image: Image = atlas.image
	if atlas_image.save_png(out.path_join("atlas.png")) != OK:
		return "Could not write atlas"
	var cutout: Dictionary = atlas.cutout
	var bin := BinWriter.new()
	bin.i32(meshes.size())
	for mesh_entry in meshes:
		var baked: Array = mesh_entry
		var single: Array = []
		var double: Array = []
		for tri in baked:
			if cutout[tri[6]]:
				double.append(tri)
			else:
				single.append(tri)
		write_surface(bin, single, atlas)
		write_surface(bin, double, atlas)
		bin.i32(baked.size())
		for tri in baked:
			var corners: Array = tri
			for n in 3:
				var p: Vector3 = corners[n]
				bin.f32(p.x)
				bin.f32(p.y)
				bin.f32(p.z)
		for _i in baked.size():
			bin.u8(0)
	var bytes := bin.bytes()
	var file := FileAccess.open(out.path_join("pieces.bin"), FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var info := {
		"id": String(spec.id),
		"name": String(spec.name),
		"layer": int(spec.layer),
		"tiles": tiles,
	}
	if spec.has("ground"):
		var channels: Array = spec.ground
		info.ground = [int(channels[0]), int(channels[1]), int(channels[2])]
	if spec.has("stack"):
		info.stack = bool(spec.stack)
	if spec.has("grid"):
		info.grid = int(spec.grid)
	var json := FileAccess.open(out.path_join("tileset.json"), FileAccess.WRITE)
	json.store_string(JSON.stringify(info, "\t"))
	json.close()
	if not readback(bytes, meshes.size()):
		return "pieces.bin did not round-trip"
	print("%s tiles %d  meshes %d  megas %d" % [info.id, tiles.size(), meshes.size(), megas])
	return ""


static func shift(tris: Array, delta: Vector3) -> void:
	for raw in tris:
		var tri: Dictionary = raw
		var a: Vector3 = tri.a
		var b: Vector3 = tri.b
		var c: Vector3 = tri.c
		if delta.x != 0.0:
			a.x += delta.x
			b.x += delta.x
			c.x += delta.x
		if delta.y != 0.0:
			a.y += delta.y
			b.y += delta.y
			c.y += delta.y
		if delta.z != 0.0:
			a.z += delta.z
			b.z += delta.z
			c.z += delta.z
		tri.a = a
		tri.b = b
		tri.c = c


static func slice_model(tris: Array, split: bool, deck: bool) -> Array:
	if not split:
		return [{"dx": 0, "dz": 0, "tris": prop_tris(tris)}]
	var buckets := {}
	for raw in tris:
		var tri: Dictionary = raw
		var a: Vector3 = tri.a
		var b: Vector3 = tri.b
		var c: Vector3 = tri.c
		var normal := (b - a).cross(c - a)
		var span := normal.length()
		if span < 1.0e-8:
			continue
		var up := normal.y > 0.7 * span
		var i0 := int(floor(-maxf(a.x, maxf(b.x, c.x)) - 1.0e-4))
		var i1 := int(floor(-minf(a.x, minf(b.x, c.x)) + 1.0e-4))
		var j0 := int(floor(minf(a.z, minf(b.z, c.z)) - 1.0e-4))
		var j1 := int(floor(maxf(a.z, maxf(b.z, c.z)) + 1.0e-4))
		for i in range(i0, i1 + 1):
			for j in range(j0, j1 + 1):
				var poly := clip_cell([a, b, c], i, j)
				if poly.size() < 3:
					continue
				var mid := centroid(poly)
				if int(floor(-mid.x + 1.0e-4)) != i or int(floor(mid.z + 1.0e-4)) != j:
					continue
				var bucket: Dictionary = take_bucket(buckets, i, j)
				var lifted: float = bucket.up
				var area: float = bucket.area
				var stored: Array = bucket.tris
				for k in range(1, poly.size() - 1):
					var p0: Vector3 = poly[0]
					var p1: Vector3 = poly[k]
					var p2: Vector3 = poly[k + 1]
					var face := (p1 - p0).cross(p2 - p0)
					var face_span := face.length()
					if face_span < 1.0e-8:
						continue
					stored.append({"a": p0, "b": p1, "c": p2, "ua": blend(tri, p0), "ub": blend(tri, p1), "uc": blend(tri, p2), "map": tri.map, "color": tri.color})
					area += face_span * 0.5
					if up:
						lifted += absf(face.y) * 0.5
				bucket.up = lifted
				bucket.area = area
				bucket.tris = stored
	if buckets.is_empty():
		return []
	var keys: Array = buckets.keys()
	var footprint: Array = []
	for key in keys:
		var bucket: Dictionary = buckets[key]
		if float(bucket.up) >= UP_CELL or (not deck and float(bucket.area) >= 0.25):
			footprint.append(key)
	if footprint.is_empty():
		var best: Vector2i = keys[0]
		var best_area := -1.0
		for key in keys:
			var bucket: Dictionary = buckets[key]
			if float(bucket.area) > best_area:
				best_area = float(bucket.area)
				best = key
		footprint.append(best)
	var owned := {}
	for key in footprint:
		owned[key] = true
	for key in keys:
		if owned.has(key):
			continue
		var bucket: Dictionary = buckets[key]
		var nearest: Vector2i = footprint[0]
		var nearest_d := 1.0e20
		for home in footprint:
			var d := Vector2(float(key.x - home.x), float(key.y - home.y)).length_squared()
			if d < nearest_d:
				nearest_d = d
				nearest = home
		var host: Dictionary = buckets[nearest]
		var host_tris: Array = host.tris
		host_tris.append_array(bucket.tris)
		host.tris = host_tris
	footprint.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	var anchor: Vector2i = footprint[0]
	var cells: Array = []
	for key in footprint:
		var at: Vector2i = key
		var bucket: Dictionary = buckets[at]
		var local: Array = bake_cell(bucket.tris, at.x, at.y)
		if local.is_empty():
			continue
		cells.append({
			"dx": anchor.x - at.x,
			"dz": at.y - anchor.y,
			"tris": local,
		})
	if cells.is_empty():
		return cells
	var origin: Dictionary = cells[0]
	for cell in cells:
		var item: Dictionary = cell
		item.dx = int(item.dx) - int(origin.dx)
		item.dz = int(item.dz) - int(origin.dz)
	origin.dx = 0
	origin.dz = 0
	return cells


static func prop_tris(tris: Array) -> Array:
	var min_x := 1.0e20
	var max_x := -1.0e20
	var min_y := 1.0e20
	var min_z := 1.0e20
	var max_z := -1.0e20
	for raw in tris:
		var tri: Dictionary = raw
		for point in [tri.a, tri.b, tri.c]:
			var p: Vector3 = point
			min_x = minf(min_x, p.x)
			max_x = maxf(max_x, p.x)
			min_y = minf(min_y, p.y)
			min_z = minf(min_z, p.z)
			max_z = maxf(max_z, p.z)
	var cx := (min_x + max_x) * 0.5
	var cz := (min_z + max_z) * 0.5
	var baked: Array = []
	for raw in tris:
		var tri: Dictionary = raw
		var corners: Array = []
		for point in [tri.a, tri.b, tri.c]:
			var p: Vector3 = point
			corners.append(Vector3((p.x - cx) * SCALE, (p.y - min_y) * SCALE, (p.z - cz) * SCALE))
		push_tri(baked, corners, tri)
	return baked


static func bake_cell(tris: Array, i: int, j: int) -> Array:
	var baked: Array = []
	for raw in tris:
		var tri: Dictionary = raw
		var corners: Array = []
		for point in [tri.a, tri.b, tri.c]:
			var p: Vector3 = point
			corners.append(Vector3((p.x + float(i) + 0.5) * SCALE, p.y * SCALE, (p.z - float(j) - 0.5) * SCALE))
		push_tri(baked, corners, tri)
	return baked


static func push_tri(baked: Array, corners: Array, tri: Dictionary) -> void:
	var a: Vector3 = corners[0]
	var b: Vector3 = corners[1]
	var c: Vector3 = corners[2]
	var normal := (b - a).cross(c - a)
	if normal.length() < 1.0e-10:
		return
	normal = normal.normalized()
	baked.append([a, c, b, normal, tri.color, [tri.ua, tri.uc, tri.ub], tri.map])


static func blend(tri: Dictionary, p: Vector3) -> Vector2:
	var ua: Vector2 = tri.ua
	var ub: Vector2 = tri.ub
	var uc: Vector2 = tri.uc
	if ua == ub and ub == uc:
		return ua
	var a: Vector3 = tri.a
	var e0: Vector3 = tri.b - a
	var e1: Vector3 = tri.c - a
	var e2 := p - a
	var d00 := e0.dot(e0)
	var d01 := e0.dot(e1)
	var d11 := e1.dot(e1)
	var d20 := e2.dot(e0)
	var d21 := e2.dot(e1)
	var denom := d00 * d11 - d01 * d01
	var v := (d11 * d20 - d01 * d21) / denom
	var w := (d00 * d21 - d01 * d20) / denom
	return ua * (1.0 - v - w) + ub * v + uc * w


static func take_bucket(buckets: Dictionary, i: int, j: int) -> Dictionary:
	var key := Vector2i(i, j)
	if not buckets.has(key):
		buckets[key] = {"tris": [], "up": 0.0, "area": 0.0}
	return buckets[key]


static func centroid(poly: Array) -> Vector3:
	var sum := Vector3.ZERO
	for point in poly:
		sum += point
	return sum / float(poly.size())


static func clip_cell(poly: Array, i: int, j: int) -> Array:
	var clipped := clip_axis(poly, 0, -float(i + 1), true)
	clipped = clip_axis(clipped, 0, -float(i), false)
	clipped = clip_axis(clipped, 2, float(j), true)
	return clip_axis(clipped, 2, float(j + 1), false)


static func clip_axis(poly: Array, axis: int, limit: float, keep_above: bool) -> Array:
	var out: Array = []
	if poly.is_empty():
		return out
	var prev: Vector3 = poly[poly.size() - 1]
	var prev_in := inside(prev, axis, limit, keep_above)
	for point in poly:
		var curr: Vector3 = point
		var curr_in := inside(curr, axis, limit, keep_above)
		if curr_in:
			if not prev_in:
				out.append(split(prev, curr, axis, limit))
			out.append(curr)
		elif prev_in:
			out.append(split(prev, curr, axis, limit))
		prev = curr
		prev_in = curr_in
	return out


static func inside(point: Vector3, axis: int, limit: float, keep_above: bool) -> bool:
	var value := point.x if axis == 0 else point.z
	if keep_above:
		return value >= limit - 1.0e-5
	return value <= limit + 1.0e-5


static func split(a: Vector3, b: Vector3, axis: int, limit: float) -> Vector3:
	var av := a.x if axis == 0 else a.z
	var bv := b.x if axis == 0 else b.z
	var span := bv - av
	var t := 0.0 if absf(span) < 1.0e-8 else (limit - av) / span
	return a.lerp(b, clampf(t, 0.0, 1.0))


static func load_obj(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var mats := {}
	var lines := text.split("\n")
	for raw_line in lines:
		var line := String(raw_line).strip_edges()
		if line.begins_with("mtllib "):
			mats = load_mtl(path.get_base_dir().path_join(line.substr(7).strip_edges()))
	var verts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	var tris: Array = []
	var color := Color(0.5, 0.5, 0.5)
	var map := ""
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	var weight := 0.0
	for raw_line in lines:
		var line := String(raw_line).strip_edges()
		var bits := line.split(" ", false)
		if bits.is_empty():
			continue
		if bits[0] == "v" and bits.size() >= 4:
			verts.append(Vector3(float(bits[1]), float(bits[2]), float(bits[3])))
		elif bits[0] == "vt" and bits.size() >= 3:
			uvs.append(Vector2(float(bits[1]), float(bits[2])))
		elif bits[0] == "usemtl" and bits.size() >= 2:
			if mats.has(bits[1]):
				var mat: Dictionary = mats[bits[1]]
				color = mat.kd
				map = mat.map
		elif bits[0] == "f" and bits.size() >= 4:
			var ids: Array[int] = []
			var tex: Array[Vector2] = []
			for n in range(1, bits.size()):
				var token := String(bits[n]).split("/")
				ids.append(obj_index(int(token[0]), verts.size()))
				if map != "" and token.size() >= 2 and token[1] != "":
					tex.append(uvs[obj_index(int(token[1]), uvs.size())])
				else:
					tex.append(Vector2.ZERO)
			for n in range(1, ids.size() - 1):
				var a: Vector3 = verts[ids[0]]
				var b: Vector3 = verts[ids[n]]
				var c: Vector3 = verts[ids[n + 1]]
				if (b - a).cross(c - a).length() * 0.5 < 1.0e-8:
					continue
				for piece in split_uv(a, b, c, tex[0], tex[n], tex[n + 1]):
					var part: Dictionary = piece
					part.map = map
					part.color = color
					tris.append(part)
					var pa: Vector3 = part.a
					var pb: Vector3 = part.b
					var pc: Vector3 = part.c
					var area := (pb - pa).cross(pc - pa).length() * 0.5
					var tint := color
					if map != "":
						tint = color * sample(maps[map], (part.ua + part.ub + part.uc) / 3.0)
					red += tint.r * area
					green += tint.g * area
					blue += tint.b * area
					weight += area
	var rgb := [128, 128, 128]
	if weight > 0.0:
		rgb = [int(round(red / weight * 255.0)), int(round(green / weight * 255.0)), int(round(blue / weight * 255.0))]
	return {"tris": tris, "color": rgb}


static func obj_index(id: int, count: int) -> int:
	return count + id if id < 0 else id - 1


static func sample(map: Image, uv: Vector2) -> Color:
	var x := clampi(int(uv.x * map.get_width()), 0, map.get_width() - 1)
	var y := clampi(int((1.0 - uv.y) * map.get_height()), 0, map.get_height() - 1)
	var texel := map.get_pixel(x, y)
	texel.a = 1.0
	return texel


static func split_uv(a: Vector3, b: Vector3, c: Vector3, ta: Vector2, tb: Vector2, tc: Vector2) -> Array:
	var cu := Vector3(ta.x, tb.x, tc.x)
	var cv := Vector3(ta.y, tb.y, tc.y)
	var u0 := int(floor(minf(cu.x, minf(cu.y, cu.z)) + 1.0e-5))
	var u1 := maxi(u0, int(floor(maxf(cu.x, maxf(cu.y, cu.z)) - 1.0e-5)))
	var v0 := int(floor(minf(cv.x, minf(cv.y, cv.z)) + 1.0e-5))
	var v1 := maxi(v0, int(floor(maxf(cv.x, maxf(cv.y, cv.z)) - 1.0e-5)))
	var tile := Vector2(float(u0), float(v0))
	if u0 == u1 and v0 == v1:
		return [{"a": a, "b": b, "c": c, "ua": ta - tile, "ub": tb - tile, "uc": tc - tile}]
	var pieces: Array = []
	var whole := [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)]
	for i in range(u0, u1 + 1):
		var column := clip_linear(clip_linear(whole, cu, float(i), true), cu, float(i + 1), false)
		for j in range(v0, v1 + 1):
			var poly := clip_linear(clip_linear(column, cv, float(j), true), cv, float(j + 1), false)
			var corners: Array = []
			for raw in poly:
				var w: Vector3 = raw
				corners.append([a * w.x + b * w.y + c * w.z, Vector2(cu.dot(w) - float(i), cv.dot(w) - float(j))])
			for k in range(1, corners.size() - 1):
				var p0: Array = corners[0]
				var p1: Array = corners[k]
				var p2: Array = corners[k + 1]
				var pa: Vector3 = p0[0]
				var pb: Vector3 = p1[0]
				var pc: Vector3 = p2[0]
				if (pb - pa).cross(pc - pa).length() < 1.0e-10:
					continue
				pieces.append({"a": pa, "b": pb, "c": pc, "ua": p0[1], "ub": p1[1], "uc": p2[1]})
	return pieces


static func clip_linear(poly: Array, coeff: Vector3, limit: float, keep_above: bool) -> Array:
	var out: Array = []
	if poly.is_empty():
		return out
	var prev: Vector3 = poly[poly.size() - 1]
	var prev_value := prev.dot(coeff)
	for point in poly:
		var curr: Vector3 = point
		var value := curr.dot(coeff)
		var curr_in := value >= limit - 1.0e-6 if keep_above else value <= limit + 1.0e-6
		var prev_in := prev_value >= limit - 1.0e-6 if keep_above else prev_value <= limit + 1.0e-6
		if curr_in != prev_in:
			out.append(prev.lerp(curr, clampf((limit - prev_value) / (value - prev_value), 0.0, 1.0)))
		if curr_in:
			out.append(curr)
		prev = curr
		prev_value = value
	return out


static func load_mtl(path: String) -> Dictionary:
	var mats := {}
	if not FileAccess.file_exists(path):
		return mats
	var name := ""
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := String(raw_line).strip_edges()
		var bits := line.split(" ", false)
		if bits.is_empty():
			continue
		if bits[0] == "newmtl" and bits.size() >= 2:
			name = bits[1]
			mats[name] = {"kd": Color(1, 1, 1), "map": ""}
		elif bits[0] == "Kd" and bits.size() >= 4 and name != "":
			mats[name].kd = Color(float(bits[1]), float(bits[2]), float(bits[3]))
		elif bits[0] == "map_Kd" and bits.size() >= 2 and name != "":
			var map_path := path.get_base_dir().path_join(line.substr(6).strip_edges()).simplify_path()
			if not maps.has(map_path):
				var image := Image.load_from_file(map_path)
				image.convert(Image.FORMAT_RGBA8)
				maps[map_path] = image
			mats[name].map = map_path
	return mats


static func pretty(stem: String) -> String:
	var text := stem
	if text.begins_with("road"):
		text = text.substr(4)
	if text.ends_with("_exclusive"):
		text = text.substr(0, text.length() - 10)
	var spaced := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		var code := ch.unicode_at(0)
		if ch == "_" or ch == "-":
			spaced += " "
		elif i > 0 and code >= 65 and code <= 90:
			spaced += " " + ch
		else:
			spaced += ch
	var words: Array = []
	for word in spaced.split(" ", false):
		words.append(word.substr(0, 1).to_upper() + word.substr(1))
	if words.is_empty():
		return stem
	return " ".join(words)


static func group_of(stem: String) -> int:
	var text := stem.to_lower()
	if text.contains("ramp") or text.contains("bump"):
		return 2
	if text.contains("wall") or text.contains("border") or text.contains("sand") or text.contains("fence") or text.contains("barrier") or text.contains("rail"):
		return 3
	if text.contains("corner") or text.contains("curved") or text.contains("split") or text.contains("crossing") or text.contains("skew"):
		return 1
	if text.begins_with("road") or text == "grass":
		return 0
	return 4


static func build_atlas(meshes: Array) -> Dictionary:
	var white := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	white.fill(Color.WHITE)
	var sources := {"": white}
	for mesh_entry in meshes:
		for tri in mesh_entry:
			var path: String = tri[6]
			if not sources.has(path):
				sources[path] = maps[path]
	var order: Array = sources.keys()
	order.sort_custom(func(x: String, y: String) -> bool:
		var hx: int = sources[x].get_height()
		var hy: int = sources[y].get_height()
		return hx > hy if hx != hy else x < y
	)
	var area := 0
	var widest := 0
	for path in order:
		var src: Image = sources[path]
		area += (src.get_width() + ATLAS_GUTTER * 2) * (src.get_height() + ATLAS_GUTTER * 2)
		widest = maxi(widest, src.get_width() + ATLAS_GUTTER * 2)
	var width := maxi(widest, int(ceil(sqrt(float(area)))))
	var places := {}
	var x := 0
	var y := 0
	var shelf := 0
	for path in order:
		var src: Image = sources[path]
		var w := src.get_width() + ATLAS_GUTTER * 2
		var h := src.get_height() + ATLAS_GUTTER * 2
		if x + w > width:
			x = 0
			y += shelf
			shelf = 0
		places[path] = Vector2i(x + ATLAS_GUTTER, y + ATLAS_GUTTER)
		x += w
		shelf = maxi(shelf, h)
	var image := Image.create(width, y + shelf, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rects := {}
	var cutout := {}
	for path in order:
		var src: Image = sources[path]
		var at: Vector2i = places[path]
		var w := src.get_width()
		var h := src.get_height()
		image.blit_rect(src, Rect2i(0, 0, w, h), at)
		for gy in range(-ATLAS_GUTTER, h + ATLAS_GUTTER):
			for gx in range(-ATLAS_GUTTER, w + ATLAS_GUTTER):
				if gx >= 0 and gx < w and gy >= 0 and gy < h:
					continue
				image.set_pixel(at.x + gx, at.y + gy, src.get_pixel(posmod(gx, w), posmod(gy, h)))
		rects[path] = Rect2(Vector2(at), Vector2(w, h))
		cutout[path] = src.detect_alpha() != Image.ALPHA_NONE
	return {"image": image, "rects": rects, "cutout": cutout, "size": Vector2(image.get_size())}


static func write_surface(bin: BinWriter, tris: Array, atlas: Dictionary) -> void:
	var size: Vector2 = atlas.size
	var rects: Dictionary = atlas.rects
	bin.i32(tris.size() * 3)
	for tri in tris:
		var corners: Array = tri
		var normal: Vector3 = corners[3]
		var color: Color = corners[4]
		var local: Array = corners[5]
		var path: String = corners[6]
		var rect: Rect2 = rects[path]
		for n in 3:
			var point: Vector3 = corners[n]
			var uv: Vector2 = local[n]
			if path == "":
				uv = Vector2(0.5, 0.5)
			bin.vertex(point, normal, color, (rect.position + Vector2(uv.x, 1.0 - uv.y) * rect.size) / size)


static func readback(bytes: PackedByteArray, count: int) -> bool:
	if bytes.size() < 4 or bytes.decode_u32(0) != count:
		return false
	var offset := 4
	for _i in count:
		for _side in 2:
			if offset + 4 > bytes.size():
				return false
			var verts := bytes.decode_u32(offset)
			offset += 4 + int(verts) * 48
		if offset + 4 > bytes.size():
			return false
		var tris := bytes.decode_u32(offset)
		offset += 4 + int(tris) * 36 + int(tris)
	return offset == bytes.size()


class BinWriter:
	var peer := StreamPeerBuffer.new()

	func _init() -> void:
		peer.big_endian = false

	func i32(value: int) -> void:
		peer.put_32(value)

	func f32(value: float) -> void:
		peer.put_float(value)

	func u8(value: int) -> void:
		peer.put_u8(value)

	func vertex(point: Vector3, normal: Vector3, color: Color, uv: Vector2) -> void:
		f32(point.x)
		f32(point.y)
		f32(point.z)
		f32(normal.x)
		f32(normal.y)
		f32(normal.z)
		f32(color.r)
		f32(color.g)
		f32(color.b)
		f32(color.a)
		f32(uv.x)
		f32(uv.y)

	func bytes() -> PackedByteArray:
		return peer.data_array.slice(0, peer.get_size())
