class_name Car
extends CharacterBody3D

# Port of the car update in the PS1 executable (SLUS_006.97, FUN_0003a330).
# Internal state uses the original units: 4096 = one world unit, velocities are
# fixed-point world units per 30 Hz game frame, angles are 12-bit (4096 = 360°).

const UNIT_METRES := 2.4 / 158.0
const ONE := 4096.0
const FIXED_TO_MPS := UNIT_METRES * 30.0 / ONE
const ANGLE_TO_RAD := TAU / 4096.0
const GRAVITY := 0x3000
const ROLLING_FRICTION := 0x80
const ROLLING_STOP := 0x100
const WRECK_FRAMES := 30
const SUNK_SLACK := 0.1
const MAX_SAFE_DROP := 0x80000 / ONE * UNIT_METRES
const HARD_SURFACE_CHANGE := 0x281 * ANGLE_TO_RAD
const STEEP_IMPACT := -0x600 / ONE
const BOUNCE_SPEED := 0x3fff
const TIP_OVER_TILT := 0x300
const MAX_AIR_TILT := 0x400 * ANGLE_TO_RAD
const DISPLAY_TILT_RATE := 0x20 * ANGLE_TO_RAD
const DISPLAY_TILT_RATE_AIR := 0x40 * ANGLE_TO_RAD
const STEEP_THRUST_TILT := 0x1c1
const FLAT_GROUND_Y := 0.9999997
const WALL_STUN_FRAMES := 8
const CAR_STUN_FRAMES := 4
const CONTACT_FRAMES := 8
const SURFACE_OUT := 2
const SURFACE_LOOSE := 6
const SURFACE_ICE := 8
const SURFACE_MUD := 10
const SURFACE_SPRAY := 4
const SURFACE_WATER := 12
const SURFACE_SPLASH := 14
const ICE_ENGINE := 8000
const ICE_GRIP := 0x38
const FALL_WRECK_HEIGHT := -20.0
const PHYSICS_TICKS_PER_GAME_FRAME := 4
const GROUND_SNAP := 0x12 * UNIT_METRES / PHYSICS_TICKS_PER_GAME_FRAME
const GROUND_SNAP_RISING := 4 * UNIT_METRES / PHYSICS_TICKS_PER_GAME_FRAME
const GROUND_SNAP_LOOSE := 1 * UNIT_METRES / PHYSICS_TICKS_PER_GAME_FRAME
const GROUND_STEP := 0x20 * UNIT_METRES
# The original moves in steps of at most 16 units along the dominant axis and
# snaps to the ground after each one.
const MOTION_STEP := 16.0
const GROUND_MAX_ANGLE := 80.0 * PI / 180.0
const BODY_CLEARANCE := 0.25
const GROUND_LAYER := 2

# Per-world handling read from offset 0xFE8C of each .TRK file:
# [drag, grip, engine, brake, turn rate]
const HANDLING := {
	"Wild West": [32, 25, 8500, 4096, 56],
	"Grand Prix 1": [32, 80, 14000, 4096, 32],
	"Grand Prix 2": [32, 80, 12000, 4096, 56],
	"Grand Prix 3": [32, 50, 12000, 4096, 56],
	"Grand Prix 4": [28, 44, 12000, 4096, 56],
	"Jungle": [32, 20, 7750, 4096, 56],
	"Persia": [32, 22, 8000, 4096, 56],
	"Snow": [32, 12, 5300, 4096, 56],
	"Snow 2": [32, 26, 5700, 4096, 56],
	"Aqua": [32, 18, 4000, 3072, 56],
	"Swamp / Venice": [6, 14, 6000, 1024, 48],
	"Castle 1": [30, 8, 8000, 4096, 56],
	"Castle 2": [30, 24, 9000, 4096, 56],
	"Castle 3": [30, 8, 10500, 4096, 56],
	"Castle 4": [30, 20, 9000, 4096, 56],
	"Rooftop 1": [32, 15, 9500, 4096, 56],
	"Rooftop 2": [32, 24, 9000, 4096, 56],
	"Rooftop 3": [32, 15, 9500, 4096, 64],
	"World": [64, 88, 7424, 4096, 56],
	"Executable fallback": [32, 40, 6700, 4096, 56],
}

# Exported from CARS.DAT, BOAT.DAT and WATER.DAT by Tools/export_car.py.
# mesh.bin holds the body and then each wheel model, every model as two
# triangle lists (single-sided, double-sided) prefixed by their vertex count;
# 12 floats per vertex: position, normal, color, uv. Record +0x18 is the kind.
const CAR_DIR := "res://cars/car%d"
const CAR_MODELS := 8
const VEHICLE_CAR := 0
const VEHICLE_BOAT := 1
const VEHICLE_SUB := 2
const VERTEX_FLOATS := 12
const MAX_STEER_ANGLE := 0.45

@export var player_controlled := false
var replay := false
var playback := false
@export_range(0, CAR_MODELS - 1) var model := 0
var mesh_dir := CAR_DIR
var vehicle_kind := VEHICLE_CAR
@export var handling := "Wild West"
@export var heading_assist := true
@export var autopilot_enabled := false

var drag := 0
var grip := 0
var engine := 0
var brake := 0
var turn_rate := 0

var accel_input := 0
var brake_input := 0
var steer_input := 0
# FUN_0003a330 counts how long a single-player AI car has held each steer
# direction (car+0x1f7742 and car+0x1f7740) and eases the lock in.
var steer_hold_left := 0
var steer_hold_right := 0
var controls := ""
var net_slot := 0
var net_driven := false
var net_accel := 0
var net_brake := 0
var net_steer := 0
var net_fire := false
var net_cycle := false
var net_reset := false
var net_reset_held := false
var puppet := false
var puppet_from := Transform3D.IDENTITY
var puppet_to := Transform3D.IDENTITY
var puppet_age := 0.0
var frozen := false
# Battle mode holds eliminated cars on the last wreck frame and places respawns.
var respawn_held := false
var battle: Battle

