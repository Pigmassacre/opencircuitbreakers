@tool
class_name Session
extends Node3D

const SCENE := "res://scenes/track.tscn"
const EDITOR_TRACK := "user://editor_track_dir"
const WORLDS := ["wild_west", "grand_prix", "venice", "swamp", "jungle", "persia", "aqua", "snow", "castle", "rooftop"]
const GRID := 8
const FAR_FOG_DENSITY := 0.003
const FAR_CLIP := 4000.0
const PAUSE_MARGIN := 32.0
static var queued_dir := ""
static var queued_source := ""
static var queued_compile := ""
# FUN_0006ad00 fills the mode corridor with World Series and Time Trial for one
# player, and Battle and Time Trial when more than one is waiting. Time trial
# (a7138 == 2, or 4 with several players) sets DAT_000a6780 and drops the AI field.
static var time_trial := false
static var trial_turn := 0
static var trial_models := PackedInt32Array()
static var trial_controls := PackedStringArray()
static var ghost_model := -1
static var editor_return := ""

@export var track_dir := "":
	set(value):
		track_dir = value
		if not Engine.is_editor_hint():
			return
		var file := FileAccess.open(EDITOR_TRACK, FileAccess.WRITE)
		file.store_string(value)
		if is_node_ready():
			show_in_editor()

var player: Car
var camera: Camera3D
var environment: Environment
var track: Track
var race: Race
var battle: Battle
var pause_menu: Control
var pause_options: Control
var pause_options_focus: Control
var pause_scroll: ScrollContainer
var pause_dim: ColorRect
var pause_shell: PanelContainer
var pause_column: VBoxContainer
var resume: Button
var pause_ask: Control
var pause_ask_title: Label
var pause_ask_body: Label
var pause_ask_yes: Button
var pause_ask_cancel: Button
var pause_ask_action: Callable
var pause_ask_return: Control
var race_hold := 0.0
var race_returning := false
var best_noted := false
var trial_any_best := false
var trial_best_index := -1
var rematch: Control
var rematch_dim: ColorRect
var rematch_shell: PanelContainer
var rematch_column: VBoxContainer
var rematch_yes := true
var rematch_yes_button: Button
var rematch_no_button: Button
var rematch_scores: Array[Label] = []


static func queue_course(source: String, dir: String) -> void:
	queued_source = source
	queued_compile = dir


static func play(dir: String) -> void:
	var source := queued_source
	var compile_dir := queued_compile
	queued_source = ""
	queued_compile = ""
	if source != "" and compile_dir == dir:
		play_course(source, dir)
		return
	queued_dir = dir
	Wipe.to(SCENE)


static func launch(path: String) -> void:
	if path.ends_with(".json"):
		play_course(path, LevelBuild.course_dir(path))
		return
	play(path)


static func play_course(path: String, dir: String) -> void:
	Wipe.to(SCENE, func() -> void:
		Session.queued_dir = LevelBuild.compile(LevelBuild.load_level(path), dir)
	)


static func play_level(level: Dictionary, dir: String) -> void:
	Wipe.to(SCENE, func() -> void:
		Session.queued_dir = LevelBuild.compile(level, dir)
	)


static func directory(world: String, number: int, reverse: bool) -> String:
	var prefix := world
	if world == "wild_west":
		prefix = "wwest"
	elif world == "grand_prix":
		prefix = "gprix"
	return "res://tracks/%s%d%s" % [prefix, number, "r" if reverse else ""]


static func directory_for_scene(path: String) -> String:
	var base := path.get_file().get_basename()
	var reverse := base.ends_with("_reverse")
	if reverse:
		base = base.trim_suffix("_reverse")
	var split := base.rsplit("_", true, 1)
	return directory(split[0], int(split[1]), reverse)


static func describe(dir: String) -> Dictionary:
	var file := dir.get_file()
	var reverse := file.ends_with("r")
	if reverse:
		file = file.left(file.length() - 1)
	var stem := file.left(file.length() - 1)
	var world := stem
	if stem == "wwest":
		world = "wild_west"
	elif stem == "gprix":
		world = "grand_prix"
	return {"world": world, "number": int(file.right(1)), "reverse": reverse}


