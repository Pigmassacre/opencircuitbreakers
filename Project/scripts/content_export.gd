class_name ContentExport
extends RefCounted

const UNIT_METRES := 2.4 / 158.0
const TILE := 256
const ATLAS_COLUMNS := 8
const CAR_COLUMNS := 4
const FLOOR_CELL := 4.0
const TEX_FIRST_PAGE := 10
const TEX_PAGES_PER_ROW := 6
const SECTOR := 2352
const SECTOR_DATA := 24
const SECTOR_USER := 2048
const DAT_OBJECTS := 0x0
const DAT_PIECES := 0x2c00
const DAT_DIMS := 0x82520
const DAT_CELLS := 0x8252c
const DAT_COLLISION := 0x89d2c
const COLLISION_POINTERS := 256
const DAT_OBJECT_TABLE := DAT_CELLS + 0x6400
const OBJECT_COUNT := 128
const TRK_CAMERAS := 0xCA04
const TRK_RESPAWN := 0xE204
const TRK_RESPAWN_REVERSE := 0xF30C
const TRK_CELL_SWAPS := 0xEF0C
const TRK_AI := 0x12204
const CBBYSS := 52
const CBBYSS_ROWS := 16
const TRK_NODE_GRID := 0x4800
const TRK_SCRIPT := 0xFEDC
const SCRIPT_TOKENS := 0x7f8
const TRK_SCROLL := 0xE304
const TRK_FLIP := 0xE3CC
const TRK_WEATHER := 0x10EDC
const TRK_TEXTURE_PAUSE := 0x10EE4
const PREVIEW_BASE := 0x2cec0
const PREVIEW_STRIDE := 0x1928
const WORLD_CLUT := 0x67f8
const WEATHER_CLUT := 0x65f8
const CAR_PRIM_SIZE: Array[int] = [24, 40, 24, 40]
const FILTERS: Array = [[0, 0], [60, 0], [115, -52], [98, -55], [122, -60]]
const WATER_OPCODES := {0x7d65: 0x100, 0x7d66: 0x200, 0x7d67: 0x100}
const RAISED_WATER: Array[int] = [0x1451, -0x9c1, 0x1451 + 0x739, -0x9c1 + 0x581, 0x180]
const WEATHER_TINT: Array = [
	[0xf8, 0xd8, 0x00],
	[0xc0, 0xd8, 0xe0],
	[0xc0, 0xd8, 0xe0],
	[0xf8, 0xf0, 0x80],
	[0x40, 0xc8, 0xf8],
	[0x40, 0xc8, 0xf8],
]
const WORLDS: Array = [
	["WWEST", "wild_west"],
	["GPRIX", "grand_prix"],
	["VENICE", "venice"],
	["SWAMP", "swamp"],
	["JUNGLE", "jungle"],
	["PERSIA", "persia"],
	["AQUA", "aqua"],
	["SNOW", "snow"],
]
const WORLD_TITLES: Array[String] = ["Wild West", "Grand Prix", "Venice", "Swamp", "Jungle", "Persia", "Aqua", "Snow"]
const DIR_PREFIX := {"wild_west": "wwest", "grand_prix": "gprix"}
const ADDON: Array = [
	["CASTLE", "CASTLE", "castle"],
	["VENROOF", "ROOF", "rooftop"],
]
const CD001 := "CD001"
const GROUP_DISTANCE := 0.055
const TILESET_CUBE := 512
const TILESET_MARKERS := 4
const TILESET_VEHICLE := {"venice": 1, "swamp": 1, "aqua": 2}

var mutex := Mutex.new()
var thread: Thread
var progress := 0.0
var status_text := ""
var result := ""
var finished := false
var shown := ""
var done := 0.0
var total := 0.0
var fault := ""
var disc_root := ""
var project_dir := ""
var cue_path := ""
var temps: Array[String] = []
var file_cache := {}
var file_stamp := {}
var tiles := {}
var tile_for := -1
var echo := false


func start(source: String, addon_source: String, out_path: String) -> void:
	mutex.lock()
	finished = false
	result = ""
	progress = 0.0
	status_text = "Starting"
	mutex.unlock()
	thread = Thread.new()
	thread.start(run.bind(source, addon_source, out_path))


func run(source: String, addon_source: String, out_path: String) -> void:
	var message := extract(source, addon_source, out_path)
	mutex.lock()
	result = message
	finished = true
	if message == "":
		progress = 1.0
		status_text = "Done."
	else:
		status_text = message
	mutex.unlock()


func snapshot() -> Dictionary:
	mutex.lock()
	var snap := {
		"progress": progress,
		"status": status_text,
		"error": result,
		"finished": finished,
	}
	mutex.unlock()
	return snap


func join() -> void:
	if thread != null:
		thread.wait_to_finish()
		thread = null


func extract(source: String, addon_source: String, out_path: String) -> String:
	fault = ""
	done = 0.0
	shown = "Starting"
	disc_root = ""
	cue_path = ""
	temps = []
	file_cache = {}
	file_stamp = {}
	tiles = {}
	tile_for = -1
	project_dir = out_path
	var extra := addon_source.strip_edges()
	total = 126.0 + (20.0 if extra != "" else 0.0)
	_extract_body(source.strip_edges(), extra)
	for temp in temps:
		remove_tree(temp)
	temps = []
	return fault


func _extract_body(source: String, extra: String) -> void:
	resolve(source)
	if fault != "":
		return
	ensure_dir(project_dir)
	export_car_set(disc_root.path_join("WWEST/CARS.DAT"), disc_root.path_join("WWEST/WWEST1.TEX"), project_dir.path_join("cars"), "Car")
	if fault != "":
		return
	export_car_set(disc_root.path_join("VENICE/BOAT.DAT"), disc_root.path_join("VENICE/VENICE1.TEX"), project_dir.path_join("vehicles/venice"), "Venice")
	if fault != "":
		return
	export_car_set(disc_root.path_join("SWAMP/BOAT.DAT"), disc_root.path_join("SWAMP/SWAMP1.TEX"), project_dir.path_join("vehicles/swamp"), "Swamp")
	if fault != "":
		return
	export_car_set(disc_root.path_join("AQUA/WATER.DAT"), disc_root.path_join("AQUA/AQUA1.TEX"), project_dir.path_join("vehicles/aqua"), "Aqua")
	if fault != "":
		return
	export_game()
	if fault != "":
		return
	export_tilesets()
	if fault != "":
		return
	phase("Sound effects")
	export_sfx(disc_root.path_join("SOUND/GAME1.VH"), disc_root.path_join("SOUND/GAME1.VB"), project_dir.path_join("audio/sfx"))
	phase_done()
	if fault != "":
		return
	export_music()
	if fault != "":
		return
	export_particles(disc_root.path_join("WWEST/WWEST1.TEX"), project_dir.path_join("textures"))
	if fault != "":
		return
	if extra != "":
		export_addon(addon_bin(extra))


func phase(text: String) -> void:
	shown = text
	if echo:
		print(text)
	_publish(done)


func phase_fraction(text: String, frac: float) -> void:
	shown = text
	_publish(done + frac)


func phase_done() -> void:
	done += 1.0
	_publish(done)


func _publish(at: float) -> void:
	var amount := 0.0
	if total > 0.0:
		amount = at / total
	mutex.lock()
	progress = amount
	status_text = shown
	mutex.unlock()


func fail(message: String) -> void:
	if fault == "":
		fault = message


func resolve(source: String) -> void:
	var path := source
	var cue := ""
	if DirAccess.dir_exists_absolute(path):
		cue = one_cue(cues_in(path))
		if fault != "":
			return
		if cue == "":
			cue = one_cue(cues_in(path.get_base_dir()))
		if fault != "":
			return
		if cue == "":
			fail("no .cue file found; pass the cue so the music can be extracted")
			return
		disc_root = find_root(path)
		cue_path = cue
		phase("Using extracted files")
		phase_done()
		return
	var lower := path.to_lower()
	if lower.ends_with(".cue"):
		var bin_path := data_bin(path)
		if fault != "":
			return
		disc_root = materialize(bin_path)
		cue_path = path
		return
	if lower.ends_with(".bin") or lower.ends_with(".iso"):
		cue = one_cue(cues_in(path.get_base_dir()))
		if fault != "":
			return
		if cue == "":
			fail("pass the .cue file so the CD audio can be extracted")
			return
		disc_root = materialize(path)
		cue_path = cue
		return
	fail("pass a .cue file, a disc image, or a folder of extracted disc files")


