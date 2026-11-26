class_name Dreams
extends RefCounted
## Сны: ночью легли спать (Hub.go_to_sleep) — с шансом снится мини-игра про одного из своих персонажей.
## Настройки — data/dreams/dreams.json. Сама игра — scenes/dreams/Dream.tscn (DreamScreen),
## у каждого сна свой скрипт в scripts/dreams/games/ (DreamGame).

const FILE := "res://data/dreams/dreams.json"
const GAMES_DIR := "res://scripts/dreams/games/"
## Скрипт игры для каждого сна.
const GAME_SCRIPTS := {
	"witch": "DreamWitch.gd",
	"warrior": "DreamWarrior.gd",
	"rikka": "DreamRikka.gd",
	"sessilia": "DreamSessilia.gd",
	"aki": "DreamAki.gd",
	"luisa": "DreamLuisa.gd",
	"fufu": "DreamFufu.gd",
}

static var _data: Dictionary = {}

static func config() -> Dictionary:
	if _data.is_empty():
		if FileAccess.file_exists(FILE):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
			if parsed is Dictionary:
				_data = parsed
		if _data.is_empty():
			_data = {"chance": 0.0, "dreams": {}}
	return _data

static func reload() -> void:
	_data = {}

static func dream(id: String) -> Dictionary:
	return (config().get("dreams", {}) as Dictionary).get(id, {})

static func all_ids() -> Array:
	return (config().get("dreams", {}) as Dictionary).keys()

## Знаком ли с персонажем: героини — в ростере (ведьмочка всегда), НПС — встречали.
static func knows(who: String) -> bool:
	if who == "witch":
		return true
	if NpcTrust.is_npc(who):
		return _npc_met(who)
	return UnitRoster_ != null and UnitRoster_.has_unit(who)

static func _npc_met(npc_id: String) -> bool:
	if npc_id == "rikka" or NpcTrust.points(npc_id) > 0:
		return true
	if StoryState_ == null or StoryDialogueDB_ == null:
		return false
	for did in StoryState_.seen_dialogues.keys():
		var d: Dictionary = StoryDialogueDB_.get_dialogue(String(did))
		if NpcTrust.normalize(String(d.get("npc", ""))) == npc_id:
			return true
	return false

## Кому из знакомых может присниться сон.
static func available() -> Array:
	var out: Array = []
	for id in all_ids():
		if knows(String(dream(String(id)).get("who", id))) and GAME_SCRIPTS.has(String(id)):
			out.append(String(id))
	return out

## Бросок шанса: какой сон приснится (id) или "" — без снов.
static func roll() -> String:
	var ids := available()
	if ids.is_empty() or randf() >= float(config().get("chance", 0.0)):
		return ""
	return String(ids[randi() % ids.size()])

## Опыт за очки (не больше xp_cap).
static func xp_for(id: String, points: int) -> int:
	var per := float(dream(id).get("xp_per_point", 1))
	return clampi(roundi(float(points) * per), 0, int(config().get("xp_cap", 50)))

static func make_game(id: String) -> DreamGame:
	var path := GAMES_DIR + String(GAME_SCRIPTS.get(id, ""))
	if not ResourceLoader.exists(path):
		return null
	var g := (load(path) as GDScript).new() as DreamGame
	if g != null:
		g.dream_id = id
		g.cfg = dream(id)
	return g