var vel := Vector3.ZERO
var heading := 0
var thrust_ramp := 0
var grounded := false
var floor_normal := Vector3.UP
var air_frames := 0
var air_tilt := Vector2.ZERO
var display_tilt := Vector2.ZERO
var shown_heading := 0.0
var shown_tilt := Vector2.ZERO
var shown_heading_from := 0.0
var shown_tilt_from := Vector2.ZERO
# Steering rolls the body (car+0x184, ramped in FUN_0003a330 and applied in
# FUN_0001f60c). The heading-relative tilt there is a roll about the forward axis.
var body_lean := 0
var shown_lean := 0.0
var shown_lean_from := 0.0
var last_ground_height := 0.0
var last_ground_position := Vector3.ZERO
var wreck_frames := 0
# FUN_000388c4 sets car+0x1f75c8. The car holds still until it counts to 0x1e.
var appear_frames := 0
# Water-puddle wreck (surface 0xe). Counts up the way FUN_0003a330 does.
var splash_wreck := false
var splash_state := 0
var wall_frames := 0
var contacts := {}
var touching := {}
var bump_axis := {}
var bump_frame := {}
var shove_x := 0.0
var shove_z := 0.0
var surface := 0
var held := false
# Singleplayer start grid. Set by Race before this car's physics step.
var staged := false
var track: Track
var autopilot := Autopilot.new()
var items: Items
var item_counts := PackedInt32Array()
var item_timers := PackedInt32Array()
var item_total := 0
var selected_item := 0
var fired_item := 0
var item_active := false
var fire_input := false
var cycle_input := false
var fire_held := false
var cycle_held := false
var forced_accel := false
var on_screen := false
var locked_heading := 0
var spin_frames := 0
var slow_frames := 0
var burn_frames := 0
var base_grip := 0
var base_engine := 0
var item_scale := 64
var stretch := 8
var rear_spread := 8
var body_lift := 0
var shown_deform := Vector2i(8, 8)
var visual := Node3D.new()
var body := MeshInstance3D.new()
var body_surfaces: Array = []
var body_materials: Array[StandardMaterial3D] = []
var textured: Array[StandardMaterial3D] = []
var color := Color.WHITE
var ground_offset := 0.0
var safe_transform: Transform3D
var safe_history: Array[Transform3D] = []
var collision_shape: CollisionShape3D
var collision_offset: Transform3D
var wheel_travel := 0.0
var steer_pivots: Array[Node3D] = []
var steer_sign: Array[float] = []
var wheel_spinners: Array[Node3D] = []
var wheel_radii: Array[float] = []
var wheel_spin_z: Array[bool] = []


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	heading = wrapi(roundi(global_rotation.y / ANGLE_TO_RAD), 0, 4096)
	shown_heading = heading
	shown_heading_from = shown_heading
	safe_transform = global_transform
	last_ground_height = global_position.y
	last_ground_position = global_position
	item_counts.resize(Items.TYPES)
	item_timers.resize(Items.TYPES)
	apply_handling(handling)
	build_body()
	if Net.puppet():
		puppet = true
		physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF
		collision_layer = 0
		collision_mask = 0
		puppet_from = global_transform
		puppet_to = global_transform


func apply_handling(preset: String) -> void:
	handling = preset
	var values: Array = HANDLING[preset]
	drag = values[0]
	grip = values[1]
	engine = values[2]
	brake = values[3]
	turn_rate = values[4]
	base_grip = grip
	base_engine = engine


static func model_color(model: int) -> Color:
	var info: Dictionary = JSON.parse_string(Data.text(CAR_DIR % model + "/car.json"))
	var rgb: Array = info.color
	return Color8(rgb[0], rgb[1], rgb[2])


static func mesh_for(track_dir: String) -> String:
	if track_dir.begins_with("user://"):
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(track_dir + "/track.json"))
		var vehicle := int(info.vehicle)
		if vehicle == 1:
			return "res://vehicles/venice/car%d"
		if vehicle == 2:
			return "res://vehicles/aqua/car%d"
		return CAR_DIR
	var name := track_dir.get_file().to_lower()
	if name.begins_with("venice"):
		return "res://vehicles/venice/car%d"
	if name.begins_with("swamp"):
		return "res://vehicles/swamp/car%d"
	if name.begins_with("aqua"):
		return "res://vehicles/aqua/car%d"
	return CAR_DIR


func load_info() -> Dictionary:
	var info: Dictionary = JSON.parse_string(Data.text(mesh_dir % model + "/car.json"))
	var rgb: Array = info.color
	color = Color8(rgb[0], rgb[1], rgb[2])
	vehicle_kind = int(info.kind)
	return info


func build_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 2.4
	collision.shape = capsule
	collision.rotation.x = PI / 2.0
	collision.position = Vector3(0.0, capsule.radius + BODY_CLEARANCE, 0.0)
	add_child(collision)
	collision_shape = collision
	collision_offset = collision.transform

	var dir := mesh_dir % model
	var info := load_info()
	var atlas_image := Image.new()
	atlas_image.load_png_from_buffer(Data.bytes(dir + "/atlas.png"))
	var atlas: Texture2D = ImageTexture.create_from_image(atlas_image)
	body_materials = [car_material(atlas, BaseMaterial3D.CULL_BACK), car_material(atlas, BaseMaterial3D.CULL_DISABLED)]
	textured = body_materials
	add_to_group(Track.TEXTURED)
	ground_offset = info.ground
	var bytes := Data.bytes(dir + "/mesh.bin")
	var offset := 0
	var meshes: Array[ArrayMesh] = []
	for i in int(info.models):
		var mesh := ArrayMesh.new()
		for material in body_materials:
			var count := bytes.decode_s32(offset)
			var size := count * VERTEX_FLOATS * 4
			if count > 0:
				var arrays := add_surface(mesh, bytes.slice(offset + 4, offset + 4 + size).to_float32_array(), count, material)
				if i == 0:
					body_surfaces.append([arrays, material])
			offset += 4 + size
		meshes.append(mesh)

	add_child(visual)
	body.mesh = meshes[0]
	visual.add_child(body)

	for wheel: Dictionary in info.wheels:
		var pivot := Node3D.new()
		pivot.position = Vector3(wheel.position[0], wheel.position[1], wheel.position[2])
		visual.add_child(pivot)
		var spinner := MeshInstance3D.new()
		spinner.mesh = meshes[int(wheel.model)]
		pivot.add_child(spinner)
		var flags := int(wheel.flags)
		# FUN_00022ec8. Case 3 yaws with the steer angle; case 2 (submarine
		# flaps) yaws with its negation. Boats never accumulate that angle.
		# Cases 3 and 7 spin about Z, which is the Godot X axle. Case 0x70
		# spins a propeller about X, which is Godot Z.
		if flags == 3 or (flags == 2 and vehicle_kind == VEHICLE_SUB):
			steer_pivots.append(pivot)
			steer_sign.append(-1.0 if flags == 2 else 1.0)
		if flags != 2:
			wheel_spinners.append(spinner)
			wheel_radii.append(wheel.radius)
			wheel_spin_z.append(flags == 0x70)


func add_surface(mesh: ArrayMesh, floats: PackedFloat32Array, count: int, material: Material) -> Array:
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
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return arrays


func car_material(atlas: Texture2D, cull: BaseMaterial3D.CullMode) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = atlas
	material.vertex_color_use_as_albedo = true
	material.texture_filter = Settings.material_filter()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = cull
	material.roughness = 1.0
	material.metallic_specular = 0.0
	return material


func _process(delta: float) -> void:
	if not puppet:
		return
	puppet_age += delta
	blend_puppet()


