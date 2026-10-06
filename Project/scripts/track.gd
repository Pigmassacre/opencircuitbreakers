@tool
class_name Track
extends Node3D

# Loads a track exported from the PS1 data by Inspo/re/export_track.py.
# mesh.bin holds two triangle lists (single-sided, double-sided), each prefixed
# by its vertex count; every vertex is 12 floats: position, normal, color, uv.

const VERTEX_FLOATS := 12
const LOST_DISTANCE := 40.0
const TEXTURED := "textured"

var nodes: Array = []
var node_grid: Dictionary
var node_cells := PackedInt32Array()
var respawn_ranges: Array = []
var sky_color := Color.WHITE
var handling: Array = []
var water_level := -INF
var water_regions: Array = []
var surfaces := PackedByteArray()
var script_tokens := PackedInt32Array()
var objects := PackedInt32Array()
var object_meshes: Dictionary[int, ArrayMesh] = {}
var pickups: Array = []
var scrolls: Array = []
var flip_entries: Array = []
var flip_groups: Array = []
var flip_count := PackedInt32Array()
var flip_index := PackedInt32Array()
var scroll_clock := 0
var weather := 0
var texture_pause := false
var water_units := 0x7fffffff
var animate_textures := false
var atlas_image: Image
var atlas_texture: ImageTexture
var flip_image: Image
var flip_bank := {}
var flip_ids := PackedInt32Array()
var ai_thresholds: Array[PackedInt32Array] = []
var ai_speeds: Array[PackedInt32Array] = []
var ai_race := false
# FUN_00026628: the rough-node rumble only runs where under 36% of nodes carry flag bit 0.
var rough_nodes := false
var ai_start := PackedInt32Array([0, 0])
var gate_fraction := 0
var edge_fraction := 0
var textured: Array[StandardMaterial3D] = []
var body: StaticBody3D


func read_text(path: String) -> String:
	if Engine.is_editor_hint() or path.begins_with("user://"):
		return FileAccess.get_file_as_string(path)
	return Data.text(path)


func read_bytes(path: String) -> PackedByteArray:
	if Engine.is_editor_hint() or path.begins_with("user://"):
		return FileAccess.get_file_as_bytes(path)
	return Data.bytes(path)