static func remembered_track() -> String:
	if not FileAccess.file_exists(EDITOR_TRACK):
		return ""
	return FileAccess.get_file_as_string(EDITOR_TRACK).strip_edges()


static func title(dir: String) -> String:
	if dir.begins_with("user://"):
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/track.json"))
		return String(info.name)
	var names: Dictionary = JSON.parse_string(Data.text("res://tracks/names.json"))
	var text: String = names[dir]
	if describe(dir).reverse:
		text += " Reverse"
	return text


func _validate_property(property: Dictionary) -> void:
	if property.name != "track_dir":
		return
	property.usage &= ~PROPERTY_USAGE_STORAGE
	property.usage |= PROPERTY_USAGE_NO_INSTANCE_STATE


func _ready() -> void:
	if Engine.is_editor_hint():
		if track_dir.is_empty():
			var remembered := remembered_track()
			if remembered != "":
				track_dir = remembered
				return
		show_in_editor()
		return
	Sound.race_audio = true
	if queued_dir != "":
		track_dir = queued_dir
		queued_dir = ""
	elif track_dir.is_empty():
		track_dir = remembered_track()
	setup_input()
	build_track()
	build_hud()
	for child in get_children():
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = 1
	build_pause_menu()
	build_rematch()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if get_tree().paused:
		return
	if Net.puppet():
		if Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME == 0:
			Net.publish_input()
		return
	if Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME != 0:
		return
	if Net.is_host():
		Net.publish_state()
	player.release_bumps()


func _input(event: InputEvent) -> void:
	if not event.is_action("ui_accept"):
		return
	if rematch.visible or not get_tree().paused:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if rematch.visible or not event.is_action_pressed("ui_cancel"):
		return
	if not get_tree().paused:
		return
	if pause_ask.visible:
		close_pause_ask()
	elif pause_options.visible:
		close_pause_options()
	else:
		set_paused(false)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	apply_fog(get_viewport().get_camera_3d())
	if pause_options.visible:
		UiTheme.fit_scroll(pause_scroll, pause_options, get_viewport().get_visible_rect().size.y - PAUSE_MARGIN * 2.0)
	if rematch.visible:
		poll_rematch()
		return
	if Input.is_action_just_pressed("pause"):
		if pause_ask.visible:
			close_pause_ask()
		elif pause_options.visible:
			close_pause_options()
		else:
			set_paused(not get_tree().paused)
	if get_tree().paused:
		return
	if race and not battle and not race_returning:
		if time_trial:
			watch_trial(_delta)
		elif not Net.in_match and race.finish_time[race.player] >= 0.0:
			if not best_noted:
				best_noted = true
				race.new_best = Settings.record_best(track_dir, race.finish_time[race.player])
				if race.cars.size() > 1:
					race.new_place = Settings.record_place(track_dir, race.place(race.player), race.cars.size())
			race_hold += _delta
			if race_hold >= (4.0 if race.new_best or race.new_place else 2.0):
				race_returning = true
				MainMenu.start_page = MainMenu.PAGE_TRACK
				Sound.depart(func() -> void: Wipe.to(MainMenu.SCENE))


# FUN_000325ac takes a reach of 0x3a0 (800 on snow tracks, TRK weather 1), less
# 0x3c, less (0xf00 - camera x angle) / 8 and (camera height - 0x400) / 16 when
# positive. The x angle is the look-down angle plus 0xc00. Cells whose nearest
# corner is at most 4 * reach deep are drawn, and SetFogNearFar starts the fade
# at 4 * reach - 0x4c0 with h = 0x100 against the projection's H = 0xf0.
# Original fog starts there and is solid at the cull depth, where drawing stops.
func apply_fog(cam: Camera3D) -> void:
	if Settings.fog == Settings.Fog.FAR:
		environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		environment.fog_density = FAR_FOG_DENSITY
		cam.far = FAR_CLIP
		return
	var look_down := asin(cam.global_basis.z.y) / Car.ANGLE_TO_RAD
	var height := cam.global_position.y / Car.UNIT_METRES
	var reach: float = (800 if track.weather == 1 else 0x3a0) - 0x3c - maxf(0x300 - look_down, 0.0) / 8.0 - maxf(height - 0x400, 0.0) / 16.0
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_density = 1.0
	environment.fog_depth_curve = 1.0
	environment.fog_depth_begin = (reach * 4.0 - 0x4c0) * 0xf0 / float(0x100) * Car.UNIT_METRES
	environment.fog_depth_end = reach * 4.0 * Car.UNIT_METRES
	cam.far = environment.fog_depth_end


