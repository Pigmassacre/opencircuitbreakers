class_name Items
extends Node3D

# Port of the item system. One pickup lies on the track at a time: tournament
# tracks place it from the CBBYSS.CON table, others at random (FUN_00055084);
# cars on screen collect it (FUN_0003a330). Cars cycle and fire their stock
# (FUN_00029c1c), the fired item runs its effect every frame (FUN_00056cf0) and
# dropped or launched items live in a 16-slot pool (FUN_00020a80).
# Positions compared here are original units: (x, y, height) = port (x, z, y).

const SHRINK := 0
const GROW := 1
const ROCKET := 2
const REPULSOR := 3
const OIL := 4
const CLOUD := 5
const UNUSED := 6
const BOMB := 7
const GLUE := 8
const SHOT := 9
const STILTS := 10
const BOUNCE := 11
const TYPES := 12

const UNIT := Car.UNIT_METRES
const POOL := 16
const POOL_OIL := 0
const POOL_GLUE := 1
const POOL_CLOUD := 2
const POOL_SHOT := 3
const NO_TARGET := -1

# Random pickup types, indexed by (rand + frame) & 31. Cars use 0x8d6d8,
# boats 0x8d6f8 and submarines 0x8d718.
const RANDOM_TYPES := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 0, 1, 2, 10, 0, 1, 2, 3, 4, 5, 6, 2, 8, 9, 10, 11, 2, 11, 2, 3]
const BOAT_TYPES := [0, 1, 2, 3, 9, 5, 6, 7, 8, 9, 6, 9, 0, 1, 2, 0, 0, 1, 2, 3, 9, 5, 6, 2, 8, 9, 8, 3, 2, 1, 2, 3]
const SUB_TYPES := [0, 1, 2, 3, 2, 0, 6, 7, 1, 9, 2, 0, 0, 1, 2, 3, 0, 1, 2, 3, 6, 2, 6, 2, 1, 9, 2, 1, 2, 0, 2, 3]
const SHRINK_IN := [3, 64, 62, 57, 50, 40, 32, 27, 26, 25, 26, 27, 32]
const SHRINK_OUT := [32, 34, 39, 46, 56, 64, 73, 77, 78, 77, 73, 64, 64]
const GROW_IN := [64, 64, 67, 78, 93, 107, 113, 120, 128, 124, 113, 106, 100]
const GROW_OUT := [100, 95, 90, 86, 75, 64, 57, 54, 52, 54, 57, 64]
# (ease table 0x14e60 - 0x800) >> 5 over the 16-frame bounce cycle.
const BOUNCE_LIFT := [0, 0, 0, 0, 0, 12, 24, 45, 53, 59, 63, 62, 59, 45, 35, 24]
# Pickup tint (0x8d0dc) and HUD icon tint (FUN_00060b48), 128 = full.
const PICKUP_COLORS := [[192, 32, 255], [255, 255, 32], [192, 32, 255], [128, 128, 128], [32, 96, 255], [32, 96, 255], [128, 128, 128], [255, 32, 32], [32, 96, 255], [255, 32, 32], [192, 32, 255], [255, 255, 32]]
const HUD_COLORS := [[192, 32, 255], [255, 255, 32], [192, 32, 255], [128, 128, 128], [32, 96, 255], [32, 96, 255], [255, 32, 32], [255, 32, 32], [32, 96, 255], [255, 32, 32], [192, 32, 255], [255, 255, 32]]
const ICONS := "res://textures/items.png"
const ICON_SIZE := Vector2(32.0, 20.0)
const PICKUP_HALF := 40
const MODEL_TO_WORLD := TrackScript.MODEL_TO_WORLD
const ICON_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D icon : source_color, filter_nearest;
uniform vec3 tint;
void fragment() {
	vec4 texel = texture(icon, UV);
	if (texel.a < 0.5) {
		discard;
	}
	ALBEDO = min(texel.rgb * tint, vec3(1.0));
}
"""

var track: Track
var race: Race
var cars: Array[Car] = []
var camera: TrackCamera
var rng := RandomNumberGenerator.new()
var setting := 1
var battle := false

var pickup := false
var pickup_units := Vector3i.ZERO
var pickup_type := 0
var pickup_node := 0
var pickup_orientation := 0
var cooldown := 0

var pool_timers := PackedInt32Array()
var pool_owners := PackedInt32Array()
var pool_kinds := PackedInt32Array()
var pool_targets := PackedInt32Array()
var pool_positions := PackedVector3Array()
var pool_velocities := PackedVector3Array()
var pool_tilts := PackedVector2Array()
var pool_from := PackedVector3Array()

var icons: Texture2D
var pickup_mesh := MeshInstance3D.new()
var pickup_shown := Vector2i(-1, -1)
var pickup_placed := Vector3i.ZERO
var pool_meshes: Array[MeshInstance3D] = []
var pool_shapes := PackedVector3Array()
var slick_oil: ShaderMaterial
var slick_glue: ShaderMaterial
var puppet_frame := -1


# Places the item visuals every physics tick once the cars have moved.
class Late extends Node:
	var items: Items

	func _physics_process(_delta: float) -> void:
		items.place_visuals()


func setup(race_track: Track, race_state: Race, racers: Array[Car], track_camera: TrackCamera) -> void:
	track = race_track
	race = race_state
	cars = racers
	camera = track_camera
	process_physics_priority = -2
	Fx.items = self
	var late := Late.new()
	late.items = self
	late.process_physics_priority = 2
	add_child(late)
	for car in cars:
		car.items = self
	pool_timers.resize(POOL)
	pool_owners.resize(POOL)
	pool_kinds.resize(POOL)
	pool_targets.resize(POOL)
	pool_positions.resize(POOL)
	pool_velocities.resize(POOL)
	pool_tilts.resize(POOL)
	pool_from.resize(POOL)
	pool_shapes.resize(POOL)

	icons = Data.texture(ICONS)
	var shader := Shader.new()
	shader.code = ICON_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("icon", icons)
	pickup_mesh.material_override = material
	pickup_mesh.visible = false
	add_child(pickup_mesh)
	var fire_image := Image.new()
	fire_image.load_png_from_buffer(Data.bytes("res://textures/particles_fire.png"))
	var fire := ImageTexture.create_from_image(fire_image)
	var slick_code := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, shadows_disabled;
uniform sampler2D sheet : filter_nearest, repeat_disable;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() {
	vec4 texel = texture(sheet, UV);
	ALBEDO = texel.rgb * tint.rgb;
	ALPHA = texel.a * tint.a;
}
"""
	slick_oil = slick_material(slick_code.replace("blend_add", "blend_sub"), fire)
	slick_glue = slick_material(slick_code, fire)
	for i in POOL:
		var mesh := MeshInstance3D.new()
		mesh.material_override = slick_oil
		mesh.visible = false
		add_child(mesh)
		pool_meshes.append(mesh)


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME != 0:
		return
	if Net.puppet():
		puppet_particles()
		return
	update_pool()
	# FUN_00055084 returns immediately while the time-trial flag is set.
	if not race.time_trial:
		if battle or track.pickups.is_empty():
			spawn_random()
		else:
			spawn_table()
		if pickup_type == UNUSED:
			pickup_type = REPULSOR
	update_ghosts()


