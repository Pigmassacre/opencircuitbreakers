extends Node

const PATH := "user://settings.cfg"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var master := 100
var music := 100
var sfx := 100
var window_mode := Mode.WINDOWED
var resolution := Vector2i(1920, 1080)
var best_times := {}
var trial_times := {}
var ghosts := {}
var ghost_models := {}

signal window_mode_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bind_menu_pad()
	add_bus(BUS_MUSIC)
	add_bus(BUS_SFX)
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		master = clampi(int(config.get_value("audio", "master", master)), 0, 100)
		music = clampi(int(config.get_value("audio", "music", music)), 0, 100)
		sfx = clampi(int(config.get_value("audio", "sfx", sfx)), 0, 100)
		window_mode = clampi(int(config.get_value("display", "window", window_mode)), 0, Mode.FULLSCREEN)
		if config.has_section_key("display", "width") and config.has_section_key("display", "height"):
			var width := int(config.get_value("display", "width"))
			var height := int(config.get_value("display", "height"))
			if width > 0 and height > 0:
				resolution = Vector2i(width, height)
			else:
				resolution = fitted_default()
		else:
			resolution = fitted_default()
		if config.has_section("times"):
			for key in config.get_section_keys("times"):
				var scene := String(key)
				var dir := scene
				if scene.begins_with("res://scenes/") and scene.ends_with(".tscn") and scene != Session.SCENE:
					dir = Session.directory_for_scene(scene)
				var seconds := float(config.get_value("times", key))
				if not best_times.has(dir) or seconds < float(best_times[dir]):
					best_times[dir] = seconds
		if config.has_section("trials"):
			for key in config.get_section_keys("trials"):
				trial_times[String(key)] = float(config.get_value("trials", key))
		if config.has_section("ghosts"):
			for key in config.get_section_keys("ghosts"):
				ghosts[String(key)] = config.get_value("ghosts", key)
		if config.has_section("ghost_models"):
			for key in config.get_section_keys("ghost_models"):
				ghost_models[String(key)] = int(config.get_value("ghost_models", key))
	else:
		resolution = fitted_default()
	apply_volumes()
	apply_window()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.alt_pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var current := DisplayServer.window_get_mode()
	var fullscreen := current == DisplayServer.WINDOW_MODE_FULLSCREEN or current == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	set_window_mode(Mode.WINDOWED if fullscreen else Mode.FULLSCREEN)


func set_master(value: int) -> void:
	master = value
	apply_volumes()
	save()


func set_music(value: int) -> void:
	music = value
	apply_volumes()
	save()


func set_sfx(value: int) -> void:
	sfx = value
	apply_volumes()
	save()


func set_window_mode(mode: int) -> void:
	window_mode = mode
	apply_window()
	save()
	window_mode_changed.emit()


func set_resolution(size: Vector2i) -> void:
	resolution = size
	apply_window()
	save()


func fitted_default() -> Vector2i:
	var screen := DisplayServer.screen_get_size()
	var want := Vector2i(1920, 1080)
	if screen.x < 1 or (want.x <= screen.x and want.y <= screen.y):
		return want
	var best := Vector2i.ZERO
	for size in RESOLUTIONS:
		if size.x <= screen.x and size.y <= screen.y and size.x >= best.x:
			best = size
	if best.x < 1:
		return screen
	return best


func resolutions() -> Array[Vector2i]:
	var screen := DisplayServer.screen_get_size()
	var list: Array[Vector2i] = []
	for size in RESOLUTIONS:
		if screen.x < 1 or (size.x <= screen.x and size.y <= screen.y):
			list.append(size)
	if screen.x > 0 and list.find(screen) == -1:
		list.append(screen)
	if list.find(resolution) == -1:
		list.append(resolution)
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return list


func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), bus_db(master))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_MUSIC), bus_db(music))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_SFX), bus_db(sfx))


# WINDOW_MODE_FULLSCREEN is the borderless mode. Exclusive fullscreen is separate.
func apply_window() -> void:
	var mode := DisplayServer.WINDOW_MODE_WINDOWED
	if window_mode == Mode.BORDERLESS:
		mode = DisplayServer.WINDOW_MODE_FULLSCREEN
	elif window_mode == Mode.FULLSCREEN:
		mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	DisplayServer.window_set_size(resolution)
	DisplayServer.window_set_mode(mode)
	if window_mode == Mode.WINDOWED:
		var screen_pos := DisplayServer.screen_get_position()
		var screen_size := DisplayServer.screen_get_size()
		DisplayServer.window_set_position(screen_pos + (screen_size - resolution) / 2)


func bus_db(value: int) -> float:
	return linear_to_db(value / 100.0)


func bind_menu_pad() -> void:
	bind_joy("ui_accept", JOY_BUTTON_A)
	bind_joy("ui_cancel", JOY_BUTTON_B)


func bind_joy(action: StringName, button: JoyButton) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton:
			var joy := event as InputEventJoypadButton
			if joy.button_index == button and joy.device < 0:
				return
	var joy := InputEventJoypadButton.new()
	joy.button_index = button
	joy.device = -1
	InputMap.action_add_event(action, joy)


func add_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func best_time(scene: String) -> float:
	if not best_times.has(scene):
		return -1.0
	return float(best_times[scene])


func record_best(scene: String, seconds: float) -> bool:
	var previous := best_time(scene)
	if previous >= 0.0 and seconds >= previous:
		return false
	best_times[scene] = seconds
	save()
	return true


func trial_time(dir: String) -> float:
	if not trial_times.has(dir):
		return -1.0
	return float(trial_times[dir])


func ghost_tape(dir: String) -> PackedByteArray:
	if not ghosts.has(dir):
		return PackedByteArray()
	return ghosts[dir]


func ghost_model(dir: String) -> int:
	var tape := ghost_tape(dir)
	if tape.is_empty() or not ghost_models.has(dir):
		return -1
	return int(ghost_models[dir])


# FUN_00025e88 keeps the run when it beats the stored time and the input tape
# has not filled the 0x1d4c-frame buffer.
func take_trial(dir: String, seconds: float, model: int, tape: PackedByteArray) -> bool:
	record_best(dir, seconds)
	var previous := trial_time(dir)
	if previous >= 0.0 and seconds >= previous:
		return false
	trial_times[dir] = seconds
	ghosts[dir] = tape.duplicate()
	ghost_models[dir] = model
	save()
	return true


func save() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master", master)
	config.set_value("audio", "music", music)
	config.set_value("audio", "sfx", sfx)
	config.set_value("display", "window", window_mode)
	config.set_value("display", "width", resolution.x)
	config.set_value("display", "height", resolution.y)
	for scene in best_times:
		config.set_value("times", scene, best_times[scene])
	for dir in trial_times:
		config.set_value("trials", dir, trial_times[dir])
	for dir in ghosts:
		config.set_value("ghosts", dir, ghosts[dir])
	for dir in ghost_models:
		config.set_value("ghost_models", dir, ghost_models[dir])
	config.save(PATH)