func set_paused(paused: bool) -> void:
	if Net.in_match and not Net.is_host():
		Net.ask_pause.rpc_id(1, paused)
		return
	apply_pause(paused)
	if Net.is_host():
		Net.set_paused_remote.rpc(paused)


func apply_pause(paused: bool) -> void:
	get_tree().paused = paused
	pause_menu.visible = paused
	if not paused:
		pause_ask.visible = false
		hide_pause_options()
		return
	hide_pause_options()
	UiTheme.kill_meta(pause_dim, "fade")
	pause_dim.modulate.a = 0.0
	var fade := pause_dim.create_tween()
	pause_dim.set_meta("fade", fade)
	fade.tween_property(pause_dim, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UiTheme.animate_in(pause_shell, pause_column)
	resume.grab_focus()


func build_rematch() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	rematch = Control.new()
	rematch.theme = UiTheme.theme()
	rematch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rematch.mouse_filter = Control.MOUSE_FILTER_STOP
	rematch.visible = false
	layer.add_child(rematch)
	rematch_dim = ColorRect.new()
	rematch_dim.color = Color(0, 0, 0, 0.62)
	rematch_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rematch_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	rematch.add_child(rematch_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rematch.add_child(center)
	rematch_shell = PanelContainer.new()
	rematch_shell.add_theme_stylebox_override("panel", UiTheme.shell_style())
	center.add_child(rematch_shell)
	rematch_column = VBoxContainer.new()
	rematch_column.alignment = BoxContainer.ALIGNMENT_CENTER
	rematch_column.add_theme_constant_override("separation", 14)
	rematch_shell.add_child(rematch_column)
	UiTheme.add_heading(rematch_column, "Race again?", 48)
	var scores := HBoxContainer.new()
	scores.alignment = BoxContainer.ALIGNMENT_CENTER
	scores.add_theme_constant_override("separation", 28)
	scores.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rematch_column.add_child(scores)
	for i in 4:
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scores.add_child(box)
		var title := Label.new()
		title.text = "P%d" % (i + 1)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 20)
		box.add_child(title)
		var number := Label.new()
		number.text = "0"
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_font_size_override("font_size", 36)
		box.add_child(number)
		rematch_scores.append(title)
		rematch_scores.append(number)
	rematch_yes_button = rematch_button("Yes", true)
	rematch_no_button = rematch_button("No", false)
	for button in [rematch_yes_button, rematch_no_button]:
		var here: NodePath = button.get_path()
		button.focus_neighbor_left = here
		button.focus_neighbor_right = here
		button.focus_neighbor_top = here
		button.focus_neighbor_bottom = here


func rematch_button(text: String, yes: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 64)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func() -> void:
		if Net.in_match and not Net.is_host():
			Sound.ui()
			Net.rematch_pick.rpc_id(1, -1 if yes else 1, true)
			return
		rematch_yes = yes
		apply_rematch(0, true)
	)
	UiTheme.hook_button(button)
	rematch_column.add_child(button)
	return button