func rand() -> int:
	return rng.randi() & 0x7fff


func units(car: Car) -> Vector3i:
	var p := car.global_position / UNIT
	return Vector3i(int(p.x), int(p.z), int(p.y))


func to_port(u: Vector3i) -> Vector3:
	return Vector3(u.x, u.z, u.y) * UNIT


# Fixed-point distance tests: |delta| below the given unit extents.
func near(car: Car, at: Vector3, across: float, height: float) -> bool:
	var d := (car.global_position - at) / UNIT
	return absf(d.x) < across and absf(d.z) < across and absf(d.y) < height


func behind(car: Car, distance: float) -> Vector3:
	return car.global_position - car.heading_forward() * distance * UNIT


# FUN_00056cf0 runs the item before FUN_00029c1c, so a fired item first acts on
# the next frame. Cycle and fire are edge triggered; firing needs stock, a car
# that isn't wrecked and no item already running.
func car_frame(car: Car) -> void:
	car.forced_accel = false
	if car.item_active:
		run_item(car)
	if car.cycle_input and not car.cycle_held:
		car.selected_item += 1
		reselect(car)
	if car.fire_input and not car.fire_held and not car.item_active and car.item_total != 0 and car.wreck_frames == 0:
		car.fired_item = car.selected_item
		car.item_active = true
		car.item_counts[car.fired_item] -= 1
		reselect(car)
	car.cycle_held = car.cycle_input
	car.fire_held = car.fire_input
	car.on_screen = camera.is_position_in_frustum(car.global_position)
	collect(car)


# FUN_00060e48: the first slot with stock from the selection on, or slot 0.
func reselect(car: Car) -> void:
	var slot := car.selected_item % TYPES
	car.selected_item = 0
	for n in TYPES:
		if car.item_counts[(slot + n) % TYPES] > 0:
			car.selected_item = (slot + n) % TYPES
			break
	car.item_total = 0
	for count in car.item_counts:
		car.item_total += count


