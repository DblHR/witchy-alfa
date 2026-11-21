@tool
extends Polygon2D
class_name WitchZone
## Хитбокс ведьмочки на ферме (Farm.tscn → World/WitchZones). Клик внутри многоугольника —
## ведьмочка на duration секунд меняет спрайт на sprite (assets/farm/background/<sprite>.png),
## потом возвращается к witch.png. Новый клик прерывает прошлую реакцию.
## Точки многоугольника двигаются в редакторе (инструмент Polygon2D). В игре зону не видно.
## Если зоны перекрываются — срабатывает та, что выше в списке узлов.

@export_enum("witch_face", "witch_breasts", "witch_butt") var sprite: String = "witch_face"
## Сколько секунд держать спрайт.
@export var duration: float = 2.0

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false

func has_global_point(p: Vector2) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(get_global_transform().affine_inverse() * p, polygon)
