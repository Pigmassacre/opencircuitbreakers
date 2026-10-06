class_name UiTheme
extends RefCounted

const TEXT_COLOR := Color(0.97, 0.96, 0.98)
const INK := Color(0.24, 0.05, 0.11)
const ACCENT := Color(0.86, 0.15, 0.46)
const CREAM := Color(0.99, 0.88, 0.58)
const CORAL := Color(0.93, 0.4, 0.26)
const LIP := Color(0.4, 0.05, 0.18)
const OPTIONS_W := 700.0
const OPTION_LABEL_W := 220.0


static func font() -> Font:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Arial", "DejaVu Sans", "sans-serif"])
	system_font.font_weight = 700
	system_font.font_italic = false
	return system_font


static func theme() -> Theme:
	var theme := Theme.new()
	var face := font()
	var text := TEXT_COLOR
	theme.default_font = face
	theme.default_font_size = 22
	for type in ["Label", "Button", "ItemList", "LineEdit", "PopupMenu"]:
		theme.set_font("font", type, face)
		theme.set_color("font_color", type, text)
		theme.set_color("font_outline_color", type, Color.BLACK)
		theme.set_constant("outline_size", type, 0)
		theme.set_color("font_shadow_color", type, Color(0.0, 0.0, 0.0, 0.55))
		theme.set_constant("shadow_outline_size", type, 4)
		theme.set_constant("shadow_offset_x", type, 0)
		theme.set_constant("shadow_offset_y", type, 2)
	for state in ["focus", "pressed", "hover", "hover_pressed", "disabled"]:
		theme.set_color("font_%s_color" % state, "Button", text)
		theme.set_color("icon_%s_color" % state, "Button", text)
	theme.set_color("icon_normal_color", "Button", text)
	theme.set_color("icon_hover_color", "Button", INK)
	theme.set_color("icon_pressed_color", "Button", INK)
	theme.set_color("icon_hover_pressed_color", "Button", INK)
	theme.set_color("icon_focus_color", "Button", INK)
	theme.set_color("font_hovered_color", "ItemList", text)
	theme.set_color("font_selected_color", "ItemList", INK)
	theme.set_color("font_hover_color", "PopupMenu", INK)
	theme.set_color("font_disabled_color", "PopupMenu", Color(text, 0.4))
	theme.set_color("caret_color", "LineEdit", text)
	theme.set_color("font_selected_color", "LineEdit", text)
	theme.set_color("selection_color", "LineEdit", Color(ACCENT, 0.45))
	theme.set_color("font_color", "Button", TEXT_COLOR)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_color("font_hover_pressed_color", "Button", INK)
	theme.set_color("font_focus_color", "Button", INK)
	theme.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))
	var normal := button_style(ACCENT, LIP)
	var selected := button_style(CREAM, CORAL)
	var focus := button_style(CREAM, CORAL)
	focus.shadow_size = 0
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", selected)
	theme.set_stylebox("pressed", "Button", selected)
	theme.set_stylebox("hover_pressed", "Button", selected)
	theme.set_stylebox("disabled", "Button", button_style(Color(0.32, 0.08, 0.16, 0.55), Color(0.2, 0.04, 0.1, 0.4)))
	theme.set_stylebox("focus", "Button", focus)
	var option_normal := button_style(ACCENT, LIP)
	var option_selected := button_style(CREAM, CORAL)
	var option_focus := button_style(CREAM, CORAL)
	option_focus.shadow_size = 0
	var option_disabled := button_style(Color(0.32, 0.08, 0.16, 0.55), Color(0.2, 0.04, 0.1, 0.4))
	for style in [option_normal, option_selected, option_focus, option_disabled]:
		style.content_margin_right = 46
	theme.set_stylebox("normal", "OptionButton", option_normal)
	theme.set_stylebox("hover", "OptionButton", option_selected)
	theme.set_stylebox("pressed", "OptionButton", option_selected)
	theme.set_stylebox("hover_pressed", "OptionButton", option_selected)
	theme.set_stylebox("disabled", "OptionButton", option_disabled)
	theme.set_stylebox("focus", "OptionButton", option_focus)
	theme.set_icon("arrow", "OptionButton", dropdown_arrow())
	theme.set_constant("arrow_margin", "OptionButton", 16)
	theme.set_constant("modulate_arrow", "OptionButton", 0)
	var field := panel_style(Color(0.16, 0.03, 0.08, 0.92), Color(ACCENT, 0.9))
	var row_hover := panel_style(Color(ACCENT, 0.95), CREAM)
	var row_pressed := panel_style(CREAM, CORAL)
	theme.set_stylebox("panel", "ItemList", field)
	theme.set_stylebox("hovered", "ItemList", row_hover)
	theme.set_stylebox("selected", "ItemList", row_pressed)
	theme.set_stylebox("selected_focus", "ItemList", row_pressed)
	theme.set_stylebox("hovered_selected", "ItemList", row_pressed)
	theme.set_stylebox("hovered_selected_focus", "ItemList", row_pressed)
	theme.set_stylebox("cursor", "ItemList", focus)
	theme.set_stylebox("cursor_unfocused", "ItemList", focus)
	theme.set_stylebox("focus", "ItemList", focus)
	theme.set_stylebox("panel", "PopupMenu", panel_style(Color(0.14, 0.03, 0.08, 0.96), ACCENT))
	theme.set_stylebox("hover", "PopupMenu", row_pressed)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field)
	theme.set_stylebox("read_only", "LineEdit", field)
	var groove := StyleBoxFlat.new()
	groove.bg_color = Color(0.28, 0.05, 0.12, 0.95)
	groove.content_margin_top = 5
	groove.content_margin_bottom = 5
	theme.set_stylebox("slider", "HSlider", groove)
	var filled := StyleBoxFlat.new()
	filled.bg_color = CREAM
	filled.content_margin_top = 5
	filled.content_margin_bottom = 5
	theme.set_stylebox("grabber_area", "HSlider", filled)
	theme.set_stylebox("grabber_area_highlight", "HSlider", filled)
	theme.set_icon("grabber", "HSlider", grabber(CREAM))
	theme.set_icon("grabber_highlight", "HSlider", grabber(Color.WHITE, Vector2i(14, 34), 2))
	theme.set_type_variation("SpinBoxInnerLineEdit", "LineEdit")
	theme.set_stylebox("normal", "SpinBoxInnerLineEdit", field)
	theme.set_stylebox("focus", "SpinBoxInnerLineEdit", field)
	theme.set_stylebox("read_only", "SpinBoxInnerLineEdit", field)
	theme.set_constant("outline_size", "SpinBoxInnerLineEdit", 3)
	theme.set_color("font_color", "SpinBoxInnerLineEdit", text)
	theme.set_font("font", "SpinBoxInnerLineEdit", face)
	theme.set_constant("buttons_width", "SpinBox", 22)
	theme.set_constant("field_and_buttons_separation", "SpinBox", 6)
	theme.set_color("up_icon_modulate", "SpinBox", text)
	theme.set_color("down_icon_modulate", "SpinBox", text)
	theme.set_color("up_hover_icon_modulate", "SpinBox", CREAM)
	theme.set_color("down_hover_icon_modulate", "SpinBox", CREAM)
	theme.set_color("up_pressed_icon_modulate", "SpinBox", CREAM)
	theme.set_color("down_pressed_icon_modulate", "SpinBox", CREAM)
	var box_on := checkbox_icon(true)
	var box_off := checkbox_icon(false)
	for state in ["", "_disabled"]:
		theme.set_icon("checked" + state, "CheckBox", box_on)
		theme.set_icon("unchecked" + state, "CheckBox", box_off)
	for state in ["", "_hover", "_pressed", "_focus", "_hover_pressed"]:
		theme.set_color("font" + state + "_color", "CheckBox", TEXT_COLOR)
	theme.set_constant("h_separation", "CheckBox", 10)
	return theme


