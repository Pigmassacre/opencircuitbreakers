extends SceneTree
# Runs CarSim one frame from every car record of a tape from record.py and
# compares the result with the next record. Every field should match on every
# frame. A frame where only the position differs is the track script moving
# the car between the two records.
#   godot --headless --path Project -s ../Tools/compare/simtest.gd -- <blocks.bin> <tape.json> [frames to print]

var record: PackedByteArray


func word(offset: int) -> int:
	return record.decode_s32(offset)


func short(offset: int) -> int:
	return record.decode_s16(offset)


func load_state(sim: CarSim) -> void:
	sim.pos = Vector3i(word(0x14), word(0x18), word(0x1c))
	sim.vel = Vector3i(word(0x84), word(0x88), word(0x8c))
	sim.heading = short(0x9e)
	sim.travel = short(0xa8)
	sim.tilt_x = short(0x4c)
	sim.tilt_y = short(0x4e)
	sim.fall = short(0x50)
	sim.normal = Vector3i(short(0x60), short(0x5c), short(0x5e))
	sim.shove = Vector2i(word(0x64), word(0x68))
	sim.grounded = word(0x74)
	sim.air = word(0x7c)
	sim.slope_drift = word(0x80)
	sim.slope_turn = short(0xa4)
	sim.speed = word(0x94)
	sim.level_speed = word(0x98)
	sim.wall = word(0xc)
	sim.ramp = short(0x190)
	sim.boost = short(0x18c)
	sim.surface = short(0x17e)
	sim.last_ground = word(0x10c)
	sim.steer_left = short(0x180)
	sim.steer_right = short(0x182)
	sim.unsteered = word(0x188)
	sim.spin = word(0x16c)
	sim.drag = word(0xac)
	sim.grip = word(0xb0)
	sim.base_grip = word(0x164)
	sim.engine = word(0xb4)
	sim.brake_force = word(0xb8)
	sim.turn_rate = word(0xc0)
	sim.held = word(0x19c) != 0


func simulated(sim: CarSim) -> Dictionary:
	return {"pos": sim.pos, "vel": sim.vel, "heading": sim.heading & 0xfff, "travel": sim.travel & 0xfff, "tilt_x": Fixed.short(sim.tilt_x), "tilt_y": Fixed.short(sim.tilt_y), "fall": Fixed.short(sim.fall), "normal": sim.normal, "shove": sim.shove, "grounded": sim.grounded, "air": sim.air, "wall": sim.wall, "ramp": sim.ramp, "surface": sim.surface, "last_ground": sim.last_ground, "speed": sim.speed, "slope_turn": sim.slope_turn}


func recorded() -> Dictionary:
	return {"pos": Vector3i(word(0x14), word(0x18), word(0x1c)), "vel": Vector3i(word(0x84), word(0x88), word(0x8c)), "heading": short(0x9e) & 0xfff, "travel": short(0xa8) & 0xfff, "tilt_x": short(0x4c), "tilt_y": short(0x4e), "fall": short(0x50), "normal": Vector3i(short(0x60), short(0x5c), short(0x5e)), "shove": Vector2i(word(0x64), word(0x68)), "grounded": word(0x74), "air": word(0x7c), "wall": word(0xc), "ramp": short(0x190), "surface": short(0x17e), "last_ground": word(0x10c), "speed": word(0x94), "slope_turn": short(0xa4)}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var sim := CarSim.new()
	sim.blocks = CollisionBlocks.read(FileAccess.get_file_as_bytes(args[0]))
	sim.guarded = true
	var frames: Array = JSON.parse_string(FileAccess.get_file_as_string(args[1])).frames
	var limit := int(args[2]) if args.size() > 2 else 10
	var tested := 0
	var wrong := 0
	var moved := 0
	for k in frames.size() - 1:
		record = (frames[k].r as String).hex_decode()
		if word(0) != 0 or word(8) != 0:
			continue
		load_state(sim)
		var before := simulated(sim)
		var pad := int(frames[k].w)
		sim.accel = 7 if pad & 0x30 else 0
		sim.brake = 7 if pad & 0xc0 else 0
		sim.steer = 7 if pad & 0x800 else (-7 if pad & 0x400 else 0)
		record = (frames[k + 1].r as String).hex_decode()
		if word(0) != 0 or word(8) != 0:
			continue
		sim.count_unsteered()
		sim.frame()
		var got := simulated(sim)
		var want := recorded()
		tested += 1
		var differing := []
		for key in want:
			if got[key] != want[key]:
				differing.append(key)
		if differing == ["pos"]:
			moved += 1
		elif differing.size() > 0:
			wrong += 1
			if wrong <= limit:
				print("frame %d, pad %x" % [k, pad])
				for key in differing:
					print("    %-11s before %s  original %s  port %s" % [key, str(before[key]), str(want[key]), str(got[key])])
	print("%d frames: %d differ, %d more only in position" % [tested, wrong, moved])
	quit()
