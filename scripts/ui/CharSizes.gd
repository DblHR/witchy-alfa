extends RefCounted
class_name CharSizes
## Размер персонажей-чибиков (дом, экран подготовки): data/characters/sizes.json, id -> множитель роста.

const PATH := "res://data/characters/sizes.json"
static var _table: Dictionary = {}
static var _loaded := false

static func scale_of(unit_id: String) -> float:
	if not _loaded:
		_loaded = true
		var txt := FileAccess.get_file_as_string(PATH)
		var parsed = JSON.parse_string(txt) if txt != "" else null
		if parsed is Dictionary:
			for k in parsed:
				if String(k).begins_with("_"):
					continue
				var v = parsed[k]
				if v is float or v is int:
					_table[String(k)] = float(v)
		elif txt != "":
			push_warning("sizes.json: не удалось прочитать (лишняя запятая?)")
	return clampf(float(_table.get(unit_id, 1.0)), 0.3, 3.0)

## Где у картинки ноги и макушка (по непрозрачным пикселям) — для одинакового роста разных картинок.
static var _bbox_cache: Dictionary = {}
static func used_rect(tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i()
	if _bbox_cache.has(tex):
		return _bbox_cache[tex]
	var r := Rect2i(0, 0, tex.get_width(), tex.get_height())
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		r = img.get_used_rect()
	_bbox_cache[tex] = r
	return r