func load_from(dir: String, collide := true) -> void:
	var info: Dictionary = JSON.parse_string(read_text(dir + "/track.json"))
	nodes = info.nodes
	for node: Dictionary in nodes:
		node.camera = node.camera.map(func(value: float) -> int: return int(value))
		node.battle_camera = node.battle_camera.map(func(value: float) -> int: return int(value))
		node.gate_units = node.gate_units.map(func(value: float) -> int: return int(value))
		node.units = node.units.map(func(value: float) -> int: return int(value))
		node.lift = node.lift.map(func(value: float) -> int: return int(value))
		node.lane_lift = node.lane_lift.map(func(value: float) -> int: return int(value))
		node.slope = node.slope.map(func(value: float) -> int: return int(value))
		node.ai = node.ai.map(func(value: float) -> int: return int(value))
		node.flags = int(node.flags)
	var flagged := 0
	for node: Dictionary in nodes:
		flagged += node.flags & 1
	rough_nodes = flagged * 100 / nodes.size() < 0x24
	for row: Array in info.ai_thresholds:
		ai_thresholds.append(PackedInt32Array(row))
	for row: Array in info.ai_speeds:
		ai_speeds.append(PackedInt32Array(row))
	ai_race = info.ai_start != null
	if ai_race:
		ai_start = PackedInt32Array(info.ai_start)
	if info.pickups != null:
		pickups = info.pickups.map(func(entry: Array) -> PackedInt32Array: return PackedInt32Array(entry))
	node_grid = info.node_grid
	node_cells = PackedInt32Array(node_grid.cells)
	respawn_ranges = info.respawn_ranges
	sky_color = Color(info.sky[0], info.sky[1], info.sky[2])
	handling = info.handling.map(func(value: float) -> int: return int(value))
	if info.water != null:
		water_level = info.water
		water_units = int(round(water_level / Car.UNIT_METRES))
	water_regions = info.water_regions
	scrolls = info.scrolls
	flip_entries = info.flip_entries
	flip_groups = info.flip_groups
	flip_count.resize(flip_groups.size())
	flip_index.resize(flip_groups.size())
	weather = int(info.weather)
	texture_pause = info.texture_pause
	flip_ids.resize(16)
	for i in 16:
		flip_ids[i] = i
	for row: Array in info.flip_bank:
		flip_bank["%d:%d" % [int(row[0]), int(row[1])]] = row
	script_tokens = PackedInt32Array(info.script)
	for entry: Array in info.objects:
		objects.append_array(PackedInt32Array(entry))

	var source := Image.new()
	source.load_png_from_buffer(read_bytes(dir + "/atlas.png"))
	var atlas: Texture2D = ImageTexture.create_from_image(source)
	if scrolls.size() > 0 or flip_groups.size() > 0:
		animate_textures = true
		atlas_image = source
		atlas_texture = atlas
		if flip_bank.size() > 0:
			flip_image = Image.new()
			flip_image.load_png_from_buffer(read_bytes(dir + "/flip.png"))
	var materials: Array[StandardMaterial3D] = [track_material(atlas, BaseMaterial3D.CULL_BACK), track_material(atlas, BaseMaterial3D.CULL_DISABLED)]
	textured = materials
	add_to_group(TEXTURED)
	var bytes := read_bytes(dir + "/mesh.bin")
	var mesh := ArrayMesh.new()
	var faces := PackedVector3Array()
	var offset := 0
	for material in materials:
		var positions := read_surface(mesh, bytes, offset, material)
		offset += 4 + positions.size() * VERTEX_FLOATS * 4
		faces.append_array(positions)

	bytes = read_bytes(dir + "/objects.bin")
	offset = 0
	for model: float in info.object_models:
		var object_mesh := ArrayMesh.new()
		for material in materials:
			offset += 4 + read_surface(object_mesh, bytes, offset, material).size() * VERTEX_FLOATS * 4
		object_meshes[int(model)] = object_mesh

	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	add_child(instance)
	if not collide:
		return

	# FUN_00044a88 tests the collision-block faces. collision.bin is those faces,
	# split the same way as the drawn quads.
	var collision_bytes := read_bytes(dir + "/collision.bin")
	var tri_count := collision_bytes.decode_s32(0)
	var floats := collision_bytes.slice(4, 4 + tri_count * 9 * 4).to_float32_array()
	var surface_at := 4 + tri_count * 9 * 4
	var floor_faces := PackedVector3Array()
	var wall_faces := PackedVector3Array()
	surfaces = PackedByteArray()
	var floor_cos := cos(Car.HARD_SURFACE_CHANGE)
	for i in tri_count:
		var f := i * 9
		var a := Vector3(floats[f], floats[f + 1], floats[f + 2])
		var b := Vector3(floats[f + 3], floats[f + 4], floats[f + 5])
		var c := Vector3(floats[f + 6], floats[f + 7], floats[f + 8])
		var n := (b - a).cross(c - a)
		if n.length_squared() < 1e-12:
			continue
		if absf(n.normalized().y) >= floor_cos:
			floor_faces.append(a)
			floor_faces.append(b)
			floor_faces.append(c)
			surfaces.append(collision_bytes[surface_at + i])
		else:
			wall_faces.append(a)
			wall_faces.append(b)
			wall_faces.append(c)
	body = add_collision(floor_faces, Car.GROUND_LAYER)
	add_collision(wall_faces, 1)


