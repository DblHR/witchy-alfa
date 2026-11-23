extends RefCounted
class_name ChibiShadow
## Тень под чибиком (assets/items/shadow.png) — в бою (BattleActor) и на подготовке (TeamSlot).
## В доме теней нет.
##
## Ширина — от видимой части картинки персонажа: у высоких — не шире ~60% роста, у круглых
## (слизни) — почти во всю ширину. Центр — под серединой фигуры, на линии ног.

const TEXTURE := "res://assets/items/shadow.png"
## Насколько тень шире/уже фигуры и прозрачность.
const WIDTH_K := 0.9
const TALL_MAX_K := 0.62
const ALPHA := 0.8
## На сколько (доля высоты тени) тень поднята над линией ног.
const LIFT := 0.25

static var _tex: Texture2D
static var _feet_cache: Dictionary = {}
## Нижняя часть фигуры (доля высоты), по которой ищется середина ног: оружие и волосы не сдвигают тень.
const FEET_BAND := 0.12

## Середина ног по X (пиксели картинки): средняя непрозрачная точка в нижней полосе фигуры.
static func feet_center_x(tex: Texture2D) -> float:
	if tex == null:
		return 0.0
	if _feet_cache.has(tex):
		return float(_feet_cache[tex])
	var r := CharSizes.used_rect(tex)
	var cx := float(r.position.x) + float(r.size.x) * 0.5
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var y0 := r.position.y + int(float(r.size.y) * (1.0 - FEET_BAND))
		var sum := 0.0
		var n := 0
		for y in range(y0, r.position.y + r.size.y, 3):
			for x in range(r.position.x, r.position.x + r.size.x, 3):
				if img.get_pixel(x, y).a > 0.5:
					sum += x
					n += 1
		if n > 0:
			cx = sum / n
	_feet_cache[tex] = cx
	return cx


static func texture() -> Texture2D:
	if _tex == null and ResourceLoader.exists(TEXTURE):
		_tex = load(TEXTURE) as Texture2D
	return _tex

## Новая тень (Sprite2D по центру). Добавить в родителя самому — позади персонажа.
static func make() -> Sprite2D:
	var s := Sprite2D.new()
	s.name = "Shadow"
	s.texture = texture()
	s.modulate = Color(1, 1, 1, ALPHA)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return s

## Ширина тени в пикселях экрана для картинки tex при масштабе k.
static func width_for(tex: Texture2D, k: float) -> float:
	var r := CharSizes.used_rect(tex)
	var w := float(r.size.x)
	var h := float(r.size.y)
	var base := w * 0.85 if w >= h * 0.9 else minf(w, h * TALL_MAX_K)
	return base * k * WIDTH_K

## Поставить тень: feet — точка ног (координаты родителя), width — ширина.
static func place(shadow: Sprite2D, feet: Vector2, width: float) -> void:
	var t := shadow.texture
	if t == null:
		shadow.visible = false
		return
	var sc := width / float(t.get_width())
	shadow.scale = Vector2(sc, sc)
	shadow.position = feet - Vector2(0, float(t.get_height()) * sc * LIFT)