func collect(car: Car) -> void:
	if not pickup or not car.on_screen or car.wreck_frames > 0:
		return
	var d := units(car) - pickup_units
	if absi(d.x) > 0x47 or absi(d.y) > 0x47 or absi(d.z) > 0x47:
		return
	pickup = false
	cooldown = 0x32
	car.item_total += 1
	car.selected_item = pickup_type
	car.item_counts[pickup_type] += 5 if pickup_type == SHOT else 1


func run_item(car: Car) -> void:
	match car.fired_item:
		SHRINK:
			shrink(car)
		GROW:
			grow(car)
		ROCKET:
			rocket(car)
		REPULSOR:
			repulsor(car)
		OIL:
			drop_ring(car, POOL_OIL)
		CLOUD:
			cloud(car)
		BOMB:
			bomb(car)
		GLUE:
			drop_ring(car, POOL_GLUE)
		SHOT:
			shot(car)
		STILTS:
			stilts(car)
		BOUNCE:
			bounce(car)
	item_sounds(car)


# FUN_00072864 plays a tone when an item's timer lands on one of these frames.
func item_sounds(car: Car) -> void:
	var kind := car.fired_item
	var t: int = car.item_timers[OIL] if kind == OIL or kind == GLUE else car.item_timers[kind]
	match kind:
		SHRINK:
			if t == 2 or t == 0x60:
				Sound.effect(1, 3)
		GROW:
			if t == 2 or t == 0x60:
				Sound.effect(1, 1)
		ROCKET:
			if t == 2:
				Sound.effect(1, 2)
		REPULSOR:
			if t == 2 or t == 0x11 or t == 0x22 or t == 0x33 or t == 0x44:
				Sound.effect(1, 0)
		OIL, GLUE:
			if t == 4:
				Sound.effect(1, 5)
		CLOUD:
			if t == 4:
				Sound.effect(1, 6)
		UNUSED:
			if t == 2 or t == 0x12 or t == 0x22 or t == 0x32 or t == 0x42 or t == 0x52:
				Sound.effect(1, 0)
		BOMB:
			if (t & 15) == 15:
				Sound.effect(1, 4)
		SHOT:
			if t == 2:
				Sound.effect(1, 4)
		STILTS:
			if t == 2 or t == 0x60:
				Sound.effect(2, 1)
		BOUNCE:
			if t == 1 or (t & 15) == 15:
				Sound.effect(2, 0)


func shrink(car: Car) -> void:
	var t := maxi(car.item_timers[SHRINK], 1)
	if t < 13:
		car.item_scale = SHRINK_IN[t]
	if t > 0x57:
		car.item_scale = SHRINK_OUT[t - 0x58]
	if t == 6:
		car.engine = car.engine * 4 / 3
		car.grip = car.grip * 4 / 3
	if t == 100:
		end_shrink(car)
	else:
		car.item_timers[SHRINK] = t + 1


func end_shrink(car: Car) -> void:
	car.item_scale = 64
	car.engine = car.base_engine
	car.grip = car.base_grip
	car.item_active = false
	car.item_timers[SHRINK] = 0


func grow(car: Car) -> void:
	var t := maxi(car.item_timers[GROW], 1)
	if t < 13:
		car.item_scale = GROW_IN[t]
	if t > 0x58:
		car.item_scale = GROW_OUT[t - 0x59]
	if t == 100:
		end_grow(car)
	else:
		car.item_timers[GROW] = t + 1
	if car.item_timers[GROW] < 0x50:
		for other in cars:
			if other != car and near(other, car.global_position, 64, 32) and other.slow_frames == 0 and other.item_timers[GROW] == 0:
				other.slow_frames = 0x60
				other.engine /= 2


func end_grow(car: Car) -> void:
	car.item_scale = 64
	car.item_active = false
	car.item_timers[GROW] = 0


func rocket(car: Car) -> void:
	var t := car.item_timers[ROCKET]
	if t == 0:
		t = 1
		car.locked_heading = car.heading
	if t < 9:
		car.stretch = t + 8
	elif t > 0x11:
		if t < 0x1b:
			car.stretch = 0x22 - t
		else:
			car.stretch = [9, 11, 9, 8][t - 0x1b]
	# FUN_00059108 replaces the input word with plain accelerate, so cycling is
	# ignored too. The single-player AI writes its own input after this.
	if t < 0x19:
		car.heading = car.locked_heading
		car.grip = 0
		car.forced_accel = true
		car.engine = car.base_engine * 2
		if not car.autopilot_enabled:
			car.cycle_input = false
			car.fire_input = false
	if t == 0x1e:
		end_rocket(car)
	else:
		car.item_timers[ROCKET] = t + 1
	# FUN_000574a4 drops a type 0x18 flame on every even timer value. FUN_00032360
	# keys program 0 tone 6 once; FUN_00032434 holds that voice at volume 0xa0.
	if car.item_timers[ROCKET] == 2 and car.player_controlled:
		Sound.effect(0, 6, 0xa0)
	if (car.item_timers[ROCKET] & 1) == 0:
		Fx.boost_fire(car)
	var flame := behind(car, 0xb0)
	for other in cars:
		if other != car and near(other, flame, 72, 48) and other.burn_frames == 0:
			other.burn_frames = 0x40


