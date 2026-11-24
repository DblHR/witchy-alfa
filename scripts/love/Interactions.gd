class_name Interactions
extends RefCounted
## Взаимодействия с персонажами: какие есть, когда открыты, откат «раз в день», сколько дают доверия.
## Действия (названия, уровни, доверие) — data/interactions/interactions.json;
## реплики сценок — в папке love каждого персонажа (см. LOVE_FILES ниже).
##
##  Несексуальные (kind "cute"): обнимашки, погладить, щёки, ручки — через VN (окно диалога):
##    - героини-вайфу (все, кроме главных героев MAIN_HEROES): клик по чибику в доме — разговор,
##      в нём выбор действия (в диалогах — вариант {"interactions": "cute"}; если разговора нет —
##      menu_lines: приветствие из папки love и выбор);
##    - НПС (NpcTrust.NPC_IDS): сердечко рядом с НПС в его комнате — то же меню в VN.
##    Открываются по уровню доверия (unlock), дают немного доверия, каждое — раз в день.
##  Сексуальные (kind "lewd"): поцелуй, тити, минет/дрочка/пайзури, прелюдия, секс.
##    - только героини-вайфу, с 5 уровня доверия; меню — кнопка SEX на экране отношений
##      (сердечко в доме -> героиня). Дают больше доверия, тоже раз в день.
##    - САМИ СЦЕНЫ ПОКА НЕ СДЕЛАНЫ: perform() засчитывает действие, а экран отношений
##      показывает заглушку (love_room.gd -> play_lewd_scene).
##
## «День» — DayCycle.day_number(): действие снова доступно, когда наступил следующий день.

const FILE := "res://data/interactions/interactions.json"
const KIND_CUTE := "cute"
const KIND_LEWD := "lewd"
## С ними взаимодействий нет (это «мы»).
const MAIN_HEROES := ["witch", "warrior"]
## Счётчик StoryState: в какой день действие делали последний раз.
const DAY_COUNTER := "interaction_day:%s:%s"

enum State { OK, LOCKED, USED_TODAY }

static var _data: Dictionary = {}

