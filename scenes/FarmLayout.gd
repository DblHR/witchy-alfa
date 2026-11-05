extends RefCounted
class_name FarmLayout
## Раскладка горшков на ферме. Всё, что нужно двигать руками, лежит здесь.
##
## anchor     — точка на экране (1920x1080), куда попадает «точка роста» горшка
##              (место, откуда растёт стебель, у верхнего края горшка).
## scale      — масштаб текстуры горшка.
## plant_mult — множитель размера растения относительно горшка (дальние/маленькие горшки — меньше).
## bag_t      — на какой высоте мешочек между ободком (0) и дном (1); для горшков, нижнюю часть которых
##              закрывает стол или табурет, ставим выше.
## shadow     — рисовать ли тень на полу под горшком (для горшков, стоящих на полу).
##
## Горшки нарисованы снизу вверх, поэтому растение рисуется ПОЗАДИ горшка и растёт из-за ободка.

const SLOTS := [
	{"anchor": Vector2(250, 78),   "scale": 0.88,  "plant_mult": 0.30, "shadow": false, "bag_t": 0.40},
	{"anchor": Vector2(440, 152),  "scale": 0.978, "plant_mult": 0.50, "shadow": false, "bag_t": 0.15},
	{"anchor": Vector2(104, 832),  "scale": 0.666, "plant_mult": 1.00, "shadow": true,  "bag_t": 0.55},
	{"anchor": Vector2(479, 805),  "scale": 0.834, "plant_mult": 1.00, "shadow": true,  "bag_t": 0.55},
	{"anchor": Vector2(712, 909),  "scale": 0.660, "plant_mult": 1.00, "shadow": true,  "bag_t": 0.55},
	{"anchor": Vector2(1777, 835), "scale": 0.901, "plant_mult": 1.00, "shadow": false, "bag_t": 0.55},
	{"anchor": Vector2(1818, 361), "scale": 0.564, "plant_mult": 0.75, "shadow": false, "bag_t": 0.22},
	{"anchor": Vector2(1538, 374), "scale": 0.688, "plant_mult": 0.85, "shadow": false, "bag_t": 0.55},
]

## Точка роста в пикселях текстуры горшка (где стебель выходит из-за ободка).
const POT_ANCHOR := [
	Vector2(120, 22),   # pot1
	Vector2(140, 38),   # pot2
	Vector2(180, 38),   # pot3
	Vector2(180, 38),   # pot4
	Vector2(180, 100),  # pot5
	Vector2(260, 85),   # pot6 (стеклянная банка, верх за кадром)
	Vector2(190, 70),   # pot7
	Vector2(178, 132),  # pot8
]

## Видимая часть текстуры горшка (без прозрачных полей): x, y, w, h в пикселях текстуры.
const POT_BBOX := [
	Rect2(5, 3, 229, 245),
	Rect2(7, 5, 255, 241),
	Rect2(23, 22, 315, 354),
	Rect2(23, 22, 315, 354),
	Rect2(33, 88, 290, 215),
	Rect2(9, 11, 407, 332),
	Rect2(22, 48, 313, 295),
	Rect2(78, 115, 200, 161),
]

static func slot(i: int) -> Dictionary:
	return SLOTS[clampi(i, 0, SLOTS.size() - 1)]

static func anchor(i: int) -> Vector2:
	return POT_ANCHOR[clampi(i, 0, POT_ANCHOR.size() - 1)]

static func bbox(i: int) -> Rect2:
	return POT_BBOX[clampi(i, 0, POT_BBOX.size() - 1)]