func end_rocket(car: Car) -> void:
	car.stretch = 8
	car.engine = car.base_engine
	car.grip = car.base_grip
	car.item_timers[ROCKET] = 0
	car.item_active = false


# Pushes every car in range away; the height test multiplies dx / 4 by dh in
# 32 bits like the original.
func repulsor(car: Car) -> void:
	var t := maxi(car.item_timers[REPULSOR], 1)
	car.item_timers[REPULSOR] = t
	for other in cars:
		if other == car or not near(other, car.global_position, 192, 96):
			continue
		var d := (other.global_position - car.global_position) / UNIT * Car.ONE
		var dx := int(d.x) / 4
		var dy := int(d.z) / 4
		var product := (dx * int(d.y)) & 0xffffffff
		if product >= 0x80000000:
			product -= 0x100000000
		if product >= 0x2400000:
			continue
		while absi(dx) > 0x3fff or absi(dy) > 0x3fff:
			dx /= 2
			dy /= 2
		var push := Vector2(dx, dy).normalized() * Car.ONE * 2.0
		other.vel.x += floorf(push.x)
		other.vel.z += floorf(push.y)
	if t == 0x50:
		end_repulsor(car)
	else:
		var wave := (t + 5) & 15
		car.item_timers[REPULSOR] = t + 1
		if wave > 7:
			wave = 15 - wave
		car.item_scale = wave + 0x3c


func end_repulsor(car: Car) -> void:
	car.item_timers[REPULSOR] = 0
	car.item_active = false
	car.item_scale = 64


func free_slot() -> int:
	for i in POOL:
		if pool_timers[i] == 0:
			return i
	return -1


# Oil and glue share the oil timer; the drop waits until the car is grounded.
func drop_ring(car: Car, kind: int) -> void:
	var t := car.item_timers[OIL]
	if t == 0:
		if not car.grounded:
			return
		var slot := free_slot()
		if slot == -1:
			return
		t = 1
		pool_timers[slot] = 100
		pool_owners[slot] = cars.find(car)
		pool_kinds[slot] = kind
	var spread := 8
	if t < 7:
		spread = t + 8
	if t >= 6 and t <= 12:
		spread = 0x14 - t
	car.rear_spread = spread
	t += 1
	car.item_timers[OIL] = t
	if t == 0xf:
		car.item_timers[OIL] = 0
		car.item_active = false


func cloud(car: Car) -> void:
	var t := car.item_timers[CLOUD]
	if t == 0:
		var slot := free_slot()
		if slot == -1:
			return
		pool_timers[slot] = 0x78
		pool_owners[slot] = cars.find(car)
		pool_kinds[slot] = POOL_CLOUD
		pool_targets[slot] = NO_TARGET
		t = 1
	car.item_timers[CLOUD] = t + 1
	if t + 1 == 0x14:
		car.item_timers[CLOUD] = 0
		car.item_active = false


func bomb(car: Car) -> void:
	var t := maxi(car.item_timers[BOMB], 1)
	car.engine = car.base_engine * 2
	car.item_timers[BOMB] = t + 1
	if (t & 3) == 0:
		Fx.bomb_smoke(cars.find(car))
	if t + 1 == 100:
		end_bomb(car)
		car.wreck()


func end_bomb(car: Car) -> void:
	car.item_timers[BOMB] = 0
	car.engine = car.base_engine
	car.grip = car.base_grip
	car.item_active = false


# The shot leaves with the car's velocity plus 48 units a frame along its
# facing, each truncated to whole units.
func shot(car: Car) -> void:
	var t := car.item_timers[SHOT]
	if t == 0:
		var slot := free_slot()
		if slot == -1:
			return
		pool_timers[slot] = 0x40
		pool_owners[slot] = cars.find(car)
		pool_kinds[slot] = POOL_SHOT
		pool_positions[slot] = to_port(units(car))
		pool_from[slot] = pool_positions[slot]
		var facing := -car.global_basis.z
		pool_velocities[slot] = (Vector3(Vector3i(car.vel / Car.ONE)) + Vector3(Vector3i(facing * 48.0))) * UNIT
		t = 1
	car.item_timers[SHOT] = t + 1
	if t + 1 == 8:
		car.item_timers[SHOT] = 0
		car.item_active = false


