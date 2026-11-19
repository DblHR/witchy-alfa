@tool
extends Line2D
class_name HomeRoute
## Маршрут по дому, по которому ходят персонажи (Hub.tscn → Routes). Точки линии — путь, по нему
## ходят туда-сюда. Если конец одной линии рядом с концом другой (ближе JOIN_DIST px), дойдя до
## него, персонаж может перейти на другую линию. В игре линии не видно, в редакторе — видно:
## двигайте точки мышкой. Координаты — экран 1920×1080, точка = где стоят ноги.

## Слой: 0 — за котлом (верхняя дуга вокруг котла, второй этаж, кровать), 1 — перед котлом.
@export_enum("За котлом:0", "Перед котлом:1") var layer: int = 1
## "bed" — кровать: на неё запрыгивают с начала линии (первая точка), в конце (последняя точка)
## делают своё действие (HomeWalker.BED_ACTIONS: прыгать / лежать).
@export var action: String = ""

const JOIN_DIST := 30.0

var _pts := PackedVector2Array()
var _cum := PackedFloat32Array()

func _ready() -> void:
	width = 6.0
	default_color = Color(0.2, 1.0, 0.4, 0.8) if action == "" else Color(0.3, 0.5, 1.0, 0.9)
	if not Engine.is_editor_hint():
		visible = false
	rebuild()

## Пересчитать точки в координатах экрана (если линию двигали).
func rebuild() -> void:
	_pts = PackedVector2Array()
	_cum = PackedFloat32Array()
	var acc := 0.0
	for i in range(points.size()):
		var p := to_global(points[i]) if is_inside_tree() else position + points[i]
		if i > 0:
			acc += p.distance_to(_pts[i - 1])
		_pts.append(p)
		_cum.append(acc)

func length() -> float:
	return _cum[_cum.size() - 1] if _cum.size() > 0 else 0.0

func start_point() -> Vector2:
	return _pts[0]

func end_point() -> Vector2:
	return _pts[_pts.size() - 1]

## Точка на расстоянии d от начала линии.
func point_at(d: float) -> Vector2:
	if _pts.size() < 2:
		return _pts[0] if _pts.size() == 1 else Vector2.ZERO
	d = clampf(d, 0.0, length())
	for i in range(1, _pts.size()):
		if d <= _cum[i] or i == _pts.size() - 1:
			var seg := _cum[i] - _cum[i - 1]
			var t := 0.0 if seg <= 0.001 else (d - _cum[i - 1]) / seg
			return _pts[i - 1].lerp(_pts[i], clampf(t, 0.0, 1.0))
	return _pts[_pts.size() - 1]

## Ближайшая точка линии к p: {"d": расстояние вдоль линии, "dist": расстояние до p}.
func nearest(p: Vector2) -> Dictionary:
	var best_d := 0.0
	var best := INF
	for i in range(1, _pts.size()):
		var a := _pts[i - 1]
		var b := _pts[i]
		var ab := b - a
		var len2 := ab.length_squared()
		var t := 0.0 if len2 <= 0.001 else clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		var q := a + ab * t
		var dd := q.distance_to(p)
		if dd < best:
			best = dd
			best_d = _cum[i - 1] + t * sqrt(len2)
	return {"d": best_d, "dist": best}
