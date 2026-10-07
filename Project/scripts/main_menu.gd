class_name MainMenu
extends Control

const SCENE := "res://scenes/main_menu.tscn"
const PREVIEWS := "res://tracks/previews.json"
const RACES := "res://tracks/races.json"
const ADDON := "res://tracks/addon.json"
const BUTTON_WIDTH := 420.0
const CREDITS_W := 860.0
const CREDITS_SCROLL := 900.0
const CREDITS_MARGIN := 32.0
const CREDITS := [
	{"title": "Created by", "names": ["Olof Karlsson"], "text": "", "prompt": "", "link": ""},
	{"title": "Written by AI", "names": [], "text": "Most of the code in this port was written by AI coding agents, steered and play-tested by a human. If something behaves oddly, that is probably why.", "prompt": "Please report any bugs you find at:", "link": "github.com/Pigmassacre/opencircuitbreakers"},
	{"title": "The original game", "names": ["Supersonic Software"], "text": "Circuit Breakers was developed by Supersonic Software and published by Mindscape for the PlayStation in 1998. The tracks, cars, art, music and sound are all their work. This port would not exist without it.", "prompt": "", "link": ""},
	{"title": "No copyrighted data", "names": [], "text": "OpenCircuitBreakers contains none of the original game's data. Tracks, cars, textures, music and sound are read from your own copy of the game during setup.", "prompt": "", "link": ""},
	{"title": "Extra art", "names": ["Kenney"], "text": "City Kit, Racing Kit and Game Icons (CC0)", "prompt": "", "link": "kenney.nl"},
	{"title": "Built with", "names": ["Godot Engine"], "text": "", "prompt": "", "link": "godotengine.org"},
]
const CAR_VIEW := 20.0
const ARROW_W := 42.0
const ARROW_H := 34.0
const HEADER_H := 96.0
const STAGE_GAP := 48.0
const STAGE_MAX_H := 700.0
const CAR_BAND := 0.75
const STAGE_FOOT := 124.0
const FLAG_SHADER := "shader_type canvas_item;
uniform vec2 flag_size;
uniform vec4 dark_color : source_color = vec4(0.16, 0.03, 0.09, 0.96);
uniform vec4 lite_color : source_color = vec4(0.34, 0.07, 0.18, 0.96);
uniform float cell = 32.0;
void fragment() {
	float t = TIME;
	vec2 px = UV * flag_size;
	px.x += t * 4.0;
	float wave = sin(px.x * 0.016 - t * 0.45);
	float wave2 = sin(px.x * 0.032 + px.y * 0.02 - t * 0.8);
	px.y += wave * 12.0 + wave2 * 5.0;
	px.x += sin(px.y * 0.028 + t * 0.5) * 7.0;
	float cx = floor(px.x / cell);
	float cy = floor(px.y / cell);
	vec4 color = mix(dark_color, lite_color, mod(cx + cy, 2.0));
	color.rgb *= 0.9 + 0.1 * (wave * 0.5 + 0.5);
	float hem = smoothstep(0.965, 0.995, UV.y);
	color.rgb = mix(color.rgb, vec3(1.0), hem * 0.9);
	COLOR = color;
}
"
const PAGE_MAIN := 0
const PAGE_MULTIPLAYER := 1
const PAGE_TRACK := 2
const PAGE_CAR := 3
const PAGE_ONLINE := 4
const PAGE_BATTLE_TRACK := 5
const PAGE_ONLINE_TRACK := 6
const WORLDS: Array = Session.WORLDS
const PICKUP_NAMES := ["Off", "Normal", "Plenty"]
const CAR_NAMES := ["Wild West", "Grand Prix", "Venice", "Swamp", "Jungle", "Persia", "Aqua", "Snow"]
const PLAYER_KEYS := ["WASD", "Arrows", "", ""]
const PAD_REPEAT := 0.22

static var start_page := PAGE_MAIN
static var battle_players := 2
static var battle_track := 0
static var race_track := 0
static var race_model := 0

var main_page: VBoxContainer
var options_page: VBoxContainer
var credits_page: VBoxContainer
var credits_scroll: ScrollContainer
var options_focus: Control
var options_frame: PanelContainer
var options_scroll: ScrollContainer
var page: VBoxContainer
var multiplayer_page: VBoxContainer
var online_page: VBoxContainer
var online_connect: VBoxContainer
var online_lobby: VBoxContainer
var online_status: Label
var online_list: Label
var online_host_line: Label
var online_wait: Label
var online_tracks: Button
var online_settings: HBoxContainer
var online_preview: Car
var online_car_label: Label
var online_expert: CheckBox
var online_address: LineEdit
var online_port: SpinBox
var online_shown := -1
var online_pad_hold := 0.0
var track_page: VBoxContainer
var mode_page: VBoxContainer
var mode_best: Label
var mode_world: Button
var mode_trial: Button
var mode_battle: Button
var mode_bumper: Button
var track_start: Button
var track_label: Label
var track_group: Label
var track_best: Label
var track_world: TextureRect
var track_weather: TextureRect
var track_pad_hold := 0.0
var track_groups: Array[int] = []
var world_icons: Array[Texture2D] = []
var weather_icons: Array[Texture2D] = []
var preview_weather: Array = []
var track_for_battle := false
var track_for_online := false
var track_paths: Array[String] = []
var track_names: Array[String] = []
var track_tab := 0
var listed_pick: Array[int] = [0, 0]
var track_list: VBoxContainer
var track_scroll: ScrollContainer
var track_tab_courses: Button
var track_tab_custom: Button
var track_reveal := false
var track_pivot: Node3D
var track_camera: Camera3D
var track_environment: Environment
var track_ribbon: MeshInstance3D
var preview_colors: Array = []
var preview_tracks: Array = []
var ribbon_slot := -1
var ribbon_track: Dictionary = {}
var ribbon_tint: Array = []
var ribbon_reverse := false
var track_tab_off: StyleBoxFlat
var track_tab_on: StyleBoxFlat
var track_tab_hover: StyleBoxFlat
var ribbon_time := 0.0
var ribbon_shown := -1
var track_wins: HBoxContainer
var cards: Array[Control] = []
var card_titles: Array[Label] = []
var car_labels: Array[Label] = []
var pad_buttons: Array[Button] = []
var preview_boxes: Array[SubViewportContainer] = []
var win_labels: Array[Label] = []
var accent_bars: Array[ColorRect] = []
var card_headers: Array[Control] = []
var card_controls: Array[Control] = []
var left_arrows: Array[Button] = []
var right_arrows: Array[Button] = []
var player_stage: Control
var previews: Array[Car] = []
var assigning := -1
var pad_hold := [0.0, 0.0, 0.0, 0.0]
var car_page: VBoxContainer
var car_stage: Control
var car_header: Control
var car_kicker: Label
var car_name: Label
var car_accent: ColorRect
var car_box: SubViewportContainer
var car_left: Button
var car_right: Button
var car_preview: Car
var car_pad_hold := 0.0
var backdrop_cars: Array[Car] = []
var setup_disc: LineEdit
var setup_addon: LineEdit
var setup_status: Label
var setup_bar: ProgressBar
var setup_go: Button
var setup_file_buttons: Array[Button] = []
var setup_dialog: FileDialog
var setup_pick := ""
var setup_page: VBoxContainer
var setup_back: Button
var setup_return: VBoxContainer
var setup_job: ContentExport
var header_flag: MeshInstance2D
var header_chrome: Control
var header_settings: HBoxContainer
var quit_ask: Control
var quit_ask_yes: Button
var quit_ask_cancel: Button
var quit_return: Control


func _ready() -> void:
	Sound.silence_race()
	theme = UiTheme.theme()
	process_physics_priority = 1
	build_header()
	build_quit_ask()
	if not Data.present():
		open_setup(null)
		return
	if Wipe.covering:
		Wipe.boot = open_with_backdrop
		return
	build_game()


func open_with_backdrop() -> void:
	build_game(false)
	await load_backdrop()


func build_game(defer_backdrop := true) -> void:
	main_page = add_page(self, "OpenCircuitBreakers", 64)
	multiplayer_page = add_page(self, "Local Multiplayer", 48)
	online_page = add_page(self, "Online Multiplayer", 48)
	var multiplayer := multiplayer_page
	car_page = add_page(self, "Select Car", 48)
	options_page = add_page(self, "Options", 48)
	credits_page = add_page(self, "Credits", 48)

	var menu := page_stack(main_page)
	add_button(menu, "Singleplayer", show_page.bind(car_page), "singleplayer")
	add_button(menu, "Local Multiplayer", show_page.bind(multiplayer), "multiplayer")
	add_button(menu, "Online Multiplayer", show_page.bind(online_page), "massiveMultiplayer")
	add_button(menu, "Options", show_page.bind(options_page), "gear")
	add_button(menu, "Level Editor", func() -> void: Wipe.to("res://scenes/level_editor.tscn"), "wrench")
	var quit := add_nav(main_page, "Quit to Desktop", prompt_quit, false)
	quit.custom_minimum_size = Vector2(360, 72)
	apply_menu_icon(quit, "exitRight")
	var version := Label.new()
	version.text = "v" + String(ProjectSettings.get_setting("application/config/version"))
	version.size_flags_vertical = Control.SIZE_SHRINK_END
	version.add_theme_font_size_override("font_size", 20)
	version.add_theme_color_override("font_color", Color(UiTheme.TEXT_COLOR, 0.6))
	(main_page.get_meta("footer_right") as HBoxContainer).add_child(version)

	build_multiplayer(multiplayer)
	build_online(online_page)
	build_car(car_page)
	Net.changed.connect(refresh_online)
	track_page = add_page(self, "Select Track", 48)
	build_tracks(track_page)
	mode_page = add_page(self, "Select Game Type", 48)
	build_mode(mode_page)
	build_options(options_page)
	build_credits(credits_page)

	if start_page == PAGE_MULTIPLAYER:
		show_page(multiplayer)
	elif start_page == PAGE_ONLINE:
		show_page(online_page)
	elif start_page == PAGE_TRACK:
		open_tracks(false)
	elif start_page == PAGE_BATTLE_TRACK:
		open_tracks(true)
	elif start_page == PAGE_ONLINE_TRACK:
		open_tracks(true, true)
	else:
		show_page(main_page)
	start_page = PAGE_MAIN
	if defer_backdrop:
		build_backdrop.call_deferred()


func _exit_tree() -> void:
	if setup_job != null:
		setup_job.join()


func _process(delta: float) -> void:
	if setup_job != null:
		poll_setup()
		return
	if page == null:
		return
	if page == options_page:
		UiTheme.fit_scroll(options_scroll, options_frame, options_page.size.y - CREDITS_MARGIN * 2.0)
	if page == credits_page:
		var scroll := Input.get_axis("ui_up", "ui_down")
		if scroll == 0.0:
			scroll = float(any_pad_vertical())
		credits_scroll.scroll_vertical += roundi(scroll * CREDITS_SCROLL * delta)
	if page == track_page:
		# FUN_00061ab4 spins the ribbon by 8/4096 of a turn each game frame.
		track_pivot.rotate_y(-delta * TAU * 8.0 / 4096.0 * 30.0)
		advance_ribbon(delta)
		if track_reveal and track_scroll.size.y > 2.0:
			track_reveal = false
			reveal_listed()
		var vertical := any_pad_vertical()
		var horizontal := any_pad_direction()
		if vertical == 0 and horizontal == 0:
			track_pad_hold = 0.0
		elif track_pad_hold > 0.0:
			track_pad_hold -= delta
		else:
			if vertical != 0:
				step_listed(vertical)
			else:
				nudge_track_tab(horizontal)
			track_pad_hold = PAD_REPEAT
		return
	if page == car_page:
		car_preview.rotate_y(delta * 0.6)
		var direction := any_pad_direction()
		if direction == 0:
			car_pad_hold = 0.0
		elif car_pad_hold > 0.0:
			car_pad_hold -= delta
		else:
			cycle_race_car(direction)
			car_pad_hold = PAD_REPEAT
		return
	if page == online_page and Net.online and online_preview:
		online_preview.rotate_y(delta * 0.6)
		var online_direction := any_pad_direction()
		if online_direction == 0:
			online_pad_hold = 0.0
		elif online_pad_hold > 0.0:
			online_pad_hold -= delta
		else:
			cycle_online(online_direction)
			online_pad_hold = PAD_REPEAT
		return
	if page != multiplayer_page:
		return
	for i in battle_players:
		previews[i].rotate_y(delta * 0.6)
		var direction := pad_direction(i)
		if direction == 0:
			pad_hold[i] = 0.0
			continue
		if pad_hold[i] > 0.0:
			pad_hold[i] -= delta
			continue
		cycle_car(i, direction)
		pad_hold[i] = PAD_REPEAT


