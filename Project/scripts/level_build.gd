class_name LevelBuild
extends RefCounted

# Placed tiles compiled into the track the race already loads: a closed loop of
# nodes, a floor/wall collision mesh, and the original per-node camera bytes.
# Gate search only hits a node within 64 units along the road, so each cell is
# split into enough nodes that a car is always inside that band.

const CELL_U := 512
const LAYER_U := 192
const NODES := 9
const NODE_MIN := 48
const NODE_MAX := 512
const NODE_CLOSE := 96
const GATE_HALF := 416.0
const AI_TURN := 24
const AI_THRESHOLD := 50
const AI_CLASSES := 40
const AI_SPEED_STEP := 100
const AI_SPEED_LOW := 800
const AI_SPEED_TOP := 3900
const AI_SPEED_SCALE := 94.0
const AI_START := [50, 100]
const PICKUP_LIMIT := 12
const PICKUP_TYPES := [Items.SHRINK, Items.GROW, Items.ROCKET, Items.REPULSOR, Items.OIL, Items.CLOUD, Items.BOMB, Items.GLUE, Items.SHOT, Items.STILTS, Items.BOUNCE]
const PICKUP_NAMES := {Items.SHRINK: "Shrink", Items.GROW: "Grow", Items.ROCKET: "Rocket", Items.REPULSOR: "Repulsor", Items.OIL: "Oil", Items.CLOUD: "Cloud", Items.BOMB: "Bomb", Items.GLUE: "Glue", Items.SHOT: "Shot", Items.STILTS: "Stilts", Items.BOUNCE: "Bounce"}
const LANE_NAMES := ["Centre", "Left", "Right", "Far left", "Far right"]
const EVERY_LAP := 4
const DIR := "user://custom_levels"
const ACTIVE := "user://custom_levels/active.json"
const TilesetBake = preload("res://scripts/tileset_bake.gd")
enum Piece { FLOOR, WALL, RAMP, START, SCENERY }

const PIECE_NAMES := ["Road", "Wall", "Ramp", "Start"]
const VEHICLE_NAMES := ["Car", "Boat", "Submarine"]
const VEHICLE_DIR := ["editor", "venice", "aqua"]
const VEHICLE_HANDLING := ["Wild West", "Swamp / Venice", "Aqua"]
const FORWARD := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const HEADING := [0, 3072, 2048, 1024]
const CAM_NORMAL := 7
const CAM_TIGHT := 0xfd
const CAM_EDGE := 0xfe
const FACING := ["-Z", "+X", "+Z", "-X"]

const FLOOR_COLOR := Color(0.84, 0.85, 0.88)
const RIM_COLOR := Color(0.22, 0.22, 0.26)
const WALL_COLOR := Color(0.34, 0.34, 0.38)
const RAMP_UP_COLOR := Color(0.74, 0.58, 0.42)
const RAMP_DOWN_COLOR := Color(0.46, 0.56, 0.72)
const START_COLOR := Color(0.42, 0.7, 0.4)
const STRIPE_COLOR := Color(0.95, 0.88, 0.25)
const ARROW_COLOR := Color(0.12, 0.12, 0.14)
const OFF_LOOP_COLOR := Color(0.72, 0.28, 0.26)
const CAMERA_COLOR := Color(0.95, 0.78, 0.22)
const LAP_ON_TINT := Color(0.0, 1.0, 0.08)
const LAP_OFF_TINT := Color(0.08, 0.22, 1.0)


static func blank() -> Dictionary:
	return {"name": "untitled", "vehicle": 0, "ai": false, "tileset": default_tileset(), "parts": [], "road": [], "line": [], "joined": false, "broken": false, "gaps": []}


static func key_of(x: int, y: int, z: int) -> String:
	return "%d,%d,%d" % [x, y, z]


static func key_part(part: Dictionary) -> String:
	return key_of(int(part.x), int(part.y), int(part.z))


static func is_road(piece: int) -> bool:
	return piece == Piece.FLOOR or piece == Piece.RAMP or piece == Piece.START


static func facing_name(rot: int) -> String:
	return FACING[rot & 3]


static func yaw_byte(heading: int) -> int:
	return ((0xc00 + heading) & 0xfff) >> 7


static func pitch_byte(step: int) -> int:
	if step >= 0:
		return step
	return 0x80 - step


static func pitch_step(byte: int) -> int:
	if byte < 0x80:
		return byte
	return -(byte - 0x80)


static func cam_type_name(type: int) -> String:
	if type == CAM_EDGE:
		return "Edge"
	if type == CAM_TIGHT:
		return "Tight"
	return "Normal"


static func camera_metres(type: int, distance_byte: int) -> float:
	var distance := distance_byte << 4
	if type < CAM_TIGHT:
		distance = maxi(distance, TrackCamera.MIN_DISTANCE)
	return float(distance - TrackCamera.DISTANCE_OFFSET) * Car.UNIT_METRES


static func flat_axes(rot: int) -> Array[Vector2]:
	var h: float = float(HEADING[rot & 3]) * Car.ANGLE_TO_RAD
	var axes: Array[Vector2] = [Vector2(-sin(h), -cos(h)), Vector2(cos(h), -sin(h))]
	return axes


static func step_rot(dx: int, dz: int) -> int:
	if dx == 1:
		return 1
	if dz == 1:
		return 2
	if dx == -1:
		return 3
	return 0


static func metres(units: float) -> float:
	return units * Car.UNIT_METRES


static func cell_center(x: int, z: int) -> Vector3:
	return Vector3(metres(x * CELL_U), 0.0, metres(z * CELL_U))


static func part_off(part: Dictionary) -> Vector2i:
	var ox := int(part.ox) if part.has("ox") else 0
	var oz := int(part.oz) if part.has("oz") else 0
	return Vector2i(ox, oz)


static func part_nudge(part: Dictionary) -> Vector3:
	var off := part_off(part)
	return Vector3(metres(float(off.x)), 0.0, metres(float(off.y)))


static func part_oy(part: Dictionary) -> int:
	return int(part.oy) if part.has("oy") else 0


static func part_lift(part: Dictionary) -> float:
	return metres(float(part_oy(part)))


static func layer_height(layer: int) -> float:
	return metres(layer * LAYER_U)


static var packed_tileset := ""
static var packed_info := {}
static var packed_meshes: Array = []
static var preview_meshes := {}
static var extra_dirs := {}
static var bake_failed := {}


static func on_lap(part: Dictionary) -> bool:
	if int(part.piece) == Piece.SCENERY:
		return int(part.lap) != 0
	return is_road(int(part.piece))


static func tile_row(tile_name: String, piece: int, rot: int, slope: int, role: String, mesh: int) -> Dictionary:
	return {"name": tile_name, "piece": piece, "rot": rot, "slope": slope, "role": role, "mesh": mesh}


static func marker_tiles() -> Array:
	var tiles: Array = []
	for rot in 4:
		tiles.append(tile_row("Start %s" % FACING[rot], Piece.START, rot, 0, "start", -1))
	return tiles


static func player_tileset_root() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("tilesets")
	return OS.get_executable_path().get_base_dir().path_join("tilesets")


static func ensure_extra_tilesets() -> void:
	extra_dirs = {}
	var root := player_tileset_root()
	if not DirAccess.dir_exists_absolute(root):
		return
	for name in DirAccess.get_directories_at(root):
		var src := root.path_join(String(name))
		var manifest := src.path_join("tileset.json")
		if not FileAccess.file_exists(manifest):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var spec: Dictionary = parsed
		if not spec.has("models"):
			continue
		var id := String(spec.id) if spec.has("id") else String(name)
		if Session.WORLDS.has(id) or FileAccess.file_exists("res://tilesets/%s/tileset.json" % id):
			if not bake_failed.has(id):
				bake_failed[id] = true
				print("Tileset %s is already built in, skipping %s" % [id, src])
			continue
		if bake_failed.has(id):
			continue
		var out := ProjectSettings.globalize_path("user://tilesets").path_join(id)
		if tileset_stale(src, out):
			var message: String = TilesetBake.bake(src, out)
			if message != "":
				bake_failed[id] = true
				print(message)
				continue
			if packed_tileset == id:
				packed_tileset = ""
		if FileAccess.file_exists(out.path_join("tileset.json")):
			extra_dirs[id] = out


static func tileset_stale(src: String, out: String) -> bool:
	var built := out.path_join("pieces.bin")
	if not FileAccess.file_exists(built):
		return true
	var built_time := FileAccess.get_modified_time(built)
	var newest := 0
	for file_name in DirAccess.get_files_at(src):
		newest = maxi(newest, FileAccess.get_modified_time(src.path_join(String(file_name))))
	return newest > built_time


static func content_tilesets() -> String:
	return Data.content_folder().path_join("tilesets")


static func tileset_home(tileset: String) -> String:
	ensure_extra_tilesets()
	if extra_dirs.has(tileset):
		return String(extra_dirs[tileset])
	var shipped := "res://tilesets/%s" % tileset
	if FileAccess.file_exists(shipped.path_join("tileset.json")):
		return shipped
	var extracted := content_tilesets().path_join(tileset)
	if FileAccess.file_exists(extracted.path_join("tileset.json")):
		return extracted
	return shipped


static func course_file(tileset: String, number: int) -> String:
	return tileset_home(tileset).path_join("courses").path_join("%d.json" % number)


static func load_atlas(dir: String) -> Texture2D:
	var path := dir.path_join("atlas.png")
	if dir.begins_with("res://"):
		return load(path)
	var image := Image.new()
	image.load(path)
	return ImageTexture.create_from_image(image)


static func list_tilesets() -> Array:
	ensure_extra_tilesets()
	var listed: Array = []
	var circuit: Array = []
	var custom: Array = []
	var seen := {}
	collect_tileset_root("res://tilesets", circuit, custom, seen)
	collect_tileset_root(content_tilesets(), circuit, custom, seen)
	for id in extra_dirs:
		var dir := String(extra_dirs[id])
		var extra: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("tileset.json")))
		custom.append({"id": id, "name": String(extra.name), "custom": true})
	var by_name := func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name)
	circuit.sort_custom(by_name)
	custom.sort_custom(by_name)
	listed.append_array(circuit)
	listed.append_array(custom)
	return listed


static func collect_tileset_root(root: String, circuit: Array, custom: Array, seen: Dictionary) -> void:
	var folder := DirAccess.open(root)
	if folder == null:
		return
	for file_name in folder.get_directories():
		var id := String(file_name)
		if seen.has(id):
			continue
		var manifest := root.path_join(id).path_join("tileset.json")
		if not FileAccess.file_exists(manifest):
			continue
		seen[id] = true
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest))
		var entry := {"id": id, "name": String(info.name), "custom": not Session.WORLDS.has(id)}
		if entry.custom:
			custom.append(entry)
		else:
			circuit.append(entry)


static func default_tileset() -> String:
	return String(list_tilesets()[0].id)


