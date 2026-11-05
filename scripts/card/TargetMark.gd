extends Control
## Выделение цели: стрелка над головой (кольцо под ногами — TargetRing, под спрайтом).
## Размер контрола = рамка персонажа; рисуется только внутри неё.

## Цвет стрелки (тот же, что у кольца): враги — красные, союзники — зелёные.
var color := Color(1.0, 0.32, 0.30, 1.0)
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	# Стрелка над головой, чуть покачивается.
	var bob := sin(_t * 5.0) * 5.0
	var line := color
	line.a = 0.65 + 0.35 * pulse
	var tip := Vector2(size.x * 0.5, 22.0 + bob)
	var tri := PackedVector2Array([tip, tip + Vector2(-16, -22), tip + Vector2(16, -22)])
	draw_colored_polygon(tri, line)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), color.darkened(0.8), 2.0, true)