func show_rematch() -> void:
	get_tree().paused = true
	pause_menu.visible = false
	battle.round_frame = 0
	rematch_yes = true
	for i in 4:
		var playing := i < Battle.players
		rematch_scores[i * 2].get_parent().visible = playing
		if not playing:
			continue
		var color := battle.cars[i].color
		rematch_scores[i * 2].add_theme_color_override("font_color", color)
		rematch_scores[i * 2 + 1].add_theme_color_override("font_color", color)
		rematch_scores[i * 2 + 1].text = str(Battle.wins[i])
	rematch.visible = true
	paint_rematch()
	UiTheme.kill_meta(rematch_dim, "fade")
	rematch_dim.modulate.a = 0.0
	var fade := rematch_dim.create_tween()
	rematch_dim.set_meta("fade", fade)
	fade.tween_property(rematch_dim, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	UiTheme.animate_in(rematch_shell, rematch_column)


func paint_rematch() -> void:
	if rematch_yes:
		rematch_yes_button.grab_focus()
	else:
		rematch_no_button.grab_focus()


func set_rematch_choice(yes: bool) -> void:
	rematch_yes = yes
	paint_rematch()


func poll_rematch() -> void:
	var move := 0
	if rematch_pressed("accelerate"):
		move = -1
	elif rematch_pressed("brake"):
		move = 1
	var accept := rematch_pressed("fire_item")
	if move == 0 and not accept:
		return
	if Net.in_match and not Net.is_host():
		Sound.ui()
		Net.rematch_pick.rpc_id(1, move, accept)
		return
	apply_rematch(move, accept)


func rematch_pressed(action: String) -> bool:
	if Net.in_match:
		return Input.is_action_just_pressed(action)
	for i in Battle.players:
		if Input.is_action_just_pressed(action + "_%d" % (i + 1)):
			return true
	return false


func apply_rematch(move: int, accept: bool) -> void:
	if not rematch.visible:
		return
	var yes := rematch_yes
	if move < 0:
		yes = true
	elif move > 0:
		yes = false
	if yes != rematch_yes:
		rematch_yes = yes
		Sound.ui()
		paint_rematch()
		if Net.is_host():
			Net.rematch_choice.rpc(rematch_yes)
	if not accept:
		return
	Sound.ui()
	rematch.visible = false
	get_tree().paused = false
	if Net.in_match:
		if rematch_yes:
			Net.begin_battle(track_dir)
		else:
			Net.rematch_tracks.rpc()
		return
	if rematch_yes:
		Session.play(track_dir)
	else:
		time_trial = false
		if editor_return != "":
			Wipe.to(editor_return)
			return
		MainMenu.start_page = MainMenu.PAGE_BATTLE_TRACK
		Wipe.to(MainMenu.SCENE)


func leave() -> void:
	if Net.in_match:
		if Net.is_host():
			if battle:
				battle.finish_match()
			else:
				Net.end_match.rpc(PackedInt32Array())
		else:
			Net.ask_end.rpc_id(1)
		return
	Sound.depart(func() -> void:
		if battle:
			battle.finish_match()
		else:
			var track_select := return_place() == "Track Select"
			time_trial = false
			if track_select:
				MainMenu.start_page = MainMenu.PAGE_TRACK
			Wipe.to(editor_return if editor_return != "" else MainMenu.SCENE)
	)


func build_pause_menu() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	pause_menu = Control.new()
	pause_menu.theme = UiTheme.theme()
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.visible = false
	layer.add_child(pause_menu)

	pause_dim = ColorRect.new()
	pause_dim.color = Color(0, 0, 0, 0.62)
	pause_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(pause_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.add_child(center)

	pause_shell = PanelContainer.new()
	pause_shell.add_theme_stylebox_override("panel", UiTheme.shell_style())
	center.add_child(pause_shell)

	pause_column = VBoxContainer.new()
	pause_column.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_column.add_theme_constant_override("separation", 14)
	pause_shell.add_child(pause_column)
	UiTheme.add_heading(pause_column, "Paused", 48)
	var track_name := Label.new()
	track_name.text = title(track_dir)
	track_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	track_name.add_theme_font_size_override("font_size", 28)
	track_name.add_theme_color_override("font_color", UiTheme.CREAM)
	pause_column.add_child(track_name)

	resume = pause_button(pause_column, "Resume", set_paused.bind(false))
	pause_button(pause_column, "Options", show_pause_options)
	pause_button(pause_column, "Return to %s" % return_place(), prompt_leave)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 28)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_column.add_child(gap)
	pause_button(pause_column, "Quit to Desktop", prompt_quit)
	build_pause_options(center)
	build_pause_ask(pause_menu)


func build_pause_options(parent: Node) -> void:
	pause_options = PanelContainer.new()
	pause_options.visible = false
	pause_options.add_theme_stylebox_override("panel", UiTheme.shell_style())
	parent.add_child(pause_options)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	pause_options.add_child(column)
	UiTheme.add_heading(column, "Options", 48)
	pause_scroll = UiTheme.options_scroll(column)
	pause_options_focus = UiTheme.fill_options(UiTheme.options_stack(pause_scroll))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 22)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(520, 64)
	back.add_theme_font_size_override("font_size", 24)
	back.pressed.connect(func() -> void:
		Sound.ui()
		close_pause_options()
	)
	UiTheme.hook_button(back)
	column.add_child(back)


