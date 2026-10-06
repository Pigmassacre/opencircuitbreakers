extends Node

const PATH := "user://settings.cfg"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"

enum Mode { WINDOWED, BORDERLESS, FULLSCREEN }
enum Fog { FAR, ORIGINAL }
enum Filter { OFF, BILINEAR }

const CRT_CURVE_MAX := 0.15
const DEVICE_ID_INTERNAL := -2

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1280, 800),
	Vector2i(1366, 768),
	Vector2i(1440, 900),
	Vector2i(1600, 900),
	Vector2i(1680, 1050),
	Vector2i(1920, 1080),
	Vector2i(1920, 1200),
	Vector2i(2560, 1440),
	Vector2i(2560, 1600),
	Vector2i(3840, 2160),
]

const ASPECTS: Array[Vector2i] = [
	Vector2i(16, 9),
	Vector2i(16, 10),
	Vector2i(4, 3),
	Vector2i(5, 4),
	Vector2i(3, 2),
	Vector2i(5, 3),
	Vector2i(21, 9),
	Vector2i(32, 9),
]

const CRT_SHADER := "shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float curve = 0.0;
void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 bent = SCREEN_UV * 2.0 - 1.0;
	bent *= 1.0 + curve * bent.yx * bent.yx;
	vec2 uv = bent * 0.5 + 0.5;
	vec2 pixel = uv * res;
	float pitch = max(3.0, round(res.y / 360.0));
	vec2 centered = uv - 0.5;
	float shift = SCREEN_PIXEL_SIZE.x * (1.0 + 3.0 * dot(centered, centered));
	vec3 color = vec3(texture(screen, uv + vec2(shift, 0.0)).r, texture(screen, uv).g, texture(screen, uv - vec2(shift, 0.0)).b);
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float scan = 0.5 + 0.5 * cos(pixel.y * TAU / pitch);
	color *= 1.0 - mix(0.4, 0.12, luma) * (1.0 - scan);
	vec3 mask = vec3(0.82);
	mask[int(mod(floor(FRAGCOORD.x * 3.0 / pitch), 3.0))] = 1.0;
	color *= mask * 1.18;
	vec2 edge = uv * (1.0 - uv);
	color *= pow(max(edge.x * edge.y * 16.0, 0.0), 0.12);
	vec2 inside = min(uv, 1.0 - uv) * res;
	color *= clamp(min(inside.x, inside.y), 0.0, 1.0);
	COLOR = vec4(color, 1.0);
}
"

var master := 100
var music := 100
var sfx := 100
var window_mode := Mode.WINDOWED
var resolution := Vector2i(1920, 1080)
var fog := Fog.FAR
var texture_filter := Filter.OFF
var crt := false
var crt_curve := 0
var crt_rect: ColorRect
var best_times := {}
var best_places := {}
var best_fields := {}
var trial_times := {}
var ghosts := {}
var ghost_models := {}

signal window_mode_changed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bind_menu_pad()
	add_bus(BUS_MUSIC)
	add_bus(BUS_SFX)
	build_crt()
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		master = clampi(int(config.get_value("audio", "master", master)), 0, 100)
		music = clampi(int(config.get_value("audio", "music", music)), 0, 100)
		sfx = clampi(int(config.get_value("audio", "sfx", sfx)), 0, 100)
		window_mode = clampi(int(config.get_value("display", "window", window_mode)), 0, Mode.FULLSCREEN)
		fog = clampi(int(config.get_value("display", "fog", fog)), 0, Fog.ORIGINAL)
		texture_filter = clampi(int(config.get_value("display", "texture_filter", texture_filter)), 0, Filter.BILINEAR)
		crt = bool(config.get_value("display", "crt", crt))
		crt_curve = clampi(int(config.get_value("display", "crt_curve", crt_curve)), 0, 100)
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
		if config.has_section("places"):
			for key in config.get_section_keys("places"):
				best_places[String(key)] = int(config.get_value("places", key))
		if config.has_section("place_fields"):
			for key in config.get_section_keys("place_fields"):
				best_fields[String(key)] = int(config.get_value("place_fields", key))
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
	apply_crt()
	get_window().window_input.connect(warp_mouse_event)


