class_name TrackScript
extends Node3D

# Port of the per-frame track script interpreter (FUN_0002f2e8). The script is
# a list of shorts at TRK 0xFEDC made of BEGIN..END blocks that run in order;
# statements are separated by 0x7d0d. It moves the objects in the object table
# and pushes, lifts, holds and wrecks cars in scripted regions.

const BEGIN := 0x7d01
const END := 0x7d02
const EVAL := 0x7d03
const STORE := 0x7d04
const IF := 0x7d05
const GOTO := 0x7d06
const SINE := 0x7d07
const EXPLODE := 0x7d0a
const SPLASH := 0x7d0b
const HOLD := 0x7d0c
const SEPARATOR := 0x7d0d
const NOP := 0x7d0e
const PARTICLE := 0x7d0f
const EFFECT := 0x7d10
const EFFECT_X := 0x7e36
const EFFECT_Y := 0x7e37
const EFFECT_HEIGHT := 0x7e38
const EFFECT_TYPE := 0x7e3f
const EFFECT_LIFE := 0x7e43
const EFFECT_EXTRA := 0x7e44
const CARPET := 0x7d64
const SCROLL := 0x7d6b
const LABEL := 0x7dc8
const OBJECT := 0x7e2c
const CAR := 0x7e2d
const VARIABLE := 0x7e2e
const FIELD := 0x7e36
const FRAME := 0x7e90
const RANDOM := 0x7e9b
const ADD := 0x7ef4
const SUBTRACT := 0x7ef5
const MULTIPLY := 0x7ef6
const DIVIDE := 0x7ef7
const AND := 0x7ef8
const OR := 0x7ef9
const COMPARE := 0x7f58
const EQUAL := 0x7f5e
const NOT_EQUAL := 0x7f5f
const LESS := 0x7f60
const GREATER := 0x7f61
const LESS_EQUAL := 0x7f62
const GREATER_EQUAL := 0x7f63
const GROUP := 100
const VARIABLES := 8
const MAX_TOKENS := 0x7f8
const MAX_CARS := 8
const LITERAL_LIMIT := 32000

const OBJECT_STRIDE := 8
const OBJECTS := 128
# Field token -> short in an object entry [s0, s1, s2, type, rx, ry, rz, model].
const OBJECT_FIELDS := {FIELD: 1, FIELD + 1: 0, FIELD + 2: 2, FIELD + 3: 4, FIELD + 4: 5, FIELD + 5: 6}
const CAR_X := FIELD
const CAR_Y := FIELD + 1
const CAR_HEIGHT := FIELD + 2
const CAR_ENGINE := FIELD + 7
const CAR_GRIP := FIELD + 8
const CAR_VEL_X := FIELD + 10
const CAR_VEL_Y := FIELD + 11
const CAR_VEL_HEIGHT := FIELD + 12

# Ease table at 0x14e60 in the executable, read as table[(x >> 5) & 0x7f].
const SINE_TABLE := [0, 0, 2, 5, 9, 15, 22, 30, 39, 49, 61, 74, 88, 103, 119, 137, 155, 175, 196, 218, 241, 266, 291, 317, 345, 373, 403, 433, 464, 497, 530, 564, 599, 635, 672, 710, 748, 788, 828, 868, 910, 952, 995, 1038, 1082, 1127, 1172, 1218, 1264, 1310, 1358, 1405, 1453, 1501, 1550, 1599, 1648, 1697, 1747, 1797, 1847, 1897, 1947, 1997, 2048, 2098, 2148, 2198, 2248, 2298, 2348, 2398, 2447, 2496, 2545, 2594, 2642, 2690, 2737, 2785, 2831, 2877, 2923, 2968, 3013, 3057, 3100, 3143, 3185, 3227, 3267, 3307, 3347, 3385, 3423, 3460, 3496, 3531, 3565, 3598, 3631, 3662, 3692, 3722, 3750, 3778, 3804, 3829, 3854, 3877, 3899, 3920, 3940, 3958, 3976, 3992, 4007, 4021, 4034, 4046, 4056, 4065, 4073, 4080, 4086, 4090, 4093, 4095]
# Start offsets of the 20 scrolling objects (0x8d176), indexed by object.
const SCROLL_TABLE := [-3, -512, -1024, -2048, -2560, 4096, 3584, 2560, 2048, 1024, 512, -1280, -1792, -2816, 4352, 3328, 2816, 1792, 1280, 256, -256]
const SCROLL_OBJECTS := 20
const SCROLL_PERIOD := 0x3bf
const SCROLL_SPEED := 8
const SCROLL_WRAP := 0x1e00
const SCROLL_MIN := -0xc00

