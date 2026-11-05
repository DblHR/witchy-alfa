extends RefCounted
class_name UIThemeHelper

static func build_pink_theme() -> Theme:
	var theme := Theme.new()

	var tooltip_panel := StyleBoxFlat.new()
	tooltip_panel.bg_color = Color(0.46, 0.22, 0.34, 0.94)
	tooltip_panel.border_color = Color(0.98, 0.88, 0.94, 0.96)
	tooltip_panel.border_width_left = 2
	tooltip_panel.border_width_top = 2
	tooltip_panel.border_width_right = 2
	tooltip_panel.border_width_bottom = 2
	tooltip_panel.corner_radius_top_left = 10
	tooltip_panel.corner_radius_top_right = 10
	tooltip_panel.corner_radius_bottom_left = 10
	tooltip_panel.corner_radius_bottom_right = 10
	tooltip_panel.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	tooltip_panel.shadow_size = 4
	theme.set_stylebox("panel", "TooltipPanel", tooltip_panel)
	theme.set_color("font_color", "TooltipLabel", Color(1.0, 0.96, 0.98, 1.0))
	theme.set_color("font_outline_color", "TooltipLabel", Color(0.22, 0.08, 0.14, 1.0))
	theme.set_constant("outline_size", "TooltipLabel", 3)

	var button_normal := StyleBoxFlat.new()
	button_normal.bg_color = Color(0.47, 0.27, 0.38, 0.90)
	button_normal.border_color = Color(0.95, 0.84, 0.91, 0.95)
	button_normal.border_width_left = 2
	button_normal.border_width_top = 2
	button_normal.border_width_right = 2
	button_normal.border_width_bottom = 2
	button_normal.corner_radius_top_left = 12
	button_normal.corner_radius_top_right = 12
	button_normal.corner_radius_bottom_left = 12
	button_normal.corner_radius_bottom_right = 12
	button_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	button_normal.shadow_size = 3

	var button_hover := button_normal.duplicate() as StyleBoxFlat
	button_hover.bg_color = Color(0.57, 0.31, 0.46, 0.96)

	var button_pressed := button_normal.duplicate() as StyleBoxFlat
	button_pressed.bg_color = Color(0.67, 0.38, 0.53, 0.98)

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("disabled", "Button", button_normal)
	theme.set_color("font_color", "Button", Color(1.0, 0.97, 0.98, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.82, 0.76, 0.80, 1.0))
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 1.0, 1.0))
	theme.set_color("font_outline_color", "Button", Color(0.20, 0.08, 0.12, 1.0))
	theme.set_constant("outline_size", "Button", 3)
	return theme

static func apply_pink_theme(control: Control) -> void:
	if control == null:
		return
	control.theme = build_pink_theme()