func _physics_process(_delta: float) -> void:
	if puppet:
		blend_puppet()
		update_wheels()
		if Engine.get_physics_frames() % PHYSICS_TICKS_PER_GAME_FRAME == 0:
			step_appear()
			Sound.car_frame(self)
			Fx.car_frame(self)
			if splash_wreck:
				step_splash(false)
			if vehicle_kind == VEHICLE_SUB:
				blow_bubbles()
		return
	if frozen:
		if Engine.get_physics_frames() % PHYSICS_TICKS_PER_GAME_FRAME == 0:
			step_appear()
		return
	if Engine.get_physics_frames() % PHYSICS_TICKS_PER_GAME_FRAME == 0 and items.race.cars[0] == self:
		items.race.begin_game_frame()
	if staged:
		if vehicle_kind != VEHICLE_CAR:
			visual.position.y = vehicle_lift() * UNIT_METRES
		if Engine.get_physics_frames() % PHYSICS_TICKS_PER_GAME_FRAME == 0:
			Sound.car_frame(self)
			Fx.car_frame(self)
		return
	if Engine.get_physics_frames() % PHYSICS_TICKS_PER_GAME_FRAME == 0:
		shown_heading_from = shown_heading
		shown_tilt_from = shown_tilt
		shown_lean_from = shown_lean
		game_frame()
		update_shape()

	var was_grounded := grounded
	velocity = vel * FIXED_TO_MPS
	move_and_slide()
	resolve_collisions()

	if held:
		grounded = wreck_frames == 0
		vel.y = 0.0
		last_ground_height = global_position.y
		last_ground_position = global_position
		update_orientation()
		update_wheels()
		return

	var ground := probe_ground(was_grounded)
	var water := track.water_height(global_position) if track else -INF
	if global_position.y - GROUND_SNAP <= water and (ground.is_empty() or ground.position.y <= water):
		grounded = wreck_frames == 0
		if grounded:
			global_position.y = water
			surface = SURFACE_WATER
			vel.y = 0.0
			floor_normal = Vector3.UP
			last_ground_position = global_position
	else:
		ground_contact(ground, was_grounded)

	update_orientation()
	update_wheels()


func ground_contact(ground: Dictionary, was_grounded: bool) -> void:
	# FUN_0003f31c writes the polygon surface before the landing is accepted, so a
	# crash onto surface 0xe or 2 still reaches FUN_0003a330.
	if wreck_frames == 0 and not splash_wreck and not ground.is_empty() and track and track.surface_of(ground) == SURFACE_SPLASH:
		global_position.y = ground.position.y
		floor_normal = ground.normal
		last_ground_height = global_position.y
		last_ground_position = global_position
		surface = 0
		begin_splash()
		grounded = false
		return
	if wreck_frames == 0 and not ground.is_empty() and track and not battle and track.surface_of(ground) == SURFACE_OUT:
		global_position.y = ground.position.y
		floor_normal = ground.normal
		last_ground_height = global_position.y
		last_ground_position = global_position
		surface = 0
		wreck()
		grounded = false
		return
	grounded = not ground.is_empty() and wreck_frames == 0
	var bounced := false
	if grounded:
		var n: Vector3 = ground.normal
		if not was_grounded or hard_surface_change(n):
			grounded = land(n, ground.position.y)
			bounced = not grounded
	if grounded:
		var n: Vector3 = ground.normal
		global_position.y = ground.position.y
		surface = track.surface_of(ground) if track else 0
		if not was_grounded or not n.is_equal_approx(floor_normal):
			redirect_along_surface(n)
		floor_normal = n
		last_ground_height = global_position.y
		last_ground_position = global_position
	elif bounced:
		air_frames = 0
		air_tilt = tilts_of(ground.normal)
	elif was_grounded:
		air_frames = 0
		air_tilt = tilts_of(floor_normal)


