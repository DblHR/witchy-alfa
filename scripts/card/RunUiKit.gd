extends RefCounted
class_name RunUiKit
## Мелкие помощники для окон забега (добыча, выбор пути, ивенты): стиль и быстрые виджеты.

const PANEL_BG := Color(0.10, 0.07, 0.17, 0.94)
const PANEL_BORDER := Color(0.95, 0.45, 0.78, 1.0)
const TEXT_DIM := Color(0.82, 0.78, 0.90, 1.0)
const GOLD := Color(1.0, 0.88, 0.40, 1.0)

static func panel_style(radius: int = 18) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	return sb

static func make_panel(pos: Vector2, panel_size: Vector2) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = panel_size
	p.add_theme_stylebox_override("panel", panel_style())
	return p

static func make_label(text: String, font_size: int, color: Color = Color.WHITE, centered: bool = true, wrap: bool = false) -> Label:
	var l := Label.new()
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 5)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func make_button(text: String, min_size: Vector2, font_size: int = 26) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

## Кнопка-карточка: внутри вертикальный стек из переданных контролов (клики они не ловят).
static func make_option_button(min_size: Vector2, content: Array) -> Button:
	var b := Button.new()
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 14
	box.offset_bottom = -14
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override("separation", 10)
	for c in content:
		if c is Control:
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE if not (c is Button) else Control.MOUSE_FILTER_STOP
			box.add_child(c)
	b.add_child(box)
	return b

## Превью карты для окон (не интерактивное, увеличенное).
static func card_preview(card: CardInstance, zoom: float = 1.3) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = CardView.CARD_SIZE * zoom
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var v := CardView.new()
	v.setup(card, false)
	v.pivot_offset = Vector2.ZERO
	v.scale = Vector2.ONE * zoom
	holder.add_child(v)
	return holder
