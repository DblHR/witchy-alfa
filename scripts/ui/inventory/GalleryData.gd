class_name GalleryData
extends RefCounted
## Данные галереи: data/gallery/gallery.json (категории «Персонажи» и «События»).
## У категории с полем character картинки собираются сами: портрет, боевой спрайт
## и всё из assets/pics/cards/art/<id>/ — новые рисунки карт появятся в галерее без правок.

const FILE := "res://data/gallery/gallery.json"
const CARD_ART_DIR := "res://assets/pics/cards/art/%s"
const IMAGE_EXT := ["png", "jpg", "jpeg", "webp"]

## group: "characters" | "events". Возвращает [{id, title, icon_path, images: Array[String]}].
static func categories(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(FILE):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (parsed is Dictionary):
		push_warning("GalleryData: не удалось прочитать %s" % FILE)
		return out
	for raw in parsed.get(group, []):
		if not (raw is Dictionary):
			continue
		var images: Array[String] = []
		var char_id := String(raw.get("character", ""))
		var icon_path := String(raw.get("icon", ""))
		if char_id != "":
			var cd: CharacterData = CharDB.get_by_id(char_id) if CharDB != null else null
			if cd != null:
				for tex in [cd.card_portrait, cd.battle_texture]:
					if tex != null and tex.resource_path != "":
						images.append(tex.resource_path)
				if icon_path == "" and cd.battle_texture != null:
					icon_path = cd.battle_texture.resource_path
			images.append_array(_images_in(CARD_ART_DIR % char_id))
		for p in raw.get("images", []):
			var path := String(p)
			if path != "" and ResourceLoader.exists(path) and not images.has(path):
				images.append(path)
		if images.is_empty():
			continue
		if icon_path == "":
			icon_path = images[0]
		out.append({"id": String(raw.get("id", "")), "title": String(raw.get("title", "")), "icon_path": icon_path, "images": images})
	return out

## Картинки в папке (в экспорте вместо .png лежат .png.import — учитываем и их).
static func _images_in(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	for f in DirAccess.get_files_at(dir_path):
		var fname := f.trim_suffix(".import").trim_suffix(".remap")
		if not IMAGE_EXT.has(fname.get_extension().to_lower()):
			continue
		var path := dir_path.path_join(fname)
		if not out.has(path) and ResourceLoader.exists(path):
			out.append(path)
	out.sort()
	return out