static func tileset_info(tileset: String) -> Dictionary:
	if packed_tileset == tileset:
		return packed_info
	preview_meshes = {}
	var dir := tileset_home(tileset)
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("tileset.json")))
	var tiles: Array = marker_tiles()
	for raw: Dictionary in info.tiles:
		var mesh_id := int(raw.mesh) if raw.has("mesh") else 0
		var cells_out: Array = []
		if raw.has("cells"):
			for cell: Dictionary in raw.cells:
				cells_out.append({"dx": int(cell.dx), "dz": int(cell.dz), "mesh": int(cell.mesh)})
			mesh_id = int(cells_out[0].mesh)
		var row := tile_row(String(raw.name), Piece.SCENERY, 0, 0, "scenery", mesh_id)
		if cells_out.size() > 1:
			row.cells = cells_out
		row.group = int(raw.group) if raw.has("group") else 0
		if raw.has("color"):
			var channels: Array = raw.color
			row.color = Color(float(channels[0]) / 255.0, float(channels[1]) / 255.0, float(channels[2]) / 255.0)
		tiles.append(row)
	packed_tileset = tileset
	packed_info = {
		"id": tileset,
		"name": String(info.name),
		"layer": int(info.layer),
		"tiles": tiles,
		"kind": "world",
		"atlas": load_atlas(dir),
		"markers": marker_tiles().size(),
		"stack": bool(info.stack) if info.has("stack") else false,
		"grid": int(info.grid) if info.has("grid") else 1,
	}
	if info.has("ground"):
		var channels: Array = info.ground
		packed_info.ground = Color(float(channels[0]) / 255.0, float(channels[1]) / 255.0, float(channels[2]) / 255.0)
	packed_meshes = parse_pieces(FileAccess.get_file_as_bytes(dir.path_join("pieces.bin")))
	return packed_info


static func tile_def(tileset: String, index: int) -> Dictionary:
	var tiles: Array = tileset_info(tileset).tiles
	return tiles[clampi(index, 0, tiles.size() - 1)]


static func layer_step(tileset: String) -> int:
	return int(tileset_info(tileset).layer)


static func cell_plane(layer: int, tileset: String) -> float:
	return metres((layer + 1) * layer_step(tileset))


static func parse_pieces(bytes: PackedByteArray) -> Array:
	var meshes: Array = []
	var offset := 0
	var count := bytes.decode_u32(offset)
	offset += 4
	for _i in count:
		var single := read_baked(bytes, offset)
		offset = int(single.next)
		var doubled := read_baked(bytes, offset)
		offset = int(doubled.next)
		var tris := bytes.decode_u32(offset)
		offset += 4
		var collision := PackedVector3Array()
		collision.resize(tris * 3)
		for v in tris * 3:
			collision[v] = Vector3(bytes.decode_float(offset), bytes.decode_float(offset + 4), bytes.decode_float(offset + 8))
			offset += 12
		var surfaces := bytes.slice(offset, offset + tris)
		offset += tris
		meshes.append({"single": single, "double": doubled, "collision": collision, "surfaces": surfaces})
	return meshes


static func read_baked(bytes: PackedByteArray, offset: int) -> Dictionary:
	var count := bytes.decode_u32(offset)
	offset += 4
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var uv := PackedVector2Array()
	pos.resize(count)
	nrm.resize(count)
	col.resize(count)
	uv.resize(count)
	for i in count:
		pos[i] = Vector3(bytes.decode_float(offset), bytes.decode_float(offset + 4), bytes.decode_float(offset + 8))
		nrm[i] = Vector3(bytes.decode_float(offset + 12), bytes.decode_float(offset + 16), bytes.decode_float(offset + 20))
		col[i] = Color(bytes.decode_float(offset + 24), bytes.decode_float(offset + 28), bytes.decode_float(offset + 32), bytes.decode_float(offset + 36))
		uv[i] = Vector2(bytes.decode_float(offset + 40), bytes.decode_float(offset + 44))
		offset += 48
	return {"pos": pos, "nrm": nrm, "col": col, "uv": uv, "next": offset}


static func normalize(raw: Dictionary) -> Dictionary:
	var piece := int(raw.piece)
	var slope := int(raw.slope) if raw.has("slope") else (1 if piece == Piece.RAMP else 0)
	if piece == Piece.RAMP and slope == 0:
		slope = 1
	var rot := int(raw.rot) & 3
	var tile := int(raw.tile) if raw.has("tile") else 0
	var lap := 1
	if raw.has("lap") and not bool(raw.lap):
		lap = 0
	var part := {
		"x": int(raw.x),
		"y": int(raw.y),
		"z": int(raw.z),
		"piece": piece,
		"rot": rot,
		"slope": slope,
		"pitch": int(raw.pitch) if raw.has("pitch") else 0,
		"distance": int(raw.distance) if raw.has("distance") else 24,
		"type": int(raw.type) if raw.has("type") else CAM_NORMAL,
		"tile": tile,
		"mirror": int(raw.mirror) if raw.has("mirror") else 0,
		"lap": lap,
	}
	if raw.has("slot"):
		part.slot = int(raw.slot)
	if raw.has("ox") and int(raw.ox) != 0:
		part.ox = int(raw.ox)
	if raw.has("oz") and int(raw.oz) != 0:
		part.oz = int(raw.oz)
	if raw.has("oy") and int(raw.oy) != 0:
		part.oy = int(raw.oy)
	return part


static func road_map(parts: Array) -> Dictionary:
	var road := {}
	for part: Dictionary in parts:
		if on_lap(part):
			road[key_part(part)] = part
	return road


static func ramp_exit(part: Dictionary) -> String:
	var fwd: Vector2i = FORWARD[int(part.rot) & 3]
	return key_of(int(part.x) + fwd.x, int(part.y) + int(part.slope), int(part.z) + fwd.y)


static func road_links(road: Dictionary) -> Dictionary:
	var links := {}
	for part: Dictionary in road.values():
		var near: Array[String] = []
		for step in FORWARD:
			var beside := key_of(int(part.x) + step.x, int(part.y), int(part.z) + step.y)
			if road.has(beside):
				near.append(beside)
		if int(part.piece) == Piece.RAMP:
			var exit_key := ramp_exit(part)
			if road.has(exit_key) and not near.has(exit_key):
				near.append(exit_key)
		links[key_part(part)] = near
	for part: Dictionary in road.values():
		if int(part.piece) != Piece.RAMP:
			continue
		var exit_key := ramp_exit(part)
		if not links.has(exit_key):
			continue
		var here := key_part(part)
		var other: Array[String] = links[exit_key]
		if not other.has(here):
			other.append(here)
			links[exit_key] = other
	for key in links:
		var near: Array[String] = links[key]
		if near.size() != 2:
			return {}
	return links


static func road_step(a: Dictionary, b: Dictionary) -> bool:
	var dx := absi(int(a.x) - int(b.x))
	var dy := absi(int(a.y) - int(b.y))
	var dz := absi(int(a.z) - int(b.z))
	if dx > 1 or dz > 1:
		return false
	return dx + dy + dz > 0


static func flat_units(sample: Dictionary, x: int, z: int) -> float:
	return Vector2(float(int(sample.x) - x), float(int(sample.z) - z)).length()


static func line_sample(x: int, y: int, z: int, heading: int) -> Dictionary:
	var sample := {
		"x": x,
		"y": y,
		"z": z,
		"h": heading,
		"lx": x,
		"lz": z,
		"rx": x,
		"rz": z,
		"ax": x,
		"az": z,
		"bx": x,
		"bz": z,
		"lift": [0, 0],
		"lane_lift": [0, 0],
		"slope": [0, 0],
	}
	aim_sample(sample, heading)
	return sample


static func aim_sample(sample: Dictionary, heading: int) -> void:
	var radians := float(heading) * Car.ANGLE_TO_RAD
	var right := Vector2(cos(radians), -sin(radians))
	var pos := Vector2(float(sample.x), float(sample.z))
	var left := pos - right * 256.0
	var right_pt := pos + right * 256.0
	var gate_left := pos - right * GATE_HALF
	var gate_right := pos + right * GATE_HALF
	sample.h = heading
	sample.lx = roundi(left.x)
	sample.lz = roundi(left.y)
	sample.rx = roundi(right_pt.x)
	sample.rz = roundi(right_pt.y)
	sample.ax = roundi(gate_left.x)
	sample.az = roundi(gate_left.y)
	sample.bx = roundi(gate_right.x)
	sample.bz = roundi(gate_right.y)


static func shift_sample(sample: Dictionary, dx: int, dy: int, dz: int) -> void:
	sample.x = int(sample.x) + dx
	sample.y = int(sample.y) + dy
	sample.z = int(sample.z) + dz
	var keys: PackedStringArray = ["lx", "lz", "rx", "rz", "ax", "az", "bx", "bz"]
	var i := 0
	while i < keys.size():
		sample[keys[i]] = int(sample[keys[i]]) + dx
		sample[keys[i + 1]] = int(sample[keys[i + 1]]) + dz
		i += 2


static func turn_span(sample: Dictionary, heading: int) -> void:
	var old := int(sample.h)
	sample.h = heading
	if old == heading:
		return
	var old_rad := float(old) * Car.ANGLE_TO_RAD
	var new_rad := float(heading) * Car.ANGLE_TO_RAD
	var old_right := Vector2(cos(old_rad), -sin(old_rad))
	var old_forward := Vector2(-sin(old_rad), -cos(old_rad))
	var new_right := Vector2(cos(new_rad), -sin(new_rad))
	var new_forward := Vector2(-sin(new_rad), -cos(new_rad))
	var pos := Vector2(float(sample.x), float(sample.z))
	var keys: PackedStringArray = ["lx", "lz", "rx", "rz", "ax", "az", "bx", "bz"]
	var i := 0
	while i < keys.size():
		var offset := Vector2(float(sample[keys[i]]), float(sample[keys[i + 1]])) - pos
		var local_right := offset.dot(old_right)
		var local_forward := offset.dot(old_forward)
		var spun := pos + new_right * local_right + new_forward * local_forward
		sample[keys[i]] = roundi(spun.x)
		sample[keys[i + 1]] = roundi(spun.y)
		i += 2


static func point_sample(sample: Dictionary, nxt: Dictionary) -> void:
	var dx := int(nxt.x) - int(sample.x)
	var dz := int(nxt.z) - int(sample.z)
	var heading := step_heading(dx, dz)
	if heading < 0:
		heading = int(sample.h)
	turn_span(sample, heading)
	var radians := float(heading) * Car.ANGLE_TO_RAD
	var forward := Vector2(-sin(radians), -cos(radians))
	var run := Vector2(float(dx), float(dz)).length()
	sample.slope = slope_bytes(forward, float(int(nxt.y) - int(sample.y)), run)


static func step_heading(dx: int, dz: int) -> int:
	if dx == 0 and dz == 0:
		return -1
	return roundi(atan2(float(-dx), float(-dz)) / Car.ANGLE_TO_RAD) & 4095


static func road_parts(parts: Array, road: Array) -> Array:
	var at := {}
	for part: Dictionary in parts:
		at[key_part(part)] = part
	var chain: Array = []
	for cell: Dictionary in road:
		var key := key_of(int(cell.x), int(cell.y), int(cell.z))
		if at.has(key):
			chain.append(at[key])
		else:
			chain.append({})
	return chain


static func trace(parts: Array, road: Array = []) -> Array:
	if road.is_empty():
		return trace_linked(parts)
	var chain := road_parts(parts, road)
	if chain.size() < 4:
		return []
	for cell: Dictionary in chain:
		if cell.is_empty():
			return []
	for i in chain.size():
		var nxt: Dictionary = chain[(i + 1) % chain.size()]
		if not road_step(chain[i], nxt):
			return []
	return chain


