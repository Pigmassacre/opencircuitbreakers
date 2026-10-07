class_name LevelEditor
extends Node3D

const SCENE := "res://scenes/level_editor.tscn"
const FAR_CELL := Vector3i(999999, 999999, 999999)
const TOOL_BRUSH := 0
const TOOL_ERASER := 1
const TOOL_PICK := 2
const TOOL_ROAD := 3
const TOOL_CAMERA := 4
const TOOL_LAP := 5
const TOOL_PICKUP := 6
const TOOL_SELECT := 7
const TOOL_NAMES := ["[B] Brush", "[X] Eraser", "[C] Pick", "[N] Road", "[V] Camera", "[Y] Race path", "[P] Pickups", "[M] Select"]
const TOOL_ICONS: Array[Texture2D] = [
	preload("res://icons/toolBrush.png"),
	preload("res://icons/toolEraser.png"),
	preload("res://icons/target.png"),
	preload("res://icons/car.png"),
	preload("res://icons/video.png"),
	preload("res://icons/flag.png"),
	preload("res://icons/diamond.png"),
	preload("res://icons/cursor.png"),
]
const PLAY_ICON := preload("res://icons/next.png")
const LAP_NAMES := ["Every lap", "Lap 1", "Lap 2", "Lap 3"]
const PANEL_W := 200

var level := LevelBuild.blank()
var cursor := Vector3i.ZERO
var cursor_off := Vector2i.ZERO
var cursor_oy := 0
var place_div := 1
var height_div := 1
var road_at := Vector3.ZERO
var road_units := Vector3i.ZERO
var road_ok := false
var road_snap := true
var hover_node := -1
var hover_part := -1
var picked_part := -1
var drag_node := -1
var node_held := false
var node_press := Vector2.ZERO
var press_node := -1
var press_moved := false
var span_node := -1
var span_end := 0
var span_hover := Vector2i(-1, -1)
var erased_key := Vector3i(999999, 999999, 999999)
var flow: MeshInstance3D
var road_guide: MeshInstance3D
var focus := Vector3.ZERO
var brush := LevelBuild.Piece.FLOOR
var brush_rot := 0
var brush_slope := 1
var brush_tile := 0
var pending_views: Array = []
var pending_view := 0
var brush_mirror := 0
var brush_lap := true
var editor_tool := TOOL_BRUSH
var select_from := FAR_CELL
var select_drag := false
var select_moved := false
var stamp: Array = []
var stamp_anchor := Vector3i.ZERO
var stamp_x0 := 0
var stamp_x1 := 0
var stamp_z0 := 0
var stamp_z1 := 0
var stamp_serial := 0
var stamp_rot := 0
var stamp_mesh_key := ""
var select_count := 0
var select_tint_key := ""
var laying := false
var place_from := -1
var show_cameras := false
var show_road := true
var camera_node := -1
var camera_memory: Array = []
var battle_memory: Array = []
var camera_drag := false
var camera_press := Vector2.ZERO
var camera_pitch0 := 0
var camera_dist0 := 0
var camera_hot := -2
var lap_painted := -1
var hover_spot := Vector2i(-1, -1)
var picked_pickup := Vector2i(-1, -1)
var pickup_type: int = Items.ROCKET
var pickup_lap := 0
var orbit_yaw := 0.65
var orbit_pitch := 1.05
var orbit_distance := 36.0
var left_down := false
var right_down := false
var middle_down := false
var grab := Vector3.ZERO
var painted := FAR_CELL
var painted_off := Vector2i.ZERO
var painted_oy := 0
var erased := FAR_CELL
var erased_off := Vector2i.ZERO
var erased_oy := 0
var dirty := false
var level_path := ""
var edit_token := 0
var untitled_id := 0
var saved_token := {"new:0": 0}
var save_dialog: Control
var save_name: LineEdit
var save_list: VBoxContainer
var save_target := ""
var filling_save := false
var after_save := ""
var pending_action := ""
var confirm_title: Label
var confirm_ok: Button
var confirm_extra: Button
var confirm_cancel: Button
var confirm_kind := ""
var confirm_ok_action: Callable = func() -> void: pass
var confirm_extra_action: Callable = func() -> void: pass
var undo_stack: Array = []
var redo_stack: Array = []
var undo_mark := {}
var undo_open := false
var filling_fields := false
var notice := ""
var notice_time := 0.0
var world: Node3D
var world_mesh: MeshInstance3D
var cell_visuals := {}
var tiles_dirty := false
var ghost: MeshInstance3D
var erase_mesh: MeshInstance3D
var select_tint: MeshInstance3D
var grid: MeshInstance3D
var ground: MeshInstance3D
var cursor_box: MeshInstance3D
var view: Camera3D
var level_title: Label
var settings_dialog: Control
var settings_name: LineEdit
var settings_vehicle: OptionButton
var settings_handling: OptionButton
var settings_ai: CheckBox
var settings_vehicle_was := 0
var filling_settings := false
var tileset_button: OptionButton
var tile_buttons: Array[Button] = []
var palette_scroll: ScrollContainer
var palette: VBoxContainer
var palette_host: Node3D
var connects_host: Node3D
var view_host: Node3D
var course_heading: Label
var course_row: HBoxContainer
var course_scroll: ScrollContainer
var course_map: TextureRect
var connects_grid: GridContainer
var connects_heading: Label
var catalog_course := 1
var link_tileset := ""
var link_next := {}
var connects_key := ""
var map_min_x := 0
var map_max_z := 0
var map_cell := 14
var map_cells := {}
var lap_button: Button
var road_snap_button: Button
var grid_button: Button
var height_button: Button
var tool_buttons: Array[Button] = []
var tileset_ids: PackedStringArray = PackedStringArray()
var status_label: Label
var message_panel: PanelContainer
var message_label: Label
var layer_label: Label
var height_box: VBoxContainer
var camera_box: VBoxContainer
var camera_type_button: Button
var camera_yaw_label: Label
var camera_pitch_label: Label
var camera_distance_label: Label
var pickup_box: VBoxContainer
var pickup_type_button: Button
var pickup_lap_button: Button
var pickup_count_label: Label
var pickup_view: MeshInstance3D
var view_menu: PopupMenu
var camera_view: MeshInstance3D
var detail_heading: Label
var tools_panel: PanelContainer
var tileset_panel: PanelContainer
var details_panel: PanelContainer
var armed := false
var ghost_revision := ""
var erase_revision := ""
var grid_key := FAR_CELL
var grid_span := -1
var grid_tileset := ""
var grid_fine := false
var grid_div := 1
var filling_tilesets := false
var picking := true
var editing := false
var picker: Control
var entry: Control
var picker_scroll: ScrollContainer
var picker_pages: Array[VBoxContainer] = []
var picker_tabs: Array[Button] = []
var picker_page := 0
var picker_idle: StyleBoxFlat
var picker_on: StyleBoxFlat
var picker_tab_off: StyleBoxFlat
var picker_tab_on: StyleBoxFlat
var picker_tab_hover: StyleBoxFlat
var confirm: Control
var confirm_text: Label
var pause_menu: Control
var pause_resume: Button
var entry_leave: Button
var pending_tileset := ""
var selected_style: StyleBoxFlat
var idle_style: StyleBoxFlat
var toolbox_on: StyleBoxFlat
var toolbox_idle: StyleBoxFlat
var tile_on: StyleBoxFlat
var tile_off: StyleBoxFlat


func _ready() -> void:
	if Wipe.covering:
		Wipe.boot = open_async
		return
	open(true)
	armed = true


func open_async() -> void:
	var id := tileset_to_load()
	if id != "":
		var loading := Wipe.push(0.0, 0.55)
		await LevelBuild.load_tileset(id)
		Wipe.pop(loading)
	open(false)
	var building := Wipe.push(0.55, 1.0)
	await rebuild_async()
	Wipe.pop(building)
	await Wipe.breathe(1.0)
	armed = true


func tileset_to_load() -> String:
	var id := String(level.tileset)
	if Session.editor_return != "" and FileAccess.file_exists(LevelBuild.ACTIVE):
		var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LevelBuild.ACTIVE))
		if parsed.has("tileset"):
			id = String(parsed.tileset)
	if not FileAccess.file_exists(LevelBuild.tileset_home(id).path_join("pieces.bin")):
		return ""
	return id


func open(build_world: bool) -> void:
	Sound.silence_race()
	get_tree().paused = false
	var resume := Session.editor_return != ""
	Session.editor_return = ""
	build_view()
	build_ui()
	if resume and FileAccess.file_exists(LevelBuild.ACTIVE):
		level = LevelBuild.load_level(LevelBuild.ACTIVE)
		level_path = String(level.source)
		if level_path != "" and not FileAccess.file_exists(level_path):
			level_path = ""
		var was_unsaved := bool(level.unsaved)
		level.erase("source")
		level.erase("unsaved")
		edit_token = 1
		if level_path == "":
			untitled_id = 1
		saved_token[save_key()] = 0 if was_unsaved else 1
	apply_level_fields()
	frame_level()
	update_camera()
	if build_world:
		rebuild_world()
	aim_cursor(get_viewport().get_visible_rect().size * 0.5)
	if resume and FileAccess.file_exists(LevelBuild.ACTIVE):
		enter_editor()
	else:
		show_entry()


func _process(delta: float) -> void:
	if not armed:
		return
	flush_views()
	if notice_time > 0.0:
		notice_time -= delta
	if blocked():
		flush_tiles()
		return
	update_camera()
	if not typing():
		poll_pan(delta)
		if not right_down and not middle_down and not over_ui():
			aim_cursor(Settings.mouse_position())
		if left_down and not over_ui():
			stroke_drag()
	var fine := editor_tool == TOOL_ROAD and road_snap and tileset_grid() <= 1
	var div := shown_grid()
	if grid_key.x != snapped_focus().x or grid_key.z != snapped_focus().y or grid_key.y != cursor.y or grid_span != grid_cells() or grid_tileset != level.tileset or grid_fine != fine or grid_div != div:
		grid_fine = fine
		grid_div = div
		rebuild_grid()
	if signature_now() != ghost_revision:
		if active_tool() == TOOL_BRUSH:
			rebuild_ghost()
		elif editor_tool != TOOL_SELECT:
			ghost_revision = signature_now()
			ghost.mesh = null
		else:
			ghost_revision = signature_now()
		rebuild_cursor_box()
		refresh_road_guide()
	if editor_tool == TOOL_SELECT:
		refresh_stamp_ghost()
	refresh_select_tint()
	ghost.visible = active_tool() == TOOL_BRUSH or (editor_tool == TOOL_SELECT and not stamp.is_empty() and not select_drag)
	if editor_tool == TOOL_CAMERA:
		var hot := hover_node if hover_node >= 0 else camera_node
		if hot != camera_hot:
			camera_hot = hot
			refresh_camera_view()
	if editor_tool == TOOL_PICKUP:
		pickup_view.mesh = LevelBuild.pickup_mesh(level.line, hover_spot, picked_pickup, true)
	else:
		pickup_view.mesh = null
	refresh_erase()
	paint_status()
	flush_tiles()