const UNIT := Car.UNIT_METRES
# The renderer's model frame (FUN_00033484) is (-y, x, -height) of the world.
const MODEL_TO_WORLD := Basis(Vector3(0.0, 0.0, -1.0), Vector3(1.0, 0.0, 0.0), Vector3(0.0, -1.0, 0.0))

var track: Track
var cars: Array[Car] = []
var camera: TrackCamera
var tokens := PackedInt32Array()
var objects := PackedInt32Array()
var variables := PackedInt32Array()
var labels := PackedInt32Array()
var acc := 0
var pc := 0
var frame := 0
var effect_x := 0
var effect_y := 0
var effect_height := 0
var effect_type := 0
var effect_life := 0
var effect_extra := 0
var scroll := 0
var carpet_riders := 0
var instances: Dictionary[int, MeshInstance3D] = {}


func setup(race_track: Track, racers: Array[Car], track_camera: TrackCamera) -> void:
	track = race_track
	cars = racers
	camera = track_camera
	tokens = track.script_tokens
	objects = track.objects.duplicate()
	variables.resize(VARIABLES)
	labels.resize(GROUP)
	labels.fill(-1)
	process_physics_priority = -1
	for i in OBJECTS:
		var model := objects[i * OBJECT_STRIDE + 7]
		if objects[i * OBJECT_STRIDE + 3] > 1 and track.object_meshes.has(model):
			var instance := MeshInstance3D.new()
			instance.mesh = track.object_meshes[model]
			add_child(instance)
			instances[i] = instance
	update_instances()


func _physics_process(_delta: float) -> void:
	if Net.puppet():
		return
	if Engine.get_physics_frames() % Car.PHYSICS_TICKS_PER_GAME_FRAME != 0:
		return
	run()
	frame += 1
	update_instances()


func update_instances() -> void:
	for i: int in instances:
		var o := i * OBJECT_STRIDE
		var rotation_basis := Basis(Vector3.RIGHT, objects[o + 4] * Car.ANGLE_TO_RAD) * Basis(Vector3.UP, objects[o + 5] * Car.ANGLE_TO_RAD) * Basis(Vector3.BACK, objects[o + 6] * Car.ANGLE_TO_RAD)
		var origin := Vector3(objects[o + 1] + 0x100, 0x100 - objects[o + 2], 0x100 - objects[o]) * UNIT
		instances[i].transform = Transform3D(MODEL_TO_WORLD * rotation_basis, origin)


func run() -> void:
	for car in cars:
		if car.held:
			car.release_hold()
	pc = 0
	while tokens[pc] == BEGIN:
		scan_labels()
		pc += 1
		run_block()
		while tokens[pc] == SEPARATOR:
			pc += 1


func scan_labels() -> void:
	var i := pc + 1
	while tokens[i] != END:
		assert(i < MAX_TOKENS)
		if is_label(tokens[i]) and tokens[i - 1] != GOTO:
			labels[tokens[i] - LABEL] = i
		i += 1