static func dropdown_arrow() -> ImageTexture:
	var image := Image.create(26, 18, false, Image.FORMAT_RGBA8)
	fill_triangle(image, Vector2(2, 2), Vector2(23, 2), Vector2(12.5, 15), CREAM)
	return ImageTexture.create_from_image(image)


static func fill_triangle(image: Image, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var min_x := maxi(int(minf(a.x, minf(b.x, c.x))), 0)
	var max_x := mini(int(ceilf(maxf(a.x, maxf(b.x, c.x)))), image.get_width() - 1)
	var min_y := maxi(int(minf(a.y, minf(b.y, c.y))), 0)
	var max_y := mini(int(ceilf(maxf(a.y, maxf(b.y, c.y)))), image.get_height() - 1)
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			if point_in_triangle(Vector2(x + 0.5, y + 0.5), a, b, c):
				image.set_pixel(x, y, color)


static func point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var v0 := c - a
	var v1 := b - a
	var v2 := p - a
	var dot00 := v0.dot(v0)
	var dot01 := v0.dot(v1)
	var dot02 := v0.dot(v2)
	var dot11 := v1.dot(v1)
	var dot12 := v1.dot(v2)
	var inv := 1.0 / (dot00 * dot11 - dot01 * dot01)
	var u := (dot11 * dot02 - dot01 * dot12) * inv
	var v := (dot00 * dot12 - dot01 * dot02) * inv
	return u >= 0.0 and v >= 0.0 and u + v <= 1.0


static func panel_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


static func button_style(fill: Color, lip: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = lip
	style.set_border_width_all(0)
	style.border_width_bottom = 5
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 10
	style.content_margin_bottom = 8
	style.skew = Vector2(0.22, 0)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2, 5)
	return style


static func shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.02, 0.06, 0.94)
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.border_width_bottom = 5
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 6)
	return style


