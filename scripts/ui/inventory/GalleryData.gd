class_name GalleryData
extends RefCounted
## Данные галереи: data/gallery/gallery.json — какие картинки в каких разделах и когда они открыты.
##
## Раздел:   {"id", "title", "icon"?, "unlock"?, "image_unlock"?, "hint"?, "images": [...]}
## Картинка: "путь"  или  {"path": "путь", "unlock"?: {...}, "hint"?: "подсказка, пока закрыта"}
##   unlock        — условие открытия раздела (нет — открыт, как только открыта хоть одна картинка);
##   image_unlock  — условие для каждой картинки раздела, у которой нет своего unlock.
## Условия (все сразу):
##   "seen": true            — картинку уже показывали в игре (экран победы, встреча с NPC, сцена...)
##   "has_unit": "fufu"      — героиня есть в отряде
##   "trust": {"fufu": 3}    — уровень доверия не ниже
##   и любые условия диалогов: flag, not_flag, party_level_min, quest_completed, counter_min...
## Раздел с "character": "fufu" умеет собирать картинки сам ("auto": true): портрет, спрайт и всё
## из assets/characters/fufu/cards/ — но тогда нельзя выбрать, какие именно показывать.

const FILE := "res://data/gallery/gallery.json"
const CARD_ART_DIR := "res://assets/characters/%s/cards"
const IMAGE_EXT := ["png", "jpg", "jpeg", "webp"]
const SEEN_FLAG := "gallery_seen:"
## Админ: открыть всю галерею (флаг StoryState).
const UNLOCK_ALL_FLAG := "gallery_unlock_all"

# --- Что уже видели -----------------------------------------------------------------

## Отметить картинку как показанную игроку (зовётся там, где игра её показывает).
static func mark_seen(path: String) -> void:
	if path == "" or StoryState_ == null or StoryState_.has_flag(SEEN_FLAG + path):
		return
	StoryState_.set_flag(SEEN_FLAG + path, true)

static func mark_seen_texture(tex: Texture2D) -> void:
	if tex != null:
		mark_seen(tex.resource_path)

static func is_seen(path: String) -> bool:
	return StoryState_ != null and StoryState_.has_flag(SEEN_FLAG + path)

# --- Разделы ------------------------------------------------------------------------

## group: "characters" | "events".
## Возвращает [{id, title, icon_path, unlocked, hint, images: [{path, unlocked, hint}], open_count}].
static func categories(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(FILE):
		return out
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (parsed is Dictionary):
		push_warning("GalleryData: не удалось прочитать %s (проверьте запятые и скобки)" % FILE)
		return out
	var all := StoryState_ != null and StoryState_.has_flag(UNLOCK_ALL_FLAG)
	for raw in parsed.get(group, []):
		if not (raw is Dictionary):
			continue
		var char_id := String(raw.get("character", ""))
		var image_unlock: Dictionary = raw.get("image_unlock", {})
		var entries: Array = []
		if char_id != "" and bool(raw.get("auto", false)):
			entries.append_array(_auto_character_images(char_id))
		entries.append_array(raw.get("images", []))
		var images: Array[Dictionary] = []
		var known: Dictionary = {}
		var open_count := 0
		for e in entries:
			var path := String(e.get("path", "")) if e is Dictionary else String(e)
			if path == "" or known.has(path) or not ResourceLoader.exists(path):
				continue
			known[path] = true
			var cond: Dictionary = image_unlock
			if e is Dictionary and e.has("unlock"):
				cond = e["unlock"]
			var open := all or check(cond, char_id, [path])
			if open:
				open_count += 1
			images.append({"path": path, "unlocked": open, "hint": String(e.get("hint", "")) if e is Dictionary else ""})
		if images.is_empty():
			continue
		var paths: Array = known.keys()
		var cat_open := open_count > 0
		if raw.has("unlock"):
			cat_open = check(raw["unlock"], char_id, paths)
		cat_open = cat_open or all
		var icon_path := String(raw.get("icon", ""))
		if icon_path == "" or not ResourceLoader.exists(icon_path):
			icon_path = String(images[0]["path"])
			for im in images:
				if bool(im["unlocked"]):
					icon_path = String(im["path"])
					break
		out.append({
			"id": String(raw.get("id", "")),
			"title": String(raw.get("title", "")),
			"icon_path": icon_path,
			"unlocked": cat_open,
			"hint": String(raw.get("hint", "")),
			"images": images,
			"open_count": open_count if cat_open else 0,
		})
	return out

## Условие открытия. paths — картинки, к которым относится "seen" (у раздела — любая из его картинок).
static func check(cond: Dictionary, char_id: String, paths: Array) -> bool:
	if cond.is_empty():
		return true
	var rest := cond.duplicate()
	if rest.has("seen"):
		if bool(rest["seen"]):
			var any := false
			for p in paths:
				if is_seen(String(p)):
					any = true
					break
			if not any:
				return false
		rest.erase("seen")
	if rest.has("trust"):
		var need = rest["trust"]
		rest.erase("trust")
		if need is Dictionary:
			for id in need.keys():
				if _trust_level(String(id)) < int(need[id]):
					return false
		elif char_id != "" and _trust_level(char_id) < int(need):
			return false
	if rest.is_empty():
		return true
	return StoryDialogueDB_ == null or StoryDialogueDB_.check_conditions(rest)

static func _trust_level(unit_id: String) -> int:
	if UnitRoster_ == null:
		return 0
	return CardBalance.trust_level(UnitRoster_.get_trust(unit_id))

static func _auto_character_images(char_id: String) -> Array:
	var images: Array = []
	var cd: CharacterData = CharDB.get_by_id(char_id) if CharDB != null else null
	if cd != null:
		for tex in [cd.card_portrait, cd.battle_texture]:
			if tex != null and tex.resource_path != "":
				images.append(tex.resource_path)
	images.append_array(_images_in(CARD_ART_DIR % char_id))
	return images

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