func game_frame() -> void:
	if player_controlled and net_driven:
		fire_input = net_fire
		cycle_input = net_cycle
	elif player_controlled:
		fire_input = Input.is_action_pressed("fire_item" + controls)
		cycle_input = Input.is_action_pressed("cycle_item" + controls)
	if autopilot_enabled:
		autopilot.restore_handling(self)
	if items:
		items.car_frame(self)
	# FUN_0003a330 counts these down ahead of the appear hold and the wreck.
	if slow_frames > 0:
		slow_frames -= 1
		engine = base_engine if slow_frames == 0 else base_engine / 2
	if burn_frames > 0:
		burn_frames -= 1
		if (burn_frames & 7) == 0:
			Fx.burn_smoke(self)
	# The appear hold returns from the car update (car+0x1f75c8). The wreck
	# state is already clear, so the engine voice in FUN_00073b08 keeps running.
	if step_appear():
		Sound.car_frame(self)
		return
	apply_shove()
	update_body_lean()

	if splash_wreck:
		Sound.car_frame(self)
		step_splash(true)
		return

	if wreck_frames > 0:
		Sound.car_frame(self)
		Fx.wreck_trail(self, 32 - wreck_frames)
		if wreck_frames > 1 or not respawn_held:
			wreck_frames -= 1
		if wreck_frames == 0:
			safe_history.clear()
			respawn()
		return

	if surface == SURFACE_SPLASH:
		surface = 0
		begin_splash()
		return
	# FUN_0003a330 wrecks a grounded car whose floor polygon is surface 2.
	# Battle (a6b24 != 0) leaves that surface alone.
	if surface == SURFACE_OUT and not battle:
		surface = 0
		wreck()
		return

	if grounded and tipped_over():
		wreck()
		return

	var tilt := tilts_of(floor_normal) if grounded else air_tilt
	var tilt_rate := DISPLAY_TILT_RATE if grounded else DISPLAY_TILT_RATE_AIR
	if vehicle_kind == VEHICLE_BOAT and tilt.is_zero_approx():
		display_tilt = boat_bank()
	else:
		display_tilt = display_tilt + (tilt - display_tilt).clampf(-tilt_rate, tilt_rate)
	if vehicle_kind == VEHICLE_SUB:
		blow_bubbles()

	if autopilot_enabled:
		autopilot.drive(self)
	elif replay:
		var sample := items.race.ghost_sample(items.race.trial_frame)
		accel_input = sample.x
		brake_input = sample.y
		steer_input = sample.z
	elif net_driven:
		accel_input = net_accel
		brake_input = net_brake
		steer_input = net_steer
		if net_reset and not net_reset_held and wreck_frames == 0 and not frozen:
			respawn()
		net_reset_held = net_reset
	elif player_controlled:
		accel_input = roundi(Input.get_action_strength("accelerate" + controls) * 7.0)
		brake_input = roundi(Input.get_action_strength("brake" + controls) * 7.0)
		steer_input = roundi(Input.get_axis("steer_left" + controls, "steer_right" + controls) * 7.0)
	if forced_accel and not autopilot_enabled:
		accel_input = 7
		brake_input = 0
		steer_input = 0
	if items.race.time_trial and not replay and (player_controlled or net_driven):
		items.race.note_trial(items.race.cars.find(self), accel_input, brake_input, steer_input)

	if wall_frames > 0:
		wall_frames -= 1

	var v2 := vel.length_squared()
	var q := v2 / 131072.0
	var spd := sqrt(v2) / 64.0
	var horizontal_speed := Vector2(vel.x, vel.z).length() / 64.0
	var travel := travel_direction(spd)

	var thrust := 0.0
	if grounded:
		if accel_input > 0 and brake_input == 0:
			thrust_ramp = mini(thrust_ramp + 1, 16)
			if wall_frames == 0:
				var power := ICE_ENGINE if surface == SURFACE_ICE else engine
				if spd <= 0x100:
					thrust = power
				else:
					thrust = maxf((0x400 - heading_travel_difference(travel)) * 2.0, 0x400) * power / 2048.0
			if spd < 0x500:
				thrust = minf(thrust * 2.0, 0x7fff)
			if spd < 0x800 and ground_tilt() >= STEEP_THRUST_TILT:
				thrust = minf(thrust * 2.0, 0x7fff)
			thrust = thrust * thrust_ramp / 16.0 * accel_input / 7.0
		else:
			thrust_ramp = maxi(thrust_ramp - 1, 0)
		if brake_input > 0 and (accel_input == 0 or absi(steer_input) != 7):
			thrust -= brake * brake_input / 7.0
	elif horizontal_speed < 0x400:
		thrust = 0x1000

	if spin_frames > 0:
		spin_out()
	elif steer_input != 0:
		if steer_input > 0:
			steer_hold_left += 1
			steer_hold_right = 0
		else:
			steer_hold_right += 1
			steer_hold_left = 0
		var turn := turn_rate
		if absi(steer_input) != 7:
			turn = turn_rate * absi(steer_input) / 6
		elif ai_steer_ramp():
			var hold := steer_hold_left if steer_input > 0 else steer_hold_right
			turn = mini(hold * hold + 8, turn_rate)
		if accel_input == 7 and brake_input == 7:
			turn += turn / 2
		heading = wrapi(heading - signi(steer_input) * turn, 0, 4096)
		if spd < 500:
			thrust += 0x600
		heading = wrapi(heading + slope_steer_drift(), 0, 4096)
	else:
		steer_hold_left = 0
		steer_hold_right = 0
		if ai_steer_ramp():
			heading = ai_assisted_heading(heading)
		elif heading_assist and spd > 0x200:
			heading = assisted_heading(heading)

	var k := minf(q * drag / 32768.0, 16384.0)
	vel -= vel * (k / 16384.0)
	vel = Vector3(rolling(vel.x), rolling(vel.y), rolling(vel.z))
	vel += thrust_direction(travel) * thrust

	if grounded:
		if surface == SURFACE_MUD:
			vel *= 7.0 / 8.0
		var fwd := ground_forward()
		var right := fwd.cross(floor_normal).normalized()
		var flat_forward := heading_forward()
		var sin_slip := travel.dot(Vector3(-flat_forward.z, 0.0, flat_forward.x))
		var cos_slip := travel.dot(flat_forward)
		var qq := q / 4.0
		var lateral_grip := ICE_GRIP if surface == SURFACE_ICE else grip
		if absf(sin_slip) > 0x20 / ONE and q >= 9.0:
			var lateral := maxf(qq * sin_slip * sin_slip * 4.0 * lateral_grip / 512.0, lateral_grip)
			lateral = minf(lateral, spd)
			vel -= right * signf(sin_slip) * lateral * 4.0
		if q > 4.0:
			var longitudinal := maxf(qq * absf(cos_slip) * mini(grip, 64) / 512.0, grip * 8.0)
			vel -= fwd * signf(cos_slip) * longitudinal
		if accel_input == 0 and brake_input == 0 and spd < (0x40 if floor_normal.y > FLAT_GROUND_Y else 0x10):
			vel = Vector3.ZERO
		apply_slope_push()
		if floor_normal.y > 0.95 and Engine.get_physics_frames() % 120 == 0:
			safe_history.append(Transform3D(Basis(Vector3.UP, heading * ANGLE_TO_RAD), global_position + Vector3.UP * 0.5))
			if safe_history.size() > 3:
				safe_history.pop_front()
			safe_transform = safe_history[0]
	else:
		vel.y -= GRAVITY
		air_frames += 1
		var rate := mini(air_frames * air_frames >> 2, 0x40) * maxf(ONE - horizontal_speed, 0.0) / ONE * ANGLE_TO_RAD
		air_tilt += Vector2(travel.z, travel.x) * rate
		air_tilt = air_tilt.clampf(-MAX_AIR_TILT, MAX_AIR_TILT)

	if global_position.y < FALL_WRECK_HEIGHT:
		wreck()
	Sound.car_frame(self)
	Fx.car_frame(self)


# Oil and shots spin the car in place of steering, fastest halfway through,
# with no grip; leaving the ground ends the spin.
func spin_out() -> void:
	if grounded:
		heading = wrapi(heading - mini(spin_frames, 0x40 - spin_frames) * 0x20, 0, 4096)
		spin_frames -= 1
	else:
		spin_frames = 0
	grip = 0
	if spin_frames == 0:
		grip = base_grip


func make_translucent() -> void:
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for material in body_materials:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func ghost() -> bool:
	return item_timers[Items.GROW] != 0 or item_timers[Items.STILTS] != 0 or item_timers[Items.BOUNCE] != 0 or wreck_frames > 0


func update_shape() -> void:
	visual.scale = Vector3.ONE * item_scale / 64.0
	body.position.y = body_lift * UNIT_METRES
	var deform := Vector2i(stretch, rear_spread)
	if deform != shown_deform:
		shown_deform = deform
		body.mesh = deformed_body()
	var shade := 0.45 if burn_frames > 0 else 1.0
	var alpha := 0.5 if playback else 1.0
	for material in body_materials:
		material.albedo_color = Color(shade, shade, shade, alpha)


# FUN_00058b38 shears the body for the rocket and FUN_00058c68 widens the
# rear (model x below -16) for the ring launcher. Model space is x forward,
# y down, z left with the origin ground_offset above the wheels' contact.
func deformed_body() -> ArrayMesh:
	var k := stretch - 8
	var mesh := ArrayMesh.new()
	for surface: Array in body_surfaces:
		var arrays: Array = surface[0].duplicate()
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		for i in positions.size():
			var p := positions[i] / UNIT_METRES
			var x := -p.z
			var y := ground_offset - p.y
			var z := -p.x
			if x < -16.0:
				z = z * rear_spread / 8.0
			var sheared_x := x - (x + 64.0) * k / 32.0 + y * k / 16.0
			var sheared_y := y - (x + 64.0) * k / 16.0
			positions[i] = Vector3(-z, ground_offset - sheared_y, -sheared_x) * UNIT_METRES
		arrays[Mesh.ARRAY_VERTEX] = positions
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, surface[1])
	return mesh


