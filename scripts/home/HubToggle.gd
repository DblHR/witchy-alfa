extends Control
class_name HubToggle
## Предмет в доме, который кликом включается / выключается (тыква-котик, камин) — Hub.tscn.
## Узлы внутри:
##   On  — картинка «включено» (плавно проявляется / гаснет);
##   Off — картинка «выключено» (необязательно: у камина «выключенный» нарисован на фоне);
##   Hit — необязательный многоугольник (Polygon2D), где можно кликнуть. Без него кликается
##         непрозрачная часть картинки Off (или On). В игре Hit не видно, в редакторе — видно.
## Двигать предмет — двигать сам узел. Включено / выключено — помнится, пока игра запущена.

## Включено при первом заходе.
@export var is_on := true
## За сколько секунд проявляется / гаснет.
@export var fade_time := 0.3

static var _states: Dictionary = {}   ## имя узла -> включено ли
static var _images: Dictionary = {}   ## текстура -> Image (проверка прозрачности)

var _tween: Tween
@onready var on_node: TextureRect = get_node_or_null("On") as TextureRect
@onready var off_node: TextureRect = get_node_or_null("Off") as TextureRect
@onready var hit_node: Polygon2D = get_node_or_null("Hit") as Polygon2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _states.has(String(name)):
		is_on = bool(_states[String(name)])
	if hit_node != null:
		hit_node.visible = false
	_apply(false)

func toggle() -> void:
	is_on = not is_on
	_states[String(name)] = is_on
	_apply(true)
	# Чуть «подпрыгивает» от клика.
	pivot_offset = size * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 0.95), 0.06)
	tw.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _apply(animated: bool) -> void:
	var a := 1.0 if is_on else 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not animated:
		if on_node != null:
			on_node.modulate.a = a
		if off_node != null:
			off_node.modulate.a = 1.0 - a
		return
	_tween = create_tween().set_parallel(true)
	if on_node != null:
		_tween.tween_property(on_node, "modulate:a", a, fade_time)
	if off_node != null:
		_tween.tween_property(off_node, "modulate:a", 1.0 - a, fade_time)

## Попадает ли точка экрана p в предмет.
func hit(p: Vector2) -> bool:
	if not is_visible_in_tree():
		return false
	if hit_node != null and hit_node.polygon.size() >= 3:
		return Geometry2D.is_point_in_polygon(hit_node.get_global_transform().affine_inverse() * p, hit_node.polygon)
	var tr := off_node if off_node != null else on_node
	if tr == null or tr.texture == null:
		return false
	var img: Image = _images.get(tr.texture, null)
	if img == null:
		img = tr.texture.get_image()
		if img == null:
			return false
		if img.is_compressed():
			img.decompress()
		_images[tr.texture] = img
	var lp := tr.get_global_transform().affine_inverse() * p
	var k := Vector2(img.get_width() / maxf(1.0, tr.size.x), img.get_height() / maxf(1.0, tr.size.y))
	var px := Vector2i(int(lp.x * k.x), int(lp.y * k.y))
	if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
		return false
	return img.get_pixelv(px).a > 0.5