func read_surface(mesh: ArrayMesh, bytes: PackedByteArray, offset: int, material: Material) -> PackedVector3Array:
	var count := bytes.decode_s32(offset)
	var floats := bytes.slice(offset + 4, offset + 4 + count * VERTEX_FLOATS * 4).to_float32_array()
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	positions.resize(count)
	normals.resize(count)
	colors.resize(count)
	uvs.resize(count)
	for i in count:
		var f := i * VERTEX_FLOATS
		positions[i] = Vector3(floats[f], floats[f + 1], floats[f + 2])
		normals[i] = Vector3(floats[f + 3], floats[f + 4], floats[f + 5])
		colors[i] = Color(floats[f + 6], floats[f + 7], floats[f + 8], floats[f + 9])
		uvs[i] = Vector2(floats[f + 10], floats[f + 11])
	if count == 0:
		return positions
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return positions


# Cars only collide with walls; they follow the floor with a ray, like the
# original's point sampling, so slopes never catch the car's body.
func add_collision(triangles: PackedVector3Array, layer: int) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(triangles)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var static_body := StaticBody3D.new()
	static_body.collision_layer = layer
	static_body.collision_mask = 0
	static_body.add_child(collision)
	add_child(static_body)
	return static_body


func water_height(point: Vector3) -> float:
	for region: Array in water_regions:
		if point.x >= region[0] and point.z >= region[1] and point.x < region[2] and point.z < region[3]:
			return region[4]
	return water_level


func surface_of(hit: Dictionary) -> int:
	if hit.collider != body:
		return 0
	return surfaces[hit.face_index]


# FUN_0003063c / FUN_00030b00 scroll the exported VRAM rectangles. FUN_0003077c
# rotates flipbook frames when a group's counter reaches that frame's period.
# Snow tracks (texture_pause) run the scroll on 32 of every 64 game frames.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME != 0:
		return
	step_textures()
	var cam := get_viewport().get_camera_3d()
	if weather != 0 and cam is TrackCamera:
		Fx.weather_frame(self, cam)
	Fx.world_frame()


func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	Fx.clear_world()


func step_textures() -> void:
	if not animate_textures:
		return
	scroll_clock += 1
	var moved := false
	if not texture_pause or (scroll_clock & 0x20) == 0:
		for scroll: Dictionary in scrolls:
			for rect: Array in scroll.rects:
				if scroll_rect(rect, int(scroll.dir), int(scroll.step)):
					moved = true
	for g in flip_groups.size():
		var count := flip_count[g]
		if count > 100:
			count = 0
		count += 1
		var index := flip_index[g]
		var entry: Dictionary = flip_entries[index]
		if count == int(entry.period):
			var start := int(flip_groups[g][0])
			var ending := int(flip_groups[g][1])
			if rotate_frames(start, ending):
				moved = true
			index += 1
			if index > ending:
				index = start
			count = 0
		flip_count[g] = count
		flip_index[g] = index
	if moved:
		atlas_texture.update(atlas_image)


func scroll_rect(rect: Array, dir: int, step: int) -> bool:
	var x := int(rect[0])
	var y := int(rect[1])
	var w := int(rect[2])
	var h := int(rect[3])
	if dir < 2:
		if step <= 0 or step >= w:
			return false
		if dir == 0:
			var body := atlas_image.get_region(Rect2i(x + step, y, w - step, h))
			var wrap := atlas_image.get_region(Rect2i(x, y, step, h))
			atlas_image.blit_rect(body, Rect2i(0, 0, w - step, h), Vector2i(x, y))
			atlas_image.blit_rect(wrap, Rect2i(0, 0, step, h), Vector2i(x + w - step, y))
		else:
			var body := atlas_image.get_region(Rect2i(x, y, w - step, h))
			var wrap := atlas_image.get_region(Rect2i(x + w - step, y, step, h))
			atlas_image.blit_rect(body, Rect2i(0, 0, w - step, h), Vector2i(x + step, y))
			atlas_image.blit_rect(wrap, Rect2i(0, 0, step, h), Vector2i(x, y))
	else:
		if step <= 0 or step >= h:
			return false
		if dir == 2:
			var body := atlas_image.get_region(Rect2i(x, y + step, w, h - step))
			var wrap := atlas_image.get_region(Rect2i(x, y, w, step))
			atlas_image.blit_rect(body, Rect2i(0, 0, w, h - step), Vector2i(x, y))
			atlas_image.blit_rect(wrap, Rect2i(0, 0, w, step), Vector2i(x, y + h - step))
		else:
			var body := atlas_image.get_region(Rect2i(x, y, w, h - step))
			var wrap := atlas_image.get_region(Rect2i(x, y + h - step, w, step))
			atlas_image.blit_rect(body, Rect2i(0, 0, w, h - step), Vector2i(x, y + step))
			atlas_image.blit_rect(wrap, Rect2i(0, 0, w, step), Vector2i(x, y))
	return true