func ground_tilt() -> float:
	var tilt_x := atan2(absf(floor_normal.z), floor_normal.y) / ANGLE_TO_RAD
	var tilt_z := atan2(absf(floor_normal.x), floor_normal.y) / ANGLE_TO_RAD
	return maxf(tilt_x, tilt_z)


func tipped_over() -> bool:
	return ground_tilt() > TIP_OVER_TILT


func travel_direction(spd: float) -> Vector3:
	var horizontal := Vector3(vel.x, 0.0, vel.z)
	if spd < 8.0 or horizontal.is_zero_approx():
		return heading_forward()
	return horizontal.normalized()


func thrust_direction(travel: Vector3) -> Vector3:
	if grounded:
		return ground_forward()
	return tilt_basis(air_tilt) * travel


func fall_line() -> int:
	return roundi(atan2(-floor_normal.x, -floor_normal.z) / ANGLE_TO_RAD)


# Steering on a slope also turns the car towards the fall line.
func slope_steer_drift() -> int:
	var drift := (0x1000 - roundi(floor_normal.y * ONE)) >> 7
	var to_fall := (fall_line() - heading) & 0xfff
	return drift if to_fall >= 1 and to_fall <= 0x800 else -drift


func heading_forward() -> Vector3:
	var yaw := heading * ANGLE_TO_RAD
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func ground_forward() -> Vector3:
	var fwd := heading_forward()
	if grounded:
		return (fwd - floor_normal * fwd.dot(floor_normal)).normalized()
	return tilt_basis(air_tilt) * fwd


# The original keeps the car's attitude as two world-axis tilts (x: about the
# X axis, y: about the Z axis) applied before the heading.
func tilts_of(n: Vector3) -> Vector2:
	return Vector2(atan2(n.z, n.y), asin(clampf(n.x, -1.0, 1.0)))


func tilt_basis(tilt: Vector2) -> Basis:
	return Basis(Vector3.RIGHT, tilt.x) * Basis(Vector3.BACK, -tilt.y)


func hard_surface_change(n: Vector3) -> bool:
	var change := tilts_of(n) - tilts_of(floor_normal)
	return absf(change.x) >= HARD_SURFACE_CHANGE or absf(change.y) >= HARD_SURFACE_CHANGE


func heading_travel_difference(travel_dir: Vector3) -> int:
	var travel := roundi(atan2(-travel_dir.x, -travel_dir.z) / ANGLE_TO_RAD)
	var diff := (heading - travel) & 0x7ff
	if diff > 0x400:
		diff = 0x800 - diff
	return diff


func rolling(component: float) -> float:
	if absf(component) < ROLLING_STOP:
		return 0.0
	return component - signf(component) * ROLLING_FRICTION


# Single-player opponents (a71c4 < 2, a6780 == 0, not the player car).
func ai_steer_ramp() -> bool:
	return autopilot_enabled and not player_controlled and not battle


func assisted_heading(h: int) -> int:
	var quadrant := h & 0xc00
	var a := h & 0x3fc
	if a < 0xc0:
		a = 0 if a < 0xd else a - 0xc
	elif a < 0xf4:
		a += 0xc
	elif a < 0x140:
		a = 0x100 if a < 0x10d else a - 0xc
	elif a < 0x1f4:
		a += 0xc
	elif a < 0x2c0:
		a = 0x200 if a < 0x20d else a - 0xc
	elif a < 0x2f4 or a >= 0x340:
		a += 0xc
	else:
		a = 0x300 if a < 0x30d else a - 0xc
	return (quadrant + a) & 0xfff


# The AI branch of the same heading settle, in steps of 4 and with no speed gate.
func ai_assisted_heading(h: int) -> int:
	var quadrant := h & 0xc00
	var a := h & 0x3fc
	if (a != 0 and a < 0x30) \
			or (a >= 0x81 and a < 0xa0) \
			or (a >= 0x101 and a < 0x130) \
			or (a >= 0x181 and a < 0x1a0) \
			or (a >= 0x201 and a < 0x230) \
			or (a >= 0x281 and a < 0x2a0) \
			or (a >= 0x301 and a < 0x330) \
			or (a >= 0x381 and a < 0x3a0):
		a -= 4
	elif a > 0x3c0:
		a += 4
	return (quadrant + a) & 0xfff


# The original stores the fall line a quarter turn from the heading convention,
# so the push peaks when driving straight up or down the slope and vanishes
# when driving across it.
func apply_slope_push() -> void:
	var diff := (fall_line() - heading - 0x400) & 0x7ff
	if diff > 0x400:
		diff = 0x800 - diff
	if diff <= 0x100:
		return
	vel += Vector3(floor_normal.x, 0.0, floor_normal.z) * ONE * 3.0 * diff / 2048.0
	vel.y -= (1.0 - floor_normal.y) * ONE * 3.0 * diff / 1024.0


func redirect_along_surface(n: Vector3) -> void:
	var speed := vel.length() * (1.0 + 1.0 / 512.0)
	var travel := Vector3(vel.x, 0.0, vel.z)
	if travel.length_squared() < 512.0 * 512.0:
		travel = heading_forward()
	var along := travel - n * travel.dot(n)
	vel = along.normalized() * speed


func land(n: Vector3, height: float) -> bool:
	if last_ground_height - height > MAX_SAFE_DROP:
		wreck()
		return false
	var speed := vel.length()
	if speed == 0.0 or vel.dot(n) / speed >= STEEP_IMPACT:
		return true
	var climb_x := atan2(absf(vel.y), absf(vel.x))
	var climb_z := atan2(absf(vel.y), absf(vel.z))
	vel -= n * vel.dot(n) * 2.0
	var rebound := vel.dot(n)
	vel -= n * rebound * (climb_x + climb_z) / TAU
	return rebound * (1.0 - (climb_x + climb_z) / TAU) <= BOUNCE_SPEED


func probe_ground(was_grounded: bool) -> Dictionary:
	var steps := maxf(ceilf(absf(vel[vel.abs().max_axis_index()]) / ONE / MOTION_STEP), 1.0)
	var below := (GROUND_SNAP if was_grounded or vel.y <= 0.0 else GROUND_SNAP_RISING) * steps
	if was_grounded and surface == SURFACE_LOOSE:
		below = GROUND_SNAP_LOOSE * steps
	var motion := get_position_delta()
	var above := GROUND_STEP + maxf(-motion.y, 0.0) + Vector2(motion.x, motion.z).length() * tan(HARD_SURFACE_CHANGE)
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * above, global_position - Vector3.UP * below)
	var exclude: Array[RID] = [get_rid()]
	query.exclude = exclude
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and hit.collider is Car:
		exclude.append(hit.rid)
		query.exclude = exclude
		hit = space.intersect_ray(query)
	if not hit.is_empty() and hit.normal.angle_to(Vector3.UP) <= GROUND_MAX_ANGLE:
		return hit
	if was_grounded:
		return {}
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider() is not Car and collision.get_normal().angle_to(Vector3.UP) <= HARD_SURFACE_CHANGE:
			return {"normal": collision.get_normal(), "position": global_position, "collider": null}
	return {}


