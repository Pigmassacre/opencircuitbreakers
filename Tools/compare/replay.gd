extends SceneTree
# Plays a tape from record.py through a time trial of the port and saves the
# car's state at the start of every game frame, for compare.py.
#   godot --headless --fixed-fps 30 --path Project -s ../Tools/compare/replay.gd -- <track folder> <tape.json> <out.json>

const UNIT := 2.4 / 158.0
var tape: Dictionary
var out_path := ""
var car
var frame := -1
var settled := 0
var rows := []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	tape = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	out_path = args[2]
	var session = load("res://scripts/session.gd")
	session.time_trial = true
	session.trial_models = PackedInt32Array([0])
	session.trial_controls = PackedStringArray([""])
	session.ghost_model = -1
	session.queued_dir = "res://tracks/" + args[0]
	change_scene_to_file(session.SCENE)


func state() -> Dictionary:
	var at: Vector3 = car.global_position / UNIT
	return {"p": [at.x, at.z, at.y], "v": [car.vel.x, car.vel.z, car.vel.y], "h": -car.heading & 0xfff, "g": int(car.grounded), "spd": car.speed, "wall": car.wall_frames, "wreck": car.wreck_count()}


func press(action: String, on: int) -> void:
	if on != 0:
		Input.action_press(action, 1.0)
	else:
		Input.action_release(action)


func _physics_process(_delta: float) -> bool:
	if current_scene == null or not current_scene.get("armed"):
		return false
	if car == null:
		car = current_scene.player
		return false
	if Engine.get_physics_frames() % 4 != 0:
		return false
	if frame < 0:
		if car.staged or current_scene.race.countdown != 0:
			return false
		settled += 1
		if settled < 4:
			return false
		var start: Array = tape.start
		car.teleport(Transform3D(Basis(Vector3.UP, -start[3] * TAU / 4096.0), Vector3(start[0], start[2], start[1]) * UNIT), 0)
		frame = 0
	rows.append(state())
	if frame >= tape.frames.size():
		rows.pop_back()
		FileAccess.open(out_path, FileAccess.WRITE).store_string(JSON.stringify(rows))
		quit()
		return true
	var pad := int(tape.frames[frame].w)
	press("accelerate", pad & 0x30)
	press("brake", pad & 0xc0)
	press("steer_right", pad & 0x800)
	press("steer_left", pad & 0x400)
	frame += 1
	return false