func rotate_frames(start: int, ending: int) -> bool:
	var turned := false
	for frame in range(start, ending):
		var a: Dictionary = flip_entries[frame]
		var b: Dictionary = flip_entries[frame + 1]
		var aw := int(a.vram[2])
		var ah := int(a.vram[3])
		if aw != int(b.vram[2]) or ah != int(b.vram[3]) or aw <= 0 or ah <= 0:
			continue
		var held := flip_ids[frame]
		flip_ids[frame] = flip_ids[frame + 1]
		flip_ids[frame + 1] = held
		turned = true
	if not turned:
		return false
	for frame in range(start, ending + 1):
		var entry: Dictionary = flip_entries[frame]
		var image := flip_ids[frame]
		for rect: Array in entry.rects:
			var src: Array = flip_bank["%d:%d" % [image, int(rect[4])]]
			var w := int(rect[2])
			var h := int(rect[3])
			var crop := flip_image.get_region(Rect2i(int(src[2]), int(src[3]), int(src[4]), int(src[5])))
			atlas_image.blit_rect(crop, Rect2i(0, 0, w, h), Vector2i(int(rect[0]), int(rect[1])))
	return true


func track_material(atlas: Texture2D, cull: BaseMaterial3D.CullMode) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = atlas
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if Engine.is_editor_hint() else Settings.material_filter()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = cull
	material.roughness = 1.0
	material.metallic_specular = 0.0
	return material


func node_position(index: int) -> Vector3:
	var node: Dictionary = nodes[index % nodes.size()]
	return Vector3(node.position[0], node.position[1], node.position[2])


func nearest_node(point: Vector3) -> int:
	var best := 0
	for i in nodes.size():
		if node_position(i).distance_squared_to(point) < node_position(best).distance_squared_to(point):
			best = i
	return best


# FUN_000388c4: a node inside a jump, or two behind one, restarts at the jump's start.
func respawn_node(node: int) -> int:
	var count := nodes.size()
	var moved := true
	while moved:
		moved = false
		var back := wrapi(node - 2, 0, count)
		for range_pair in respawn_ranges:
			var start: int = range_pair[0]
			var end: int = range_pair[1]
			if (start < node and node <= end) or (start < back and back < end):
				node = start
				moved = true
	return node


func node_data(index: int) -> Dictionary:
	return nodes[wrapi(index, 0, nodes.size())]


func gate_a(index: int) -> Vector2:
	var gate: Array = node_data(index).gate
	return Vector2(gate[0], gate[1])


func gate_b(index: int) -> Vector2:
	var gate: Array = node_data(index).gate
	return Vector2(gate[2], gate[3])


# 0 at gate point A and 0x1000 at B, measured along the gate rather than its
# longer axis, so a diagonal road still reports a car that has left the lane.
func across_gate(a: Vector2, b: Vector2, point: Vector2) -> float:
	var across := b - a
	var span := across.length_squared()
	if span == 0.0:
		return 0.0
	return (point - a).dot(across) / span * 4096.0


# FUN_00035c5c wrecks a grounded car once it is 0x500 past either road edge.
func outside_road(lateral: float) -> bool:
	return lateral < -0x500 or lateral >= 0x1500