func stilts(car: Car) -> void:
	var t := maxi(car.item_timers[STILTS], 1)
	car.engine = car.base_engine * 2
	if t < 9:
		car.body_lift = t * 8
	if t > 0x47:
		car.body_lift = (0x50 - t) * 8
	if t == 0x50:
		end_stilts(car)
	else:
		car.item_timers[STILTS] = t + 1


func end_stilts(car: Car) -> void:
	car.body_lift = 0
	car.item_timers[STILTS] = 0
	car.engine = car.base_engine
	car.item_active = false


func bounce(car: Car) -> void:
	var t := car.item_timers[BOUNCE]
	if t == 0:
		t = 4
	car.engine = car.base_engine * 3 / 2
	car.body_lift = BOUNCE_LIFT[t & 15]
	if t & 15 > 12:
		for other in cars:
			if other != car and near(other, car.global_position, 64, 32) and other.slow_frames == 0:
				other.slow_frames = 0x60
				other.engine /= 2
	if t == 100:
		end_bounce(car)
	else:
		car.item_timers[BOUNCE] = t + 1


func end_bounce(car: Car) -> void:
	car.body_lift = 0
	car.item_timers[BOUNCE] = 0
	car.engine = car.base_engine
	car.item_active = false


# FUN_000388c4: a respawn ends the running body effects and every status timer.
func respawn(car: Car) -> void:
	if car.item_timers[SHRINK] != 0:
		end_shrink(car)
	if car.item_timers[GROW] != 0:
		end_grow(car)
	if car.item_timers[STILTS] != 0:
		end_stilts(car)
	if car.item_timers[ROCKET] != 0:
		end_rocket(car)
	if car.item_timers[REPULSOR] != 0:
		end_repulsor(car)
	if car.item_timers[BOMB] != 0:
		end_bomb(car)
	if car.item_timers[BOUNCE] != 0:
		end_bounce(car)
	car.grip = car.base_grip
	car.engine = car.base_engine
	car.spin_frames = 0
	car.slow_frames = 0
	car.burn_frames = 0


func update_pool() -> void:
	for slot in POOL:
		var timer := pool_timers[slot]
		if timer == 0:
			continue
		pool_particles(slot, timer)
		var owner := cars[pool_owners[slot]]
		match pool_kinds[slot]:
			POOL_OIL, POOL_GLUE:
				if timer > 0x50:
					if not owner.grounded and owner.air_frames > 0x2f:
						pool_timers[slot] = 0
						continue
					pool_positions[slot] = behind(owner, 0x40)
					pool_tilts[slot] = owner.tilts_of(owner.floor_normal) if owner.grounded else owner.air_tilt
				if timer >= 11 and timer <= 79:
					for other in cars:
						if other != owner and near(other, pool_positions[slot], 96, 96) and other.item_timers[BOUNCE] == 0:
							if pool_kinds[slot] == POOL_OIL:
								if other.spin_frames == 0:
									other.spin_frames = 0x40
									other.grip = 0
							else:
								other.vel = Vector3(Vector3i(other.vel * 5.0 / 8.0))
				pool_timers[slot] -= 1
			POOL_CLOUD:
				pool_timers[slot] -= 1
				if timer >= 100:
					if timer == 100:
						pool_positions[slot] = to_port(units(owner))
						pool_targets[slot] = NO_TARGET
				elif pool_targets[slot] == NO_TARGET:
					for j in cars.size():
						if cars[j] != owner and near(cars[j], pool_positions[slot], 80, 128):
							pool_targets[slot] = j
				elif cars[pool_targets[slot]].wreck_frames > 0:
					pool_timers[slot] = 0
			POOL_SHOT:
				pool_from[slot] = pool_positions[slot]
				pool_timers[slot] -= 1
				for other in cars:
					if other != owner and near(other, pool_positions[slot], 48, 64):
						other.burn_frames = 0x38 if other.burn_frames != 0 else 0x40
						if other.spin_frames == 0:
							other.spin_frames = (rand() & 1) * 2 + 0xf
						pool_timers[slot] = 0
				if move_shot(slot):
					pool_timers[slot] = 0
				if pool_timers[slot] < 0x20:
					pool_timers[slot] = 0