func _unhandled_input(event: InputEvent) -> void:
	if not armed:
		return
	if menu_pad(event):
		editor_back()
		get_viewport().set_input_as_handled()
		return
	if blocked() and not (event is InputEventKey):
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if right_down:
			orbit_yaw -= motion.relative.x * 0.006
			orbit_pitch = clampf(orbit_pitch + motion.relative.y * 0.004, 0.25, 1.35)
			return
		if middle_down:
			drag_pan(motion.position)
			return
		if over_ui():
			return
		aim_cursor(motion.position)
		if left_down:
			stroke_drag()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			right_down = button.pressed
			return
		if button.button_index == MOUSE_BUTTON_MIDDLE:
			if button.pressed:
				begin_pan(button.position)
			else:
				middle_down = false
			return
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			if button.ctrl_pressed:
				turn(1)
			else:
				orbit_distance = maxf(12.0, orbit_distance - 3.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if button.ctrl_pressed:
				turn(-1)
			else:
				orbit_distance = minf(90.0, orbit_distance + 3.0)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			aim_cursor(button.position)
			left_down = true
			stroke_down()
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return
	var key := key_event.keycode
	if settings_dialog.visible or save_dialog.visible or confirm.visible:
		if save_dialog.visible and event.ctrl_pressed and key == KEY_S and not key_event.shift_pressed:
			commit_save_dialog()
		return
	if event.ctrl_pressed and key == KEY_S and not key_event.shift_pressed:
		save_current()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and key == KEY_S and key_event.shift_pressed:
		open_save_dialog()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and key == KEY_N and not key_event.shift_pressed:
		try_close("new")
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and key == KEY_O and not key_event.shift_pressed:
		show_picker()
		get_viewport().set_input_as_handled()
		return
	if picking or pause_menu.visible:
		return
	if event.ctrl_pressed and key == KEY_Z and not key_event.shift_pressed:
		undo_level()
		get_viewport().set_input_as_handled()
		return
	if event.ctrl_pressed and (key == KEY_Y or (key == KEY_Z and key_event.shift_pressed)):
		redo_level()
		get_viewport().set_input_as_handled()
		return
	if event.echo:
		return
	match key:
		KEY_Q:
			turn(-1)
		KEY_E:
			turn(1)
		KEY_R:
			shift_layer(1)
		KEY_F:
			shift_layer(-1)
		KEY_L:
			toggle_lap()
		KEY_B:
			set_tool(TOOL_BRUSH)
		KEY_X:
			set_tool(TOOL_ERASER)
		KEY_C:
			set_tool(TOOL_PICK)
		KEY_N:
			set_tool(TOOL_ROAD)
		KEY_V:
			set_tool(TOOL_CAMERA)
		KEY_Y:
			set_tool(TOOL_LAP)
		KEY_P:
			set_tool(TOOL_PICKUP)
		KEY_M:
			set_tool(TOOL_SELECT)
		KEY_K:
			if editor_tool == TOOL_PICKUP:
				cycle_pickup_lap()
		KEY_G:
			if editor_tool == TOOL_ROAD:
				road_snap = not road_snap
		KEY_H:
			cycle_grid()
		KEY_J:
			cycle_height()
		KEY_T:
			if editor_tool == TOOL_CAMERA:
				cycle_camera_type()
			elif editor_tool == TOOL_PICKUP:
				cycle_pickup_type(-1 if key_event.shift_pressed else 1)
		KEY_BRACKETLEFT:
			if editor_tool == TOOL_CAMERA:
				step_camera_pitch(-1)
		KEY_BRACKETRIGHT:
			if editor_tool == TOOL_CAMERA:
				step_camera_pitch(1)
		KEY_MINUS:
			if editor_tool == TOOL_CAMERA:
				step_camera_distance(-1)
		KEY_EQUAL:
			if editor_tool == TOOL_CAMERA:
				step_camera_distance(1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			stroke_down()
			finish_select()
			end_stroke()
		KEY_DELETE, KEY_BACKSPACE:
			if editor_tool == TOOL_ROAD:
				cut_road()
			elif editor_tool == TOOL_PICKUP:
				remove_pickup()
			elif editor_tool != TOOL_CAMERA and editor_tool != TOOL_LAP:
				remove_part()
		KEY_F5:
			play(true)
		KEY_F6:
			play(false)


func _input(event: InputEvent) -> void:
	if not armed:
		return
	if blocked():
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
			if press_node >= 0 and not press_moved and editor_tool == TOOL_ROAD:
				start_placing(press_node)
			press_node = -1
			press_moved = false
			picked_part = -1
			node_held = false
			left_down = false
			drag_node = -1
			span_node = -1
			camera_drag = false
			erased = FAR_CELL
			finish_select()
			end_stroke()
			flush()


func poll_pan(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		move.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		move.y -= 1.0
	if move == Vector2.ZERO:
		return
	var offset := view.global_position - focus
	offset.y = 0.0
	var back := offset.normalized()
	var right := Vector3(back.z, 0.0, -back.x)
	var forward := -back
	focus += (right * move.x + forward * move.y) * orbit_distance * 0.85 * delta


func typing() -> bool:
	return settings_dialog.visible or save_dialog.visible


func menu_pad(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventJoypadButton:
		var joy := event as InputEventJoypadButton
		return joy.pressed and joy.button_index == JOY_BUTTON_START
	return false


func editor_back() -> void:
	if settings_dialog.visible:
		cancel_settings()
	elif save_dialog.visible:
		cancel_save_dialog()
	elif confirm.visible:
		cancel_confirm()
	elif pause_menu.visible:
		resume_editor()
	elif picker.visible:
		if editing:
			enter_editor()
		else:
			show_entry()
	elif entry.visible:
		if editing:
			enter_editor()
		else:
			try_close("leave")
	elif laying:
		laying = false
	else:
		show_pause()


func blocked() -> bool:
	return picking or confirm.visible or pause_menu.visible or save_dialog.visible or settings_dialog.visible


func over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE


func signature_now() -> String:
	var base := "%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d" % [level.tileset, cursor.x, cursor.y, cursor.z, cursor_off.x, cursor_off.y, cursor_oy, brush_tile, brush_rot, brush_mirror, 1 if brush_lap else 0, editor_tool * 2 + (1 if wants_erase() else 0), level.line.size(), 1 if level.joined else 0, 1 if road_ok else 0, road_units.x, road_units.y, road_units.z, hover_node, 1 if laying else 0, span_hover.x, span_hover.y, place_from, 1 if wants_pick() else 0, hover_part, level.parts.size(), place_div, height_div]
	return "%s:%d:%d:%d:%d:%d:%d" % [base, 1 if select_drag else 0, select_from.x, select_from.y, select_from.z, stamp_serial, stamp_rot]


func plane_hit(screen: Vector2) -> Variant:
	var origin := view.project_ray_origin(screen)
	var dir := view.project_ray_normal(screen)
	var plane := Plane(Vector3.UP, LevelBuild.cell_plane(cursor.y, level.tileset))
	return plane.intersects_ray(origin, dir)


func aim_cursor(screen: Vector2) -> void:
	if editor_tool == TOOL_CAMERA:
		hover_part = -1
		hover_node = nearest_node(screen)
		span_hover = Vector2i(-1, -1)
		return
	if editor_tool == TOOL_LAP:
		hover_node = -1
		span_hover = Vector2i(-1, -1)
		hover_part = part_under_mouse(screen)
		return
	if editor_tool == TOOL_PICKUP:
		hover_node = -1
		hover_part = -1
		span_hover = Vector2i(-1, -1)
		hover_spot = nearest_spot(screen)
		return
	if editor_tool == TOOL_ROAD:
		hover_part = -1
		var surface := LevelBuild.surface_point(level.parts, level.tileset, view.project_ray_origin(screen), view.project_ray_normal(screen))
		road_ok = not surface.is_empty()
		if road_ok:
			road_at = surface.at
			road_units = Vector3i(int(surface.x), int(surface.y), int(surface.z))
			if road_snap:
				var step := road_step()
				road_units.x = LevelBuild.snap_unit(road_units.x, step)
				road_units.z = LevelBuild.snap_unit(road_units.z, step)
				road_at.x = LevelBuild.metres(float(road_units.x))
				road_at.z = LevelBuild.metres(float(road_units.z))
			cursor = Vector3i(LevelBuild.cell_index(road_units.x), int(surface.layer), LevelBuild.cell_index(road_units.z))
		if drag_node >= 0:
			hover_node = drag_node
		else:
			hover_node = nearest_node(screen)
		if span_node >= 0:
			span_hover = Vector2i(span_node, span_end)
		else:
			span_hover = pick_span(screen)
		return
	hover_node = -1
	span_hover = Vector2i(-1, -1)
	hover_part = part_under_mouse(screen) if wants_pick() else -1
	var hit: Variant = plane_hit(screen)
	if hit == null:
		return
	var point: Vector3 = hit
	var div := snap_div()
	if div <= 1:
		var step := LevelBuild.metres(LevelBuild.CELL_U)
		cursor.x = roundi(point.x / step)
		cursor.z = roundi(point.z / step)
		cursor_off = Vector2i.ZERO
		return
	var step_u := LevelBuild.CELL_U / div
	var step_m := LevelBuild.metres(float(step_u))
	var units_x := roundi(point.x / step_m) * step_u
	var units_z := roundi(point.z / step_m) * step_u
	cursor.x = roundi(float(units_x) / float(LevelBuild.CELL_U))
	cursor.z = roundi(float(units_z) / float(LevelBuild.CELL_U))
	cursor_off = Vector2i(units_x - cursor.x * LevelBuild.CELL_U, units_z - cursor.z * LevelBuild.CELL_U)


func part_under_mouse(screen: Vector2) -> int:
	var origin := view.project_ray_origin(screen)
	var dir := view.project_ray_normal(screen)
	var half := LevelBuild.metres(256.0)
	var height := LevelBuild.metres(float(LevelBuild.CELL_U)) - 0.02
	var best := -1
	var best_t := 1.0e20
	for i in level.parts.size():
		var part: Dictionary = level.parts[i]
		var center := LevelBuild.cell_center(int(part.x), int(part.z)) + LevelBuild.part_nudge(part)
		var y0 := LevelBuild.cell_plane(int(part.y), level.tileset) + LevelBuild.part_lift(part)
		var pad := LevelBuild.metres(128.0)
		if ray_box(origin, dir, Vector3(center.x - half - pad, y0 - pad, center.z - half - pad), Vector3(center.x + half + pad, y0 + height + pad, center.z + half + pad)) < 0.0:
			continue
		var t := -1.0
		if int(part.piece) == LevelBuild.Piece.SCENERY:
			t = LevelBuild.ray_part(part, level.tileset, origin, dir)
		else:
			t = ray_box(origin, dir, Vector3(center.x - half, y0, center.z - half), Vector3(center.x + half, y0 + height, center.z + half))
		if t >= 0.0 and t < best_t:
			best_t = t
			best = i
	return best


func ray_box(origin: Vector3, dir: Vector3, box_min: Vector3, box_max: Vector3) -> float:
	var tmin := 0.0
	var tmax := 1.0e20
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
				return -1.0
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
			return -1.0
	return tmin


func begin_pan(screen: Vector2) -> void:
	var hit: Variant = plane_hit(screen)
	if hit == null:
		return
	middle_down = true
	grab = hit


func drag_pan(screen: Vector2) -> void:
	var hit: Variant = plane_hit(screen)
	if hit == null:
		return
	var shift: Vector3 = grab - hit
	shift.y = 0.0
	focus += shift
	update_camera()


func update_camera() -> void:
	var yaw := Basis(Vector3.UP, orbit_yaw)
	var pitched := yaw * Basis(Vector3.RIGHT, -orbit_pitch)
	view.global_position = focus + pitched * Vector3(0.0, 0.0, orbit_distance)
	view.look_at(focus, Vector3.UP)


func frame_level() -> void:
	if level.parts.is_empty():
		focus = Vector3.ZERO
		return
	var sum := Vector3.ZERO
	for part: Dictionary in level.parts:
		sum += LevelBuild.cell_center(int(part.x), int(part.z))
		sum.y += LevelBuild.layer_height(int(part.y))
	focus = sum / float(level.parts.size())


func set_tile(index: int) -> void:
	var tiles: Array = LevelBuild.tileset_info(level.tileset).tiles
	brush_tile = clampi(index, 0, tiles.size() - 1)
	var tile: Dictionary = tiles[brush_tile]
	brush = int(tile.piece)
	if String(tile.role) != "scenery":
		brush_rot = int(tile.rot) & 3
	brush_slope = int(tile.slope)
	if brush == LevelBuild.Piece.RAMP and brush_slope == 0:
		brush_slope = 1
	if editor_tool != TOOL_BRUSH:
		editor_tool = TOOL_BRUSH
		painted = FAR_CELL
		erased = FAR_CELL
	for button in tile_buttons:
		var i := int(button.get_meta("tile"))
		var on := i == brush_tile
		var style := tile_on if on else tile_off
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", tile_on)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("hover_pressed", tile_on)
		button.add_theme_stylebox_override("focus", style)
	if left_down:
		painted = FAR_CELL
	refresh_course_map()
	call_deferred("refresh_connects")


func piece_tile() -> int:
	var tiles: Array = LevelBuild.tileset_info(level.tileset).tiles
	for i in tiles.size():
		var tile: Dictionary = tiles[i]
		if String(tile.role) == "scenery":
			return i
	return 0


func brush_index() -> int:
	return brush_tile


func turn(direction: int) -> void:
	if editor_tool == TOOL_CAMERA:
		step_camera_yaw(direction)
		return
	if editor_tool == TOOL_ROAD:
		move_start(direction)
		return
	if editor_tool == TOOL_SELECT:
		rotate_stamp(direction)
		return
	var tiles: Array = LevelBuild.tileset_info(level.tileset).tiles
	var tile: Dictionary = tiles[brush_tile]
	if String(tile.role) == "scenery":
		brush_rot = (brush_rot + direction) & 3
		paint_facing()
		if left_down:
			painted = FAR_CELL
		return
	var group: Array[int] = []
	for i in tiles.size():
		var other: Dictionary = tiles[i]
		if int(other.piece) == int(tile.piece):
			group.append(i)
	var at := group.find(brush_tile)
	set_tile(group[(at + direction + group.size()) % group.size()])


func shift_layer(direction: int) -> void:
	var div := active_height()
	if div <= 1:
		cursor.y += direction
		cursor_oy = 0
	else:
		var span := LevelBuild.layer_step(level.tileset)
		if direction > 0:
			cursor_oy += layer_substep(span, div, layer_index(cursor_oy, span, div))
			if cursor_oy >= span:
				cursor.y += 1
				cursor_oy -= span
		elif cursor_oy == 0:
			cursor.y -= 1
			cursor_oy = span - layer_substep(span, div, div - 1)
		else:
			cursor_oy -= layer_substep(span, div, layer_index(cursor_oy - 1, span, div))
	painted = FAR_CELL
	erased = FAR_CELL


func toggle_lap() -> void:
	brush_lap = not brush_lap
	if editor_tool == TOOL_LAP:
		return
	var index := part_at_cursor()
	if index >= 0 and int(level.parts[index].piece) == LevelBuild.Piece.SCENERY:
		var owned := undo_scope()
		level.parts[index].lap = 1 if brush_lap else 0
		commit()
		undo_scope_end(owned)


func active_camera_node() -> int:
	if camera_node >= 0 and camera_node < level.line.size():
		return camera_node
	if hover_node >= 0 and hover_node < level.line.size():
		return hover_node
	return -1


func node_camera(index: int) -> Array:
	var sample: Dictionary = level.line[index]
	if sample.has("camera"):
		var cam: Array = sample.camera
		return [int(cam[0]), int(cam[1]), int(cam[2]), int(cam[3]), int(cam[4])]
	if camera_memory.size() == 5:
		return [int(camera_memory[0]), int(camera_memory[1]), int(camera_memory[2]), int(camera_memory[3]), int(camera_memory[4])]
	var made := LevelBuild.camera_bytes(int(sample.h))
	var fresh: Array = made.camera
	return [int(fresh[0]), int(fresh[1]), int(fresh[2]), int(fresh[3]), int(fresh[4])]


func remember_shot(sample: Dictionary) -> void:
	if not sample.has("camera"):
		return
	var cam: Array = sample.camera
	camera_memory = [int(cam[0]), int(cam[1]), int(cam[2]), int(cam[3]), int(cam[4])]
	if sample.has("battle_camera"):
		var battle: Array = sample.battle_camera
		battle_memory = [int(battle[0]), int(battle[1]), int(battle[2])]
	else:
		battle_memory = [int(cam[1]), int(cam[2]), int(cam[3])]


func store_camera(index: int, cam: Array) -> void:
	var sample: Dictionary = level.line[index]
	var fresh := not sample.has("camera")
	sample.camera = [int(cam[0]), int(cam[1]), int(cam[2]), int(cam[3]), int(cam[4])]
	if not sample.has("battle_camera"):
		if fresh and battle_memory.size() == 3:
			sample.battle_camera = [int(battle_memory[0]), int(battle_memory[1]), int(battle_memory[2])]
		else:
			sample.battle_camera = [int(cam[1]), int(cam[2]), int(cam[3])]
	remember_shot(sample)
	dirty = true
	refresh_camera_view()


func grab_camera() -> void:
	var index := nearest_node(Settings.mouse_position())
	if index < 0:
		camera_node = -1
		camera_drag = false
		return
	camera_node = index
	var sample: Dictionary = level.line[index]
	var cam := node_camera(index)
	if sample.has("camera"):
		remember_shot(sample)
	else:
		store_camera(index, cam)
	camera_pitch0 = LevelBuild.pitch_step(int(cam[2]))
	camera_dist0 = int(cam[3])
	camera_press = Settings.mouse_position()
	camera_drag = true


func slide_camera() -> void:
	if not camera_drag or camera_node < 0 or camera_node >= level.line.size():
		return
	var delta := Settings.mouse_position() - camera_press
	if delta.length() < 8.0:
		return
	var pitch := clampi(camera_pitch0 - int(delta.y / 12.0), -63, 63)
	var dist := clampi(camera_dist0 + int(delta.x / 10.0), 0, 255)
	var cam := node_camera(camera_node)
	var pitch_byte := LevelBuild.pitch_byte(pitch)
	if int(cam[2]) == pitch_byte and int(cam[3]) == dist:
		return
	cam[2] = pitch_byte
	cam[3] = dist
	store_camera(camera_node, cam)


func step_camera_yaw(direction: int) -> void:
	var index := active_camera_node()
	if index < 0:
		return
	var cam := node_camera(index)
	cam[1] = (int(cam[1]) + direction) & 31
	var owned := undo_scope()
	store_camera(index, cam)
	if owned:
		undo_scope_end(owned)
		flush()


func step_camera_pitch(direction: int) -> void:
	var index := active_camera_node()
	if index < 0:
		return
	var cam := node_camera(index)
	cam[2] = LevelBuild.pitch_byte(clampi(LevelBuild.pitch_step(int(cam[2])) + direction, -63, 63))
	var owned := undo_scope()
	store_camera(index, cam)
	if owned:
		undo_scope_end(owned)
		flush()


func step_camera_distance(direction: int) -> void:
	var index := active_camera_node()
	if index < 0:
		return
	var cam := node_camera(index)
	cam[3] = clampi(int(cam[3]) + direction, 0, 255)
	var owned := undo_scope()
	store_camera(index, cam)
	if owned:
		undo_scope_end(owned)
		flush()


func cycle_camera_type() -> void:
	var index := active_camera_node()
	if index < 0:
		return
	var order := [LevelBuild.CAM_NORMAL, LevelBuild.CAM_EDGE, LevelBuild.CAM_TIGHT]
	var cam := node_camera(index)
	var at := order.find(int(cam[0]))
	if at < 0:
		at = 0
	cam[0] = order[(at + 1) % order.size()]
	var owned := undo_scope()
	store_camera(index, cam)
	if owned:
		undo_scope_end(owned)
		flush()


func paint_lap() -> void:
	var index := part_under_mouse(Settings.mouse_position())
	if index == lap_painted:
		return
	lap_painted = index
	if index < 0:
		return
	var part: Dictionary = level.parts[index]
	if int(part.piece) != LevelBuild.Piece.SCENERY:
		return
	var want := 1 if brush_lap else 0
	if int(part.lap) == want:
		return
	part.lap = want
	rebake_cell(Vector3i(int(part.x), int(part.y), int(part.z)))
	dirty = true


func nearest_spot(screen: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 18.0
	for i in level.line.size():
		for lane in LevelBuild.LANE_NAMES.size():
			var point := LevelBuild.pickup_spot(level.line[i], lane) + Vector3.UP * 0.1
			if view.is_position_behind(point):
				continue
			var dist := view.unproject_position(point).distance_to(screen)
			if dist < best_d:
				best_d = dist
				best = Vector2i(i, lane)
	return best


func spot_entries(spot: Vector2i) -> Array[int]:
	var found: Array[int] = []
	var sample: Dictionary = level.line[spot.x]
	if not sample.has("pickups"):
		return found
	var entries: Array = sample.pickups
	for k in entries.size():
		if int(entries[k][2]) == spot.y:
			found.append(k)
	return found


func picked_valid() -> bool:
	if picked_pickup.x < 0 or picked_pickup.x >= level.line.size():
		return false
	var sample: Dictionary = level.line[picked_pickup.x]
	return sample.has("pickups") and picked_pickup.y < (sample.pickups as Array).size()


func picked_entry() -> Array:
	return level.line[picked_pickup.x].pickups[picked_pickup.y]


func click_pickup() -> void:
	if hover_spot.x < 0:
		picked_pickup = Vector2i(-1, -1)
		return
	var here := spot_entries(hover_spot)
	if shift_down():
		if not here.is_empty():
			remove_entry(Vector2i(hover_spot.x, here[here.size() - 1]))
		return
	if here.is_empty() or ctrl_down():
		add_pickup(hover_spot)
		return
	var at := here.find(picked_pickup.y) if picked_pickup.x == hover_spot.x else -1
	picked_pickup = Vector2i(hover_spot.x, here[(at + 1) % here.size()])
	var entry := picked_entry()
	pickup_lap = int(entry[0])
	pickup_type = int(entry[1])


func add_pickup(spot: Vector2i) -> void:
	if LevelBuild.pickup_count(level.line) >= LevelBuild.PICKUP_LIMIT:
		flash("%d pickups at most" % LevelBuild.PICKUP_LIMIT)
		return
	var sample: Dictionary = level.line[spot.x]
	if not sample.has("pickups"):
		sample.pickups = []
	var entries: Array = sample.pickups
	entries.append([pickup_lap, pickup_type, spot.y])
	picked_pickup = Vector2i(spot.x, entries.size() - 1)
	dirty = true


func remove_entry(at: Vector2i) -> void:
	var sample: Dictionary = level.line[at.x]
	var entries: Array = sample.pickups
	entries.remove_at(at.y)
	if entries.is_empty():
		sample.erase("pickups")
	picked_pickup = Vector2i(-1, -1)
	dirty = true


func remove_pickup() -> void:
	if not picked_valid():
		return
	var owned := undo_scope()
	remove_entry(picked_pickup)
	undo_scope_end(owned)
	flush()


func cycle_pickup_type(direction: int) -> void:
	var at := LevelBuild.PICKUP_TYPES.find(pickup_type)
	pickup_type = LevelBuild.PICKUP_TYPES[wrapi(at + direction, 0, LevelBuild.PICKUP_TYPES.size())]
	set_picked(1, pickup_type)


func cycle_pickup_lap() -> void:
	pickup_lap = (pickup_lap + 1) % LAP_NAMES.size()
	set_picked(0, pickup_lap)


func set_picked(slot: int, value: int) -> void:
	if not picked_valid():
		return
	var owned := undo_scope()
	picked_entry()[slot] = value
	dirty = true
	undo_scope_end(owned)
	flush()


func pickup_text(entry: Array) -> String:
	return "%s, %s" % [LevelBuild.PICKUP_NAMES[int(entry[1])], LAP_NAMES[int(entry[0])].to_lower()]


func find_part() -> int:
	return find_at(cursor.x, cursor.y, cursor.z)


func find_at(x: int, y: int, z: int) -> int:
	for i in level.parts.size():
		var part: Dictionary = level.parts[i]
		if int(part.x) == x and int(part.y) == y and int(part.z) == z:
			return i
	return -1


func find_same(part: Dictionary) -> int:
	var slot := int(part.slot) if part.has("slot") else 0
	var found := -1
	for i in level.parts.size():
		var other: Dictionary = level.parts[i]
		var other_slot := int(other.slot) if other.has("slot") else 0
		if int(other.x) == int(part.x) and int(other.y) == int(part.y) and int(other.z) == int(part.z) and int(other.tile) == int(part.tile) and other_slot == slot and LevelBuild.part_off(other) == LevelBuild.part_off(part) and LevelBuild.part_oy(other) == LevelBuild.part_oy(part):
			found = i
	return found


func stacks() -> bool:
	return bool(LevelBuild.tileset_info(level.tileset).stack)


func tileset_grid() -> int:
	return maxi(1, int(LevelBuild.tileset_info(level.tileset).grid))


func active_div() -> int:
	var limit := tileset_grid()
	if limit <= 1:
		return 1
	var div := place_div
	if div < 1:
		div = 1
	while div > limit:
		div = int(div / 2)
	return div


func snap_div() -> int:
	if tileset_grid() <= 1:
		return 1
	if editor_tool == TOOL_CAMERA or editor_tool == TOOL_LAP or editor_tool == TOOL_SELECT:
		return 1
	if editor_tool == TOOL_ROAD:
		return active_div()
	var tile: Dictionary = LevelBuild.tile_def(level.tileset, brush_index())
	if String(tile.role) != "scenery":
		return 1
	return active_div()


func road_step() -> int:
	if tileset_grid() > 1:
		return LevelBuild.CELL_U / active_div()
	return LevelBuild.CELL_U / 16


func shown_grid() -> int:
	return snap_div()


func active_height() -> int:
	if tileset_grid() <= 1:
		return 1
	if editor_tool == TOOL_CAMERA or editor_tool == TOOL_LAP or editor_tool == TOOL_ROAD or editor_tool == TOOL_SELECT:
		return 1
	var tile: Dictionary = LevelBuild.tile_def(level.tileset, brush_index())
	if String(tile.role) != "scenery":
		return 1
	var div := height_div
	if div < 1:
		div = 1
	while div > 32:
		div = int(div / 2)
	return div


func place_oy() -> int:
	if active_height() <= 1:
		return 0
	return cursor_oy


func layer_substep(span: int, div: int, index: int) -> int:
	var base := int(span / div)
	var extra := span - base * div
	var at := index % div
	if at < 0:
		at += div
	return base + (1 if at < extra else 0)


func layer_index(oy: int, span: int, div: int) -> int:
	var base := int(span / div)
	var extra := span - base * div
	var at := 0
	for i in div:
		var size := base + (1 if i < extra else 0)
		if oy < at + size:
			return i
		at += size
	return div - 1


func cycle_height() -> void:
	if tileset_grid() <= 1:
		return
	if height_div < 1 or height_div >= 32:
		height_div = 1
	else:
		height_div *= 2
	cursor_oy = 0
	painted = FAR_CELL
	erased = FAR_CELL


func cycle_grid() -> void:
	var limit := tileset_grid()
	if limit <= 1:
		return
	if place_div < 1 or place_div >= limit:
		place_div = 1
	else:
		place_div *= 2
	painted = FAR_CELL
	erased = FAR_CELL


func part_at_cursor() -> int:
	if stacks():
		var hit := part_under_mouse(Settings.mouse_position())
		if hit >= 0:
			return hit
		var found := -1
		for i in level.parts.size():
			var other: Dictionary = level.parts[i]
			if int(other.x) == cursor.x and int(other.y) == cursor.y and int(other.z) == cursor.z:
				found = i
				if LevelBuild.part_off(other) == cursor_off and LevelBuild.part_oy(other) == place_oy():
					return i
		return found
	return find_part()


func paint_at_cursor() -> void:
	if editor_tool == TOOL_ROAD:
		extend_road()
		return
	if painted == cursor and painted_off == cursor_off and painted_oy == place_oy():
		return
	painted = cursor
	painted_off = cursor_off
	painted_oy = place_oy()
	put_part(false)


func finish_select() -> void:
	if not select_drag:
		return
	select_drag = false
	if editor_tool != TOOL_SELECT:
		return
	if select_moved or stamp.is_empty():
		capture_stamp()
	else:
		place_stamp()


func capture_stamp() -> void:
	var x0 := mini(select_from.x, cursor.x)
	var x1 := maxi(select_from.x, cursor.x)
	var z0 := mini(select_from.z, cursor.z)
	var z1 := maxi(select_from.z, cursor.z)
	var layer := select_from.y
	var picked := parts_inside(x0, x1, z0, z1, layer)
	stamp = []
	stamp_rot = 0
	stamp_serial += 1
	stamp_mesh_key = ""
	if picked.is_empty():
		flash("Nothing there")
		return
	var box := stamp_box(picked)
	for src in picked:
		stamp.append((src as Dictionary).duplicate(true))
	stamp_x0 = int(box.x0)
	stamp_x1 = int(box.x1)
	stamp_z0 = int(box.z0)
	stamp_z1 = int(box.z1)
	stamp_anchor = Vector3i(cursor.x, layer, cursor.z)


func parts_inside(x0: int, x1: int, z0: int, z1: int, layer: int) -> Array:
	var picked := {}
	for i in level.parts.size():
		var part: Dictionary = level.parts[i]
		if int(part.y) < layer:
			continue
		if int(part.x) < x0 or int(part.x) > x1 or int(part.z) < z0 or int(part.z) > z1:
			continue
		take_stamp(picked, i)
	var found: Array = []
	for i in level.parts.size():
		if picked.has(i):
			found.append(level.parts[i])
	return found


func stamp_box(parts: Array) -> Dictionary:
	var x0 := 999999
	var x1 := -999999
	var z0 := 999999
	var z1 := -999999
	for src in parts:
		var part: Dictionary = src
		x0 = mini(x0, int(part.x))
		x1 = maxi(x1, int(part.x))
		z0 = mini(z0, int(part.z))
		z1 = maxi(z1, int(part.z))
	return {"x0": x0, "x1": x1, "z0": z0, "z1": z1}


func rotate_stamp(direction: int) -> void:
	if stamp.is_empty() or select_drag:
		return
	stamp_rot = (stamp_rot + direction) & 3


func oriented_stamp() -> Array:
	var turned: Array = []
	for src in stamp:
		turned.append(oriented_part(src))
	return turned


func oriented_part(src: Dictionary) -> Dictionary:
	var part: Dictionary = src.duplicate(true)
	var steps := stamp_rot & 3
	var off := LevelBuild.part_off(part)
	var dx := int(part.x) - stamp_anchor.x
	var dz := int(part.z) - stamp_anchor.z
	var ox := off.x
	var oz := off.y
	for _i in steps:
		var next_dx := -dz
		var next_dz := dx
		dx = next_dx
		dz = next_dz
		var next_ox := -oz
		var next_oz := ox
		ox = next_ox
		oz = next_oz
	part.x = stamp_anchor.x + dx
	part.z = stamp_anchor.z + dz
	if ox == 0:
		part.erase("ox")
	else:
		part.ox = ox
	if oz == 0:
		part.erase("oz")
	else:
		part.oz = oz
	part.rot = (int(part.rot) + steps) & 3
	match_tile_rot(part)
	return part


func match_tile_rot(part: Dictionary) -> void:
	var tiles: Array = LevelBuild.tileset_info(level.tileset).tiles
	var current: Dictionary = tiles[int(part.tile)]
	if String(current.role) == "scenery":
		return
	var rot := int(part.rot) & 3
	for i in tiles.size():
		var other: Dictionary = tiles[i]
		if int(other.piece) != int(part.piece) or int(other.slope) != int(part.slope):
			continue
		if (int(other.rot) & 3) != rot:
			continue
		part.tile = i
		return


func take_stamp(picked: Dictionary, index: int) -> void:
	if picked.has(index):
		return
	picked[index] = true
	var part: Dictionary = level.parts[index]
	var spots: Array = LevelBuild.stamp_cells(part, level.tileset)
	var tile_index := int(part.tile)
	var nudge := LevelBuild.part_off(part)
	var lift := LevelBuild.part_oy(part)
	for other_index in level.parts.size():
		if picked.has(other_index):
			continue
		var other: Dictionary = level.parts[other_index]
		var slot := int(other.slot) if other.has("slot") else 0
		if int(other.tile) != tile_index or slot >= spots.size() or LevelBuild.part_off(other) != nudge or LevelBuild.part_oy(other) != lift:
			continue
		var at: Vector3i = spots[slot]
		if int(other.x) == at.x and int(other.y) == at.y and int(other.z) == at.z:
			picked[other_index] = true


func place_stamp() -> void:
	if stamp.is_empty():
		return
	var dx := cursor.x - stamp_anchor.x
	var dy := cursor.y - stamp_anchor.y
	var dz := cursor.z - stamp_anchor.z
	if dx == 0 and dy == 0 and dz == 0 and (stamp_rot & 3) == 0:
		return
	var stack := stacks()
	for src in oriented_stamp():
		var part: Dictionary = src
		part.x = int(part.x) + dx
		part.y = int(part.y) + dy
		part.z = int(part.z) + dz
		var at := find_same(part) if stack else find_at(int(part.x), int(part.y), int(part.z))
		if at >= 0:
			level.parts[at] = part
		else:
			level.parts.append(part)
		rebake_cell(Vector3i(int(part.x), int(part.y), int(part.z)))
	sync_fields()
	dirty = true


func clear_stamp() -> void:
	stamp = []
	stamp_rot = 0
	select_drag = false
	stamp_serial += 1
	stamp_mesh_key = ""


func set_tool(next: int) -> void:
	var was := editor_tool
	editor_tool = next
	camera_drag = false
	painted = FAR_CELL
	erased = FAR_CELL
	laying = next == TOOL_ROAD and not bool(level.joined)
	if laying and not level.line.is_empty():
		place_from = int(level.line.size()) - 1
	span_node = -1
	select_drag = false
	if next == TOOL_BRUSH:
		paint_facing()
	if was == TOOL_LAP or next == TOOL_LAP:
		rebuild_world()
	elif was == TOOL_CAMERA or next == TOOL_CAMERA or was == TOOL_PICKUP or next == TOOL_PICKUP:
		camera_hot = -2
		refresh_flow()


func shift_down() -> bool:
	return Input.is_physical_key_pressed(KEY_SHIFT) and not typing()


func ctrl_down() -> bool:
	return Input.is_key_pressed(KEY_CTRL) and not typing()


func active_tool() -> int:
	if editor_tool == TOOL_BRUSH and shift_down():
		return TOOL_ERASER
	if editor_tool == TOOL_BRUSH and ctrl_down():
		return TOOL_PICK
	return editor_tool


func wants_erase() -> bool:
	return active_tool() == TOOL_ERASER


func wants_pick() -> bool:
	return active_tool() == TOOL_PICK


func stroke_down() -> void:
	begin_stroke()
	press_node = -1
	press_moved = false
	if editor_tool == TOOL_ROAD and ctrl_down() and not shift_down():
		left_down = false
		var picked := nearest_node(Settings.mouse_position())
		if picked > 0:
			set_start(picked)
		return
	if editor_tool == TOOL_ROAD and shift_down():
		erased = FAR_CELL
		erase_at_cursor()
	elif editor_tool == TOOL_ROAD and pick_span(Settings.mouse_position()).x >= 0:
		var span := pick_span(Settings.mouse_position())
		span_node = span.x
		span_end = span.y
		span_hover = span
		node_held = true
		node_press = Settings.mouse_position()
	elif editor_tool == TOOL_ROAD and nearest_node(Settings.mouse_position()) >= 0:
		var index := nearest_node(Settings.mouse_position())
		if gap_before(index) and can_mend(index):
			var filling := place_from + 1 == index
			mend_gap(index)
			if filling:
				laying = false
		elif laying and index == 0 and not bool(level.joined) and can_close() and anchor_index() >= int(level.line.size()) - 1:
			close_road()
		else:
			drag_node = index
			hover_node = index
			press_node = index
			node_held = true
			node_press = Settings.mouse_position()
	elif editor_tool == TOOL_SELECT:
		select_from = cursor
		select_drag = true
		select_moved = false
	elif wants_pick():
		picked_part = -1
		sample_tile()
	elif wants_erase():
		erased = FAR_CELL
		erase_at_cursor()
	elif editor_tool == TOOL_CAMERA:
		grab_camera()
	elif editor_tool == TOOL_LAP:
		lap_painted = -1
		paint_lap()
	elif editor_tool == TOOL_PICKUP:
		click_pickup()
	else:
		painted = FAR_CELL
		paint_at_cursor()


func stroke_drag() -> void:
	if editor_tool == TOOL_SELECT:
		if cursor != select_from:
			select_moved = true
		return
	if node_held and Settings.mouse_position().distance_to(node_press) < 20.0:
		return
	if node_held:
		press_moved = true
	node_held = false
	if span_node >= 0:
		slide_span()
		return
	if drag_node >= 0:
		slide_node()
		return
	if editor_tool == TOOL_CAMERA:
		slide_camera()
		return
	if editor_tool == TOOL_LAP:
		paint_lap()
		return
	if editor_tool == TOOL_PICKUP:
		return
	if editor_tool == TOOL_ROAD and (shift_down() or not laying):
		return
	elif wants_pick():
		sample_tile()
	elif wants_erase():
		erase_at_cursor()
	else:
		paint_at_cursor()


func sample_tile() -> void:
	var index := part_under_mouse(Settings.mouse_position())
	if index < 0 or index == picked_part:
		return
	picked_part = index
	var part: Dictionary = level.parts[index]
	var stay := editor_tool
	brush_rot = int(part.rot) & 3
	brush_mirror = int(part.mirror) & 3
	brush_slope = int(part.slope)
	brush_lap = int(part.lap) != 0
	set_tile(int(part.tile))
	editor_tool = stay
	paint_facing()
	for button in tile_buttons:
		if int(button.get_meta("tile")) == brush_tile:
			palette_scroll.ensure_control_visible(button)
			return


func anchor_index() -> int:
	var count := int(level.line.size())
	if count == 0:
		return -1
	if place_from >= 0 and place_from < count:
		return place_from
	return count - 1


func start_placing(index: int) -> void:
	var count := int(level.line.size())
	if index < 0 or index >= count:
		laying = true
		return
	place_from = index
	var nxt := index + 1
	if nxt >= count:
		if bool(level.joined):
			level.joined = false
			level.broken = true
			sync_road_cells()
			note_change()
	elif not gap_before(nxt):
		level.gaps.append(nxt)
		sync_road_cells()
		note_change()
	laying = true


func extend_road() -> void:
	if not laying:
		return
	if not road_ok:
		flash("Click the road surface")
		return
	var x := road_units.x
	var y := road_units.y
	var z := road_units.z
	if level.line.is_empty():
		level.line.append(LevelBuild.line_sample(x, y, z, 0))
		place_from = 0
		sync_road_cells()
		note_change()
		return
	var from := anchor_index()
	if bool(level.joined) and from >= int(level.line.size()) - 1:
		flash("Road is closed")
		return
	var anchor: Dictionary = level.line[from]
	var to_anchor := LevelBuild.flat_units(anchor, x, z)
	var other := -1
	if from + 1 < level.line.size() and gap_before(from + 1):
		other = from + 1
	elif from + 1 >= level.line.size() and not bool(level.joined):
		other = 0
	if other >= 0:
		var side: Dictionary = level.line[other]
		var to_side := LevelBuild.flat_units(side, x, z)
		if to_side <= LevelBuild.NODE_CLOSE and to_side < to_anchor and absi(y - int(side.y)) <= 256:
			if other == 0 and can_close():
				close_road()
				return
			if can_mend(other):
				mend_gap(other)
				laying = false
				return
	if to_anchor < LevelBuild.NODE_MIN:
		return
	if to_anchor > LevelBuild.NODE_MAX:
		flash("Stay within a tile of the node")
		return
	var heading := LevelBuild.step_heading(x - int(anchor.x), z - int(anchor.z))
	var at := from + 1
	level.line.insert(at, LevelBuild.line_sample(x, y, z, heading))
	var shifted: Array = []
	for g in level.gaps:
		var gap := int(g)
		if gap >= at:
			shifted.append(gap + 1)
		else:
			shifted.append(gap)
	level.gaps = shifted
	LevelBuild.point_sample(level.line[from], level.line[at])
	place_from = at
	sync_road_cells()
	note_change()


func cut_road() -> void:
	var index := nearest_node(Settings.mouse_position())
	if index < 0:
		return
	var sample: Dictionary = level.line[index]
	var key := Vector3i(int(sample.x), int(sample.y), int(sample.z))
	if key == erased_key:
		return
	erased_key = key
	var owned := undo_scope()
	var count := int(level.line.size())
	var was_joined := bool(level.joined)
	var into := index > 0 and not gap_before(index)
	var onward := index + 1 < count and not gap_before(index + 1)
	var wrap := index + 1 >= count and was_joined and count > 1
	level.line.remove_at(index)
	var gaps: Array = []
	for g in level.gaps:
		var gap := int(g)
		if gap == index:
			if index < count - 1:
				gaps.append(index)
		elif gap > index:
			gaps.append(gap - 1)
		else:
			gaps.append(gap)
	if level.line.is_empty():
		level.joined = false
		level.broken = false
		level.gaps = []
		sync_road_cells()
		note_change()
		undo_scope_end(owned)
		return
	if index == 0 and was_joined:
		level.joined = false
		level.broken = true
		laying = true
		place_from = int(level.line.size()) - 1
	elif wrap:
		level.joined = false
		level.broken = true
		laying = true
		place_from = int(level.line.size()) - 1
	elif into and onward:
		var listed := false
		for g in gaps:
			if int(g) == index:
				listed = true
		if not listed:
			gaps.append(index)
	level.gaps = gaps
	sync_road_cells()
	note_change()
	undo_scope_end(owned)


func slide_node() -> void:
	if not road_ok or drag_node < 0 or drag_node >= level.line.size():
		return
	var sample: Dictionary = level.line[drag_node]
	LevelBuild.shift_sample(sample, road_units.x - int(sample.x), road_units.y - int(sample.y), road_units.z - int(sample.z))
	var count := int(level.line.size())
	var prev := drag_node - 1
	if prev < 0 and bool(level.joined) and count > 1:
		prev = count - 1
	if prev == drag_node - 1 and gap_before(drag_node):
		prev = -1
	var nxt := drag_node + 1
	if nxt >= count:
		nxt = 0 if bool(level.joined) and count > 1 else -1
	if nxt == drag_node + 1 and gap_before(nxt):
		nxt = -1
	if prev >= 0 and prev != drag_node:
		LevelBuild.point_sample(level.line[prev], sample)
	if nxt >= 0 and nxt != drag_node:
		LevelBuild.point_sample(sample, level.line[nxt])
	else:
		var heading := int(sample.h)
		if prev >= 0:
			var stepped := LevelBuild.step_heading(int(sample.x) - int(level.line[prev].x), int(sample.z) - int(level.line[prev].z))
			if stepped >= 0:
				heading = stepped
		LevelBuild.turn_span(sample, heading)
	sync_road_cells()
	refresh_flow()
	dirty = true


func slide_span() -> void:
	if span_node < 0 or span_node >= level.line.size():
		return
	var sample: Dictionary = level.line[span_node]
	var height := LevelBuild.metres(float(sample.y)) + 0.35
	var hit: Variant = Plane(Vector3.UP, height).intersects_ray(view.project_ray_origin(Settings.mouse_position()), view.project_ray_normal(Settings.mouse_position()))
	if hit == null:
		return
	var point: Vector3 = hit
	var x := roundi(point.x / Car.UNIT_METRES)
	var z := roundi(point.z / Car.UNIT_METRES)
	if road_snap:
		var step := road_step()
		x = LevelBuild.snap_unit(x, step)
		z = LevelBuild.snap_unit(z, step)
	var other := Vector2(float(sample.bx if span_end == 0 else sample.ax), float(sample.bz if span_end == 0 else sample.az))
	if Vector2(float(x) - other.x, float(z) - other.y).length() < 64.0:
		return
	if span_end == 0:
		sample.ax = x
		sample.az = z
	else:
		sample.bx = x
		sample.bz = z
	refresh_flow()
	dirty = true


func span_world(sample: Dictionary, end: int) -> Vector3:
	var x := float(sample.ax if end == 0 else sample.bx)
	var z := float(sample.az if end == 0 else sample.bz)
	return Vector3(LevelBuild.metres(x), LevelBuild.metres(float(sample.y)) + 0.35, LevelBuild.metres(z))


func pick_span(screen: Vector2) -> Vector2i:
	var best := Vector2i(-1, 0)
	var best_d := 18.0
	for i in level.line.size():
		var sample: Dictionary = level.line[i]
		for end in 2:
			var point := span_world(sample, end)
			if view.is_position_behind(point):
				continue
			var dist := view.unproject_position(point).distance_to(screen)
			if dist < best_d:
				best_d = dist
				best = Vector2i(i, end)
	if best.x < 0:
		return best
	var node := nearest_node(screen)
	if node >= 0:
		var at: Dictionary = level.line[node]
		var marker := Vector3(LevelBuild.metres(float(at.x)), LevelBuild.metres(float(at.y)) + 0.4, LevelBuild.metres(float(at.z)))
		if not view.is_position_behind(marker) and view.unproject_position(marker).distance_to(screen) <= best_d:
			return Vector2i(-1, 0)
	return best


func nearest_node(screen: Vector2) -> int:
	var best := -1
	var best_d := 28.0
	for i in level.line.size():
		var sample: Dictionary = level.line[i]
		var point := Vector3(LevelBuild.metres(float(sample.x)), LevelBuild.metres(float(sample.y)) + 0.4, LevelBuild.metres(float(sample.z)))
		if view.is_position_behind(point):
			continue
		var dist := view.unproject_position(point).distance_to(screen)
		if dist < best_d:
			best_d = dist
			best = i
	return best


func gap_before(index: int) -> bool:
	for g in level.gaps:
		if int(g) == index:
			return true
	return false


func can_mend(index: int) -> bool:
	if index <= 0 or index >= level.line.size() or not gap_before(index):
		return false
	var prev: Dictionary = level.line[index - 1]
	var nxt: Dictionary = level.line[index]
	var ends := LevelBuild.flat_units(prev, int(nxt.x), int(nxt.z))
	return ends <= LevelBuild.NODE_MAX and absi(int(prev.y) - int(nxt.y)) <= 256


func mend_gap(index: int) -> void:
	LevelBuild.point_sample(level.line[index - 1], level.line[index])
	var kept: Array = []
	for g in level.gaps:
		if int(g) != index:
			kept.append(int(g))
	level.gaps = kept
	if kept.is_empty() and bool(level.joined):
		level.broken = false
	sync_road_cells()
	note_change()
	flash("Gap closed")


func can_close() -> bool:
	if int(level.line.size()) < 4:
		return false
	var first: Dictionary = level.line[0]
	var last: Dictionary = level.line[level.line.size() - 1]
	var ends := LevelBuild.flat_units(last, int(first.x), int(first.z))
	return ends <= LevelBuild.NODE_MAX and absi(int(last.y) - int(first.y)) <= 256


func close_road() -> void:
	var first: Dictionary = level.line[0]
	var last: Dictionary = level.line[level.line.size() - 1]
	LevelBuild.point_sample(last, first)
	level.joined = true
	level.broken = false
	laying = false
	sync_road_cells()
	note_change()
	flash("Road closed")


func set_start(index: int) -> void:
	spin_line(index)


func spin_line(index: int) -> void:
	var count := int(level.line.size())
	if index <= 0 or index >= count:
		return
	var spun: Array = []
	for j in count:
		spun.append(level.line[(index + j) % count])
	var kept: Array = []
	for g in level.gaps:
		var shifted := (int(g) - index + count) % count
		if shifted == 0:
			level.joined = false
			level.broken = true
		else:
			kept.append(shifted)
	level.line = spun
	level.gaps = kept
	sync_road_cells()
	note_change()


func move_start(direction: int) -> void:
	if not level.joined or level.line.size() < 4:
		flash("Close the road first")
		return
	var owned := undo_scope()
	if direction > 0:
		spin_line(1)
	else:
		spin_line(int(level.line.size()) - 1)
	undo_scope_end(owned)


func ask_remove_road() -> void:
	if level.line.is_empty():
		return
	confirm_kind = "road"
	confirm_title.text = "Remove road?"
	confirm_text.text = "This removes every road node. Tiles stay."
	confirm_ok.text = "Remove"
	confirm_ok_action = remove_road
	confirm_extra.visible = false
	show_confirm()


func remove_road() -> void:
	var owned := undo_scope()
	drop_line()
	level.road = []
	laying = editor_tool == TOOL_ROAD
	place_from = -1
	drag_node = -1
	span_node = -1
	hover_node = -1
	camera_node = -1
	camera_drag = false
	note_change()
	undo_scope_end(owned)


func drop_line() -> void:
	level.line = []
	level.joined = false
	level.broken = false
	level.gaps = []


func sync_road_cells() -> void:
	var road: Array = []
	for sample: Dictionary in level.line:
		var cx := LevelBuild.cell_index(int(sample.x))
		var cz := LevelBuild.cell_index(int(sample.z))
		var layer := sample_layer(sample, cx, cz)
		if layer < -1000:
			continue
		if not road.is_empty():
			var prev: Dictionary = road[road.size() - 1]
			if int(prev.x) == cx and int(prev.y) == layer and int(prev.z) == cz:
				continue
		road.append({"x": cx, "y": layer, "z": cz})
	level.road = road


func sample_layer(sample: Dictionary, cx: int, cz: int) -> int:
	var best := -100000
	var best_d := 10000000
	var y := int(sample.y)
	for part: Dictionary in level.parts:
		if int(part.x) != cx or int(part.z) != cz:
			continue
		var base := (int(part.y) + 1) * LevelBuild.layer_step(level.tileset)
		var dist := absi(y - (base + LevelBuild.CELL_U / 2))
		if dist < best_d:
			best_d = dist
			best = int(part.y)
	return best


func capture_level() -> Dictionary:
	return {
		"parts": level.parts.duplicate(true),
		"road": level.road.duplicate(true),
		"line": level.line.duplicate(true),
		"joined": bool(level.joined),
		"broken": bool(level.broken),
		"gaps": level.gaps.duplicate(),
		"name": String(level.name),
		"vehicle": int(level.vehicle),
		"handling": String(level.handling) if level.has("handling") else "",
		"ai": bool(level.ai),
		"tileset": String(level.tileset),
		"laying": laying,
		"place_from": place_from,
		"path": level_path,
		"token": edit_token,
		"untitled": untitled_id,
	}


func begin_stroke() -> void:
	if undo_open:
		return
	undo_mark = capture_level()
	undo_open = true


func end_stroke() -> void:
	if not undo_open:
		return
	undo_open = false
	var now := capture_level()
	if JSON.stringify(now) == JSON.stringify(undo_mark):
		return
	undo_stack.append(undo_mark)
	redo_stack.clear()
	edit_token += 1
	if undo_stack.size() > 100:
		undo_stack.pop_front()


func undo_scope() -> bool:
	if undo_open:
		return false
	begin_stroke()
	return true


func undo_scope_end(owned: bool) -> void:
	if owned:
		end_stroke()


func undo_level() -> void:
	end_stroke()
	if undo_stack.is_empty():
		return
	redo_stack.append(capture_level())
	restore_level(undo_stack.pop_back())


func redo_level() -> void:
	end_stroke()
	if redo_stack.is_empty():
		return
	undo_stack.append(capture_level())
	restore_level(redo_stack.pop_back())


func restore_level(shot: Dictionary) -> void:
	var tileset_changed := String(shot.tileset) != String(level.tileset)
	level.parts = (shot.parts as Array).duplicate(true)
	level.road = (shot.road as Array).duplicate(true)
	level.line = (shot.line as Array).duplicate(true)
	level.gaps = (shot.gaps as Array).duplicate()
	level.joined = bool(shot.joined)
	level.broken = bool(shot.broken)
	level.name = String(shot.name)
	level.vehicle = int(shot.vehicle)
	if String(shot.handling) == "":
		level.erase("handling")
	else:
		level.handling = String(shot.handling)
	level.ai = bool(shot.ai)
	level.tileset = String(shot.tileset)
	laying = bool(shot.laying)
	place_from = int(shot.place_from)
	level_path = String(shot.path)
	edit_token = int(shot.token)
	untitled_id = int(shot.untitled)
	refresh_title()
	if tileset_changed:
		filling_tilesets = true
		tileset_button.select(tileset_index(String(level.tileset)))
		filling_tilesets = false
		rebuild_palette()
		var tiles: Array = LevelBuild.tileset_info(level.tileset).tiles
		if brush_tile >= tiles.size():
			set_tile(piece_tile())
	dirty = true
	rebuild_world()


func note_change() -> void:
	sync_fields()
	refresh_flow()
	refresh_ground()
	dirty = true


func put_part(write_disk: bool) -> void:
	var spots: Array = LevelBuild.footprint_parts(level.tileset, brush_index(), cursor.x, cursor.y, cursor.z, brush_rot, brush_mirror, brush_lap, cursor_off.x, cursor_off.y, place_oy())
	var stack := stacks()
	for spot in spots:
		var part: Dictionary = spot
		var at := find_same(part) if stack else find_at(int(part.x), int(part.y), int(part.z))
		if at >= 0:
			level.parts[at] = part
		else:
			level.parts.append(part)
		rebake_cell(Vector3i(int(part.x), int(part.y), int(part.z)))
	sync_fields()
	if write_disk:
		write_active()
	else:
		dirty = true


func flush() -> void:
	if not dirty:
		return
	write_active()


func erasing() -> bool:
	return wants_erase() or (editor_tool == TOOL_ROAD and shift_down())


func parts_here() -> Array:
	var index := part_at_cursor()
	if index < 0:
		return []
	var part: Dictionary = level.parts[index]
	var found: Array = []
	var spots: Array = LevelBuild.stamp_cells(part, level.tileset)
	var tile_index := int(part.tile)
	var off := LevelBuild.part_off(part)
	var lift := LevelBuild.part_oy(part)
	for other: Dictionary in level.parts:
		var slot := int(other.slot) if other.has("slot") else 0
		if int(other.tile) != tile_index or slot >= spots.size() or LevelBuild.part_off(other) != off or LevelBuild.part_oy(other) != lift:
			continue
		var at: Vector3i = spots[slot]
		if int(other.x) == at.x and int(other.y) == at.y and int(other.z) == at.z:
			found.append(other)
	return found


func erase_at_cursor() -> void:
	if editor_tool == TOOL_ROAD:
		cut_road()
		return
	if erased == cursor and erased_off == cursor_off and erased_oy == place_oy():
		return
	erased = cursor
	erased_off = cursor_off
	erased_oy = place_oy()
	var index := part_at_cursor()
	if index < 0:
		return
	var chosen: Dictionary = level.parts[index]
	var doomed := {}
	var touched: Array = []
	var spots: Array = LevelBuild.stamp_cells(chosen, level.tileset)
	for slot in spots.size():
		var at: Vector3i = spots[slot]
		doomed[Vector4i(at.x, at.y, at.z, slot)] = int(chosen.tile)
		touched.append(at)
	if doomed.is_empty():
		return
	var nudge := LevelBuild.part_off(chosen)
	var kept: Array = []
	for part: Dictionary in level.parts:
		var slot := int(part.slot) if part.has("slot") else 0
		var key := Vector4i(int(part.x), int(part.y), int(part.z), slot)
		if doomed.has(key) and int(doomed[key]) == int(part.tile) and LevelBuild.part_off(part) == nudge and LevelBuild.part_oy(part) == LevelBuild.part_oy(chosen):
			continue
		kept.append(part)
	level.parts = kept
	var flow_changed := prune_road()
	sync_fields()
	for at in touched:
		rebake_cell(at)
	if flow_changed:
		refresh_flow()
	dirty = true


func remove_part() -> void:
	var index := part_at_cursor()
	if index < 0:
		return
	var owned := undo_scope()
	if stacks():
		var chosen: Dictionary = level.parts[index]
		var spots: Array = LevelBuild.stamp_cells(chosen, level.tileset)
		var doomed := {}
		for slot in spots.size():
			var at: Vector3i = spots[slot]
			doomed[Vector4i(at.x, at.y, at.z, slot)] = int(chosen.tile)
		var nudge := LevelBuild.part_off(chosen)
		var kept: Array = []
		for part: Dictionary in level.parts:
			var slot := int(part.slot) if part.has("slot") else 0
			var key := Vector4i(int(part.x), int(part.y), int(part.z), slot)
			if doomed.has(key) and int(doomed[key]) == int(part.tile) and LevelBuild.part_off(part) == nudge and LevelBuild.part_oy(part) == LevelBuild.part_oy(chosen):
				continue
			kept.append(part)
		level.parts = kept
	else:
		level.parts.remove_at(index)
	prune_road()
	commit()
	undo_scope_end(owned)


func prune_road() -> bool:
	var occupied := {}
	for part: Dictionary in level.parts:
		occupied[LevelBuild.key_part(part)] = true
	var kept: Array = []
	for cell: Dictionary in level.road:
		var key := LevelBuild.key_of(int(cell.x), int(cell.y), int(cell.z))
		if occupied.has(key):
			kept.append(cell)
	level.road = kept
	return prune_line()


func prune_line() -> bool:
	var columns := {}
	for part: Dictionary in level.parts:
		columns[Vector2i(int(part.x), int(part.z))] = true
	var drop := {}
	for i in level.line.size():
		var sample: Dictionary = level.line[i]
		var column := Vector2i(LevelBuild.cell_index(int(sample.x)), LevelBuild.cell_index(int(sample.z)))
		if not columns.has(column):
			drop[i] = true
	if drop.is_empty():
		return false
	var old_count := int(level.line.size())
	var old_joined := bool(level.joined)
	var old_gaps := {}
	for g in level.gaps:
		old_gaps[int(g)] = true
	var survivors: Array = []
	var old_index: Array[int] = []
	for i in old_count:
		if drop.has(i):
			continue
		survivors.append(level.line[i])
		old_index.append(i)
	if survivors.is_empty():
		level.line = []
		level.joined = false
		level.broken = false
		level.gaps = []
		sync_road_cells()
		return true
	var gaps: Array = []
	for s in old_index.size() - 1:
		var a: int = old_index[s]
		var b: int = old_index[s + 1]
		if b != a + 1 or old_gaps.has(b):
			gaps.append(s + 1)
	var first: int = old_index[0]
	var last: int = old_index[old_index.size() - 1]
	if old_joined and (first != 0 or last != old_count - 1):
		level.joined = false
		level.broken = true
	level.line = survivors
	level.gaps = gaps
	sync_road_cells()
	return true


func commit() -> void:
	write_active()
	rebuild_world()


func sync_fields() -> void:
	var id := tileset_ids[tileset_button.selected]
	if id != "":
		level.tileset = id


func apply_level_fields() -> void:
	refresh_title()
	var pick := tileset_ids.find(String(level.tileset))
	filling_tilesets = true
	tileset_button.select(tileset_index(String(level.tileset)))
	filling_tilesets = false
	if pick < 0:
		level.tileset = LevelBuild.default_tileset()
		level.parts = []
	rebuild_palette()
	set_tile(piece_tile())


func save_key() -> String:
	if level_path != "":
		return level_path
	return "new:%d" % untitled_id


func has_unsaved() -> bool:
	return int(saved_token.get(save_key(), -1)) != edit_token


func write_active() -> void:
	sync_fields()
	level.source = level_path
	level.unsaved = has_unsaved()
	LevelBuild.save_level(level, LevelBuild.ACTIVE)
	level.erase("source")
	level.erase("unsaved")
	dirty = false


func write_file(path: String, display_name: String) -> void:
	level.name = display_name
	refresh_title()
	sync_fields()
	LevelBuild.save_level(level, path)
	level_path = path
	saved_token[path] = edit_token
	write_active()


func save_current() -> void:
	end_stroke()
	var typed := String(level.name).strip_edges()
	if level_path == "" or typed == "":
		open_save_dialog()
		return
	write_file(level_path, typed)
	finish_save()


func open_save_dialog() -> void:
	end_stroke()
	fill_save_list()
	filling_save = true
	save_name.text = String(level.name)
	filling_save = false
	save_target = ""
	save_dialog.visible = true
	save_name.grab_focus()
	save_name.select_all()


func cancel_save_dialog() -> void:
	save_dialog.visible = false
	after_save = ""


func commit_save_dialog() -> void:
	var typed := save_name.text.strip_edges()
	if typed == "":
		flash("Name the track")
		return
	var path := save_target if save_target != "" else LevelBuild.named_path(typed)
	if FileAccess.file_exists(path) and path != level_path:
		pending_action = path
		confirm_kind = "overwrite"
		confirm_title.text = "Replace track?"
		confirm_text.text = "A track named %s is already saved." % typed
		confirm_ok.text = "Replace"
		confirm_ok_action = replace_save
		confirm_extra.visible = false
		show_confirm()
		return
	write_file(path, typed)
	finish_save()


func replace_save() -> void:
	var path := pending_action
	pending_action = ""
	write_file(path, save_name.text.strip_edges())
	finish_save()


func finish_save() -> void:
	save_dialog.visible = false
	flash("Saved %s" % String(level.name))
	if after_save != "":
		var next := after_save
		after_save = ""
		run_pending(next)


func pick_save_target(path: String, label: String) -> void:
	filling_save = true
	save_name.text = label
	save_target = path
	filling_save = false


func on_save_text(_text: String) -> void:
	if filling_save:
		return
	save_target = ""


func on_save_submitted(_text: String) -> void:
	commit_save_dialog()


func try_close(next: String) -> void:
	end_stroke()
	if not has_unsaved():
		run_pending(next)
		return
	pending_action = next
	pause_menu.visible = false
	confirm_kind = "unsaved"
	confirm_title.text = "Unsaved changes"
	confirm_text.text = "Save this track before closing it?"
	confirm_ok.text = "Save"
	confirm_ok_action = save_then_continue
	confirm_extra.text = "Don't save"
	confirm_extra.visible = true
	confirm_extra_action = discard_then_continue
	show_confirm()


func save_then_continue() -> void:
	after_save = pending_action
	pending_action = ""
	save_current()


func discard_then_continue() -> void:
	var next := pending_action
	pending_action = ""
	run_pending(next)


func run_pending(next: String) -> void:
	if next == "new":
		begin_new()
	elif next == "leave":
		leave()
	elif next.begins_with("load:"):
		load_from(next.substr(5))


func load_from(path: String) -> void:
	var owned := undo_scope()
	camera_memory = []
	battle_memory = []
	clear_stamp()
	level = LevelBuild.load_level(path)
	level.erase("source")
	level.erase("unsaved")
	apply_level_fields()
	frame_level()
	rebuild_world()
	enter_editor()
	flash("Loaded %s" % String(level.name))
	undo_scope_end(owned)
	if path.begins_with("user://"):
		level_path = path
	else:
		level_path = ""
		untitled_id += 1
	saved_token[save_key()] = edit_token
	write_active()


func begin_new() -> void:
	var owned := undo_scope()
	camera_memory = []
	battle_memory = []
	clear_stamp()
	level = LevelBuild.blank()
	apply_level_fields()
	focus = Vector3.ZERO
	cursor = Vector3i.ZERO
	rebuild_world()
	enter_editor()
	flash("New track")
	undo_scope_end(owned)
	level_path = ""
	untitled_id += 1
	saved_token[save_key()] = edit_token
	write_active()


func play(trial: bool) -> void:
	flush()
	sync_fields()
	if bool(level.broken) or not level.gaps.is_empty():
		flash("Road is broken")
		return
	if level.line.size() < 4 or not level.joined:
		flash("Draw a closed road first")
		return
	write_active()
	var course := level
	var out := LevelBuild.play_dir(int(level.vehicle))
	Session.editor_return = SCENE
	Session.time_trial = trial
	if trial:
		Session.trial_turn = 0
		Session.trial_models = PackedInt32Array([MainMenu.race_model])
		Session.trial_controls = PackedStringArray([""])
		Battle.players = 0
	else:
		Battle.players = 2
		Battle.wins.fill(0)
		Session.rebind_pads()
	Sound.depart(func() -> void: Session.play_level(course, out))


func leave() -> void:
	flush()
	Session.editor_return = ""
	Session.time_trial = false
	Battle.players = 0
	Sound.depart(func() -> void: Wipe.to(MainMenu.SCENE))


func flash(text: String) -> void:
	notice = text
	notice_time = 2.4


func camera_readout(parent: Node) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiTheme.CREAM)
	parent.add_child(label)
	return label


func paint_camera_detail() -> void:
	var index := active_camera_node()
	if index < 0:
		camera_type_button.text = "[T] Type"
		camera_yaw_label.text = "Yaw"
		camera_pitch_label.text = "Pitch"
		camera_distance_label.text = "Distance"
		return
	var cam := node_camera(index)
	camera_type_button.text = "[T] %s" % LevelBuild.cam_type_name(int(cam[0]))
	camera_yaw_label.text = "Yaw %d°" % roundi(float(int(cam[1])) * 11.25)
	var step := LevelBuild.pitch_step(int(cam[2]))
	if step > 0:
		camera_pitch_label.text = "Pitch up %d" % step
	elif step < 0:
		camera_pitch_label.text = "Pitch down %d" % -step
	else:
		camera_pitch_label.text = "Pitch level"
	var metres := roundi(LevelBuild.camera_metres(int(cam[0]), int(cam[3])))
	camera_distance_label.text = "Distance %d · %d m" % [int(cam[3]), metres]


func refresh_title() -> void:
	var title := String(level.name)
	if has_unsaved():
		title += " •"
	level_title.text = title


func paint_status() -> void:
	refresh_title()
	layout_side()
	lap_button.text = "[L] On the path" if brush_lap else "[L] Off the path"
	road_snap_button.text = "[G] Snap" if road_snap else "[G] Free"
	paint_tools()
	if cursor_oy == 0 or active_height() <= 1:
		layer_label.text = "Layer %d" % cursor.y
	else:
		layer_label.text = "Layer %d +%d" % [cursor.y, cursor_oy]
	paint_camera_detail()
	var here := "Empty"
	var road_index := part_at_cursor()
	if road_index >= 0:
		var part: Dictionary = level.parts[road_index]
		here = String(LevelBuild.tile_def(level.tileset, int(part.tile)).name)
		if int(part.piece) == LevelBuild.Piece.SCENERY and int(part.rot) != 0:
			here += " facing %s" % LevelBuild.facing_name(int(part.rot))
		if int(part.piece) == LevelBuild.Piece.SCENERY and int(part.mirror) != 0:
			here += " mirrored"
		if int(part.piece) == LevelBuild.Piece.SCENERY and int(part.lap) == 0:
			here += ", off the path"
	for cell: Dictionary in level.road:
		if int(cell.x) == cursor.x and int(cell.y) == cursor.y and int(cell.z) == cursor.z:
			here = "Road" if here == "Empty" else here + ", road"
	if editor_tool == TOOL_LAP:
		here = "Empty"
		if hover_part >= 0:
			var hovered: Dictionary = level.parts[hover_part]
			here = String(LevelBuild.tile_def(level.tileset, int(hovered.tile)).name)
			if int(hovered.piece) == LevelBuild.Piece.SCENERY:
				here += ", on the path" if LevelBuild.on_lap(hovered) else ", off the path"
	elif editor_tool == TOOL_CAMERA:
		var shown := active_camera_node()
		here = "Node %d" % shown if shown >= 0 else "No node"
	elif editor_tool == TOOL_SELECT and not stamp.is_empty() and not select_drag:
		here = "%d tiles" % stamp.size()
		if stamp_rot != 0:
			here += " facing %s" % LevelBuild.facing_name(stamp_rot)
	elif editor_tool == TOOL_PICKUP:
		here = "No spot"
		var spot := hover_spot
		if spot.x < 0 and picked_valid():
			spot = Vector2i(picked_pickup.x, int(picked_entry()[2]))
		if spot.x >= 0:
			here = "Node %d %s" % [spot.x, LevelBuild.LANE_NAMES[spot.y].to_lower()]
			for k in spot_entries(spot):
				here += " · " + pickup_text(level.line[spot.x].pickups[k])
	status_label.text = here
	var message := ""
	var gapped: bool = not level.gaps.is_empty()
	var failed: bool = bool(level.broken) or gapped
	if editor_tool == TOOL_LAP:
		message = "[L] Switch    [Drag] On the path" if brush_lap else "[L] Switch    [Drag] Off the path"
	elif editor_tool == TOOL_CAMERA:
		if level.line.is_empty():
			message = "Place a road first"
		else:
			message = "[Click] Node    [Drag] Pitch and distance    [Q/E] Yaw    [T] Type"
	elif editor_tool == TOOL_SELECT:
		if notice_time > 0.0:
			message = notice
		elif select_drag:
			var wide := absi(cursor.x - select_from.x) + 1
			var deep := absi(cursor.z - select_from.z) + 1
			var noun := "tile" if select_count == 1 else "tiles"
			message = "Selecting %d×%d · %d %s" % [wide, deep, select_count, noun]
		elif stamp.is_empty():
			message = "[Drag] Select cells"
		else:
			message = "[Q/E] Rotate    [Click] Place copy    [Drag] Select again"
	elif editor_tool == TOOL_PICKUP and notice_time <= 0.0:
		if level.line.is_empty():
			message = "Place a road first"
		else:
			message = "[Click] Place or select    [Ctrl+Click] Stack    [Shift+Click] Remove    [T] Item    [K] Lap"
	elif editor_tool == TOOL_ROAD and span_hover.x >= 0:
		message = "[Drag] Wreck span"
	elif active_tool() == TOOL_ROAD and laying:
		message = "[Click] Place node    [G] Snap" if road_snap else "[Click] Place node    [G] Free"
	elif gapped:
		message = "Road is broken    [Click] Join gap"
	elif failed:
		message = "Road is broken    [Click node] Place    [Click start] Close road"
	elif notice_time > 0.0:
		message = notice
	message_label.text = message
	message_label.add_theme_color_override("font_color", Color(1.0, 0.34, 0.38) if failed else UiTheme.CREAM)
	var panel_style := editor_panel()
	if failed:
		panel_style.bg_color = Color(0.32, 0.03, 0.06, 0.96)
		panel_style.border_color = Color(1.0, 0.28, 0.32)
	message_panel.add_theme_stylebox_override("panel", panel_style)
	message_panel.visible = message != ""


func world_groups() -> Dictionary:
	var groups := {}
	for part: Dictionary in level.parts:
		var key := Vector3i(int(part.x), int(part.y), int(part.z))
		var list: Array = groups.get(key, [])
		list.append(part)
		groups[key] = list
	return groups


func seal_world() -> void:
	tiles_dirty = false
	upload_world()
	refresh_flow()
	ghost_revision = ""
	erase_revision = ""


func rebuild_world() -> void:
	cell_visuals.clear()
	var groups := world_groups()
	for key: Vector3i in groups:
		cell_visuals[key] = LevelBuild.visual_buckets(groups[key], level.tileset, editor_tool == TOOL_LAP)
	seal_world()


func rebuild_async() -> void:
	cell_visuals.clear()
	var groups := world_groups()
	var keys: Array = groups.keys()
	var denom := maxi(keys.size(), 1)
	for i in keys.size():
		var key: Vector3i = keys[i]
		cell_visuals[key] = LevelBuild.visual_buckets(groups[key], level.tileset, editor_tool == TOOL_LAP)
		await Wipe.breathe(float(i + 1) / float(denom))
	seal_world()


func rebake_cell(key: Vector3i) -> void:
	var parts: Array = []
	for part: Dictionary in level.parts:
		if int(part.x) == key.x and int(part.y) == key.y and int(part.z) == key.z:
			parts.append(part)
	if parts.is_empty():
		cell_visuals.erase(key)
	else:
		cell_visuals[key] = LevelBuild.visual_buckets(parts, level.tileset, editor_tool == TOOL_LAP)
	tiles_dirty = true


func flush_tiles() -> void:
	if not tiles_dirty:
		return
	tiles_dirty = false
	upload_world()


func upload_world() -> void:
	if world_mesh == null:
		world_mesh = MeshInstance3D.new()
		world.add_child(world_mesh)
	var single_pos := PackedVector3Array()
	var single_nrm := PackedVector3Array()
	var single_col := PackedColorArray()
	var single_uv := PackedVector2Array()
	var double_pos := PackedVector3Array()
	var double_nrm := PackedVector3Array()
	var double_col := PackedColorArray()
	var double_uv := PackedVector2Array()
	for visual: Dictionary in cell_visuals.values():
		var single: Dictionary = visual.single
		single_pos.append_array(single.pos)
		single_nrm.append_array(single.nrm)
		single_col.append_array(single.col)
		single_uv.append_array(single.uv)
		var doubled: Dictionary = visual.double
		double_pos.append_array(doubled.pos)
		double_nrm.append_array(doubled.nrm)
		double_col.append_array(doubled.col)
		double_uv.append_array(doubled.uv)
	var texture: Texture2D = null
	if String(level.tileset) != "":
		texture = LevelBuild.tileset_info(level.tileset).atlas
	world_mesh.mesh = LevelBuild.make_mesh({
		"single": {"pos": single_pos, "nrm": single_nrm, "col": single_col, "uv": single_uv},
		"double": {"pos": double_pos, "nrm": double_nrm, "col": double_col, "uv": double_uv},
	}, texture)
	refresh_ground()


func refresh_flow() -> void:
	if show_road or editor_tool == TOOL_CAMERA or editor_tool == TOOL_PICKUP:
		flow.mesh = LevelBuild.flow_mesh(level.parts, level.tileset, level.road, level.line, level.joined, level.broken, level.gaps)
	else:
		flow.mesh = null
	refresh_camera_view()


func refresh_road_guide() -> void:
	if editor_tool != TOOL_ROAD:
		road_guide.mesh = null
		return
	var placing := laying and road_ok and drag_node < 0 and not node_held and not shift_down()
	road_guide.mesh = LevelBuild.road_guide(level.line, hover_node, road_at + Vector3.UP * 0.6, placing, span_hover.x, span_hover.y, anchor_index())


func refresh_camera_view() -> void:
	if not show_cameras and editor_tool != TOOL_CAMERA:
		camera_view.mesh = null
		return
	var hot := -1
	if editor_tool == TOOL_CAMERA:
		hot = hover_node if hover_node >= 0 else camera_node
	camera_view.mesh = LevelBuild.camera_view_mesh(level.line, hot)


func refresh_erase() -> void:
	if editor_tool == TOOL_ROAD:
		erase_mesh.mesh = null
		erase_revision = ""
		return
	var picking := wants_pick()
	var on := erasing()
	var signature := "%d:%d:%d:%d:%d:%d" % [1 if on else 0, 1 if picking else 0, cursor.x, cursor.y, cursor.z, hover_part]
	if signature == erase_revision:
		return
	erase_revision = signature
	var hovered: Array = []
	if picking and hover_part >= 0:
		hovered = [level.parts[hover_part]]
	elif on:
		hovered = parts_here()
	if hovered.is_empty():
		erase_mesh.mesh = null
		return
	var mesh := LevelBuild.preview_mesh(hovered, level.tileset)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.25, 0.72, 1.0) if picking else Color(1.0, 0.25, 0.25)
	for surface in mesh.get_surface_count():
		mesh.surface_set_material(surface, material)
	erase_mesh.mesh = mesh
	erase_mesh.position = Vector3(0.0, 0.08, 0.0)


func refresh_select_tint() -> void:
	if editor_tool != TOOL_SELECT or (not select_drag and stamp.is_empty()):
		select_count = 0
		if select_tint_key != "":
			select_tint_key = ""
			select_tint.mesh = null
		return
	if select_drag:
		var x0 := mini(select_from.x, cursor.x)
		var x1 := maxi(select_from.x, cursor.x)
		var z0 := mini(select_from.z, cursor.z)
		var z1 := maxi(select_from.z, cursor.z)
		var key := "%d:%d:%d:%d:%d:%d" % [x0, x1, z0, z1, select_from.y, level.parts.size()]
		if key == select_tint_key:
			return
		var parts := parts_inside(x0, x1, z0, z1, select_from.y)
		select_count = parts.size()
		select_tint_key = key
		paint_select_tint(parts)
		return
	select_count = stamp.size()
	var held := "s:%d" % stamp_serial
	if held == select_tint_key:
		return
	select_tint_key = held
	paint_select_tint(stamp)


func paint_select_tint(parts: Array) -> void:
	if parts.is_empty():
		select_tint.mesh = null
		return
	var mesh := LevelBuild.make_mesh(LevelBuild.visual_buckets(parts, level.tileset, false, Color(1.0, 0.86, 0.05)), null)
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as StandardMaterial3D
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	select_tint.mesh = mesh
	select_tint.position = Vector3(0.0, 0.08, 0.0)


func rebuild_ghost() -> void:
	ghost_revision = signature_now()
	var spots: Array = LevelBuild.footprint_parts(level.tileset, brush_index(), cursor.x, cursor.y, cursor.z, brush_rot, brush_mirror, brush_lap, cursor_off.x, cursor_off.y, place_oy())
	var mesh := LevelBuild.preview_mesh(spots, level.tileset)
	for surface in mesh.get_surface_count():
		var material := (mesh.surface_get_material(surface) as StandardMaterial3D).duplicate()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(material.albedo_color, 0.9)
		mesh.surface_set_material(surface, material)
	var flow := LevelBuild.flow_mesh(spots, level.tileset)
	var flow_material := StandardMaterial3D.new()
	flow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flow_material.vertex_color_use_as_albedo = true
	for surface in flow.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flow.surface_get_arrays(surface))
		mesh.surface_set_material(mesh.get_surface_count() - 1, flow_material)
	ghost.mesh = mesh
	ghost.position = Vector3(0.0, 0.12, 0.0)


func refresh_stamp_ghost() -> void:
	if stamp.is_empty() or select_drag:
		ghost.mesh = null
		stamp_mesh_key = ""
		return
	var key := "%s:%d:%d" % [level.tileset, stamp_serial, stamp_rot]
	if key != stamp_mesh_key:
		stamp_mesh_key = key
		rebuild_stamp_ghost()
	ghost.position = stamp_shift()


func stamp_shift() -> Vector3:
	var dx := cursor.x - stamp_anchor.x
	var dy := cursor.y - stamp_anchor.y
	var dz := cursor.z - stamp_anchor.z
	var y := LevelBuild.metres(float(dy * LevelBuild.layer_step(level.tileset)))
	return Vector3(LevelBuild.metres(float(dx * LevelBuild.CELL_U)), y + 0.12, LevelBuild.metres(float(dz * LevelBuild.CELL_U)))


func rebuild_stamp_ghost() -> void:
	var turned := oriented_stamp()
	var mesh := LevelBuild.preview_mesh(turned, level.tileset)
	for surface in mesh.get_surface_count():
		var material := (mesh.surface_get_material(surface) as StandardMaterial3D).duplicate()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(material.albedo_color, 0.9)
		mesh.surface_set_material(surface, material)
	var arrows := LevelBuild.flow_mesh(turned, level.tileset)
	var flow_material := StandardMaterial3D.new()
	flow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flow_material.vertex_color_use_as_albedo = true
	for surface in arrows.get_surface_count():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrows.surface_get_arrays(surface))
		mesh.surface_set_material(mesh.get_surface_count() - 1, flow_material)
	ghost.mesh = mesh


func snapped_focus() -> Vector2i:
	var step := LevelBuild.metres(LevelBuild.CELL_U)
	return Vector2i(roundi(focus.x / step), roundi(focus.z / step))


func grid_cells() -> int:
	var step := LevelBuild.metres(LevelBuild.CELL_U)
	return clampi(ceili(orbit_distance / step) + 4, 8, 40)


func refresh_ground() -> void:
	var info := LevelBuild.tileset_info(level.tileset)
	if not info.has("ground"):
		ground.mesh = null
		return
	var bounds := LevelBuild.ground_bounds(level.parts, level.line)
	var single := LevelBuild.mesh_bucket()
	var discard := PackedVector3Array()
	var y := LevelBuild.cell_plane(0, level.tileset) - LevelBuild.metres(2.0)
	LevelBuild.paint_ground(single, discard, level.tileset, bounds, y, false)
	ground.mesh = LevelBuild.make_mesh({"single": single, "double": LevelBuild.mesh_bucket()}, info.atlas)


func rebuild_grid() -> void:
	var step := LevelBuild.metres(LevelBuild.CELL_U)
	var span := grid_cells()
	var origin := snapped_focus()
	grid_key = Vector3i(origin.x, cursor.y, origin.y)
	grid_span = span
	grid_tileset = level.tileset
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	var y := LevelBuild.cell_plane(cursor.y, level.tileset) + 0.03
	var x0 := (float(origin.x - span) - 0.5) * step
	var x1 := (float(origin.x + span) + 0.5) * step
	var z0 := (float(origin.y - span) - 0.5) * step
	var z1 := (float(origin.y + span) + 0.5) * step
	for i in range(-span, span + 1):
		var edge_x := origin.x + i
		var edge_z := origin.y + i
		var across := Color(0.99, 0.88, 0.58, 0.9) if edge_x == -1 or edge_x == 0 else Color(1, 1, 1, 0.45)
		var along := Color(0.99, 0.88, 0.58, 0.9) if edge_z == -1 or edge_z == 0 else Color(1, 1, 1, 0.45)
		var x := (float(edge_x) + 0.5) * step
		var z := (float(edge_z) + 0.5) * step
		tool.set_color(across)
		tool.add_vertex(Vector3(x, y, z0))
		tool.set_color(across)
		tool.add_vertex(Vector3(x, y, z1))
		tool.set_color(along)
		tool.add_vertex(Vector3(x0, y, z))
		tool.set_color(along)
		tool.add_vertex(Vector3(x1, y, z))
	if grid_div > 1:
		var minor := Color(1, 1, 1, 0.22)
		var fine := LevelBuild.metres(float(LevelBuild.CELL_U / grid_div))
		var x_start := ceili(x0 / fine - 0.5)
		var x_end := floori(x1 / fine - 0.5)
		for k in range(x_start, x_end + 1):
			var fx := (float(k) + 0.5) * fine
			tool.set_color(minor)
			tool.add_vertex(Vector3(fx, y, z0))
			tool.set_color(minor)
			tool.add_vertex(Vector3(fx, y, z1))
		var z_start := ceili(z0 / fine - 0.5)
		var z_end := floori(z1 / fine - 0.5)
		for k in range(z_start, z_end + 1):
			var fz := (float(k) + 0.5) * fine
			tool.set_color(minor)
			tool.add_vertex(Vector3(x0, y, fz))
			tool.set_color(minor)
			tool.add_vertex(Vector3(x1, y, fz))
	if grid_fine:
		var fine_step := LevelBuild.metres(float(LevelBuild.CELL_U / 16))
		var minor := Color(1, 1, 1, 0.16)
		var x_start := ceili(x0 / fine_step)
		var x_end := floori(x1 / fine_step)
		for k in range(x_start, x_end + 1):
			if (k + 8) % 16 == 0:
				continue
			var fx := float(k) * fine_step
			tool.set_color(minor)
			tool.add_vertex(Vector3(fx, y, z0))
			tool.set_color(minor)
			tool.add_vertex(Vector3(fx, y, z1))
		var z_start := ceili(z0 / fine_step)
		var z_end := floori(z1 / fine_step)
		for k in range(z_start, z_end + 1):
			if (k + 8) % 16 == 0:
				continue
			var fz := float(k) * fine_step
			tool.set_color(minor)
			tool.add_vertex(Vector3(x0, y, fz))
			tool.set_color(minor)
			tool.add_vertex(Vector3(x1, y, fz))
	grid.mesh = tool.commit()


func rebuild_cursor_box() -> void:
	if editor_tool == TOOL_SELECT:
		rebuild_select_cursor()
		return
	if editor_tool == TOOL_ROAD:
		rebuild_road_cursor()
		return
	if wants_pick() or editor_tool == TOOL_LAP:
		rebuild_pick_cursor()
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	var y := LevelBuild.cell_plane(cursor.y, level.tileset) + LevelBuild.metres(float(place_oy())) + 0.08
	var center := LevelBuild.cell_center(cursor.x, cursor.z) + Vector3(LevelBuild.metres(float(cursor_off.x)), 0.0, LevelBuild.metres(float(cursor_off.y)))
	var half := LevelBuild.metres(float(LevelBuild.CELL_U / snap_div()) * 0.5)
	var corners: Array[Vector3] = [
		center + Vector3(-half, y, -half),
		center + Vector3(half, y, -half),
		center + Vector3(half, y, half),
		center + Vector3(-half, y, half),
	]
	var color := Color(0.95, 0.22, 0.18, 1.0) if erasing() else Color(0.99, 0.88, 0.58, 1.0)
	for i in 4:
		tool.set_color(color)
		tool.add_vertex(corners[i])
		tool.set_color(color)
		tool.add_vertex(corners[(i + 1) % 4])
	cursor_box.mesh = tool.commit()


func rebuild_select_cursor() -> void:
	var lines := SurfaceTool.new()
	lines.begin(Mesh.PRIMITIVE_LINES)
	var gold := Color(0.99, 0.88, 0.58, 1.0)
	var cyan := Color(0.45, 0.92, 1.0, 1.0)
	if select_drag:
		add_rect(lines, select_from.x, select_from.z, cursor.x, cursor.z, select_from.y, gold, 0.1)
	elif not stamp.is_empty():
		add_rect(lines, stamp_x0, stamp_z0, stamp_x1, stamp_z1, stamp_anchor.y, cyan, 0.08)
		var dx := cursor.x - stamp_anchor.x
		var dy := cursor.y - stamp_anchor.y
		var dz := cursor.z - stamp_anchor.z
		var box := stamp_box(oriented_stamp())
		if dx != 0 or dy != 0 or dz != 0 or (stamp_rot & 3) != 0:
			add_rect(lines, int(box.x0) + dx, int(box.z0) + dz, int(box.x1) + dx, int(box.z1) + dz, cursor.y, gold, 0.14)
	else:
		add_rect(lines, cursor.x, cursor.z, cursor.x, cursor.z, cursor.y, gold, 0.1)
	cursor_box.mesh = lines.commit()


func add_rect(lines: SurfaceTool, x0: int, z0: int, x1: int, z1: int, layer: int, color: Color, lift: float) -> void:
	var step := LevelBuild.metres(float(LevelBuild.CELL_U))
	var y := LevelBuild.cell_plane(layer, level.tileset) + lift
	var min_x := (float(mini(x0, x1)) - 0.5) * step
	var max_x := (float(maxi(x0, x1)) + 0.5) * step
	var min_z := (float(mini(z0, z1)) - 0.5) * step
	var max_z := (float(maxi(z0, z1)) + 0.5) * step
	var corners: Array[Vector3] = [
		Vector3(min_x, y, min_z),
		Vector3(max_x, y, min_z),
		Vector3(max_x, y, max_z),
		Vector3(min_x, y, max_z),
	]
	for i in 4:
		lines.set_color(color)
		lines.add_vertex(corners[i])
		lines.set_color(color)
		lines.add_vertex(corners[(i + 1) % 4])


func rebuild_pick_cursor() -> void:
	if hover_part < 0:
		cursor_box.mesh = null
		return
	var part: Dictionary = level.parts[hover_part]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	var y := LevelBuild.cell_plane(int(part.y), level.tileset) + LevelBuild.part_lift(part) + 0.08
	var center := LevelBuild.cell_center(int(part.x), int(part.z)) + LevelBuild.part_nudge(part)
	var half := LevelBuild.metres(256.0)
	var corners: Array[Vector3] = [
		center + Vector3(-half, y, -half),
		center + Vector3(half, y, -half),
		center + Vector3(half, y, half),
		center + Vector3(-half, y, half),
	]
	var color := Color(0.45, 0.92, 1.0, 1.0)
	for i in 4:
		tool.set_color(color)
		tool.add_vertex(corners[i])
		tool.set_color(color)
		tool.add_vertex(corners[(i + 1) % 4])
	cursor_box.mesh = tool.commit()


func rebuild_road_cursor() -> void:
	var point := road_at
	var show := road_ok and hover_node < 0 and bool(level.joined)
	if erasing():
		var index := nearest_node(Settings.mouse_position())
		if index >= 0:
			var sample: Dictionary = level.line[index]
			point = Vector3(LevelBuild.metres(float(sample.x)), LevelBuild.metres(float(sample.y)), LevelBuild.metres(float(sample.z)))
			show = true
		else:
			show = false
	if not show:
		cursor_box.mesh = null
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_LINES)
	var center := point + Vector3.UP * 0.15
	var span := 0.45
	var corners: Array[Vector3] = [
		center + Vector3(-span, 0.0, -span),
		center + Vector3(span, 0.0, -span),
		center + Vector3(span, 0.0, span),
		center + Vector3(-span, 0.0, span),
	]
	var color := Color(0.95, 0.22, 0.18, 1.0) if erasing() else Color(0.99, 0.88, 0.58, 1.0)
	for i in 4:
		tool.set_color(color)
		tool.add_vertex(corners[i])
		tool.set_color(color)
		tool.add_vertex(corners[(i + 1) % 4])
	cursor_box.mesh = tool.commit()