# Signed distance of a point past a node's gate, measured along the node heading.
func past_gate(index: int, point: Vector2) -> float:
	var a := gate_a(index)
	var n := (gate_b(index) - a).orthogonal().normalized()
	var heading: float = node_data(index).heading * TAU / 4096.0
	if n.dot(Vector2(-sin(heading), -cos(heading))) < 0.0:
		n = -n
	return (point - a).dot(n)


# Steps a tracked node index to the segment containing the point; -1 starts a fresh search.
func follow_node(index: int, point: Vector3) -> int:
	if index < 0 or node_position(index).distance_to(point) > LOST_DISTANCE:
		index = nearest_node(point)
	var flat := Vector2(point.x, point.z)
	for i in 4:
		if past_gate(index + 1, flat) >= 0.0:
			index = wrapi(index + 1, 0, nodes.size())
		elif past_gate(index, flat) < 0.0:
			index = wrapi(index - 1, 0, nodes.size())
		else:
			break
	return index


func to_units(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / Car.UNIT_METRES), floori(point.z / Car.UNIT_METRES))


# Cross product of the gate line A->B with the point; negative past the gate.
func gate_cross(index: int, p: Vector2i) -> int:
	var g: Array = nodes[index].gate_units
	return (g[2] - g[0]) * (p.y - g[1]) - (g[3] - g[1]) * (p.x - g[0])


# FUN_00038418: the first node in [first, last], starting at previous, whose gate
# line the point lies on, within a band around the line. The edge fraction runs
# from the node's left edge to its right one along their dominant axis, signed by
# the gate's direction on that axis; -1 is past the left edge, -2 past the right.
func search_gate(p: Vector2i, first: int, last: int, previous: int) -> int:
	var index := previous if first < previous and previous <= last else first
	for n in last - first + 1:
		var node: Dictionary = nodes[index]
		if node.enabled:
			var g: Array = node.gate_units
			var dx: int = g[2] - g[0]
			var dz: int = g[3] - g[1]
			var band := maxi(maxi(absi(dx), absi(dz)) << 6, 0x6400)
			var cross := gate_cross(index, p)
			if -band < cross and cross < band:
				var t: int = (p.y - g[1]) * 4096 / absi(dz) * signi(dz) if absi(dx) < absi(dz) else (p.x - g[0]) * 4096 / absi(dx) * signi(dx)
				if t > 0 and t < 0x1000:
					gate_fraction = t
					var u: Array = node.units
					var ex := absi(u[5] - u[3])
					var ez := absi(u[6] - u[4])
					var e: int = (p.y - u[4]) * 4096 / ez * (-1 if dz < 0 else 1) if ex < ez else (p.x - u[3]) * 4096 / ex * (-1 if dx < 0 else 1)
					edge_fraction = e if e > 0 and e < 0x1000 else (-1 if e < 0 else -2)
					return index
		index += 1
		if index > last:
			index = first
		if index >= nodes.size():
			index = 0
	return -1


func grid_value(p: Vector2i) -> int:
	var width: int = node_grid.size[0]
	var depth: int = node_grid.size[1]
	var cell := ((p.x + width / 2 * 512) >> 9) + ((p.y + depth / 2 * 512) >> 9) * width
	return node_cells[node_cells[cell] * 16 + width * depth + ((p.x >> 7) & 3) + ((p.y >> 7) & 3) * 4]


# FUN_00037d64: 0 on plain node cells, 2 in zones listing node ranges, 1 in the
# other zones, where the AI holds its course.
func cell_kind(point: Vector3) -> int:
	var value := grid_value(to_units(point)) & 0x7f
	if value == 0:
		return 0
	if value < 0x21:
		return 1
	return 1 if node_grid.zones[value - 0x21][0] == 0 else 2