static func trace_linked(parts: Array) -> Array:
	var road := road_map(parts)
	var start: Dictionary = {}
	var starts := 0
	for part: Dictionary in road.values():
		if int(part.piece) == Piece.START:
			starts += 1
			start = part
	if starts != 1:
		return []
	var links := road_links(road)
	if links.is_empty():
		return []
	var start_key := key_part(start)
	var neighbors: Array[String] = links[start_key]
	var faced: Vector2i = FORWARD[int(start.rot) & 3]
	var faced_key := key_of(int(start.x) + faced.x, int(start.y), int(start.z) + faced.y)
	var prev := neighbors[0]
	if neighbors.has(faced_key):
		prev = neighbors[1] if neighbors[0] == faced_key else neighbors[0]
	var loop: Array = []
	var current := start
	for _i in road.size():
		loop.append(current)
		var options: Array[String] = links[key_part(current)]
		var nxt_key := options[0] if options[1] == prev else options[1]
		if nxt_key == start_key:
			if loop.size() != road.size():
				return []
			return loop
		prev = key_part(current)
		current = road[nxt_key]
	return []


static func safe_name(level_name: String) -> String:
	var text := level_name.strip_edges()
	var safe := ""
	for i in text.length():
		var ch := text.substr(i, 1)
		var code := ch.unicode_at(0)
		var ok := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or ch == " " or ch == "_" or ch == "-"
		if ok:
			safe += ch
	safe = safe.replace(" ", "_")
	if safe == "":
		return "untitled"
	return safe


static func named_path(level_name: String) -> String:
	return DIR + "/" + safe_name(level_name) + ".json"


static func save_level(level: Dictionary, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(level, "\t"))


static func load_level(path: String) -> Dictionary:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var parts: Array = []
	for raw: Dictionary in parsed.parts:
		parts.append(normalize(raw))
	var tileset := String(parsed.tileset) if parsed.has("tileset") else ""
	var known := false
	for entry: Dictionary in list_tilesets():
		if String(entry.id) == tileset:
			known = true
	var road: Array = []
	var line: Array = []
	var joined := false
	var broken := false
	var gaps: Array = []
	if not known:
		tileset = default_tileset()
		parts = []
	else:
		if parsed.has("road"):
			for raw: Dictionary in parsed.road:
				road.append({"x": int(raw.x), "y": int(raw.y), "z": int(raw.z)})
		else:
			for cell: Dictionary in trace(parts):
				road.append({"x": int(cell.x), "y": int(cell.y), "z": int(cell.z)})
		if parsed.has("line"):
			for raw: Dictionary in parsed.line:
				var sample := {
					"x": int(raw.x),
					"y": int(raw.y),
					"z": int(raw.z),
					"h": int(raw.h),
					"lx": int(raw.lx),
					"lz": int(raw.lz),
					"rx": int(raw.rx),
					"rz": int(raw.rz),
					"ax": int(raw.ax) if raw.has("ax") else int(raw.lx),
					"az": int(raw.az) if raw.has("az") else int(raw.lz),
					"bx": int(raw.bx) if raw.has("bx") else int(raw.rx),
					"bz": int(raw.bz) if raw.has("bz") else int(raw.rz),
					"lift": [int(raw.lift[0]), int(raw.lift[1])],
					"lane_lift": [int(raw.lane_lift[0]), int(raw.lane_lift[1])],
					"slope": [int(raw.slope[0]), int(raw.slope[1])],
				}
				if raw.has("camera"):
					var cam: Array = raw.camera
					sample.camera = [int(cam[0]), int(cam[1]), int(cam[2]), int(cam[3]), int(cam[4])]
				if raw.has("battle_camera"):
					var battle: Array = raw.battle_camera
					sample.battle_camera = [int(battle[0]), int(battle[1]), int(battle[2])]
				if raw.has("pickups"):
					var pickups: Array = []
					for entry: Array in raw.pickups:
						pickups.append([int(entry[0]), int(entry[1]), int(entry[2])])
					sample.pickups = pickups
				line.append(sample)
			if parsed.has("joined"):
				joined = bool(parsed.joined)
			elif not line.is_empty():
				joined = true
			if parsed.has("broken"):
				broken = bool(parsed.broken)
			if parsed.has("gaps"):
				for raw in parsed.gaps:
					gaps.append(int(raw))
		var kept: Array = []
		for part: Dictionary in parts:
			if int(part.piece) == Piece.START:
				continue
			kept.append(part)
		parts = kept
	var level := {
		"name": String(parsed.name),
		"vehicle": int(parsed.vehicle),
		"ai": supports_ai(parsed),
		"tileset": tileset,
		"parts": parts,
		"road": road,
		"line": line,
		"joined": joined,
		"broken": broken,
		"gaps": gaps,
		"source": String(parsed.source) if parsed.has("source") else "",
		"unsaved": bool(parsed.unsaved) if parsed.has("unsaved") else false,
	}
	if parsed.has("handling"):
		level.handling = String(parsed.handling)
	return level


static func list_courses() -> Array:
	var listed: Array = []
	for root in ["res://tilesets", content_tilesets()]:
		var folder := DirAccess.open(root)
		if folder == null:
			continue
		for world in folder.get_directories():
			var courses := DirAccess.open(root.path_join(String(world)).path_join("courses"))
			if courses == null:
				continue
			for file_name in courses.get_files():
				var name := String(file_name)
				if not name.ends_with(".json"):
					continue
				var path := courses.get_current_dir().path_join(name)
				listed.append({"name": course_name(path), "path": path})
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name))
	return listed


static func course_name(path: String) -> String:
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	return String(parsed.name)


static func list_levels() -> PackedStringArray:
	var names := PackedStringArray()
	var folder := DirAccess.open(DIR)
	if folder == null:
		return names
	folder.list_dir_begin()
	var file_name := folder.get_next()
	while file_name != "":
		if not folder.current_is_dir() and file_name.ends_with(".json") and file_name != "active.json":
			names.append(file_name.get_basename())
		file_name = folder.get_next()
	folder.list_dir_end()
	names.sort()
	return names


static func list_saved() -> Array:
	var listed: Array = []
	for file_name in list_levels():
		var path := DIR + "/" + file_name + ".json"
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var label := file_name
		if parsed.has("name") and String(parsed.name) != "":
			label = String(parsed.name)
		listed.append({"name": label, "path": path})
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name))
	return listed


static func list_playable() -> Array:
	var listed: Array = []
	for file_name in list_levels():
		var path := DIR + "/" + file_name + ".json"
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed.has("line"):
			continue
		var line: Array = parsed.line
		if line.size() < 4:
			continue
		if parsed.has("joined") and not bool(parsed.joined):
			continue
		if parsed.has("broken") and bool(parsed.broken):
			continue
		if parsed.has("gaps"):
			var gaps: Array = parsed.gaps
			if not gaps.is_empty():
				continue
		var label := file_name
		if parsed.has("name") and String(parsed.name) != "":
			label = String(parsed.name)
		var tileset := String(parsed.tileset) if parsed.has("tileset") else ""
		listed.append({"name": label, "path": path, "tileset": tileset})
	listed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.name) < String(b.name))
	return listed


static func play_dir(vehicle: int) -> String:
	return DIR + "/play/" + VEHICLE_DIR[vehicle]


static func course_dir(path: String) -> String:
	return DIR + "/play/" + path.get_file().get_basename()


# A sample stores [lap, type, lane] with lap 0 meaning every lap. The race
# matches the table's lap byte against laps left, so lap 1 of 3 is stored as 3.
static func pickup_table(line: Array) -> Array:
	var table: Array = []
	for index in line.size():
		var sample: Dictionary = line[index]
		if not sample.has("pickups"):
			continue
		for entry: Array in sample.pickups:
			var lap := int(entry[0])
			table.append([index, EVERY_LAP if lap == 0 else Race.LAPS - lap + 1, int(entry[1]), int(entry[2])])
	assert(table.size() <= PICKUP_LIMIT, "more pickups than the race table holds")
	return table


static func pickup_count(line: Array) -> int:
	var count := 0
	for sample: Dictionary in line:
		if sample.has("pickups"):
			count += (sample.pickups as Array).size()
	return count


static func pickup_spot(sample: Dictionary, lane: int) -> Vector3:
	var x := float(sample.x)
	var z := float(sample.z)
	var y := float(sample.y)
	match lane:
		1:
			x = float(sample.lx)
			z = float(sample.lz)
			y -= float(sample.lift[0])
		2:
			x = float(sample.rx)
			z = float(sample.rz)
			y -= float(sample.lift[1])
		3:
			x = float(int(sample.ax) + int(sample.lx)) * 0.5
			z = float(int(sample.az) + int(sample.lz)) * 0.5
		4:
			x = float(int(sample.rx) + int(sample.bx)) * 0.5
			z = float(int(sample.rz) + int(sample.bz)) * 0.5
	return Vector3(metres(x), metres(y), metres(z))


static func pickup_color(type: int) -> Color:
	var rgb: Array = Items.PICKUP_COLORS[type]
	return Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]), 230)


static func pickup_mesh(line: Array, hover: Vector2i, picked: Vector2i, show_spots: bool) -> ArrayMesh:
	var bucket := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	for i in line.size():
		var sample: Dictionary = line[i]
		if show_spots:
			for lane in LANE_NAMES.size():
				add_flow_marker(bucket, pickup_spot(sample, lane) + Vector3.UP * 0.1, Color(1, 1, 1, 0.3), 0.3)
		if not sample.has("pickups"):
			continue
		var stacked := {}
		var entries: Array = sample.pickups
		for k in entries.size():
			var entry: Array = entries[k]
			var lane := int(entry[2])
			var level_up := int(stacked.get(lane, 0))
			stacked[lane] = level_up + 1
			var base := pickup_spot(sample, lane)
			var top := base + Vector3.UP * (2.0 + 1.8 * float(level_up))
			var color := pickup_color(int(entry[1]))
			var size := 1.1 if picked == Vector2i(i, k) else 0.8
			if picked == Vector2i(i, k):
				add_gem(bucket, top, size + 0.3, Color(1, 1, 1, 0.9))
			add_beam(bucket, base, top, 0.08, color)
			add_gem(bucket, top, size, color)
	if hover.x >= 0 and hover.x < line.size():
		var spot := pickup_spot(line[hover.x], hover.y)
		add_beam(bucket, spot, spot + Vector3.UP * 2.0, 0.1, Color(1, 1, 1, 0.8))
		add_flow_marker(bucket, spot + Vector3.UP * 0.1, Color(1, 1, 1, 0.8), 0.7)
	var empty := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	return make_mesh({"single": bucket, "double": empty})


static func add_gem(bucket: Dictionary, centre: Vector3, size: float, color: Color) -> void:
	var up := Vector3.UP * size
	var x := Vector3.RIGHT * size * 0.7
	var z := Vector3.BACK * size * 0.7
	add_quad(bucket, PackedVector3Array(), centre - up, centre - x, centre + up, centre + x, color, false, false)
	add_quad(bucket, PackedVector3Array(), centre - up, centre - z, centre + up, centre + z, color, false, false)
	add_quad(bucket, PackedVector3Array(), centre - x, centre - z, centre + x, centre + z, color, false, false)


static func supports_ai(level: Dictionary) -> bool:
	return level.has("ai") and bool(level.ai)


static func handling_preset(level: Dictionary) -> String:
	if level.has("handling"):
		return String(level.handling)
	return VEHICLE_HANDLING[int(level.vehicle)]