static func _ensure() -> void:
	if not _data.is_empty():
		return
	if FileAccess.file_exists(FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary:
			_data = parsed
	if _data.is_empty():
		_data = {"actions": {}, "scenes": {}}

static func reload() -> void:
	_data = {}
	_love = {}
	_ensure()

# --- Кто и что -----------------------------------------------------------------------

## Героиня, с которой есть взаимодействия (не главный герой).
static func is_waifu(char_id: String) -> bool:
	return char_id != "" and not MAIN_HEROES.has(char_id) and not NpcTrust.is_npc(char_id)

## С кем можно kind-взаимодействия: cute — вайфу и НПС, lewd — только вайфу.
static func supports(char_id: String, kind: String) -> bool:
	if kind == KIND_LEWD:
		return is_waifu(char_id)
	return is_waifu(char_id) or NpcTrust.is_npc(char_id)

## Действия вида kind по порядку: [{id, title, kind, unlock, trust}].
static func actions(kind: String) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	var all: Dictionary = _data.get("actions", {})
	for id in all.keys():
		var a: Dictionary = all[id]
		if String(a.get("kind", KIND_CUTE)) != kind:
			continue
		var d := a.duplicate()
		d["id"] = String(id)
		out.append(d)
	out.sort_custom(func(x, y): return int(x.get("order", 0)) < int(y.get("order", 0)))
	return out

static func action(action_id: String) -> Dictionary:
	_ensure()
	var a: Dictionary = (_data.get("actions", {}) as Dictionary).get(action_id, {})
	return a

static func title(action_id: String) -> String:
	return String(action(action_id).get("title", action_id))

## Уровень доверия: у героинь — уровень отношений (0..10), у НПС — 0..5.
static func level(char_id: String) -> int:
	if NpcTrust.is_npc(char_id):
		return NpcTrust.level(char_id)
	return UnitRoster_.get_relationship(char_id) if UnitRoster_ != null else 0

static func used_today(char_id: String, action_id: String) -> bool:
	if StoryState_ == null:
		return false
	return StoryState_.get_counter(DAY_COUNTER % [char_id, action_id]) == DayCycle.day_number()

static func state(char_id: String, action_id: String) -> State:
	if level(char_id) < int(action(action_id).get("unlock", 0)):
		return State.LOCKED
	if used_today(char_id, action_id):
		return State.USED_TODAY
	return State.OK

## Сделать действие: доверие + отметка «сегодня уже было». Возвращает, сколько доверия дали
## (-1 — нельзя: закрыто или уже было сегодня).
static func perform(char_id: String, action_id: String) -> int:
	if state(char_id, action_id) != State.OK or StoryState_ == null:
		return -1
	var key := DAY_COUNTER % [char_id, action_id]
	StoryState_.add_counter(key, DayCycle.day_number() - StoryState_.get_counter(key))
	var amount := int(action(action_id).get("trust", 0))
	if NpcTrust.is_npc(char_id):
		NpcTrust.add(char_id, amount)
	elif UnitRoster_ != null:
		UnitRoster_.add_trust(char_id, amount)
	return amount

# --- Сценки (VN) -----------------------------------------------------------------------
## Реплики — в папке love персонажа: assets/characters/<id>/love/interactions.json (героини)
## или assets/npc/<id>/love/interactions.json (НПС). Ключи: greeting — реплики перед выбором
## действия, hug / pat / cheeks / hands — сценки действий.
const LOVE_FILES := ["res://assets/characters/%s/love/interactions.json", "res://assets/npc/%s/love/interactions.json"]
## Если у персонажа нет файла или в нём нет приветствия.
const DEFAULT_GREETING := "Что-то нужно?"

static var _love: Dictionary = {}

## Путь файла реплик персонажа ("" — нет).
static func love_file(char_id: String) -> String:
	for f in LOVE_FILES:
		var p := String(f) % char_id
		if FileAccess.file_exists(p):
			return p
	return ""

static func _love_data(char_id: String) -> Dictionary:
	if _love.has(char_id):
		return _love[char_id]
	var d: Dictionary = {}
	var p := love_file(char_id)
	if p != "":
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
		if parsed is Dictionary:
			d = parsed
	_love[char_id] = d
	return d

static func _raw_lines(char_id: String, key: String) -> Array:
	var raw = _love_data(char_id).get(key, [])
	return raw if raw is Array else []

static func _resolve(char_id: String, key: String, lines: Array) -> Array:
	if lines.is_empty() or StoryDialogueDB_ == null:
		return []
	return StoryDialogueDB_.resolve_lines({"id": "interaction_%s_%s" % [char_id, key], "npc": char_id, "lines": lines})

## Реплики сценки действия (готовые для DialogueManager_.show_sequence). Нет своих — одна строка-ремарка.
static func scene_lines(char_id: String, action_id: String) -> Array:
	var lines: Array = []
	for l in _raw_lines(char_id, action_id):
		if l is Dictionary:
			lines.append((l as Dictionary).duplicate(true))
	if lines.is_empty():
		lines.append({"speaker": "hero", "text": "*%s*" % title(action_id)})
	return _resolve(char_id, action_id, lines)

## VN-меню взаимодействий: приветствие персонажа, а в последней реплике — выбор действий и «Уйти».
static func menu_lines(char_id: String) -> Array:
	var lines: Array = []
	for l in _raw_lines(char_id, "greeting"):
		if l is Dictionary:
			lines.append((l as Dictionary).duplicate(true))
	if lines.is_empty():
		lines.append({"speaker": char_id, "text": DEFAULT_GREETING})
	lines[lines.size() - 1]["choices"] = [{"interactions": KIND_CUTE, "with": char_id}, {"text": "Уйти"}]
	return _resolve(char_id, "greeting", lines)

## Строки выбора в VN вместо {"interactions": "cute", "with": id}: по одной на действие.
## {text, interaction, with, disabled}. Закрытые — «(с N ур.)», сделанные сегодня — «(завтра)».
static func choice_entries(char_id: String, kind: String = KIND_CUTE) -> Array:
	var out: Array = []
	for a in actions(kind):
		var id := String(a["id"])
		var st := state(char_id, id)
		var text := "%s   +%d ♥" % [String(a.get("title", id)), int(a.get("trust", 0))]
		match st:
			State.LOCKED:
				text = "%s   (с %d ур.)" % [String(a.get("title", id)), int(a.get("unlock", 0))]
			State.USED_TODAY:
				text = "%s   (завтра)" % String(a.get("title", id))
		out.append({"text": text, "interaction": id, "with": char_id, "disabled": st != State.OK})
	return out