# FUN_000381d8: the node whose gate the point is on, or -1 between gates.
func lookup_node(point: Vector3, previous: int) -> int:
	var p := to_units(point)
	var value := grid_value(p)
	if value & 0x7f == 0:
		if value < 0x80:
			return -1
		return search_gate(p, maxi((value >> 7) - 2, 0), (value >> 7) + 1, previous)
	if value & 0x7f < 0x21:
		return -1
	var zone: Array = node_grid.zones[(value & 0x7f) - 0x21]
	if zone[0] != 1:
		return -1
	for first: int in [zone[1], zone[2]]:
		var found := search_gate(p, first, first + 7, previous)
		if found != -1 and absi(wrapi(found - previous, -nodes.size() / 2, nodes.size() / 2)) <= 12:
			return found
	return -1


func segment_progress(index: int, point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var behind := absf(past_gate(index, flat))
	var before := absf(past_gate(index + 1, flat))
	return behind / (behind + before) if behind + before > 0.0 else 0.0


func node_transform(index: int, lane: float) -> Transform3D:
	var node: Dictionary = nodes[index % nodes.size()]
	var left := Vector3(node.left[0], node.left[1], node.left[2])
	var right := Vector3(node.right[0], node.right[1], node.right[2])
	var origin := left.lerp(right, lane)
	origin.y = lane_height(node, lane)
	return Transform3D(Basis(Vector3.UP, node.heading * TAU / 4096.0), origin)


# FUN_000388c4: a lane sits at the node height minus its lift byte. Edges are
# bytes 0x1f and 0x1d, quarters are 0x1e and 0x1c, and the centre is unlifted.
func lane_height(node: Dictionary, lane: float) -> float:
	var y: float = node.position[1]
	var heights: Array[float] = [
		y - node.lift[0] * Car.UNIT_METRES,
		y - node.lane_lift[0] * Car.UNIT_METRES,
		y,
		y - node.lane_lift[1] * Car.UNIT_METRES,
		y - node.lift[1] * Car.UNIT_METRES,
	]
	var t := clampf(lane, 0.0, 1.0) * 4.0
	var i := mini(int(t), 3)
	return lerpf(heights[i], heights[i + 1], t - float(i)) + 0.01


# Byte 3 is the tilt about X and byte 2 the tilt about Z, both shifted up by 4.
func node_slope(index: int) -> Vector2:
	var s: Array = nodes[index % nodes.size()].slope
	return Vector2(float(s[1]), float(s[0])) * 16.0 * Car.ANGLE_TO_RAD


func editor_guides() -> Node3D:
	var guides := Node3D.new()
	guides.name = "Guides"
	guides.add_child(editor_path())
	var markers := Node3D.new()
	markers.name = "Nodes"
	guides.add_child(markers)
	var scenery := Node3D.new()
	scenery.name = "Objects"
	guides.add_child(scenery)
	fill_node_markers(markers)
	fill_objects(scenery)
	if not pickups.is_empty():
		var spots := Node3D.new()
		spots.name = "Pickups"
		guides.add_child(spots)
		fill_pickups(spots)
	return guides


func editor_path() -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	var count := nodes.size()
	for i in count:
		var node: Dictionary = nodes[i]
		var center := Vector3(node.position[0], node.position[1], node.position[2]) + Vector3.UP * 0.25
		var nxt: Dictionary = nodes[(i + 1) % count]
		var next_center := Vector3(nxt.position[0], nxt.position[1], nxt.position[2]) + Vector3.UP * 0.25
		var left := Vector3(node.left[0], node.left[1], node.left[2]) + Vector3.UP * 0.2
		var right := Vector3(node.right[0], node.right[1], node.right[2]) + Vector3.UP * 0.2
		var next_left := Vector3(nxt.left[0], nxt.left[1], nxt.left[2]) + Vector3.UP * 0.2
		var next_right := Vector3(nxt.right[0], nxt.right[1], nxt.right[2]) + Vector3.UP * 0.2
		editor_segment(tool, center, next_center, Color(1.0, 0.82, 0.15))
		editor_segment(tool, left, next_left, Color(0.25, 0.85, 1.0))
		editor_segment(tool, right, next_right, Color(1.0, 0.45, 0.15))
		var gate: Array = node.gate
		var y: float = node.position[1] + 0.3
		editor_segment(tool, Vector3(gate[0], y, gate[1]), Vector3(gate[2], y, gate[3]), Color(1, 1, 1, 0.85))
		var forward := Basis(Vector3.UP, float(node.heading) * Car.ANGLE_TO_RAD) * Vector3(0, 0, -2.0)
		editor_segment(tool, center, center + forward, Color.WHITE)
	var lines := MeshInstance3D.new()
	lines.name = "Path"
	lines.mesh = tool.commit()
	lines.material_override = guide_material(Color.WHITE, true)
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return lines


func editor_segment(tool: SurfaceTool, a: Vector3, b: Vector3, color: Color) -> void:
	tool.set_color(color)
	tool.add_vertex(a)
	tool.set_color(color)
	tool.add_vertex(b)


func fill_node_markers(parent: Node3D) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.28, 1.3)
	var start := guide_material(Color(0.2, 0.95, 0.35))
	var jump := guide_material(Color(0.35, 0.65, 1.0))
	var plain := guide_material(Color(1.0, 0.75, 0.15))
	var off := guide_material(Color(0.45, 0.45, 0.45))
	var jump_starts := {}
	for pair in respawn_ranges:
		jump_starts[int(pair[0])] = true
	for i in nodes.size():
		var node: Dictionary = nodes[i]
		var marker := MeshInstance3D.new()
		marker.name = "%04d" % i
		marker.mesh = box
		marker.transform = node_transform(i, 0.5)
		marker.position.y += 0.35
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if i == 0:
			marker.material_override = start
		elif not node.enabled:
			marker.material_override = off
		elif jump_starts.has(i):
			marker.material_override = jump
		else:
			marker.material_override = plain
		marker.set_meta("enabled", node.enabled)
		marker.set_meta("heading", node.heading)
		parent.add_child(marker)


