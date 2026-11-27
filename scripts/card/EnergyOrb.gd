extends Control
class_name EnergyOrb
## Энергия хода в бою (CardBattle.tscn → UI/Hud/EnergyOrb): жёлтый кругляшок, по кругу — ячейки
## энергии (как деления заряда у кнопок ульт), в середине — «текущая/макс».
## CardBattle зовёт set_energy(текущая, максимум).

@export var fill_color := Color(1.0, 0.82, 0.25)        ## полная ячейка
@export var empty_color := Color(0.22, 0.16, 0.10, 0.9) ## пустая ячейка
@export var core_color := Color(1.0, 0.9, 0.45)         ## середина
@export var back_color := Color(0.08, 0.05, 0.12, 0.88) ## подложка
@export var ring_width := 10.0
@export var gap_deg := 7.0                             ## промежуток между ячейками

var current := 3
var maximum := 3
var _label: Label
var _pulse := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Value"
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(0.25, 0.12, 0.02))
	_label.add_theme_color_override("font_outline_color", Color(1.0, 0.97, 0.8))
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_refresh()

func set_energy(cur: int, mx: int) -> void:
	if cur < current:
		_pulse = 1.0   ## потратили — короткая вспышка
	current = cur
	maximum = mx
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	_label.text = "%d/%d" % [current, maximum]
	queue_redraw()

func _process(delta: float) -> void:
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 3.0)
		queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - ring_width * 0.5 - 1.0
	draw_circle(c, r + ring_width * 0.5, back_color)
	draw_circle(c, r - ring_width * 0.5 - 3.0, core_color.lerp(Color.WHITE, _pulse * 0.5))
	var n := maxi(1, maximum)
	var gap := deg_to_rad(gap_deg) if n > 1 else 0.0
	for i in n:
		var a0 := -PI * 0.5 + TAU * float(i) / float(n) + gap * 0.5
		var a1 := -PI * 0.5 + TAU * float(i + 1) / float(n) - gap * 0.5
		var col := fill_color if i < current else empty_color
		draw_arc(c, r, a0, a1, 24, col, ring_width, true)