# FUN_00021450: the shot moves, then snaps to a floor within 0x40 units of its
# new height and keeps the snap as its climb. With no floor that close it
# flies on at the same climb. It dies against a wall.
func move_shot(slot: int) -> bool:
	var from := pool_positions[slot]
	var to := from + pool_velocities[slot]
	var space := get_world_3d().direct_space_state
	var wall := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 16.0 * UNIT, to + Vector3.UP * 16.0 * UNIT, 1)
	if not space.intersect_ray(wall).is_empty():
		return true
	var floor_ray := PhysicsRayQueryParameters3D.create(to + Vector3.UP * 0x40 * UNIT, to - Vector3.UP * 0x40 * UNIT, Car.GROUND_LAYER)
	var hit := space.intersect_ray(floor_ray)
	if hit.is_empty():
		pool_positions[slot] = to
		return false
	var velocity := pool_velocities[slot]
	velocity.y = hit.position.y - to.y
	pool_velocities[slot] = velocity
	pool_positions[slot] = Vector3(to.x, hit.position.y, to.z)
	return false


# FUN_00020a80 spawns the cloud and shot particles from the timer before it
# counts down. The original draws neither item any other way.
func pool_particles(slot: int, t: int) -> void:
	var at := pool_positions[slot] / UNIT
	match pool_kinds[slot]:
		POOL_CLOUD:
			if t >= 100:
				if (t & 3) != 0:
					var o := units(cars[pool_owners[slot]])
					Fx.cloud_puff(o.x + (randi() & 0xf) - 7, o.y + (randi() & 0xf) - 7, o.z + 0x8c - t)
			elif pool_targets[slot] == NO_TARGET:
				if (t & 3) == 1:
					var bits := randi()
					Fx.cloud_puff(int(at.x) + ((bits >> 7) & 0x3f) - 0x20, int(at.z) + (bits & 0x3f) - 0x20, int(at.y))
			elif cars[pool_targets[slot]].wreck_frames == 0:
				var target := pool_targets[slot]
				if (t & 7) == 0:
					Fx.cloud_over(0, target)
				var part: int = {8: 1, 0x14: 2, 0x24: 3, 0x34: 4}.get(t & 0x3f, 0)
				if part != 0:
					Fx.cloud_over(part, target)
		POOL_SHOT:
			if t == 0x3f:
				Fx.shot_puff(slot)
			if (t & 0xf) != 0 and t < 0x3d:
				Fx.shot_trail(int(at.x) + (randi() & 0xf) - 7, int(at.z) + (randi() & 0xf) - 7, int(at.y))


# Puppets get the pool from the host once per game frame, already counted down.
func puppet_particles() -> void:
	if race.frame == puppet_frame:
		return
	puppet_frame = race.frame
	for slot in POOL:
		if pool_timers[slot] != 0:
			pool_particles(slot, pool_timers[slot] + 1)


func frame_step() -> float:
	return float(Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME + 1) / Car.PHYSICS_TICKS_PER_GAME_FRAME


# The shot steps once per game frame. Draw it across the physics ticks the
# same way the car blends its heading. A spent slot keeps its last spot.
func shot_visual(slot: int) -> Vector3:
	if Net.puppet() or pool_timers[slot] == 0 or pool_kinds[slot] != POOL_SHOT:
		return pool_positions[slot]
	return pool_from[slot].lerp(pool_positions[slot], frame_step())


func spawn_table() -> void:
	var player := race.player
	if race.places[player] == 1:
		cooldown = 100
	if cooldown != 0:
		cooldown -= 1
	var count := track.nodes.size()
	var found: PackedInt32Array
	for entry: PackedInt32Array in track.pickups:
		if entry[1] == race.laps_left[player] or entry[1] == 4:
			var ahead := entry[0] - camera.node
			if ahead < 0:
				ahead += count
			if ahead >= 17 and ahead <= 23:
				found = entry
				break
	if cooldown != 0 or found.is_empty():
		return
	pickup = true
	place_pickup(found[0], found[3])
	pickup_type = found[2]


func spawn_random() -> void:
	if setting == 0:
		return
	var count := track.nodes.size()
	var windows := 3 if setting == 1 else 5
	var step := count / windows
	var target := -1
	for k in windows:
		var past := camera.node - k * step
		if past >= 11 and past <= 15:
			target = (k + 1) * step
			break
	if pickup:
		var at := camera.node if camera.node >= 20 else camera.node + count
		if pickup_node + 10 < at and at < pickup_node + 20:
			pickup = false
		if pickup:
			return
	if target == -1:
		return
	var node := wrapi(target - 3 + (rand() & 7), 0, count)
	for range_pair: Array in track.respawn_ranges:
		if range_pair[0] < node and node <= range_pair[1]:
			node = int(range_pair[0])
			break
	pickup = true
	var types := RANDOM_TYPES
	if race.cars[0].vehicle_kind == Car.VEHICLE_BOAT:
		types = BOAT_TYPES
	elif race.cars[0].vehicle_kind == Car.VEHICLE_SUB:
		types = SUB_TYPES
	pickup_type = types[(rand() + race.frame) & 31]
	var code := 0
	if rand() & 3 != 0:
		code = 2 if rand() & 1 == 0 else 1
	place_pickup(node, code)