static func compile(level: Dictionary, dir: String) -> String:
	var tileset := String(level.tileset)
	var loop := trace(level.parts, level.road)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var built := build_nodes(level.parts, loop, tileset, level.line)
	var grid := build_grid(level.parts, built.nodes)
	var mesh := collect_mesh(level.parts, loop, tileset)
	add_ground(mesh, level.parts, level.line, tileset)
	write_mesh(dir + "/mesh.bin", mesh)
	write_collision(dir + "/collision.bin", mesh.collision, mesh.surfaces)
	var objects_file := FileAccess.open(dir + "/objects.bin", FileAccess.WRITE)
	objects_file.store_32(0)
	objects_file.store_32(0)
	var atlas := load_atlas(tileset_home(tileset))
	atlas.get_image().save_png(dir + "/atlas.png")
	var objects: Array = []
	for _i in 128:
		objects.append([0, 0, 0, 0, 0, 0, 0, 0])
	assign_ai(built.nodes)
	var tables := ai_tables()
	var data := {
		"name": String(level.name),
		"vehicle": int(level.vehicle),
		"nodes": built.nodes,
		"node_grid": grid,
		"respawn_ranges": [],
		"sky": [0.62, 0.7, 0.78],
		"handling": Car.HANDLING[handling_preset(level)],
		"water": null,
		"water_regions": [],
		"script": [0],
		"objects": objects,
		"object_models": [],
		"pickups": pickup_table(level.line),
		"ai_thresholds": tables.thresholds,
		"ai_speeds": tables.speeds,
		"ai_start": AI_START if bool(level.ai) else null,
		"scrolls": [],
		"flip_entries": [],
		"flip_groups": [],
		"flip_bank": [],
		"weather": 0,
		"texture_pause": false,
	}
	var track_file := FileAccess.open(dir + "/track.json", FileAccess.WRITE)
	track_file.store_string(JSON.stringify(data))
	return dir


static func part_mesh(part: Dictionary, tileset: String) -> Dictionary:
	var tile: Dictionary = tile_def(tileset, int(part.tile))
	var mesh_index := int(tile.mesh)
	if part.has("slot") and tile.has("cells"):
		var cells: Array = tile.cells
		mesh_index = int(cells[int(part.slot)].mesh)
	return packed_meshes[mesh_index]


static func footprint_parts(tileset: String, tile_index: int, x: int, y: int, z: int, rot: int, mirror: int, lap_on: bool, ox: int = 0, oz: int = 0, oy: int = 0) -> Array:
	var tile: Dictionary = tile_def(tileset, tile_index)
	var cells: Array = [{"dx": 0, "dz": 0}]
	if tile.has("cells"):
		cells = tile.cells
	var scenery := String(tile.role) == "scenery"
	var parts: Array = []
	for slot in cells.size():
		var cell: Dictionary = cells[slot]
		var turned := orient_point(Vector3(float(int(cell.dx)), 0.0, float(int(cell.dz))), rot, mirror)
		var part := {
			"x": x + roundi(turned.x),
			"y": y,
			"z": z + roundi(turned.z),
			"piece": int(tile.piece),
			"rot": (rot & 3) if scenery else int(tile.rot) & 3,
			"slope": int(tile.slope),
			"pitch": 0,
			"distance": 24,
			"type": CAM_NORMAL,
			"tile": tile_index,
			"mirror": mirror,
			"lap": 1 if lap_on or not scenery else 0,
		}
		if cells.size() > 1:
			part.slot = slot
		if ox != 0:
			part.ox = ox
		if oz != 0:
			part.oz = oz
		if oy != 0:
			part.oy = oy
		parts.append(part)
	return parts


static func stamp_cells(part: Dictionary, tileset: String) -> Array:
	var tile: Dictionary = tile_def(tileset, int(part.tile))
	var here := Vector3i(int(part.x), int(part.y), int(part.z))
	if not tile.has("cells"):
		return [here]
	var cells: Array = tile.cells
	var slot := int(part.slot) if part.has("slot") else 0
	var cell: Dictionary = cells[slot]
	var turned := orient_point(Vector3(float(int(cell.dx)), 0.0, float(int(cell.dz))), int(part.rot), int(part.mirror))
	var ax := int(part.x) - roundi(turned.x)
	var az := int(part.z) - roundi(turned.z)
	var spots: Array = []
	for item in cells:
		var other: Dictionary = item
		var offset := orient_point(Vector3(float(int(other.dx)), 0.0, float(int(other.dz))), int(part.rot), int(part.mirror))
		spots.append(Vector3i(ax + roundi(offset.x), int(part.y), az + roundi(offset.z)))
	return spots


static func ray_part(part: Dictionary, tileset: String, origin: Vector3, dir: Vector3) -> float:
	var mesh: Dictionary = part_mesh(part, tileset)
	var placed := cell_center(int(part.x), int(part.z)) + part_nudge(part)
	placed.y = cell_plane(int(part.y), tileset) + part_lift(part)
	var rot := int(part.rot) & 3
	var flags := int(part.mirror)
	var best := -1.0
	var single: Dictionary = mesh.single
	var doubled: Dictionary = mesh.double
	best = nearer_hit(best, ray_baked(single.pos, origin, dir, placed, rot, flags))
	return nearer_hit(best, ray_baked(doubled.pos, origin, dir, placed, rot, flags))


static func ray_baked(pos: PackedVector3Array, origin: Vector3, dir: Vector3, placed: Vector3, rot: int, flags: int) -> float:
	var best := -1.0
	var i := 0
	while i + 2 < pos.size():
		var a := placed + orient_point(pos[i], rot, flags)
		var b := placed + orient_point(pos[i + 1], rot, flags)
		var c := placed + orient_point(pos[i + 2], rot, flags)
		best = nearer_hit(best, ray_tri(origin, dir, a, b, c))
		i += 3
	return best


static func nearer_hit(best: float, hit: float) -> float:
	if hit >= 0.0 and (best < 0.0 or hit < best):
		return hit
	return best


static func ray_tri(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var p := dir.cross(ac)
	var det := ab.dot(p)
	if absf(det) < 0.0000001:
		return -1.0
	var inv := 1.0 / det
	var tvec := origin - a
	var u := tvec.dot(p) * inv
	if u < 0.0 or u > 1.0:
		return -1.0
	var q := tvec.cross(ab)
	var v := dir.dot(q) * inv
	if v < 0.0 or u + v > 1.0:
		return -1.0
	var t := ac.dot(q) * inv
	if t < 0.0:
		return -1.0
	return t


static func orient_point(point: Vector3, rot: int, flags: int) -> Vector3:
	var x := point.x
	var z := point.z
	if flags & 1:
		x = -x
	if flags & 2:
		z = -z
	match rot & 3:
		1:
			var east := -z
			z = x
			x = east
		2:
			x = -x
			z = -z
		3:
			var west := z
			z = -x
			x = west
	return Vector3(x, point.y, z)


static func contains_xz(a: Vector3, b: Vector3, c: Vector3, x: float, z: float) -> bool:
	var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
	if absf(area) < 1e-8:
		return false
	var w0 := (b.x - x) * (c.z - z) - (c.x - x) * (b.z - z)
	var w1 := (c.x - x) * (a.z - z) - (a.x - x) * (c.z - z)
	var w2 := (a.x - x) * (b.z - z) - (b.x - x) * (a.z - z)
	var edge := 0.001
	if area > 0.0:
		return w0 >= -edge and w1 >= -edge and w2 >= -edge
	return w0 <= edge and w1 <= edge and w2 <= edge


static func surface_point(parts: Array, tileset: String, origin: Vector3, dir: Vector3) -> Dictionary:
	var best_t := 1.0e20
	var best := Vector3.ZERO
	var layer := 0
	var found := false
	var half := metres(256.0)
	var span := metres(float(CELL_U))
	for part: Dictionary in parts:
		var center := cell_center(int(part.x), int(part.z)) + part_nudge(part)
		var y0 := cell_plane(int(part.y), tileset) + part_lift(part)
		if not ray_hits_box(origin, dir, Vector3(center.x - half, y0, center.z - half), Vector3(center.x + half, y0 + span, center.z + half), best_t):
			continue
		var mesh: Dictionary = part_mesh(part, tileset)
		var collision: PackedVector3Array = mesh.collision
		var rot := int(part.rot) & 3
		var flags := int(part.mirror)
		var flip := flags == 1 or flags == 2
		var placed := Vector3(center.x, y0, center.z)
		var i := 0
		while i < collision.size():
			var a := placed + orient_point(collision[i], rot, flags)
			var b := placed + orient_point(collision[i + 1], rot, flags)
			var c := placed + orient_point(collision[i + 2], rot, flags)
			i += 3
			if flip:
				var swap := b
				b = c
				c = swap
			var t := ray_triangle(origin, dir, a, b, c)
			if t < 0.0 or t >= best_t:
				continue
			best_t = t
			best = origin + dir * t
			layer = int(part.y)
			found = true
	if not found:
		return {}
	return {
		"x": roundi(best.x / Car.UNIT_METRES),
		"y": roundi(best.y / Car.UNIT_METRES),
		"z": roundi(best.z / Car.UNIT_METRES),
		"at": best,
		"layer": layer,
	}


static func ray_hits_box(origin: Vector3, dir: Vector3, box_min: Vector3, box_max: Vector3, limit: float) -> bool:
	var tmin := 0.0
	var tmax := limit
	for axis in 3:
		var origin_axis := origin.x
		var dir_axis := dir.x
		var low := box_min.x
		var high := box_max.x
		if axis == 1:
			origin_axis = origin.y
			dir_axis = dir.y
			low = box_min.y
			high = box_max.y
		elif axis == 2:
			origin_axis = origin.z
			dir_axis = dir.z
			low = box_min.z
			high = box_max.z
		if absf(dir_axis) < 0.00001:
			if origin_axis < low or origin_axis > high:
				return false
			continue
		var t0 := (low - origin_axis) / dir_axis
		var t1 := (high - origin_axis) / dir_axis
		if t0 > t1:
			var swap := t0
			t0 = t1
			t1 = swap
		tmin = maxf(tmin, t0)
		tmax = minf(tmax, t1)
		if tmin > tmax:
			return false
	return tmax >= 0.0


static func ray_triangle(origin: Vector3, dir: Vector3, a: Vector3, b: Vector3, c: Vector3) -> float:
	var ab := b - a
	var ac := c - a
	var p := dir.cross(ac)
	var det := ab.dot(p)
	if absf(det) < 1.0e-8:
		return -1.0
	var inv := 1.0 / det
	var tvec := origin - a
	var u := tvec.dot(p) * inv
	if u < -0.001 or u > 1.001:
		return -1.0
	var q := tvec.cross(ab)
	var v := dir.dot(q) * inv
	if v < -0.001 or u + v > 1.001:
		return -1.0
	var t := ac.dot(q) * inv
	if t < 0.0:
		return -1.0
	return t


static func floor_units(part: Dictionary, tileset: String) -> float:
	if int(part.piece) != Piece.SCENERY:
		return float((int(part.y) + 1) * layer_step(tileset))
	var mesh: Dictionary = part_mesh(part, tileset)
	var collision: PackedVector3Array = mesh.collision
	var rot := int(part.rot) & 3
	var flags := int(part.mirror)
	var best := 0.0
	var found := false
	var i := 0
	while i < collision.size():
		var a := orient_point(collision[i], rot, flags)
		var b := orient_point(collision[i + 1], rot, flags)
		var c := orient_point(collision[i + 2], rot, flags)
		i += 3
		if flags == 1 or flags == 2:
			var swap := b
			b = c
			c = swap
		if not contains_xz(a, b, c, 0.0, 0.0):
			continue
		var area := (b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)
		var wa := b.x * c.z - c.x * b.z
		var wb := -a.x * (c.z - a.z) + a.z * (c.x - a.x)
		var wc := -(b.x - a.x) * a.z + a.x * (b.z - a.z)
		var h := (a.y * wa + b.y * wb + c.y * wc) / area
		if not found or h > best:
			best = h
			found = true
	if found:
		return float((int(part.y) + 1) * layer_step(tileset)) + best / Car.UNIT_METRES
	return float((int(part.y) + 1) * layer_step(tileset))


static func cell_index(units: int) -> int:
	return floori((float(units) + float(CELL_U / 2)) / float(CELL_U))


static func ground_bounds(parts: Array, line: Array) -> Vector4i:
	var min_x := 0
	var max_x := 0
	var min_z := 0
	var max_z := 0
	var any := false
	for part: Dictionary in parts:
		var x := int(part.x)
		var z := int(part.z)
		if not any:
			min_x = x
			max_x = x
			min_z = z
			max_z = z
			any = true
		else:
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_z = mini(min_z, z)
			max_z = maxi(max_z, z)
	for sample: Dictionary in line:
		var x := cell_index(int(sample.x))
		var z := cell_index(int(sample.z))
		if not any:
			min_x = x
			max_x = x
			min_z = z
			max_z = z
			any = true
		else:
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			min_z = mini(min_z, z)
			max_z = maxi(max_z, z)
	var pad := 8
	if not any:
		return Vector4i(-pad, -pad, pad, pad)
	return Vector4i(min_x - pad, min_z - pad, max_x + pad, max_z + pad)


static func paint_ground(bucket: Dictionary, collision: PackedVector3Array, tileset: String, bounds: Vector4i, y: float, collide: bool) -> void:
	var color: Color = tileset_info(tileset).ground
	var half := metres(256.0)
	var x0 := cell_center(bounds.x, 0).x - half
	var x1 := cell_center(bounds.z, 0).x + half
	var z0 := cell_center(0, bounds.y).z - half
	var z1 := cell_center(0, bounds.w).z + half
	add_quad(bucket, collision, Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1), color, collide, true)