func resolve_collisions() -> void:
	var bounced := false
	var ground_up := floor_normal if grounded else Vector3.UP
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var n := collision.get_normal()
		var other := collision.get_collider()
		if other is Car:
			bump_car(other, n)
		elif other is RigidBody3D:
			push_prop(other, n)
		elif not bounced and n.angle_to(ground_up) > HARD_SURFACE_CHANGE:
			bounce_off_wall(n)
			bounced = true


func bounce_off_wall(n: Vector3) -> void:
	var into := vel.dot(n)
	if into >= 0.0:
		return
	if not grounded and last_ground_height - global_position.y > MAX_SAFE_DROP:
		wreck()
		return
	var incidence := -into / vel.length()
	var keep := minf(1.25 - incidence, 1.0)
	vel = (vel - n * into * 2.0) * keep
	wall_frames = WALL_STUN_FRAMES


# FUN_00056348. A fresh overlap replaces each horizontal speed with 15/16 of
# the other's, then kicks them 4 units/frame apart. The speed that was cancelled
# and, while the pair stays overlapped, each car's own speed, collect in a shove
# that apply_shove drips onto the position. Grown, stilted, and bouncing cars
# are skipped, same as the original early return. The contact count is cleared
# only when the pair is inside the proximity box and misses; leaving the box
# keeps it, so the next real overlap continues the countdown.
func bump_car(other: Car, n: Vector3) -> void:
	if item_timers[Items.GROW] != 0 or other.item_timers[Items.GROW] != 0:
		return
	if item_timers[Items.STILTS] != 0 or other.item_timers[Items.STILTS] != 0:
		return
	var frame := Engine.get_physics_frames() >> 2
	touching[other] = frame
	other.touching[self] = frame
	if bump_frame.get(other, -1) == frame:
		return
	bump_frame[other] = frame
	other.bump_frame[self] = frame
	if item_timers[Items.BOUNCE] != 0 or other.item_timers[Items.BOUNCE] != 0:
		return
	if contacts.get(other, 0) > 0:
		contacts[other] -= 1
		other.contacts[self] -= 1
		if bump_axis[other]:
			shove_x += vel.x
			other.shove_x += other.vel.x
		else:
			shove_z += vel.z
			other.shove_z += other.vel.z
		if item_timers[Items.BOMB] > 0x10:
			other.wreck()
		if other.item_timers[Items.BOMB] > 0x10:
			wreck()
		return
	var old_x := vel.x
	var old_z := vel.z
	var other_x := other.vel.x
	var other_z := other.vel.z
	vel.x = share_speed(other_x)
	vel.z = share_speed(other_z)
	other.vel.x = share_speed(old_x)
	other.vel.z = share_speed(old_z)
	var along_x := absf(n.x) >= absf(n.z)
	var kick := 0x4000 * signf(n.x if along_x else n.z)
	bump_axis[other] = along_x
	other.bump_axis[self] = along_x
	if along_x:
		shove_x -= old_x
		other.shove_x -= other_x
		vel.x += kick
		other.vel.x -= kick
	else:
		shove_z -= old_z
		other.shove_z -= other_z
		vel.z += kick
		other.vel.z -= kick
	wall_frames = CAR_STUN_FRAMES
	other.wall_frames = CAR_STUN_FRAMES
	contacts[other] = CONTACT_FRAMES
	other.contacts[self] = CONTACT_FRAMES
	bump_sound(self)
	bump_sound(other)
	if item_timers[Items.BOMB] > 0x10:
		other.wreck()
	if other.item_timers[Items.BOMB] > 0x10:
		wreck()


# FUN_00056348 queues tone 4 on each car's effect voice. FUN_00032434 plays
# that as program 1 at volume 0x3c. FUN_0007220c then plays program 0 tone 5
# for each of the first human-count cars, from that car's speed: the tone's
# volume minus 10, then 20 below 900 and 50 below 300. No particles.
func bump_sound(car: Car) -> void:
	var list: Array[Car] = items.race.cars
	var index := list.find(car)
	var humans := 0
	for other in list:
		if other.player_controlled:
			humans += 1
	if humans != 1 or index == 0:
		Sound.effect(1, 4, 0x3c)
	if index < humans:
		var volume := 70
		var spd := int(car.vel.length() / 64.0)
		if spd < 900:
			volume -= 20
		if spd < 300:
			volume -= 50
		if volume > 0:
			Sound.effect(0, 5, volume)


func release_bumps() -> void:
	var cars := get_tree().get_nodes_in_group("cars")
	var frame := Engine.get_physics_frames() >> 2
	for i in cars.size():
		var a: Car = cars[i]
		for j in range(i + 1, cars.size()):
			a.release_bump(cars[j], frame)


func release_bump(other: Car, frame: int) -> void:
	if item_timers[Items.GROW] != 0 or other.item_timers[Items.GROW] != 0:
		return
	if item_timers[Items.STILTS] != 0 or other.item_timers[Items.STILTS] != 0:
		return
	if int(touching.get(other, -1)) == frame:
		return
	if not in_bump_box(other):
		return
	contacts.erase(other)
	other.contacts.erase(self)
	bump_axis.erase(other)
	other.bump_axis.erase(self)
	bump_frame.erase(other)
	other.bump_frame.erase(self)


func in_bump_box(other: Car) -> bool:
	var dx := bump_bucket(global_position.x) - bump_bucket(other.global_position.x)
	var dz := bump_bucket(global_position.z) - bump_bucket(other.global_position.z)
	var dy := height_units(global_position.y) - height_units(other.global_position.y)
	return absi(dx) < 0x20 and absi(dz) < 0x20 and absi(dy) < 0x61


# (position * 3/4) >> 14, the coarse X/Y the original compares with 32.
func bump_bucket(metres: float) -> int:
	var v := int(metres / UNIT_METRES * ONE) * 3
	if v < 0:
		v += 3
	return (v >> 2) >> 14


func height_units(metres: float) -> int:
	var fixed := int(metres / UNIT_METRES * ONE)
	if fixed < 0:
		fixed += 0xfff
	return fixed >> 12


func share_speed(v: float) -> float:
	var n := int(v) * 15
	if n < 0:
		n += 15
	return n >> 4


# FUN_0003a330 at 0x3d14c. Up to 4 units of shove move the car each game frame.
# A remainder inside that range is applied whole, but a small negative remainder
# is subtracted, so it moves the other way (subu at 0x3d188).
func apply_shove() -> void:
	var step := take_shove(shove_x)
	shove_x = step.y
	global_position.x += step.x / ONE * UNIT_METRES
	step = take_shove(shove_z)
	shove_z = step.y
	global_position.z += step.x / ONE * UNIT_METRES


func take_shove(amount: float) -> Vector2:
	if amount > 0.0:
		if amount < 0x4001:
			return Vector2(amount, 0.0)
		return Vector2(0x4000, amount - 0x4000)
	if amount < 0.0:
		if amount < -0x4000:
			return Vector2(-0x4000, amount + 0x4000)
		return Vector2(-amount, 0.0)
	return Vector2.ZERO