func build_view() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.52, 0.6)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.62, 0.64)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	sun.look_at_from_position(Vector3(0.4, 1.0, 0.3), Vector3.ZERO)
	world = Node3D.new()
	add_child(world)
	ground = MeshInstance3D.new()
	world.add_child(ground)
	ghost = MeshInstance3D.new()
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ghost)
	erase_mesh = MeshInstance3D.new()
	erase_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(erase_mesh)
	select_tint = MeshInstance3D.new()
	select_tint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(select_tint)
	grid = line_mesh()
	add_child(grid)
	cursor_box = line_mesh()
	add_child(cursor_box)
	flow = road_overlay(10)
	add_child(flow)
	road_guide = road_overlay(12)
	add_child(road_guide)
	camera_view = road_overlay(14)
	add_child(camera_view)
	pickup_view = road_overlay(16)
	add_child(pickup_view)
	view = Camera3D.new()
	view.current = true
	add_child(view)


func road_overlay(priority: int) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.render_priority = priority
	material.vertex_color_use_as_albedo = true
	mesh.material_override = material
	return mesh


func line_mesh() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = material
	return mesh


func build_ui() -> void:
	idle_style = tool_style(UiTheme.ACCENT, UiTheme.LIP)
	selected_style = tool_style(UiTheme.CREAM, UiTheme.CORAL)
	toolbox_idle = tool_style(UiTheme.ACCENT, UiTheme.LIP)
	toolbox_on = tool_style(UiTheme.CREAM, UiTheme.CORAL)
	for style in [toolbox_idle, toolbox_on]:
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 2
	tile_off = palette_style(false)
	tile_on = palette_style(true)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.theme()
	layer.add_child(root)
	build_top(root)
	build_tools(root)
	build_bottom(root)
	build_picker(root)
	build_entry(root)
	build_pause(root)
	build_save_dialog(root)
	build_settings(root)
	build_confirm(root)
	fill_tilesets()


