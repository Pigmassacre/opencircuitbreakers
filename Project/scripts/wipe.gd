extends Node

const SWEEP := 0.34
const SLICE := 16

var block: Control
var shade: ColorRect
var percent: Label
var busy := false
var covering := false
var boot := Callable()
var shown := 0.0
var lo := 0.0
var hi := 1.0
var clock := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	block = Control.new()
	block.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.visible = false
	layer.add_child(block)
	shade = ColorRect.new()
	shade.color = Color.BLACK
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.anchor_top = 0.0
	shade.anchor_bottom = 1.0
	shade.visible = false
	layer.add_child(shade)
	percent = Label.new()
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	percent.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	percent.offset_left = 36.0
	percent.offset_top = -68.0
	percent.offset_right = -36.0
	percent.offset_bottom = -24.0
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.add_theme_font_override("font", UiTheme.font())
	percent.add_theme_font_size_override("font_size", 32)
	percent.add_theme_color_override("font_color", UiTheme.CREAM)
	percent.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	percent.add_theme_constant_override("shadow_offset_x", 0)
	percent.add_theme_constant_override("shadow_offset_y", 2)
	percent.add_theme_constant_override("shadow_outline_size", 6)
	percent.visible = false
	percent.text = "0%"
	layer.add_child(percent)


func to(path: String, during: Callable = Callable()) -> void:
	if busy:
		return
	busy = true
	covering = true
	boot = Callable()
	block.visible = true
	shade.visible = true
	shade.offset_left = 0.0
	shade.offset_right = 0.0
	var width := get_viewport().get_visible_rect().size.x
	await sweep("offset_right", width)
	# The cover reaches black before this frame is drawn. Wait until that frame is up.
	await get_tree().process_frame
	get_tree().paused = false
	shown = 0.0
	lo = 0.0
	hi = 1.0
	clock = Time.get_ticks_msec()
	percent.text = "0%"
	percent.visible = true
	if during.is_valid():
		hi = 0.5
		await during.call()
		lo = 0.0
		hi = 1.0
	var scene_from := shown
	lo = scene_from
	hi = minf(scene_from + 0.08, 1.0)
	var packed := await load_packed(path)
	lo = 0.0
	hi = 1.0
	get_tree().change_scene_to_packed(packed)
	if boot.is_valid():
		var job := boot
		boot = Callable()
		lo = shown
		hi = 1.0
		await job.call()
	lo = 0.0
	hi = 1.0
	report(1.0)
	percent.visible = false
	covering = false
	await sweep("offset_left", width)
	clear()


func load_packed(path: String) -> PackedScene:
	if ResourceLoader.has_cached(path):
		await breathe(1.0)
		return load(path) as PackedScene
	ResourceLoader.load_threaded_request(path)
	var progress: Array = []
	while true:
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		var local := 0.0
		if not progress.is_empty():
			local = float(progress[0])
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			await breathe(1.0)
			break
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			push_error("Could not load %s" % path)
			break
		await breathe(local)
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene


func read_file(path: String, a: float, b: float) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	var length := file.get_length()
	var out := PackedByteArray()
	if length == 0:
		await breathe(b)
		return out
	var got := 0
	while got < length:
		var n := mini(1024 * 1024, length - got)
		out.append_array(file.get_buffer(n))
		got += n
		await breathe(lerpf(a, b, float(got) / float(length)))
	return out


func push(a: float, b: float) -> Vector2:
	var prev := Vector2(lo, hi)
	lo = lerpf(prev.x, prev.y, a)
	hi = lerpf(prev.x, prev.y, b)
	return prev


func pop(prev: Vector2) -> void:
	lo = prev.x
	hi = prev.y


func report(local: float) -> void:
	var value := lerpf(lo, hi, clampf(local, 0.0, 1.0))
	if value < shown:
		value = shown
	shown = value
	percent.text = "%d%%" % roundi(shown * 100.0)


func breathe(local: float) -> void:
	report(local)
	var now := Time.get_ticks_msec()
	if now - clock < SLICE:
		return
	clock = now
	await get_tree().process_frame


func sweep(property: String, target: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(shade, property, target, SWEEP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func clear() -> void:
	shade.visible = false
	shade.offset_left = 0.0
	shade.offset_right = 0.0
	percent.visible = false
	block.visible = false
	covering = false
	boot = Callable()
	busy = false