# Position codes: 0 centre, 1 left, 2 right, 3 between gate A and the left
# point, 4 between the right point and gate B. The sides sit lower by the
# node's lift bytes.
func place_pickup(node: int, code: int) -> void:
	var info: Dictionary = track.nodes[node]
	var u: Array = info.units
	var height: int = u[2]
	pickup_node = node
	pickup_orientation = ((-int(info.heading)) & 0xfff) >> 7
	match code:
		0:
			pickup_units = Vector3i(u[0], u[1], height)
		1:
			pickup_units = Vector3i(u[3], u[4], height - info.lift[0])
		2:
			pickup_units = Vector3i(u[5], u[6], height - info.lift[1])
		3:
			pickup_units = Vector3i((u[7] + u[3]) / 2, (u[8] + u[4]) / 2, height)
		4:
			pickup_units = Vector3i((u[5] + u[9]) / 2, (u[6] + u[10]) / 2, height)


# FUN_00056348 skips car-car collisions while either car has grown, is on
# stilts or bounces. A pair sunk into each other is bumped here instead of
# being pushed apart by the engine.
func update_ghosts() -> void:
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var ghost := cars[i].ghost() or cars[j].ghost() or cars[i].playback or cars[j].playback
			var sunk := not ghost and cars[i].sunk_into(cars[j])
			if sunk:
				cars[i].bump_car(cars[j], cars[i].sunk_normal(cars[j]))
			var skip := ghost or sunk
			if skip != cars[i].get_collision_exceptions().has(cars[j]):
				if skip:
					cars[i].add_collision_exception_with(cars[j])
				else:
					cars[i].remove_collision_exception_with(cars[j])


# Runs every physics tick after the cars, so the engine interpolates what it
# places. Values that step per game frame are blended across its ticks.
func place_visuals() -> void:
	var step := 1.0 if Net.puppet() else frame_step()
	var pickup_appear := pickup and (not pickup_mesh.visible or pickup_units != pickup_placed)
	pickup_mesh.visible = pickup
	if pickup:
		var shown := Vector2i(pickup_type, (pickup_orientation + 4) & 0x18)
		if shown != pickup_shown:
			pickup_shown = shown
			pickup_mesh.mesh = pickup_quad(shown.x, shown.y)
			var color: Array = PICKUP_COLORS[pickup_type]
			pickup_mesh.material_override.set_shader_parameter("tint", Vector3(color[0], color[1], color[2]) / 128.0)
		var angle := (float(race.frame) - 1.0 + step) * 0x40 * Car.ANGLE_TO_RAD
		var tilt := Vector2(sin(angle), cos(angle)) * 5.0 / 32.0 * Car.ONE * Car.ANGLE_TO_RAD
		var spin := Basis(Vector3.RIGHT, tilt.x) * Basis(Vector3.UP, tilt.y)
		# The original paints the whole quad from its center depth. Lay it on the
		# node slope and keep the low edge just above the road.
		var slope := track.node_slope(pickup_node)
		var road := Basis(Vector3.RIGHT, slope.x) * Basis(Vector3.BACK, -slope.y)
		var basis := road * MODEL_TO_WORLD * spin
		var up := road * Vector3.UP
		var h := PICKUP_HALF * UNIT
		var low := INF
		for x in [-h, h]:
			for y in [-h, h]:
				low = minf(low, up.dot(basis * Vector3(x, y, 0.0)))
		pickup_mesh.transform = Transform3D(basis, to_port(pickup_units) + up * (0.03 - low))
		if pickup_appear:
			pickup_placed = pickup_units
			pickup_mesh.reset_physics_interpolation()
	for slot in POOL:
		var mesh := pool_meshes[slot]
		var kind := pool_kinds[slot]
		var shown := pool_timers[slot] != 0 and (kind == POOL_OIL or kind == POOL_GLUE)
		var appear := shown and not mesh.visible
		mesh.visible = shown
		if not shown:
			continue
		# While the timer is above 0x50 the next pool update puts the slick
		# behind its owner again, so it rides the drawn car until then.
		var owner := cars[pool_owners[slot]]
		var at := pool_positions[slot]
		var tilt := pool_tilts[slot]
		if pool_timers[slot] > 0x50:
			var forward := Vector3(-owner.global_basis.z.x, 0.0, -owner.global_basis.z.z).normalized()
			at = owner.global_position - forward * 0x40 * UNIT
			tilt = owner.tilts_of(owner.floor_normal) if owner.grounded else owner.air_tilt
		var shape := slick_shape(minf(pool_timers[slot] + 1.0 - step, 100.0))
		var key := Vector3(shape.x, shape.y, kind)
		if appear or key != pool_shapes[slot]:
			pool_shapes[slot] = key
			mesh.mesh = slick_mesh(shape, kind == POOL_GLUE)
			mesh.material_override = slick_glue if kind == POOL_GLUE else slick_oil
		var basis := owner.tilt_basis(tilt)
		mesh.basis = basis
		mesh.position = at + basis * Vector3.UP * 0.05
		if appear:
			mesh.reset_physics_interpolation()