static func add_ground(mesh: Dictionary, parts: Array, line: Array, tileset: String) -> void:
	if not tileset_info(tileset).has("ground"):
		return
	var bounds := ground_bounds(parts, line)
	var y := cell_plane(0, tileset)
	var discard := PackedVector3Array()
	paint_ground(mesh.single, discard, tileset, bounds, y - metres(2.0), false)
	var collision: PackedVector3Array = mesh.collision
	var surfaces: PackedByteArray = mesh.surfaces
	var before := collision.size()
	paint_ground(mesh_bucket(), collision, tileset, bounds, y, true)
	var added := int((collision.size() - before) / 3.0)
	for _i in added:
		surfaces.append(0)
	mesh.collision = collision
	mesh.surfaces = surfaces


static func snap_unit(value: int, step: int) -> int:
	return roundi(float(value) / float(step)) * step


# The autopilot's node bytes, as the original tracks store them: the distance
# left to the next corner and through it (units / 16), the heading still to
# turn in 0x80 steps (signed five bits, original heading sense) and a speed
# class into the per-car tables. A section is a straight and the corner after
# it; a corner turning the other way starts a new one.
static func assign_ai(nodes: Array) -> void:
	var count := nodes.size()
	var turns: Array[int] = []
	var gaps: Array[float] = []
	var kinds: Array[int] = []
	for i in count:
		var a: Dictionary = nodes[i]
		var b: Dictionary = nodes[(i + 1) % count]
		var turn := wrapi(int(b.heading) - int(a.heading), -2048, 2048)
		turns.append(turn)
		gaps.append(Vector2(float(b.units[0] - a.units[0]), float(b.units[1] - a.units[1])).length())
		kinds.append(0 if absi(turn) <= AI_TURN else signi(turn))
	var starts: Array[int] = []
	for i in count:
		var before := kinds[(i + count - 1) % count]
		if before != 0 and kinds[i] != before:
			starts.append(i)
	if starts.is_empty():
		starts.append(0)
	for s in starts.size():
		var first := starts[s]
		var length := (starts[(s + 1) % starts.size()] - first + count - 1) % count + 1
		var corner := 0
		while corner < length and kinds[(first + corner) % count] == 0:
			corner += 1
		var arc := 0.0
		var swept := 0
		for k in range(corner, length):
			arc += gaps[(first + k) % count]
			swept += turns[(first + k) % count]
		var speed := AI_SPEED_TOP
		if swept != 0:
			var radius := arc / (absf(float(swept)) * TAU / 4096.0)
			speed = clampi(roundi(AI_SPEED_SCALE * sqrt(radius)), AI_SPEED_LOW, AI_SPEED_TOP)
		var straight_left := 0.0
		for k in corner:
			straight_left += gaps[(first + k) % count]
		var corner_left := arc
		var turn_left := swept
		for k in length:
			var index := (first + k) % count
			var turn_steps := clampi(roundi(float(-turn_left) / 128.0), -15, 15) & 31
			nodes[index].ai = [mini(int(straight_left / 16.0), 255), mini(int(corner_left / 16.0), 255), turn_steps, speed / AI_SPEED_STEP]
			if k < corner:
				straight_left -= gaps[index]
			else:
				corner_left -= gaps[index]
				turn_left -= turns[index]


static func ai_tables() -> Dictionary:
	var thresholds: Array = []
	var speeds: Array = []
	var threshold_row: Array = []
	threshold_row.resize(AI_CLASSES)
	threshold_row.fill(AI_THRESHOLD)
	var speed_row: Array = []
	for i in AI_CLASSES:
		speed_row.append(i * AI_SPEED_STEP)
	for _car in 8:
		thresholds.append(threshold_row.duplicate())
		speeds.append(speed_row.duplicate())
	return {"thresholds": thresholds, "speeds": speeds}


static func build_nodes(parts: Array, loop: Array, tileset: String, line: Array = []) -> Dictionary:
	if line.size() >= 4:
		return {"nodes": nodes_from_line(line)}
	var nodes: Array = []
	var carried := 0
	for index in loop.size():
		var cell: Dictionary = loop[index]
		var nxt: Dictionary = loop[(index + 1) % loop.size()]
		var dx := int(nxt.x) - int(cell.x)
		var dz := int(nxt.z) - int(cell.z)
		var heading := step_heading(dx, dz)
		if heading < 0:
			heading = carried
		else:
			carried = heading
		var radians := float(heading) * Car.ANGLE_TO_RAD
		var forward := Vector2(-sin(radians), -cos(radians))
		var right := Vector2(-forward.y, forward.x)
		var back := Vector2(float(int(cell.x) * CELL_U), float(int(cell.z) * CELL_U))
		var front := Vector2(float(int(nxt.x) * CELL_U), float(int(nxt.z) * CELL_U))
		var entry := floor_units(cell, tileset)
		var exit := floor_units(nxt, tileset)
		var view := camera_bytes(heading if int(cell.piece) == Piece.SCENERY else int(HEADING[int(cell.rot) & 3]))
		var run := Vector2(float(dx * CELL_U), float(dz * CELL_U)).length()
		var slope := slope_bytes(forward, float(exit - entry), run)
		for i in NODES:
			var t := (float(i) + 0.5) / float(NODES)
			var pos := back.lerp(front, t)
			var height := lerpf(float(entry), float(exit), t)
			var left := pos - right * 256.0
			var right_pt := pos + right * 256.0
			var gate_left := pos - right * GATE_HALF
			var gate_right := pos + right * GATE_HALF
			var ix := roundi(pos.x)
			var iz := roundi(pos.y)
			var iy := roundi(height)
			var il := Vector2i(roundi(left.x), roundi(left.y))
			var ir := Vector2i(roundi(right_pt.x), roundi(right_pt.y))
			var ia := Vector2i(roundi(gate_left.x), roundi(gate_left.y))
			var ib := Vector2i(roundi(gate_right.x), roundi(gate_right.y))
			var y := metres(height)
			nodes.append({
				"enabled": true,
				"gate": [metres(ia.x), metres(ia.y), metres(ib.x), metres(ib.y)],
				"gate_units": [ia.x, ia.y, ib.x, ib.y],
				"camera": view.camera,
				"battle_camera": view.battle,
				"position": [metres(ix), y, metres(iz)],
				"left": [metres(il.x), y, metres(il.y)],
				"right": [metres(ir.x), y, metres(ir.y)],
				"heading": heading,
				"floor": y,
				"units": [ix, iz, iy, il.x, il.y, ir.x, ir.y, ia.x, ia.y, ib.x, ib.y],
				"lift": [0, 0],
				"lane_lift": [0, 0],
				"slope": slope,
				"ai": [0, 0, 0, 0],
			})
	return {"nodes": nodes}


static func nodes_from_line(line: Array) -> Array:
	var nodes: Array = []
	for index in line.size():
		var sample: Dictionary = line[index]
		var heading := int(sample.h)
		var pos := Vector2(float(sample.x), float(sample.z))
		var height := float(sample.y)
		var left := Vector2(float(sample.lx), float(sample.lz))
		var right_pt := Vector2(float(sample.rx), float(sample.rz))
		var gate_a := Vector2(float(sample.ax), float(sample.az))
		var gate_b := Vector2(float(sample.bx), float(sample.bz))
		var ix := roundi(pos.x)
		var iz := roundi(pos.y)
		var iy := roundi(height)
		var il := Vector2i(roundi(left.x), roundi(left.y))
		var ir := Vector2i(roundi(right_pt.x), roundi(right_pt.y))
		var ia := Vector2i(roundi(gate_a.x), roundi(gate_a.y))
		var ib := Vector2i(roundi(gate_b.x), roundi(gate_b.y))
		var y := metres(height)
		var view := shot_bytes(sample, heading)
		var lift: Array = sample.lift
		var lane_lift: Array = sample.lane_lift
		var slope: Array = sample.slope
		nodes.append({
			"enabled": true,
			"gate": [metres(ia.x), metres(ia.y), metres(ib.x), metres(ib.y)],
			"gate_units": [ia.x, ia.y, ib.x, ib.y],
			"camera": view.camera,
			"battle_camera": view.battle,
			"position": [metres(ix), y, metres(iz)],
			"left": [metres(il.x), y, metres(il.y)],
			"right": [metres(ir.x), y, metres(ir.y)],
			"heading": heading,
			"floor": y,
			"units": [ix, iz, iy, il.x, il.y, ir.x, ir.y, ia.x, ia.y, ib.x, ib.y],
			"lift": [int(lift[0]), int(lift[1])],
			"lane_lift": [int(lane_lift[0]), int(lane_lift[1])],
			"slope": [int(slope[0]), int(slope[1])],
			"ai": [0, 0, 0, 0],
		})
	return nodes


static func camera_bytes(heading: int) -> Dictionary:
	var yaw := yaw_byte(heading)
	return {
		"camera": [CAM_NORMAL, yaw, 0, 24, 0],
		"battle": [yaw, 0, 24],
	}


static func shot_bytes(sample: Dictionary, heading: int) -> Dictionary:
	if not sample.has("camera"):
		return camera_bytes(heading)
	var cam: Array = sample.camera
	var battle: Array = [int(cam[1]), int(cam[2]), int(cam[3])]
	if sample.has("battle_camera"):
		var stored: Array = sample.battle_camera
		battle = [int(stored[0]), int(stored[1]), int(stored[2])]
	return {
		"camera": [int(cam[0]), int(cam[1]), int(cam[2]), int(cam[3]), int(cam[4])],
		"battle": battle,
	}


static func slope_bytes(forward: Vector2, rise: float, run: float = float(CELL_U)) -> Array:
	var span := run if run > 1.0 else float(CELL_U)
	var normal := Vector3(-forward.x * rise, span, -forward.y * rise).normalized()
	var tilt := Vector2(atan2(normal.z, normal.y), asin(clampf(normal.x, -1.0, 1.0)))
	var scale := 16.0 * Car.ANGLE_TO_RAD
	return [roundi(tilt.y / scale), roundi(tilt.x / scale)]