func show_pause_options() -> void:
	pause_shell.visible = false
	pause_options.visible = true
	pause_options_focus.grab_focus()


func hide_pause_options() -> void:
	pause_options.visible = false
	pause_shell.visible = true


func close_pause_options() -> void:
	hide_pause_options()
	resume.grab_focus()


func pause_button(column: VBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520, 64)
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func() -> void:
		Sound.ui()
		action.call()
	)
	UiTheme.hook_button(button)
	column.add_child(button)
	return button


func build_pause_ask(parent: Control) -> void:
	pause_ask = Control.new()
	pause_ask.visible = false
	pause_ask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ask.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(pause_ask)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_ask.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_ask.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", UiTheme.shell_style())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	pause_ask_title = Label.new()
	pause_ask_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_ask_title.add_theme_font_size_override("font_size", 32)
	column.add_child(pause_ask_title)
	pause_ask_body = Label.new()
	pause_ask_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_ask_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_ask_body.add_theme_font_size_override("font_size", 22)
	pause_ask_body.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(pause_ask_body)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	pause_ask_yes = ask_button(row, "Return", accept_pause_ask)
	pause_ask_cancel = ask_button(row, "Cancel", close_pause_ask)
	UiTheme.lock_focus([pause_ask_yes, pause_ask_cancel])


func ask_button(row: HBoxContainer, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 64)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(func() -> void:
		Sound.ui()
		action.call()
	)
	UiTheme.hook_button(button)
	row.add_child(button)
	return button


func return_place() -> String:
	if editor_return != "":
		return "Level Editor"
	if Net.in_match:
		return "Online Multiplayer"
	if battle:
		return "Local Multiplayer"
	if time_trial and trial_controls.size() > 0 and trial_controls[0] != "":
		return "Main Menu"
	return "Track Select"


func prompt_leave() -> void:
	if editor_return != "":
		leave()
		return
	var place := return_place()
	open_pause_ask("Return to %s?" % place, "This race will end.", "Return", leave)


func prompt_quit() -> void:
	open_pause_ask("Quit to Desktop?", "The game will close.", "Quit", func() -> void: get_tree().quit())


func open_pause_ask(title: String, body: String, yes: String, action: Callable) -> void:
	pause_ask_title.text = title
	pause_ask_body.text = body
	pause_ask_yes.text = yes
	pause_ask_action = action
	pause_ask_return = get_viewport().gui_get_focus_owner()
	pause_ask.visible = true
	pause_ask_cancel.grab_focus()


func close_pause_ask() -> void:
	pause_ask.visible = false
	pause_ask_return.grab_focus()


func accept_pause_ask() -> void:
	var action := pause_ask_action
	pause_ask.visible = false
	action.call()


