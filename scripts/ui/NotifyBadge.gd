extends Control
class_name NotifyBadge
## Значок уведомления «!» в углу кнопки: красный кружок с белой обводкой, слегка подпрыгивает.
## NotifyBadge.attach(button, show) — повесить (или убрать) значок на кнопку.

const SIZE := 40.0
const FILL := Color(0.92, 0.18, 0.32)
const RING := Color(1.0, 0.97, 0.9)

var _t := 0.0
var _label: Label

static func attach(button: Control, show_it: bool) -> NotifyBadge:
	if button == null:
		return null
	var b := button.get_node_or_null("NotifyBadge") as NotifyBadge
	if b == null:
		b = NotifyBadge.new()
		b.name = "NotifyBadge"
		button.add_child(b)
	b.visible = show_it
	b._place()
	return b

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	size = Vector2(SIZE, SIZE)
	pivot_offset = size * 0.5
	_label = Label.new()
	_label.text = "!"
	_label.size = size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_color_override("font_outline_color", Color(0.35, 0.02, 0.1))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_place()

## Правый верхний угол кнопки, чуть наружу.
func _place() -> void:
	var p := get_parent() as Control
	if p == null:
		return
	position = Vector2(p.size.x - SIZE * 0.85, -SIZE * 0.1)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# Подпрыгивает раз в ~1.6 с, между прыжками стоит.
	var k := fmod(_t, 1.6)
	var hop := sin(clampf(k / 0.45, 0.0, 1.0) * PI)
	position.y = -SIZE * 0.1 - hop * 8.0
	scale = Vector2.ONE * (1.0 + 0.08 * hop)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	draw_circle(c + Vector2(0, 2), SIZE * 0.5, Color(0, 0, 0, 0.35))
	draw_circle(c, SIZE * 0.5, RING)
	draw_circle(c, SIZE * 0.5 - 3.0, FILL)