func _draw() -> void:
	var dim := 0.38 if page == null or page == main_page else 0.68
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, dim))


func build_header() -> void:
	var shader := Shader.new()
	shader.code = FLAG_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	header_flag = MeshInstance2D.new()
	header_flag.material = material
	header_flag.z_index = -1
	add_child(header_flag)
	header_chrome = Control.new()
	header_chrome.mouse_filter = Control.MOUSE_FILTER_PASS
	header_chrome.z_index = 10
	add_child(header_chrome)
	header_chrome.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_chrome.offset_bottom = HEADER_H
	resized.connect(layout_flag)
	layout_flag()


func build_quit_ask() -> void:
	quit_ask = Control.new()
	quit_ask.visible = false
	quit_ask.z_index = 20
	quit_ask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	quit_ask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(quit_ask)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	quit_ask.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quit_ask.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.shell_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Quit to Desktop?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	column.add_child(title)
	var body := Label.new()
	body.text = "The game will close."
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 22)
	body.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	quit_ask_cancel = Button.new()
	quit_ask_cancel.text = "Cancel"
	quit_ask_cancel.custom_minimum_size = Vector2(180, 64)
	quit_ask_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_ask_cancel.add_theme_font_size_override("font_size", 24)
	quit_ask_cancel.pressed.connect(func() -> void:
		Sound.ui()
		close_quit_ask()
	)
	UiTheme.hook_button(quit_ask_cancel)
	quit_ask_yes = Button.new()
	quit_ask_yes.text = "Quit"
	quit_ask_yes.custom_minimum_size = Vector2(180, 64)
	quit_ask_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit_ask_yes.add_theme_font_size_override("font_size", 24)
	quit_ask_yes.pressed.connect(func() -> void:
		Sound.ui()
		get_tree().quit()
	)
	UiTheme.hook_button(quit_ask_yes)
	row.add_child(quit_ask_yes)
	row.add_child(quit_ask_cancel)
	UiTheme.lock_focus([quit_ask_yes, quit_ask_cancel])


func prompt_quit() -> void:
	quit_return = get_viewport().gui_get_focus_owner()
	quit_ask.visible = true
	quit_ask.move_to_front()
	quit_ask_cancel.grab_focus()


func close_quit_ask() -> void:
	quit_ask.visible = false
	quit_return.grab_focus()


func layout_flag() -> void:
	if size.x < 2.0:
		return
	var bleed := 24.0
	header_flag.mesh = flag_mesh(size.x + bleed, HEADER_H)
	(header_flag.material as ShaderMaterial).set_shader_parameter("flag_size", Vector2(size.x + bleed, HEADER_H))


func flag_mesh(width: float, height: float) -> ArrayMesh:
	var cols := 36
	var rows := 6
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in rows + 1:
		for x in cols + 1:
			var u := float(x) / float(cols)
			var v := float(y) / float(rows)
			vertices.append(Vector3(u * width, v * height, 0.0))
			uvs.append(Vector2(u, v))
	for y in rows:
		for x in cols:
			var i := y * (cols + 1) + x
			var j := i + cols + 1
			indices.append_array(PackedInt32Array([i, j, i + 1, i + 1, j, j + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func present_header(next: VBoxContainer, previous: VBoxContainer) -> void:
	if previous:
		dismiss_header_item(previous.get_meta("heading"))
		if previous == multiplayer_page:
			dismiss_header_item(header_settings)
	reveal_header_item(next.get_meta("heading"))
	if next == multiplayer_page:
		reveal_header_item(header_settings)


func reveal_header_item(item: Control) -> void:
	var token := int(item.get_meta("header_token", 0)) + 1
	item.set_meta("header_token", token)
	UiTheme.kill_meta(item, "fade")
	item.visible = true
	item.scale = Vector2.ONE
	item.mouse_filter = item.get_meta("header_mouse")
	var rest_left: float = item.get_meta("rest_left")
	var rest_right: float = item.get_meta("rest_right")
	var from: float = item.get_meta("header_from")
	item.offset_left = rest_left + from * 28.0
	item.offset_right = rest_right + from * 28.0
	item.modulate.a = 0.0
	var tween := item.create_tween()
	item.set_meta("fade", tween)
	tween.set_parallel(true)
	tween.tween_property(item, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "offset_left", rest_left, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "offset_right", rest_right, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func dismiss_header_item(item: Control) -> void:
	var token := int(item.get_meta("header_token", 0)) + 1
	item.set_meta("header_token", token)
	UiTheme.kill_meta(item, "fade")
	var rest_left: float = item.get_meta("rest_left")
	var rest_right: float = item.get_meta("rest_right")
	var from: float = item.get_meta("header_from")
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := item.create_tween()
	item.set_meta("fade", tween)
	tween.set_parallel(true)
	tween.tween_property(item, "modulate:a", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "offset_left", rest_left + from * 20.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(item, "offset_right", rest_right + from * 20.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if int(item.get_meta("header_token", 0)) != token:
			return
		item.visible = false
		item.offset_left = rest_left
		item.offset_right = rest_right
	)


func build_backdrop() -> void:
	var dir := exhibition_dir()
	var track := prepare_backdrop()
	track.load_from(dir)
	finish_backdrop(track, dir)


func load_backdrop() -> void:
	var dir := exhibition_dir()
	var track := prepare_backdrop()
	await track.load_async(dir)
	finish_backdrop(track, dir)


func prepare_backdrop() -> Track:
	var world := Node3D.new()
	get_parent().add_child(world)
	get_parent().move_child(world, 0)
	world.tree_exiting.connect(func() -> void:
		for car in backdrop_cars:
			Sound.stop_engine(car)
	)
	var track := Track.new()
	track.process_mode = Node.PROCESS_MODE_DISABLED
	world.add_child(track)
	return track


func finish_backdrop(track: Track, dir: String) -> void:
	track.process_mode = Node.PROCESS_MODE_INHERIT
	var world := track.get_parent()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = track.sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.fog_enabled = true
	env.fog_light_color = track.sky_color
	env.fog_density = 0.003
	env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	world.add_child(sun)
	sun.look_at_from_position(Vector3(0.27, 0.92, 0.27), Vector3.ZERO)
	backdrop_cars = spawn_field(world, track, dir)
	var preset: String = Car.HANDLING.find_key(track.handling)
	for car in backdrop_cars:
		car.track = track
		car.apply_handling(preset)
	var race := Race.new()
	world.add_child(race)
	race.start(track, backdrop_cars, 0)
	race.endless = true
	race.ai_frame = track.ai_start[1]
	var follow := TrackCamera.new()
	follow.track = track
	follow.race = race
	follow.target = backdrop_cars[randi() % backdrop_cars.size()]
	world.add_child(follow)
	follow.snap_to_target()
	follow.current = true
	var track_script := TrackScript.new()
	world.add_child(track_script)
	track_script.setup(track, backdrop_cars, follow)
	var items := Items.new()
	world.add_child(items)
	items.setup(track, race, backdrop_cars, follow)


func open_setup(return_to: VBoxContainer) -> void:
	setup_return = return_to
	if setup_page == null:
		build_setup()
	setup_back.text = "Quit to Desktop" if return_to == null else "Back"
	if setup_job == null:
		setup_status.text = idle_setup_status()
		setup_bar.value = 0.0
		setup_go.disabled = false
		setup_disc.editable = true
		setup_addon.editable = true
		for button in setup_file_buttons:
			button.disabled = false
	show_page(setup_page)


func idle_setup_status() -> String:
	if Data.outdated():
		return "Your data folder is from an older version of the game and is missing content this version needs. Run the export again to update it."
	return "Waiting for data..."


func build_setup() -> void:
	var column := add_page(self, "Setup", 56)
	setup_page = column
	var center := Control.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(center)
	var panel := PanelContainer.new()
	var shell := UiTheme.shell_style()
	shell.content_margin_top = 16
	shell.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", shell)
	center.add_child(panel)
	center.resized.connect(func() -> void:
		var width := minf(center.size.x, 1080.0)
		var height := minf(center.size.y, 640.0)
		if width < 1.0 or height < 1.0:
			return
		panel.position = (center.size - Vector2(width, height)) * 0.5
		panel.size = Vector2(width, height)
	)
	var outer: VBoxContainer = column.get_parent()
	outer.get_child(1).visible = false
	outer.add_theme_constant_override("separation", 0)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	panel.add_child(inner)
	var help_pad := MarginContainer.new()
	help_pad.add_theme_constant_override("margin_top", 4)
	help_pad.add_theme_constant_override("margin_bottom", 4)
	inner.add_child(help_pad)
	var body := Label.new()
	body.text = "This copies the tracks, cars, and audio from your copy of Circuit Breakers into a data folder next to this game. You only need to do this once."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(960, 0)
	body.add_theme_font_size_override("font_size", 20)
	help_pad.add_child(body)
	inner.add_child(setup_caption("Circuit Breakers"))
	var disc_row := HBoxContainer.new()
	disc_row.add_theme_constant_override("separation", 12)
	inner.add_child(disc_row)
	setup_disc = setup_field(disc_row)
	setup_file_buttons.append(setup_pick_button(disc_row, "File…", "disc-file"))
	setup_file_buttons.append(setup_pick_button(disc_row, "Folder…", "disc-folder"))
	inner.add_child(setup_caption("Add-on disc"))
	var addon_row := HBoxContainer.new()
	addon_row.add_theme_constant_override("separation", 12)
	inner.add_child(addon_row)
	setup_addon = setup_field(addon_row)
	setup_file_buttons.append(setup_pick_button(addon_row, "File…", "addon-file"))
	var hint := Label.new()
	hint.text = "Optional. Castle and Rooftop levels are on the demo add-on disc."
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	inner.add_child(hint)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(gap)
	var progress := VBoxContainer.new()
	progress.add_theme_constant_override("separation", 6)
	inner.add_child(progress)
	setup_status = Label.new()
	setup_status.text = "Waiting for data..."
	setup_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	setup_status.custom_minimum_size = Vector2(960, 0)
	setup_status.add_theme_font_size_override("font_size", 24)
	progress.add_child(setup_status)
	setup_bar = ProgressBar.new()
	setup_bar.min_value = 0.0
	setup_bar.max_value = 1.0
	setup_bar.value = 0.0
	setup_bar.show_percentage = false
	setup_bar.custom_minimum_size = Vector2(0, 28)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.28, 0.05, 0.12, 0.95)
	var filled := StyleBoxFlat.new()
	filled.bg_color = UiTheme.CREAM
	setup_bar.add_theme_stylebox_override("background", groove)
	setup_bar.add_theme_stylebox_override("fill", filled)
	progress.add_child(setup_bar)
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(push)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 16)
	inner.add_child(actions)
	setup_back = setup_action(actions, "Quit to Desktop", leave_setup)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	setup_go = setup_action(actions, "Extract", start_setup)


func setup_action(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 72)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(func() -> void:
		Sound.ui()
		action.call()
	)
	UiTheme.hook_button(button)
	row.add_child(button)
	return button


func setup_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 26)
	return label


func setup_field(row: HBoxContainer) -> LineEdit:
	var field := LineEdit.new()
	field.custom_minimum_size = Vector2(0, 56)
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_theme_font_size_override("font_size", 22)
	row.add_child(field)
	return field


func setup_pick_button(row: HBoxContainer, text: String, kind: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(func() -> void:
		Sound.ui()
		open_setup_pick(kind)
	)
	UiTheme.hook_button(button)
	row.add_child(button)
	return button


func open_setup_pick(kind: String) -> void:
	setup_pick = kind
	if setup_dialog == null:
		setup_dialog = FileDialog.new()
		setup_dialog.access = FileDialog.ACCESS_FILESYSTEM
		setup_dialog.use_native_dialog = false
		setup_dialog.file_selected.connect(apply_setup_pick)
		setup_dialog.dir_selected.connect(apply_setup_pick)
		add_child(setup_dialog)
	var directory := kind.ends_with("folder")
	setup_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if directory else FileDialog.FILE_MODE_OPEN_FILE
	setup_dialog.title = "Demo add-on disc" if kind.begins_with("addon") else "Circuit Breakers disc"
	setup_dialog.filters = PackedStringArray() if directory else PackedStringArray(["*.cue, *.bin, *.iso ; Cue sheet or disc image"])
	setup_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	setup_dialog.popup_centered_ratio(0.72)
	focus_setup_dialog.call_deferred()


func apply_setup_pick(path: String) -> void:
	if setup_pick == "addon-file":
		setup_addon.text = path
	else:
		setup_disc.text = path


func start_setup() -> void:
	var source := setup_disc.text.strip_edges()
	if source == "":
		setup_status.text = "Choose your copy of Circuit Breakers."
		return
	setup_go.disabled = true
	setup_disc.editable = false
	setup_addon.editable = false
	for button in setup_file_buttons:
		button.disabled = true
	setup_bar.value = 0.0
	setup_status.text = "Copying Starting"
	setup_job = ContentExport.new()
	setup_job.start(source, setup_addon.text.strip_edges(), Data.content_folder())


func leave_setup() -> void:
	if setup_return == null:
		prompt_quit()
		return
	show_page(setup_return)


func poll_setup() -> void:
	var snap := setup_job.snapshot()
	setup_bar.value = snap.progress
	if not snap.finished:
		setup_status.text = "Copying " + snap.status
		return
	var job := setup_job
	setup_job = null
	job.join()
	if snap.error != "":
		setup_status.text = snap.error
		setup_go.disabled = false
		setup_disc.editable = true
		setup_addon.editable = true
		for button in setup_file_buttons:
			button.disabled = false
		return
	if not Data.adopt(Data.content_folder()):
		setup_status.text = "Export finished, but the data folder is still incomplete."
		setup_go.disabled = false
		setup_disc.editable = true
		setup_addon.editable = true
		for button in setup_file_buttons:
			button.disabled = false
		return
	Sound.boot()
	Fx.boot()
	if setup_return != null:
		setup_status.text = "Waiting for data..."
		setup_bar.value = 0.0
		setup_go.disabled = false
		setup_disc.editable = true
		setup_addon.editable = true
		for button in setup_file_buttons:
			button.disabled = false
		show_page(setup_return)
		return
	var heading: Control = page.get_meta("heading")
	var shell: Control = page.get_meta("shell")
	heading.queue_free()
	page = null
	setup_page = null
	shell.queue_free()
	build_game()


func race_groups() -> Array:
	var groups: Array = JSON.parse_string(Data.text(RACES))
	if Data.exists(ADDON):
		groups.append_array(JSON.parse_string(Data.text(ADDON)))
	return groups


func exhibition_dir() -> String:
	var dirs: Array[String] = []
	for group: Dictionary in race_groups():
		for dir: String in group.tracks:
			if not Data.exists(dir + "/track.json"):
				continue
			var info: Dictionary = JSON.parse_string(Data.text(dir + "/track.json"))
			if info.ai_start != null:
				dirs.append(dir)
	return dirs[randi() % dirs.size()]


func spawn_field(world: Node3D, track: Track, dir: String) -> Array[Car]:
	var count := track.nodes.size()
	var mesh := Car.mesh_for(dir)
	var grid_node: Array[int] = []
	var grid_lane: Array[float] = []
	grid_node.resize(Session.GRID)
	grid_lane.resize(Session.GRID)
	var cursor := 0
	var order: Array[int] = [7, 1, 2, 3, 4, 5, 6, 0]
	for step in Session.GRID:
		var node := cursor
		if node < 0:
			node = node - 1 + count
		var slot: int = order[step]
		grid_node[slot] = track.respawn_node(node)
		grid_lane[slot] = 0.25 if (step & 1) == 0 else 0.75
		cursor = -(step + 1)
	var cars: Array[Car] = []
	for slot in Session.GRID:
		var placed := track.node_transform(grid_node[slot], grid_lane[slot])
		var car := Car.new()
		car.model = slot
		car.mesh_dir = mesh
		car.transform = Transform3D(Basis(Vector3.UP, placed.basis.get_euler().y), placed.origin)
		car.autopilot_enabled = true
		car.add_to_group("cars")
		world.add_child(car)
		car.track = track
		car.plant(grid_node[slot])
		cars.append(car)
	return cars


func _input(event: InputEvent) -> void:
	if setup_dialog != null and setup_dialog.visible and event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		if joy.pressed and joy.button_index == JOY_BUTTON_Y:
			setup_dialog.get_ok_button().pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if page == track_page:
		if event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT or event.button_index == JOY_BUTTON_DPAD_UP or event.button_index == JOY_BUTTON_DPAD_DOWN):
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and (event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y) and absf(event.axis_value) > 0.5:
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed:
			if event.physical_keycode == KEY_W or event.physical_keycode == KEY_UP:
				step_listed(-1)
			elif event.physical_keycode == KEY_S or event.physical_keycode == KEY_DOWN:
				step_listed(1)
			elif event.physical_keycode == KEY_A or event.physical_keycode == KEY_LEFT:
				nudge_track_tab(-1)
			elif event.physical_keycode == KEY_D or event.physical_keycode == KEY_RIGHT:
				nudge_track_tab(1)
			else:
				return
			get_viewport().set_input_as_handled()
		return
	if page == car_page:
		if event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT):
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.5:
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed:
			if event.physical_keycode == KEY_A or event.physical_keycode == KEY_LEFT:
				cycle_race_car(-1)
			elif event.physical_keycode == KEY_D or event.physical_keycode == KEY_RIGHT:
				cycle_race_car(1)
			else:
				return
			get_viewport().set_input_as_handled()
		return
	if page == online_page and Net.online:
		var focus := get_viewport().gui_get_focus_owner()
		var field := focus is SpinBox or focus is OptionButton
		if not field and event is InputEventJoypadButton and event.pressed and (event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT):
			get_viewport().set_input_as_handled()
		elif not field and event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) > 0.5:
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not focus is LineEdit and not focus is SpinBox:
			if event.physical_keycode == KEY_A or event.physical_keycode == KEY_LEFT:
				cycle_online(-1)
			elif event.physical_keycode == KEY_D or event.physical_keycode == KEY_RIGHT:
				cycle_online(1)
			else:
				return
			get_viewport().set_input_as_handled()
		return
	if page != multiplayer_page:
		return
	var focus := get_viewport().gui_get_focus_owner()
	var field := focus is SpinBox or focus is OptionButton
	if event is InputEventJoypadButton and event.pressed and event.device >= 0:
		if assigning >= 0 and event.button_index < JOY_BUTTON_DPAD_UP:
			assign_pad(assigning, event.device)
			get_viewport().set_input_as_handled()
			return
		var owner := Battle.devices.find(event.device)
		if not field and owner >= 0 and owner < battle_players and (event.button_index == JOY_BUTTON_DPAD_LEFT or event.button_index == JOY_BUTTON_DPAD_RIGHT):
			get_viewport().set_input_as_handled()
	elif not field and event is InputEventJoypadMotion and event.device >= 0 and event.axis == JOY_AXIS_LEFT_X:
		var owner := Battle.devices.find(event.device)
		if owner >= 0 and owner < battle_players and absf(event.axis_value) > 0.5:
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not focus is SpinBox:
		var navigating := focus is OptionButton or focus is ItemList
		if event.physical_keycode == KEY_A:
			cycle_car(0, -1)
		elif event.physical_keycode == KEY_D:
			cycle_car(0, 1)
		elif not navigating and battle_players > 1 and event.physical_keycode == KEY_LEFT:
			cycle_car(1, -1)
		elif not navigating and battle_players > 1 and event.physical_keycode == KEY_RIGHT:
			cycle_car(1, 1)
		else:
			return
		get_viewport().set_input_as_handled()