func setup_input() -> void:
	if InputMap.has_action("accelerate"):
		rebind_pads()
		return
	add_action("accelerate", [key(KEY_UP), key(KEY_W), joy_button(JOY_BUTTON_A), joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)])
	add_action("brake", [key(KEY_DOWN), key(KEY_S), joy_button(JOY_BUTTON_X), joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0)])
	add_action("steer_left", [key(KEY_LEFT), key(KEY_A), joy_button(JOY_BUTTON_DPAD_LEFT), joy_axis(JOY_AXIS_LEFT_X, -1.0)])
	add_action("steer_right", [key(KEY_RIGHT), key(KEY_D), joy_button(JOY_BUTTON_DPAD_RIGHT), joy_axis(JOY_AXIS_LEFT_X, 1.0)])
	add_action("fire_item", [key(KEY_SPACE), joy_button(JOY_BUTTON_RIGHT_SHOULDER)])
	add_action("cycle_item", [key(KEY_E), joy_button(JOY_BUTTON_LEFT_SHOULDER)])
	add_action("pause", [key(KEY_ESCAPE), joy_button(JOY_BUTTON_START)])
	var keys := [
		[KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE, KEY_E],
		[KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_CTRL, KEY_SHIFT],
	]
	var locations := [KEY_LOCATION_UNSPECIFIED, KEY_LOCATION_RIGHT]
	for i in 4:
		var suffix := "_%d" % (i + 1)
		var device: int = Battle.devices[i]
		var events: Array[Array] = [[], [], [], [], [], []]
		if device >= 0:
			events = [
				[joy_button(JOY_BUTTON_A, device), joy_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, device)],
				[joy_button(JOY_BUTTON_X, device), joy_axis(JOY_AXIS_TRIGGER_LEFT, 1.0, device)],
				[joy_button(JOY_BUTTON_DPAD_LEFT, device), joy_axis(JOY_AXIS_LEFT_X, -1.0, device)],
				[joy_button(JOY_BUTTON_DPAD_RIGHT, device), joy_axis(JOY_AXIS_LEFT_X, 1.0, device)],
				[joy_button(JOY_BUTTON_RIGHT_SHOULDER, device)],
				[joy_button(JOY_BUTTON_LEFT_SHOULDER, device)],
			]
		if i < keys.size():
			for k in events.size():
				var event := key(keys[i][k])
				if k >= 4:
					event.location = locations[i]
				events[k].append(event)
		var names := ["accelerate", "brake", "steer_left", "steer_right", "fire_item", "cycle_item"]
		for k in names.size():
			var typed: Array[InputEvent] = []
			typed.assign(events[k])
			add_action(names[k] + suffix, typed)


func add_action(action: StringName, events: Array[InputEvent]) -> void:
	InputMap.add_action(action, 0.2)
	for event in events:
		InputMap.action_add_event(action, event)


func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func joy_button(button: JoyButton, device := -1) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	return event


func joy_axis(axis: JoyAxis, value: float, device := -1) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = device
	return event


static func rebind_pads() -> void:
	if not InputMap.has_action("accelerate_1"):
		return
	var buttons: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER]
	var axes: Array = [[JOY_AXIS_TRIGGER_RIGHT, 1.0], [JOY_AXIS_TRIGGER_LEFT, 1.0], [JOY_AXIS_LEFT_X, -1.0], [JOY_AXIS_LEFT_X, 1.0], [], []]
	var names := ["accelerate", "brake", "steer_left", "steer_right", "fire_item", "cycle_item"]
	for i in 4:
		var device: int = Battle.devices[i]
		for k in names.size():
			var action := StringName(names[k] + "_%d" % (i + 1))
			for event in InputMap.action_get_events(action):
				if event is InputEventJoypadButton or event is InputEventJoypadMotion:
					InputMap.action_erase_event(action, event)
			if device < 0:
				continue
			var button := InputEventJoypadButton.new()
			button.button_index = buttons[k]
			button.device = device
			InputMap.action_add_event(action, button)
			if axes[k].is_empty():
				continue
			var motion := InputEventJoypadMotion.new()
			motion.axis = axes[k][0]
			motion.axis_value = axes[k][1]
			motion.device = device
			InputMap.action_add_event(action, motion)


# Open a track scene to see the mesh, scenery, and racing nodes. Playing it starts the race.
func show_in_editor() -> void:
	if has_node("EditorView"):
		get_node("EditorView").free()
	if track_dir.is_empty():
		return
	var view := Node3D.new()
	view.name = "EditorView"
	add_child(view)
	track = Track.new()
	track.name = "Track"
	view.add_child(track)
	track.load_from(track_dir, false)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = track.sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.55)
	var world_env := WorldEnvironment.new()
	world_env.name = "Sky"
	world_env.environment = env
	view.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	view.add_child(sun)
	sun.look_at_from_position(Vector3(0.27, 0.92, 0.27), Vector3.ZERO)
	view.add_child(track.editor_guides())
	get_node("EditorView/Track/Mesh").set_meta("_edit_lock_", true)
	get_node("EditorView/Guides/Path").set_meta("_edit_lock_", true)
	get_node("EditorView/Guides/Objects").set_meta("_edit_lock_", true)
	call_deferred("frame_editor_camera")