func push_prop(prop: RigidBody3D, n: Vector3) -> void:
	var closing := -vel.dot(n)
	if closing <= 0.0:
		return
	prop.apply_central_impulse(-n * closing * FIXED_TO_MPS * prop.mass * 1.6)
	vel += n * closing * 0.1


# FUN_0002a824 queues tone 5 on the car channel when this is a race. The wreck
# state reaches 2 in that same update, which is when FUN_00071ef0 plays tone 7.
# FUN_00032360 only voices car 0 while a single human is playing.
func wreck() -> void:
	if wreck_frames > 0:
		return
	wreck_frames = WRECK_FRAMES
	vel = Vector3.ZERO
	if not battle:
		var players := 0
		for other in items.race.cars:
			if other.player_controlled:
				players += 1
		if players != 1 or player_controlled:
			Sound.effect(0, 5)
	Sound.effect(0, 7)
	Sound.stop_engine(self)
	Fx.despawn(global_position)


# FUN_0003a330 surface 0xe. FUN_0002ae04 plays tone 9, marks the wreck as water
# and spawns the ring. The same frame then advances the state to 2, which is
# when FUN_00071ef0 plays tone 10.
func begin_splash() -> void:
	if wreck_frames > 0 or splash_wreck:
		return
	splash_wreck = true
	splash_state = 2
	wreck_frames = 1
	vel = Vector3.ZERO
	Sound.effect(0, 9)
	Sound.effect(0, 10)
	Sound.stop_engine(self)
	Fx.puddle_ring(global_position)


# After the trigger frame the state counts 3, 4, ... and FUN_000388c4 respawns
# at 0x1e. FUN_0002b218 runs at 3 and 6, FUN_0002ae04 again at 8 and 0x10.
func step_splash(authoritative: bool) -> void:
	if splash_state >= 0x1e:
		if authoritative and not respawn_held:
			splash_wreck = false
			splash_state = 0
			safe_history.clear()
			respawn()
		return
	splash_state += 1
	if splash_state == 3 or splash_state == 6:
		Fx.puddle_droplet(global_position)
	elif splash_state == 8 or splash_state == 0x10:
		if authoritative:
			Sound.effect(0, 9)
		Fx.puddle_ring(global_position)
	if splash_state == 0x1e and authoritative:
		if respawn_held:
			splash_state = 0x1d
			return
		splash_wreck = false
		splash_state = 0
		safe_history.clear()
		respawn()


# FUN_0002f844: a track script carries the car; it counts as grounded on a flat
# floor at whatever height the script sets.
func hold() -> void:
	held = true
	floor_normal = Vector3.UP
	air_tilt = Vector2.ZERO
	display_tilt = Vector2.ZERO


func release_hold() -> void:
	held = false
	var values: Array = HANDLING[handling]
	grip = values[1]
	engine = values[2]


func respawn() -> void:
	if battle:
		battle.respawn(self)
	else:
		var race := items.race
		var i := race.cars.find(self)
		var node := track.respawn_node(race.respawn_nodes[i])
		race.nodes[i] = node
		race.respawn_nodes[i] = node
		teleport(track.node_transform(node, 0.5), node)
	begin_appear()


# Two cars respawned on the same node line up capsule inside capsule, which
# leaves the engine no separating direction and it often lifts one onto the
# other. The original never resolves overlaps itself; it only bumps the pair
# apart sideways, so a sunk pair skips the engine and bumps instead.
func sunk_into(other: Car) -> bool:
	return capsule_gap(other).length() < (collision_shape.shape as CapsuleShape3D).radius * 2.0 - SUNK_SLACK


func sunk_normal(other: Car) -> Vector3:
	var gap := capsule_gap(other)
	var flat := Vector3(gap.x, 0.0, gap.z)
	if flat.length_squared() < 0.0001:
		flat = global_basis.x
	return flat.normalized()


func capsule_gap(other: Car) -> Vector3:
	var mine := capsule_axis()
	var theirs := other.capsule_axis()
	var closest := Geometry3D.get_closest_points_between_segments(mine[0], mine[1], theirs[0], theirs[1])
	return closest[0] - closest[1]


func capsule_axis() -> PackedVector3Array:
	var capsule := collision_shape.shape as CapsuleShape3D
	var half := collision_shape.global_basis.y.normalized() * (capsule.height * 0.5 - capsule.radius)
	var centre := collision_shape.global_position
	return PackedVector3Array([centre - half, centre + half])


func teleport(xform: Transform3D, node := -1) -> void:
	global_transform = xform
	heading = wrapi(roundi(xform.basis.get_euler().y / ANGLE_TO_RAD), 0, 4096)
	vel = Vector3.ZERO
	thrust_ramp = 0
	wreck_frames = 0
	appear_frames = 0
	visual.visible = true
	splash_wreck = false
	splash_state = 0
	wall_frames = 0
	surface = 0
	release_hold()
	if items:
		items.respawn(self)
	air_frames = 0
	last_ground_height = xform.origin.y
	last_ground_position = xform.origin
	shown_heading = heading
	shown_heading_from = shown_heading
	body_lean = 0
	shown_lean = 0.0
	shown_lean_from = 0.0
	body.rotation.z = 0.0
	grounded = node >= 0
	seat(track.node_slope(node) if node >= 0 else Vector2.ZERO)


# FUN_000388c4 copies the node slope into the drawn tilt and leaves the car
# there until physics is allowed to run.
func plant(node: int) -> void:
	grounded = true
	shown_heading = heading
	shown_heading_from = heading
	seat(track.node_slope(node))


func seat(tilt: Vector2) -> void:
	floor_normal = tilt_basis(tilt) * Vector3.UP
	air_tilt = tilt
	display_tilt = tilt
	shown_tilt = tilt
	shown_tilt_from = tilt
	global_basis = tilt_basis(tilt) * Basis(Vector3.UP, heading * ANGLE_TO_RAD)
	collision_shape.global_transform = Transform3D(global_basis, global_position) * collision_offset
	reset_physics_interpolation()
	if puppet:
		puppet_from = global_transform
		puppet_to = global_transform


# FUN_0002ad40 plays at the respawn point. With more than one player the car
# stays undrawn until car+0x1f75c8 passes 0xf (FUN_00026628).
func begin_appear() -> void:
	appear_frames = 1
	var players := 0
	for other in items.race.cars:
		if other.player_controlled:
			players += 1
	if players > 1:
		visual.visible = false
	Fx.appear(self)


func step_appear() -> bool:
	if appear_frames == 0:
		return false
	appear_frames += 1
	var players := 0
	for other in items.race.cars:
		if other.player_controlled:
			players += 1
	visual.visible = players < 2 or appear_frames > 0xf
	if appear_frames == 0x1e:
		appear_frames = 0
		visual.visible = true
	return true