func build_multiplayer(column: VBoxContainer) -> void:
	column.add_theme_constant_override("separation", 8)
	var settings := HBoxContainer.new()
	header_settings = settings
	settings.alignment = BoxContainer.ALIGNMENT_END
	settings.add_theme_constant_override("separation", 16)
	settings.visible = false
	settings.modulate.a = 0.0
	header_chrome.add_child(settings)
	settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	settings.offset_left = 0.0
	settings.offset_top = (HEADER_H - 2.0 - 56.0) * 0.5
	settings.offset_right = -64.0
	settings.offset_bottom = settings.offset_top + 56.0
	settings.set_meta("rest_left", settings.offset_left)
	settings.set_meta("rest_right", settings.offset_right)
	settings.set_meta("header_from", 1.0)
	settings.set_meta("header_mouse", settings.mouse_filter)
	var count := OptionButton.new()
	for n in range(2, 5):
		count.add_item("%d Players" % n)
	count.select(battle_players - 2)
	add_setting(settings, "", count)
	var target := SpinBox.new()
	target.min_value = 1
	target.max_value = 99
	target.value = Battle.target
	target.value_changed.connect(func(value: float) -> void: Battle.target = int(value))
	add_setting(settings, "Points", target)
	target.custom_minimum_size = Vector2(52, 40)
	target.add_theme_constant_override("buttons_width", 16)
	target.add_theme_constant_override("field_and_buttons_separation", 2)
	var points_field := UiTheme.panel_style(Color(0.16, 0.03, 0.08, 0.92), Color(UiTheme.ACCENT, 0.9))
	points_field.content_margin_left = 6
	points_field.content_margin_right = 2
	points_field.content_margin_top = 4
	points_field.content_margin_bottom = 4
	var points_edit := target.get_line_edit()
	points_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	for state in ["normal", "focus", "read_only"]:
		points_edit.add_theme_stylebox_override(state, points_field)
	var pickups := OptionButton.new()
	for option: String in PICKUP_NAMES:
		pickups.add_item(option)
	pickups.select(Battle.pickups)
	pickups.item_selected.connect(func(index: int) -> void: Battle.pickups = index)
	add_setting(settings, "Pickups", pickups)

	var shell: Control = column.get_meta("shell")
	player_stage = Control.new()
	player_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	player_stage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shell.add_child(player_stage)
	player_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.resized.connect(fit_car_stage.bind(player_stage))
	fit_car_stage(player_stage)
	player_stage.resized.connect(layout_players)
	for i in 4:
		player_stage.add_child(build_player_card(i))
	player_stage.draw.connect(draw_player_stage)
	count.item_selected.connect(func(index: int) -> void:
		battle_players = index + 2
		Battle.target = Battle.TARGETS[battle_players]
		target.value = Battle.target
		if assigning >= battle_players:
			assigning = -1
			refresh_pads()
		settle_models()
		show_players())

	show_players()
	add_nav(column, "Back", show_page.bind(main_page), false)
	add_nav(column, "Tracks", open_tracks.bind(true), true)