static func add_heading(column: VBoxContainer, title: String, size: int) -> void:
	var block := VBoxContainer.new()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_theme_constant_override("separation", 8)
	column.add_child(block)
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	block.add_child(label)
	var rule := ColorRect.new()
	rule.color = ACCENT
	rule.custom_minimum_size = Vector2(clampf(float(title.length()) * 14.0, 96.0, 280.0), 4.0)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_meta("rule", true)
	block.add_child(rule)


static func options_scroll(column: Container) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 22)
	stack.custom_minimum_size = Vector2(OPTIONS_W, 0)
	margin.add_child(stack)
	return scroll


static func options_stack(scroll: ScrollContainer) -> VBoxContainer:
	return scroll.get_child(0).get_child(0)


# Grows the scroll to its content, but no taller than the panel fits in height.
static func fit_scroll(scroll: ScrollContainer, panel: Control, height: float) -> void:
	var margin := scroll.get_child(0) as MarginContainer
	var content := options_stack(scroll).get_combined_minimum_size().y
	var room := height - (panel.size.y - scroll.size.y)
	var bar := 0
	if room < content:
		bar = int(scroll.get_v_scroll_bar().get_combined_minimum_size().x) + 12
	margin.add_theme_constant_override("margin_right", bar)
	scroll.custom_minimum_size.y = clampf(room, 0.0, content)


static func fill_options(column: VBoxContainer) -> HSlider:
	section_header(column, "Audio")
	var focus := volume_row(column, "Master", Settings.master, Settings.set_master)
	volume_row(column, "Music", Settings.music, Settings.set_music)
	volume_row(column, "SFX", Settings.sfx, Settings.set_sfx)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(gap)
	section_header(column, "Graphics")
	var mode := choice_row(column, "Window", ["Windowed", "Borderless", "Fullscreen"], Settings.window_mode, Settings.set_window_mode)
	Settings.window_mode_changed.connect(func() -> void: mode.select(Settings.window_mode))
	var sizes := Settings.resolutions()
	var labels: Array[String] = []
	var selected := 0
	for i in sizes.size():
		labels.append("%d x %d" % [sizes[i].x, sizes[i].y])
		if sizes[i] == Settings.resolution:
			selected = i
	choice_row(column, "Resolution", labels, selected, func(index: int) -> void: Settings.set_resolution(sizes[index]))
	choice_row(column, "Distance Fog", ["Far", "Original"], Settings.fog, Settings.set_fog)
	choice_row(column, "Texture Filter", ["Off", "Bilinear"], Settings.texture_filter, Settings.set_texture_filter)
	var crt := choice_row(column, "CRT Filter", ["Off", "On"], int(Settings.crt), func(index: int) -> void: Settings.set_crt(index == 1))
	var curve_row := volume_row(column, "Curvature", Settings.crt_curve, Settings.set_crt_curve).get_parent() as Control
	curve_row.visible = Settings.crt
	crt.item_selected.connect(func(index: int) -> void: curve_row.visible = index == 1)
	return focus