func run_block() -> void:
	while true:
		var token := tokens[pc]
		if token == SEPARATOR or token == NOP or is_label(token):
			pc += 1
		elif token >= CARPET and token <= SCROLL:
			if token == CARPET:
				carpet()
			elif token == SCROLL:
				scroll_objects()
			pc += 1
		elif token == END:
			pc += 1
			return
		elif token == EVAL:
			acc = evaluate(0)
		elif token == STORE:
			store(acc)
			pc += 1
		elif token == IF:
			branch()
		elif token == GOTO:
			pc = label_position(tokens[pc + 1])
		elif token == EXPLODE or token == SPLASH:
			assert(acc >= 0 and acc < MAX_CARS)
			if acc < cars.size():
				cars[acc].wreck()
			pc += 1
		elif token == HOLD:
			assert(acc >= 0 and acc < MAX_CARS)
			if acc < cars.size():
				cars[acc].hold()
			pc += 1
		elif token == SINE:
			acc = sine(acc)
			pc += 1
		elif token == PARTICLE:
			pc += 1
			if (randi() & 3) == 0:
				Fx.track_particle(effect_x, effect_y, effect_height, effect_type)
		elif token == EFFECT:
			pc += 1
			Fx.track_effect(effect_x, effect_y, effect_height, effect_type, effect_life, effect_extra)
		else:
			assert(false, "Unsupported track script token 0x%x at %d" % [token, pc])


# FUN_0002fa78: operands combine left to right with the last operator seen.
func evaluate(value: int) -> int:
	var op := ADD
	pc += 1
	while not ends_expression(tokens[pc]):
		var token := tokens[pc]
		if token >= ADD and token < ADD + GROUP:
			op = token
		else:
			value = apply(op, value, operand(token))
		pc += 1
		assert(pc < MAX_TOKENS)
	return value


func ends_expression(token: int) -> bool:
	return token == STORE or token == GOTO or (token >= EXPLODE and token <= SEPARATOR) or (token >= COMPARE and token < COMPARE + GROUP)


func apply(op: int, value: int, x: int) -> int:
	match op:
		ADD:
			return value + x
		SUBTRACT:
			return value - x
		MULTIPLY:
			return value * x
		DIVIDE:
			assert(x != 0)
			return value / x
		AND:
			return value & x
		OR:
			return value | x
	return value


func operand(token: int) -> int:
	if is_variable(token):
		return variables[token - VARIABLE]
	if token == OBJECT:
		var o := object_field()
		return objects[o]
	if token == CAR:
		var index := car_index()
		pc += 2
		return read_car(index, tokens[pc])
	if token == FRAME:
		return frame
	if token == RANDOM:
		return randi() & 0x7fff
	assert(token < LITERAL_LIMIT, "Unsupported track script operand 0x%x at %d" % [token, pc])
	return token


func store(value: int) -> void:
	pc += 1
	var target := tokens[pc]
	if is_variable(target):
		variables[target - VARIABLE] = value
	elif target == OBJECT:
		var o := object_field()
		objects[o] = ((value + 0x8000) & 0xffff) - 0x8000
	elif target == CAR:
		var index := car_index()
		pc += 2
		write_car(index, tokens[pc], value)
	elif target == EFFECT_X:
		effect_x = value
	elif target == EFFECT_Y:
		effect_y = value
	elif target == EFFECT_HEIGHT:
		effect_height = value
	elif target == EFFECT_TYPE:
		effect_type = value
	elif target == EFFECT_LIFE:
		effect_life = value
	elif target == EFFECT_EXTRA:
		effect_extra = value
	else:
		assert(false, "Unsupported track script target 0x%x at %d" % [target, pc])


# FUN_0002f884: IF a <cmp> b GOTO label; a false condition skips the GOTO.
func branch() -> void:
	var a := evaluate(0)
	var comparison := tokens[pc]
	assert(comparison >= COMPARE and comparison < COMPARE + GROUP)
	var b := evaluate(0)
	assert(tokens[pc] == GOTO)
	var target := label_position(tokens[pc + 1])
	pc = target if compare(comparison, a, b) else pc + 2


func compare(comparison: int, a: int, b: int) -> bool:
	match comparison:
		EQUAL:
			return a == b
		NOT_EQUAL:
			return a != b
		LESS:
			return a < b
		GREATER:
			return a > b
		LESS_EQUAL:
			return a <= b
		GREATER_EQUAL:
			return a >= b
	return true


func label_position(token: int) -> int:
	assert(is_label(token) and labels[token - LABEL] >= 0)
	return labels[token - LABEL]


func is_label(token: int) -> bool:
	return token >= LABEL and token < LABEL + GROUP


func is_variable(token: int) -> bool:
	return token >= VARIABLE and token < VARIABLE + VARIABLES


