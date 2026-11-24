class_name TrustRewards
extends RefCounted
## Что открывается за уровни доверия героини — для карточки персонажа в инвентаре
## («Следующая награда — на 5 уровне: …»). Собирается само:
##   карты за отношения (CharacterData.unlock_cards, уровни — CardLibrary.unlock_level);
##   сцены — диалоги с условием "trust": {"<id>": N} (data/dialogues/...);
##   картинки галереи с условием "trust" (data/gallery/gallery.json).

const _CardLib := preload("res://scripts/card/CardLibrary.gd")

## Все награды: [{level, text}], по возрастанию уровня.
static func all(data: CharacterData) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in data.unlock_cards.size():
		var def: CardDef = data.unlock_cards[i]
		if def != null:
			out.append({"level": _CardLib.unlock_level(data, i), "text": "карта «%s»" % def.title})
	if StoryDialogueDB_ != null:
		for d in StoryDialogueDB_.dialogues_by_id.values():
			var lvl := _trust_need((d as Dictionary).get("conditions", {}), data.id, "")
			if lvl > 0:
				out.append({"level": lvl, "text": "новая сцена"})
	_gallery_rewards(data.id, out)
	out.sort_custom(func(a, b): return int(a["level"]) < int(b["level"]))
	return out

## Ближайшая награда после уровня level: {level, text} (несколько на одном уровне — через запятую).
## {} — больше наград нет.
static func next_reward(data: CharacterData, level: int) -> Dictionary:
	var lvl := -1
	var parts := PackedStringArray()
	for r in all(data):
		var l := int(r["level"])
		if l <= level:
			continue
		if lvl == -1:
			lvl = l
		if l != lvl:
			break
		if not parts.has(String(r["text"])):
			parts.append(String(r["text"]))
	if lvl == -1:
		return {}
	return {"level": lvl, "text": ", ".join(parts)}

## Какой уровень доверия героини char_id требует условие (0 — не требует).
## owner — героиня раздела галереи (там "trust": 5 без имени означает её).
static func _trust_need(cond, char_id: String, owner: String) -> int:
	if not (cond is Dictionary) or not (cond as Dictionary).has("trust"):
		return 0
	var t = cond["trust"]
	if t is Dictionary:
		return int((t as Dictionary).get(char_id, 0))
	if owner == char_id:
		return int(t)
	return 0

static func _gallery_rewards(char_id: String, out: Array[Dictionary]) -> void:
	if not FileAccess.file_exists(GalleryData.FILE):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(GalleryData.FILE))
	_walk_gallery(parsed, char_id, "", out)

static func _walk_gallery(node, char_id: String, owner: String, out: Array[Dictionary]) -> void:
	if node is Array:
		for v in node:
			_walk_gallery(v, char_id, owner, out)
	elif node is Dictionary:
		var d: Dictionary = node
		var own := String(d.get("character", owner))
		# Условие на раздел — без картинок; условие на картинки (своё или общее для раздела).
		var lvl := _trust_need(d.get("unlock", {}), char_id, own) if d.has("path") else 0
		if lvl > 0:
			out.append({"level": lvl, "text": "картинка в галерее"})
		var each := _trust_need(d.get("image_unlock", {}), char_id, own)
		if each > 0:
			out.append({"level": each, "text": "картинка в галерее"})
		for k in d.keys():
			if d[k] is Array or d[k] is Dictionary:
				_walk_gallery(d[k], char_id, own, out)