static func build_grid(parts: Array, nodes: Array) -> Dictionary:
	var min_x := 0
	var max_x := 0
	var min_z := 0
	var max_z := 0
	for part: Dictionary in parts:
		min_x = mini(min_x, int(part.x))
		max_x = maxi(max_x, int(part.x))
		min_z = mini(min_z, int(part.z))
		max_z = maxi(max_z, int(part.z))
	var pad := 4
	var half_w := maxi(pad - min_x, max_x + pad + 1)
	var half_d := maxi(pad - min_z, max_z + pad + 1)
	var width := half_w * 2
	var depth := half_d * 2
	var header: Array = []
	header.resize(width * depth)
	header.fill(0)
	var blocks: Array = []
	var empty: Array = []
	empty.resize(16)
	empty.fill(0)
	blocks.append(empty)
	var best: Array = []
	best.resize(width * depth)
	for cell in width * depth:
		var scores: Array = []
		scores.resize(16)
		scores.fill(1.0e9)
		best[cell] = scores
	for node_index in nodes.size():
		var node: Dictionary = nodes[node_index]
		var hint := maxi(node_index, 1) << 7
		var units: Array = node.units
		var px := int(units[0])
		var pz := int(units[1])
		var h := int(node.heading) * Car.ANGLE_TO_RAD
		var forward := Vector2(-sin(h), -cos(h))
		var right := Vector2(cos(h), -sin(h))
		for along in range(-40, 41, 10):
			for side in range(-240, 241, 40):
				var x := roundi(px + forward.x * along + right.x * side)
				var z := roundi(pz + forward.y * along + right.y * side)
				var cx := (x + half_w * CELL_U) >> 9
				var cz := (z + half_d * CELL_U) >> 9
				if cx < 0 or cz < 0 or cx >= width or cz >= depth:
					continue
				var cell := cx + cz * width
				var sub := ((x >> 7) & 3) + ((z >> 7) & 3) * 4
				var dist := absi(along)
				var scores: Array = best[cell]
				if dist >= int(scores[sub]):
					continue
				scores[sub] = dist
				if int(header[cell]) == 0:
					var block: Array = []
					block.resize(16)
					block.fill(0)
					header[cell] = blocks.size()
					blocks.append(block)
				blocks[int(header[cell])][sub] = hint
	var zones: Array = []
	var zone_of := {}
	var covers := gate_coverage(nodes, half_w, half_d)
	for key: int in covers:
		var passes := node_passes(covers[key], nodes.size())
		if passes.size() < 2:
			continue
		assert(passes.size() == 2, "three passes of the track over one spot")
		var pair := Vector2i(wrapi(int(passes[0]) - 1, 0, nodes.size()), wrapi(int(passes[1]) - 1, 0, nodes.size()))
		if not zone_of.has(pair):
			zone_of[pair] = zones.size()
			zones.append([1, pair.x, pair.y])
		var cell := key >> 4
		if int(header[cell]) == 0:
			var block: Array = []
			block.resize(16)
			block.fill(0)
			header[cell] = blocks.size()
			blocks.append(block)
		blocks[int(header[cell])][key & 15] = 0x21 + int(zone_of[pair])
	assert(zones.size() <= 32, "more crossover zones than the grid holds")
	while zones.size() < 32:
		zones.append([0, 0, 0])
	var cells: Array = []
	cells.append_array(header)
	for block: Array in blocks:
		cells.append_array(block)
	return {"size": [width, depth], "zones": zones, "cells": cells}


# Grid sub-cells (cell << 4 | sub) whose centre lies between a node's gate and
# the next one, with the nodes that cover each.
static func gate_coverage(nodes: Array, half_w: int, half_d: int) -> Dictionary:
	var covers := {}
	var width := half_w * 2
	for i in nodes.size():
		var g: Array = nodes[i].gate_units
		var h: Array = nodes[(i + 1) % nodes.size()].gate_units
		var quad: Array[Vector2] = [Vector2(g[0], g[1]), Vector2(g[2], g[3]), Vector2(h[2], h[3]), Vector2(h[0], h[1])]
		var low := quad[0].min(quad[1]).min(quad[2]).min(quad[3])
		var high := quad[0].max(quad[1]).max(quad[2]).max(quad[3])
		for sx in range(floori(low.x / 128.0), ceili(high.x / 128.0) + 1):
			for sz in range(floori(low.y / 128.0), ceili(high.y / 128.0) + 1):
				var centre := Vector2(sx * 128 + 64, sz * 128 + 64)
				if not (Geometry2D.point_is_inside_triangle(centre, quad[0], quad[1], quad[2]) or Geometry2D.point_is_inside_triangle(centre, quad[0], quad[2], quad[3])):
					continue
				var x := sx * 128
				var z := sz * 128
				var cell := ((x + half_w * CELL_U) >> 9) + ((z + half_d * CELL_U) >> 9) * width
				var key := cell << 4 | (((x >> 7) & 3) + ((z >> 7) & 3) * 4)
				if not covers.has(key):
					covers[key] = []
				covers[key].append(i)
	return covers


# The first node of each separate stretch of the lap in the list, where
# stretches are runs of nodes no more than 12 apart around the loop.
static func node_passes(indices: Array, count: int) -> Array:
	var sorted := indices.duplicate()
	sorted.sort()
	var starts: Array = []
	for k in sorted.size():
		var before: int = sorted[(k + sorted.size() - 1) % sorted.size()]
		if wrapi(int(sorted[k]) - before, 0, count) > 12 or sorted.size() == 1:
			starts.append(sorted[k])
	if starts.is_empty():
		starts.append(sorted[0])
	return starts


static func loop_keys(loop: Array) -> Dictionary:
	var keys := {}
	for part: Dictionary in loop:
		keys[key_part(part)] = true
	return keys


static func mesh_bucket() -> Dictionary:
	return {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray(), "uv": PackedVector2Array()}


static func collect_mesh(parts: Array, loop: Array, tileset: String) -> Dictionary:
	var single := mesh_bucket()
	var double := mesh_bucket()
	var collision := PackedVector3Array()
	var surfaces := PackedByteArray()
	var on_loop := loop_keys(loop)
	var open := loop.is_empty()
	for part: Dictionary in parts:
		if int(part.piece) == Piece.SCENERY:
			stamp_piece(part, tileset, single, double, collision, surfaces)
		else:
			var before := collision.size()
			add_part(part, open or on_loop.has(key_part(part)), single, double, collision, tileset)
			var added := int((collision.size() - before) / 3.0)
			for _i in added:
				surfaces.append(0)
	return {"single": single, "double": double, "collision": collision, "surfaces": surfaces}


static func preview_mesh(parts: Array, tileset: String = "") -> ArrayMesh:
	var loop := trace(parts)
	var mesh := collect_mesh(parts, loop, tileset)
	var texture: Texture2D = null
	if tileset != "":
		texture = tileset_info(tileset).atlas
	return make_mesh(mesh, texture)


const FLOW_COLOR := Color(0.99, 0.88, 0.58)
const FLOW_START := Color(0.45, 0.95, 0.55)
const FLOW_ORIGIN := Color(0.18, 0.92, 0.28)
const FLOW_HOVER := Color(1.0, 0.98, 0.72)
const FLOW_PREVIEW := Color(0.99, 0.88, 0.58, 0.42)
const FLOW_BREAK := Color(1.0, 0.22, 0.28)
const FLOW_GATE := Color(0.55, 0.86, 1.0)
const FLOW_LIMIT := Color(0.55, 0.86, 1.0, 0.35)


static func flow_origin(part: Dictionary, tileset: String) -> Vector3:
	var y := layer_height(int(part.y))
	if tileset != "":
		y = cell_plane(int(part.y), tileset) + part_lift(part)
	return cell_center(int(part.x), int(part.z)) + part_nudge(part) + Vector3.UP * (y + 0.22)


static func flow_mesh(parts: Array, tileset: String = "", road: Array = [], line: Array = [], joined: bool = false, broken: bool = false, gaps: Array = []) -> ArrayMesh:
	var bucket := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	if not line.is_empty():
		draw_line_flow(bucket, line, joined, broken, gaps)
	elif road.is_empty():
		draw_linked_flow(bucket, parts, tileset)
	else:
		draw_road_flow(bucket, parts, tileset, road)
	var empty := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	return make_mesh({"single": bucket, "double": empty})


static func draw_linked_flow(bucket: Dictionary, parts: Array, tileset: String) -> void:
	var loop := trace(parts)
	var loop_at := {}
	for index in loop.size():
		loop_at[key_part(loop[index])] = index
	for part: Dictionary in parts:
		if not on_lap(part):
			continue
		var rot := int(part.rot) & 3
		if int(part.piece) == Piece.SCENERY:
			if not loop_at.has(key_part(part)):
				continue
			var index := int(loop_at[key_part(part)])
			var nxt: Dictionary = loop[(index + 1) % loop.size()]
			rot = step_rot(int(nxt.x) - int(part.x), int(nxt.z) - int(part.z))
		add_flow_arrow(bucket, flow_origin(part, tileset), rot, FLOW_COLOR)


static func draw_line_flow(bucket: Dictionary, line: Array, joined: bool, broken: bool = false, gaps: Array = []) -> void:
	var skip := {}
	for g in gaps:
		var gap := int(g)
		if gap > 0:
			skip[gap] = true
	var count := line.size()
	for index in count:
		var nxt := index + 1
		if nxt == count:
			if not joined:
				continue
			nxt = 0
		elif skip.has(nxt):
			continue
		var sample: Dictionary = line[index]
		var color := FLOW_START if index == 0 else FLOW_COLOR
		add_flow_link(bucket, flow_point(sample), flow_point(line[nxt]), color)
	for sample: Dictionary in line:
		draw_gate_span(bucket, sample)
	if line.is_empty():
		return
	var start: Dictionary = line[0]
	add_flow_marker(bucket, flow_point(start) + Vector3.UP * 0.05, FLOW_ORIGIN, metres(72.0))
	for g in gaps:
		var gap := int(g)
		if gap <= 0 or gap >= count:
			continue
		var tail := flow_point(line[gap - 1])
		var head := flow_point(line[gap])
		add_flow_marker(bucket, tail + Vector3.UP * 0.12, FLOW_BREAK, metres(48.0))
		add_break_cross(bucket, tail, head)
	if broken and not joined and count >= 2:
		var last: Dictionary = line[count - 1]
		var open_tail := flow_point(last)
		var open_head := flow_point(start)
		add_flow_marker(bucket, open_tail + Vector3.UP * 0.12, FLOW_BREAK, metres(48.0))
		add_break_cross(bucket, open_tail, open_head)


static func draw_gate_span(bucket: Dictionary, sample: Dictionary) -> void:
	var a := span_point(sample, "ax", "az")
	var b := span_point(sample, "bx", "bz")
	var past := (b - a) * (float(0x500) / 4096.0)
	add_flat_span(bucket, a - past, b + past, FLOW_LIMIT, 0.05)
	add_flat_span(bucket, a, b, FLOW_GATE, 0.1)
	add_flow_marker(bucket, a, FLOW_GATE, metres(22.0))
	add_flow_marker(bucket, b, FLOW_GATE, metres(22.0))


static func span_point(sample: Dictionary, x_key: String, z_key: String) -> Vector3:
	return Vector3(metres(float(sample[x_key])), metres(float(sample.y)) + 0.35, metres(float(sample[z_key])))