func build_top(root: Control) -> void:
	var panel := chrome(0, 0, 0, 40, Control.PRESET_TOP_WIDE)
	var bar_style := editor_panel()
	bar_style.content_margin_left = 8
	bar_style.content_margin_right = 12
	bar_style.content_margin_top = 2
	bar_style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", bar_style)
	root.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var file_menu := menu_popup(row, "File")
	add_menu_item(file_menu, "New", 0, KEY_MASK_CTRL | KEY_N)
	add_menu_item(file_menu, "Load...", 1, KEY_MASK_CTRL | KEY_O)
	file_menu.add_separator()
	add_menu_item(file_menu, "Save", 2, KEY_MASK_CTRL | KEY_S)
	add_menu_item(file_menu, "Save As...", 3, KEY_MASK_CTRL | KEY_MASK_SHIFT | KEY_S)
	file_menu.add_separator()
	add_menu_item(file_menu, "Quit", 4, 0)
	file_menu.id_pressed.connect(on_file_menu)
	var edit_menu := menu_popup(row, "Edit")
	add_menu_item(edit_menu, "Undo", 0, KEY_MASK_CTRL | KEY_Z)
	add_menu_item(edit_menu, "Redo", 1, KEY_MASK_CTRL | KEY_Y)
	edit_menu.add_separator()
	add_menu_item(edit_menu, "Remove Road...", 3, 0)
	edit_menu.add_separator()
	add_menu_item(edit_menu, "Level Settings...", 2, 0)
	edit_menu.id_pressed.connect(on_edit_menu)
	view_menu = menu_popup(row, "View")
	view_menu.add_check_item("Road", 1)
	view_menu.add_check_item("Cameras", 0)
	view_menu.set_item_checked(0, true)
	view_menu.id_pressed.connect(on_view_menu)
	level_title = Label.new()
	level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	level_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_title.add_theme_font_size_override("font_size", 16)
	level_title.add_theme_color_override("font_color", UiTheme.CREAM)
	level_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(level_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(16, 0)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	var runs := HBoxContainer.new()
	runs.add_theme_constant_override("separation", 8)
	runs.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(runs)
	run_button(runs, "Trial", true)
	run_button(runs, "Battle", false)


func menu_popup(parent: Node, title: String) -> PopupMenu:
	var button := MenuButton.new()
	button.text = title
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var font := UiTheme.font()
	button.custom_minimum_size = Vector2(ceil(font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 24, 32)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UiTheme.CREAM)
	button.add_theme_color_override("font_hover_color", UiTheme.INK)
	button.add_theme_color_override("font_pressed_color", UiTheme.INK)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.INK)
	button.add_theme_color_override("font_focus_color", UiTheme.CREAM)
	var idle := StyleBoxEmpty.new()
	idle.set_content_margin_all(8)
	var hover := StyleBoxFlat.new()
	hover.bg_color = UiTheme.CREAM
	hover.set_content_margin_all(8)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", idle)
	parent.add_child(button)
	var popup := button.get_popup()
	popup.theme = parent.get_parent().get_parent().theme
	popup.add_theme_font_size_override("font_size", 16)
	return popup


