extends RefCounted
class_name VnPortraits
## Как ставить портреты в диалогах (VN). Рисунки героинь разного размера и с разными полями,
## поэтому портрет подгоняется по видимой части картинки (без прозрачных полей):
## голова — у верхней линии, фигура — на одну высоту, тело — по центру своего места.
##
## Для нового персонажа достаточно ничего не делать — сработают значения по умолчанию.
## Если выглядит мельче/крупнее остальных или стоит криво — добавьте строку в TUNING:
##   zoom    — крупнее (>1) или мельче (<1) остальных (у кого шляпа, уши, рога — им нужно >1,
##             иначе голова окажется меньше, чем у соседей);
##   focus_x — где центр тела по ширине картинки, 0..1 (оружие, хвосты и шляпы сдвигают центр);
##   top     — сдвиг вниз в пикселях (опустить, если макушка упирается в край);
##   color   — цвет плашки с именем (героини берут цвет своих карт сами).

## Высота видимой части портрета на экране 1920×1080 при zoom = 1.
const BASE_HEIGHT := 1060.0
## Отступ макушки от верха экрана.
const TOP_Y := 36.0

const TUNING := {
	"witch": {"zoom": 1.04, "focus_x": 0.54, "top": -20.0},
	"warrior": {"zoom": 1.0, "focus_x": 0.50},
	"aki": {"zoom": 1.06, "focus_x": 0.525},
	"luisa": {"zoom": 0.96, "focus_x": 0.49, "top": -50.0},
	"fufu": {"zoom": 1.16, "focus_x": 0.475, "top": -30.0},
	"rabbit_shop": {"zoom": 1.15, "focus_x": 0.50, "color": Color(0.86, 0.26, 0.30)},
	"nurse": {"zoom": 1.08, "focus_x": 0.475, "color": Color(0.90, 0.45, 0.70)},
	"lamia": {"zoom": 1.18, "focus_x": 0.47, "color": Color(0.80, 0.62, 0.20)},
	"statue_white": {"zoom": 0.92, "color": Color(0.62, 0.62, 0.70)},
	"statue_black": {"zoom": 0.92, "color": Color(0.30, 0.26, 0.36)},
	"chest": {"color": Color(0.72, 0.50, 0.16)},
	"slime": {"zoom": 0.42, "top": 430.0, "color": Color(0.42, 0.72, 0.28)},   ## обучение: маленький спрайт, стоит «на полу»
}
const DEFAULT_COLOR := Color(0.55, 0.30, 0.48)

static var _rect_cache: Dictionary = {}

static func tuning(id: String) -> Dictionary:
	return TUNING.get(id, {})

## Цвет плашки имени: из TUNING, иначе цвет карт героини, иначе общий.
static func name_color(id: String) -> Color:
	var t := tuning(id)
	if t.has("color"):
		return t["color"]
	if CharDB != null and id != "":
		var cd: CharacterData = CharDB.get_by_id(id)
		if cd != null:
			return cd.card_color
	return DEFAULT_COLOR

## Видимая часть текстуры (без прозрачных полей), в пикселях текстуры.
static func used_rect(tex: Texture2D) -> Rect2:
	if tex == null:
		return Rect2()
	var key := tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _rect_cache.has(key):
		return _rect_cache[key]
	var full := Rect2(Vector2.ZERO, tex.get_size())
	var out := full
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var r := img.get_used_rect()
		if r.size.x > 0 and r.size.y > 0:
			out = Rect2(r)
	_rect_cache[key] = out
	return out

## Картинка без прозрачных полей во весь кадр (сундук на фоне): это «картинка», а не персонаж.
static func is_picture(tex: Texture2D) -> bool:
	var r := used_rect(tex)
	var s := tex.get_size()
	return r.size.x >= s.x * 0.98 and r.size.y >= s.y * 0.98 and s.x > s.y * 1.3

## Куда поставить портрет: {scale, position, pivot}. center_x — центр места на экране,
## shrink — общий множитель (когда на экране трое, все чуть мельче).
static func layout(id: String, tex: Texture2D, center_x: float, shrink: float = 1.0) -> Dictionary:
	var size := tex.get_size()
	if is_picture(tex):
		var k := minf(820.0 / size.x, 520.0 / size.y) * shrink
		return {"scale": k, "position": Vector2(center_x - size.x * k * 0.5, 150.0), "pivot": size * k * 0.5, "picture": true}
	var t := tuning(id)
	var r := used_rect(tex)
	var k2 := BASE_HEIGHT * float(t.get("zoom", 1.0)) * shrink / maxf(r.size.y, 1.0)
	var focus := float(t.get("focus_x", (r.position.x + r.size.x * 0.5) / maxf(size.x, 1.0)))
	var pos := Vector2(center_x - focus * size.x * k2, TOP_Y + float(t.get("top", 0.0)) - r.position.y * k2)
	return {"scale": k2, "position": pos, "pivot": Vector2(focus * size.x * k2, (r.position.y + r.size.y * 0.45) * k2), "picture": false}