func fill_objects(parent: Node3D) -> void:
	var model_to_world := Basis(Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))
	var count := int(objects.size() / 8.0)
	for i in count:
		var o := i * 8
		var model := objects[o + 7]
		if objects[o + 3] <= 1 or not object_meshes.has(model):
			continue
		var instance := MeshInstance3D.new()
		instance.name = str(i)
		instance.mesh = object_meshes[model]
		var rotation_basis := Basis(Vector3.RIGHT, objects[o + 4] * Car.ANGLE_TO_RAD) * Basis(Vector3.UP, objects[o + 5] * Car.ANGLE_TO_RAD) * Basis(Vector3.BACK, objects[o + 6] * Car.ANGLE_TO_RAD)
		var origin := Vector3(objects[o + 1] + 0x100, 0x100 - objects[o + 2], 0x100 - objects[o]) * Car.UNIT_METRES
		instance.transform = Transform3D(model_to_world * rotation_basis, origin)
		parent.add_child(instance)


func fill_pickups(parent: Node3D) -> void:
	var bead := SphereMesh.new()
	bead.radius = 0.35
	bead.height = 0.7
	var material := guide_material(Color(0.95, 0.25, 0.85))
	for i in pickups.size():
		var entry: PackedInt32Array = pickups[i]
		var lane := 0.5
		match entry[3]:
			1:
				lane = 0.0
			2:
				lane = 1.0
			3:
				lane = 0.25
			4:
				lane = 0.75
		var spot := MeshInstance3D.new()
		spot.name = "%d at %d" % [i, entry[0]]
		spot.mesh = bead
		spot.transform = node_transform(entry[0], lane)
		spot.position.y += 0.6
		spot.material_override = material
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spot.set_meta("laps", entry[1])
		spot.set_meta("type", entry[2])
		parent.add_child(spot)


func guide_material(color: Color, vertex_color := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.vertex_color_use_as_albedo = vertex_color
	material.roughness = 1.0
	return material
