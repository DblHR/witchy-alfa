@tool
extends Polygon2D
class_name WitchZone
## Хитбокс ведьмочки на ферме (Farm.tscn → World/WitchZones). Клик внутри многоугольника —
## ведьмочка на duration секунд меняет спрайт на sprite, потом возвращается к обычному.
## Новый клик прерывает прошлую реакцию. (Используется на ферме и в главном меню.)
## action — дополнительное действие зоны для сцены (например "heart" в главном меню).
## Точки многоугольника двигаются в редакторе (инструмент Polygon2D). В игре зону не видно.
## Если зоны перекрываются — срабатывает та, что выше в списке узлов.

## Какую картинку показать (имя файла без .png; папку задаёт сцена: ферма — assets/farm/background/,
## главное меню — assets/ui/menu/). Если такой картинки нет — спрайт не меняется.
@export var sprite: String = "witch_face"
## Сколько секунд держать спрайт.
@export var duration: float = 0.5
@export var action: String = ""

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false

func has_global_point(p: Vector2) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(get_global_transform().affine_inverse() * p, polygon)