func build_crt() -> void:
	var layer := CanvasLayer.new()
	# Embedded popups like dropdowns draw on Viewport.SUBWINDOW_CANVAS_LAYER (1024).
	layer.layer = 1025
	add_child(layer)
	var shader := Shader.new()
	shader.code = CRT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	crt_rect = ColorRect.new()
	crt_rect.material = material
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(crt_rect)


func apply_crt() -> void:
	crt_rect.visible = crt
	(crt_rect.material as ShaderMaterial).set_shader_parameter("curve", curve_amount())


func curve_amount() -> float:
	return crt_curve / 100.0 * CRT_CURVE_MAX


# Maps a point on the curved picture to where it was drawn before the filter bent it.
func crt_warp(pos: Vector2, size: Vector2) -> Vector2:
	if not crt:
		return pos
	var bent := pos / size * 2.0 - Vector2.ONE
	bent *= Vector2.ONE + curve_amount() * Vector2(bent.y * bent.y, bent.x * bent.x)
	return (bent + Vector2.ONE) * 0.5 * size


func mouse_position() -> Vector2:
	return crt_warp(get_viewport().get_mouse_position(), get_viewport().get_visible_rect().size)


func warp_mouse_event(event: InputEvent) -> void:
	if event is InputEventMouse:
		var mouse := event as InputEventMouse
		var size := Vector2(get_window().size)
		mouse.position = crt_warp(mouse.position, size)
		mouse.global_position = crt_warp(mouse.global_position, size)


# Engine-generated hover events skip window_input, so they are warped here before the GUI sees them.
func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == DEVICE_ID_INTERNAL:
		warp_mouse_event(event)
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


func set_fog(mode: int) -> void:
	fog = mode
	save()


func set_texture_filter(mode: int) -> void:
	texture_filter = mode
	for node in get_tree().get_nodes_in_group(Track.TEXTURED):
		for material: BaseMaterial3D in node.textured:
			material.texture_filter = material_filter()
	save()


func material_filter() -> BaseMaterial3D.TextureFilter:
	return BaseMaterial3D.TEXTURE_FILTER_LINEAR if texture_filter == Filter.BILINEAR else BaseMaterial3D.TEXTURE_FILTER_NEAREST


func set_crt(on: bool) -> void:
	crt = on
	apply_crt()
	save()


func set_crt_curve(value: int) -> void:
	crt_curve = value
	apply_crt()
	save()


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
		list.append(size)
	if screen.x > 0 and list.find(screen) == -1:
		list.append(screen)
	if list.find(resolution) == -1:
		list.append(resolution)
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return list


static func aspect_name(size: Vector2i) -> String:
	var ratio := float(size.x) / float(size.y)
	var best := Vector2i.ZERO
	var error := 0.02
	for aspect in ASPECTS:
		var next := absf(ratio - float(aspect.x) / float(aspect.y))
		if next < error:
			error = next
			best = aspect
	if best.x > 0:
		return "%d:%d" % [best.x, best.y]
	var a := size.x
	var b := size.y
	while b != 0:
		var next := a % b
		a = b
		b = next
	return "%d:%d" % [size.x / a, size.y / a]


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
	get_window().size = resolution
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


func best_place(scene: String) -> int:
	if not best_places.has(scene):
		return -1
	return int(best_places[scene])


func best_field(scene: String) -> int:
	return int(best_fields[scene])


func record_place(scene: String, place: int, field: int) -> bool:
	var previous := best_place(scene)
	if previous >= 1 and place >= previous:
		return false
	best_places[scene] = place
	best_fields[scene] = field
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
	config.set_value("display", "fog", fog)
	config.set_value("display", "texture_filter", texture_filter)
	config.set_value("display", "crt", crt)
	config.set_value("display", "crt_curve", crt_curve)
	for scene in best_times:
		config.set_value("times", scene, best_times[scene])
	for scene in best_places:
		config.set_value("places", scene, best_places[scene])
	for scene in best_fields:
		config.set_value("place_fields", scene, best_fields[scene])
	for dir in trial_times:
		config.set_value("trials", dir, trial_times[dir])
	for dir in ghosts:
		config.set_value("ghosts", dir, ghosts[dir])
	for dir in ghost_models:
		config.set_value("ghost_models", dir, ghost_models[dir])
	config.save(PATH)