func add_menu_item(popup: PopupMenu, label: String, id: int, accelerator: int) -> void:
	popup.add_item(label, id)
	if accelerator != 0:
		popup.set_item_accelerator(popup.get_item_index(id), accelerator)


func on_file_menu(id: int) -> void:
	match id:
		0:
			try_close("new")
		1:
			show_picker()
		2:
			save_current()
		3:
			open_save_dialog()
		4:
			try_close("leave")


func on_edit_menu(id: int) -> void:
	match id:
		0:
			undo_level()
		1:
			redo_level()
		2:
			open_settings()
		3:
			ask_remove_road()


func on_view_menu(id: int) -> void:
	if id == 0:
		show_cameras = not show_cameras
		view_menu.set_item_checked(view_menu.get_item_index(0), show_cameras)
		refresh_camera_view()
	elif id == 1:
		show_road = not show_road
		view_menu.set_item_checked(view_menu.get_item_index(1), show_road)
		refresh_flow()


func run_button(parent: Node, label: String, trial: bool) -> void:
	var button := Button.new()
	button.text = label
	button.icon = PLAY_ICON
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 18)
	button.add_theme_constant_override("icon_max_height", 18)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.clip_text = false
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_constant_override("h_separation", 6)
	button.add_theme_color_override("font_color", UiTheme.INK)
	button.add_theme_color_override("font_hover_color", UiTheme.CREAM)
	button.add_theme_color_override("font_pressed_color", UiTheme.CREAM)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.CREAM)
	button.add_theme_color_override("font_focus_color", UiTheme.INK)
	button.add_theme_color_override("icon_normal_color", UiTheme.INK)
	button.add_theme_color_override("icon_hover_color", UiTheme.CREAM)
	button.add_theme_color_override("icon_pressed_color", UiTheme.CREAM)
	button.add_theme_color_override("icon_hover_pressed_color", UiTheme.CREAM)
	button.add_theme_color_override("icon_focus_color", UiTheme.INK)
	var idle := run_face(UiTheme.CREAM, UiTheme.CORAL)
	var hover := run_face(UiTheme.ACCENT, UiTheme.LIP)
	button.add_theme_stylebox_override("normal", idle)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", idle)
	var font := UiTheme.font()
	button.custom_minimum_size = Vector2(ceil(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x) + 46, 32)
	button.pressed.connect(play.bind(trial))
	parent.add_child(button)


