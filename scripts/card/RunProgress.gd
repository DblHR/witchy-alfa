extends HBoxContainer
class_name RunProgress
## Полоса прогресса забега: кружки комнат, босс — красный квадрат.
## Закрашены комнаты до `current` (не включая), у `current` золотая рамка.
## Используется и постоянно сверху экрана, и в окне выбора пути.

func setup(total: int, current: int) -> void:
	for c in get_children():
		c.queue_free()
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 12)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(total):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(26, 26)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		var is_boss := i == total - 1
		sb.set_corner_radius_all(4 if is_boss else 13)
		if i < current:
			sb.bg_color = RunUiKit.PANEL_BORDER
		elif is_boss:
			sb.bg_color = Color(0.85, 0.25, 0.25, 1.0)
		else:
			sb.bg_color = Color(0.25, 0.20, 0.35, 1.0)
		if i == current:
			sb.border_color = RunUiKit.GOLD
			sb.set_border_width_all(3)
		dot.add_theme_stylebox_override("panel", sb)
		add_child(dot)
