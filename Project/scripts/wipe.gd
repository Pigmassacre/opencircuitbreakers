extends Node

const SWEEP := 0.34

var block: Control
var shade: ColorRect
var busy := false


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


func to(path: String) -> void:
	if busy:
		return
	busy = true
	block.visible = true
	shade.visible = true
	shade.offset_left = 0.0
	shade.offset_right = 0.0
	var width := get_viewport().get_visible_rect().size.x
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(shade, "offset_right", width, SWEEP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file(path)
	)
	tween.tween_property(shade, "offset_left", width, SWEEP).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(clear)


func clear() -> void:
	shade.visible = false
	shade.offset_left = 0.0
	shade.offset_right = 0.0
	block.visible = false
	busy = false