func frame_editor_camera() -> void:
	if not Engine.is_editor_hint() or not has_node("EditorView/Track/Mesh"):
		return
	var bounds := (get_node("EditorView/Track/Mesh") as MeshInstance3D).get_aabb()
	var iface: Object = Engine.get_singleton("EditorInterface")
	var viewport: Viewport = iface.call("get_editor_viewport_3d", 0)
	var cam := viewport.get_camera_3d()
	if cam == null:
		return
	var center := bounds.get_center()
	var span := maxf(bounds.size.length(), 20.0)
	cam.look_at_from_position(center + Vector3(span * 0.35, span * 0.5, span * 0.6), center)


func build_track() -> void:
	track = Track.new()
	add_child(track)
	track.load_from(track_dir)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = track.sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)
	env.fog_enabled = true
	env.fog_light_color = track.sky_color
	env.fog_sky_affect = 0.0
	environment = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)
	sun.look_at_from_position(Vector3(0.27, 0.92, 0.27), Vector3.ZERO)

	var start := track.node_transform(0, 0.3)
	if time_trial:
		load_ghost()
	if Net.in_match and time_trial:
		for i in Battle.players:
			var car := spawn_car(start.origin, start.basis.get_euler().y, Battle.models[i], 0)
			car.net_slot = i
			car.player_controlled = true
			car.controls = ""
			car.puppet = Net.puppet()
			car.net_driven = Net.is_host() and i != Net.slot
		spawn_ghost(start)
		player = get_tree().get_nodes_in_group("cars")[Net.slot]
	elif Net.in_match:
		for i in Battle.players:
			var car := spawn_car(start.origin, start.basis.get_euler().y, Battle.models[i], 0)
			car.net_slot = i
			car.player_controlled = true
			car.controls = ""
			car.puppet = Net.puppet()
			car.net_driven = Net.is_host() and i != Net.slot
		player = get_tree().get_nodes_in_group("cars")[Net.slot]
	elif time_trial:
		player = spawn_car(start.origin, start.basis.get_euler().y, trial_models[trial_turn], 0)
		player.player_controlled = true
		player.controls = trial_controls[trial_turn]
		spawn_ghost(start)
	elif Battle.players > 0:
		for i in Battle.players:
			var car := spawn_car(start.origin, start.basis.get_euler().y, Battle.models[i], 0)
			car.player_controlled = true
			car.controls = "_%d" % (i + 1)
		player = get_tree().get_first_node_in_group("cars")
	else:
		if track.ai_race:
			place_grid()
		else:
			player = spawn_car(start.origin, start.basis.get_euler().y, MainMenu.race_model, 0)
			player.player_controlled = true
	var preset: String = Car.HANDLING.find_key(track.handling)
	for car in get_tree().get_nodes_in_group("cars"):
		car.track = track
		car.apply_handling(preset)
	race = Race.new()
	add_child(race)
	var racers: Array[Car] = []
	racers.assign(get_tree().get_nodes_in_group("cars"))
	race.start(track, racers, racers.find(player))
	if time_trial:
		race.ghost_tape = Settings.ghost_tape(track_dir)
		race.prepare_trial(racers.size() - (1 if ghost_model >= 0 else 0))
		race.arm_start()
	elif track.ai_race and not Net.in_match and Battle.players == 0:
		race.arm_start()
	if time_trial:
		add_camera()
	elif Net.in_match or Battle.players > 0:
		var battle_camera := BattleCamera.new()
		battle_camera.track = track
		battle_camera.race = race
		add_child(battle_camera)
		camera = battle_camera
		battle = Battle.new()
		add_child(battle)
		battle_camera.current = true
	else:
		add_camera()
	var track_script := TrackScript.new()
	add_child(track_script)
	track_script.setup(track, racers, camera)
	var items := Items.new()
	add_child(items)
	items.setup(track, race, racers, camera)
	if battle:
		items.battle = true
		items.setting = Battle.pickups
		battle.start(track, race, racers, camera as BattleCamera)