func cues_in(folder: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(folder):
		return found
	var dir := DirAccess.open(folder)
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		if not dir.current_is_dir() and entry_name.to_lower().ends_with(".cue"):
			found.append(folder.path_join(entry_name))
		entry_name = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


func one_cue(found: Array[String]) -> String:
	if found.size() > 1:
		fail("several .cue files; pass the Circuit Breakers cue directly:\n" + "\n".join(found))
		return ""
	if found.size() == 1:
		return found[0]
	return ""


func find_root(folder: String) -> String:
	if DirAccess.dir_exists_absolute(folder.path_join("WWEST")):
		return folder
	var nested := folder.path_join("LES00753")
	if DirAccess.dir_exists_absolute(nested.path_join("WWEST")):
		return nested
	fail("no Circuit Breakers files in %s (looked for a WWEST folder)" % folder)
	return ""


func data_bin(path: String) -> String:
	for entry in parse_cue(path):
		for track in entry.tracks:
			if String(track.kind).to_upper().contains("MODE"):
				return entry.name
	fail("no data track in " + path)
	return ""


func addon_bin(path: String) -> String:
	if path.to_lower().ends_with(".cue"):
		return data_bin(path)
	if not FileAccess.file_exists(path):
		fail("add-on disc not found: " + path)
		return ""
	return path


func materialize(bin_path: String) -> String:
	phase("Reading the disc")
	var files := read_iso(bin_path, ["VIDEO"])
	if fault != "":
		return ""
	if not files.has("WWEST/CARS.DAT"):
		fail("that disc image has no Circuit Breakers track files")
		return ""
	var folder := make_temp("opencircuitbreakers-disc")
	var index := 0
	var count := files.size()
	for rel in files:
		index += 1
		phase_fraction("Reading " + rel, float(index) / float(count))
		write_bytes(folder.path_join(rel), files[rel])
		if fault != "":
			return ""
	phase_done()
	return folder


func export_game() -> void:
	phase("Item icons")
	export_icons(read_file(disc_root.path_join("TUNNEL/TUNNEL.TIM")), project_dir.path_join("textures/items.png"))
	phase_done()
	if fault != "":
		return
	for world_index in WORLDS.size():
		var world: Array = WORLDS[world_index]
		for number in range(1, 5):
			for reverse_pass in 2:
				var reverse := reverse_pass == 1
				var track_name := "%s%d%s" % [world[0], number, "R" if reverse else ""]
				var label := "%s %d" % [WORLD_TITLES[world_index], number]
				if reverse:
					label += " reverse"
				phase(label)
				export_named(track_name, world[0], project_dir.path_join("tracks").path_join(track_name.to_lower()))
				phase_done()
				if fault != "":
					return
	phase("Championships")
	export_races(read_file(disc_root.path_join("INDEX/CBBYSS.CON")))
	phase_done()
	if fault != "":
		return
	phase("Track names")
	export_names(read_file(disc_root.path_join("INDEX/CBBYSS.CON")), world_slugs())
	phase_done()
	if fault != "":
		return
	phase("Course select")
	export_previews()
	phase_done()
	if fault != "":
		return
	phase("Menu icons")
	export_menu_icons()
	phase_done()


func export_named(track_name: String, world: String, out: String) -> void:
	var root := disc_root.path_join(world)
	export_level(
		root.path_join(track_name + ".DAT"),
		root.path_join(track_name + ".TRK"),
		root.path_join(world + "1.TEX"),
		out,
		track_name.ends_with("R"),
		track_number(track_name, world),
		""
	)


func export_car_set(cars_path: String, tex_path: String, out_dir: String, label: String) -> void:
	var data := read_file(cars_path)
	var tex := read_file(tex_path)
	if fault != "":
		return
	var cars := load_cars(data)
	var stamp := int(file_stamp[tex_path])
	for i in cars.size():
		phase("%s %d" % [label, i + 1])
		export_one_car(cars[i], tex, stamp, out_dir.path_join("car%d" % i))
		phase_done()
		if fault != "":
			return


func export_one_car(car: Dictionary, tex: PackedByteArray, stamp: int, out_dir: String) -> void:
	var models: Array = [car.body]
	for wheel_model in car.wheel_models:
		models.append(wheel_model)
	var combos := {}
	var key := Vector2i()
	for model in models:
		for prim in model.prims:
			if not prim.has("tpage"):
				continue
			key = Vector2i(prim.tpage, prim.clut)
			if not combos.has(key):
				combos[key] = combos.size()
	var rows := divi((combos.size() + 1 + CAR_COLUMNS - 1), CAR_COLUMNS)
	var atlas_w := CAR_COLUMNS * TILE
	var atlas_h := rows * TILE
	var atlas := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	for combo_key in combos:
		key = combo_key
		var index: int = combos[key]
		blit_tile(atlas, cached_tile(tex, key.x, key.y, stamp), (index % CAR_COLUMNS) * TILE, (divi(index, CAR_COLUMNS)) * TILE)
	var white := combos.size()
	var origin_x := (white % CAR_COLUMNS) * TILE
	var origin_y := (divi(white, CAR_COLUMNS)) * TILE
	for y in 4:
		for x in 4:
			atlas.set_pixel(origin_x + x, origin_y + y, Color(1, 1, 1, 1))
	ensure_dir(out_dir)
	if atlas.save_png(out_dir.path_join("atlas.png")) != OK:
		fail("Could not write " + out_dir)
		return
	var wheel_table: Array = car.wheel_table
	var wheel_models: Array = car.wheel_models
	var ground: int = wheel_table[0].pos[1] + wheel_radius(wheel_models[wheel_table[0].model - 1])
	for wh in wheel_table:
		ground = maxi(ground, wh.pos[1] + wheel_radius(wheel_models[wh.model - 1]))
	var bin := BinWriter.new()
	write_car_model(bin, car_triangles(car.body, combos, white, atlas_w, atlas_h), [0, ground, 0])
	for wheel_model in wheel_models:
		write_car_model(bin, car_triangles(wheel_model, combos, white, atlas_w, atlas_h), [0, 0, 0])
	write_bytes(out_dir.path_join("mesh.bin"), bin.bytes())
	var mounts: Array = []
	for wh in wheel_table:
		var pos: Array = wh.pos
		mounts.append({
			"position": to_godot([pos[2], pos[1], pos[0]], [0, ground, 0]),
			"radius": wheel_radius(wheel_models[wh.model - 1]) * UNIT_METRES,
			"model": wh.model,
			"flags": wh.flags,
			"steers": wh.flags == 3,
		})
	var fields: Array = car.fields
	write_json(out_dir.path_join("car.json"), {
		"models": models.size(),
		"wheels": mounts,
		"ground": ground,
		"kind": fields[6],
		"color": [fields[3] & 0xff, fields[4] & 0xff, fields[5] & 0xff],
	})


func export_level(dat_path: String, trk_path: String, tex_path: String, out_dir: String, reverse: bool, track_id: int, con_path: String) -> void:
	var dat := read_file(dat_path)
	var trk := read_file(trk_path)
	var tex := read_file(tex_path)
	if fault != "":
		return
	var track := load_track(dat)
	swap_cells(track, trk)
	var grid_w: int = track.dims[0]
	var grid_d: int = track.dims[1]
	var cells: Array = []
	for cell in track.cells:
		var piece_id: int = cell[0]
		if piece_id != 0xff and track.pieces.get(piece_id) != null:
			cells.append(cell)
		else:
			cells.append([0xff, cell[1], cell[2], cell[3]])
	var objects := object_table(dat)
	var models := object_models(dat, objects, track.base)
	var combos := {}
	var key := Vector2i()
	for cell in cells:
		if cell[0] == 0xff:
			continue
		for prim in track.pieces[cell[0]].prims:
			key = Vector2i(prim.tpage, prim.clut)
			if not combos.has(key):
				combos[key] = combos.size()
	for model_id in models:
		for prim in models[model_id].prims:
			key = Vector2i(prim.tpage, prim.clut)
			if not combos.has(key):
				combos[key] = combos.size()
	var atlas_rows := divi((combos.size() + ATLAS_COLUMNS - 1), ATLAS_COLUMNS)
	var atlas_w := ATLAS_COLUMNS * TILE
	var atlas_h := maxi(atlas_rows, 1) * TILE
	var stamp := int(file_stamp[tex_path])
	var atlas := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	if combos.size() > 0:
		for combo_key in combos:
			key = combo_key
			var index: int = combos[key]
			blit_tile(atlas, cached_tile(tex, key.x, key.y, stamp), (index % ATLAS_COLUMNS) * TILE, (divi(index, ATLAS_COLUMNS)) * TILE)
	ensure_dir(out_dir)
	var png_errors: Array = []
	var png_path := out_dir.path_join("atlas.png")
	var png_task := WorkerThreadPool.add_task(write_png.bind(atlas, png_path, png_errors))
	var surfaces0: Array = []
	var surfaces1: Array = []
	var types0: Array = []
	var types1: Array = []
	var baked := {}
	var bake_xform := {"object": false, "raw": true, "fx": 1, "fz": 1}
	for i in cells.size():
		var placed: Array = cells[i]
		if placed[0] == 0xff:
			continue
		var col := i % grid_w
		var row := (divi(i, grid_w)) % grid_d
		var layer := divi(i, (grid_w * grid_d))
		var fx := -1 if (placed[1] & 2) != 0 else 1
		var fz := -1 if (placed[1] & 1) != 0 else 1
		var bake_key := int(placed[0]) * 4
		if fx < 0:
			bake_key += 2
		if fz < 0:
			bake_key += 1
		var local: Array = baked.get(bake_key, [])
		if not baked.has(bake_key):
			bake_xform["fx"] = fx
			bake_xform["fz"] = fz
			local = model_triangles(track.pieces[placed[0]], bake_xform, combos, atlas_w, atlas_h, false)
			baked[bake_key] = local
		var cx := (col - divi(grid_w, 2)) * 512 + 256
		var cy := layer * 512 + 256
		var cz := (row - divi(grid_d, 2)) * 512 + 256
		translate_piece(local, cx, cy, cz, surfaces0, types0, surfaces1, types1)
	var mesh := BinWriter.new()
	write_triangle_list(mesh, surfaces0)
	write_triangle_list(mesh, surfaces1)
	write_bytes(out_dir.path_join("mesh.bin"), mesh.bytes())
	var objects_bin := BinWriter.new()
	var object_xform := {"object": true}
	var model_ids: Array = []
	for model_id in models:
		model_ids.append(model_id)
		var grouped: Array = [[], []]
		for item in model_triangles(models[model_id], object_xform, combos, atlas_w, atlas_h):
			grouped[item[1]].append(item[0])
		write_triangle_list(objects_bin, grouped[0])
		write_triangle_list(objects_bin, grouped[1])
	write_bytes(out_dir.path_join("objects.bin"), objects_bin.bytes())
	var surface_bytes := PackedByteArray()
	surface_bytes.resize(types0.size() + types1.size())
	var surface_at := 0
	for value in types0:
		surface_bytes[surface_at] = value
		surface_at += 1
	for value in types1:
		surface_bytes[surface_at] = value
		surface_at += 1
	write_bytes(out_dir.path_join("surfaces.bin"), surface_bytes)
	track.cells = cells
	write_collision(track, out_dir.path_join("collision.bin"))
	WorkerThreadPool.wait_for_task_completion(png_task)
	if png_errors.size() > 0:
		fail("Could not write " + png_path)
		return
	var all_tris: Array = []
	all_tris.append_array(surfaces0)
	all_tris.append_array(surfaces1)
	var floor_grid := build_floor_grid(all_tris)
	var count := trk.decode_s32(0xC900)
	var nodes: Array = []
	for i in count:
		var o := i * 0x24
		var x := trk.decode_s16(o + 0x14)
		var z := trk.decode_s16(o + 0x16)
		var y := trk.decode_s16(o + 0x22)
		var lx := trk.decode_s16(o + 8)
		var lz := trk.decode_s16(o + 10)
		var rx := trk.decode_s16(o + 12)
		var rz := trk.decode_s16(o + 14)
		var ax := trk.decode_s16(o + 4)
		var az := trk.decode_s16(o + 6)
		var bx := trk.decode_s16(o + 0x10)
		var bz := trk.decode_s16(o + 0x12)
		var cam := TRK_CAMERAS + i * 12
		var px := x * UNIT_METRES
		var py := y * UNIT_METRES
		var pz := z * UNIT_METRES
		nodes.append({
			"enabled": trk[o] != 0x80,
			"gate": [ax * UNIT_METRES, az * UNIT_METRES, bx * UNIT_METRES, bz * UNIT_METRES],
			"gate_units": [ax, az, bx, bz],
			"camera": [trk[cam], trk[cam + 3], trk[cam + 6], trk[cam + 9], trk[o + 0x18]],
			"battle_camera": [trk[cam + 4], trk[cam + 7], trk[cam + 10]],
			"position": [px, py, pz],
			"left": [lx * UNIT_METRES, py, lz * UNIT_METRES],
			"right": [rx * UNIT_METRES, py, rz * UNIT_METRES],
			"heading": (-(trk[o] << 7)) & 0xfff,
			"floor": floor_height(floor_grid, px, py, pz),
			"units": [x, z, y, lx, lz, rx, rz, ax, az, bx, bz],
			"lift": [byte_lift(trk[o + 0x1f], false), byte_lift(trk[o + 0x1d], false)],
			"lane_lift": [byte_lift(trk[o + 0x1e], false), byte_lift(trk[o + 0x1c], false)],
			"slope": [byte_lift(trk[o + 2], true), byte_lift(trk[o + 3], true)],
			"ai": [trk[o + 0x18], trk[o + 0x19], trk[o + 0x1a], trk.decode_s16(o + 0x20)],
		})
	var ranges: Array = []
	var respawn_at := TRK_RESPAWN_REVERSE if reverse else TRK_RESPAWN
	for pair in 32:
		var start := trk.decode_s32(respawn_at + pair * 8)
		var end := trk.decode_s32(respawn_at + pair * 8 + 4)
		if start == -1:
			break
		ranges.append([start, end])
	var env := DAT_CELLS + 0x6400 + 0x1400 + 0x14400
	var sky := [
		dat.decode_s32(env + 0x64) / 255.0,
		dat.decode_s32(env + 0x68) / 255.0,
		dat.decode_s32(env + 0x6c) / 255.0,
	]
	var handling := [
		trk.decode_s32(0xFE8C),
		trk.decode_s32(0xFE90),
		trk.decode_s32(0xFE94),
		trk.decode_s32(0xFE98),
		trk.decode_s32(0xFEA0),
	]
	var con := con_bytes(con_path)
	if fault != "":
		return
	var tables := ai_tables(trk)
	var anim := animation_data(trk, combos)
	var flip := flip_sheet(tex, stamp, anim)
	write_json(out_dir.path_join("track.json"), {
		"nodes": nodes,
		"node_grid": node_grid(trk, grid_w, grid_d),
		"respawn_ranges": ranges,
		"sky": sky,
		"handling": handling,
		"water": water_level(trk),
		"water_regions": water_regions(trk),
		"script": script_tokens(trk),
		"objects": objects,
		"object_models": model_ids,
		"pickups": pickup_table(con, track_id),
		"ai_thresholds": tables[0],
		"ai_speeds": tables[1],
		"ai_start": ai_start(con, track_id),
		"scrolls": anim.scrolls,
		"flip_entries": anim.flip_entries,
		"flip_groups": anim.flip_groups,
		"flip_bank": flip.bank,
		"weather": anim.weather,
		"texture_pause": anim.texture_pause,
	})
	if flip.bank.size() > 0:
		save_rgba(out_dir.path_join("flip.png"), flip.width, flip.height, flip.rgba)


func write_collision(track: Dictionary, path: String) -> void:
	var grid_w: int = track.dims[0]
	var grid_d: int = track.dims[1]
	var blocks := load_collision(track.data)
	var bin := BinWriter.new()
	var kinds: Array = []
	var positions := PackedFloat32Array()
	for i in track.cells.size():
		var cell: Array = track.cells[i]
		var piece_id: int = cell[0]
		if piece_id == 0xff or not blocks.has(piece_id):
			continue
		var block: Dictionary = blocks[piece_id]
		var col: int = i % grid_w
		var row := (divi(i, grid_w)) % grid_d
		var layer := divi(i, (grid_w * grid_d))
		var fx := -1 if (cell[1] & 2) != 0 else 1
		var fz := -1 if (cell[1] & 1) != 0 else 1
		var cx: int = (col - divi(grid_w, 2)) * 512 + 256
		var cy := layer * 512 + 256
		var cz := (row - divi(grid_d, 2)) * 512 + 256
		for face in block.faces:
			var pts: Array = []
			for vi in face.verts:
				var vert: Array = block.verts[vi]
				pts.append([
					(cx - vert[2] * fz) * UNIT_METRES,
					(cy - vert[1]) * UNIT_METRES,
					(cz - vert[0] * fx) * UNIT_METRES,
				])
			var tris: Array = [pts.slice(0, 3)]
			if pts.size() == 4:
				tris = [pts.slice(0, 3), [pts[1], pts[3], pts[2]]]
			for tri in tris:
				for point in tri:
					positions.append(point[0])
					positions.append(point[1])
					positions.append(point[2])
				kinds.append(face.surface)
	bin.i32(kinds.size())
	for component in positions:
		bin.f32(component)
	for kind in kinds:
		bin.u8(kind)
	write_bytes(path, bin.bytes())


func export_sfx(vh_path: String, vb_path: String, out_dir: String) -> void:
	var vh := read_file(vh_path)
	var vb := read_file(vb_path)
	if fault != "":
		return
	if vh.slice(0, 4) != PackedByteArray([112, 66, 65, 86]):
		fail("not a VAB header")
		return
	var count := vh.decode_u16(22)
	var samples := vag_waveforms(vb)
	if fault != "":
		return
	if samples.size() != count:
		fail("VAB lists %d vags, body has %d" % [count, samples.size()])
		return
	ensure_dir(out_dir)
	for i in samples.size():
		var pcm: PackedInt32Array = samples[i]
		var bytes := PackedByteArray()
		bytes.resize(pcm.size() * 2)
		for s in pcm.size():
			bytes.encode_s16(s * 2, pcm[s])
		write_wav(out_dir.path_join("vag_%02d.wav" % [i + 1]), bytes, 1, 44100)


func export_music() -> void:
	var spans := audio_spans(cue_path)
	if fault != "":
		return
	var out_dir := project_dir.path_join("audio/music")
	ensure_dir(out_dir)
	for span in spans:
		phase("Music track %d" % span[0])
		var handle := FileAccess.open(span[1], FileAccess.READ)
		if handle == null:
			fail("missing audio " + span[1])
			return
		handle.seek(int(span[2]) * SECTOR)
		var pcm := handle.get_buffer((int(span[3]) - int(span[2])) * SECTOR)
		handle.close()
		write_wav(out_dir.path_join("track_%d.wav" % span[0]), pcm, 2, 44100)
		phase_done()


func export_particles(tex_path: String, out_dir: String) -> void:
	var tex := read_file(tex_path)
	var tim := read_file(disc_root.path_join("TUNNEL/TUNNEL.TIM"))
	if fault != "":
		return
	var stamp := int(file_stamp[tex_path])
	ensure_dir(out_dir)
	for spec in [[0x2e, 0x783a, 256, "particles_fire.png"], [0x3e, 0x787a, 64, "particles_smoke.png"]]:
		phase(spec[3])
		var cropped: Array = sheet(tex, stamp, spec[0], spec[1], spec[2])
		save_rgba(out_dir.path_join(spec[3]), cropped[1], cropped[2], cropped[0])
		phase_done()
	for spec in [
		[0x2a, 0x78fa, 0x1a, 0x8a, 9, 6, "particles_streak.png"],
		[0x2a, 0x78fa, 0, 0x80, 256, 128, "particles_respawn.png"],
		[0x6a, 0x793a, 0xc0, 0x20, 64, 64, "particles_ring.png"],
		[0x6a, 0x793a, 0xc4, 0x20, 0xfb - 0xc4 + 1, 0x26 - 0x20 + 1, "particles_arc.png"],
	]:
		phase(spec[6])
		var tile := cached_tile(tex, spec[0], spec[1], stamp)
		save_rgba(out_dir.path_join(spec[6]), spec[4], spec[5], crop_tile(tile, spec[2], spec[3], spec[4], spec[5]))
		phase_done()
	phase("particles_wake.png")
	var wake := wake_image(tim)
	save_rgba(out_dir.path_join("particles_wake.png"), wake[1], wake[2], wake[0])
	phase_done()


func export_addon(bin_path: String) -> void:
	if bin_path == "" or fault != "":
		return
	var files := read_iso(bin_path, ["VIDEO", "SOUND", "TIMS", "TUNNEL"])
	if fault != "":
		return
	var scratch := make_temp("cbaddon")
	if not files.has("INDEX/CBBYSS.CON"):
		fail("add-on disc is missing INDEX/CBBYSS.CON")
		return
	var con_path := scratch.path_join("CBBYSS.CON")
	write_bytes(con_path, files["INDEX/CBBYSS.CON"])
	for world in ADDON.size():
		var spec: Array = ADDON[world]
		var tex_rel := "%s/%s1.TEX" % [spec[0], spec[1]]
		if not files.has(tex_rel):
			fail("add-on disc is missing " + tex_rel)
			return
		var tex_path := scratch.path_join(tex_rel.get_file())
		write_bytes(tex_path, files[tex_rel])
		for number in range(1, 5):
			for reverse_pass in 2:
				var reverse := reverse_pass == 1
				var stem := "%s%d%s" % [spec[1], number, "R" if reverse else ""]
				var dat_rel := "%s/%s.DAT" % [spec[0], stem]
				var trk_rel := "%s/%s.TRK" % [spec[0], stem]
				if not files.has(dat_rel) or not files.has(trk_rel):
					fail("add-on disc is missing " + stem)
					return
				var dat_path := scratch.path_join(stem + ".DAT")
				var trk_path := scratch.path_join(stem + ".TRK")
				write_bytes(dat_path, files[dat_rel])
				write_bytes(trk_path, files[trk_rel])
				var dirname := "%s%d%s" % [spec[2], number, "r" if reverse else ""]
				phase(stem)
				export_level(dat_path, trk_path, tex_path, project_dir.path_join("tracks").path_join(dirname), reverse, addon_id(world, number, reverse), con_path)
				phase_done()
				if fault != "":
					return
	phase("Add-on course select")
	merge_addon_previews(files)
	phase_done()
	phase("Add-on icons")
	export_addon_icons(files)
	phase_done()
	phase("Add-on championships")
	write_addon_races()
	phase_done()
	phase("Add-on names")
	export_names(files["INDEX/CBBYSS.CON"], addon_slugs())
	phase_done()


func read_iso(path: String, skip: Array) -> Dictionary:
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		fail("not a disc image: " + path)
		return {}
	var size := int(handle.get_length())
	var stride := 0
	var header := 0
	if size % SECTOR == 0 and sector_mark(handle, SECTOR, SECTOR_DATA):
		stride = SECTOR
		header = SECTOR_DATA
	elif size % SECTOR_USER == 0 and sector_mark(handle, SECTOR_USER, 0):
		stride = SECTOR_USER
	if stride == 0:
		handle.close()
		fail("not a disc image: " + path)
		return {}
	var pvd := read_sector(handle, stride, header, 16)
	var root := parse_dir(read_extent(handle, stride, header, pvd.decode_u32(158), pvd.decode_u32(166)))
	var les_extent := -1
	var les_size := 0
	for entry in root:
		if entry.name == "LES00753":
			les_extent = entry.extent
			les_size = entry.size
			break
	if les_extent < 0:
		handle.close()
		fail("that disc image has no Circuit Breakers track files")
		return {}
	var files := {}
	walk_iso(handle, stride, header, parse_dir(read_extent(handle, stride, header, les_extent, les_size)), "", skip, files)
	handle.close()
	return files


func sector_mark(handle: FileAccess, stride: int, header: int) -> bool:
	handle.seek(16 * stride + header)
	var mark := handle.get_buffer(6)
	return mark.size() >= 6 and mark.slice(1, 6).get_string_from_ascii() == CD001


func read_sector(handle: FileAccess, stride: int, header: int, n: int) -> PackedByteArray:
	handle.seek(n * stride + header)
	return handle.get_buffer(SECTOR_USER)


func read_extent(handle: FileAccess, stride: int, header: int, extent: int, size: int) -> PackedByteArray:
	var out := PackedByteArray()
	var count := divi((size + SECTOR_USER - 1), SECTOR_USER)
	for i in count:
		out.append_array(read_sector(handle, stride, header, extent + i))
	if size <= 0:
		return PackedByteArray()
	return out.slice(0, size)


func parse_dir(data: PackedByteArray) -> Array:
	var entries: Array = []
	var o := 0
	while o < data.size():
		var ln := data[o]
		if ln == 0:
			o = (o + SECTOR_USER - 1) & ~(SECTOR_USER - 1)
			continue
		var nlen := data[o + 32]
		var skipped := nlen == 1 and (data[o + 33] == 0 or data[o + 33] == 1)
		var name := ""
		if not skipped:
			var raw := data.slice(o + 33, o + 33 + nlen)
			var semi := raw.find(59)
			if semi >= 0:
				raw = raw.slice(0, semi)
			name = raw.get_string_from_ascii()
		entries.append({
			"name": name,
			"extent": data.decode_u32(o + 2),
			"size": data.decode_u32(o + 10),
			"flags": data[o + 25],
			"skip": skipped,
		})
		o += ln
	return entries


func walk_iso(handle: FileAccess, stride: int, header: int, entries: Array, prefix: String, skip: Array, files: Dictionary) -> void:
	for entry in entries:
		if entry.skip:
			continue
		var rel := prefix + String(entry.name)
		if entry.flags & 2:
			if skip.has(rel):
				continue
			var child := parse_dir(read_extent(handle, stride, header, entry.extent, entry.size))
			walk_iso(handle, stride, header, child, rel + "/", skip, files)
		else:
			files[rel] = read_extent(handle, stride, header, entry.extent, entry.size)


func parse_cue(path: String) -> Array:
	var text := FileAccess.get_file_as_string(path)
	var files: Array = []
	var track := {}
	var have := false
	for raw_line in text.split("\n"):
		var line := raw_line.strip_edges()
		if line.begins_with("FILE "):
			var q0 := line.find("\"")
			var q1 := line.find("\"", q0 + 1)
			var name := line.substr(q0 + 1, q1 - q0 - 1)
			files.append({"name": path.get_base_dir().path_join(name), "tracks": []})
			have = false
		elif line.begins_with("TRACK "):
			var parts := line.split(" ", false)
			track = {"number": int(parts[1]), "kind": parts[2], "indexes": {}}
			files[files.size() - 1].tracks.append(track)
			have = true
		elif line.begins_with("INDEX ") and have:
			var parts := line.split(" ", false)
			track.indexes[int(parts[1])] = msf(parts[2])
	return files


func msf(text: String) -> int:
	var parts := text.split(":")
	return (int(parts[0]) * 60 + int(parts[1])) * 75 + int(parts[2])


func audio_spans(path: String) -> Array:
	var found: Array = []
	for entry in parse_cue(path):
		var tracks: Array = entry.tracks
		var handle := FileAccess.open(entry.name, FileAccess.READ)
		if handle == null:
			fail("missing audio " + entry.name)
			return []
		var size := divi(int(handle.get_length()), SECTOR)
		handle.close()
		for i in tracks.size():
			var track: Dictionary = tracks[i]
			if not String(track.kind).begins_with("AUDIO"):
				continue
			var indexes: Dictionary = track.indexes
			var start: int = indexes[1]
			var end := size
			if i + 1 < tracks.size():
				var nxt: Dictionary = tracks[i + 1].indexes
				end = nxt[0] if nxt.has(0) else nxt[1]
			found.append([track.number, entry.name, start, end])
	return found


func load_cars(data: PackedByteArray) -> Array:
	var cars: Array = []
	for i in 8:
		var r := i * 100
		var nmodels := data.decode_s32(r + 0x20)
		var fields: Array = []
		for f in 25:
			fields.append(data.decode_s32(r + f * 4))
		var wheel_models: Array = []
		for k in nmodels:
			wheel_models.append(parse_car_model(data, data.decode_s32(r + 0x24 + k * 4)))
		cars.append({
			"fields": fields,
			"body": parse_car_model(data, data.decode_s32(r)),
			"wheel_models": wheel_models,
			"wheel_table": parse_wheels(data, data.decode_s32(r + 0x34)),
		})
	return cars


func parse_car_model(data: PackedByteArray, header: int) -> Dictionary:
	var nprims := data.decode_s16(header + 0x52)
	var o := header + 0x58
	var nverts := data.decode_s32(o)
	var verts: Array = []
	var p := o + 4
	for _vert in nverts:
		verts.append([
			[data.decode_s16(p), data.decode_s16(p + 2), data.decode_s16(p + 4)],
			[data[p + 8], data[p + 9], data[p + 10]],
		])
		p += 12
	var prims: Array = []
	for _prim in nprims:
		var kind := data[p]
		var prim := {"kind": kind, "double": data[p + 2], "idx": [data[p + 4], data[p + 5], data[p + 6]]}
		if kind == 1 or kind == 3:
			prim["uv"] = [[data[p + 24], data[p + 25]], [data[p + 28], data[p + 29]], [data[p + 32], data[p + 33]]]
			prim["clut"] = data.decode_u16(p + 26)
			prim["tpage"] = data.decode_u16(p + 30)
		prims.append(prim)
		p += CAR_PRIM_SIZE[kind]
	return {"verts": verts, "prims": prims}


func parse_wheels(data: PackedByteArray, o: int) -> Array:
	var count := data.decode_s32(o)
	var wheels: Array = []
	for i in count:
		var at := o + 8 + i * 20
		wheels.append({
			"pos": [data.decode_s32(at), data.decode_s32(at + 4), data.decode_s32(at + 8)],
			"flags": data.decode_s32(at + 12),
			"model": data.decode_s32(at + 16),
		})
	return wheels


func car_triangles(model: Dictionary, combos: Dictionary, white: int, atlas_w: int, atlas_h: int) -> Array:
	var tris: Array = []
	for prim in model.prims:
		var textured: bool = prim.kind == 1 or prim.kind == 3
		var gouraud: bool = prim.kind == 2 or prim.kind == 3
		var index := white
		if textured:
			index = combos[Vector2i(prim.tpage, prim.clut)]
		var ox := (index % CAR_COLUMNS) * TILE
		var oy := (divi(index, CAR_COLUMNS)) * TILE
		var scale := 128.0 if textured else 255.0
		var tri: Array = []
		for k in prim.idx.size():
			var vert: Array = model.verts[prim.idx[k]]
			var rgb: Array = vert[1]
			if not gouraud:
				rgb = model.verts[prim.idx[0]][1]
			var u := 1
			var v := 1
			if textured:
				u = prim.uv[k][0]
				v = prim.uv[k][1]
			tri.append([
				vert[0],
				[minf(float(rgb[0]) / scale, 1.0), minf(float(rgb[1]) / scale, 1.0), minf(float(rgb[2]) / scale, 1.0)],
				[(ox + u + 0.5) / float(atlas_w), (oy + v + 0.5) / float(atlas_h)],
			])
		tris.append([tri, prim.double])
	return tris


func write_car_model(bin: BinWriter, tris: Array, offset: Array) -> void:
	for double_flag in 2:
		var group: Array = []
		for item in tris:
			if (int(item[1]) != 0) == (double_flag == 1):
				group.append(item[0])
		bin.i32(group.size() * 3)
		for tri in group:
			var pts: Array = []
			for corner in tri:
				pts.append(to_godot(corner[0], offset))
			var normal := face_normal(pts)
			for k in pts.size():
				var color: Array = tri[k][1]
				var uv: Array = tri[k][2]
				bin.vertex(pts[k], normal, [color[0], color[1], color[2], 1.0], uv)


func load_track(data: PackedByteArray) -> Dictionary:
	var grid_w := data.decode_s32(DAT_DIMS)
	var grid_d := data.decode_s32(DAT_DIMS + 4)
	var grid_h := data.decode_s32(DAT_DIMS + 8)
	var cells: Array = []
	for i in grid_w * grid_d * grid_h:
		var o := DAT_CELLS + i * 4
		cells.append([data[o], data[o + 1], data[o + 2], data[o + 3]])
	var base := load_base(data)
	var pieces := {}
	for cell in cells:
		var piece_id: int = cell[0]
		if piece_id != 0xff and not pieces.has(piece_id):
			pieces[piece_id] = parse_track_model(data, DAT_PIECES + piece_id * 0x58, base)
	return {"data": data, "dims": [grid_w, grid_d, grid_h], "cells": cells, "pieces": pieces, "base": base}


func load_base(data: PackedByteArray) -> int:
	var lowest := 0
	var have := false
	for group in 2:
		var origin := DAT_OBJECTS if group == 0 else DAT_PIECES
		var count := 128 if group == 0 else 256
		for i in count:
			var ptr := data.decode_u32(origin + i * 0x58 + 0x54)
			if ptr != 0 and (not have or ptr < lowest):
				lowest = ptr
				have = true
	return lowest - (DAT_PIECES + 256 * 0x58)


func parse_track_model(data: PackedByteArray, header: int, base: int) -> Variant:
	var nprims := data.decode_s16(header + 0x52)
	var ptr := data.decode_u32(header + 0x54)
	if ptr == 0:
		return null
	var o := ptr - base
	var nverts := data.decode_s32(o)
	var verts: Array = []
	var p := o + 4
	for _vert in nverts:
		verts.append([
			[data.decode_s16(p), data.decode_s16(p + 2), data.decode_s16(p + 4)],
			[data.decode_s16(p + 8), data.decode_s16(p + 10), data.decode_s16(p + 12)],
			[data[p + 16], data[p + 17], data[p + 18]],
		])
		p += 20
	var prims: Array = []
	for _prim in nprims:
		var kind := data[p]
		var quad := kind == 5 or kind == 7
		var idx: Array = []
		for k in (4 if quad else 3):
			idx.append(data[p + 4 + k])
		var uvs := [split_uv(data.decode_u16(p + 24)), split_uv(data.decode_u16(p + 28)), split_uv(data.decode_u16(p + 32))]
		if quad:
			uvs.append(split_uv(data.decode_u16(p + 34)))
		prims.append({
			"kind": kind,
			"double": data[p + 2],
			"idx": idx,
			"uv": uvs,
			"clut": data.decode_u16(p + 26),
			"tpage": data.decode_u16(p + 30),
			"raw3": data[p + 3],
		})
		p += 44 if quad else 40
	return {"verts": verts, "prims": prims}


func split_uv(packed: int) -> Array:
	return [packed & 0xff, packed >> 8]


func swap_cells(track: Dictionary, trk: PackedByteArray) -> void:
	var data: PackedByteArray = track.data
	var base: int = track.base
	var cells: Array = track.cells
	var pieces: Dictionary = track.pieces
	for i in 256:
		var at := TRK_CELL_SWAPS + i * 4
		var cell := trk.decode_s16(at)
		if cell == -1:
			continue
		var piece_id := trk[at + 2]
		var flags := trk[at + 3]
		var old: Array = cells[cell]
		cells[cell] = [piece_id, flags, old[2], old[3]]
		if piece_id != 0xff and not pieces.has(piece_id):
			pieces[piece_id] = parse_track_model(data, DAT_PIECES + piece_id * 0x58, base)


func object_table(data: PackedByteArray) -> Array:
	var objects: Array = []
	for i in OBJECT_COUNT:
		var o := DAT_OBJECT_TABLE + i * 0x14
		var row: Array = []
		for k in 8:
			row.append(data.decode_s16(o + k * 2))
		objects.append(row)
	return objects


func object_models(data: PackedByteArray, objects: Array, base: int) -> Dictionary:
	var models := {}
	for obj in objects:
		var kind: int = obj[3]
		var model_id: int = obj[7]
		if kind > 1 and not models.has(model_id):
			var parsed = parse_track_model(data, DAT_OBJECTS + model_id * 0x58, base)
			if parsed != null:
				models[model_id] = parsed
	return models


func translate_piece(local: Array, cx: int, cy: int, cz: int, singles: Array, single_types: Array, doubles: Array, double_types: Array) -> void:
	for item in local:
		var src: Array = item[0]
		var tri: Array = []
		tri.resize(3)
		for k in 3:
			var corner: Array = src[k]
			var raw: Array = corner[0]
			tri[k] = [[
				(cx - int(raw[0])) * UNIT_METRES,
				(cy - int(raw[1])) * UNIT_METRES,
				(cz - int(raw[2])) * UNIT_METRES,
			], corner[1], corner[2], corner[3]]
		var edge_u: Array = sub3(tri[1][0], tri[0][0])
		var edge_v: Array = sub3(tri[2][0], tri[0][0])
		var face: Array = cross(edge_u, edge_v)
		var n0: Array = tri[0][1]
		var n1: Array = tri[1][1]
		var n2: Array = tri[2][1]
		var shading := [n0[0] + n1[0] + n2[0], n0[1] + n1[1] + n2[1], n0[2] + n1[2] + n2[2]]
		if dot3(face, shading) > 0.0:
			tri = [tri[0], tri[2], tri[1]]
		if item[1] == 0:
			singles.append(tri)
			single_types.append(item[2])
		else:
			doubles.append(tri)
			double_types.append(item[2])


func write_png(image: Image, path: String, errors: Array) -> void:
	if image.save_png(path) != OK:
		errors.append(path)


func model_triangles(model: Dictionary, xform: Dictionary, combos: Dictionary, atlas_w: int, atlas_h: int, wind: bool = true) -> Array:
	var out: Array = []
	for prim in model.prims:
		var index: int = combos[Vector2i(prim.tpage, prim.clut)]
		var ox := (index % ATLAS_COLUMNS) * TILE
		var oy := (divi(index, ATLAS_COLUMNS)) * TILE
		var corners: Array = []
		for k in prim.idx.size():
			var placed := transform_vert(model.verts[prim.idx[k]], xform)
			var uv: Array = prim.uv[k]
			placed.append([(ox + uv[0] + 0.5) / float(atlas_w), (oy + uv[1] + 0.5) / float(atlas_h)])
			corners.append(placed)
		if prim.kind == 1 or prim.kind == 5:
			var flat: Array = corners[0][2]
			for corner in corners:
				corner[2] = flat
		var tris: Array = [corners.slice(0, 3)]
		if corners.size() == 4:
			tris = [corners.slice(0, 3), [corners[1], corners[3], corners[2]]]
		var double := 1 if prim.double != 0 else 0
		var surface: int = prim.raw3 & 0xfe
		for tri in tris:
			if wind:
				var face := cross(sub3(tri[1][0], tri[0][0]), sub3(tri[2][0], tri[0][0]))
				var shading := [
					tri[0][1][0] + tri[1][1][0] + tri[2][1][0],
					tri[0][1][1] + tri[1][1][1] + tri[2][1][1],
					tri[0][1][2] + tri[1][1][2] + tri[2][1][2],
				]
				if dot3(face, shading) > 0.0:
					tri = [tri[0], tri[2], tri[1]]
			out.append([tri, double, surface])
	return out


func transform_vert(vert: Array, xform: Dictionary) -> Array:
	var pos: Array = vert[0]
	var nrm: Array = vert[1]
	var rgb: Array = vert[2]
	if xform.has("raw"):
		var fx: int = xform.fx
		var fz: int = xform.fz
		return [
			[pos[2] * fz, pos[1], pos[0] * fx],
			[float(nrm[2] * fz) / 4096.0, float(nrm[1]) / 4096.0, float(nrm[0] * fx) / 4096.0],
			rgb,
		]
	if xform.has("tileset"):
		return [
			[-pos[2] * UNIT_METRES, (256 - pos[1]) * UNIT_METRES, -pos[0] * UNIT_METRES],
			[float(nrm[2]) / 4096.0, float(nrm[1]) / 4096.0, float(nrm[0]) / 4096.0],
			rgb,
		]
	if xform.object:
		return [
			[pos[0] * UNIT_METRES, pos[1] * UNIT_METRES, pos[2] * UNIT_METRES],
			[nrm[0] / 4096.0, nrm[1] / 4096.0, nrm[2] / 4096.0],
			rgb,
		]
	var fx: int = xform.fx
	var fz: int = xform.fz
	return [
		[(xform.cx - pos[2] * fz) * UNIT_METRES, (xform.cy - pos[1]) * UNIT_METRES, (xform.cz - pos[0] * fx) * UNIT_METRES],
		[float(nrm[2] * fz) / 4096.0, float(nrm[1]) / 4096.0, float(nrm[0] * fx) / 4096.0],
		rgb,
	]


func write_triangle_list(bin: BinWriter, tris: Array) -> void:
	var verts := tris.size() * 3
	bin.i32(verts)
	var blob := PackedByteArray()
	blob.resize(verts * 48)
	var at := 0
	for tri in tris:
		for corner in tri:
			var pos: Array = corner[0]
			var nrm: Array = corner[1]
			var rgb: Array = corner[2]
			var uv: Array = corner[3]
			blob.encode_float(at, pos[0])
			blob.encode_float(at + 4, pos[1])
			blob.encode_float(at + 8, pos[2])
			blob.encode_float(at + 12, nrm[0])
			blob.encode_float(at + 16, nrm[1])
			blob.encode_float(at + 20, nrm[2])
			blob.encode_float(at + 24, minf(float(rgb[0]) / 128.0, 1.0))
			blob.encode_float(at + 28, minf(float(rgb[1]) / 128.0, 1.0))
			blob.encode_float(at + 32, minf(float(rgb[2]) / 128.0, 1.0))
			blob.encode_float(at + 36, 1.0)
			blob.encode_float(at + 40, uv[0])
			blob.encode_float(at + 44, uv[1])
			at += 48
	bin.raw(blob)


func load_collision(data: PackedByteArray) -> Dictionary:
	var pointers: Array = []
	var lowest := 0
	var have := false
	for i in COLLISION_POINTERS:
		var ptr := data.decode_u32(DAT_COLLISION + i * 4)
		pointers.append(ptr)
		if ptr != 0 and (not have or ptr < lowest):
			lowest = ptr
			have = true
	var base := lowest - (DAT_COLLISION + COLLISION_POINTERS * 4)
	var blocks := {}
	for piece_id in COLLISION_POINTERS:
		var ptr := int(pointers[piece_id])
		if ptr == 0:
			continue
		var o := ptr - base
		var verts_at := int(data.decode_u32(o)) - base
		var grid: Array = []
		for i in 16:
			grid.append(int(data.decode_u32(o + 4 + i * 4)) - base)
		var faces := {}
		for cell in grid:
			var p: int = cell
			for quad_pass in 2:
				while data[p] != 0xff:
					var index := data[p]
					if not faces.has(index):
						var f := int(data.decode_u32(o + (index + 0x11) * 4)) - base
						var count := 4 if quad_pass == 1 else 3
						var face_verts: Array = []
						for k in count:
							face_verts.append(data[f + k])
						faces[index] = {
							"verts": face_verts,
							"surface": (data.decode_u16(f - 2) >> 8) & 0xfe,
						}
					p += 1
				p += 1
		var nverts := 0
		for face_index in faces:
			for vi in faces[face_index].verts:
				nverts = maxi(nverts, int(vi) + 1)
		var verts: Array = []
		for i in nverts:
			var at := verts_at + i * 20
			verts.append([data.decode_s16(at), data.decode_s16(at + 2), data.decode_s16(at + 4)])
		var face_list: Array = []
		for face_index in faces:
			face_list.append(faces[face_index])
		blocks[piece_id] = {"verts": verts, "faces": face_list}
	return blocks


func build_floor_grid(tris: Array) -> Dictionary:
	var grid := {}
	for tri in tris:
		var min_x := floor_cell(minf(tri[0][0][0], minf(tri[1][0][0], tri[2][0][0])))
		var max_x := floor_cell(maxf(tri[0][0][0], maxf(tri[1][0][0], tri[2][0][0])))
		var min_z := floor_cell(minf(tri[0][0][2], minf(tri[1][0][2], tri[2][0][2])))
		var max_z := floor_cell(maxf(tri[0][0][2], maxf(tri[1][0][2], tri[2][0][2])))
		var gx := min_x
		while gx <= max_x:
			var gz := min_z
			while gz <= max_z:
				var key := Vector2i(gx, gz)
				if not grid.has(key):
					grid[key] = []
				grid[key].append([tri[0][0], tri[1][0], tri[2][0]])
				gz += 1
			gx += 1
	return grid


func floor_cell(value: float) -> int:
	return int(floor(value / FLOOR_CELL))


func heights_at(grid: Dictionary, x: float, z: float) -> Array:
	var key := Vector2i(floor_cell(x), floor_cell(z))
	var out: Array = []
	if not grid.has(key):
		return out
	for tri in grid[key]:
		var a: Array = tri[0]
		var b: Array = tri[1]
		var c: Array = tri[2]
		var det: float = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
		if absf(det) < 1e-9:
			continue
		var l1: float = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / det
		var l2: float = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / det
		var l3: float = 1.0 - l1 - l2
		if minf(l1, minf(l2, l3)) >= -1e-4:
			out.append(l1 * a[1] + l2 * b[1] + l3 * c[1])
	return out


func floor_height(grid: Dictionary, x: float, y: float, z: float) -> float:
	var best := y
	var found := false
	for h in heights_at(grid, x, z):
		if h <= y + 0.05 and (not found or h > best):
			best = h
			found = true
	return best


func byte_lift(b: int, slope: bool) -> int:
	var limit := 0x80 if slope else 0x81
	return b - 0x100 if b >= limit else b


func ai_tables(trk: PackedByteArray) -> Array:
	var thresholds: Array = []
	var speeds: Array = []
	for car_i in 8:
		var o := TRK_AI + car_i * 0xa4
		var th: Array = []
		var sp: Array = []
		th.resize(40)
		sp.resize(40)
		for i in 40:
			th[i] = trk.decode_s16(o + 4 + i * 2)
			sp[i] = trk.decode_s16(o + 0x54 + i * 2)
		thresholds.append(th)
		speeds.append(sp)
	return [thresholds, speeds]


func ai_start(con: PackedByteArray, track_id: int) -> Variant:
	var rows := open_con_rows(con)
	for row in rows:
		var o := CBBYSS + row * 0x6c
		if con[o + 1] == track_id:
			return [con[o + 2] * 25, con[o + 3] * 25]
		if con[o + 0x34] == track_id:
			return [con[o + 0x35] * 25, con[o + 0x36] * 25]
	return null


func pickup_table(con: PackedByteArray, track_id: int) -> Variant:
	var rows := open_con_rows(con)
	for row in rows:
		var o := CBBYSS + row * 0x6c
		var entries := -1
		if con[o + 1] == track_id:
			entries = o + 4
		elif con[o + 0x34] == track_id:
			entries = o + 0x38
		if entries < 0:
			continue
		var table: Array = []
		for i in 12:
			var packed := con[entries + i * 4 + 3]
			table.append([con.decode_s16(entries + i * 4), con[entries + i * 4 + 2], packed & 0xf, packed >> 4])
		return table
	return null


func open_con_rows(con: PackedByteArray) -> int:
	return divi((con.decode_u32(8) - CBBYSS), 0x6c)


func con_bytes(con_path: String) -> PackedByteArray:
	if con_path == "":
		return read_file(disc_root.path_join("INDEX/CBBYSS.CON"))
	return read_file(con_path)


func script_tokens(trk: PackedByteArray) -> Array:
	var tokens: Array = []
	tokens.resize(SCRIPT_TOKENS)
	for i in SCRIPT_TOKENS:
		tokens[i] = trk.decode_s16(TRK_SCRIPT + i * 2)
	return tokens


func water_opcode(trk: PackedByteArray) -> int:
	for i in 0x7f8:
		var op := trk.decode_u16(TRK_SCRIPT + i * 2)
		if op == 0x7d02:
			return -1
		if WATER_OPCODES.has(op):
			return op
	return -1


func water_level(trk: PackedByteArray) -> Variant:
	var op := water_opcode(trk)
	if op < 0:
		return null
	return float(WATER_OPCODES[op]) * UNIT_METRES


func water_regions(trk: PackedByteArray) -> Array:
	if water_opcode(trk) != 0x7d67:
		return []
	var region: Array = []
	for v in RAISED_WATER:
		region.append(v * UNIT_METRES)
	return [region]


func node_grid(trk: PackedByteArray, grid_w: int, grid_d: int) -> Dictionary:
	var zones: Array = []
	for i in 32:
		var z := TRK_NODE_GRID + i * 8
		zones.append([trk[z], trk[z + 4] * 256 + trk[z + 5], trk[z + 6] * 256 + trk[z + 7]])
	var cells: Array = []
	cells.resize(16384)
	var base := TRK_NODE_GRID + 0x100
	for i in 16384:
		cells[i] = trk.decode_u16(base + i * 2)
	return {"size": [grid_w, grid_d], "zones": zones, "cells": cells}


func animation_data(trk: PackedByteArray, combos: Dictionary) -> Dictionary:
	var scrolls: Array = []
	for scroll_i in 16:
		var at := TRK_SCROLL + scroll_i * 12
		var x := trk.decode_s16(at)
		if x == -1:
			break
		var direction := trk.decode_s16(at + 8)
		var speed := trk.decode_s16(at + 10)
		scrolls.append({
			"dir": direction,
			"step": speed * 4 if direction < 2 else speed,
			"rects": atlas_rects(combos, x, trk.decode_s16(at + 2), trk.decode_s16(at + 4), trk.decode_s16(at + 6)),
		})
	var entries: Array = []
	var raw: Array = []
	for flip_i in 16:
		var at := TRK_FLIP + flip_i * 12
		var index := trk.decode_s16(at)
		raw.append(index)
		entries.append({
			"period": trk.decode_s16(at + 2),
			"vram": [trk.decode_s16(at + 4), trk.decode_s16(at + 6), trk.decode_s16(at + 8), trk.decode_s16(at + 10)],
			"rects": atlas_rects(combos, trk.decode_s16(at + 4), trk.decode_s16(at + 6), trk.decode_s16(at + 8), trk.decode_s16(at + 10)),
		})
	var groups: Array = []
	var group_i := 0
	while group_i < 16:
		if raw[group_i] == 0:
			var start := group_i
			var end := 0
			var step_n := 0
			var cursor := group_i
			while step_n < 8:
				var nxt: int = raw[cursor + 1] if cursor + 1 < 16 else 0
				if nxt == -1:
					groups.append([start, cursor])
					return anim_result(trk, scrolls, entries, groups)
				step_n += 1
				if nxt == 0:
					end = cursor
					step_n = 9
				cursor = group_i + step_n
			groups.append([start, end])
		group_i += 1
	return anim_result(trk, scrolls, entries, groups)


func anim_result(trk: PackedByteArray, scrolls: Array, entries: Array, groups: Array) -> Dictionary:
	return {
		"scrolls": scrolls,
		"flip_entries": entries,
		"flip_groups": groups,
		"weather": trk.decode_s32(TRK_WEATHER),
		"texture_pause": trk.decode_s32(TRK_TEXTURE_PAUSE) == 1,
	}


func atlas_rects(combos: Dictionary, vx: int, vy: int, vw: int, vh: int) -> Array:
	if vw <= 0 or vh <= 0 or vx < 0 or vy < 0:
		return []
	var page_x := divi(vx, 64)
	var page_y := 1 if vy >= 256 else 0
	var tex_x := (vx % 64) * 4
	var tex_y := vy % 256
	var tex_w := mini(vw * 4, TILE - tex_x)
	var tex_h := mini(vh, TILE - tex_y)
	if tex_x >= TILE or tex_y >= TILE or tex_w <= 0 or tex_h <= 0:
		return []
	var rects: Array = []
	for combo_key in combos:
		var key: Vector2i = combo_key
		if (key.x & 0xf) != page_x or ((key.x >> 4) & 1) != page_y:
			continue
		var index: int = combos[key]
		rects.append([(index % ATLAS_COLUMNS) * TILE + tex_x, (divi(index, ATLAS_COLUMNS)) * TILE + tex_y, tex_w, tex_h, key.y])
	return rects


func flip_sheet(tex: PackedByteArray, stamp: int, anim: Dictionary) -> Dictionary:
	var crops: Array = []
	var seen := {}
	var entries: Array = anim.flip_entries
	for group in anim.flip_groups:
		var start: int = group[0]
		var end: int = group[1]
		for image in range(start, end + 1):
			var vw: int = entries[image].vram[2]
			var vh: int = entries[image].vram[3]
			if vw <= 0 or vh <= 0:
				continue
			var cluts: Array = []
			for slot in range(start, end + 1):
				var slot_vram: Array = entries[slot].vram
				if slot_vram[2] != vw or slot_vram[3] != vh:
					continue
				for rect in entries[slot].rects:
					if not cluts.has(rect[4]):
						cluts.append(rect[4])
			var vx: int = entries[image].vram[0]
			var vy: int = entries[image].vram[1]
			for clut in cluts:
				var seen_key := Vector2i(image, clut)
				if seen.has(seen_key):
					continue
				seen[seen_key] = true
				var cropped: Array = decode_crop(tex, stamp, vx, vy, vw, vh, clut)
				if cropped[1] <= 0:
					continue
				crops.append([image, clut, cropped[0], cropped[1], cropped[2]])
	if crops.is_empty():
		return {"bank": [], "rgba": PackedByteArray(), "width": 0, "height": 0}
	var max_w := 1024
	var x := 0
	var y := 0
	var row_h := 0
	var placed: Array = []
	for crop in crops:
		var w: int = crop[3]
		var h: int = crop[4]
		if x > 0 and x + w > max_w:
			y += row_h
			x = 0
			row_h = 0
		placed.append([crop[0], crop[1], x, y, w, h, crop[2]])
		x += w
		row_h = maxi(row_h, h)
	var width := x if y == 0 else max_w
	var height := y + row_h
	var buf := PackedByteArray()
	buf.resize(width * height * 4)
	var bank: Array = []
	for spot in placed:
		var sx: int = spot[2]
		var sy: int = spot[3]
		var w: int = int(spot[4])
		var h: int = int(spot[5])
		var rgba: PackedByteArray = spot[6]
		for row in h:
			var dst := ((sy + row) * width + sx) * 4
			var src := row * w * 4
			for b in w * 4:
				buf[dst + b] = rgba[src + b]
		bank.append([spot[0], spot[1], sx, sy, w, h])
	return {"bank": bank, "rgba": buf, "width": width, "height": height}


func decode_crop(tex: PackedByteArray, stamp: int, vx: int, vy: int, vw: int, vh: int, clut: int) -> Array:
	var page_x := divi(vx, 64)
	var page_y := 1 if vy >= 256 else 0
	var tex_x := (vx % 64) * 4
	var tex_y := vy % 256
	var tex_w := mini(vw * 4, TILE - tex_x)
	var tex_h := mini(vh, TILE - tex_y)
	if tex_x >= TILE or tex_y >= TILE or tex_w <= 0 or tex_h <= 0:
		return [PackedByteArray(), 0, 0]
	var tile := cached_tile(tex, page_x | (page_y << 4), clut, stamp)
	return [crop_tile(tile, tex_x, tex_y, tex_w, tex_h), tex_w, tex_h]


func vag_waveforms(vb: PackedByteArray) -> Array:
	var block_count := vb.size() / 16
	var found: Array = []
	var i := 0
	while i < block_count:
		var start := i
		while (vb[i * 16 + 1] & 1) == 0:
			i += 1
			if i >= block_count:
				fail("sound data ended early")
				return []
		found.append(decode_vag(vb, start, i))
		if i + 1 < block_count and (vb[(i + 1) * 16 + 1] & 1) != 0:
			i += 2
		else:
			i += 1
	return found


func decode_vag(vb: PackedByteArray, start: int, end_block: int) -> PackedInt32Array:
	var older := 0
	var old := 0
	var pcm := PackedInt32Array()
	for block in range(start, end_block + 1):
		var at := block * 16
		var shift: int = vb[at] & 0x0f
		var filter: Array = FILTERS[vb[at] >> 4]
		var f0: int = filter[0]
		var f1: int = filter[1]
		for byte_i in range(2, 16):
			var byte := vb[at + byte_i]
			for nibble_i in 2:
				var nibble := byte & 0x0f if nibble_i == 0 else byte >> 4
				if nibble >= 8:
					nibble -= 16
				var sample := (nibble << 12) >> shift
				sample += (old * f0 + older * f1 + 32) >> 6
				sample = clampi(sample, -32768, 32767)
				older = old
				old = sample
				pcm.append(sample)
	return pcm


func sheet(tex: PackedByteArray, stamp: int, tpage: int, clut: int, height: int) -> Array:
	var tile := cached_tile(tex, tpage, clut, stamp)
	if height >= TILE:
		return [tile, TILE, TILE]
	return [crop_tile(tile, 0, 0, TILE, height), TILE, height]


func wake_image(data: PackedByteArray) -> Array:
	var p := 0x8000 + 8
	var clut_bytes := data.decode_u32(p)
	var palette: Array = []
	for i in 16:
		var c := data.decode_u16(p + 12 + i * 2)
		if c == 0:
			palette.append([0, 0, 0, 0])
		else:
			palette.append([divi((c & 31) * 255, 31), divi(((c >> 5) & 31) * 255, 31), divi(((c >> 10) & 31) * 255, 31), 255])
	p += clut_bytes
	var pixels := data.slice(p + 12, p + data.decode_u32(p))
	var rgba := PackedByteArray()
	rgba.resize(256 * 32 * 4)
	var dst := 0
	for row in 32:
		for u in 256:
			var texel := pixels.decode_u16(row * 128 + (divi(u, 4)) * 2)
			var color: Array = palette[(texel >> ((u % 4) * 4)) & 0xf]
			rgba[dst] = color[0]
			rgba[dst + 1] = color[1]
			rgba[dst + 2] = color[2]
			rgba[dst + 3] = color[3]
			dst += 4
	return [rgba, 256, 32]


func export_icons(data: PackedByteArray, path: String) -> void:
	if data.is_empty():
		return
	var o := 0xf840 + 8
	var clut_len := data.decode_u32(o)
	var palette: Array = []
	for i in 16:
		var c := data.decode_u16(o + 12 + i * 2)
		palette.append([
			divi((c & 31) * 255, 31),
			divi(((c >> 5) & 31) * 255, 31),
			divi(((c >> 10) & 31) * 255, 31),
			0 if c == 0 else 255,
		])
	var p := o + clut_len
	var pix_len := data.decode_u32(p)
	var w := data.decode_u16(p + 8)
	var h := data.decode_u16(p + 10)
	var pixels := data.slice(p + 12, p + pix_len)
	var width := w * 4
	var rgba := PackedByteArray()
	rgba.resize(width * h * 4)
	var dst := 0
	for v in h:
		for u in width:
			var color: Array = palette[(pixels[v * w * 2 + divi(u, 2)] >> ((u & 1) * 4)) & 15]
			rgba[dst] = color[0]
			rgba[dst + 1] = color[1]
			rgba[dst + 2] = color[2]
			rgba[dst + 3] = color[3]
			dst += 4
	save_rgba(path, width, h, rgba)


func export_previews() -> void:
	var world := read_file(disc_root.path_join("WORLD/WORLD.DAT"))
	var con := read_file(disc_root.path_join("INDEX/CBBYSS.CON"))
	if fault != "":
		return
	var colors := world_colors(con, 0x1038 + 0x10, 8)
	var tracks: Array = []
	var weather: Array = []
	for slot in 32:
		var ribbon: Array = ribbon_slot(world, slot)
		weather.append(ribbon[0])
		tracks.append(ribbon[1])
	var path := project_dir.path_join("tracks/previews.json")
	var old = read_json(path)
	if old != null and old.tracks.size() > tracks.size():
		for i in range(colors.size(), old.colors.size()):
			colors.append(old.colors[i])
		for i in range(weather.size(), old.weather.size()):
			weather.append(old.weather[i])
		for i in range(tracks.size(), old.tracks.size()):
			tracks.append(old.tracks[i])
	write_json(path, {"colors": colors, "weather": weather, "tracks": tracks})


func export_menu_icons() -> void:
	var tex := read_file(disc_root.path_join("WORLD/WORLD.TIM"))
	var con := read_file(disc_root.path_join("INDEX/CBBYSS.CON"))
	if fault != "":
		return
	var colors := world_colors(con, 0x1038 + 0x10, 8)
	var out := project_dir.path_join("textures/menu")
	var stamp := int(file_stamp[disc_root.path_join("WORLD/WORLD.TIM")])
	var page_a := cached_tile(tex, 0x3a, WORLD_CLUT, stamp)
	var page_b := cached_tile(tex, 0x3b, WORLD_CLUT, stamp)
	for i in WORLDS.size():
		var cell := i & 3
		var page := page_a if i < 4 else page_b
		var rgba := crop_tile(page, 128 if (cell & 1) != 0 else 0, 128 if (cell & 2) != 0 else 0, 128, 128)
		var vertex: Array = colors[i]
		save_rgba(out.path_join(WORLDS[i][1] + ".png"), 128, 128, modulate(rgba, [(vertex[0] * 0x58) >> 8, (vertex[1] * 0x58) >> 8, (vertex[2] * 0x58) >> 8]))
	var glyphs := cached_tile(tex, 0x3d, WEATHER_CLUT, stamp)
	for i in WEATHER_TINT.size():
		var rgba := crop_tile(glyphs, i * 24 + 64, 64, 24, 24)
		save_rgba(out.path_join("weather_%d.png" % i), 24, 24, modulate(rgba, WEATHER_TINT[i]))


func merge_addon_previews(files: Dictionary) -> void:
	var world: PackedByteArray = files["WORLD/WORLD.DAT"]
	var con: PackedByteArray = files["INDEX/CBBYSS.CON"]
	var base := con.decode_u32(16)
	var colors := world_colors(con, base + 0x10, ADDON.size())
	var weather: Array = []
	var tracks: Array = []
	for slot in ADDON.size() * 4:
		var ribbon: Array = ribbon_slot(world, slot)
		weather.append(ribbon[0])
		tracks.append(ribbon[1])
	var path := project_dir.path_join("tracks/previews.json")
	var data = read_json(path)
	var merged_colors: Array = []
	for i in 8:
		merged_colors.append(data.colors[i])
	for color in colors:
		merged_colors.append(color)
	var merged_weather: Array = []
	for i in 32:
		merged_weather.append(data.weather[i])
	for icon in weather:
		merged_weather.append(icon)
	var merged_tracks: Array = []
	for i in 32:
		merged_tracks.append(data.tracks[i])
	for extra in tracks:
		merged_tracks.append(extra)
	write_json(path, {"colors": merged_colors, "weather": merged_weather, "tracks": merged_tracks})


func export_addon_icons(files: Dictionary) -> void:
	var tex: PackedByteArray = files["WORLD/WORLD.TIM"]
	var con: PackedByteArray = files["INDEX/CBBYSS.CON"]
	var colors := world_colors(con, con.decode_u32(16) + 0x10, ADDON.size())
	var out := project_dir.path_join("textures/menu")
	file_cache["addon-world-tim"] = tex
	file_stamp["addon-world-tim"] = file_stamp.size()
	var stamp := int(file_stamp["addon-world-tim"])
	var page := cached_tile(tex, 0x3a, WORLD_CLUT, stamp)
	for i in ADDON.size():
		var rgba := crop_tile(page, 128 if (i & 1) != 0 else 0, 0, 128, 128)
		var vertex: Array = colors[i]
		save_rgba(out.path_join(ADDON[i][2] + ".png"), 128, 128, modulate(rgba, [(vertex[0] * 0x58) >> 8, (vertex[1] * 0x58) >> 8, (vertex[2] * 0x58) >> 8]))


func write_addon_races() -> void:
	var forward: Array = []
	var reverse: Array = []
	for index in ADDON.size():
		var slug: String = ADDON[index][2]
		var ahead: Array = []
		var back: Array = []
		for number in range(1, 5):
			ahead.append("res://tracks/%s%d" % [slug, number])
			back.append("res://tracks/%s%dr" % [slug, number])
		forward.append({"group": 9 + index, "tracks": ahead})
		reverse.append({"group": 9 + ADDON.size() + index, "tracks": back})
	forward.append_array(reverse)
	write_json(project_dir.path_join("tracks/addon.json"), forward)


func ribbon_slot(world: PackedByteArray, slot: int) -> Array:
	var o := PREVIEW_BASE + slot * PREVIEW_STRIDE
	var count := world.decode_s32(o + 0x1828)
	var icon := world.decode_s32(o + 0x182c)
	if icon == 6:
		icon = 0
	return [icon, {
		"h0": world.decode_s32(o + 0x1810),
		"h1": world.decode_s32(o + 0x1814),
		"x0": read_s16s(world, o, count),
		"z0": read_s16s(world, o + 0x400, count),
		"x1": read_s16s(world, o + 0x800, count),
		"z1": read_s16s(world, o + 0xc00, count),
		"h": read_s16s(world, o + 0x1000, count),
		"a": read_bytes(world, o + 0x1400, count),
		"b": read_bytes(world, o + 0x1600, count),
	}]


func read_s16s(data: PackedByteArray, at: int, count: int) -> Array:
	var values: Array = []
	values.resize(count)
	for i in count:
		values[i] = data.decode_s16(at + i * 2)
	return values


func read_bytes(data: PackedByteArray, at: int, count: int) -> Array:
	var values: Array = []
	values.resize(count)
	for i in count:
		values[i] = data[at + i]
	return values


func world_colors(con: PackedByteArray, base_off: int, count: int) -> Array:
	var colors: Array = []
	for i in count:
		colors.append([con[base_off + (i * 3) * 4], con[base_off + (i * 3 + 1) * 4], con[base_off + (i * 3 + 2) * 4]])
	return colors


func modulate(rgba: PackedByteArray, rgb: Array) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(rgba.size())
	var i := 0
	while i < rgba.size():
		if rgba[i + 3] == 0:
			i += 4
			continue
		out[i] = mini(255, (rgba[i] * int(rgb[0])) >> 7)
		out[i + 1] = mini(255, (rgba[i + 1] * int(rgb[1])) >> 7)
		out[i + 2] = mini(255, (rgba[i + 2] * int(rgb[2])) >> 7)
		out[i + 3] = 255
		i += 4
	return out


func export_races(con: PackedByteArray) -> void:
	var menu := con.decode_u32(0)
	var shift := con[menu + 9]
	var groups := {}
	for row in CBBYSS_ROWS:
		var o := CBBYSS + row * 0x6c
		var group := con[o]
		if not groups.has(group):
			groups[group] = []
		groups[group].append(directory_for(con[o + 1], []))
		var back := group + shift
		if not groups.has(back):
			groups[back] = []
		groups[back].append(directory_for(con[o + 0x34], []))
	var order: Array = []
	for group_id in groups:
		order.append(group_id)
	order.sort()
	var races: Array = []
	for group_id in order:
		races.append({"group": group_id, "tracks": groups[group_id]})
	write_json(project_dir.path_join("tracks/races.json"), races)


func export_names(con: PackedByteArray, slugs: Array) -> void:
	var path := project_dir.path_join("tracks/names.json")
	var named = read_json(path)
	if named == null:
		named = {}
	var labels := english_names(con)
	var rows_at := con.decode_u32(4)
	var rows_end := con.decode_u32(8)
	for row in divi((rows_end - rows_at), 0x6c):
		var o := rows_at + row * 0x6c
		var label: String = labels[con[o + 0x68]]
		named[directory_for(con[o + 1], slugs)] = label
		named[directory_for(con[o + 0x34], slugs)] = label
	var courses_at := rows_end
	var courses_end := con.decode_u32(12)
	for row in divi((courses_end - courses_at), 0x14):
		var o := courses_at + row * 0x14
		var label: String = labels[con[o + 0x10]]
		named[directory_for(con[o], slugs)] = label
		named[directory_for(con[o + 8], slugs)] = label
	write_json(path, named)


func english_names(con: PackedByteArray) -> Array:
	var at := int(con.decode_u32(0x24))
	var names: Array = []
	while names.size() < 16:
		var end := con.find(0, at)
		names.append(title_ascii(con.slice(at, end).get_string_from_ascii()))
		at = end + 1
	return names


func directory_for(track_id: int, slugs: Array) -> String:
	var track := track_id - 1
	var slug: String = WORLDS[divi(track, 8)][1] if slugs.is_empty() else slugs[divi(track, 8)]
	var number := (track % 4) + 1
	var reverse := track % 8 >= 4
	var prefix: String = DIR_PREFIX[slug] if DIR_PREFIX.has(slug) else slug
	return "res://tracks/%s%d%s" % [prefix, number, "r" if reverse else ""]


func world_slugs() -> Array:
	var slugs: Array = []
	for world in WORLDS:
		slugs.append(world[1])
	return slugs


func addon_slugs() -> Array:
	var slugs: Array = []
	for spec in ADDON:
		slugs.append(spec[2])
	return slugs


func addon_id(world: int, number: int, reverse: bool) -> int:
	return world * 8 + number - 1 + (4 if reverse else 0) + 1


func track_number(track_name: String, world: String) -> int:
	var reverse := track_name.ends_with("R")
	var number := track_name.substr(world.length(), 1).to_int()
	var index := 0
	for entry in WORLDS:
		if entry[0] == world:
			break
		index += 1
	return index * 8 + number - 1 + (4 if reverse else 0) + 1


func title_ascii(text: String) -> String:
	var out := ""
	var up := true
	for i in text.length():
		var ch := text.unicode_at(i)
		var letter := (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122)
		if letter:
			if up and ch >= 97:
				ch -= 32
			elif not up and ch <= 90:
				ch += 32
			up = false
		else:
			up = true
		out += String.chr(ch)
	return out


func cached_tile(tex: PackedByteArray, tpage: int, clut: int, stamp: int) -> PackedByteArray:
	if tile_for != stamp:
		tile_for = stamp
		tiles = {}
	var key := tpage | (clut << 16)
	if tiles.has(key):
		return tiles[key]
	var rgba := decode_tile(tex, tpage, clut)
	tiles[key] = rgba
	return rgba


func decode_tile(tex: PackedByteArray, tpage: int, clut: int) -> PackedByteArray:
	var base_x := (tpage & 0xf) * 64
	var base_y := ((tpage >> 4) & 1) * 256
	var clut_x := (clut & 0x3f) * 16
	var clut_y := (clut >> 6) & 0x1ff
	var pal := PackedByteArray()
	pal.resize(64)
	for i in 16:
		var c := vram(tex, clut_x + i, clut_y)
		if c == 0:
			continue
		var o := i * 4
		pal[o] = divi(((c & 31) * 255), 31)
		pal[o + 1] = divi((((c >> 5) & 31) * 255), 31)
		pal[o + 2] = divi((((c >> 10) & 31) * 255), 31)
		pal[o + 3] = 255
	var rgba := PackedByteArray()
	rgba.resize(TILE * TILE * 4)
	var dst := 0
	for v in TILE:
		var y := base_y + v
		var block := (divi(base_x, 64) - TEX_FIRST_PAGE) + (divi(y, 256)) * TEX_PAGES_PER_ROW
		var row_at := block * 32768 + (y % 256) * 128
		for u_group in 64:
			var word := tex.decode_u16(row_at + u_group * 2)
			for nibble_i in 4:
				var idx := (word >> (nibble_i * 4)) & 0xf
				var po := idx * 4
				rgba[dst] = pal[po]
				rgba[dst + 1] = pal[po + 1]
				rgba[dst + 2] = pal[po + 2]
				rgba[dst + 3] = pal[po + 3]
				dst += 4
	return rgba


func vram(tex: PackedByteArray, x: int, y: int) -> int:
	var block := (divi(x, 64) - TEX_FIRST_PAGE) + (divi(y, 256)) * TEX_PAGES_PER_ROW
	return tex.decode_u16(block * 32768 + (y % 256) * 128 + (x % 64) * 2)


func crop_tile(tile: PackedByteArray, u: int, v: int, w: int, h: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h * 4)
	var dst := 0
	for row in h:
		var src := ((v + row) * TILE + u) * 4
		for b in w * 4:
			out[dst + b] = tile[src + b]
		dst += w * 4
	return out


func blit_tile(atlas: Image, tile: PackedByteArray, ox: int, oy: int) -> void:
	var image := Image.create_from_data(TILE, TILE, false, Image.FORMAT_RGBA8, tile)
	atlas.blit_rect(image, Rect2i(0, 0, TILE, TILE), Vector2i(ox, oy))


func to_godot(pos: Array, offset: Array) -> Array:
	return [
		(-pos[2] - offset[0]) * UNIT_METRES,
		(offset[1] - pos[1]) * UNIT_METRES,
		(-pos[0] - offset[2]) * UNIT_METRES,
	]


func face_normal(pts: Array) -> Array:
	var n := cross(sub3(pts[2], pts[0]), sub3(pts[1], pts[0]))
	var length := sqrt(dot3(n, n))
	if length == 0.0:
		length = 1.0
	return [n[0] / length, n[1] / length, n[2] / length]


func sub3(a: Array, b: Array) -> Array:
	return [a[0] - b[0], a[1] - b[1], a[2] - b[2]]


func cross(a: Array, b: Array) -> Array:
	return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


func dot3(a: Array, b: Array) -> float:
	return float(a[0]) * float(b[0]) + float(a[1]) * float(b[1]) + float(a[2]) * float(b[2])


func divi(a: int, b: int) -> int:
	return int(float(a) / float(b))


func wheel_radius(model: Dictionary) -> int:
	var radius := 0
	for vert in model.verts:
		var pos: Array = vert[0]
		radius = maxi(radius, maxi(absi(pos[0]), absi(pos[1])))
	return radius


func export_tilesets() -> void:
	for world in WORLDS:
		phase("%s tiles" % world[1])
		export_tileset_world(world[0], world[1])
		if fault != "":
			return
		phase_done()


func export_tileset_world(world: String, slug: String) -> void:
	var collected: Array = collect_pieces(world)
	if fault != "":
		return
	var tex: PackedByteArray = collected[0]
	var pieces: Array = collected[1]
	var tex_path := disc_root.path_join(world).path_join(world + "1.TEX")
	var stamp := int(file_stamp[tex_path])
	var combos := {}
	for entry in pieces:
		var piece: Dictionary = entry[0]
		for prim in piece.prims:
			var key := Vector2i(prim.tpage, prim.clut)
			if not combos.has(key):
				combos[key] = combos.size()
	var columns := ATLAS_COLUMNS
	var rows := divi(combos.size() + columns - 1, columns)
	var atlas_w := columns * TILE
	var atlas_h := maxi(rows, 1) * TILE
	var atlas_image := Image.create(atlas_w, atlas_h, false, Image.FORMAT_RGBA8)
	var tile_image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for combo_key in combos:
		var key: Vector2i = combo_key
		var index: int = combos[key]
		var ox := (index % columns) * TILE
		var oy := divi(index, columns) * TILE
		tile_image.set_data(TILE, TILE, false, Image.FORMAT_RGBA8, cached_tile(tex, key.x, key.y, stamp))
		atlas_image.blit_rect(tile_image, Rect2i(0, 0, TILE, TILE), Vector2i(ox, oy))
	var out := project_dir.path_join("tilesets").path_join(slug)
	ensure_dir(out)
	if atlas_image.save_png(out.path_join("atlas.png")) != OK:
		fail("Could not write " + out)
		return
	var atlas := atlas_image.get_data()
	var tiles_info: Array = []
	var baked_all: Array = []
	baked_all.resize(pieces.size())
	var bin := BinWriter.new()
	bin.i32(pieces.size())
	var place := {"tileset": true}
	for index in pieces.size():
		var entry: Array = pieces[index]
		var piece: Dictionary = entry[0]
		var baked: Array = model_triangles(piece, place, combos, atlas_w, atlas_h)
		baked_all[index] = baked
		var collision: Array = bake_tileset_collision(entry[1])
		var singles: Array = []
		var doubles: Array = []
		for item in baked:
			if item[1] == 0:
				singles.append(item)
			else:
				doubles.append(item)
		write_tileset_surface(bin, singles)
		write_tileset_surface(bin, doubles)
		bin.i32(collision[0].size())
		for tri in collision[0]:
			for point in tri:
				bin.f32(point[0])
				bin.f32(point[1])
				bin.f32(point[2])
		for surface in collision[1]:
			bin.u8(surface)
		tiles_info.append({"name": entry[2], "mesh": index})
	write_bytes(out.path_join("pieces.bin"), bin.bytes())
	var colors: Array = []
	for index in pieces.size():
		colors.append(piece_color(baked_all[index], atlas, atlas_w, atlas_h))
	var info := {
		"id": slug,
		"name": title_ascii(slug.replace("_", " ")),
		"layer": 256,
		"groups": assign_groups(colors, tiles_info),
		"tiles": tiles_info,
	}
	write_json(out.path_join("tileset.json"), info)
	write_tileset_courses(world, slug, collected)


func collect_pieces(world: String) -> Array:
	var root := disc_root.path_join(world)
	var tex := read_file(root.path_join(world + "1.TEX"))
	if fault != "":
		return []
	var found := {}
	var order: Array = []
	for number in range(1, 5):
		var name := "%s%d" % [world, number]
		var data := read_file(root.path_join(name + ".DAT"))
		var trk := read_file(root.path_join(name + ".TRK"))
		if fault != "":
			return []
		var track := load_track(data)
		swap_cells(track, trk)
		var blocks := load_collision(data)
		var ids: Array = track.pieces.keys()
		ids.sort()
		for piece_id in ids:
			var piece = track.pieces[piece_id]
			if piece == null:
				continue
			var key := piece_hash(piece)
			if found.has(key):
				continue
			var block = blocks.get(piece_id)
			found[key] = [piece, block, "%s %d" % [name.to_lower(), piece_id]]
			order.append(key)
	var pieces: Array = []
	for key in order:
		pieces.append(found[key])
	return [tex, pieces]


func piece_hash(piece: Dictionary) -> String:
	var blob := PackedByteArray()
	for vert in piece.verts:
		var pos: Array = vert[0]
		append_s16(blob, pos[0])
		append_s16(blob, pos[1])
		append_s16(blob, pos[2])
	for prim in piece.prims:
		var idx: Array = prim.idx
		for k in mini(idx.size(), 8):
			blob.append(int(idx[k]))
		blob.append(int(prim.kind))
		blob.append(int(prim.double))
		blob.append(int(prim.tpage) & 0xff)
		blob.append(int(prim.clut) & 0xff)
		for uv in prim.uv:
			blob.append(int(uv[0]) & 0xff)
			blob.append(int(uv[1]) & 0xff)
	return blob.hex_encode()


func append_s16(blob: PackedByteArray, value: int) -> void:
	blob.append(value & 0xff)
	blob.append((value >> 8) & 0xff)


func bake_tileset_collision(block) -> Array:
	var tris: Array = []
	var surfaces: Array = []
	if block == null:
		return [tris, surfaces]
	for face in block.faces:
		var pts: Array = []
		for vi in face.verts:
			var vert: Array = block.verts[vi]
			pts.append([
				-vert[2] * UNIT_METRES,
				(256 - vert[1]) * UNIT_METRES,
				-vert[0] * UNIT_METRES,
			])
		var groups: Array = [pts.slice(0, 3)]
		if pts.size() == 4:
			groups = [pts.slice(0, 3), [pts[1], pts[3], pts[2]]]
		for tri in groups:
			tris.append(tri)
			surfaces.append(int(face.surface) & 0xfe)
	return [tris, surfaces]


func write_tileset_surface(bin: BinWriter, tris: Array) -> void:
	bin.i32(tris.size() * 3)
	for item in tris:
		var tri: Array = item[0]
		for corner in tri:
			var rgb: Array = corner[2]
			bin.vertex(corner[0], corner[1], [
				minf(float(rgb[0]) / 128.0, 1.0),
				minf(float(rgb[1]) / 128.0, 1.0),
				minf(float(rgb[2]) / 128.0, 1.0),
				1.0,
			], corner[3])


func piece_color(tris: Array, atlas: PackedByteArray, atlas_w: int, atlas_h: int) -> Array:
	var samples: Array = []
	for item in tris:
		var corners: Array = item[0]
		var area := tri_area(corners[0][0], corners[1][0], corners[2][0])
		if area < 1.0e-8:
			continue
		var color := lit_sample(corners, atlas, atlas_w, atlas_h)
		samples.append([color[0], color[1], color[2], color[3], area])
	if samples.is_empty():
		return [128, 128, 128]
	samples.sort_custom(func(a, b): return a[3] > b[3])
	var total := 0.0
	for sample in samples:
		total += float(sample[4])
	var need := total * 0.25
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	var got := 0.0
	for sample in samples:
		var take := minf(float(sample[4]), need - got)
		red += float(sample[0]) * take
		green += float(sample[1]) * take
		blue += float(sample[2]) * take
		got += take
		if got >= need:
			break
	return [int(round(red / got)), int(round(green / got)), int(round(blue / got))]


func lit_sample(corners: Array, atlas: PackedByteArray, atlas_w: int, atlas_h: int) -> Array:
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	for corner in corners:
		var normal: Array = corner[1]
		var rgb: Array = corner[2]
		var uv: Array = corner[3]
		var light := 0.72 + 0.28 * maxf(0.0, float(normal[1]) * 0.65 + float(normal[0]) * 0.25 + float(normal[2]) * 0.25)
		var tx := clampi(int(float(uv[0]) * atlas_w), 0, atlas_w - 1)
		var ty := clampi(int(float(uv[1]) * atlas_h), 0, atlas_h - 1)
		var ti := (ty * atlas_w + tx) * 4
		var sr := maxf(0.55, minf(float(rgb[0]), 255.0) / 128.0) * light
		var sg := maxf(0.55, minf(float(rgb[1]), 255.0) / 128.0) * light
		var sb := maxf(0.55, minf(float(rgb[2]), 255.0) / 128.0) * light
		red += float(atlas[ti]) * sr
		green += float(atlas[ti + 1]) * sg
		blue += float(atlas[ti + 2]) * sb
	var count := float(corners.size())
	red /= count
	green /= count
	blue /= count
	return [red, green, blue, 0.3 * red + 0.59 * green + 0.11 * blue]


func tri_area(a: Array, b: Array, c: Array) -> float:
	var crossed := cross(sub3(b, a), sub3(c, a))
	return sqrt(dot3(crossed, crossed)) * 0.5


func write_tileset_courses(world: String, slug: String, collected: Array) -> void:
	var pieces: Array = collected[1]
	var index_of := {}
	for index in pieces.size():
		index_of[piece_hash(pieces[index][0])] = index
	var scale := divi(TILESET_CUBE, 256)
	var out := project_dir.path_join("tilesets").path_join(slug).path_join("courses")
	var title := title_ascii(slug.replace("_", " "))
	var root := disc_root.path_join(world)
	var vehicle := 0
	if TILESET_VEHICLE.has(slug):
		vehicle = int(TILESET_VEHICLE[slug])
	for number in range(1, 5):
		for reverse_pass in 2:
			var reverse := reverse_pass == 1
			var tag := "%d%s" % [number, "r" if reverse else ""]
			var disc_name := "%s%d%s" % [world, number, "R" if reverse else ""]
			var data := read_file(root.path_join(disc_name + ".DAT"))
			var trk := read_file(root.path_join(disc_name + ".TRK"))
			if fault != "":
				return
			var track := load_track(data)
			swap_cells(track, trk)
			var course: Array = course_parts(track, trk, index_of, scale)
			write_json(out.path_join(tag + ".json"), {
				"name": "%s %s" % [title, tag.to_upper()],
				"vehicle": vehicle,
				"tileset": slug,
				"parts": course[0],
				"road": course[1],
				"line": course[2],
				"joined": true,
			})


func course_parts(track: Dictionary, trk: PackedByteArray, index_of: Dictionary, scale: int) -> Array:
	var grid_w: int = track.dims[0]
	var grid_d: int = track.dims[1]
	var parts: Array = []
	var columns := {}
	for i in track.cells.size():
		var cell: Array = track.cells[i]
		var piece_index: int = cell[0]
		if piece_index == 0xff or track.pieces.get(piece_index) == null:
			continue
		var col: int = i % grid_w
		var row: int = divi(i, grid_w) % grid_d
		var layer: int = divi(i, grid_w * grid_d)
		var ex: int = col - divi(grid_w, 2)
		var ez: int = row - divi(grid_d, 2)
		var flags: int = cell[1]
		parts.append({
			"x": ex,
			"y": layer * scale - 1,
			"z": ez,
			"piece": 4,
			"rot": 0,
			"slope": 0,
			"pitch": 0,
			"distance": 24,
			"type": 7,
			"tile": TILESET_MARKERS + int(index_of[piece_hash(track.pieces[piece_index])]),
			"mirror": flags & 3,
			"lap": 0,
		})
		var column_key := Vector2i(ex, ez)
		if not columns.has(column_key):
			columns[column_key] = []
		columns[column_key].append(layer)
	var count := trk.decode_s32(0xC900)
	var path: Array = []
	var line: Array = []
	for n in count:
		var o := n * 0x24
		if trk[o] == 0x80:
			continue
		var x := trk.decode_s16(o + 0x14)
		var z := trk.decode_s16(o + 0x16)
		var y := trk.decode_s16(o + 0x22)
		var lx := trk.decode_s16(o + 8)
		var lz := trk.decode_s16(o + 10)
		var rx := trk.decode_s16(o + 12)
		var rz := trk.decode_s16(o + 14)
		var ax := trk.decode_s16(o + 4)
		var az := trk.decode_s16(o + 6)
		var bx := trk.decode_s16(o + 0x10)
		var bz := trk.decode_s16(o + 0x12)
		var cam := TRK_CAMERAS + n * 12
		line.append({
			"x": x - 256,
			"y": y,
			"z": z - 256,
			"h": (-(trk[o] << 7)) & 0xfff,
			"lx": lx - 256,
			"lz": lz - 256,
			"rx": rx - 256,
			"rz": rz - 256,
			"ax": ax - 256,
			"az": az - 256,
			"bx": bx - 256,
			"bz": bz - 256,
			"lift": [byte_lift(trk[o + 0x1f], false), byte_lift(trk[o + 0x1d], false)],
			"lane_lift": [byte_lift(trk[o + 0x1e], false), byte_lift(trk[o + 0x1c], false)],
			"slope": [byte_lift(trk[o + 2], true), byte_lift(trk[o + 3], true)],
			"camera": [trk[cam], trk[cam + 3], trk[cam + 6], trk[cam + 9], trk[o + 0x18]],
			"battle_camera": [trk[cam + 4], trk[cam + 7], trk[cam + 10]],
		})
		var ex := floordiv(x, 512)
		var ez := floordiv(z, 512)
		var column_key := Vector2i(ex, ez)
		if not columns.has(column_key):
			continue
		var layers: Array = columns[column_key]
		var chosen: int = layers[0]
		var chosen_gap := absi(chosen * 512 + 256 - y)
		for height in layers:
			var gap := absi(int(height) * 512 + 256 - y)
			if gap < chosen_gap:
				chosen = height
				chosen_gap = gap
		var stepped := Vector3i(ex, chosen, ez)
		if path.is_empty() or path[path.size() - 1] != stepped:
			path.append(stepped)
	if path.size() > 1 and path[path.size() - 1] == path[0]:
		path.remove_at(path.size() - 1)
	var on_road := {}
	for stepped in path:
		on_road[stepped] = true
	for part in parts:
		var layer := divi(int(part.y) + 1, scale)
		if on_road.has(Vector3i(part.x, layer, part.z)):
			part.lap = 1
	var road: Array = []
	for stepped in path:
		road.append({"x": stepped.x, "y": stepped.y * scale - 1, "z": stepped.z})
	return [parts, road, line]


func floordiv(a: int, b: int) -> int:
	var q := int(float(a) / float(b))
	if a < 0 and q * b != a:
		q -= 1
	return q


func assign_groups(colors: Array, tile_rows: Array) -> Array:
	var labs: Array = []
	for color in colors:
		labs.append(oklab(color[0], color[1], color[2]))
	var groups := cluster_colors(labs)
	absorb_small(groups, labs, 4, 0.10)
	groups.sort_custom(func(a, b): return group_before(a, b, labs))
	var names: Array = []
	var used := {}
	for group_index in groups.size():
		var members: Array = groups[group_index]
		var mean := mean_rgb(members, colors)
		var base := color_name(mean[0], mean[1], mean[2])
		used[base] = int(used.get(base, 0)) + 1
		if int(used[base]) == 1:
			names.append(base)
		else:
			names.append("%s %d" % [base, int(used[base])])
		for index in members:
			tile_rows[index]["color"] = colors[index]
			tile_rows[index]["group"] = group_index
	return names


func group_before(a: Array, b: Array, labs: Array) -> bool:
	var left: Array = group_sort_key(lab_centroid(a, labs))
	var right: Array = group_sort_key(lab_centroid(b, labs))
	if left[0] != right[0]:
		return left[0] < right[0]
	if left[1] != right[1]:
		return left[1] < right[1]
	return left[2] < right[2]


func mean_rgb(members: Array, colors: Array) -> Array:
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	for index in members:
		var color: Array = colors[index]
		red += color[0]
		green += color[1]
		blue += color[2]
	var count := float(members.size())
	return [red / count, green / count, blue / count]


func lab_centroid(members: Array, labs: Array) -> Array:
	var lightness := 0.0
	var a := 0.0
	var b := 0.0
	for index in members:
		var lab: Array = labs[index]
		lightness += lab[0]
		a += lab[1]
		b += lab[2]
	var count := float(members.size())
	return [lightness / count, a / count, b / count]


func absorb_small(groups: Array, labs: Array, minimum: int, limit: float) -> void:
	while groups.size() > 1:
		groups.sort_custom(func(a, b): return a.size() < b.size())
		var merged := false
		var index := 0
		while index < groups.size():
			var small: Array = groups[index]
			if small.size() >= minimum:
				return
			var origin: Array = lab_centroid(small, labs)
			var nearest := -1
			var nearest_distance := limit
			for other_index in groups.size():
				if other_index == index:
					continue
				var apart := lab_distance(origin, lab_centroid(groups[other_index], labs))
				if apart < nearest_distance:
					nearest = other_index
					nearest_distance = apart
			if nearest == -1:
				index += 1
				continue
			groups[nearest].append_array(small)
			groups.remove_at(index)
			merged = true
			break
		if not merged:
			return


func cluster_colors(labs: Array) -> Array:
	var count := labs.size()
	var parent: Array = []
	var size: Array = []
	parent.resize(count)
	size.resize(count)
	var distm: Array = []
	distm.resize(count)
	for i in count:
		parent[i] = i
		size[i] = 1
		var row: Array = []
		row.resize(count)
		row.fill(0.0)
		distm[i] = row
	for i in count:
		for j in range(i + 1, count):
			var apart := lab_distance(labs[i], labs[j])
			distm[i][j] = apart
			distm[j][i] = apart
	while true:
		var roots: Array = []
		for i in count:
			if parent[i] == i:
				roots.append(i)
		var best := GROUP_DISTANCE
		var pair := Vector2i(-1, -1)
		for ai in roots.size():
			var i: int = roots[ai]
			var row: Array = distm[i]
			for aj in range(ai + 1, roots.size()):
				var j: int = roots[aj]
				var apart: float = row[j]
				if apart < best:
					best = apart
					pair = Vector2i(i, j)
		if pair.x == -1:
			break
		var keep: int = pair.x
		var drop: int = pair.y
		var left: int = size[keep]
		var right: int = size[drop]
		for root in roots:
			var k: int = root
			if k == keep or k == drop:
				continue
			var merged: float = (distm[keep][k] * left + distm[drop][k] * right) / float(left + right)
			distm[keep][k] = merged
			distm[k][keep] = merged
		size[keep] = left + right
		parent[drop] = keep
	var grouped := {}
	for i in count:
		var root := i
		while parent[root] != root:
			root = parent[root]
		if not grouped.has(root):
			grouped[root] = []
		grouped[root].append(i)
	var result: Array = []
	for root in grouped:
		result.append(grouped[root])
	return result


func color_name(red: float, green: float, blue: float) -> String:
	var peak := maxf(red, maxf(green, maxf(blue, 1.0)))
	if peak < 180.0:
		var scale := 180.0 / peak
		red *= scale
		green *= scale
		blue *= scale
	var lab: Array = oklab(red, green, blue)
	var chroma := sqrt(lab[1] * lab[1] + lab[2] * lab[2])
	if chroma < 0.045:
		if lab[0] < 0.35:
			return "Dark"
		if lab[0] > 0.7:
			return "Light"
		return "Gray"
	var hue := fmod(rad_to_deg(atan2(lab[2], lab[1])) + 360.0, 360.0)
	var name := "Red"
	for edge in [[18, "Red"], [42, "Orange"], [70, "Yellow"], [155, "Green"], [195, "Teal"], [255, "Blue"], [295, "Purple"], [340, "Pink"], [360, "Red"]]:
		if hue < float(edge[0]):
			name = edge[1]
			break
	if lab[0] < 0.4:
		return "Dark " + name
	if lab[0] > 0.75:
		return "Light " + name
	return name


func group_sort_key(lab: Array) -> Array:
	var chroma := sqrt(lab[1] * lab[1] + lab[2] * lab[2])
	if chroma < 0.04:
		return [0, 0.0, -lab[0]]
	var hue := fmod(rad_to_deg(atan2(lab[2], lab[1])) + 360.0, 360.0)
	return [1, hue, -lab[0]]


func lab_distance(left: Array, right: Array) -> float:
	var dl: float = left[0] - right[0]
	var da: float = left[1] - right[1]
	var db: float = left[2] - right[2]
	return sqrt(dl * dl + da * da + db * db)


func oklab(red: float, green: float, blue: float) -> Array:
	var r := linear_channel(red)
	var g := linear_channel(green)
	var b := linear_channel(blue)
	var l := 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	var m := 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	var s := 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
	l = pow(l, 1.0 / 3.0)
	m = pow(m, 1.0 / 3.0)
	s = pow(s, 1.0 / 3.0)
	return [
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
	]


func linear_channel(channel: float) -> float:
	var value := channel / 255.0
	if value <= 0.04045:
		return value / 12.92
	return pow((value + 0.055) / 1.055, 2.4)


func read_file(path: String) -> PackedByteArray:
	if file_cache.has(path):
		return file_cache[path]
	if not FileAccess.file_exists(path):
		fail("Missing file: " + path)
		return PackedByteArray()
	var data := FileAccess.get_file_as_bytes(path)
	file_cache[path] = data
	file_stamp[path] = file_stamp.size()
	return data


func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func write_json(path: String, value: Variant) -> void:
	var text := JSON.stringify(value)
	if text == "":
		fail("Could not encode " + path)
		return
	write_text(path, text)


func write_text(path: String, text: String) -> void:
	ensure_dir(path.get_base_dir())
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		fail("Could not write " + path)
		return
	handle.store_string(text)
	handle.close()


func write_bytes(path: String, data: PackedByteArray) -> void:
	ensure_dir(path.get_base_dir())
	var handle := FileAccess.open(path, FileAccess.WRITE)
	if handle == null:
		fail("Could not write " + path)
		return
	handle.store_buffer(data)
	handle.close()


func save_rgba(path: String, width: int, height: int, rgba: PackedByteArray) -> void:
	var image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
	ensure_dir(path.get_base_dir())
	if image.save_png(path) != OK:
		fail("Could not write " + path)


func write_wav(path: String, pcm: PackedByteArray, channels: int, rate: int) -> void:
	var header := StreamPeerBuffer.new()
	header.big_endian = false
	var block := channels * 2
	var data_size := pcm.size()
	header.put_data("RIFF".to_ascii_buffer())
	header.put_32(36 + data_size)
	header.put_data("WAVE".to_ascii_buffer())
	header.put_data("fmt ".to_ascii_buffer())
	header.put_32(16)
	header.put_16(1)
	header.put_16(channels)
	header.put_32(rate)
	header.put_32(rate * block)
	header.put_16(block)
	header.put_16(16)
	header.put_data("data".to_ascii_buffer())
	header.put_32(data_size)
	var bytes := header.data_array.slice(0, header.get_size())
	bytes.append_array(pcm)
	write_bytes(path, bytes)


func ensure_dir(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path)


func make_temp(prefix: String) -> String:
	var path := OS.get_cache_dir().path_join("%s-%d" % [prefix, Time.get_ticks_usec()])
	ensure_dir(path)
	temps.append(path)
	return path


func remove_tree(path: String) -> void:
	if path == "" or not DirAccess.dir_exists_absolute(path):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	var names: Array[String] = []
	dir.list_dir_begin()
	var entry_name := dir.get_next()
	while entry_name != "":
		names.append(entry_name)
		entry_name = dir.get_next()
	dir.list_dir_end()
	for child_name in names:
		var sub := path.path_join(child_name)
		if DirAccess.dir_exists_absolute(sub):
			remove_tree(sub)
		else:
			DirAccess.remove_absolute(sub)
	DirAccess.remove_absolute(path)


class BinWriter:
	var peer := StreamPeerBuffer.new()

	func _init() -> void:
		peer.big_endian = false

	func i32(v: int) -> void:
		peer.put_32(v)

	func f32(v: float) -> void:
		peer.put_float(v)

	func u8(v: int) -> void:
		peer.put_u8(v)

	func raw(data: PackedByteArray) -> void:
		peer.put_data(data)

	func vertex(pos: Array, normal: Array, color: Array, uv: Array) -> void:
		f32(pos[0])
		f32(pos[1])
		f32(pos[2])
		f32(normal[0])
		f32(normal[1])
		f32(normal[2])
		f32(color[0])
		f32(color[1])
		f32(color[2])
		f32(color[3])
		f32(uv[0])
		f32(uv[1])

	func bytes() -> PackedByteArray:
		return peer.data_array.slice(0, peer.get_size())