func run_face(fill: Color, lip: Color) -> StyleBoxFlat:
	var style := tool_style(fill, lip)
	style.shadow_size = 0
	style.border_width_bottom = 3
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 2
	style.content_margin_bottom = 1
	style.skew = Vector2(0.12, 0)
	return style


func build_tools(root: Control) -> void:
	tools_panel = side_panel()
	tools_panel.anchor_top = 0
	tools_panel.anchor_bottom = 0
	tools_panel.offset_top = 40
	tools_panel.offset_bottom = 488
	root.add_child(tools_panel)
	var tools_column := VBoxContainer.new()
	tools_column.add_theme_constant_override("separation", 6)
	tools_panel.add_child(tools_column)
	section_label(tools_column, "Tools")
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	tools_column.add_child(tools)
	for i in TOOL_NAMES.size():
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.text = TOOL_NAMES[i]
		button.icon = TOOL_ICONS[i]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26)
		button.add_theme_constant_override("icon_max_height", 26)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 42)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(set_tool.bind(i))
		tools.add_child(button)
		tool_buttons.append(button)
	paint_tools()
	tileset_panel = side_panel()
	tileset_panel.anchor_left = 1
	tileset_panel.anchor_right = 1
	tileset_panel.anchor_top = 0
	tileset_panel.anchor_bottom = 1
	tileset_panel.offset_left = -600
	tileset_panel.offset_right = 0
	tileset_panel.offset_top = 40
	tileset_panel.offset_bottom = -52
	root.add_child(tileset_panel)
	var tiles_column := VBoxContainer.new()
	tiles_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tiles_column.add_theme_constant_override("separation", 6)
	tileset_panel.add_child(tiles_column)
	section_label(tiles_column, "Tileset")
	tileset_button = OptionButton.new()
	tileset_button.custom_minimum_size = Vector2(0, 40)
	tileset_button.item_selected.connect(on_tileset_selected)
	tiles_column.add_child(tileset_button)
	course_heading = section_label(tiles_column, "Courses")
	course_row = HBoxContainer.new()
	course_row.add_theme_constant_override("separation", 6)
	tiles_column.add_child(course_row)
	course_scroll = ScrollContainer.new()
	course_scroll.custom_minimum_size = Vector2(0, 220)
	course_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	course_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tiles_column.add_child(course_scroll)
	course_map = TextureRect.new()
	course_map.mouse_filter = Control.MOUSE_FILTER_STOP
	course_map.stretch_mode = TextureRect.STRETCH_KEEP
	course_map.gui_input.connect(on_course_map_input)
	course_scroll.add_child(course_map)
	connects_heading = Label.new()
	connects_heading.text = "Next to this"
	connects_heading.add_theme_font_size_override("font_size", 16)
	connects_heading.add_theme_color_override("font_color", UiTheme.CREAM)
	tiles_column.add_child(connects_heading)
	connects_grid = GridContainer.new()
	connects_grid.columns = 6
	connects_grid.add_theme_constant_override("h_separation", 4)
	connects_grid.add_theme_constant_override("v_separation", 4)
	tiles_column.add_child(connects_grid)
	section_label(tiles_column, "All tiles")
	palette_scroll = ScrollContainer.new()
	palette_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tiles_column.add_child(palette_scroll)
	palette = VBoxContainer.new()
	palette.add_theme_constant_override("separation", 22)
	palette.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_scroll.add_child(palette)
	palette_host = Node3D.new()
	add_child(palette_host)
	connects_host = Node3D.new()
	add_child(connects_host)
	view_host = palette_host
	details_panel = side_panel()
	details_panel.anchor_top = 1
	details_panel.anchor_bottom = 1
	details_panel.offset_top = -220
	details_panel.offset_bottom = -52
	root.add_child(details_panel)
	var detail_column := VBoxContainer.new()
	detail_column.add_theme_constant_override("separation", 6)
	details_panel.add_child(detail_column)
	detail_heading = Label.new()
	detail_heading.add_theme_font_size_override("font_size", 16)
	detail_heading.add_theme_color_override("font_color", UiTheme.CREAM)
	detail_column.add_child(detail_heading)
	height_box = VBoxContainer.new()
	height_box.add_theme_constant_override("separation", 6)
	detail_column.add_child(height_box)
	layer_label = Label.new()
	layer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer_label.add_theme_font_size_override("font_size", 16)
	layer_label.add_theme_color_override("font_color", UiTheme.CREAM)
	height_box.add_child(layer_label)
	bar_button(height_box, "[F] Lower", func() -> void: shift_layer(-1))
	bar_button(height_box, "[R] Raise", func() -> void: shift_layer(1))
	grid_button = Button.new()
	grid_button.focus_mode = Control.FOCUS_NONE
	grid_button.custom_minimum_size = Vector2(0, 36)
	grid_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_button.add_theme_font_size_override("font_size", 18)
	grid_button.add_theme_stylebox_override("normal", idle_style)
	grid_button.add_theme_stylebox_override("hover", selected_style)
	grid_button.add_theme_stylebox_override("pressed", selected_style)
	grid_button.add_theme_stylebox_override("focus", idle_style)
	grid_button.pressed.connect(cycle_grid)
	detail_column.add_child(grid_button)
	height_button = Button.new()
	height_button.focus_mode = Control.FOCUS_NONE
	height_button.custom_minimum_size = Vector2(0, 36)
	height_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	height_button.add_theme_font_size_override("font_size", 18)
	height_button.add_theme_stylebox_override("normal", idle_style)
	height_button.add_theme_stylebox_override("hover", selected_style)
	height_button.add_theme_stylebox_override("pressed", selected_style)
	height_button.add_theme_stylebox_override("focus", idle_style)
	height_button.pressed.connect(cycle_height)
	detail_column.add_child(height_button)
	camera_box = VBoxContainer.new()
	camera_box.add_theme_constant_override("separation", 6)
	detail_column.add_child(camera_box)
	camera_type_button = Button.new()
	camera_type_button.focus_mode = Control.FOCUS_NONE
	camera_type_button.custom_minimum_size = Vector2(0, 42)
	camera_type_button.add_theme_font_size_override("font_size", 16)
	camera_type_button.pressed.connect(cycle_camera_type)
	camera_box.add_child(camera_type_button)
	camera_yaw_label = camera_readout(camera_box)
	camera_pitch_label = camera_readout(camera_box)
	camera_distance_label = camera_readout(camera_box)
	pickup_box = VBoxContainer.new()
	pickup_box.add_theme_constant_override("separation", 6)
	detail_column.add_child(pickup_box)
	pickup_type_button = bar_button(pickup_box, "[T] Item", cycle_pickup_type.bind(1))
	pickup_lap_button = bar_button(pickup_box, "[K] Lap", cycle_pickup_lap)
	bar_button(pickup_box, "[Del] Remove", remove_pickup)
	pickup_count_label = camera_readout(pickup_box)
	lap_button = Button.new()
	lap_button.focus_mode = Control.FOCUS_NONE
	lap_button.custom_minimum_size = Vector2(0, 42)
	lap_button.add_theme_font_size_override("font_size", 16)
	lap_button.pressed.connect(toggle_lap)
	lap_button.add_theme_stylebox_override("normal", idle_style)
	lap_button.add_theme_stylebox_override("hover", selected_style)
	lap_button.add_theme_stylebox_override("pressed", selected_style)
	detail_column.add_child(lap_button)
	road_snap_button = Button.new()
	road_snap_button.focus_mode = Control.FOCUS_NONE
	road_snap_button.custom_minimum_size = Vector2(0, 42)
	road_snap_button.add_theme_font_size_override("font_size", 16)
	road_snap_button.pressed.connect(func() -> void: road_snap = not road_snap)
	road_snap_button.add_theme_stylebox_override("normal", idle_style)
	road_snap_button.add_theme_stylebox_override("hover", selected_style)
	road_snap_button.add_theme_stylebox_override("pressed", selected_style)
	detail_column.add_child(road_snap_button)
	layout_side()