static func add_flat_span(bucket: Dictionary, a: Vector3, b: Vector3, color: Color, width: float) -> void:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length_squared() < 0.0001:
		return
	var side := flat.cross(Vector3.UP).normalized() * width
	add_quad(bucket, PackedVector3Array(), a - side, a + side, b + side, b - side, color, false, true)


static func flow_point(sample: Dictionary) -> Vector3:
	return Vector3(metres(float(sample.x)), metres(float(sample.y)) + 0.6, metres(float(sample.z)))


static func add_break_cross(bucket: Dictionary, a: Vector3, b: Vector3) -> void:
	var mid := a.lerp(b, 0.5) + Vector3.UP * 0.25
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(1.0, 0.0, 0.0)
	flat = flat.normalized()
	var side := flat.cross(Vector3.UP).normalized()
	var reach := 0.75
	var thick := 0.1
	add_quad(bucket, PackedVector3Array(), mid - flat * reach - side * thick, mid - flat * reach + side * thick, mid + flat * reach + side * thick, mid + flat * reach - side * thick, FLOW_BREAK, false, true)
	add_quad(bucket, PackedVector3Array(), mid - side * reach - flat * thick, mid - side * reach + flat * thick, mid + side * reach + flat * thick, mid + side * reach - flat * thick, FLOW_BREAK, false, true)


static func road_surface(part: Dictionary, tileset: String) -> Vector3:
	var center := cell_center(int(part.x), int(part.z))
	return Vector3(center.x, metres(floor_units(part, tileset)) + 0.6, center.z)


static func draw_road_flow(bucket: Dictionary, parts: Array, tileset: String, road: Array) -> void:
	var chain := road_parts(parts, road)
	var closed := not trace(parts, road).is_empty()
	var limit := 0
	if closed:
		limit = chain.size()
	elif chain.size() > 1:
		limit = chain.size() - 1
	var linked := {}
	for i in limit:
		var a: Dictionary = chain[i]
		var b: Dictionary = chain[(i + 1) % chain.size()]
		if a.is_empty() or b.is_empty() or not road_step(a, b):
			continue
		linked[i] = true
		var color := FLOW_START if i == 0 else FLOW_COLOR
		add_flow_link(bucket, road_surface(a, tileset), road_surface(b, tileset), color)
	for i in chain.size():
		if linked.has(i):
			continue
		var part: Dictionary = chain[i]
		if part.is_empty():
			continue
		var color := FLOW_START if i == 0 else FLOW_COLOR
		add_flow_marker(bucket, road_surface(part, tileset), color)


static func visual_buckets(parts: Array, tileset: String, show_lap: bool = false) -> Dictionary:
	var single := mesh_bucket()
	var double := mesh_bucket()
	var discard := PackedVector3Array()
	for part: Dictionary in parts:
		var tint := Color.WHITE
		if show_lap:
			tint = LAP_ON_TINT if on_lap(part) else LAP_OFF_TINT
		if int(part.piece) == Piece.SCENERY:
			stamp_visual(part, tileset, single, double, tint)
		else:
			add_part(part, true, single, double, discard, tileset, tint)
	return {"single": single, "double": double}


static func stamp_visual(part: Dictionary, tileset: String, single: Dictionary, double: Dictionary, tint: Color = Color.WHITE) -> void:
	var mesh: Dictionary = part_mesh(part, tileset)
	var origin := cell_center(int(part.x), int(part.z)) + part_nudge(part)
	origin.y = cell_plane(int(part.y), tileset) + part_lift(part)
	var rot := int(part.rot) & 3
	var flags := int(part.mirror)
	var flip := flags == 1 or flags == 2
	copy_baked(mesh.single, single, origin, rot, flags, flip, tint)
	copy_baked(mesh.double, double, origin, rot, flags, flip, tint)


static func stamp_piece(part: Dictionary, tileset: String, single: Dictionary, double: Dictionary, collision: PackedVector3Array, surfaces: PackedByteArray) -> void:
	var mesh: Dictionary = part_mesh(part, tileset)
	var origin := cell_center(int(part.x), int(part.z)) + part_nudge(part)
	origin.y = cell_plane(int(part.y), tileset) + part_lift(part)
	var rot := int(part.rot) & 3
	var flags := int(part.mirror)
	var flip := flags == 1 or flags == 2
	copy_baked(mesh.single, single, origin, rot, flags, flip)
	copy_baked(mesh.double, double, origin, rot, flags, flip)
	var baked: PackedVector3Array = mesh.collision
	var kinds: PackedByteArray = mesh.surfaces
	var tri := 0
	var i := 0
	while i < baked.size():
		var a := origin + orient_point(baked[i], rot, flags)
		var b := origin + orient_point(baked[i + 1], rot, flags)
		var c := origin + orient_point(baked[i + 2], rot, flags)
		if flip:
			var swap := b
			b = c
			c = swap
		collision.append(a)
		collision.append(b)
		collision.append(c)
		surfaces.append(kinds[tri])
		tri += 1
		i += 3


static func apply_lap_tint(color: Color, tint: Color) -> Color:
	if tint == Color.WHITE:
		return color
	var mixed := tint
	mixed.a = color.a
	return mixed


static func copy_baked(src: Dictionary, bucket: Dictionary, origin: Vector3, rot: int, flags: int, flip: bool, tint: Color = Color.WHITE) -> void:
	var pos: PackedVector3Array = src.pos
	var nrm: PackedVector3Array = src.nrm
	var col: PackedColorArray = src.col
	var uv: PackedVector2Array = src.uv
	var dst_pos: PackedVector3Array = bucket.pos
	var dst_nrm: PackedVector3Array = bucket.nrm
	var dst_col: PackedColorArray = bucket.col
	var dst_uv: PackedVector2Array = bucket.uv
	var t := 0
	while t < pos.size():
		var order: Array[int] = [0, 1, 2]
		if flip:
			order = [0, 2, 1]
		for k in order:
			var i: int = t + k
			dst_pos.append(origin + orient_point(pos[i], rot, flags))
			dst_nrm.append(orient_point(nrm[i], rot, flags))
			dst_col.append(apply_lap_tint(col[i], tint))
			dst_uv.append(uv[i])
		t += 3


static func add_flow_link(bucket: Dictionary, a: Vector3, b: Vector3, color: Color) -> void:
	var flat := Vector3(b.x - a.x, 0.0, b.z - a.z)
	if flat.length_squared() < 0.0001:
		var climb := Vector3(0.22, 0.0, 0.0)
		add_quad(bucket, PackedVector3Array(), a - climb, a + climb, b + climb, b - climb, color, false, true)
		return
	var side := flat.cross(Vector3.UP).normalized()
	var neck := a.lerp(b, 0.72)
	var shaft := side * 0.28
	var head := side * 0.62
	add_quad(bucket, PackedVector3Array(), a - shaft, a + shaft, neck + shaft, neck - shaft, color, false, true)
	add_quad(bucket, PackedVector3Array(), neck - head, neck + head, b, b, color, false, true)


static func add_flow_arrow(bucket: Dictionary, origin: Vector3, rot: int, color: Color) -> void:
	var axes := flat_axes(rot)
	var forward: Vector2 = axes[0]
	var right: Vector2 = axes[1]
	var tip := origin + Vector3(metres(forward.x * 150.0), 0.0, metres(forward.y * 150.0))
	var base := origin - Vector3(metres(forward.x * 30.0), 0.0, metres(forward.y * 30.0))
	var wing := Vector3(metres(right.x * 64.0), 0.0, metres(right.y * 64.0))
	add_quad(bucket, PackedVector3Array(), base - wing, base + wing, tip, tip, color, false, true)


static func road_guide(line: Array, hover: int, preview: Vector3, show_preview: bool, span_at: int = -1, span_end: int = 0, anchor: int = -1) -> ArrayMesh:
	var bucket := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	if show_preview:
		if line.is_empty():
			add_flow_marker(bucket, preview, FLOW_PREVIEW)
		else:
			var index := line.size() - 1
			if anchor >= 0 and anchor < line.size():
				index = anchor
			var last: Dictionary = line[index]
			var from := Vector3(metres(float(last.x)), metres(float(last.y)) + 0.6, metres(float(last.z)))
			add_flow_link(bucket, from, preview, FLOW_PREVIEW)
			add_flow_marker(bucket, preview, FLOW_PREVIEW)
	if hover >= 0 and hover < line.size():
		var sample: Dictionary = line[hover]
		var at := Vector3(metres(float(sample.x)), metres(float(sample.y)) + 0.9, metres(float(sample.z)))
		add_flow_marker(bucket, at, FLOW_HOVER, metres(36.0))
	if span_at >= 0 and span_at < line.size():
		var chosen: Dictionary = line[span_at]
		var end := span_point(chosen, "ax" if span_end == 0 else "bx", "az" if span_end == 0 else "bz")
		add_flow_marker(bucket, end + Vector3.UP * 0.15, FLOW_HOVER, metres(40.0))
	var empty := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	return make_mesh({"single": bucket, "double": empty})


static func add_flow_marker(bucket: Dictionary, origin: Vector3, color: Color, span: float = -1.0) -> void:
	var s := metres(56.0) if span < 0.0 else span
	add_quad(bucket, PackedVector3Array(), origin + Vector3(-s, 0.0, 0.0), origin + Vector3(0.0, 0.0, -s), origin + Vector3(s, 0.0, 0.0), origin + Vector3(0.0, 0.0, s), color, false, true)


static func tile_thumb_mesh(tileset: String, tile_index: int) -> ArrayMesh:
	var tile: Dictionary = tile_def(tileset, tile_index)
	if not tile.has("cells"):
		return tile_preview_mesh(tileset, int(tile.mesh))
	return preview_mesh(footprint_parts(tileset, tile_index, 0, 0, 0, 0, 0, true), tileset)


static func tile_preview_mesh(tileset: String, mesh_index: int) -> ArrayMesh:
	var info := tileset_info(tileset)
	if preview_meshes.has(mesh_index):
		return preview_meshes[mesh_index]
	var src: Dictionary = packed_meshes[mesh_index]
	var single := mesh_bucket()
	var double := mesh_bucket()
	copy_baked(src.single, single, Vector3.ZERO, 0, 0, false)
	copy_baked(src.double, double, Vector3.ZERO, 0, 0, false)
	var built := make_mesh({"single": single, "double": double}, info.atlas)
	preview_meshes[mesh_index] = built
	return built


static func make_mesh(mesh: Dictionary, texture: Texture2D = null) -> ArrayMesh:
	var out := ArrayMesh.new()
	add_surface(out, mesh.single, false, texture)
	add_surface(out, mesh.double, true, texture)
	return out


static func add_surface(mesh: ArrayMesh, bucket: Dictionary, double_sided: bool, texture: Texture2D = null) -> void:
	var pos: PackedVector3Array = bucket.pos
	if pos.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = bucket.nrm
	arrays[Mesh.ARRAY_COLOR] = bucket.col
	var uvs: PackedVector2Array = bucket.uv if bucket.has("uv") else PackedVector2Array()
	if uvs.size() != pos.size():
		uvs = PackedVector2Array()
		uvs.resize(pos.size())
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	if texture != null:
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
	material.roughness = 1.0
	material.metallic_specular = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED if double_sided else BaseMaterial3D.CULL_BACK
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)