func build_online(column: VBoxContainer) -> void:
	column.add_theme_constant_override("separation", 10)
	online_status = Label.new()
	online_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_status.add_theme_font_size_override("font_size", 18)
	column.add_child(online_status)

	online_connect = VBoxContainer.new()
	online_connect.alignment = BoxContainer.ALIGNMENT_CENTER
	online_connect.add_theme_constant_override("separation", 10)
	column.add_child(online_connect)
	var address_row := HBoxContainer.new()
	address_row.alignment = BoxContainer.ALIGNMENT_CENTER
	online_connect.add_child(address_row)
	online_address = LineEdit.new()
	online_address.text = "127.0.0.1"
	online_address.placeholder_text = "Address"
	online_address.custom_minimum_size = Vector2(560, 52)
	online_address.add_theme_font_size_override("font_size", 26)
	address_row.add_child(online_address)
	var port_row := HBoxContainer.new()
	port_row.alignment = BoxContainer.ALIGNMENT_CENTER
	online_connect.add_child(port_row)
	var port_label := Label.new()
	port_label.text = "Port"
	port_label.add_theme_font_size_override("font_size", 26)
	port_row.add_child(port_label)
	online_port = SpinBox.new()
	online_port.min_value = 1
	online_port.max_value = 65535
	online_port.value = Net.DEFAULT_PORT
	online_port.custom_minimum_size = Vector2(200, 52)
	online_port.add_theme_font_size_override("font_size", 26)
	port_row.add_child(online_port)
	add_button(online_connect, "Host", host_online)
	add_button(online_connect, "Join", join_online)

	online_lobby = VBoxContainer.new()
	online_lobby.alignment = BoxContainer.ALIGNMENT_CENTER
	online_lobby.size_flags_vertical = Control.SIZE_EXPAND_FILL
	online_lobby.add_theme_constant_override("separation", 12)
	column.add_child(online_lobby)
	online_connect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	online_host_line = Label.new()
	online_host_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_host_line.add_theme_font_size_override("font_size", 22)
	online_lobby.add_child(online_host_line)
	online_list = Label.new()
	online_list.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_list.add_theme_font_size_override("font_size", 24)
	online_lobby.add_child(online_list)

	var stage := HBoxContainer.new()
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_theme_constant_override("separation", 28)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	online_lobby.add_child(stage)
	add_arrow(stage, "arrowLeft", cycle_online.bind(-1), false)
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(420, 220)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(box)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.size = Vector2i(840, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(viewport)
	dress_stage(viewport)
	online_preview = spawn_model(viewport, 0, 0.5)
	add_arrow(stage, "arrowRight", cycle_online.bind(1), false)

	online_car_label = Label.new()
	online_car_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_car_label.add_theme_font_size_override("font_size", 28)
	online_car_label.text = CAR_NAMES[0]
	online_lobby.add_child(online_car_label)

	online_expert = CheckBox.new()
	online_expert.text = "Expert"
	online_expert.add_theme_font_size_override("font_size", 24)
	online_expert.toggled.connect(func(on: bool) -> void:
		Net.local_expert = 1 if on else 0
		Net.push_profile()
	)
	online_lobby.add_child(online_expert)

	online_settings = HBoxContainer.new()
	online_settings.alignment = BoxContainer.ALIGNMENT_CENTER
	online_settings.add_theme_constant_override("separation", 20)
	online_lobby.add_child(online_settings)
	var target := SpinBox.new()
	target.min_value = 1
	target.max_value = 99
	target.value = Battle.target
	target.value_changed.connect(func(value: float) -> void: Battle.target = int(value))
	add_setting(online_settings, "Points", target)
	var pickups := OptionButton.new()
	for option: String in PICKUP_NAMES:
		pickups.add_item(option)
	pickups.select(Battle.pickups)
	pickups.item_selected.connect(func(index: int) -> void: Battle.pickups = index)
	add_setting(online_settings, "Pickups", pickups)

	online_wait = Label.new()
	online_wait.text = "Waiting for the host"
	online_wait.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	online_wait.add_theme_font_size_override("font_size", 26)
	online_lobby.add_child(online_wait)
	online_tracks = add_nav(column, "Tracks", open_tracks.bind(true, true), true)
	online_tracks.visible = false
	add_nav(column, "Back", leave_online, false)


func host_online() -> void:
	Net.host(int(online_port.value))


func join_online() -> void:
	var address := online_address.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
	Net.join(address, int(online_port.value))


func leave_online() -> void:
	if Net.online:
		Net.close()
		Net.status = ""
		refresh_online()
		return
	show_page(main_page)


func refresh_online() -> void:
	online_status.text = Net.status
	var lobby_was := online_lobby.visible
	online_connect.visible = not Net.online
	online_lobby.visible = Net.online
	var shell: Control = online_page.get_meta("shell")
	if shell.modulate.a > 0.9:
		if Net.online and not lobby_was:
			UiTheme.punch(online_lobby)
		elif not Net.online and lobby_was:
			UiTheme.punch(online_connect)
	if not Net.online:
		online_tracks.visible = false
		link_page(online_page)
		if page == online_page:
			online_address.grab_focus()
		return
	online_host_line.text = host_line()
	online_host_line.visible = Net.is_host()
	online_settings.visible = Net.is_host()
	online_tracks.visible = Net.is_host()
	online_tracks.disabled = Net.peers.size() < 2
	online_wait.visible = not Net.is_host()
	online_expert.set_pressed_no_signal(Net.local_expert == 1)
	if online_shown != Net.local_model:
		online_shown = Net.local_model
		show_online_model()
	var lines := PackedStringArray()
	for i in Net.peers.size():
		var peer: Dictionary = Net.peers[i]
		var line := "P%d  %s" % [i + 1, CAR_NAMES[int(peer.model)]]
		if int(peer.expert) == 1:
			line += "  Expert"
		if i == Net.slot:
			line += "  (you)"
		lines.append(line)
	if lines.is_empty():
		lines.append("Connecting...")
	online_list.text = "\n".join(lines)
	var wins := PackedStringArray()
	for i in Net.peers.size():
		wins.append("P%d: %d" % [i + 1, Battle.wins[i]])
	if Net.peers.size() > 0:
		online_list.text += "\n" + "    ".join(wins)
	link_page(online_page)
	if page == online_page and not lobby_was:
		online_expert.grab_focus()


func host_line() -> String:
	var ips := PackedStringArray()
	for ip in IP.get_local_addresses():
		if ip.contains(":") or ip.begins_with("127."):
			continue
		ips.append(ip)
	var where := "port %d" % Net.port
	if ips.size() > 0:
		where = "%s, port %d" % [", ".join(ips), Net.port]
	return "Others join at %s" % where


func cycle_online(direction: int) -> void:
	var model := Net.local_model
	for _step in Car.CAR_MODELS - 1:
		model = wrapi(model + direction, 0, Car.CAR_MODELS)
		if not online_taken(model):
			break
	if model == Net.local_model:
		return
	Sound.ui()
	Net.local_model = model
	online_shown = model
	show_online_model()
	Net.push_profile()


func online_taken(model: int) -> bool:
	for i in Net.peers.size():
		if i != Net.slot and int(Net.peers[i].model) == model:
			return true
	return false


func show_online_model() -> void:
	online_car_label.text = CAR_NAMES[Net.local_model]
	UiTheme.punch(online_car_label)
	var viewport := online_preview.get_parent() as SubViewport
	var yaw := online_preview.rotation.y
	online_preview.free()
	online_preview = spawn_model(viewport, Net.local_model, yaw)


func build_tracks(column: VBoxContainer) -> void:
	column.add_theme_constant_override("separation", 8)
	track_wins = HBoxContainer.new()
	track_wins.alignment = BoxContainer.ALIGNMENT_CENTER
	track_wins.add_theme_constant_override("separation", 28)
	track_wins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var footer_left: HBoxContainer = column.get_meta("footer_left")
	var footer := footer_left.get_parent() as HBoxContainer
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	var spacer := footer.get_child(1)
	footer.remove_child(spacer)
	spacer.free()
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(center)
	footer.move_child(center, 1)
	center.add_child(track_wins)
	for world: String in WORLDS:
		var icon := "res://textures/menu/%s.png" % world
		world_icons.append(Data.texture(icon) if Data.exists(icon) else ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8)))
	for i in 6:
		weather_icons.append(Data.texture("res://textures/menu/weather_%d.png" % i))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 28)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	var list_margin := MarginContainer.new()
	list_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_margin.add_theme_constant_override("margin_top", 24)
	list_margin.add_theme_constant_override("margin_bottom", 24)
	body.add_child(list_margin)
	var list_side := VBoxContainer.new()
	list_side.custom_minimum_size = Vector2(520, 0)
	list_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_side.add_theme_constant_override("separation", 0)
	list_margin.add_child(list_side)
	track_tab_off = track_tab_face(false)
	track_tab_on = track_tab_face(true)
	track_tab_hover = track_tab_face(false)
	track_tab_hover.bg_color = Color(0.18, 0.04, 0.09, 1)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	list_side.add_child(tabs)
	track_tab_courses = track_tab_button(tabs, "Courses", 0)
	track_tab_custom = track_tab_button(tabs, "Custom", 1)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.14, 0.03, 0.07, 1)
	well.set_border_width_all(0)
	well.content_margin_left = 12
	well.content_margin_right = 12
	well.content_margin_top = 14
	well.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", well)
	list_side.add_child(panel)
	track_scroll = ScrollContainer.new()
	track_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	track_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(track_scroll)
	track_list = VBoxContainer.new()
	track_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track_list.add_theme_constant_override("separation", 6)
	track_scroll.add_child(track_list)

	var detail := VBoxContainer.new()
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 8)
	body.add_child(detail)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override("separation", 18)
	detail.add_child(icons)
	track_world = TextureRect.new()
	track_world.custom_minimum_size = Vector2(112, 112)
	track_world.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track_world.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	track_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	track_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.add_child(track_world)
	track_weather = TextureRect.new()
	track_weather.custom_minimum_size = Vector2(72, 72)
	track_weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track_weather.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track_weather.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	track_weather.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	track_weather.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.add_child(track_weather)
	var view := build_track_view()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(view)

	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	detail.add_child(names)
	track_group = Label.new()
	track_group.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_group.add_theme_font_size_override("font_size", 22)
	track_group.add_theme_color_override("font_color", Color(0.98, 0.78, 0.88))
	names.add_child(track_group)
	track_label = Label.new()
	track_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_label.add_theme_font_size_override("font_size", 36)
	names.add_child(track_label)
	track_best = Label.new()
	track_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_best.add_theme_font_size_override("font_size", 24)
	track_best.add_theme_color_override("font_color", UiTheme.CREAM)
	names.add_child(track_best)

	track_start = add_nav(column, "Next", open_mode, true)
	add_nav(column, "Back", leave_tracks, false)


func open_tracks(for_battle: bool, for_online := false) -> void:
	track_for_battle = for_battle
	track_for_online = for_online
	fill_tracks(not for_battle and not for_online)
	refresh_track_wins()
	show_page(track_page)


func build_mode(column: VBoxContainer) -> void:
	var stack := page_stack(column)
	stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mode_best = Label.new()
	mode_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_best.add_theme_font_size_override("font_size", 26)
	mode_best.add_theme_color_override("font_color", UiTheme.CREAM)
	stack.add_child(mode_best)
	mode_world = add_button(stack, "World Series", start_world_series)
	mode_battle = add_button(stack, "Battle", start_selected_battle.bind(false))
	mode_bumper = add_button(stack, "Bumper Cars", start_selected_battle.bind(true))
	mode_trial = add_button(stack, "Time Trial", start_time_trial)
	add_nav(column, "Back", show_page.bind(track_page), false)


func open_mode() -> void:
	var index := battle_track if track_for_battle or track_for_online else race_track
	mode_best.text = best_caption(record_dir(index))
	mode_world.visible = not track_for_battle and not track_for_online and supports_ai(track_paths[index])
	mode_battle.visible = track_for_battle or track_for_online
	mode_bumper.visible = mode_battle.visible and not submarine(track_paths[index])
	show_page(mode_page)


func submarine(path: String) -> bool:
	if path.ends_with(".json"):
		return int(JSON.parse_string(FileAccess.get_file_as_string(path)).vehicle) == 2
	return path.get_file().begins_with("aqua")


func supports_ai(path: String) -> bool:
	if path.ends_with(".json"):
		return LevelBuild.supports_ai(JSON.parse_string(FileAccess.get_file_as_string(path)))
	var info: Dictionary = JSON.parse_string(Data.text(path + "/track.json"))
	return info.ai_start != null


func start_world_series() -> void:
	Session.time_trial = false
	start_race(current_path())


func start_selected_battle(bumper: bool) -> void:
	Session.time_trial = false
	var source := current_path()
	if track_for_online:
		Net.begin_battle(selected_track(), level_text(source), source, bumper)
	else:
		Session.bumper = bumper
		start_battle(source)


func start_time_trial() -> void:
	var source := current_path()
	if track_for_online:
		Net.begin_trial(selected_track(), level_text(source), source)
		return
	Session.time_trial = true
	Session.trial_turn = 0
	if track_for_battle:
		Session.trial_models = PackedInt32Array()
		Session.trial_controls = PackedStringArray()
		for i in battle_players:
			Session.trial_models.append(Battle.models[i])
			Session.trial_controls.append("_%d" % (i + 1))
		Battle.players = 0
		Session.rebind_pads()
	else:
		Session.trial_models = PackedInt32Array([race_model])
		Session.trial_controls = PackedStringArray([""])
		Battle.players = 0
	Sound.depart(func() -> void: Session.launch(source))


func current_path() -> String:
	var index := battle_track if track_for_battle or track_for_online else race_track
	return track_paths[index]


func level_text(source: String) -> String:
	if source.ends_with(".json"):
		return FileAccess.get_file_as_string(source)
	return ""


func selected_track() -> String:
	var path := current_path()
	if path.ends_with(".json"):
		return LevelBuild.course_dir(path)
	return path


func record_dir(index: int) -> String:
	var path := track_paths[index]
	if path.ends_with(".json"):
		return LevelBuild.course_dir(path)
	return path


func best_caption(dir: String) -> String:
	var seconds := Settings.best_time(dir)
	var caption := "Best %s" % Hud.format_time(seconds) if seconds >= 0.0 else "Best —"
	var place := Settings.best_place(dir)
	if place < 1:
		return caption
	return "%s\nPlace %d/%d" % [caption, place, Settings.best_field(dir)]