# A held direction adds 4 a frame and letting go steps by 8 toward zero. The two
# comparisons are not exclusive, so a remainder of 4 stays until the next turn.
# Boats step by 1 (FUN_0003a330 when the vehicle kind is 1). Submarines skip it.
func update_body_lean() -> void:
	if vehicle_kind == VEHICLE_SUB:
		return
	var step := 1 if vehicle_kind == VEHICLE_BOAT else 4
	var settle := 1 if vehicle_kind == VEHICLE_BOAT else 8
	if steer_input > 0:
		body_lean += step
	elif steer_input < 0:
		body_lean -= step
	else:
		if body_lean > 0:
			body_lean -= settle
		if body_lean < 0:
			body_lean += settle
	body_lean = clampi(body_lean, -0x10, 0x10)


# On flat water the lean replaces the ground tilt (FUN_0001f60c). The cos term
# is the rotation about Z and the sin term the rotation about X, which rolls
# the hull about its heading.
func boat_bank() -> Vector2:
	var h := -heading & 0xfff
	var cos_h := game_sine(h + 0x400)
	var sin_h := game_sine(h)
	if cos_h < 0:
		cos_h += 7
	if sin_h < 0:
		sin_h += 7
	var along := (cos_h >> 3) * body_lean
	var across := (sin_h >> 3) * body_lean
	if along < 0:
		along += 0xf
	if across < 0:
		across += 0xf
	return Vector2(across >> 4, along >> 4) * ANGLE_TO_RAD


func game_sine(angle: int) -> int:
	return int(round(sin(float(angle & 0xfff) * ANGLE_TO_RAD) * 4096.0))


# FUN_0001f60c adds the bob to (camera height - car height). That row of the
# view is negated, so the stored -64 draws a submarine 64 units above the
# ground contact, and the boat's +8 sits the hull 8 units down in the water.
# FUN_0002a964 drops a bubble above a sub.
func vehicle_lift() -> int:
	var frame := Engine.get_physics_frames() >> 2
	var slot := get_tree().get_nodes_in_group("cars").find(self)
	var wave := game_sine((slot * 4 + frame) * 0x100)
	if vehicle_kind == VEHICLE_BOAT:
		var spd := maxi(int(vel.length() / 64.0), 0x400)
		return ((spd * (wave >> 8)) >> 12) - 8
	return 0x40 + (wave >> 10)


func blow_bubbles() -> void:
	var frame := Engine.get_physics_frames() >> 2
	var slot := get_tree().get_nodes_in_group("cars").find(self)
	if slot >= 4 or (frame & 3) != 0 or (randi() & 1) == 0:
		return
	var jitter := (randi() & 0x7f) - 0x3f
	var ang := (-heading + jitter) & 0xfff
	var x := int(global_position.x / UNIT_METRES) + ((game_sine(ang) * -0x60) >> 12)
	var z := int(global_position.z / UNIT_METRES) + ((game_sine(ang + 0x400) * 0x60) >> 12)
	var h := int(global_position.y / UNIT_METRES) + 0x40
	Fx.spawn_script(x, z, h, Fx.BUBBLE, 1)


func update_orientation() -> void:
	if wreck_frames > 0:
		return
	var yaw := Basis(Vector3.UP, heading * ANGLE_TO_RAD)
	var tilt := tilts_of(floor_normal) if grounded else air_tilt
	var step := float(Engine.get_physics_frames() % PHYSICS_TICKS_PER_GAME_FRAME + 1) / PHYSICS_TICKS_PER_GAME_FRAME
	shown_heading = wrapf(shown_heading_from + wrapf(heading - shown_heading_from, -2048.0, 2048.0) * step, 0.0, 4096.0)
	shown_tilt = shown_tilt_from.lerp(display_tilt, step)
	shown_lean = lerpf(shown_lean_from, float(body_lean), step)
	if vehicle_kind != VEHICLE_CAR:
		visual.position.y = vehicle_lift() * UNIT_METRES
	global_basis = tilt_basis(shown_tilt) * Basis(Vector3.UP, shown_heading * ANGLE_TO_RAD)
	collision_shape.global_transform = Transform3D(tilt_basis(tilt) * yaw, global_position) * collision_offset
	if vehicle_kind == VEHICLE_CAR:
		body.rotation.z = shown_lean * 512.0 / 96.0 * ANGLE_TO_RAD
	else:
		body.rotation.z = 0.0


func blend_puppet() -> void:
	var along := clampf(puppet_age * 30.0, 0.0, 1.0)
	global_transform = puppet_from.interpolate_with(puppet_to, along)


func apply_puppet(xform: Transform3D, next_vel: Vector3, next_heading: int, lean: float, steer: float, lift: float, scale: int, next_body_lift: int, next_stretch: int, next_spread: int, next_burn: int, next_wreck: int, next_splash: bool, show: bool, next_grounded: bool, next_surface: int, item: int, counts: PackedByteArray) -> void:
	puppet_from = xform if global_position.distance_squared_to(xform.origin) > 64.0 else global_transform
	puppet_to = xform
	puppet_age = 0.0
	vel = next_vel
	heading = next_heading
	body.rotation.z = lean
	steer_input = roundi(steer)
	visual.position.y = lift
	item_scale = scale
	body_lift = next_body_lift
	stretch = next_stretch
	rear_spread = next_spread
	burn_frames = next_burn
	update_shape()
	var was_splash := splash_wreck
	splash_wreck = next_splash
	if splash_wreck and not was_splash:
		splash_state = 2
		Fx.puddle_ring(xform.origin)
	elif not splash_wreck:
		splash_state = 0
	var was := wreck_frames
	wreck_frames = next_wreck
	if was == 0 and next_wreck > 0 and not next_splash:
		if next_wreck == 1 and battle:
			Fx.appear(self, xform.origin)
		else:
			Fx.despawn(xform.origin)
	elif was > 0 and next_wreck == 0:
		begin_appear()
	elif next_wreck > 0 and not next_splash:
		Fx.wreck_trail(self, 31 - next_wreck)
	visible = show
	grounded = next_grounded
	surface = next_surface
	selected_item = item
	for i in counts.size():
		item_counts[i] = counts[i]
	item_total = 0
	for count in item_counts:
		item_total += count


func update_wheels() -> void:
	var steer_angle := -steer_input / 7.0 * MAX_STEER_ANGLE
	for i in steer_pivots.size():
		steer_pivots[i].rotation.y = steer_angle * steer_sign[i]
	wheel_travel += vel.dot(ground_forward()) * FIXED_TO_MPS / Engine.physics_ticks_per_second
	for i in wheel_spinners.size():
		var spin := -wheel_travel / wheel_radii[i]
		if wheel_spin_z[i]:
			wheel_spinners[i].rotation.z = spin
		else:
			wheel_spinners[i].rotation.x = spin


func speed_kmh() -> float:
	return vel.length() * FIXED_TO_MPS * 3.6