static func add_part(part: Dictionary, on_loop: bool, single: Dictionary, double: Dictionary, collision: PackedVector3Array, tileset: String = "", tint: Color = Color.WHITE) -> void:
	var piece := int(part.piece)
	var rot := int(part.rot) & 3
	var center := cell_center(int(part.x), int(part.z))
	var y := cell_plane(int(part.y), tileset) if tileset != "" else layer_height(int(part.y))
	var half := metres(256.0)
	if piece == Piece.WALL:
		var tall := metres(LAYER_U * 2.0)
		var wall := apply_lap_tint(WALL_COLOR, tint)
		add_box(double, collision, center + Vector3(0, y + tall * 0.5, 0), Vector3(half * 2.0, tall, half * 2.0), wall, true)
		return
	var color := FLOOR_COLOR
	if not on_loop and is_road(piece):
		color = OFF_LOOP_COLOR
	elif piece == Piece.START:
		color = START_COLOR
	elif piece == Piece.RAMP:
		color = RAMP_UP_COLOR if int(part.slope) >= 0 else RAMP_DOWN_COLOR
	color = apply_lap_tint(color, tint)
	if piece == Piece.RAMP:
		var axes := flat_axes(rot)
		var forward: Vector2 = axes[0]
		var right: Vector2 = axes[1]
		var fwd := Vector3(metres(forward.x * 256.0), 0.0, metres(forward.y * 256.0))
		var side := Vector3(metres(right.x * 256.0), 0.0, metres(right.y * 256.0))
		var exit := layer_height(int(part.y) + int(part.slope))
		var back := Vector3(center.x, 0.0, center.z) - fwd
		var front := Vector3(center.x, 0.0, center.z) + fwd
		var bl := back - side + Vector3.UP * y
		var br := back + side + Vector3.UP * y
		var fr := front + side + Vector3.UP * exit
		var fl := front - side + Vector3.UP * exit
		add_quad(single, collision, bl, br, fr, fl, color, true, true)
		return
	var a := center + Vector3(-half, y, -half)
	var b := center + Vector3(half, y, -half)
	var c := center + Vector3(half, y, half)
	var d := center + Vector3(-half, y, half)
	add_quad(single, collision, a, b, c, d, color, true, true)
	var rim := half - metres(28.0)
	var inset_a := center + Vector3(-rim, y + 0.02, -rim)
	var inset_b := center + Vector3(rim, y + 0.02, -rim)
	var inset_c := center + Vector3(rim, y + 0.02, rim)
	var inset_d := center + Vector3(-rim, y + 0.02, rim)
	add_quad(single, PackedVector3Array(), a, b, inset_b, inset_a, RIM_COLOR, false, true)
	add_quad(single, PackedVector3Array(), b, c, inset_c, inset_b, RIM_COLOR, false, true)
	add_quad(single, PackedVector3Array(), c, d, inset_d, inset_c, RIM_COLOR, false, true)
	add_quad(single, PackedVector3Array(), d, a, inset_a, inset_d, RIM_COLOR, false, true)
	if piece == Piece.START:
		add_arrow(single, part, y + 0.05)
		var axes := flat_axes(rot)
		var right: Vector2 = axes[1]
		var side := Vector3(metres(right.x * 220.0), 0.0, metres(right.y * 220.0))
		var thin := Vector3(metres(axes[0].x * 36.0), 0.0, metres(axes[0].y * 36.0))
		var lift := Vector3.UP * (y + 0.05)
		add_quad(single, collision, center - side - thin + lift, center + side - thin + lift, center + side + thin + lift, center - side + thin + lift, STRIPE_COLOR, false, true)


static func add_arrow(bucket: Dictionary, part: Dictionary, y: float) -> void:
	var axes := flat_axes(int(part.rot) & 3)
	var forward: Vector2 = axes[0]
	var right: Vector2 = axes[1]
	var center := cell_center(int(part.x), int(part.z))
	var tip := center + Vector3(metres(forward.x * 140.0), y, metres(forward.y * 140.0))
	var base := center - Vector3(metres(forward.x * 40.0), -y, metres(forward.y * 40.0))
	var wing := Vector3(metres(right.x * 70.0), 0.0, metres(right.y * 70.0))
	add_quad(bucket, PackedVector3Array(), base - wing, base + wing, tip, tip, ARROW_COLOR, false, true)


static func camera_view_mesh(line: Array, hot: int = -1) -> ArrayMesh:
	var bucket := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	for i in line.size():
		var sample: Dictionary = line[i]
		if not sample.has("camera"):
			continue
		var cam: Array = sample.camera
		var focus := Vector3(metres(float(sample.x)), metres(float(sample.y)), metres(float(sample.z)))
		var shot := TrackCamera.preview_shot(int(cam[1]), int(cam[2]), int(cam[3]), int(cam[0]), focus)
		var color := camera_type_color(int(cam[0]))
		var width := 0.06
		if i == hot:
			color.a = 1.0
			width = 0.16
		var eye: Vector3 = shot.eye
		var look: Vector3 = shot.look
		if eye.distance_squared_to(look) < 0.05:
			continue
		add_beam(bucket, eye, look, width, color)
		add_camera_body(bucket, eye, shot.forward, shot.up, shot.right, color)
		add_flow_marker(bucket, focus + Vector3.UP * 0.35, color, 0.55 if i == hot else 0.35)
	var empty := {"pos": PackedVector3Array(), "nrm": PackedVector3Array(), "col": PackedColorArray()}
	return make_mesh({"single": bucket, "double": empty})


static func camera_type_color(type: int) -> Color:
	if type == CAM_EDGE:
		return Color(0.93, 0.4, 0.26, 0.85)
	if type == CAM_TIGHT:
		return Color(0.35, 0.75, 0.95, 0.85)
	var color := CAMERA_COLOR
	color.a = 0.8
	return color


static func add_beam(bucket: Dictionary, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var span := b - a
	if span.length_squared() < 0.0001:
		return
	var dir := span.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var lift := dir.cross(side).normalized()
	add_quad(bucket, PackedVector3Array(), a - side * width, a + side * width, b + side * width, b - side * width, color, false, false)
	add_quad(bucket, PackedVector3Array(), a - lift * width, a + lift * width, b + lift * width, b - lift * width, color, false, false)


static func add_camera_body(bucket: Dictionary, eye: Vector3, forward: Vector3, up: Vector3, right: Vector3, color: Color) -> void:
	var f := forward.normalized()
	var u := up.normalized()
	var r := right.normalized()
	var depth := 1.15
	var w := 0.62
	var h := 0.46
	var back := eye - f * (depth * 0.55)
	var front := eye + f * (depth * 0.45)
	var bw := r * w
	var bh := u * h
	var fw := r * (w * 0.7)
	var fh := u * (h * 0.7)
	add_quad(bucket, PackedVector3Array(), back - bw - bh, back + bw - bh, back + bw + bh, back - bw + bh, color, false, false)
	add_quad(bucket, PackedVector3Array(), front - fw - fh, front + fw - fh, front + fw + fh, front - fw + fh, color, false, false)
	add_quad(bucket, PackedVector3Array(), back - bw - bh, front - fw - fh, front + fw - fh, back + bw - bh, color, false, false)
	add_quad(bucket, PackedVector3Array(), back - bw + bh, back + bw + bh, front + fw + fh, front - fw + fh, color, false, false)
	add_quad(bucket, PackedVector3Array(), back - bw - bh, back - bw + bh, front - fw + fh, front - fw - fh, color, false, false)
	add_quad(bucket, PackedVector3Array(), back + bw - bh, front + fw - fh, front + fw + fh, back + bw + bh, color, false, false)
	var lens := front + f * 0.38
	var lw := r * 0.32
	var lh := u * 0.32
	add_quad(bucket, PackedVector3Array(), front - lw - lh, front + lw - lh, lens, lens, color, false, false)
	add_quad(bucket, PackedVector3Array(), front - lw + lh, front - lw - lh, lens, lens, color, false, false)
	add_quad(bucket, PackedVector3Array(), front + lw + lh, front - lw + lh, lens, lens, color, false, false)
	add_quad(bucket, PackedVector3Array(), front + lw - lh, front + lw + lh, lens, lens, color, false, false)


static func add_box(bucket: Dictionary, collision: PackedVector3Array, center: Vector3, size: Vector3, color: Color, collide: bool) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var p := [
		center + Vector3(-hx, -hy, -hz),
		center + Vector3(hx, -hy, -hz),
		center + Vector3(hx, -hy, hz),
		center + Vector3(-hx, -hy, hz),
		center + Vector3(-hx, hy, -hz),
		center + Vector3(hx, hy, -hz),
		center + Vector3(hx, hy, hz),
		center + Vector3(-hx, hy, hz),
	]
	add_quad(bucket, collision, p[4], p[5], p[6], p[7], color, collide, true)
	add_quad(bucket, collision, p[1], p[0], p[3], p[2], color, collide, false)
	add_quad(bucket, collision, p[0], p[1], p[5], p[4], color, collide, false)
	add_quad(bucket, collision, p[2], p[3], p[7], p[6], color, collide, false)
	add_quad(bucket, collision, p[1], p[2], p[6], p[5], color, collide, false)
	add_quad(bucket, collision, p[3], p[0], p[4], p[7], color, collide, false)


static func add_quad(bucket: Dictionary, collision: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, collide: bool, face_up: bool) -> void:
	add_tri(bucket, collision, a, b, c, color, collide, face_up)
	add_tri(bucket, collision, a, c, d, color, collide, face_up)


static func add_tri(bucket: Dictionary, collision: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, color: Color, collide: bool, face_up: bool) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 1e-10:
		return
	if face_up and normal.y < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	var wound := b
	b = c
	c = wound
	normal = normal.normalized()
	var pos: PackedVector3Array = bucket.pos
	var nrm: PackedVector3Array = bucket.nrm
	var col: PackedColorArray = bucket.col
	pos.append(a)
	pos.append(b)
	pos.append(c)
	nrm.append(normal)
	nrm.append(normal)
	nrm.append(normal)
	col.append(color)
	col.append(color)
	col.append(color)
	if bucket.has("uv"):
		var uvs: PackedVector2Array = bucket.uv
		uvs.append(Vector2.ZERO)
		uvs.append(Vector2.ZERO)
		uvs.append(Vector2.ZERO)
	if collide:
		collision.append(a)
		collision.append(b)
		collision.append(c)


static func write_mesh(path: String, mesh: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	write_bucket(file, mesh.single)
	write_bucket(file, mesh.double)


static func write_bucket(file: FileAccess, bucket: Dictionary) -> void:
	var pos: PackedVector3Array = bucket.pos
	var nrm: PackedVector3Array = bucket.nrm
	var col: PackedColorArray = bucket.col
	var uvs: PackedVector2Array = bucket.uv if bucket.has("uv") else PackedVector2Array()
	file.store_32(pos.size())
	for i in pos.size():
		var p: Vector3 = pos[i]
		var n: Vector3 = nrm[i]
		var color: Color = col[i]
		file.store_float(p.x)
		file.store_float(p.y)
		file.store_float(p.z)
		file.store_float(n.x)
		file.store_float(n.y)
		file.store_float(n.z)
		file.store_float(color.r)
		file.store_float(color.g)
		file.store_float(color.b)
		file.store_float(color.a)
		if uvs.size() == pos.size():
			file.store_float(uvs[i].x)
			file.store_float(uvs[i].y)
		else:
			file.store_float(0.0)
			file.store_float(0.0)


static func write_collision(path: String, triangles: PackedVector3Array, surfaces: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	var count := int(triangles.size() / 3.0)
	file.store_32(count)
	for p in triangles:
		file.store_float(p.x)
		file.store_float(p.y)
		file.store_float(p.z)
	for i in count:
		file.store_8(surfaces[i])
