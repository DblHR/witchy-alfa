class_name CharacterBust
extends RefCounted
## Портрет «по бюст» для плиток героинь в инвентаре: из большой картинки (портрет из диалогов)
## вырезается верх фигуры — голова, плечи, грудь.
##
## Как режется: берётся непрозрачная часть картинки, сверху — HEIGHT её высоты; по ширине —
## так, чтобы вышло ASPECT (ширина/высота, как окошко в плитке), с центром на голове (середина
## непрозрачных пикселей в полосе на уровне лица — HEAD_BAND).
## Не нравится, как вырезалось у кого-то, — впишите прямоугольник вручную в OVERRIDES
## (в пикселях исходной картинки): "witch": Rect2(x, y, ширина, высота).

const HEIGHT := 0.5
const ASPECT := 1.3
const HEAD_BAND := Vector2(0.08, 0.3)    ## от и до, доли высоты фигуры
const OVERRIDES := {}

static var _cache: Dictionary = {}

static func texture(src: Texture2D, char_id: String = "") -> Texture2D:
	if src == null:
		return null
	var key := "%s|%s" % [src.resource_path, char_id]
	if _cache.has(key):
		return _cache[key]
	var region := _region(src, char_id)
	var out: Texture2D = src
	if region.has_area():
		var at := AtlasTexture.new()
		at.atlas = src
		at.region = region
		at.filter_clip = true
		out = at
	_cache[key] = out
	return out

static func _region(src: Texture2D, char_id: String) -> Rect2:
	if OVERRIDES.has(char_id):
		return OVERRIDES[char_id]
	var img := src.get_image()
	if img == null:
		return Rect2()
	if img.is_compressed():
		img.decompress()
	var used := img.get_used_rect()
	if not used.has_area():
		return Rect2()
	var fig_h := float(used.size.y)
	var h := fig_h * HEIGHT
	var w := minf(h * ASPECT, float(img.get_width()))
	h = w / ASPECT
	# Центр головы: средняя (медианная) колонка непрозрачных пикселей на уровне лица.
	var cols: Array[int] = []
	var y0 := used.position.y + int(fig_h * HEAD_BAND.x)
	var y1 := used.position.y + int(fig_h * HEAD_BAND.y)
	for y in range(y0, y1, 4):
		for x in range(used.position.x, used.end.x, 4):
			if img.get_pixel(x, y).a > 0.5:
				cols.append(x)
	var cx := float(used.get_center().x)
	if not cols.is_empty():
		cols.sort()
		cx = float(cols[floori(cols.size() * 0.5)])
	var x := clampf(cx - w * 0.5, 0.0, float(img.get_width()) - w)
	var y := maxf(0.0, used.position.y - fig_h * 0.02)
	return Rect2(x, y, w, h)