func fill_tracks(race: bool) -> void:
	track_paths.clear()
	track_names.clear()
	track_groups.clear()
	if race:
		for group: Dictionary in race_groups():
			for dir: String in group.tracks:
				if not Data.exists(dir + "/track.json"):
					continue
				track_paths.append(dir)
				track_names.append(Session.title(dir))
				track_groups.append(int(group.group))
	else:
		for world: String in WORLDS:
			for number in range(1, 5):
				for reverse in [false, true]:
					var dir := Session.directory(world, number, reverse)
					if not Data.exists(dir + "/track.json"):
						continue
					track_paths.append(dir)
					track_names.append(Session.title(dir))
					track_groups.append(0)
	for saved: Dictionary in LevelBuild.list_playable():
		track_paths.append(String(saved.path))
		track_names.append(String(saved.name))
		track_groups.append(-1)
	var index := race_track if race else battle_track
	if index >= track_paths.size():
		index = 0
	if race:
		race_track = index
	else:
		battle_track = index
	track_tab = 1 if track_paths[index].ends_with(".json") else 0
	listed_pick[0] = first_in_tab(0)
	listed_pick[1] = first_in_tab(1)
	listed_pick[track_tab] = index
	paint_track_tabs()
	rebuild_track_list()
	show_track(index)


func leave_tracks() -> void:
	if track_for_online:
		show_page(online_page)
	else:
		show_page(multiplayer_page if track_for_battle else car_page)




func cycle_track(direction: int) -> void:
	Sound.ui()
	var index := battle_track if track_for_battle or track_for_online else race_track
	show_track(wrapi(index + direction, 0, track_paths.size()))
	UiTheme.punch(track_label)


func track_tab_face(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var well_color := Color(0.14, 0.03, 0.07, 1)
	style.bg_color = well_color if selected else Color(0, 0, 0, 0)
	var line := UiTheme.ACCENT
	line.a = 0.7
	style.border_color = well_color if selected else line
	style.set_border_width_all(0)
	style.border_width_bottom = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 10
	return style


func track_tab_button(parent: HBoxContainer, text: String, tab: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 46)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void:
		Sound.ui()
		show_track_tab(tab)
	)
	parent.add_child(button)
	return button


func paint_track_tabs() -> void:
	paint_track_tab(track_tab_courses, track_tab == 0)
	paint_track_tab(track_tab_custom, track_tab == 1)


func paint_track_tab(button: Button, on: bool) -> void:
	var face := track_tab_on if on else track_tab_off
	button.add_theme_stylebox_override("normal", face)
	button.add_theme_stylebox_override("hover", track_tab_on if on else track_tab_hover)
	button.add_theme_stylebox_override("pressed", face)
	button.add_theme_stylebox_override("focus", face)
	var ink := UiTheme.CREAM if on else Color(1, 1, 1, 0.55)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", UiTheme.CREAM)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_focus_color", ink)


func show_track_tab(tab: int) -> void:
	if tab == track_tab:
		return
	listed_pick[track_tab] = battle_track if track_for_battle or track_for_online else race_track
	track_tab = tab
	paint_track_tabs()
	rebuild_track_list()
	var index := listed_pick[tab]
	if index < 0 or index >= track_paths.size() or track_paths[index].ends_with(".json") != (tab == 1):
		index = first_in_tab(tab)
	if index >= 0:
		show_track(index)


func nudge_track_tab(direction: int) -> void:
	var tab := clampi(track_tab + direction, 0, 1)
	if tab == track_tab:
		return
	Sound.ui()
	show_track_tab(tab)


func first_in_tab(tab: int) -> int:
	for i in track_paths.size():
		if track_paths[i].ends_with(".json") == (tab == 1):
			return i
	return -1


func step_listed(direction: int) -> void:
	var index := battle_track if track_for_battle or track_for_online else race_track
	var count := track_paths.size()
	var next := index
	for _step in count:
		next = wrapi(next + direction, 0, count)
		if track_paths[next].ends_with(".json") != (track_tab == 1):
			continue
		if next == index:
			return
		Sound.ui()
		show_track(next)
		UiTheme.punch(track_label)
		return


func rebuild_track_list() -> void:
	var old := track_list.get_children()
	for child in old:
		child.free()
	var rows := ButtonGroup.new()
	rows.allow_unpress = false
	var last_group := 0
	var any := false
	var index := battle_track if track_for_battle or track_for_online else race_track
	for i in track_paths.size():
		var custom := track_paths[i].ends_with(".json")
		if custom != (track_tab == 1):
			continue
		any = true
		var course_group := track_groups[i]
		if course_group > 0 and course_group != last_group:
			last_group = course_group
			var heading := Label.new()
			heading.text = "Group %d" % course_group
			heading.add_theme_font_size_override("font_size", 18)
			heading.add_theme_color_override("font_color", Color(0.98, 0.78, 0.88))
			heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pad := MarginContainer.new()
			pad.add_theme_constant_override("margin_left", 8)
			pad.add_theme_constant_override("margin_top", 8)
			pad.add_child(heading)
			track_list.add_child(pad)
		var button := Button.new()
		button.text = track_names[i]
		button.clip_text = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = rows
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_stylebox_override("normal", list_row_style(Color(0.86, 0.15, 0.46, 0.28), Color(0.86, 0.15, 0.46, 0.0)))
		button.add_theme_stylebox_override("hover", list_row_style(Color(0.86, 0.15, 0.46, 0.72), UiTheme.CREAM))
		button.add_theme_stylebox_override("pressed", list_row_style(UiTheme.CREAM, UiTheme.CORAL))
		button.add_theme_stylebox_override("hover_pressed", list_row_style(UiTheme.CREAM, UiTheme.CORAL))
		button.add_theme_stylebox_override("focus", list_row_style(Color(0.86, 0.15, 0.46, 0.72), UiTheme.CREAM))
		button.set_meta("index", i)
		button.set_pressed_no_signal(i == index)
		button.pressed.connect(select_listed.bind(i))
		track_list.add_child(button)
	if not any:
		var empty := Label.new()
		empty.text = "No custom tracks" if track_tab == 1 else "No courses"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 20)
		empty.add_theme_color_override("font_color", UiTheme.CREAM)
		track_list.add_child(empty)
	track_reveal = true


func list_row_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(0)
	style.border_width_left = 4
	style.content_margin_left = 14
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func select_listed(index: int) -> void:
	Sound.ui()
	show_track(index)
	UiTheme.punch(track_label)


func reveal_listed() -> void:
	for child in track_list.get_children():
		if child is Button and int(child.get_meta("index")) == (battle_track if track_for_battle or track_for_online else race_track):
			track_scroll.ensure_control_visible(child)
			return


func build_track_view() -> Control:
	var box := SubViewportContainer.new()
	box.custom_minimum_size = Vector2(0, 280)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.size = Vector2i(1200, 960)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(viewport)
	track_environment = Environment.new()
	track_environment.background_mode = Environment.BG_COLOR
	track_environment.background_color = Color(0, 0, 0, 0)
	track_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	track_environment.ambient_light_color = Color(0.72, 0.72, 0.74)
	track_environment.ambient_light_energy = 1.3
	var world := WorldEnvironment.new()
	world.environment = track_environment
	viewport.add_child(world)
	track_pivot = Node3D.new()
	viewport.add_child(track_pivot)
	track_ribbon = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	track_ribbon.material_override = material
	track_pivot.add_child(track_ribbon)
	var data: Dictionary = JSON.parse_string(Data.text(PREVIEWS))
	preview_colors = data.colors
	preview_weather = data.weather
	preview_tracks = data.tracks
	track_camera = Camera3D.new()
	track_camera.fov = 48.0
	viewport.add_child(track_camera)
	return box


func show_track(index: int) -> void:
	if track_for_battle or track_for_online:
		battle_track = index
		track_group.visible = false
		track_best.visible = false
	else:
		race_track = index
		track_group.visible = track_groups[index] > 0
		if track_groups[index] > 0:
			track_group.text = "Group %d" % track_groups[index]
		track_best.visible = true
		track_best.text = best_caption(record_dir(index))
	var path := track_paths[index]
	var tab := 1 if path.ends_with(".json") else 0
	listed_pick[tab] = index
	if tab != track_tab:
		track_tab = tab
		paint_track_tabs()
		rebuild_track_list()
	else:
		for child in track_list.get_children():
			if child is Button:
				var row := child as Button
				row.set_pressed_no_signal(int(row.get_meta("index")) == index)
		track_reveal = true
	if path.ends_with(".json"):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		track_label.text = String(parsed.name)
		var world_index := WORLDS.find(String(parsed.tileset))
		track_world.texture = world_icons[world_index]
		track_weather.texture = weather_icons[0]
		ribbon_reverse = false
		var line: Array = parsed.line
		ribbon_track = ribbon_from_line(line)
		ribbon_tint = preview_colors[world_index]
	else:
		var info := Session.describe(path)
		track_label.text = Session.title(path)
		ribbon_reverse = info.reverse
		var world := WORLDS.find(info.world)
		ribbon_slot = world * 4 + int(info.number) - 1
		track_world.texture = world_icons[world]
		track_weather.texture = weather_icons[int(preview_weather[ribbon_slot])]
		ribbon_track = preview_tracks[ribbon_slot]
		ribbon_tint = preview_colors[ribbon_slot >> 2]
	ribbon_time = 0.0
	ribbon_shown = -1
	track_pivot.rotation = Vector3.ZERO
	frame_ribbon()
	advance_ribbon(0.0)


# FUN_00061ab4 reveals four more nodes every frame. A reverse course walks
# that ribbon backwards, which is how its nodes are stored.
func ribbon_from_line(line: Array) -> Dictionary:
	var x0: Array = []
	var z0: Array = []
	var x1: Array = []
	var z1: Array = []
	var heights: Array = []
	var lift: Array = []
	var low := 0
	var high := 0
	for sample: Dictionary in line:
		var y := int(sample.y) << 4
		x0.append(int(sample.lx))
		z0.append(int(sample.lz))
		x1.append(int(sample.rx))
		z1.append(int(sample.rz))
		heights.append(y)
		lift.append(0)
		if heights.size() == 1 or y < low:
			low = y
		if heights.size() == 1 or y > high:
			high = y
	return {"x0": x0, "z0": z0, "x1": x1, "z1": z1, "h": heights, "a": lift, "b": lift.duplicate(), "h0": low, "h1": high}


func advance_ribbon(delta: float) -> void:
	if ribbon_track.is_empty():
		return
	ribbon_time += delta
	var shown := int(ribbon_time * 30.0 * 4.0)
	var count: int = ribbon_track.x0.size()
	if shown > count:
		shown = count
	if shown == ribbon_shown:
		return
	ribbon_shown = shown
	track_ribbon.mesh = ribbon_mesh(shown)


func frame_ribbon() -> void:
	var track: Dictionary = ribbon_track
	var n: int = track.x0.size()
	var min_x := 1e9
	var max_x := -1e9
	var min_z := 1e9
	var max_z := -1e9
	for i in n:
		min_x = minf(min_x, minf(track.x0[i], track.x1[i]))
		max_x = maxf(max_x, maxf(track.x0[i], track.x1[i]))
		min_z = minf(min_z, minf(track.z0[i], track.z1[i]))
		max_z = maxf(max_z, maxf(track.z0[i], track.z1[i]))
	var center := Vector3((min_x + max_x) * 0.5, float(track.h0 + track.h1) * 0.5 / 16.0, (min_z + max_z) * 0.5)
	track_ribbon.position = Vector3(center.x, -center.y, -center.z)
	# Extra distance so the ribbon stays inside the frame while it spins,
	# including courses that are about as wide as they are long.
	var span := maxf(max_x - min_x, max_z - min_z) * 1.75
	track_camera.far = maxf(span * 4.0, 4000.0)
	track_camera.look_at_from_position(Vector3(0.0, span * 0.85, span * 0.72), Vector3.ZERO)


func ribbon_mesh(shown: int) -> ArrayMesh:
	var track: Dictionary = ribbon_track
	var tint: Array = ribbon_tint
	var base := Color8(int(tint[0]), int(tint[1]), int(tint[2]))
	var n: int = track.x0.size()
	var span := int(track.h1) - int(track.h0)
	if span == 0:
		span = 1
	# FUN_00061ab4 steps two nodes per quad and skips the first two quads
	# (s1 < 4), which leaves the start/finish open. A short custom loop has
	# no spare quads, so it draws from the first edge.
	var s1 := 4
	var prev := 3
	if n < 8:
		s1 = 1
		prev = 0
	if shown < s1 + 1:
		return ArrayMesh.new()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	while s1 < shown:
		var a1 := s1 + 1
		if a1 >= n:
			a1 -= n
		ribbon_quad(tool, track, base, span, ribbon_index(prev, n), ribbon_index(a1, n))
		prev = a1
		s1 += 2
	return tool.commit()


func ribbon_index(i: int, n: int) -> int:
	return n - 1 - i if ribbon_reverse else i


