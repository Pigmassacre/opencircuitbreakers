class_name HudTheme
extends RefCounted

const TEXT_COLOR := Color(0.96, 0.96, 0.96)


static func font() -> Font:
	var system_font := SystemFont.new()
	system_font.font_names = PackedStringArray(["Arial Black", "Impact", "DejaVu Sans", "sans-serif"])
	system_font.font_weight = 900
	system_font.font_italic = true
	return system_font


static func theme() -> Theme:
	var theme := Theme.new()
	var face := font()
	theme.default_font = face
	theme.default_font_size = 22
	theme.set_font("font", "Label", face)
	theme.set_color("font_color", "Label", TEXT_COLOR)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	theme.set_constant("outline_size", "Label", 8)
	theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.6))
	theme.set_constant("shadow_outline_size", "Label", 8)
	theme.set_constant("shadow_offset_x", "Label", 3)
	theme.set_constant("shadow_offset_y", "Label", 3)
	return theme