# FUN_00021e48: a flat 80-unit quad in the renderer's model frame whose icon
# corners are permuted by the node heading's quadrant.
func pickup_quad(type: int, quadrant: int) -> ArrayMesh:
	var h := PICKUP_HALF * UNIT
	var corners := [Vector3(h, -h, 0.0), Vector3(h, h, 0.0), Vector3(-h, -h, 0.0), Vector3(-h, h, 0.0)]
	var size := icons.get_size()
	var left := (type & 1) * 32.0
	var top := (type >> 1) * 32.0
	var l := left / size.x
	var r := (left + 31.0) / size.x
	var t := top / size.y
	var b := (top + 19.0) / size.y
	var uv: Array
	match quadrant:
		0:
			uv = [Vector2(l, t), Vector2(r, t), Vector2(l, b), Vector2(r, b)]
		8:
			uv = [Vector2(l, t), Vector2(l, b), Vector2(r, t), Vector2(r, b)]
		0x10:
			uv = [Vector2(r, t), Vector2(l, t), Vector2(r, b), Vector2(l, b)]
		0x18:
			uv = [Vector2(r, t), Vector2(r, b), Vector2(l, t), Vector2(l, b)]
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in [0, 1, 2, 2, 1, 3]:
		positions.append(corners[i])
		uvs.append(uv[i])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func slick_material(code: String, fire: Texture2D) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("sheet", fire)
	return material


# FUN_0002188c draws oil (kind 0, subtractive tpage 0x4e) and glue (kind 1,
# additive tpage 0x2e) as four flat quads of the fire page's bottom-right cell.
# The corner table is the shorts at 0x8d0ac, in the model frame of
# MODEL_TO_WORLD: the first short is model X (port -Z) and the second model Y
# (port X). The GPU quad is center, first pair, third pair, second pair, so the
# circle is split from the first pair to the third.
#
# The shade and spread step once per game frame from the timer. The timer is
# taken fractionally so the slick grows and fades smoothly between frames; at
# whole values this is the original's fixed point.
func slick_shape(timer: float) -> Vector2:
	if timer < 0x51:
		return Vector2(minf(timer, 0x14), 0x14)
	return Vector2(100.0 - timer, 100.0 - timer)


func slick_mesh(shape: Vector2, glue: bool) -> ArrayMesh:
	var level := shape.x * 4.0
	var color := Color(level / 128.0, level / 128.0, level / 128.0)
	if glue:
		color = Color(floorf(level / 6.0) / 128.0, level / 128.0, floorf(level / 3.0) / 128.0)
	var span := shape.y * 5.0
	var positions := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var cell := 1.0 / 256.0
	var uv_center := Vector2(0xe0 * cell, 0xe0 * cell)
	var uv_right := Vector2(0xff * cell, 0xe0 * cell)
	var uv_down := Vector2(0xe0 * cell, 0xff * cell)
	var uv_far := Vector2(0xff * cell, 0xff * cell)
	for quad in [[16, 44, -56, 24, -42, 0], [-8, -20, -24, -48, -42, 0], [-8, -20, 28, -40, 40, 8], [16, 44, 56, 24, 40, 8]]:
		var center := Vector3.ZERO
		var corner_a := Vector3(slick_offset(int(quad[1]), span), 0.0, -slick_offset(int(quad[0]), span))
		var corner_b := Vector3(slick_offset(int(quad[3]), span), 0.0, -slick_offset(int(quad[2]), span))
		var corner_c := Vector3(slick_offset(int(quad[5]), span), 0.0, -slick_offset(int(quad[4]), span))
		var corners := [center, corner_a, corner_c, corner_b]
		var corner_uv := [uv_center, uv_right, uv_down, uv_far]
		for i in [0, 1, 2, 1, 2, 3]:
			positions.append(corners[i])
			uvs.append(corner_uv[i])
			colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	var built := ArrayMesh.new()
	built.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return built


# value * span >> 5, rounded toward zero like the original.
func slick_offset(value: int, span: float) -> float:
	return float(int(value * span / 32.0)) * UNIT
