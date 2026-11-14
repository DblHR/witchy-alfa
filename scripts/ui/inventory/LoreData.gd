extends RefCounted
class_name LoreData
## Энциклопедия из data/lore/lore.json: записки (сюжет, поручения, места), страницы персонажей,
## бестиарий и статусы. Что открыто — решают условия unlock (те же, что у диалогов).
## Как править — см. "_help" в самом файле.

const FILE := "res://data/lore/lore.json"
## Флаг «встречала этого врага» (ставит CardBattle при появлении врага): met_enemy:<id>.
const MET_ENEMY_FLAG := "met_enemy:"
const CAT_ENEMIES := "Бестиарий"
const CAT_STATUSES := "Статусы"

static var _data: Dictionary = {}
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_warning("LoreData: не получилось прочитать %s (проверьте запятые и скобки)" % FILE)

static func _unlocked(cond) -> bool:
	if not (cond is Dictionary) or (cond as Dictionary).is_empty():
		return true
	return StoryDialogueDB_ == null or StoryDialogueDB_.check_conditions(cond)

static func mark_enemy_met(enemy_id: String) -> void:
	if StoryState_ != null and enemy_id != "" and not StoryState_.has_flag(MET_ENEMY_FLAG + enemy_id):
		StoryState_.set_flag(MET_ENEMY_FLAG + enemy_id)

## Все открытые записи по порядку: [{id, category, title, body}].
static func entries() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for n in _data.get("notes", []):
		if n is Dictionary and _unlocked(n.get("unlock", {})):
			out.append({"id": String(n.get("id", "")), "category": String(n.get("category", "Записки")),
				"title": String(n.get("title", "")), "body": String(n.get("body", ""))})
	for e in _data.get("enemies", []):
		if not (e is Dictionary):
			continue
		var eid := String(e.get("id", ""))
		if StoryState_ != null and StoryState_.has_flag(MET_ENEMY_FLAG + eid):
			out.append({"id": "enemy_" + eid, "category": CAT_ENEMIES,
				"title": String(e.get("title", EnemyDefs.title_of(eid))), "body": String(e.get("body", ""))})
	for sid in CardStatuses.all_ids():
		var s := CardStatuses.get_status(String(sid))
		if s == null or s.info == "":
			continue
		out.append({"id": "status_" + String(sid), "category": CAT_STATUSES, "title": s.title, "body": s.info})
	return out

static func entry(entry_id: String) -> Dictionary:
	for e in entries():
		if String(e["id"]) == entry_id:
			return e
	return {}

## Описание персонажа для его страницы ("" — нет в файле).
static func character_description(char_id: String) -> String:
	_ensure()
	var c = (_data.get("characters", {}) as Dictionary).get(char_id, {})
	return String(c.get("description", "")) if c is Dictionary else ""

## Открытые заметки о персонаже (то, что игрок уже видел в диалогах).
static func character_facts(char_id: String) -> Array[String]:
	_ensure()
	var out: Array[String] = []
	var c = (_data.get("characters", {}) as Dictionary).get(char_id, {})
	if c is Dictionary:
		for f in c.get("facts", []):
			if f is Dictionary and _unlocked(f.get("unlock", {})):
				out.append(String(f.get("text", "")))
	return out