static func section_header(column: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title.to_upper()
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", CORAL)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(label)


static func volume_row(column: VBoxContainer, title: String, value: int, apply: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_FILL
	column.add_child(row)
	var name := Label.new()
	name.text = title
	name.custom_minimum_size = Vector2(OPTION_LABEL_W, 0)
	name.add_theme_font_size_override("font_size", 26)
	row.add_child(name)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.scrollable = false
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(360, 32)
	var amount := Label.new()
	amount.custom_minimum_size = Vector2(56, 0)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_font_size_override("font_size", 26)
	amount.text = str(value)
	slider.value_changed.connect(func(next: float) -> void:
		apply.call(int(next))
		amount.text = str(int(next))
	)
	row.add_child(slider)
	row.add_child(amount)
	return slider


static func choice_row(column: VBoxContainer, title: String, items: Array, selected: int, apply: Callable) -> OptionButton:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_FILL
	column.add_child(row)
	var name := Label.new()
	name.text = title
	name.custom_minimum_size = Vector2(OPTION_LABEL_W, 0)
	name.add_theme_font_size_override("font_size", 26)
	row.add_child(name)
	var button := OptionButton.new()
	for item in items:
		button.add_item(item)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(360, 48)
	button.add_theme_font_size_override("font_size", 26)
	button.select(selected)
	button.item_selected.connect(apply)
	row.add_child(button)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(56, 0)
	row.add_child(spacer)
	return button


static func lock_focus(controls: Array) -> void:
	var shown: Array[Control] = []
	for item in controls:
		var control := item as Control
		if control.visible:
			shown.append(control)
	for i in shown.size():
		var current := shown[i]
		var previous := shown[(i + shown.size() - 1) % shown.size()]
		var next := shown[(i + 1) % shown.size()]
		var here := current.get_path()
		current.focus_neighbor_left = previous.get_path()
		current.focus_neighbor_right = next.get_path()
		current.focus_neighbor_top = here
		current.focus_neighbor_bottom = here
		current.focus_next = next.get_path()
		current.focus_previous = previous.get_path()


static func hook_button(button: Button) -> void:
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.mouse_entered.connect(func() -> void: pop(button, 1.05))
	button.mouse_exited.connect(func() -> void: pop(button, 1.03 if button.has_focus() else 1.0))
	button.focus_entered.connect(func() -> void: pop(button, 1.05 if button.is_hovered() else 1.03))
	button.focus_exited.connect(func() -> void: pop(button, 1.05 if button.is_hovered() else 1.0))
	button.button_down.connect(func() -> void: pop(button, 0.96))
	button.button_up.connect(func() -> void: pop(button, rest_scale(button)))


static func pop(control: Control, scale: float) -> void:
	kill_meta(control, "pop")
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	control.set_meta("pop", tween)
	tween.tween_property(control, "scale", Vector2(scale, scale), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func punch(control: Control) -> void:
	kill_meta(control, "pop")
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(1.08, 1.08)
	var tween := control.create_tween()
	control.set_meta("pop", tween)
	tween.tween_property(control, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func animate_in(shell: Control, content: Control) -> void:
	var token := int(shell.get_meta("anim_token", 0)) + 1
	shell.set_meta("anim_token", token)
	shell.set_meta("anim_waits", 0)
	kill_motion(shell)
	kill_meta(shell, "page_tween")
	shell.visible = true
	shell.modulate.a = 0.0
	shell.scale = Vector2.ONE
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	for child in content.get_children():
		if child is CanvasItem:
			child.modulate.a = 0.0
	shell.get_tree().create_timer(0.016, true, true).timeout.connect(func() -> void: begin_in(shell, content, token), CONNECT_ONE_SHOT)


static func animate_out(shell: Control) -> void:
	var token := int(shell.get_meta("anim_token", 0)) + 1
	shell.set_meta("anim_token", token)
	kill_motion(shell)
	kill_meta(shell, "page_tween")
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.pivot_offset = shell.size * 0.5
	var tween := shell.create_tween()
	shell.set_meta("page_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(shell, "modulate:a", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(shell, "scale", Vector2(0.98, 0.95), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		if int(shell.get_meta("anim_token", 0)) != token:
			return
		shell.visible = false
		shell.modulate.a = 1.0
		shell.scale = Vector2.ONE
		shell.mouse_filter = Control.MOUSE_FILTER_STOP
		reset_look(shell)
	)


static func begin_in(shell: Control, content: Control, token: int) -> void:
	if int(shell.get_meta("anim_token", 0)) != token:
		return
	if shell.size.x <= 1.0 and int(shell.get_meta("anim_waits", 0)) < 10:
		shell.set_meta("anim_waits", int(shell.get_meta("anim_waits", 0)) + 1)
		shell.get_tree().create_timer(0.016, true, true).timeout.connect(func() -> void: begin_in(shell, content, token), CONNECT_ONE_SHOT)
		return
	shell.pivot_offset = shell.size * 0.5
	shell.scale = Vector2(0.94, 0.92)
	var tween := shell.create_tween()
	shell.set_meta("page_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(shell, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(shell, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var delay := 0.02
	for child in content.get_children():
		if not child is CanvasItem:
			continue
		if not child.visible:
			child.modulate.a = 1.0
			continue
		var fade := child.create_tween()
		child.set_meta("fade", fade)
		fade.tween_property(child, "modulate:a", 1.0, 0.2).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if child is Button:
			kill_meta(child, "pop")
			child.pivot_offset = child.size * 0.5
			child.scale = Vector2(0.9, 0.9)
			var pop_tween := child.create_tween()
			child.set_meta("pop", pop_tween)
			var target := 1.03 if child.has_focus() else 1.0
			pop_tween.tween_property(child, "scale", Vector2(target, target), 0.3).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		wipe_rule(child, delay)
		delay += 0.045


static func wipe_rule(node: Node, delay: float) -> void:
	var targets: Array[Node] = [node]
	if node is Container:
		for child in node.get_children():
			targets.append(child)
	for target in targets:
		if not target.has_meta("rule") or not target is Control:
			continue
		var rule := target as Control
		rule.pivot_offset = rule.size * 0.5
		rule.scale = Vector2(0.0, 1.0)
		var tween := rule.create_tween()
		rule.set_meta("fade", tween)
		tween.tween_property(rule, "scale:x", 1.0, 0.28).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func rest_scale(button: Button) -> float:
	if button.is_hovered():
		return 1.05
	if button.has_focus():
		return 1.03
	return 1.0


static func kill_meta(node: Node, key: String) -> void:
	if not node.has_meta(key):
		return
	(node.get_meta(key) as Tween).kill()


static func kill_motion(node: Node) -> void:
	kill_meta(node, "pop")
	kill_meta(node, "fade")
	for child in node.get_children():
		if child is Control:
			kill_motion(child)


static func reset_look(node: Node) -> void:
	for child in node.get_children():
		if not child is Control:
			continue
		child.modulate.a = 1.0
		child.scale = Vector2.ONE
		reset_look(child)


static func checkbox_icon(on: bool) -> ImageTexture:
	var image := Image.create(22, 22, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(0, 0, 22, 22), ACCENT)
	image.fill_rect(Rect2i(3, 3, 16, 16), Color(0.1, 0.02, 0.05, 0.95))
	if on:
		image.fill_rect(Rect2i(6, 6, 10, 10), CREAM)
	return ImageTexture.create_from_image(image)


static func grabber(color: Color, size := Vector2i(8, 22), border := 0) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(ACCENT)
	image.fill_rect(Rect2i(Vector2i(border, border), size - Vector2i(border, border) * 2), color)
	return ImageTexture.create_from_image(image)
