extends RefCounted
class_name BanterDB
## Реплики отряда и врагов из data/banter/*.json (все файлы папки складываются вместе).
## В каждом файле два списка:
##   "battle" — фразы-пузыри в бою (триггеры: начало боя, карта, убийство, статус...) — BattleBanterManager;
##   "camp"   — разговоры между комнатами (после добычи и на выборе комнаты) — CardBanter.
## Формат и все триггеры/условия описаны в data/banter/README.md.

const ROOT := "res://data/banter"

static var battle_lines: Array = []
static var camp_entries: Array = []
## Настройки из ключа "settings" (обычно data/banter/settings.json): частота триггеров, паузы.
static var settings: Dictionary = {}
static var _loaded := false

static func ensure_loaded() -> void:
	if not _loaded:
		load_all()

static func load_all() -> void:
	_loaded = true
	battle_lines.clear()
	camp_entries.clear()
	settings.clear()
	var files := DirAccess.get_files_at(ROOT)
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			_load_file(ROOT + "/" + f)

static func _load_file(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("BanterDB: не получилось прочитать %s (проверьте запятые и скобки)" % path)
		return
	var st = parsed.get("settings", {})
	if st is Dictionary:
		for k in st.keys():
			if st[k] is Dictionary and settings.get(k) is Dictionary:
				(settings[k] as Dictionary).merge(st[k], true)
			else:
				settings[k] = st[k]
	for e in parsed.get("battle", []):
		if e is Dictionary and String(e.get("id", "")) != "" and not bool(e.get("disabled", false)):
			var line: Dictionary = e.duplicate(true)
			line["_file"] = path
			battle_lines.append(line)
	for e in parsed.get("camp", []):
		if e is Dictionary and String(e.get("id", "")) != "" and not bool(e.get("disabled", false)):
			var entry: Dictionary = e.duplicate(true)
			entry["_file"] = path
			camp_entries.append(entry)

## "text": "строка" или ["вариант 1", "вариант 2"] — берётся случайный вариант.
static func pick_text(value) -> String:
	if value is Array:
		if value.is_empty():
			return ""
		return String(value[randi() % value.size()])
	return String(value)

## Подстановки в тексте: {actor} {target} {enemy} — имена участников события.
static func fill(text: String, ctx: Dictionary) -> String:
	if not text.contains("{"):
		return text
	for key in ["actor", "target"]:
		var tag := "{%s}" % key
		if text.contains(tag):
			text = text.replace(tag, _name_of(String(ctx.get(key, "")), ctx))
	if text.contains("{enemy}"):
		text = text.replace("{enemy}", String(ctx.get("enemy_name", ctx.get("enemy", ""))))
	return text

static func _name_of(id: String, ctx: Dictionary) -> String:
	if id == "":
		return ""
	if id == String(ctx.get("enemy", "")) and ctx.has("enemy_name"):
		return String(ctx["enemy_name"])
	if StoryDialogueDB_ != null:
		return StoryDialogueDB_.get_character_name(id)
	return id

## once: true — фраза звучит один раз за всю игру (запоминается в сохранении).
static func once_used(id: String) -> bool:
	return StoryState_ != null and StoryState_.has_seen_dialogue("banter:" + id)

static func mark_once(id: String) -> void:
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen("banter:" + id)

## Ключи условий, которые проверяет сам бой/лагерь (остальные уходят в StoryDialogueDB.check_conditions).
const LOCAL_KEYS := ["status", "card", "card_kind", "card_cost_min", "card_cost_max", "enemy", "enemy_in_room",
	"room", "actor", "target", "target_side", "party_has", "party_has_any", "not_party_has",
	"turn_min", "turn_max", "after_room", "offered", "hero_low_hp", "hero_dead", "room_min", "room_max"]

static func _as_list(v) -> Array:
	return v if v is Array else [v]

## Проверка условий фразы. ctx — что знает бой/лагерь о моменте:
##   actor, target, target_side, status, card, card_kind, card_cost, enemy, enemies (Array), room,
##   party (Array живых id), turn, after_room, offered (Array), hero_low_hp, hero_dead, room_index.
static func check(conditions, ctx: Dictionary) -> bool:
	if not (conditions is Dictionary) or (conditions as Dictionary).is_empty():
		return true
	var c: Dictionary = conditions
	var party: Array = ctx.get("party", [])
	for key in ["status", "card", "card_kind", "enemy", "room", "actor", "target", "target_side", "after_room"]:
		if c.has(key) and not _as_list(c[key]).has(ctx.get(key, "")):
			return false
	if c.has("card_cost_min") and int(ctx.get("card_cost", 0)) < int(c["card_cost_min"]):
		return false
	if c.has("card_cost_max") and int(ctx.get("card_cost", 99)) > int(c["card_cost_max"]):
		return false
	if c.has("turn_min") and int(ctx.get("turn", 0)) < int(c["turn_min"]):
		return false
	if c.has("turn_max") and int(ctx.get("turn", 0)) > int(c["turn_max"]):
		return false
	if c.has("room_min") and int(ctx.get("room_index", 0)) + 1 < int(c["room_min"]):
		return false
	if c.has("room_max") and int(ctx.get("room_index", 0)) + 1 > int(c["room_max"]):
		return false
	if c.has("enemy_in_room"):
		var enemies: Array = ctx.get("enemies", [])
		var found := false
		for e in _as_list(c["enemy_in_room"]):
			if enemies.has(String(e)):
				found = true
		if not found:
			return false
	if c.has("offered"):
		var offered: Array = ctx.get("offered", [])
		var any_offered := false
		for o in _as_list(c["offered"]):
			if offered.has(String(o)):
				any_offered = true
		if not any_offered:
			return false
	if c.has("party_has"):
		for p in _as_list(c["party_has"]):
			if not party.has(String(p)):
				return false
	if c.has("party_has_any"):
		var any_party := false
		for p in _as_list(c["party_has_any"]):
			if party.has(String(p)):
				any_party = true
		if not any_party:
			return false
	if c.has("not_party_has"):
		for p in _as_list(c["not_party_has"]):
			if party.has(String(p)):
				return false
	if c.has("hero_low_hp") and bool(ctx.get("hero_low_hp", false)) != bool(c["hero_low_hp"]):
		return false
	if c.has("hero_dead") and bool(ctx.get("hero_dead", false)) != bool(c["hero_dead"]):
		return false
	var rest := {}
	for key in c.keys():
		if not LOCAL_KEYS.has(String(key)):
			rest[key] = c[key]
	if not rest.is_empty() and StoryDialogueDB_ != null:
		return StoryDialogueDB_.check_conditions(rest)
	return true

## Из списка подходящих: сначала самый высокий priority, среди них — случайно по weight.
static func pick_weighted(candidates: Array) -> Dictionary:
	if candidates.is_empty():
		return {}
	var top := -999999
	for e in candidates:
		top = maxi(top, int(e.get("priority", 0)))
	var pool: Array = []
	var total := 0
	for e in candidates:
		if int(e.get("priority", 0)) == top:
			pool.append(e)
			total += maxi(1, int(e.get("weight", 1)))
	var roll := randi_range(1, maxi(1, total))
	var acc := 0
	for e in pool:
		acc += maxi(1, int(e.get("weight", 1)))
		if roll <= acc:
			return e
	return pool[0]
