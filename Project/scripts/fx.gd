extends Node3D

# The original draws these as textured quads. Tools/export_particles.py writes
# the sheets from a Circuit Breakers TEX: fire (tpage 0x2e), smoke (tpage 0x3e),
# the same smoke page subtracted (tpage 0x5e), the weather streak and the
# respawn grid (tpage 0x2a), the splash ring (tpage 0x6a) and the Venice ripple
# arc, the top of that ring.

const FIRE := 0
const SMOKE := 1
const RING := 2
const STREAK := 3
const ARC := 4
const SUB := 5
const RESPAWN := 6
const WAKE := 7
const CLOUD := 8
# Type byte of a script particle. FUN_0002c5a0 and FUN_00021e48 switch on it.
const BURST := 0
const WRECK_SMOKE := 1
const JUMP_SMOKE := 2
const DRIFT_SMOKE := 4
const BURST_CORE := 0x0e
const RESPAWN_GRID := 0x15
# FUN_0002ba38 writes type 0x21 + car. The next seven are the same orbit.
const SWIRL := 0x21
const BOOST_FIRE := 0x18
# FUN_00020a80 drops 0x31 from a cloud and 0x32–0x36 over its target.
const CLOUD_PUFF := 0x31
const CLOUD_OVER := 0x32
const PUDDLE_DROP := 0x3a
const SMOKE_NEG_Z := 0x3b
const SMOKE_POS_Z := 0x3c
const SMOKE_NEG_X := 0x3d
const SMOKE_POS_X := 0x3e
const BUBBLE := 0x41
# FUN_0002b438 writes type 0x42 + car for the bomb fuse.
const BOMB_SMOKE := 0x42
const SHOT_PUFF := 0x4a
const GREEN_SMOKE := 0x4b
const ORANGE_SMOKE := 0x4c
const SMALL_FIRE := 0x4d
const SHOT_TRAIL := 0x50
const SPARK_EMBER := 0x51
const WRECK_SPARK := 0x52
const PUDDLE_RING := 0x89
const WAKE_SPRITE := 0x91
const WATER_RING := 0x93
# FUN_0002c5a0 type 0x52 reads DAT_00014e60. Shade 0 rises fastest.
const SPARK_RISE := [31, 31, 30, 29, 27, 24, 22, 19, 16, 12, 9, 7, 4, 2, 1, 0]
const POOL := 64
const FLAKES := 32
const RIPPLES := 48
const SHEETS := [
	{"path": "res://textures/particles_fire.png", "cells": Vector2(4, 4), "frames": 16},
	{"path": "res://textures/particles_smoke.png", "cells": Vector2(8, 2), "frames": 16},
	{"path": "res://textures/particles_ring.png", "cells": Vector2(1, 1), "frames": 1},
	{"path": "res://textures/particles_streak.png", "cells": Vector2(1, 1), "frames": 1},
	{"path": "res://textures/particles_arc.png", "cells": Vector2(1, 1), "frames": 1},
	{"path": "res://textures/particles_smoke.png", "cells": Vector2(8, 2), "frames": 16, "subtract": true},
	{"path": "res://textures/particles_respawn.png", "cells": Vector2(4, 4), "frames": 16, "overlay": true},
	{"path": "res://textures/particles_wake.png", "cells": Vector2(8, 1), "frames": 8},
	{"path": "res://textures/particles_smoke.png", "cells": Vector2(8, 2), "frames": 16, "subtract": true, "near": 80.0},
]
# FUN_0002c474 makes the sprite 1.5× as wide as it is tall in the 512×240
# framebuffer. Shown 4:3, that blob is round, and it is linked at the front of
# the ordering table so it covers the car and the ground.
const FRAME_WIDE := 1.5 * (240.0 / 512.0) * (4.0 / 3.0)
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform sampler2D sheet : filter_nearest, repeat_disable;
uniform vec2 cells = vec2(4.0, 4.0);
// The ordering-table bias in metres. The quad slides toward the camera along its
// view ray and shrinks to keep its screen size, so it draws over what it sits in.
uniform float near = 0.0;
varying vec4 tint;
varying vec2 frame;
varying float mirrored;
void vertex() {
	tint = COLOR;
	frame = INSTANCE_CUSTOM.rg;
	mirrored = INSTANCE_CUSTOM.a;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 origin = MODEL_MATRIX[3].xyz;
	// b above 0.5 lays the quad on the ground. Past 1.5 the instance basis is kept,
	// so a wake can be stretched and flipped. Otherwise the amount past 1 is a turn.
	float turn = INSTANCE_CUSTOM.b - 1.0;
	if (INSTANCE_CUSTOM.b > 1.5) {
		MODELVIEW_MATRIX = VIEW_MATRIX * MODEL_MATRIX;
	} else if (abs(INSTANCE_CUSTOM.b) > 0.5) {
		float c = cos(turn * TAU);
		float s = sin(turn * TAU);
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			vec4(c * sx, 0.0, s * sx, 0.0),
			vec4(s * sy, 0.0, -c * sy, 0.0),
			vec4(0.0, sx, 0.0, 0.0),
			vec4(origin, 1.0));
	} else {
		// Local XY becomes the camera plane. X is flipped so the quad's front faces the camera.
		vec4 view = VIEW_MATRIX * vec4(origin, 1.0);
		float pull = clamp((view.z + near) / min(view.z, -0.001), 0.05, 1.0);
		MODELVIEW_MATRIX = mat4(
			vec4(-sx * pull, 0.0, 0.0, 0.0),
			vec4(0.0, sy * pull, 0.0, 0.0),
			vec4(0.0, 0.0, sx * pull, 0.0),
			vec4(view.xyz * pull, 1.0));
	}
}
void fragment() {
	vec2 cell = floor(frame * cells);
	float u = UV.x;
	if (mirrored > 0.5)
		u = 1.0 - u;
	vec4 texel = texture(sheet, (vec2(u, UV.y) + cell) / cells);
	ALBEDO = texel.rgb * tint.rgb;
	ALPHA = texel.a * tint.a;
}
"""

var script_meshes: Array[MultiMesh] = []
var script_instances: Array[MultiMeshInstance3D] = []
var script_x := PackedInt32Array()
var script_y := PackedInt32Array()
var script_h := PackedInt32Array()
var script_life := PackedInt32Array()
var script_type := PackedInt32Array()
var script_kind := PackedInt32Array()
var script_byte := PackedInt32Array()
# Where each particle was drawn on the last two game frames, and its offset from
# the car it rides on. The physics ticks in between blend or follow.
var script_from := PackedVector3Array()
var script_at := PackedVector3Array()
var script_offset := PackedVector3Array()
var items: Items
var respawn_core: MultiMesh
var respawn_core_instance: MultiMeshInstance3D
var weather := 0
var flake_pos := PackedVector3Array()
var flake_mesh: MultiMesh
var flake_instance: MultiMeshInstance3D
var ripple_pos := PackedVector3Array()
var ripple_life := PackedInt32Array()
var ripple_mesh: MultiMesh
var ripple_instance: MultiMeshInstance3D
var world_live := false
# With physics interpolation on, MultiMesh.get_instance_transform returns the
# transform from the last interpolation reset, so the drawn basis is kept here.
var bases := {}
var game_tick := 0


func _ready() -> void:
	process_physics_priority = 10
	if not Data.present():
		set_physics_process(false)
		return
	boot()


func boot() -> void:
	if not script_meshes.is_empty():
		return
	set_physics_process(true)
	var shader := Shader.new()
	shader.code = SHADER
	var sub_shader := Shader.new()
	sub_shader.code = SHADER.replace("blend_add", "blend_sub")
	var overlay_shader := Shader.new()
	# PS1 modulates by the colour byte over 128, and those bytes pass 128. The
	# instance colour is stored as byte/255 so the multiply can exceed 1.
	overlay_shader.code = SHADER.replace("cull_disabled", "cull_disabled, depth_test_disabled").replace(
		"ALBEDO = texel.rgb * tint.rgb;",
		"ALBEDO = texel.rgb * tint.rgb * (255.0 / 128.0);")
	var quads: Array[QuadMesh] = []
	var fire_sheet: Texture2D
	for info: Dictionary in SHEETS:
		var material := ShaderMaterial.new()
		if info.get("subtract", false):
			material.shader = sub_shader
		elif info.get("overlay", false):
			material.shader = overlay_shader
			material.render_priority = 126
		else:
			material.shader = shader
		var image := Image.new()
		image.load_png_from_buffer(Data.bytes(info.path))
		var texture := ImageTexture.create_from_image(image)
		material.set_shader_parameter("sheet", texture)
		material.set_shader_parameter("cells", info.cells)
		material.set_shader_parameter("near", float(info.get("near", 0.0)) * Car.UNIT_METRES)
		if info.path.ends_with("particles_fire.png"):
			fire_sheet = texture
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = material
		quads.append(quad)
	script_x.resize(POOL)
	script_y.resize(POOL)
	script_h.resize(POOL)
	script_life.resize(POOL)
	script_type.resize(POOL)
	script_kind.resize(POOL)
	script_byte.resize(POOL)
	script_from.resize(POOL)
	script_at.resize(POOL)
	script_offset.resize(POOL)
	for quad in quads:
		var built: Array = add_multi(quad, POOL)
		script_meshes.append(built[0])
		script_instances.append(built[1])
	var core_material := ShaderMaterial.new()
	core_material.shader = overlay_shader
	core_material.render_priority = 127
	core_material.set_shader_parameter("sheet", fire_sheet)
	core_material.set_shader_parameter("cells", Vector2(4, 4))
	var core_quad := QuadMesh.new()
	core_quad.size = Vector2.ONE
	core_quad.material = core_material
	var core_built: Array = add_multi(core_quad, POOL)
	respawn_core = core_built[0]
	respawn_core_instance = core_built[1]
	flake_pos.resize(FLAKES)
	var flakes: Array = add_multi(quads[STREAK], FLAKES)
	flake_mesh = flakes[0]
	flake_instance = flakes[1]
	ripple_pos.resize(RIPPLES)
	ripple_life.resize(RIPPLES)
	var ripples: Array = add_multi(quads[ARC], RIPPLES)
	ripple_mesh = ripples[0]
	ripple_instance = ripples[1]


func add_multi(quad: QuadMesh, count: int) -> Array:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.instance_count = count
	multi.mesh = quad
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO)
	var shown: Array[Basis] = []
	shown.resize(count)
	shown.fill(hidden.basis)
	bases[multi] = shown
	for i in count:
		multi.set_instance_transform(i, hidden)
	return [multi, instance]


# Script particles step once per game frame. Every physics tick after the cars
# have moved, the ones riding a car or a shot are put back on it and the rest
# blend between their last two game-frame spots, so the interpolated draw is
# smooth at any frame rate.
func _physics_process(_delta: float) -> void:
	if not world_live:
		return
	var step := float(Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME + 1) / Car.PHYSICS_TICKS_PER_GAME_FRAME
	for i in POOL:
		if script_life[i] == 0:
			continue
		var type := script_type[i]
		var at := script_from[i].lerp(script_at[i], step)
		if type == SHOT_PUFF:
			at = items.shot_visual(script_byte[i])
		elif rider(type):
			at = items.cars[script_byte[i]].global_position + script_offset[i]
		place(script_meshes[script_kind[i]], i, at)
		if type == WRECK_SPARK or type == SHOT_PUFF or rider(type):
			place(script_meshes[FIRE], i, at)
		elif type == RESPAWN_GRID:
			place(respawn_core, i, at)


func rider(type: int) -> bool:
	return (type >= CLOUD_OVER and type < CLOUD_OVER + 5) or (type >= BOMB_SMOKE and type < BOMB_SMOKE + 8)


func place(multi: MultiMesh, slot: int, at: Vector3) -> void:
	var basis: Basis = bases[multi][slot]
	if basis.x == Vector3.ZERO:
		return
	multi.set_instance_transform(slot, Transform3D(basis, at))


func car_frame(car: Car) -> void:
	if car.wreck_frames > 0 or not car.grounded:
		return
	# FUN_0003a330 surface 0xc every 8 frames, surface 4 every frame. FUN_0002bad8
	# lays a wake out to either side. Type 4 below is the car drift puff only.
	if car.surface == Car.SURFACE_WATER or car.surface == Car.SURFACE_SPRAY:
		wake(car)
		return
	if car.vehicle_kind != Car.VEHICLE_CAR:
		return
	var spd := car.vel.length() / 64.0
	# FUN_0003a330 / FUN_0002ab90. Type 4 is a car-world puff on odd frames, and
	# only while the heading is 0x81..0x3ff off the travel direction at speed,
	# or while held at full throttle below that speed. A coin flip thins it.
	if ((Engine.get_physics_frames() >> 2) & 1) == 0:
		return
	if not car.get_viewport().get_camera_3d().is_position_in_frustum(car.global_position):
		return
	var smoke := false
	if spd > 0x200:
		var travel := car.travel_direction(spd)
		var travel_h := roundi(atan2(-travel.x, -travel.z) / Car.ANGLE_TO_RAD)
		var slip := (car.heading - travel_h) & 0xfff
		if slip > 0x800:
			slip = 0x1000 - slip
		smoke = slip >= 0x81 and slip < 0x400 and (randi() & 1) == 0
	elif car.accel_input == 7 and (randi() & 1) != 0:
		smoke = true
	if smoke:
		var units := car.global_position / Car.UNIT_METRES
		spawn_script(int(units.x), int(units.z), int(units.y), DRIFT_SMOKE, 9)


# FUN_0002bad8. Below 0x200 a ring sits on the vehicle. Faster, a wake sprite
# leaves from each side. Singleplayer only does this for the player car.
func wake(car: Car) -> void:
	if not car.get_viewport().get_camera_3d().is_position_in_frustum(car.global_position):
		return
	# NOTE: This disables wake particles for CPU controlled cars, which is probably for performance reasons on PS1
	# We can disable this on PC
	var humans := 0
	for other in car.items.race.cars:
		if other.player_controlled:
			humans += 1
	if humans == 1 and not car.player_controlled:
		return
	var game := Engine.get_physics_frames() >> 2
	if car.surface != Car.SURFACE_SPRAY and (game & 7) != 0:
		return
	var units := car.global_position / Car.UNIT_METRES
	if car.vel.length() / 64.0 < 0x200:
		spawn_script(int(units.x), int(units.z), int(units.y), WATER_RING, 1)
		return
	var heading := -car.heading
	for side in [0x200, -0x200]:
		var ang: int = (heading + side) & 0xfff
		var x := int(units.x) + ((car.game_sine(ang) * -0x30) >> 12)
		var z := int(units.z) + ((car.game_sine(ang + 0x400) * 0x30) >> 12)
		var bits: int = ((heading + (side >> 1)) >> 4) & 0xff
		spawn_script(x, z, int(units.y), WAKE_SPRITE, 1, false, bits)


# FUN_0002a824. Type 0 is the fire-sheet burst; type 0x0e is the core
# FUN_0002c33c draws on top of it.
func despawn(at: Vector3) -> void:
	var x := int(at.x / Car.UNIT_METRES)
	var z := int(at.z / Car.UNIT_METRES)
	var h := int(at.y / Car.UNIT_METRES)
	spawn_script(x, z, h, BURST, 1)
	spawn_script(x, z, h, BURST_CORE, 1)


# FUN_0003a330 while the wreck state is climbing. Type 1 at 2, 5 and 11.
# Type 0x52 on the odd states below 12.
func wreck_trail(car: Car, state: int) -> void:
	if state < 2 or state >= 0x1e:
		return
	if not car.get_viewport().get_camera_3d().is_position_in_frustum(car.global_position):
		return
	if state == 2 or state == 5 or state == 0xb:
		var x := int(car.global_position.x / Car.UNIT_METRES) + (randi() & 0x1f) - 0xf
		var z := int(car.global_position.z / Car.UNIT_METRES) + (randi() & 0x1f) - 0xf
		var h := int(car.global_position.y / Car.UNIT_METRES)
		spawn_script(x, z, h, WRECK_SMOKE, 1)
	if state < 0xc and (state & 1) != 0:
		var bits := randi() & 0xff
		var spark_x := int(car.global_position.x / Car.UNIT_METRES) + ((bits >> 4) - 8) * 6
		var spark_z := int(car.global_position.z / Car.UNIT_METRES) + ((bits & 0xf) - 8) * 6
		var spark_h := int(car.global_position.y / Car.UNIT_METRES) + (randi() & 0xf) + 0x40
		spawn_script(spark_x, spark_z, spark_h, WRECK_SPARK, 1, false, bits)


# FUN_0002ad40. The car's score color tints the tpage 0x2a grid.
func appear(car: Car, at := Vector3.INF) -> void:
	var point := car.global_position if is_inf(at.x) else at
	var units := point / Car.UNIT_METRES
	var rgb := car.color
	var packed := (roundi(rgb.r * 255.0) & 0xff) | ((roundi(rgb.g * 255.0) & 0xff) << 8) | ((roundi(rgb.b * 255.0) & 0xff) << 16)
	spawn_script(int(units.x), int(units.z), int(units.y), RESPAWN_GRID, 1, false, packed)


# FUN_0006de3c calls FUN_0002ba38 four times, a quarter turn apart. FUN_0002e1c8
# then orbits that car: the angle byte grows by (age >> 2) + 1 and the radius
# is age*8. tpage 0x6a is the respawn page with abr 3, a quarter add.
func winner_swirls(index: int) -> void:
	for angle in [0, 0x40, 0x80, 0xc0]:
		spawn_script(0, 0, 0, SWIRL + index, 1, false, angle)


# FUN_000574a4 / FUN_0002b140. Even frames of the rocket drop a type 0x18
# flame 0x5a units behind the locked heading, jittered by a few units.
# FUN_00080398 is the sine and FUN_00080468 the cosine.
func boost_fire(car: Car) -> void:
	var heading := -car.locked_heading
	var back_x: int = -car.game_sine(heading) * 0x5a
	var back_z: int = car.game_sine(heading + 0x400) * 0x5a
	if back_x < 0:
		back_x += 0xfff
	if back_z < 0:
		back_z += 0xfff
	var units := car.global_position / Car.UNIT_METRES
	var x := int(units.x) + (back_x >> 12) + (randi() & 0x1f) - 0x10
	var z := int(units.z) + (back_z >> 12) + (randi() & 0x1f) - 0x10
	var h := int(units.y) + (randi() & 0xf)
	spawn_script(x, z, h, BOOST_FIRE, 1)


# FUN_0003a330 / FUN_0002b1b8: a burning car leaves a type 1 puff every 8 frames.
func burn_smoke(car: Car) -> void:
	var units := car.global_position / Car.UNIT_METRES
	spawn_script(int(units.x) + (randi() & 0x1f) - 0xf, int(units.z) + (randi() & 0x1f) - 0xf, int(units.y), WRECK_SMOKE, 1)


# FUN_0002b438. The fuse puff keeps its offset from the car; world_frame lifts it.
func bomb_smoke(car_index: int) -> void:
	spawn_script((randi() & 0x1f) - 0xf, (randi() & 0x1f) - 0xf, 0, BOMB_SMOKE + car_index, 9, false, car_index)


# FUN_0002b278 / FUN_0002b710: smoke rising out of a cloud and around it.
func cloud_puff(x: int, y: int, height: int) -> void:
	spawn_script(x, y, height, CLOUD_PUFF, 1)


# FUN_0002b828. Part 0 sits on the target, parts 1–4 0x30 units to each side.
func cloud_over(part: int, target: int) -> void:
	spawn_script(0, 0, 0, CLOUD_OVER + part, 1, false, target)


# FUN_0002b524 takes a slot even when the pool is full. The puff rides the shot
# in pool slot `slot` and stays where it ended.
func shot_puff(slot: int) -> void:
	spawn_script(0, 0, 0, SHOT_PUFF, 0x12, true, slot)


# FUN_0002b738 type 0x50, the shot's trail.
func shot_trail(x: int, y: int, height: int) -> void:
	spawn_script(x, y, height, SHOT_TRAIL, 0x10)


const SMOKE_UNITS := 36.0
const FIRE_UNITS := 32.0
# Type 0 uses scale*0x18, drawn at 192. Type 0x18 uses scale<<5, so 192 * 0x20 / 0x18.
const BOOST_UNITS := 256.0
# Types 0x21–0x28 use scale*9 through the same sizer, so 192 * 9 / 0x18.
const SWIRL_UNITS := 72.0
# FUN_00069178 sizes the flake in screen pixels: width is local_30/z and height
# is 0x300/z, with z the camera depth in world units shifted down by 2. Against
# the port projection (H = 240) that is a constant world size.
const SNOW_W := 19.2
const RAIN_W := 9.6
const FLAKE_H := 12.8
const SNOW_FALL := 8
const RAIN_FALL := 0x40
const FLAKE_TINT := Color(0x70 / 128.0, 0x78 / 128.0, 0x80 / 128.0, 1.0)
# FUN_00069aac: code 0x26, tpage 0x6a (abr 3 is a quarter add), RGB 0x50, 0x60, 0x40 over 128.
const RIPPLE_TINT := Color(0x50 / 128.0, 0x60 / 128.0, 0x40 / 128.0, 0.25)


func track_particle(x: int, y: int, height: int, type: int) -> void:
	var kind := type & 0xff
	if kind == 0x3b or kind == 0x3c:
		x += jitter()
	else:
		y += jitter()
	spawn_script(x, y, height + jitter(), kind, 9)


func track_effect(x: int, y: int, height: int, type: int, span: int, _extra: int) -> void:
	var life_span := span & 0xffff
	if life_span == 0:
		return
	spawn_script(x, y, height, type & 0xff, life_span)


func puddle_ring(at: Vector3) -> void:
	spawn_script(int(at.x / Car.UNIT_METRES), int(at.z / Car.UNIT_METRES), int(at.y / Car.UNIT_METRES), PUDDLE_RING, 1, true)


func puddle_droplet(at: Vector3) -> void:
	var x := int(at.x / Car.UNIT_METRES) + (randi() & 0x1f) - 0xf
	var z := int(at.z / Car.UNIT_METRES) + (randi() & 0x1f) - 0xf
	var h := int(at.y / Car.UNIT_METRES)
	spawn_script(x, z, h, PUDDLE_DROP, 9)


func spawn_script(x: int, y: int, height: int, type: int, span: int, overwrite := false, bits := 0) -> int:
	var kind := sheet_for(type)
	if kind < 0:
		return -1
	var slot := -1
	for i in range(POOL - 1, -1, -1):
		if script_life[i] == 0:
			slot = i
			break
	if slot < 0:
		if not overwrite:
			return -1
		slot = (POOL - 1) - (type & 3)
	script_x[slot] = x
	script_y[slot] = y
	script_h[slot] = height
	script_life[slot] = span
	script_type[slot] = type
	script_kind[slot] = kind
	script_byte[slot] = bits
	script_from[slot] = Vector3.INF
	for other in script_meshes.size():
		if other != kind:
			hide_slot(script_meshes[other], slot)
	hide_slot(respawn_core, slot)
	return slot


func sheet_for(type: int) -> int:
	if type == BURST or type == BURST_CORE:
		return FIRE
	if type == WRECK_SMOKE or type == WRECK_SPARK:
		return SUB
	if type == RESPAWN_GRID:
		return RESPAWN
	if type == JUMP_SMOKE or type == DRIFT_SMOKE or type == PUDDLE_DROP or type == SMOKE_NEG_Z or type == SMOKE_POS_Z or type == SMOKE_NEG_X or type == SMOKE_POS_X or type == GREEN_SMOKE or type == ORANGE_SMOKE or type == SPARK_EMBER or type == SHOT_TRAIL:
		return SMOKE
	if type == CLOUD_PUFF or type == SHOT_PUFF or (type >= BOMB_SMOKE and type < BOMB_SMOKE + 8):
		return SUB
	if type >= CLOUD_OVER and type < CLOUD_OVER + 5:
		return CLOUD
	if type == BOOST_FIRE or type == SMALL_FIRE:
		return FIRE
	if type == WAKE_SPRITE:
		return WAKE
	if type == WATER_RING or type == BUBBLE or (type >= PUDDLE_RING and type <= PUDDLE_RING + 3):
		return RING
	if type >= SWIRL and type < SWIRL + 8:
		return RESPAWN
	return -1


func world_frame() -> void:
	world_live = true
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var any := false
	for i in POOL:
		if script_life[i] == 0:
			continue
		var shown := script_life[i]
		var age := shown - 1
		var type := script_type[i]
		var kill := false
		if type == GREEN_SMOKE or type == ORANGE_SMOKE:
			script_h[i] += 0xc
			script_life[i] += 1
			kill = script_life[i] == 0x21
		elif type == WRECK_SMOKE:
			script_h[i] += 0xc
			script_life[i] += 1
			kill = script_life[i] > 0x21
		elif type == BURST or type == BURST_CORE:
			script_h[i] += 4
			script_life[i] += 1
			kill = script_life[i] >= 0x11
		elif type == RESPAWN_GRID:
			script_life[i] += 1
			kill = script_life[i] >= 0x20
		elif type >= SWIRL and type < SWIRL + 8:
			# Drawn, then life += 2, and it dies once that reaches 0x1f. The
			# frame that crosses the line still shows; the next one is cleared.
			if script_life[i] >= 0x1f:
				kill = true
			else:
				var orbit_byte: int = (script_byte[i] + (age >> 2) + 1) & 0xff
				script_byte[i] = orbit_byte
				var orbit_car: Car = (get_tree().current_scene as Session).battle.cars[type - SWIRL]
				var orbit_ang: int = orbit_byte << 4
				var orbit_sin: int = orbit_car.game_sine(orbit_ang)
				var orbit_cos: int = orbit_car.game_sine(orbit_ang + 0x400)
				var orbit_span: int = age * 8
				var orbit_dx: int = orbit_cos * orbit_span
				var orbit_dz: int = orbit_sin * orbit_span
				if orbit_dx < 0:
					orbit_dx += 0xfff
				if orbit_dz < 0:
					orbit_dz += 0xfff
				var orbit_at := orbit_car.global_position / Car.UNIT_METRES
				script_x[i] = int(orbit_at.x) + (orbit_dx >> 12)
				script_y[i] = int(orbit_at.z) + (orbit_dz >> 12)
				script_h[i] = int(orbit_at.y) + 0x20
				script_life[i] += 2
		elif type == SPARK_EMBER or type == SHOT_TRAIL:
			script_h[i] += 2
			script_life[i] += 1
			kill = script_life[i] > 0x21
		elif type == CLOUD_PUFF:
			script_h[i] += 2
			script_life[i] += 2
			kill = script_life[i] > 0x22
		elif type >= CLOUD_OVER and type < CLOUD_OVER + 5:
			# FUN_0002e1c8 sets these on the target every frame, raised by the age.
			var target := items.cars[script_byte[i]].global_position / Car.UNIT_METRES
			var part := type - CLOUD_OVER
			script_x[i] = int(target.x) + (0x30 if part == 1 else -0x30 if part == 2 else 0)
			script_y[i] = int(target.z) + (0x30 if part == 3 else -0x30 if part == 4 else 0)
			script_h[i] = int(target.y) + age
			script_life[i] += 2
			kill = script_life[i] > 0x22
		elif type >= BOMB_SMOKE and type < BOMB_SMOKE + 8:
			# FUN_0002e1c8 carries the puff with the car and lifts it by the life.
			# FUN_0002c5a0 clears it once the car is wrecked.
			var bomber := items.cars[script_byte[i]]
			script_life[i] += 1
			kill = script_life[i] > 0x1f or bomber.wreck_frames > 0
			script_h[i] = int(bomber.global_position.y / Car.UNIT_METRES) - 0x10 + shown * 4
		elif type == SHOT_PUFF:
			script_life[i] += 1
			kill = script_life[i] > 0x3e
		elif type == WRECK_SPARK:
			var rise_shade := age if age <= 0xf else 0x1f - age
			var rise: int = SPARK_RISE[rise_shade]
			if (i & 2) != 0:
				rise = rise >> 1
			if age > 0xf:
				rise = -rise
			script_h[i] += rise
			var drift := script_byte[i]
			script_x[i] += (drift >> 4) - 8
			script_y[i] += (drift & 0xf) - 8
			if age < 0x14 and (age & 1) != 0:
				spawn_script(script_x[i], script_y[i], script_h[i], SPARK_EMBER, 0x10)
			script_life[i] += 1
			kill = script_life[i] > 0x20
		elif type == JUMP_SMOKE:
			script_h[i] += 0x10
			script_life[i] += 2
			kill = script_life[i] > 0x20
		elif type == DRIFT_SMOKE:
			script_h[i] += 4
			script_life[i] += 1
			kill = script_life[i] > 0x20
		elif type == BOOST_FIRE:
			# FUN_0002c424 clears the life at 0x10 after the flame is drawn.
			script_h[i] += 4
			script_life[i] += 1
			kill = script_life[i] > 0x10
		elif type == SMALL_FIRE:
			script_h[i] += 8
			script_life[i] += 1
			kill = script_life[i] == 0x10
		elif type == SMOKE_NEG_Z or type == SMOKE_POS_Z or type == SMOKE_NEG_X or type == SMOKE_POS_X:
			script_h[i] += 2
			if type == SMOKE_NEG_Z:
				script_y[i] -= age
			elif type == SMOKE_POS_Z:
				script_y[i] += age
			elif type == SMOKE_NEG_X:
				script_x[i] -= age
			else:
				script_x[i] += age
			script_life[i] += 1
			kill = script_life[i] > 0x20
		elif type == WAKE_SPRITE:
			var ang: int = script_byte[i] * 0x10
			script_x[i] -= int(round(sin(float(ang & 0xfff) * Car.ANGLE_TO_RAD) * 4096.0)) >> 9
			script_y[i] += int(round(sin(float((ang + 0x400) & 0xfff) * Car.ANGLE_TO_RAD) * 4096.0)) >> 9
			script_life[i] += 1
			kill = script_life[i] == 0x10
		elif type == WATER_RING:
			script_life[i] += 2
			kill = script_life[i] > 0x1f
		elif type >= PUDDLE_RING and type <= PUDDLE_RING + 3:
			script_life[i] += 1
			kill = script_life[i] > 0x20
		elif type == PUDDLE_DROP:
			if age < 0x10:
				script_h[i] += (0x10 - age) * 3
			else:
				script_h[i] += 0x10 - age
			script_life[i] += 1
			kill = script_life[i] > 0x20
		elif type == BUBBLE:
			script_h[i] += 0xc
			script_life[i] += 1
			kill = script_life[i] == 0x20
		else:
			kill = true
		if kill:
			script_life[i] = 0
			for multi in script_meshes:
				hide_slot(multi, i)
			hide_slot(respawn_core, i)
			continue
		var kind := script_kind[i]
		var at := Vector3(script_x[i], script_h[i], script_y[i]) * Car.UNIT_METRES
		var size := SMOKE_UNITS
		var quad := Vector3.ONE
		var color := Color(1.0, 1.0, 1.0, envelope(age))
		var frame := age & 15
		var flat := false
		var mirror := false
		var spin := 0.0
		var wake_x := 0
		var wake_z := 0
		var flame := 99
		if type == BOOST_FIRE:
			# FUN_0002c3b8 / FUN_0002c474. Same sheet as the burst, RGB 0x30.
			quad = Vector3(BOOST_UNITS * FRAME_WIDE, BOOST_UNITS, 1.0)
			color = Color(0x30 / 128.0, 0x30 / 128.0, 0x30 / 128.0, 1.0)
		elif type == SMALL_FIRE:
			size = FIRE_UNITS
		elif type == GREEN_SMOKE:
			color = Color(0.45, 1.0, 0.25, envelope(age))
		elif type == ORANGE_SMOKE:
			color = Color(1.0, 0.7, 0.15, envelope(age))
		elif type == DRIFT_SMOKE:
			var dust := age if age <= 0xf else 0x1f - age
			var dust_level := (dust + 4) * 4
			var tall := float(age * 8)
			quad = Vector3(tall * FRAME_WIDE, tall, 1.0)
			color = Color(dust_level / 128.0, dust_level / 128.0, dust_level / 128.0, 0.25)
			frame = dust
		elif type == WAKE_SPRITE:
			# FUN_00021e48. The chevron's point lies along X and its width along Z,
			# each signed by sine and cosine of (byte*16 - 0x440). The point edge
			# sits 16 units under the open edge. Vertex colour is the life fade.
			var wake_age := shown
			if wake_age > 7:
				wake_age = 0xf - wake_age
			var wake_ang: int = (script_byte[i] * 0x10 - 0x440) & 0xfff
			var trig_s: int = int(round(sin(float(wake_ang) * Car.ANGLE_TO_RAD) * 4096.0))
			var trig_c: int = int(round(sin(float((wake_ang + 0x400) & 0xfff) * Car.ANGLE_TO_RAD) * 4096.0))
			if trig_s < 0:
				trig_s += 0x3f
			if trig_c < 0:
				trig_c += 0x3f
			var wake_span: int = (shown + 8) * 0x10
			var sin_term: int = (trig_s >> 6) * wake_span
			var cos_term: int = -((trig_c >> 6) * wake_span)
			if sin_term < 0:
				sin_term += 0x7f
			if cos_term < 0:
				cos_term += 0x7f
			wake_z = sin_term >> 7
			wake_x = cos_term >> 7
			at.y += 0.05 + 8.0 * Car.UNIT_METRES
			var wake_level: int = ((shown * -2 + 0x20) & 0xff) * 3
			var wake_red := wake_level >> 2
			color = Color(float(wake_red) / 128.0, float(wake_red + (wake_level >> 3)) / 128.0, float(wake_red + (wake_level >> 4)) / 128.0, 1.0)
			frame = wake_age
			flat = true
			spin = 1.0
		elif type == WATER_RING:
			# FUN_00021e48 lays a square of half-side life*2 on the ground, quarter-add
			# (tpage 0x6a) of the ring cell, fading with (0x20 - life).
			size = float(shown) * 4.0
			at.y += 0.05
			var splash_fade := 0x20 - shown
			var splash_g: int = (splash_fade * 0xff) >> 5
			color = Color(float(splash_fade * 7) / 128.0, float(splash_g) / 128.0, float(splash_fade * 7) / 128.0, 0.25)
			frame = 0
			flat = true
		elif type == PUDDLE_RING:
			# FUN_00021e48 tiles four quadrants of the tpage 0x6a ring into one
			# ground-plane quad, life*8+0x10 on a side for each quadrant.
			var ring := (shown * 8 + 0x10) * 2
			at.y += 0.05
			size = float(ring)
			var tone := float((0x20 - shown) * 6) / 128.0
			color = Color(tone, tone, tone, 0.25)
			frame = 0
			flat = true
		elif type == PUDDLE_DROP:
			var shade := age if age <= 0xf else 0x1f - age
			var byte := (shade + 4) * 4
			size = float(age + (age >> 1)) * 2.0
			color = Color(float(byte) / 128.0, float(byte) / 128.0, float(byte) / 128.0, 1.0)
			frame = shade
		elif type == WRECK_SMOKE:
			var puff_shade := age if age <= 0xf else 0x1f - age
			size = 192.0
			var puff_level := float(puff_shade << 2) / 128.0
			color = Color(puff_level, puff_level, puff_level, 1.0)
			frame = puff_shade
		elif type == BURST:
			quad = Vector3(192.0 * FRAME_WIDE, 192.0, 1.0)
			color = Color(0x7f / 128.0, 0x7f / 128.0, 0x7f / 128.0, 1.0)
			frame = age
		elif type == BURST_CORE:
			var core := age if age <= 7 else 0x10 - age
			var core_h := float((core + 14) * 8)
			quad = Vector3(core_h * FRAME_WIDE, core_h, 1.0)
			var core_rg := float(core << 3) / 128.0
			color = Color(core_rg, core_rg, float((core * 0xe) >> 1) / 128.0, 1.0)
			frame = 15
		elif type == RESPAWN_GRID:
			var pop := age if age <= 0xf else 0x1e - age
			var pop_h := float((pop * 4 + 16) * 4)
			quad = Vector3(pop_h * FRAME_WIDE, pop_h, 1.0)
			var tint_bits := script_byte[i]
			color = Color(float(tint_bits & 0xff) / 255.0, float((tint_bits >> 8) & 0xff) / 255.0, float((tint_bits >> 16) & 0xff) / 255.0, 1.0)
			frame = pop
			mirror = age > 0xf
		elif type >= SWIRL and type < SWIRL + 8:
			var swirl_car: Car = (get_tree().current_scene as Session).battle.cars[type - SWIRL]
			var swirl_rgb := swirl_car.color
			quad = Vector3(SWIRL_UNITS * FRAME_WIDE, SWIRL_UNITS, 1.0)
			color = Color(swirl_rgb.r, swirl_rgb.g, swirl_rgb.b, 0.25)
			frame = age if age <= 0xf else 0x1e - age
			mirror = age > 0xf
		elif type == WRECK_SPARK:
			var spark_shade := age if age <= 0xf else 0x1f - age
			var spark_h := 64.0
			if (i & 1) != 0:
				spark_h *= 0.5
			quad = Vector3(spark_h * FRAME_WIDE, spark_h, 1.0)
			var spark_level := float(spark_shade << 2) / 128.0
			color = Color(spark_level, spark_level, spark_level, 1.0)
			frame = spark_shade
		elif type == SPARK_EMBER or type == SHOT_TRAIL:
			# FUN_0002c258 with equal half sizes, square in the 512-wide framebuffer.
			var ember := age if age <= 0xf else 0x1f - age
			var ember_h := 128.0 if type == SHOT_TRAIL else 96.0
			quad = Vector3(ember_h * FRAME_WIDE / 1.5, ember_h, 1.0)
			color = Color(float(ember << 1) / 128.0, float(ember + (ember >> 1)) / 128.0, 0.0, 1.0)
			frame = ember
		elif type == CLOUD_PUFF or (type >= CLOUD_OVER and type < CLOUD_OVER + 5):
			# FUN_0002c5a0: subtracted smoke, 0x31 at scale 0x20 and the target's
			# puffs at 0x28. The puff right on the target is three times darker.
			var billow := maxi(age if age <= 0xf else 0x1f - age, 4)
			var billow_h := 256.0 if type == CLOUD_PUFF else 320.0
			quad = Vector3(billow_h * FRAME_WIDE, billow_h, 1.0)
			var billow_level := float(billow * (9 if type == CLOUD_OVER else 3)) / 128.0
			color = Color(billow_level, billow_level, billow_level, 1.0)
			frame = age if age <= 0xf else 0x1f - age
			if type != CLOUD_PUFF:
				script_offset[i] = at - items.cars[script_byte[i]].global_position
		elif type >= BOMB_SMOKE and type < BOMB_SMOKE + 8:
			# FUN_0002c5a0 sizes the fuse by the bomb timer: 50 before it runs, 20
			# for the first 0x28 frames, then half the timer.
			var bomber := items.cars[script_byte[i]]
			var bomb_t: int = bomber.item_timers[Items.BOMB]
			var fuse := 50 if bomb_t < 2 else 0x14 if bomb_t < 0x28 else bomb_t >> 1
			var fuse_h := float(fuse * 3)
			at = Vector3(int(bomber.global_position.x / Car.UNIT_METRES) + script_x[i], script_h[i], int(bomber.global_position.z / Car.UNIT_METRES) + script_y[i]) * Car.UNIT_METRES
			script_offset[i] = at - bomber.global_position
			quad = Vector3(fuse_h * FRAME_WIDE, fuse_h, 1.0)
			var fuse_shade := age if age <= 0xf else 0x1f - age
			color = Color(float(fuse_shade << 2) / 128.0, float(fuse_shade << 2) / 128.0, float(fuse_shade << 2) / 128.0, 1.0)
			frame = fuse_shade
			flame = age - 8
		elif type == SHOT_PUFF:
			# FUN_0002c5a0 steps the frame every other life, 96 units tall.
			var puff_step := age >> 1
			var puff_shade := puff_step if puff_step <= 0xf else 0x1f - puff_step
			at = items.pool_positions[script_byte[i]]
			quad = Vector3(96.0 * FRAME_WIDE, 96.0, 1.0)
			color = Color(float(puff_shade << 2) / 128.0, float(puff_shade << 2) / 128.0, float(puff_shade << 2) / 128.0, 1.0)
			frame = puff_shade
			flame = puff_step - 8
		elif type == BUBBLE:
			var span := age
			if span < 0x19:
				span = maxi(span, 0x10)
			else:
				span = span * -2 + 0x48
			var band := float(span) / 3.0
			quad = Vector3(band * FRAME_WIDE, band, 1.0)
			color = Color(1.0, 1.0, 1.0, 0.25)
			frame = 0
		if quad == Vector3.ONE:
			quad = Vector3(size, size, 1.0)
		var fresh := is_inf(script_from[i].x)
		script_from[i] = at if fresh else script_at[i]
		script_at[i] = at
		paint(script_meshes[kind], i, kind, at, quad * Car.UNIT_METRES, color, frame, flat, mirror, spin)
		if type == WAKE_SPRITE:
			var units := Car.UNIT_METRES
			var basis := Basis(
				Vector3(0.0, 0.0, 2.0 * float(wake_z) * units),
				Vector3(2.0 * float(wake_x) * units, -16.0 * units, 0.0),
				Vector3(0.0, 1.0, 0.0))
			bases[script_meshes[kind]][i] = basis
			script_meshes[kind].set_instance_transform(i, Transform3D(basis, at))
			if fresh:
				script_meshes[kind].reset_instance_physics_interpolation(i)
		if type == WRECK_SPARK and age <= 22:
			var flick := age - 8
			paint(script_meshes[FIRE], i, FIRE, at, quad * Car.UNIT_METRES, Color(0x60 / 128.0, 0x60 / 128.0, 0x60 / 128.0, 1.0), ((flick & 0xc) >> 2) * 4 + (flick & 3))
		elif type == WRECK_SPARK:
			hide_slot(script_meshes[FIRE], i)
		elif flame <= 14:
			# The fire page frame under the smoke, RGB 0x60, the same size.
			paint(script_meshes[FIRE], i, FIRE, at, quad * Car.UNIT_METRES, Color(0x60 / 128.0, 0x60 / 128.0, 0x60 / 128.0, 1.0), flame & 15)
		elif type == SHOT_PUFF or (type >= BOMB_SMOKE and type < BOMB_SMOKE + 8):
			hide_slot(script_meshes[FIRE], i)
		elif type == RESPAWN_GRID:
			var glow := age if age <= 0xf else 0x1e - age
			var glow_h := float((glow + 8) * 8)
			var glow_level := float(glow << 3) / 255.0
			paint(respawn_core, i, FIRE, at, Vector3(glow_h * FRAME_WIDE, glow_h, 1.0) * Car.UNIT_METRES, Color(glow_level, glow_level, glow_level, 1.0), 15)
		# The ring is only pixels at its edge, so the box has to cover the quad
		# and not just the center or the splash is clipped away as it grows.
		var reach := Vector3(absf(quad.x), absf(quad.y), absf(quad.x)) * Car.UNIT_METRES * 0.5
		if type == WAKE_SPRITE:
			reach = Vector3(absf(float(wake_x)), 16.0, absf(float(wake_z))) * Car.UNIT_METRES
		lo = lo.min(at - reach)
		hi = hi.max(at + reach)
		any = true
	fit_bounds(script_instances, any, lo, hi)
	fit_bounds([respawn_core_instance], any, lo, hi)


func weather_frame(track: Track, cam: TrackCamera) -> void:
	world_live = true
	game_tick += 1
	var origin := cam.global_position
	var dist := int(cam.distance)
	if track.weather == 3:
		hide_all(flake_mesh, FLAKES)
		step_ripples(track, cam)
	else:
		hide_all(ripple_mesh, RIPPLES)
		step_flakes(origin, dist, SNOW_FALL if track.weather == 1 else RAIN_FALL, cam)
		if track.weather == 2 and (game_tick & 3) == 0 and (randi() & 1) == 0:
			rain_splash(track, cam)


func step_flakes(origin: Vector3, dist: int, fall: int, cam: TrackCamera) -> void:
	var forward := -cam.global_basis.z
	var right := cam.global_basis.x
	var up := cam.global_basis.y
	var view_size := get_viewport().get_visible_rect().size
	var half_h := 0.5 * view_size.x / view_size.y * 1.5
	var wide := SNOW_W if fall == SNOW_FALL else RAIN_W
	var tall := FLAKE_H + float(fall)
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var any := false
	var spread := dist >> 5
	var cam_x := int(origin.x / Car.UNIT_METRES)
	var cam_z := int(origin.z / Car.UNIT_METRES)
	var cam_h := int(origin.y / Car.UNIT_METRES)
	var floor_y := origin.y - 0x100 * Car.UNIT_METRES
	for i in FLAKES:
		var at := flake_pos[i]
		var rel := at - origin
		var depth_m := rel.dot(forward)
		var depth_u := int(depth_m / Car.UNIT_METRES)
		var z := depth_u >> 2 if depth_u > 0 else 0
		var on_x := depth_m > 0.0 and absf(rel.dot(right)) < depth_m * half_h
		var spawned := at == Vector3.ZERO or at.y < floor_y or z < 0x28 or z >= 0x200 or not on_x
		if spawned:
			var x := cam_x + ((randi() & 0xff) - 0x7f) * spread
			var zz := cam_z + ((randi() & 0xff) - 0x7f) * spread
			var h := cam_h + (dist >> 1) + (randi() & 0x3f)
			at = Vector3(x, h, zz) * Car.UNIT_METRES
			rel = at - origin
			depth_m = rel.dot(forward)
			depth_u = int(depth_m / Car.UNIT_METRES)
			z = depth_u >> 2 if depth_u > 0 else 0
			on_x = depth_m > 0.0 and absf(rel.dot(right)) < depth_m * half_h
		# FUN_00069178 subtracts the fall only while the flake is inside the draw window.
		if z >= 0x29 and z < 0x300:
			at.y -= float(fall) * Car.UNIT_METRES
		flake_pos[i] = at
		if z >= 0x29 and z < 0x300 and on_x:
			var height_m := tall * Car.UNIT_METRES
			var center := at + up * (height_m * 0.5)
			paint(flake_mesh, i, STREAK, center, Vector3(wide, tall, 1.0) * Car.UNIT_METRES, FLAKE_TINT, 0)
			lo = lo.min(center)
			hi = hi.max(center)
			any = true
		else:
			hide_slot(flake_mesh, i)
	fit_bounds([flake_instance], any, lo, hi)


func step_ripples(track: Track, cam: TrackCamera) -> void:
	var origin := cam.global_position
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	var any := false
	var count := track.nodes.size()
	for i in RIPPLES:
		if ripple_life[i] == 0 and ((randi() + i) & 3) == 0 and track.water_level > -INF:
			var n := posmod(cam.node - 2 + ((randi() + i) & 0xf), count)
			var units: Array = track.nodes[n].units
			if int(units[2]) <= track.water_units:
				var edge := (randi() + i) & 7
				var x := int(units[0])
				var z := int(units[1])
				if edge == 1:
					x = int(units[3])
					z = int(units[4])
				elif edge == 2:
					x = int(units[5])
					z = int(units[6])
				elif edge == 3:
					x = (int(units[5]) + int(units[9])) >> 1
					z = (int(units[6]) + int(units[10])) >> 1
				elif edge == 4:
					x = (int(units[7]) + int(units[3])) >> 1
					z = (int(units[8]) + int(units[4])) >> 1
				elif edge == 6:
					x = int(units[7])
					z = int(units[8])
				elif edge == 7:
					x = int(units[9])
					z = int(units[10])
				if edge < 6:
					x += (randi() & 0x80) - 0x40
					z += (randi() & 0x78) - 0x40
				ripple_pos[i] = Vector3(x, int(units[2]), z) * Car.UNIT_METRES
				ripple_life[i] = (randi() & 7) + 0x10
		var shown := ripple_life[i]
		var drew := false
		if shown > 0 and shown < 0x11:
			var at: Vector3 = ripple_pos[i]
			var pulse := shown if shown <= 8 else 16 - shown
			var dist_m := origin.distance_to(at)
			var depth := maxi(int(dist_m / Car.UNIT_METRES), 1)
			var span := int(float(0xa00) / float(depth))
			if span < 10:
				span = 10
			span *= pulse + 2
			var width_px := (span >> 2) * 2
			var height_px := span >> 5
			if width_px > 0 and height_px > 0 and dist_m > 0.0:
				var width_m := float(width_px) / 240.0 * dist_m
				var height_m := float(height_px) / 240.0 * dist_m
				var to_cam := origin - at
				var center := at + to_cam / dist_m * 0.2
				paint(ripple_mesh, i, ARC, center, Vector3(width_m, height_m, 1.0), RIPPLE_TINT, 0)
				lo = lo.min(center)
				hi = hi.max(center)
				any = true
				drew = true
		if not drew:
			hide_slot(ripple_mesh, i)
		if ripple_life[i] > 0:
			ripple_life[i] -= 1
	fit_bounds([ripple_instance], any, lo, hi)


func rain_splash(track: Track, cam: TrackCamera) -> void:
	if track.water_level <= -INF:
		return
	var count := track.nodes.size()
	var n := posmod(cam.node - 2 + (randi() & 7), count)
	var units: Array = track.nodes[n].units
	if int(units[2]) > track.water_units:
		return
	var edge := randi() & 3
	if edge == 3:
		return
	var x := int(units[0])
	var z := int(units[1])
	if edge == 1:
		x = int(units[3])
		z = int(units[4])
	elif edge == 2:
		x = int(units[5])
		z = int(units[6])
	spawn_script(x, z, int(units[2]), WATER_RING, 1)


func jitter() -> int:
	return -0x1f + (randi() & 0x3f)


func envelope(age: int) -> float:
	var band := age
	if band > 15:
		band = 31 - band
	return clampf(float(band) / 15.0, 0.0, 1.0)


func paint(multi: MultiMesh, slot: int, kind: int, at: Vector3, scale: Vector3, color: Color, frame: int, flat := false, mirror := false, spin := 0.0) -> void:
	var cells: Vector2 = SHEETS[kind].cells
	var frames: int = SHEETS[kind].frames
	frame = mini(frame, frames - 1)
	var col := frame % int(cells.x)
	var row := int(float(frame) / cells.x)
	var shown: Array[Basis] = bases[multi]
	var appear := shown[slot].x == Vector3.ZERO
	shown[slot] = Basis.IDENTITY.scaled(scale)
	multi.set_instance_transform(slot, Transform3D(shown[slot], at))
	if appear:
		multi.reset_instance_physics_interpolation(slot)
	multi.set_instance_color(slot, color)
	var lay := 1.0 + spin if flat else 0.0
	multi.set_instance_custom_data(slot, Color((float(col) + 0.5) / cells.x, (float(row) + 0.5) / cells.y, lay, 1.0 if mirror else 0.0))


func hide_slot(multi: MultiMesh, slot: int) -> void:
	bases[multi][slot] = Basis.IDENTITY.scaled(Vector3.ZERO)
	multi.set_instance_transform(slot, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	multi.reset_instance_physics_interpolation(slot)


func hide_all(multi: MultiMesh, count: int) -> void:
	for i in count:
		hide_slot(multi, i)


func fit_bounds(nodes: Array, any: bool, lo: Vector3, hi: Vector3) -> void:
	var box := AABB(Vector3.ZERO, Vector3.ZERO)
	if any:
		var pad := Vector3(2.0, 2.0, 2.0)
		box = AABB(lo - pad, hi - lo + pad * 2.0)
	for node: MultiMeshInstance3D in nodes:
		node.custom_aabb = box


func clear_world() -> void:
	world_live = false
	game_tick = 0
	for i in POOL:
		script_life[i] = 0
		for multi in script_meshes:
			hide_slot(multi, i)
	for i in FLAKES:
		flake_pos[i] = Vector3.ZERO
		hide_slot(flake_mesh, i)
	for i in RIPPLES:
		ripple_life[i] = 0
		hide_slot(ripple_mesh, i)
	for i in POOL:
		hide_slot(respawn_core, i)
	fit_bounds(script_instances, false, Vector3.ZERO, Vector3.ZERO)
	fit_bounds([respawn_core_instance], false, Vector3.ZERO, Vector3.ZERO)
	fit_bounds([flake_instance], false, Vector3.ZERO, Vector3.ZERO)
	fit_bounds([ripple_instance], false, Vector3.ZERO, Vector3.ZERO)