func ribbon_quad(tool: SurfaceTool, track: Dictionary, base: Color, span: int, i: int, j: int) -> void:
	var a := ribbon_vertex(track, base, span, i, false)
	var b := ribbon_vertex(track, base, span, i, true)
	var c := ribbon_vertex(track, base, span, j, false)
	var d := ribbon_vertex(track, base, span, j, true)
	tool.set_color(a[1])
	tool.add_vertex(a[0])
	tool.set_color(b[1])
	tool.add_vertex(b[0])
	tool.set_color(c[1])
	tool.add_vertex(c[0])
	tool.set_color(b[1])
	tool.add_vertex(b[0])
	tool.set_color(d[1])
	tool.add_vertex(d[0])
	tool.set_color(c[1])
	tool.add_vertex(c[0])


# Height is the node short, dropped by four and by the edge's lift byte.
# Shade runs from the height bounds: the first edge sits 0x20 brighter.
func ribbon_vertex(track: Dictionary, base: Color, span: int, i: int, second: bool) -> Array:
	var lift := int(track.a[i] if second else track.b[i])
	if lift > 128:
		lift -= 256
	var height: int = int(track.h[i])
	var y := float((height >> 4) - (lift >> 4))
	var shade := (height - lift - int(track.h0)) * 64 / span + (96 if second else 128)
	shade = clampi(shade, 0, 255)
	var x: float = track.x1[i] if second else track.x0[i]
	var z: float = track.z1[i] if second else track.z0[i]
	return [Vector3(-x, y, z), base * (shade / 255.0)]


func fit_car_stage(stage: Control) -> void:
	var parent_h := (stage.get_parent() as Control).size.y
	if parent_h < 2.0:
		return
	var top := HEADER_H + STAGE_GAP
	var bottom := parent_h - STAGE_FOOT - STAGE_GAP
	if bottom - top > STAGE_MAX_H:
		var slack := (bottom - top - STAGE_MAX_H) * 0.5
		top += slack
		bottom = top + STAGE_MAX_H
	stage.offset_top = top
	stage.offset_bottom = bottom - parent_h


func build_car(column: VBoxContainer) -> void:
	var shell: Control = column.get_meta("shell")
	car_stage = Control.new()
	car_stage.mouse_filter = Control.MOUSE_FILTER_STOP
	car_stage.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	shell.add_child(car_stage)
	car_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.resized.connect(fit_car_stage.bind(car_stage))
	fit_car_stage(car_stage)
	car_stage.resized.connect(layout_car)
	car_stage.draw.connect(draw_car_stage)

	car_header = VBoxContainer.new()
	car_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_header.add_theme_constant_override("separation", 4)
	car_stage.add_child(car_header)
	car_kicker = Label.new()
	car_kicker.text = "WASD"
	car_kicker.add_theme_font_size_override("font_size", 15)
	car_header.add_child(car_kicker)
	car_name = Label.new()
	car_name.clip_text = true
	car_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	car_name.add_theme_font_size_override("font_size", 40)
	car_name.text = "Player 1"
	car_header.add_child(car_name)
	car_accent = ColorRect.new()
	car_accent.custom_minimum_size = Vector2(0, 3)
	car_accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	car_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_header.add_child(car_accent)

	car_box = SubViewportContainer.new()
	car_box.stretch = true
	car_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car_stage.add_child(car_box)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.size = Vector2i(960, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	car_box.add_child(viewport)
	dress_stage(viewport)
	for child in viewport.get_children():
		if child is Camera3D:
			child.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			child.look_at_from_position(Vector3(1.7, 0.82, -1.9), Vector3(0.0, 0.38, 0.05))
	car_preview = spawn_model(viewport, race_model, 0.5)
	car_left = add_arrow(car_stage, "arrowLeft", cycle_race_car.bind(-1), false)
	car_right = add_arrow(car_stage, "arrowRight", cycle_race_car.bind(1), false)
	style_arrow(car_left)
	style_arrow(car_right)
	paint_race_car()
	add_nav(column, "Back", show_page.bind(main_page), false)
	add_nav(column, "Tracks", open_tracks.bind(false), true)


func layout_car() -> void:
	if car_stage == null:
		return
	var width := car_stage.size.x
	var height := car_stage.size.y
	if width < 2.0 or height < 2.0:
		return
	var metrics := car_metrics(width, height)
	var margin: float = metrics.margin
	var slant: float = metrics.slant
	var band: float = metrics.band
	var header_h := 72.0
	var header_span := row_span(0, 12.0, 12.0 + header_h, height, margin, slant, band)
	place_box(car_header, header_span.x, 12.0, header_span.y - header_span.x, header_h)
	var name_size := 40
	if header_span.y - header_span.x < 520.0:
		name_size = 32
	if header_span.y - header_span.x < 320.0:
		name_size = 24
	car_name.add_theme_font_size_override("font_size", name_size)
	var car_top := 12.0 + header_h + 6.0
	var car_bottom := height - 16.0
	var avail_h := maxf(car_bottom - car_top, 80.0)
	var center_y := (car_top + car_bottom) * 0.5
	var mid_shift := slant * (1.0 - center_y / height)
	var center_x := margin + band * 0.5 + mid_shift
	var view_h := minf(avail_h, 620.0)
	var view_w := minf(band * 0.55, view_h / 0.62)
	view_w = maxf(view_w, 280.0)
	var arrow_top := center_y - ARROW_H * 0.5
	var left_limit := margin + slant * (1.0 - arrow_top / height) + 4.0
	var right_limit := margin + band + slant * (1.0 - (arrow_top + ARROW_H) / height) - 4.0
	place_box(car_left, left_limit, arrow_top, ARROW_W, ARROW_H)
	place_box(car_right, right_limit - ARROW_W, arrow_top, ARROW_W, ARROW_H)
	place_box(car_box, center_x - view_w * 0.5, center_y - view_h * 0.5, view_w, view_h)
	car_box.stretch_shrink = 2 if view_w > 1100.0 else 1
	var aspect := view_w / view_h
	var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(CAR_VIEW)) * 1.5 / aspect))
	for child in (car_box.get_child(0) as SubViewport).get_children():
		if child is Camera3D:
			child.fov = fov
	car_stage.queue_redraw()


func draw_car_stage() -> void:
	if car_preview == null:
		return
	draw_slant_stage(car_stage, [car_preview.color], car_metrics(car_stage.size.x, car_stage.size.y))


func car_metrics(width: float, height: float) -> Dictionary:
	var metrics := stage_metrics(width, height, 1)
	var band: float = metrics.band
	var narrow := band * CAR_BAND
	return {
		"margin": metrics.margin + (band - narrow) * 0.5,
		"slant": metrics.slant,
		"band": narrow,
	}


func build_player_card(player: int) -> Control:
	var column := Control.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var header := VBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)
	card_headers.append(header)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	header.add_child(title_row)
	var id_col := VBoxContainer.new()
	id_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_col.add_theme_constant_override("separation", 0)
	title_row.add_child(id_col)
	var kicker := Label.new()
	kicker.add_theme_font_size_override("font_size", 15)
	kicker.custom_minimum_size = Vector2(0, 18)
	kicker.text = PLAYER_KEYS[player]
	id_col.add_child(kicker)
	card_titles.append(kicker)
	var name_label := Label.new()
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.text = "Player %d" % (player + 1)
	id_col.add_child(name_label)
	car_labels.append(name_label)
	var score := VBoxContainer.new()
	score.custom_minimum_size = Vector2(68, 0)
	score.add_theme_constant_override("separation", 0)
	title_row.add_child(score)
	var wins_caption := Label.new()
	wins_caption.text = "WINS"
	wins_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wins_caption.add_theme_font_size_override("font_size", 13)
	wins_caption.add_theme_color_override("font_color", UiTheme.CREAM)
	score.add_child(wins_caption)
	var wins_num := Label.new()
	wins_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wins_num.add_theme_font_size_override("font_size", 28)
	wins_num.text = str(Battle.wins[player])
	score.add_child(wins_num)
	win_labels.append(wins_num)
	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 3)
	accent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(accent)
	accent_bars.append(accent)

	var box := SubViewportContainer.new()
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(box)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.size = Vector2i(640, 360)
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	box.add_child(viewport)
	stage_car(viewport, player)
	preview_boxes.append(box)
	var left_arrow := add_arrow(column, "arrowLeft", cycle_car.bind(player, -1), false)
	var right_arrow := add_arrow(column, "arrowRight", cycle_car.bind(player, 1), false)
	style_arrow(left_arrow)
	style_arrow(right_arrow)
	left_arrows.append(left_arrow)
	right_arrows.append(right_arrow)
	var controls := HBoxContainer.new()
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	column.add_child(controls)
	card_controls.append(controls)

	var pad := Button.new()
	pad.clip_text = true
	pad.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pad.custom_minimum_size = Vector2(0, 42)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pad.add_theme_font_size_override("font_size", 18)
	pad.pressed.connect(arm_pad.bind(player))
	UiTheme.hook_button(pad)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var fill := UiTheme.ACCENT
		var lip := UiTheme.LIP
		if state != "normal" and state != "disabled":
			fill = UiTheme.CREAM
			lip = UiTheme.CORAL
		if state == "disabled":
			fill = Color(0.32, 0.08, 0.16, 0.55)
			lip = Color(0.2, 0.04, 0.1, 0.4)
		var style := UiTheme.button_style(fill, lip)
		style.content_margin_left = 14
		style.content_margin_right = 14
		pad.add_theme_stylebox_override(state, style)
	controls.add_child(pad)
	pad_buttons.append(pad)
	refresh_pad(player)
	var expert := CheckBox.new()
	expert.text = "Expert"
	expert.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	expert.add_theme_font_size_override("font_size", 16)
	expert.button_pressed = Battle.experts[player] == 1
	expert.toggled.connect(func(on: bool) -> void: Battle.experts[player] = 1 if on else 0)
	controls.add_child(expert)
	cards.append(column)
	paint_player(player)
	return column


func style_arrow(button: Button) -> void:
	button.custom_minimum_size = Vector2(ARROW_W, ARROW_H)
	button.add_theme_constant_override("icon_max_width", 22)
	button.add_theme_constant_override("icon_max_height", 22)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var fill := UiTheme.ACCENT
		var lip := UiTheme.LIP
		if state != "normal" and state != "disabled":
			fill = UiTheme.CREAM
			lip = UiTheme.CORAL
		if state == "disabled":
			fill = Color(0.32, 0.08, 0.16, 0.55)
			lip = Color(0.2, 0.04, 0.1, 0.4)
		var style := UiTheme.button_style(fill, lip)
		style.content_margin_left = 2
		style.content_margin_right = 2
		style.content_margin_top = 0
		style.content_margin_bottom = 0
		style.border_width_bottom = 3
		style.shadow_size = 0 if state == "focus" else 2
		button.add_theme_stylebox_override(state, style)


func place_box(control: Control, x: float, y: float, w: float, h: float) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = x
	control.offset_top = y
	control.offset_right = x + w
	control.offset_bottom = y + h


func stage_metrics(width: float, height: float, count: int) -> Dictionary:
	var margin := 40.0
	var slant := height * 0.26
	var band := (width - margin * 2.0 - slant) / float(count)
	if band < 150.0:
		slant = maxf(48.0, width * 0.12)
		margin = 24.0
		band = (width - margin * 2.0 - slant) / float(count)
	return {"margin": margin, "slant": slant, "band": band}


func row_span(index: int, y0: float, y1: float, height: float, margin: float, slant: float, band: float) -> Vector2:
	var gutter := 12.0
	var left := margin + band * float(index) + slant * (1.0 - y0 / height) + gutter
	var right := margin + band * float(index + 1) + slant * (1.0 - y1 / height) - gutter
	return Vector2(left, right)