func side_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.anchor_left = 0
	panel.anchor_right = 0
	panel.offset_left = 0
	panel.offset_right = PANEL_W
	panel.add_theme_stylebox_override("panel", editor_panel())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func layout_side() -> void:
	var height := 168.0
	var heading := "Height"
	if editor_tool == TOOL_ROAD:
		height = 110.0
		heading = "Road"
	elif editor_tool == TOOL_CAMERA:
		height = 200.0
		heading = "Camera"
	elif editor_tool == TOOL_LAP:
		height = 110.0
		heading = "Race path"
	elif editor_tool == TOOL_PICKUP:
		height = 200.0
		heading = "Pickups"
	elif editor_tool == TOOL_BRUSH:
		height = 220.0
		heading = "Tile"
	elif editor_tool == TOOL_SELECT:
		heading = "Layer"
	var placing := editor_tool != TOOL_CAMERA and editor_tool != TOOL_LAP and editor_tool != TOOL_PICKUP
	var show_grid := placing and editor_tool != TOOL_SELECT and tileset_grid() > 1
	var show_height := placing and editor_tool != TOOL_ROAD and editor_tool != TOOL_SELECT and tileset_grid() > 1
	if show_grid:
		height += 48.0
	if show_height:
		height += 48.0
	tileset_panel.visible = placing and editor_tool != TOOL_ROAD
	details_panel.visible = height > 0.0
	if height > 0.0:
		details_panel.offset_top = -52.0 - height
		details_panel.offset_bottom = -52.0
		detail_heading.text = heading
	height_box.visible = placing and editor_tool != TOOL_ROAD
	grid_button.visible = show_grid
	if place_div <= 1:
		grid_button.text = "[H] Cell"
	else:
		grid_button.text = "[H] 1/%d" % place_div
	height_button.visible = show_height
	if height_div <= 1:
		height_button.text = "[J] Layer"
	else:
		height_button.text = "[J] 1/%d" % height_div
	camera_box.visible = editor_tool == TOOL_CAMERA
	pickup_box.visible = editor_tool == TOOL_PICKUP
	if editor_tool == TOOL_PICKUP:
		pickup_type_button.text = "[T] %s" % LevelBuild.PICKUP_NAMES[pickup_type]
		pickup_lap_button.text = "[K] %s" % LAP_NAMES[pickup_lap]
		pickup_count_label.text = "%d / %d placed" % [LevelBuild.pickup_count(level.line), LevelBuild.PICKUP_LIMIT]
	lap_button.visible = editor_tool == TOOL_BRUSH or editor_tool == TOOL_LAP
	road_snap_button.visible = editor_tool == TOOL_ROAD


func fill_tilesets() -> void:
	filling_tilesets = true
	tileset_button.clear()
	tileset_ids = PackedStringArray()
	var entries: Array = LevelBuild.list_tilesets()
	add_tileset_group(entries, false, "Circuit Breakers")
	add_tileset_group(entries, true, "Custom")
	filling_tilesets = false


func add_tileset_group(entries: Array, custom: bool, label: String) -> void:
	var started := false
	for entry in entries:
		var row: Dictionary = entry
		if bool(row.custom) != custom:
			continue
		if not started:
			tileset_button.add_separator(label)
			tileset_ids.append("")
			started = true
		tileset_ids.append(String(row.id))
		tileset_button.add_item(String(row.name))


func tileset_index(id: String) -> int:
	var pick := tileset_ids.find(id)
	if pick >= 0:
		return pick
	for i in tileset_ids.size():
		if tileset_ids[i] != "":
			return i
	return 0


func on_tileset_selected(index: int) -> void:
	if filling_tilesets:
		return
	var id := tileset_ids[index]
	if id == "" or id == String(level.tileset):
		return
	if level.parts.is_empty():
		apply_tileset(id)
		return
	pending_tileset = id
	filling_tilesets = true
	tileset_button.select(tileset_index(String(level.tileset)))
	filling_tilesets = false
	confirm_kind = "tileset"
	confirm_title.text = "Change tileset?"
	confirm_text.text = "Switching to %s clears every placed tile." % tileset_button.get_item_text(index)
	confirm_ok.text = "Clear and switch"
	confirm_ok_action = accept_tileset
	confirm_extra.visible = false
	show_confirm()


func apply_tileset(id: String) -> void:
	var owned := undo_scope()
	clear_stamp()
	level.tileset = id
	level.parts = []
	level.road = []
	drop_line()
	brush_tile = 0
	brush_mirror = 0
	filling_tilesets = true
	tileset_button.select(tileset_index(id))
	filling_tilesets = false
	rebuild_palette()
	set_tile(piece_tile())
	commit()
	flash("Tileset changed")
	undo_scope_end(owned)


func accept_tileset() -> void:
	var id := pending_tileset
	confirm.visible = false
	pending_tileset = ""
	apply_tileset(id)


func show_confirm() -> void:
	confirm.visible = true
	var buttons: Array[Button] = [confirm_ok]
	if confirm_extra.visible:
		buttons.append(confirm_extra)
	buttons.append(confirm_cancel)
	UiTheme.lock_focus(buttons)
	confirm_cancel.grab_focus()


func accept_confirm() -> void:
	var action := confirm_ok_action
	confirm.visible = false
	confirm_extra.visible = false
	confirm_kind = ""
	action.call()


func extra_confirm() -> void:
	var action := confirm_extra_action
	confirm.visible = false
	confirm_extra.visible = false
	confirm_kind = ""
	action.call()


func cancel_confirm() -> void:
	var kind := confirm_kind
	confirm.visible = false
	confirm_extra.visible = false
	confirm_kind = ""
	pending_tileset = ""
	if kind == "unsaved" or kind == "overwrite":
		pending_action = ""
		if kind == "unsaved":
			after_save = ""