func load_ghost() -> void:
	if Net.in_match and not Net.is_host():
		return
	ghost_model = Settings.ghost_model(track_dir)


func spawn_ghost(start: Transform3D) -> void:
	if ghost_model < 0:
		return
	var car := spawn_car(start.origin, start.basis.get_euler().y, ghost_model, 0)
	car.replay = not Net.puppet()
	car.puppet = Net.puppet()
	car.playback = true
	car.make_translucent()
	for other in get_tree().get_nodes_in_group("cars"):
		if other == car:
			continue
		car.add_collision_exception_with(other)
		other.add_collision_exception_with(car)


func watch_trial(delta: float) -> void:
	if Net.puppet():
		return
	note_finished_trials()
	if not humans_finished():
		return
	if not best_noted:
		best_noted = true
	race_hold += delta
	if race_hold < (4.0 if trial_any_best else 2.0):
		return
	race_returning = true
	if Net.is_host():
		Sound.depart(func() -> void: Net.restart_trial(track_dir))
	else:
		trial_turn = (trial_turn + 1) % trial_models.size()
		Sound.depart(func() -> void: play(track_dir))


func humans_finished() -> bool:
	for i in race.trial_tapes.size():
		if race.finish_time[i] < 0.0:
			return false
	return true


func note_finished_trials() -> void:
	for i in race.trial_tapes.size():
		if race.trial_saved[i] == 1 or race.finish_time[i] < 0.0 or race.trial_capped[i] == 1:
			continue
		race.trial_saved[i] = 1
		var model := Battle.models[i] if Net.in_match else int(trial_models[trial_turn])
		if Settings.take_trial(track_dir, race.finish_time[i], model, race.trial_tapes[i]):
			trial_any_best = true
			trial_best_index = i
			if i == race.player:
				race.new_best = true


func add_camera() -> void:
	var track_camera := TrackCamera.new()
	track_camera.track = track
	track_camera.race = race
	track_camera.target = player
	add_child(track_camera)
	track_camera.snap_to_target()
	camera = track_camera


# FUN_00028e30. Eight cars, one node apart, alternating the quarter lanes.
# Slot 7 is put at the front and the player (slot 0) at the back. Slots 1..7
# take models 1..7, with the player's model replaced by 0.
func place_grid() -> void:
	var count := track.nodes.size()
	var models: Array[int] = []
	models.resize(GRID)
	models[0] = MainMenu.race_model
	for i in range(1, GRID):
		models[i] = 0 if i == MainMenu.race_model else i
	var grid_node: Array[int] = []
	var grid_lane: Array[float] = []
	grid_node.resize(GRID)
	grid_lane.resize(GRID)
	var cursor := 0
	var order: Array[int] = [7, 1, 2, 3, 4, 5, 6, 0]
	for step in GRID:
		var node := cursor
		if node < 0:
			node = node - 1 + count
		var slot: int = order[step]
		grid_node[slot] = track.respawn_node(node)
		grid_lane[slot] = 0.25 if (step & 1) == 0 else 0.75
		cursor = -(step + 1)
	for slot in GRID:
		var placed := track.node_transform(grid_node[slot], grid_lane[slot])
		var car := spawn_car(placed.origin, placed.basis.get_euler().y, models[slot], grid_node[slot])
		if slot == 0:
			car.player_controlled = true
			player = car
		else:
			car.autopilot_enabled = true


func spawn_car(pos: Vector3, heading: float, model: int, node: int) -> Car:
	var car := Car.new()
	car.model = model
	car.mesh_dir = Car.mesh_for(track_dir)
	car.transform = Transform3D(Basis(Vector3.UP, heading), pos)
	car.add_to_group("cars")
	add_child(car)
	car.track = track
	car.plant(node)
	return car


func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var hud := Hud.new()
	hud.player = player
	hud.race = race
	hud.battle = battle
	layer.add_child(hud)
