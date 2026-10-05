class_name BattleCamera
extends TrackCamera

# The shared battle camera. Battle sets the targets every game frame; yaw, zoom
# and distance step towards them at the original's per-frame rates. The focus
# follows the cars Battle doesn't ignore every tick, since they move every tick,
# at most 0x60 units a frame (FUN_00036f5c).

const BATTLE_YAW_RATE := Battle.YAW_RATE / float(TICKS)
const ZOOM_RATE := Battle.ZOOM_RATE / float(TICKS)
const BATTLE_DISTANCE_RATE := Battle.DISTANCE_RATE / float(TICKS)

var yaw_target := 0.0
var zoom := 0.0
var zoom_target := 0.0
var distance_target := 0.0
var focus_target := Vector3.ZERO
var cars: Array[Car] = []
var ignored := PackedByteArray()
var tracking := false
var puppet_from := Transform3D.IDENTITY
var puppet_to := Transform3D.IDENTITY
var puppet_age := 0.0


func _ready() -> void:
	if Net.puppet():
		physics_interpolation_mode = PHYSICS_INTERPOLATION_MODE_OFF


func _process(delta: float) -> void:
	if not Net.puppet():
		return
	puppet_age += delta
	blend_puppet()


func snap() -> void:
	fov = PSX_FOV
	yaw = yaw_target
	zoom = zoom_target
	distance = distance_target
	focus = focus_target
	pitch = zoom + Battle.PITCH_OFFSET
	apply_transform()
	reset_physics_interpolation()
	puppet_from = global_transform
	puppet_to = global_transform


func apply_puppet(xform: Transform3D) -> void:
	puppet_from = xform if global_position.distance_squared_to(xform.origin) > 64.0 else global_transform
	puppet_to = xform
	puppet_age = 0.0


func blend_puppet() -> void:
	var along := clampf(puppet_age * 30.0, 0.0, 1.0)
	global_transform = puppet_from.interpolate_with(puppet_to, along)


func _physics_process(_delta: float) -> void:
	if Net.puppet():
		blend_puppet()
		return
	if tracking and ignored.count(0) > 0:
		focus_target = Battle.focus_box(cars, ignored).get_center()
	yaw = ease_angle(yaw, yaw_target, BATTLE_YAW_RATE)
	zoom = move_toward(zoom, zoom_target, ZOOM_RATE)
	pitch = zoom + Battle.PITCH_OFFSET
	distance = move_toward(distance, distance_target, BATTLE_DISTANCE_RATE)
	follow(focus_target)
	apply_transform()


func arrived() -> bool:
	return focus.is_equal_approx(focus_target)