func build_save_dialog(root: Control) -> void:
	save_dialog = Control.new()
	save_dialog.visible = false
	save_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	save_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(save_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	save_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 520)
	panel.add_theme_stylebox_override("panel", editor_panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	var title := Label.new()
	title.text = "Save track"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(title)
	var note := Label.new()
	note.text = "Choose a new name, or pick a track to replace."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	column.add_child(note)
	save_name = LineEdit.new()
	save_name.placeholder_text = "Track name"
	save_name.custom_minimum_size = Vector2(0, 40)
	save_name.text_changed.connect(on_save_text)
	save_name.text_submitted.connect(on_save_submitted)
	column.add_child(save_name)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	save_list = VBoxContainer.new()
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_list.add_theme_constant_override("separation", 6)
	scroll.add_child(save_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	bar_button(row, "Cancel", cancel_save_dialog)
	bar_button(row, "Save", commit_save_dialog)


func fill_save_list() -> void:
	for child in save_list.get_children():
		child.free()
	var saved := LevelBuild.list_saved()
	if saved.is_empty():
		var empty := Label.new()
		empty.text = "No saved tracks"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
		save_list.add_child(empty)
		return
	for entry: Dictionary in saved:
		bar_button(save_list, String(entry.name), pick_save_target.bind(String(entry.path), String(entry.name)))


func open_settings() -> void:
	filling_settings = true
	settings_name.text = String(level.name)
	settings_vehicle_was = int(level.vehicle)
	settings_vehicle.select(int(level.vehicle))
	select_handling(LevelBuild.handling_preset(level))
	settings_ai.button_pressed = bool(level.ai)
	filling_settings = false
	settings_dialog.visible = true
	settings_name.grab_focus()
	settings_name.select_all()


func cancel_settings() -> void:
	settings_dialog.visible = false


func apply_settings() -> void:
	var typed := settings_name.text.strip_edges()
	if typed == "":
		flash("Name the track")
		return
	var vehicle := settings_vehicle.selected
	var preset := settings_handling.get_item_text(settings_handling.selected)
	var ai := settings_ai.button_pressed
	var same := typed == String(level.name) and vehicle == int(level.vehicle) and preset == LevelBuild.handling_preset(level) and ai == bool(level.ai)
	settings_dialog.visible = false
	if same:
		return
	var before := capture_level()
	level.name = typed
	level.vehicle = vehicle
	level.ai = ai
	if preset == LevelBuild.VEHICLE_HANDLING[vehicle]:
		level.erase("handling")
	else:
		level.handling = preset
	undo_stack.append(before)
	redo_stack.clear()
	edit_token += 1
	refresh_title()


func on_settings_submitted(_text: String) -> void:
	apply_settings()


func on_settings_vehicle(index: int) -> void:
	if filling_settings:
		return
	var preset := settings_handling.get_item_text(settings_handling.selected)
	if preset == LevelBuild.VEHICLE_HANDLING[settings_vehicle_was]:
		select_handling(LevelBuild.VEHICLE_HANDLING[index])
	settings_vehicle_was = index


func select_handling(preset: String) -> void:
	for i in settings_handling.item_count:
		if settings_handling.get_item_text(i) == preset:
			settings_handling.select(i)
			return


func build_settings(root: Control) -> void:
	settings_dialog = Control.new()
	settings_dialog.visible = false
	settings_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settings_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(settings_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	settings_dialog.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_dialog.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", editor_panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Level settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(title)
	section_label(column, "Name")
	settings_name = LineEdit.new()
	settings_name.placeholder_text = "Track name"
	settings_name.custom_minimum_size = Vector2(0, 40)
	settings_name.text_submitted.connect(on_settings_submitted)
	column.add_child(settings_name)
	section_label(column, "Vehicle")
	settings_vehicle = OptionButton.new()
	settings_vehicle.custom_minimum_size = Vector2(0, 40)
	for vehicle_name in LevelBuild.VEHICLE_NAMES:
		settings_vehicle.add_item(vehicle_name)
	settings_vehicle.item_selected.connect(on_settings_vehicle)
	column.add_child(settings_vehicle)
	section_label(column, "Handling")
	settings_handling = OptionButton.new()
	settings_handling.custom_minimum_size = Vector2(0, 40)
	for preset in Car.HANDLING:
		settings_handling.add_item(preset)
	column.add_child(settings_handling)
	settings_ai = CheckBox.new()
	settings_ai.text = "AI drivers"
	settings_ai.custom_minimum_size = Vector2(0, 40)
	column.add_child(settings_ai)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	bar_button(row, "Cancel", cancel_settings)
	bar_button(row, "OK", apply_settings)


func build_confirm(root: Control) -> void:
	confirm = Control.new()
	confirm.visible = false
	confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(confirm)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	confirm.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.add_theme_stylebox_override("panel", editor_panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	confirm_title = Label.new()
	confirm_title.text = "Change tileset?"
	confirm_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_title.add_theme_font_size_override("font_size", 24)
	confirm_title.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(confirm_title)
	confirm_text = Label.new()
	confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_text.custom_minimum_size = Vector2(420, 0)
	column.add_child(confirm_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	confirm_ok = Button.new()
	confirm_ok.text = "Clear and switch"
	confirm_ok.focus_mode = Control.FOCUS_ALL
	confirm_ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_ok.custom_minimum_size = Vector2(0, 36)
	confirm_ok.add_theme_font_size_override("font_size", 18)
	confirm_ok.add_theme_stylebox_override("normal", idle_style)
	confirm_ok.add_theme_stylebox_override("hover", selected_style)
	confirm_ok.add_theme_stylebox_override("pressed", selected_style)
	confirm_ok.add_theme_stylebox_override("focus", selected_style)
	confirm_ok.pressed.connect(accept_confirm)
	row.add_child(confirm_ok)
	confirm_extra = Button.new()
	confirm_extra.text = "Don't save"
	confirm_extra.focus_mode = Control.FOCUS_ALL
	confirm_extra.visible = false
	confirm_extra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_extra.custom_minimum_size = Vector2(0, 36)
	confirm_extra.add_theme_font_size_override("font_size", 18)
	confirm_extra.add_theme_stylebox_override("normal", idle_style)
	confirm_extra.add_theme_stylebox_override("hover", selected_style)
	confirm_extra.add_theme_stylebox_override("pressed", selected_style)
	confirm_extra.add_theme_stylebox_override("focus", selected_style)
	confirm_extra.pressed.connect(extra_confirm)
	row.add_child(confirm_extra)
	confirm_cancel = bar_button(row, "Cancel", cancel_confirm, true)


func build_pause(root: Control) -> void:
	pause_menu = Control.new()
	pause_menu.visible = false
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(pause_menu)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_menu.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_menu.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", editor_panel())
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(title)
	pause_resume = bar_button(column, "Resume", resume_editor, true)
	bar_button(column, "Main menu", try_close.bind("leave"), true)


func show_pause() -> void:
	left_down = false
	drag_node = -1
	node_held = false
	press_node = -1
	press_moved = false
	span_node = -1
	right_down = false
	middle_down = false
	pause_menu.visible = true
	pause_resume.grab_focus()


func resume_editor() -> void:
	pause_menu.visible = false


func paint_facing() -> void:
	pending_views.clear()
	pending_view = 0
	for button in tile_buttons:
		var mesh_index := int(button.get_meta("mesh"))
		if mesh_index < 0:
			continue
		var inst: MeshInstance3D = button.get_meta("view")
		var center: Vector3 = inst.get_meta("center")
		var basis := Basis(Vector3.UP, -float(brush_rot & 3) * PI * 0.5)
		inst.basis = basis
		inst.position = center - basis * center
		queue_view(inst.get_parent() as SubViewport)


func queue_view(vp: SubViewport) -> void:
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	pending_views.append(vp)


func flush_views() -> void:
	var left := 48
	var count := pending_views.size()
	while left > 0 and pending_view < count:
		var vp: SubViewport = pending_views[pending_view]
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		pending_view += 1
		left -= 1


func color_rank(tile: Dictionary) -> float:
	var color: Color = tile.color
	return color.h * 6.0 + color.v


func fill_palette_block(tiles: Array, indices: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette.add_child(grid)
	for raw_index in indices:
		var index := int(raw_index)
		var tile: Dictionary = tiles[index]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(136, 136)
		button.tooltip_text = String(tile.name)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.set_meta("tile", index)
		button.pressed.connect(set_tile.bind(index))
		var mesh_index := int(tile.mesh)
		button.set_meta("mesh", mesh_index)
		if mesh_index >= 0:
			button.icon = tile_view(LevelBuild.tile_thumb_mesh(level.tileset, index), button)
		else:
			button.icon = marker_icon(tile)
		grid.add_child(button)
		tile_buttons.append(button)


func rebuild_palette() -> void:
	pending_views.clear()
	pending_view = 0
	for child in palette.get_children():
		child.free()
	for child in palette_host.get_children():
		child.free()
	tile_buttons.clear()
	var info := LevelBuild.tileset_info(level.tileset)
	var tiles: Array = info.tiles
	var grouped := {}
	for i in tiles.size():
		var tile: Dictionary = tiles[i]
		if String(tile.role) != "scenery":
			continue
		var group := int(tile.group)
		var list: Array = grouped.get(group, [])
		list.append(i)
		grouped[group] = list
	var ids: Array = grouped.keys()
	ids.sort()
	for raw_group in ids:
		var group := int(raw_group)
		var members: Array = grouped[group]
		members.sort_custom(func(a: int, b: int) -> bool: return color_rank(tiles[a]) < color_rank(tiles[b]))
		fill_palette_block(tiles, members)
	refresh_course_map()
	connects_key = ""
	refresh_connects()


func ensure_links() -> void:
	if link_tileset == String(level.tileset):
		return
	link_tileset = String(level.tileset)
	link_next = {}
	var steps: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var buckets := {}
	for number in range(1, 5):
		var path := LevelBuild.course_file(link_tileset, number)
		if not FileAccess.file_exists(path):
			continue
		var course: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var grid := {}
		var parts: Array = course.parts
		for raw: Dictionary in parts:
			grid["%d,%d,%d" % [int(raw.x), int(raw.y), int(raw.z)]] = [int(raw.tile), int(raw.mirror)]
		for raw: Dictionary in parts:
			var tile := int(raw.tile)
			var mirror := int(raw.mirror)
			var id := "%d,%d" % [tile, mirror]
			var bucket: Dictionary = buckets.get(id, {})
			var x := int(raw.x)
			var y := int(raw.y)
			var z := int(raw.z)
			for step in steps:
				var beside: String = "%d,%d,%d" % [x + step.x, y, z + step.y]
				if not grid.has(beside):
					continue
				var other: Array = grid[beside]
				var nid := "%d,%d" % [int(other[0]), int(other[1])]
				bucket[nid] = int(bucket.get(nid, 0)) + 1
			buckets[id] = bucket
	for id in buckets:
		var bucket: Dictionary = buckets[id]
		var rows: Array = []
		for nid in bucket:
			var bits: PackedStringArray = String(nid).split(",")
			rows.append([int(bits[0]), int(bits[1]), int(bucket[nid])])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[2]) > int(b[2]))
		link_next[id] = rows


func refresh_course_map() -> void:
	var tileset := String(level.tileset)
	if course_row.get_child_count() == 0 or String(course_row.get_meta("tileset")) != tileset:
		for child in course_row.get_children():
			child.free()
		course_row.set_meta("tileset", tileset)
		var found := false
		for number in range(1, 5):
			if not FileAccess.file_exists(LevelBuild.course_file(tileset, number)):
				continue
			found = true
			var button := Button.new()
			button.focus_mode = Control.FOCUS_NONE
			button.text = str(number)
			button.custom_minimum_size = Vector2(0, 36)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 16)
			button.pressed.connect(show_course.bind(number))
			course_row.add_child(button)
		if not found:
			catalog_course = 1
	var alive := false
	for child in course_row.get_children():
		var button := child as Button
		if int(button.text) == catalog_course:
			alive = true
	if not alive and course_row.get_child_count() > 0:
		var first := course_row.get_child(0) as Button
		catalog_course = int(first.text)
	for child in course_row.get_children():
		var button := child as Button
		var number := int(button.text)
		button.add_theme_stylebox_override("normal", selected_style if number == catalog_course else idle_style)
		button.add_theme_stylebox_override("hover", selected_style)
		button.add_theme_stylebox_override("pressed", selected_style)
	var show_courses := course_row.get_child_count() > 0
	course_heading.visible = show_courses
	course_row.visible = show_courses
	course_scroll.visible = show_courses
	var path := LevelBuild.course_file(tileset, catalog_course)
	map_cells = {}
	if not FileAccess.file_exists(path):
		course_map.texture = null
		return
	var course: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var parts: Array = course.parts
	var tiles: Array = LevelBuild.tileset_info(tileset).tiles
	var min_x := 0
	var max_x := 0
	var min_z := 0
	var max_z := 0
	var have := false
	for raw: Dictionary in parts:
		var x := int(raw.x)
		var z := int(raw.z)
		if not have:
			min_x = x
			max_x = x
			min_z = z
			max_z = z
			have = true
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_z = mini(min_z, z)
		max_z = maxi(max_z, z)
		var key := Vector2i(x, z)
		if not map_cells.has(key) or int(raw.lap) != 0:
			map_cells[key] = raw
	if not have:
		course_map.texture = null
		return
	map_min_x = min_x
	map_max_z = max_z
	var span_x := max_x - min_x + 1
	var span_z := max_z - min_z + 1
	var image := Image.create(span_x * map_cell, span_z * map_cell, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.05, 0.02, 0.04))
	var mark := Color(0.99, 0.88, 0.58)
	for key: Vector2i in map_cells:
		var raw: Dictionary = map_cells[key]
		var tile: Dictionary = tiles[int(raw.tile)]
		var color: Color = tile.color
		if int(raw.lap) == 0:
			color = color.darkened(0.55)
		var px := (key.x - min_x) * map_cell
		var py := (max_z - key.y) * map_cell
		image.fill_rect(Rect2i(px, py, map_cell, map_cell), color)
		if int(raw.tile) == brush_tile and (int(raw.mirror) & 3) == (brush_mirror & 3):
			image.fill_rect(Rect2i(px, py, map_cell, 2), mark)
			image.fill_rect(Rect2i(px, py + map_cell - 2, map_cell, 2), mark)
			image.fill_rect(Rect2i(px, py, 2, map_cell), mark)
			image.fill_rect(Rect2i(px + map_cell - 2, py, 2, map_cell), mark)
	course_map.texture = ImageTexture.create_from_image(image)
	course_map.custom_minimum_size = Vector2(image.get_width(), image.get_height())


func show_course(number: int) -> void:
	catalog_course = number
	refresh_course_map()


func on_course_map_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var x := map_min_x + int(button.position.x / float(map_cell))
	var z := map_max_z - int(button.position.y / float(map_cell))
	var key := Vector2i(x, z)
	if not map_cells.has(key):
		return
	var raw: Dictionary = map_cells[key]
	brush_rot = 0
	brush_mirror = int(raw.mirror) & 3
	connects_key = ""
	set_tile(int(raw.tile))


func refresh_connects() -> void:
	var key := "%s:%d:%d" % [level.tileset, brush_tile, brush_mirror]
	if key == connects_key:
		return
	connects_key = key
	ensure_links()
	for child in connects_grid.get_children():
		child.free()
	for child in connects_host.get_children():
		child.free()
	var rows: Array = link_next.get("%d,%d" % [brush_tile, brush_mirror], [])
	connects_heading.visible = not rows.is_empty()
	var tiles: Array = LevelBuild.tileset_info(level.tileset).tiles
	view_host = connects_host
	var shown := mini(18, rows.size())
	for i in shown:
		var row: Array = rows[i]
		var index := int(row[0])
		var mirror := int(row[1])
		var tile: Dictionary = tiles[index]
		var button := Button.new()
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(88, 88)
		button.tooltip_text = String(tile.name)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.expand_icon = true
		button.add_theme_stylebox_override("normal", tile_off)
		button.add_theme_stylebox_override("hover", tile_on)
		button.add_theme_stylebox_override("pressed", tile_on)
		var mesh_index := int(tile.mesh)
		button.set_meta("mesh", mesh_index)
		if mesh_index >= 0:
			button.icon = tile_view(LevelBuild.tile_preview_mesh(level.tileset, mesh_index), button)
			apply_tile_basis(button.get_meta("view"), 0, mirror)
		button.pressed.connect(adopt_piece.bind(index, mirror))
		connects_grid.add_child(button)
	view_host = palette_host


func adopt_piece(index: int, mirror: int) -> void:
	brush_rot = 0
	brush_mirror = mirror
	connects_key = ""
	set_tile(index)


func apply_tile_basis(inst: MeshInstance3D, rot: int, mirror: int) -> void:
	var center: Vector3 = inst.get_meta("center")
	var flip := Basis.IDENTITY
	if mirror & 1:
		flip.x *= -1
	if mirror & 2:
		flip.z *= -1
	var basis := Basis(Vector3.UP, -float(rot & 3) * PI * 0.5) * flip
	inst.basis = basis
	inst.position = center - basis * center


func tile_view(mesh: ArrayMesh, button: Button) -> Texture2D:
	var box := mesh.get_aabb()
	var center := box.get_center()
	var reach := maxf(box.size.x, maxf(box.size.y, box.size.z))
	if reach < 0.05:
		reach = 4.0
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.handle_input_locally = false
	vp.gui_disable_input = true
	vp.size = Vector2i(160, 160)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(18, 14, 22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-48, 32, 0)
	vp.add_child(sun)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.set_meta("center", center)
	var basis := Basis(Vector3.UP, -float(brush_rot & 3) * PI * 0.5)
	inst.basis = basis
	inst.position = center - basis * center
	vp.add_child(inst)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = reach * 1.35
	vp.add_child(cam)
	cam.look_at_from_position(center + Vector3(1.0, 0.82, 1.0).normalized() * reach * 4.0, center, Vector3.UP)
	view_host.add_child(vp)
	button.set_meta("view", inst)
	queue_view(vp)
	return vp.get_texture()


func marker_icon(tile: Dictionary) -> Texture2D:
	var part := {
		"x": 0,
		"y": 0,
		"z": 0,
		"piece": int(tile.piece),
		"rot": int(tile.rot),
		"slope": int(tile.slope),
		"pitch": 0,
		"distance": 24,
		"type": LevelBuild.CAM_NORMAL,
		"tile": 0,
		"mirror": 0,
		"lap": 1,
	}
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.07, 0.12, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.72, 0.74)
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	vp.add_child(sun)
	var inst := MeshInstance3D.new()
	inst.mesh = LevelBuild.preview_mesh([part])
	vp.add_child(inst)
	var flow := MeshInstance3D.new()
	flow.mesh = LevelBuild.flow_mesh([part])
	var flow_material := StandardMaterial3D.new()
	flow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	flow_material.vertex_color_use_as_albedo = true
	flow.material_override = flow_material
	vp.add_child(flow)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 10.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(8.0, 9.5, 8.0), Vector3(0, 0.5, 0), Vector3.UP)
	palette_host.add_child(vp)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	return vp.get_texture()


func palette_style(on: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.CREAM if on else Color(0.16, 0.07, 0.11, 1)
	style.border_color = UiTheme.CORAL if on else UiTheme.ACCENT
	style.set_border_width_all(3 if on else 1)
	style.set_content_margin_all(2)
	return style


func build_bottom(root: Control) -> void:
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -124
	holder.offset_bottom = -60
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	message_panel = PanelContainer.new()
	message_panel.add_theme_stylebox_override("panel", editor_panel())
	message_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	message_panel.visible = false
	holder.add_child(message_panel)
	message_label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", UiTheme.CREAM)
	message_panel.add_child(message_label)
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -52
	bar.offset_bottom = 0
	bar.add_theme_stylebox_override("panel", status_style())
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_label.add_theme_font_size_override("font_size", 16)
	row.add_child(status_label)
	var help := Label.new()
	help.text = "[Ctrl+Z] Undo    [Ctrl+Y] Redo    [Ctrl] Pick tile    [Q/E] Turn    [Ctrl-click] Make node start    [Shift-click] Remove node    [Click start] Close road    [Esc] Stop placing    [Esc] Menu    [RMB] Orbit    [MMB/WASD] Pan    [Wheel] Zoom"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.custom_minimum_size = Vector2(860, 0)
	help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	help.size_flags_stretch_ratio = 3.0
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(help)


func chrome(left: float, top: float, right: float, bottom: float, preset: Control.LayoutPreset) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(preset)
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	panel.add_theme_stylebox_override("panel", editor_panel())
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	return panel


func status_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.02, 0.06, 0.94)
	style.border_color = UiTheme.ACCENT
	style.border_width_top = 2
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func editor_panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.02, 0.06, 0.92)
	style.border_color = UiTheme.ACCENT
	style.set_border_width_all(2)
	style.border_width_bottom = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func paint_tools() -> void:
	for i in tool_buttons.size():
		var button := tool_buttons[i]
		var on := i == active_tool()
		var face := toolbox_on if on else toolbox_idle
		button.add_theme_stylebox_override("normal", face)
		button.add_theme_stylebox_override("hover", toolbox_on)
		button.add_theme_stylebox_override("pressed", face)
		button.add_theme_stylebox_override("hover_pressed", toolbox_on)
		var ink := UiTheme.INK if on else Color.WHITE
		button.add_theme_color_override("font_color", ink)
		button.add_theme_color_override("font_hover_color", UiTheme.INK)
		button.add_theme_color_override("font_pressed_color", ink)
		button.add_theme_color_override("icon_normal_color", ink)
		button.add_theme_color_override("icon_hover_color", UiTheme.INK)
		button.add_theme_color_override("icon_pressed_color", ink)
		button.add_theme_color_override("icon_hover_pressed_color", UiTheme.INK)


func tool_style(fill: Color, lip: Color) -> StyleBoxFlat:
	var style := UiTheme.button_style(fill, lip)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 4
	style.skew = Vector2(0.08, 0)
	return style


func section_label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UiTheme.CREAM)
	parent.add_child(label)
	return label


func bar_button(parent: Node, text: String, action: Callable, focusable: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", idle_style)
	button.add_theme_stylebox_override("hover", selected_style)
	button.add_theme_stylebox_override("pressed", selected_style)
	button.add_theme_stylebox_override("focus", selected_style if focusable else idle_style)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func picker_button(parent: Node, text: String, action: Callable, height: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, height)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_stylebox_override("normal", picker_idle)
	button.add_theme_stylebox_override("hover", picker_on)
	button.add_theme_stylebox_override("pressed", picker_on)
	button.add_theme_stylebox_override("focus", picker_idle)
	button.add_theme_color_override("font_hover_color", UiTheme.INK)
	button.add_theme_color_override("font_pressed_color", UiTheme.INK)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func build_picker(root: Control) -> void:
	picker = Control.new()
	picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(picker)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	picker.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picker.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 660)
	var shell := editor_panel()
	shell.content_margin_left = 28
	shell.content_margin_right = 28
	shell.content_margin_top = 24
	shell.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", shell)
	center.add_child(panel)
	picker_idle = tool_style(UiTheme.ACCENT, UiTheme.LIP)
	picker_on = tool_style(UiTheme.CREAM, UiTheme.CORAL)
	for face in [picker_idle, picker_on]:
		face.content_margin_left = 18
		face.content_margin_right = 18
		face.content_margin_top = 10
		face.content_margin_bottom = 8
		face.skew = Vector2(0.05, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(column)
	var title := Label.new()
	title.text = "Open track"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(title)
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 0)
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(block)
	picker_tab_off = tab_face(false)
	picker_tab_on = tab_face(true)
	picker_tab_hover = tab_face(false)
	picker_tab_hover.bg_color = Color(0.18, 0.04, 0.09, 1)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	block.add_child(tabs)
	for tab_name in ["Courses", "Saved"]:
		var button := Button.new()
		button.text = tab_name
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 46)
		button.add_theme_font_size_override("font_size", 18)
		var page := picker_tabs.size()
		button.pressed.connect(show_picker_page.bind(page))
		tabs.add_child(button)
		picker_tabs.append(button)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 12)
		picker_pages.append(list)
	var sheet := PanelContainer.new()
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.14, 0.03, 0.07, 1)
	well.set_border_width_all(0)
	well.content_margin_left = 10
	well.content_margin_right = 10
	well.content_margin_top = 14
	well.content_margin_bottom = 10
	sheet.add_theme_stylebox_override("panel", well)
	block.add_child(sheet)
	picker_scroll = ScrollContainer.new()
	picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_scroll.custom_minimum_size = Vector2(0, 380)
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(picker_scroll)
	show_picker_page(0)
	picker.visible = false


func fill_picker() -> void:
	for page in picker_pages:
		for child in page.get_children():
			child.free()
	for course: Dictionary in LevelBuild.list_courses():
		picker_button(picker_pages[0], String(course.name), try_close.bind("load:" + String(course.path)), 44)
	var saved := LevelBuild.list_saved()
	if saved.is_empty():
		var empty := Label.new()
		empty.text = "No saved tracks"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.custom_minimum_size = Vector2(0, 64)
		empty.add_theme_font_size_override("font_size", 16)
		empty.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
		picker_pages[1].add_child(empty)
	for saved_track: Dictionary in saved:
		picker_button(picker_pages[1], String(saved_track.name), try_close.bind("load:" + String(saved_track.path)), 44)


func show_picker_page(page: int) -> void:
	picker_page = page
	if picker_scroll.get_child_count() > 0:
		picker_scroll.remove_child(picker_scroll.get_child(0))
	picker_scroll.add_child(picker_pages[page])
	for i in picker_tabs.size():
		var button := picker_tabs[i]
		var on := i == page
		var face := picker_tab_on if on else picker_tab_off
		button.add_theme_stylebox_override("normal", face)
		button.add_theme_stylebox_override("hover", picker_tab_on if on else picker_tab_hover)
		button.add_theme_stylebox_override("pressed", face)
		button.add_theme_stylebox_override("focus", face)
		var ink := UiTheme.CREAM if on else Color(1, 1, 1, 0.55)
		button.add_theme_color_override("font_color", ink)
		button.add_theme_color_override("font_hover_color", UiTheme.CREAM)
		button.add_theme_color_override("font_pressed_color", ink)
		button.add_theme_color_override("font_focus_color", ink)


func show_picker() -> void:
	flush()
	picking = true
	entry.visible = false
	fill_picker()
	picker.visible = true


func show_entry() -> void:
	flush()
	picking = true
	picker.visible = false
	entry.visible = true
	entry_leave.grab_focus()


func enter_editor() -> void:
	editing = true
	picking = false
	picker.visible = false
	entry.visible = false
	get_viewport().gui_release_focus()
	aim_cursor(get_viewport().get_visible_rect().size * 0.5)


func tab_face(selected: bool) -> StyleBoxFlat:
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


func build_entry(root: Control) -> void:
	entry = Control.new()
	entry.visible = false
	entry.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	entry.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(entry)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.01, 0.03, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	entry.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var shell := editor_panel()
	shell.content_margin_left = 32
	shell.content_margin_right = 32
	shell.content_margin_top = 28
	shell.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", shell)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Level editor"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UiTheme.CREAM)
	column.add_child(title)
	picker_button(column, "New track", try_close.bind("new"), 52)
	picker_button(column, "Open track", show_picker, 52)
	entry_leave = picker_button(column, "Main menu", try_close.bind("leave"), 52)
	entry_leave.focus_mode = Control.FOCUS_ALL
	entry_leave.add_theme_stylebox_override("focus", picker_on)