func layout_players() -> void:
	if player_stage == null or pad_buttons.is_empty():
		return
	wire_player_focus()
	var width := player_stage.size.x
	var height := player_stage.size.y
	if width < 2.0 or height < 2.0:
		return
	var count := battle_players
	var metrics := stage_metrics(width, height, count)
	var margin: float = metrics.margin
	var slant: float = metrics.slant
	var band: float = metrics.band
	for i in cards.size():
		var card := cards[i]
		card.visible = i < count
		if i >= count:
			continue
		place_box(card, 0.0, 0.0, width, height)
		var header_h := 72.0
		var header_span := row_span(i, 12.0, 12.0 + header_h, height, margin, slant, band)
		place_box(card_headers[i], header_span.x, 12.0, header_span.y - header_span.x, header_h)
		var controls_h := 52.0
		var controls_top := height - controls_h - 10.0
		var controls_span := row_span(i, controls_top, height - 8.0, height, margin, slant, band)
		place_box(card_controls[i], controls_span.x, controls_top, controls_span.y - controls_span.x, controls_h)
		var car_top := 12.0 + header_h + 6.0
		var car_bottom := controls_top - 8.0
		var avail_h := maxf(car_bottom - car_top, 80.0)
		var center_y := (car_top + car_bottom) * 0.5
		var arrow_top := center_y - ARROW_H * 0.5
		var left_limit := margin + band * float(i) + slant * (1.0 - arrow_top / height) + 4.0
		var right_limit := margin + band * float(i + 1) + slant * (1.0 - (arrow_top + ARROW_H) / height) - 4.0
		place_box(left_arrows[i], left_limit, arrow_top, ARROW_W, ARROW_H)
		place_box(right_arrows[i], right_limit - ARROW_W, arrow_top, ARROW_W, ARROW_H)
		var gap := 6.0
		var view_w := maxf(right_limit - left_limit - ARROW_W * 2.0 - gap * 2.0, 64.0)
		var view_h := minf(avail_h, view_w * 0.78)
		var center_x := (left_limit + right_limit) * 0.5
		place_box(preview_boxes[i], center_x - view_w * 0.5, center_y - view_h * 0.5, view_w, view_h)
		preview_boxes[i].stretch_shrink = 2 if view_w > 1100.0 else 1
		var aspect := view_w / view_h
		var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(CAR_VIEW)) * 1.5 / aspect))
		for child in (preview_boxes[i].get_child(0) as SubViewport).get_children():
			if child is Camera3D:
				child.fov = fov
		var pad_size := 18
		if controls_span.y - controls_span.x < 240.0:
			pad_size = 15
		if controls_span.y - controls_span.x < 190.0:
			pad_size = 14
		pad_buttons[i].add_theme_font_size_override("font_size", pad_size)
		var name_size := 34
		if header_span.y - header_span.x < 420.0:
			name_size = 26
		if header_span.y - header_span.x < 260.0:
			name_size = 20
		car_labels[i].add_theme_font_size_override("font_size", name_size)
		win_labels[i].add_theme_font_size_override("font_size", 22 if name_size < 26 else 28)
	player_stage.queue_redraw()


func draw_player_stage() -> void:
	if player_stage.size.x < 2.0 or player_stage.size.y < 2.0 or previews.is_empty():
		return
	var colors: Array[Color] = []
	for i in battle_players:
		colors.append(previews[i].color)
	draw_slant_stage(player_stage, colors)


func draw_slant_stage(canvas: Control, colors: Array, metrics: Dictionary = {}) -> void:
	var width := canvas.size.x
	var height := canvas.size.y
	if width < 2.0 or height < 2.0 or colors.is_empty():
		return
	var count := colors.size()
	if metrics.is_empty():
		metrics = stage_metrics(width, height, count)
	var margin: float = metrics.margin
	var slant: float = metrics.slant
	var band: float = metrics.band
	var ink := Color(0.05, 0.008, 0.02)
	var gray := Color(0.0, 0.0, 0.0, 0.68)
	var span := band * float(count)
	canvas.draw_polygon(PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(margin + slant, 0.0),
		Vector2(margin, height),
		Vector2(0.0, height),
	]), PackedColorArray([gray, gray, gray, gray]))
	canvas.draw_polygon(PackedVector2Array([
		Vector2(margin + span + slant, 0.0),
		Vector2(width, 0.0),
		Vector2(width, height),
		Vector2(margin + span, height),
	]), PackedColorArray([gray, gray, gray, gray]))
	for i in count:
		var color: Color = colors[i]
		var left := margin + band * float(i)
		var right := margin + band * float(i + 1)
		var top := color.lerp(ink, 0.34)
		top.a = 0.95
		var bottom := color.lerp(ink, 0.8)
		bottom.a = 0.97
		var overlap := 1.5
		canvas.draw_polygon(PackedVector2Array([
			Vector2(left + slant, 0.0),
			Vector2(right + slant + overlap, 0.0),
			Vector2(right + overlap, height),
			Vector2(left, height),
		]), PackedColorArray([top, top, bottom, bottom]))
		var sheen := height * 0.42
		var sheen_shift := slant * (1.0 - sheen / height)
		canvas.draw_polygon(PackedVector2Array([
			Vector2(left + slant, 0.0),
			Vector2(right + slant + overlap, 0.0),
			Vector2(right + sheen_shift + overlap, sheen),
			Vector2(left + sheen_shift, sheen),
		]), PackedColorArray([
			Color(1, 1, 1, 0.16),
			Color(1, 1, 1, 0.1),
			Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 0.0),
		]))
		var header := height * 0.2
		var header_shift := slant * (1.0 - header / height)
		canvas.draw_polygon(PackedVector2Array([
			Vector2(left + slant, 0.0),
			Vector2(right + slant + overlap, 0.0),
			Vector2(right + header_shift + overlap, header),
			Vector2(left + header_shift, header),
		]), PackedColorArray([
			Color(0, 0, 0, 0.34),
			Color(0, 0, 0, 0.34),
			Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.0),
		]))
		var foot := height * 0.62
		var foot_shift := slant * (1.0 - foot / height)
		canvas.draw_polygon(PackedVector2Array([
			Vector2(left + foot_shift, foot),
			Vector2(right + foot_shift + overlap, foot),
			Vector2(right + overlap, height),
			Vector2(left, height),
		]), PackedColorArray([
			Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.48),
			Color(0, 0, 0, 0.48),
		]))
		var crown := color.lerp(Color.WHITE, 0.62)
		crown.a = 0.95
		canvas.draw_line(Vector2(left + slant, 2.0), Vector2(right + slant, 2.0), crown, 3.0, true)
	var edge := Color(1, 1, 1, 0.72)
	for i in count + 1:
		var x := margin + band * float(i)
		canvas.draw_line(Vector2(x + slant, 0.0), Vector2(x, height), edge, 2.0, true)
	var base := height - 3.0
	canvas.draw_line(Vector2(margin, base), Vector2(margin + span, base), edge, 2.0, true)


func dress_stage(viewport: SubViewport) -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.65, 0.7)
	environment.ambient_light_energy = 1.0
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	viewport.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, -140, 0)
	fill.light_energy = 0.45
	viewport.add_child(fill)
	var spot_mesh := PlaneMesh.new()
	spot_mesh.size = Vector2(2.2, 2.2)
	var spot_shader := Shader.new()
	spot_shader.code = "shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;
uniform vec3 spot_color : source_color = vec3(1.0);
void fragment() {
	float d = length(UV * 2.0 - 1.0);
	float light = clamp(1.0 - d, 0.0, 1.0);
	light *= light;
	ALBEDO = spot_color;
	ALPHA = light * 0.82;
}"
	var spot_material := ShaderMaterial.new()
	spot_material.shader = spot_shader
	var spot := MeshInstance3D.new()
	spot.name = "spot"
	spot.mesh = spot_mesh
	spot.material_override = spot_material
	spot.position.y = -0.02
	viewport.add_child(spot)
	var camera := Camera3D.new()
	camera.fov = 38.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(1.7, 0.9, -1.85), Vector3(0, 0.4, 0))


func stage_car(viewport: SubViewport, player: int) -> void:
	dress_stage(viewport)
	for child in viewport.get_children():
		if child is Camera3D:
			child.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			child.fov = 32.0
			child.look_at_from_position(Vector3(1.7, 0.82, -1.9), Vector3(0.0, 0.38, 0.05))
	previews.append(spawn_preview(viewport, player, 0.5))


func spawn_preview(viewport: SubViewport, player: int, yaw: float) -> Car:
	return spawn_model(viewport, Battle.models[player], yaw)


func spawn_model(viewport: SubViewport, model: int, yaw: float) -> Car:
	var car := Car.new()
	car.model = model
	car.load_info()
	car.frozen = true
	car.rotation.y = yaw
	viewport.add_child(car)
	car.set_physics_process(false)
	var spot := viewport.get_node("spot") as MeshInstance3D
	(spot.material_override as ShaderMaterial).set_shader_parameter("spot_color", car.color)
	return car


func paint_player(player: int) -> void:
	var color := previews[player].color
	card_titles[player].add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	car_labels[player].add_theme_color_override("font_color", color.lerp(UiTheme.CREAM, 0.72))
	win_labels[player].add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.25))
	accent_bars[player].color = color.lerp(Color.WHITE, 0.2)
	if player_stage:
		player_stage.queue_redraw()


func cycle_car(player: int, direction: int) -> void:
	var model := Battle.models[player]
	for _step in Car.CAR_MODELS - 1:
		model = wrapi(model + direction, 0, Car.CAR_MODELS)
		if not model_taken(model, player):
			break
	if model == Battle.models[player]:
		return
	Sound.ui()
	Battle.models[player] = model
	show_model(player)


func show_model(player: int) -> void:
	UiTheme.punch(preview_boxes[player])
	var viewport := previews[player].get_parent() as SubViewport
	var yaw := previews[player].rotation.y
	previews[player].free()
	previews[player] = spawn_preview(viewport, player, yaw)
	paint_player(player)


func settle_models() -> void:
	var used: Array[int] = []
	for i in battle_players:
		var model := int(Battle.models[i])
		if used.has(model):
			for _step in Car.CAR_MODELS:
				model = wrapi(model + 1, 0, Car.CAR_MODELS)
				if not used.has(model):
					break
			Battle.models[i] = model
			show_model(i)
		used.append(int(Battle.models[i]))


func model_taken(model: int, player: int) -> bool:
	for i in battle_players:
		if i != player and Battle.models[i] == model:
			return true
	return false


func cycle_race_car(direction: int) -> void:
	Sound.ui()
	race_model = wrapi(race_model + direction, 0, Car.CAR_MODELS)
	var viewport := car_preview.get_parent() as SubViewport
	var yaw := car_preview.rotation.y
	car_preview.free()
	car_preview = spawn_model(viewport, race_model, yaw)
	paint_race_car()
	UiTheme.punch(car_box)


func paint_race_car() -> void:
	var color := car_preview.color
	car_kicker.add_theme_color_override("font_color", color.lerp(Color.WHITE, 0.35))
	car_name.add_theme_color_override("font_color", color.lerp(UiTheme.CREAM, 0.72))
	car_accent.color = color.lerp(Color.WHITE, 0.2)
	if car_stage:
		car_stage.queue_redraw()


func arm_pad(player: int) -> void:
	assigning = -1 if assigning == player else player
	refresh_pads()


func assign_pad(player: int, device: int) -> void:
	for i in Battle.devices.size():
		if i != player and Battle.devices[i] == device:
			Battle.devices[i] = -1
	Battle.devices[player] = device
	assigning = -1
	refresh_pads()
	Session.rebind_pads()


func refresh_pads() -> void:
	for i in pad_buttons.size():
		refresh_pad(i)


func refresh_pad(player: int) -> void:
	var button := pad_buttons[player]
	if assigning == player:
		button.text = "Press a button..."
		return
	var device: int = Battle.devices[player]
	if device < 0:
		button.text = "Assign pad"
		return
	var joy_name := Input.get_joy_name(device)
	button.text = "Pad %d" % (device + 1) if joy_name.is_empty() else joy_name


func any_pad_vertical() -> int:
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
			return -1
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
			return 1
		var axis := Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		if axis < -0.5:
			return -1
		if axis > 0.5:
			return 1
	return 0


func any_pad_direction() -> int:
	for device in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
			return -1
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
			return 1
		var axis := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if axis < -0.5:
			return -1
		if axis > 0.5:
			return 1
	return 0


func pad_direction(player: int) -> int:
	var device: int = Battle.devices[player]
	if device < 0:
		return 0
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
		return -1
	if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
		return 1
	var axis := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
	if axis < -0.5:
		return -1
	if axis > 0.5:
		return 1
	return 0


func show_players() -> void:
	var appeared: Array[int] = []
	for i in cards.size():
		var show := i < battle_players
		if show and not cards[i].visible:
			appeared.append(i)
	layout_players()
	for i in appeared:
		UiTheme.punch(car_labels[i])
	update_wins()


func add_setting(row: HBoxContainer, title: String, control: Control) -> void:
	if not title.is_empty():
		var label := Label.new()
		label.text = title
		label.add_theme_font_size_override("font_size", 20)
		row.add_child(label)
	control.add_theme_font_size_override("font_size", 20)
	if control is SpinBox:
		control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, 76.0), 40)
	row.add_child(control)


func update_wins() -> void:
	for i in win_labels.size():
		win_labels[i].text = str(Battle.wins[i])


func refresh_track_wins() -> void:
	var count := 0
	if track_for_online:
		count = Net.peers.size()
	elif track_for_battle:
		count = battle_players
	fill_win_row(track_wins, count, track_for_online)