func index_operand() -> int:
	var token := tokens[pc + 1]
	if token >= LITERAL_LIMIT:
		assert(is_variable(token))
		return variables[token - VARIABLE]
	return token


func object_field() -> int:
	var index := index_operand()
	assert(index >= 0 and index < OBJECTS)
	pc += 2
	assert(OBJECT_FIELDS.has(tokens[pc]))
	return index * OBJECT_STRIDE + OBJECT_FIELDS[tokens[pc]]


func car_index() -> int:
	var index := index_operand()
	assert(index >= 0 and index < MAX_CARS)
	return index


func sine(x: int) -> int:
	return SINE_TABLE[(x >> 5) & 0x7f]


# Car positions are whole units truncated towards zero, like the shorts the
# original keeps next to its fixed-point position.
func units(metres: float) -> int:
	return int(snappedf(metres / UNIT, 0.0001))


func read_car(index: int, field: int) -> int:
	if index >= cars.size():
		return 0
	var car := cars[index]
	match field:
		CAR_X:
			return units(car.global_position.x)
		CAR_Y:
			return units(car.global_position.z)
		CAR_HEIGHT:
			return units(car.global_position.y)
		CAR_VEL_X:
			return int(car.vel.x)
		CAR_VEL_Y:
			return int(car.vel.z)
		CAR_VEL_HEIGHT:
			return int(car.vel.y)
	assert(false, "Unsupported car field 0x%x at %d" % [field, pc])
	return 0


func write_car(index: int, field: int, value: int) -> void:
	if index >= cars.size():
		return
	var car := cars[index]
	match field:
		CAR_X:
			car.global_position.x = value * UNIT
		CAR_Y:
			car.global_position.z = value * UNIT
		CAR_HEIGHT:
			car.global_position.y = value * UNIT
		CAR_ENGINE:
			car.engine = value
		CAR_GRIP:
			car.grip = value
		CAR_VEL_X:
			car.vel.x = value
		CAR_VEL_Y:
			car.vel.z = value
		CAR_VEL_HEIGHT:
			car.vel.y = value
		_:
			assert(false, "Unsupported car field 0x%x at %d" % [field, pc])


# FUN_0002f228: objects 1-20 drift towards +y and wrap around.
func scroll_objects() -> void:
	if frame == 0:
		scroll = 0
	while scroll > SCROLL_PERIOD:
		scroll -= SCROLL_PERIOD
	scroll += 1
	for i in range(1, SCROLL_OBJECTS + 1):
		var s: int = SCROLL_TABLE[i] - scroll * SCROLL_SPEED
		while s < SCROLL_MIN:
			s += SCROLL_WRAP
		objects[i * OBJECT_STRIDE] = s


# FUN_0002ecb0: object 1 is a bobbing carpet that ferries cars across a pit.
# It waits at one end, moves while carried, and returns when empty; the camera
# node picks the direction.
func carpet() -> void:
	var o := OBJECT_STRIDE
	var phase := frame & 0x1f
	if phase > 0xf:
		phase = 0x1f - phase
	objects[o + 2] = -(sine(phase << 8) >> 8)
	var step := 0
	if camera.node < 0x65:
		if carpet_riders != 0:
			if objects[o] > -0x700:
				step = -4
		elif objects[o] <= -0x301:
			step = 8
	else:
		if carpet_riders != 0:
			if objects[o] < -0x300:
				step = 4
		elif objects[o] >= -0x6ff:
			step = -8
	objects[o] += step
	carpet_riders = 0
	for i in mini(cars.size(), MAX_CARS):
		var car := cars[i]
		var x := read_car(i, CAR_X)
		var y := read_car(i, CAR_Y)
		if x < 0x2181 or x >= 0x2880 or y < 0x81 or y >= 0xb60:
			continue
		var dx := x - objects[o + 1]
		var dy := y + objects[o]
		if dx >= 0 and dx <= 0x200 and dy >= 0 and dy <= 0x200:
			write_car(i, CAR_HEIGHT, 0x120 - objects[o + 2])
			car.global_position.z -= step * UNIT
			car.hold()
			car.engine = 0x1000
			car.grip = 0x50
			carpet_riders += 1
		if read_car(i, CAR_HEIGHT) < 0x100:
			car.wreck()
