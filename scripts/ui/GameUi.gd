extends RefCounted
class_name GameUi
## Общий вид окон игры (пауза, настройки…): кремовая панель со сливовой рамкой, как лавка Рикки,
## розовый заголовок, сливовые кнопки (ShopUi.style_button).

const PANEL_COLOR := Color(1.0, 0.955, 0.905, 0.98)
const BORDER_COLOR := Color(0.31, 0.15, 0.25)
const DIM_COLOR := Color(0.12, 0.05, 0.12, 0.55)
const SELECTED_COLOR := Color(0.78, 0.22, 0.52)

static func panel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_COLOR
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(4)
	sb.border_color = BORDER_COLOR
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 18
	sb.content_margin_left = 36
	sb.content_margin_right = 36
	sb.content_margin_top = 24
	sb.content_margin_bottom = 28
	return sb

static func style_panel(p: Control) -> void:
	p.add_theme_stylebox_override("panel", panel_box())

static func style_title(l: Label, font_px: int = 56) -> void:
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", ShopUi.TITLE_COLOR)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

static func style_text(l: Label, font_px: int = 24, alpha: float = 1.0) -> void:
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", Color(ShopUi.TEXT_COLOR, alpha))
	l.add_theme_constant_override("outline_size", 0)

static func style_button(b: Button, font_px: int = 28) -> void:
	ShopUi.style_button(b, font_px)
	b.focus_mode = Control.FOCUS_ALL   ## окна паузы листаются и с клавиатуры
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.set_corner_radius_all(16)
	focus.set_border_width_all(3)
	focus.border_color = Color(1.0, 0.75, 0.9)
	b.add_theme_stylebox_override("focus", focus)

## Кнопка-переключатель (выбран — розовая).
static func style_toggle(b: Button, font_px: int = 26) -> void:
	style_button(b, font_px)
	b.add_theme_stylebox_override("pressed", ShopUi._box(SELECTED_COLOR))
	b.add_theme_stylebox_override("hover_pressed", ShopUi._box(SELECTED_COLOR.lightened(0.1)))

static func style_slider(s: HSlider) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(ShopUi.PLUM, 0.35)
	track.set_corner_radius_all(8)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := StyleBoxFlat.new()
	fill.bg_color = SELECTED_COLOR
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)

static func separator() -> Control:
	var r := ColorRect.new()
	r.color = Color(BORDER_COLOR, 0.25)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