func fill_win_row(row: HBoxContainer, count: int, online: bool) -> void:
	while row.get_child_count() > 0:
		row.get_child(0).free()
	row.visible = count > 0
	for i in count:
		var model := int(Net.peers[i].model) if online else Battle.models[i]
		var color := Car.model_color(model)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(box)
		var title := Label.new()
		title.text = "WINS"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", color)
		box.add_child(title)
		var number := Label.new()
		number.text = str(Battle.wins[i])
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 40)
		number.add_theme_color_override("font_color", color)
		box.add_child(number)


func start_battle(path: String) -> void:
	Session.time_trial = false
	Battle.players = battle_players
	Session.rebind_pads()
	Sound.depart(func() -> void: Session.launch(path))


func _unhandled_input(event: InputEvent) -> void:
	if setup_dialog != null and setup_dialog.visible:
		if event.is_action_pressed("ui_cancel"):
			setup_dialog.hide()
			get_viewport().set_input_as_handled()
		return
	if quit_ask.visible and event.is_action_pressed("ui_cancel"):
		close_quit_ask()
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel") or page == main_page:
		return
	Sound.ui()
	if page == setup_page:
		if setup_return != null and setup_job == null:
			show_page(setup_return)
		elif setup_return == null and setup_job == null:
			prompt_quit()
	elif page == mode_page:
		show_page(track_page)
	elif page == track_page:
		leave_tracks()
	elif page == online_page:
		leave_online()
	elif page == credits_page:
		show_page(options_page)
	else:
		show_page(main_page)
	get_viewport().set_input_as_handled()


func add_page(parent: Control, title: String, size: int, _framed := true) -> VBoxContainer:
	var shell := Control.new()
	shell.visible = false
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(shell)
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := VBoxContainer.new()
	shell.add_child(outer)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.offset_left = 48.0
	outer.offset_top = HEADER_H + 8.0
	outer.offset_right = -48.0
	outer.offset_bottom = -32.0
	outer.add_theme_constant_override("separation", 16)
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	column.set_meta("shell", shell)
	outer.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_font_size_override("font_size", size)
	heading.add_theme_constant_override("outline_size", 0)
	heading.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	heading.add_theme_color_override("font_color", UiTheme.TEXT_COLOR)
	heading.visible = false
	heading.modulate.a = 0.0
	header_chrome.add_child(heading)
	heading.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	heading.offset_left = 48.0
	heading.offset_top = 0.0
	heading.offset_right = -48.0
	heading.offset_bottom = HEADER_H - 2.0
	heading.set_meta("rest_left", heading.offset_left)
	heading.set_meta("rest_right", heading.offset_right)
	heading.set_meta("header_from", -1.0)
	heading.set_meta("header_mouse", heading.mouse_filter)
	column.set_meta("heading", heading)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	outer.add_child(footer)
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 12)
	footer.add_child(left)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(spacer)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	footer.add_child(right)
	column.set_meta("footer_left", left)
	column.set_meta("footer_right", right)
	return column


func page_stack(page: VBoxContainer) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	stack.add_theme_constant_override("separation", 18)
	page.add_child(stack)
	return stack


func add_nav(page: VBoxContainer, text: String, action: Callable, forward: bool) -> Button:
	var side: HBoxContainer = page.get_meta("footer_right" if forward else "footer_left")
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 72)
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(func() -> void:
		Sound.ui()
		action.call()
	)
	UiTheme.hook_button(button)
	side.add_child(button)
	return button


func add_arrow(parent: Node, icon_name: String, action: Callable, tall: bool) -> Button:
	var button := Button.new()
	button.icon = menu_icon(icon_name)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var icon_size := 56 if tall else 32
	button.add_theme_constant_override("icon_max_width", icon_size)
	button.add_theme_constant_override("icon_max_height", icon_size)
	button.custom_minimum_size = Vector2(96, 148) if tall else Vector2(72, 56)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.set_meta("arrow", true)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	UiTheme.hook_button(button)
	parent.add_child(button)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var style := button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 8
		style.content_margin_bottom = 6
		button.add_theme_stylebox_override(state, style)
	return button


func add_button(column: VBoxContainer, text: String, action: Callable, icon_name: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH, 72.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 26)
	if icon_name != "":
		apply_menu_icon(button, icon_name)
	button.pressed.connect(func() -> void:
		Sound.ui()
		action.call()
	)
	UiTheme.hook_button(button)
	column.add_child(button)
	return button


func apply_menu_icon(button: Button, icon_name: String) -> void:
	button.icon = menu_icon(icon_name)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 36)
	button.add_theme_constant_override("icon_max_height", 36)
	button.add_theme_constant_override("h_separation", 14)


func menu_icon(icon_name: String) -> Texture2D:
	return load("res://icons/%s.png" % icon_name)


func build_options(column: VBoxContainer) -> void:
	options_frame = PanelContainer.new()
	options_frame.add_theme_stylebox_override("panel", UiTheme.shell_style())
	options_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	options_frame.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
	column.add_child(options_frame)
	options_scroll = UiTheme.options_scroll(options_frame)
	var stack := UiTheme.options_stack(options_scroll)
	options_focus = UiTheme.fill_options(stack)
	add_gap(stack, 14.0)
	add_button(stack, "Setup", func() -> void: open_setup(options_page))
	add_button(stack, "Credits", show_page.bind(credits_page))
	add_gap(stack, 0.0)
	add_nav(column, "Back", show_page.bind(main_page), false)


func build_credits(column: VBoxContainer) -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiTheme.shell_style())
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.custom_minimum_size = Vector2(CREDITS_W, 0)
	add_gap(column, CREDITS_MARGIN)
	column.add_child(frame)
	add_gap(column, CREDITS_MARGIN)
	credits_scroll = ScrollContainer.new()
	credits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(credits_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 28)
	credits_scroll.add_child(margin)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	credits_text(body, "OpenCircuitBreakers", 56, UiTheme.TEXT_COLOR)
	credits_text(body, "A fan-made port of Circuit Breakers", 22, UiTheme.CREAM)
	credits_rule(body, 220.0)
	for section: Dictionary in CREDITS:
		add_gap(body, 30.0)
		credits_text(body, String(section.title).to_upper(), 18, UiTheme.CORAL)
		for credit: String in section.names:
			credits_text(body, credit, 32, UiTheme.TEXT_COLOR)
		if String(section.text) != "":
			credits_text(body, section.text, 19, Color(UiTheme.TEXT_COLOR, 0.78))
		if String(section.prompt) != "":
			add_gap(body, 6.0)
			credits_text(body, section.prompt, 19, Color(UiTheme.TEXT_COLOR, 0.78))
		if String(section.link) != "":
			credits_link(body, section.link)
	add_gap(body, 40.0)
	credits_rule(body, 120.0)
	add_gap(body, 12.0)
	credits_text(body, "GODOT ENGINE LICENSE", 15, UiTheme.CORAL)
	credits_text(body, Engine.get_license_text(), 14, Color(UiTheme.TEXT_COLOR, 0.55))
	add_gap(body, 40.0)
	credits_text(body, "Thanks for playing!", 28, UiTheme.CREAM)
	add_nav(column, "Back", show_page.bind(options_page), false)


func credits_text(body: VBoxContainer, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	body.add_child(label)


func credits_rule(body: VBoxContainer, width: float) -> void:
	var rule := ColorRect.new()
	rule.color = UiTheme.ACCENT
	rule.custom_minimum_size = Vector2(width, 4.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(rule)


func credits_link(body: VBoxContainer, address: String) -> void:
	var link := LinkButton.new()
	link.text = address
	link.uri = "https://" + address
	link.focus_mode = Control.FOCUS_NONE
	link.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	link.add_theme_font_size_override("font_size", 20)
	link.add_theme_color_override("font_color", UiTheme.CREAM)
	link.add_theme_color_override("font_hover_color", UiTheme.TEXT_COLOR)
	link.add_theme_color_override("font_pressed_color", UiTheme.ACCENT)
	body.add_child(link)


func add_gap(body: VBoxContainer, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, height)
	body.add_child(gap)


func show_page(next: VBoxContainer) -> void:
	if next == main_page or next == car_page:
		Battle.wins.fill(0)
	if next == multiplayer_page:
		update_wins()
		layout_players()
	if next == car_page:
		layout_car()
	if next == credits_page:
		credits_scroll.scroll_vertical = 0
	if page == next:
		focus_page(next)
		return
	var previous := page
	page = next
	queue_redraw()
	var shell: Control = next.get_meta("shell")
	if previous:
		UiTheme.animate_out(previous.get_meta("shell"))
	shell.move_to_front()
	header_chrome.move_to_front()
	UiTheme.animate_in(shell, next)
	present_header(next, previous)
	focus_page(next)


func link_page(page: VBoxContainer) -> void:
	var into: Array[Control] = []
	gather_focus(page.get_meta("shell"), into)
	link_vertical(into)


func wire_player_focus() -> void:
	var column: Array[Control] = []
	gather_focus(player_stage, column)
	var footer: Array[Control] = []
	gather_focus(multiplayer_page.get_meta("footer_left"), footer)
	gather_focus(multiplayer_page.get_meta("footer_right"), footer)
	column.append_array(footer)
	link_vertical(column)
	var header: Array[Control] = []
	gather_focus(header_settings, header)
	if header.size() > 0 and column.size() > 0:
		var below: NodePath = column[0].get_path()
		var above: NodePath = column[column.size() - 1].get_path()
		for control in header:
			control.focus_neighbor_top = above
			control.focus_neighbor_bottom = below
		column[0].focus_neighbor_top = header[0].get_path()
	link_horizontal(header)
	link_horizontal(footer)
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and not owner.is_visible_in_tree():
		var pad := first_visible_button(player_stage)
		if pad:
			pad.grab_focus()


func gather_focus(node: Node, into: Array[Control]) -> void:
	for child in node.get_children():
		if not child is Control:
			continue
		var control := child as Control
		if not focus_shown(control):
			continue
		if control is BaseButton and (control as BaseButton).disabled:
			continue
		var take := control.focus_mode != Control.FOCUS_NONE and (control is BaseButton or control is SpinBox or control is LineEdit or control is HSlider)
		if take:
			into.append(control)
			if control is SpinBox or control is OptionButton:
				continue
		gather_focus(control, into)


func focus_shown(control: Control) -> bool:
	var here: Node = control
	while here is Control:
		var item := here as Control
		if item == header_chrome or item.get_parent() == self:
			return true
		if not item.visible:
			return false
		here = item.get_parent()
	return true


func link_vertical(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for i in controls.size():
		var current := controls[i]
		var above := controls[controls.size() - 1] if i == 0 else controls[i - 1]
		var below := controls[0] if i + 1 == controls.size() else controls[i + 1]
		current.focus_neighbor_top = above.get_path()
		current.focus_neighbor_bottom = below.get_path()
		current.focus_neighbor_left = current.get_path()
		current.focus_neighbor_right = current.get_path()


func link_horizontal(controls: Array[Control]) -> void:
	if controls.is_empty():
		return
	for i in controls.size():
		var current := controls[i]
		var left := controls[controls.size() - 1] if i == 0 else controls[i - 1]
		var right := controls[0] if i + 1 == controls.size() else controls[i + 1]
		current.focus_neighbor_left = left.get_path()
		current.focus_neighbor_right = right.get_path()


func focus_setup_dialog() -> void:
	var list := find_item_list(setup_dialog)
	if list:
		list.grab_focus()


func find_item_list(node: Node) -> ItemList:
	if node is ItemList:
		return node
	for child in node.get_children():
		var found := find_item_list(child)
		if found:
			return found
	return null


func focus_page(next: VBoxContainer) -> void:
	if next == options_page:
		link_page(next)
		options_focus.grab_focus()
		return
	if next == online_page:
		refresh_online()
		return
	if next == track_page:
		track_start.grab_focus()
		return
	if next == multiplayer_page and player_stage != null:
		wire_player_focus()
		var pad := first_visible_button(player_stage)
		if pad:
			pad.grab_focus()
			return
	if next != multiplayer_page:
		link_page(next)
	var button := first_visible_button(next)
	if button == null:
		button = first_visible_button(next.get_meta("footer_right"))
	if button == null:
		button = first_visible_button(next.get_meta("footer_left"))
	if button:
		button.grab_focus()


func first_visible_button(node: Node) -> Button:
	for child in node.get_children():
		if child is CanvasItem and not (child as CanvasItem).is_visible_in_tree():
			continue
		if child is Button and not child.disabled and not child.has_meta("arrow"):
			return child
		var found := first_visible_button(child)
		if found:
			return found
	return null


func start_race(path: String) -> void:
	Session.time_trial = false
	Battle.players = 0
	Sound.depart(func() -> void: Session.launch(path))
