extends Node2D
## Кольцо выделения цели под ногами персонажа. Живёт первым ребёнком актёра,
## поэтому рисуется ПОД спрайтом, а не поверх него.
## Цвет задаёт CardBattle: враги — красные, союзники — зелёные.

const COLOR_ENEMY := Color(1.0, 0.32, 0.30, 1.0)
const COLOR_ALLY := Color(0.42, 1.0, 0.50, 1.0)

var radius := 90.0
var color := COLOR_ENEMY
var _t := 0.0

func _ready() -> void:
	set_process(false)

func show_ring(rx: float, ring_color: Color = COLOR_ENEMY) -> void:
	radius = rx
	color = ring_color
	visible = true
	set_process(true)

func hide_ring() -> void:
	visible = false
	set_process(false)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _ellipse(rx: float, ry: float, n: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n + 1):
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	var col := color
	var fill := col
	fill.a = 0.12 + 0.10 * pulse
	draw_colored_polygon(_ellipse(radius, radius * 0.26), fill)
	var glow := col
	glow.a = 0.25
	draw_polyline(_ellipse(radius + 8.0, (radius + 8.0) * 0.26), glow, 8.0, true)
	var line := col
	line.a = 0.65 + 0.35 * pulse
	draw_polyline(_ellipse(radius, radius * 0.26), line, 4.0, true)
