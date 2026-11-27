class_name Mood
extends RefCounted
## Настроение героинь-вайфу и НПС: влюблённое / радостное / нейтральное / грустное. Цифры — data/interactions/mood.json.
##
## Падает, когда с персонажем давно не взаимодействовали, давно ничего не дарили и давно не брали
## в забег (у НПС забегов нет). Поднимается от взаимодействий (первое за день), подарков (Gifts) и
## забегов в отряде. Чем выше уровень доверия, тем быстрее меняется (и вверх, и вниз).
## Влияет на доверие за забег (CardBattle) и на шанс отказа от взаимодействия (окно диалога).
## Влюблённое (у самого верха, love_from) — самый большой бафф, но пока влюблена, штрафы за то,
## что давно не было взаимодействий / подарков / забегов, умножаются на love_decay_mult.
##
## Считается «лениво»: когда настроение спрашивают, за все прошедшие с прошлого раза игровые дни
## (DayCycle.day_number) снимается положенное. Хранится в StoryState:
##   счётчики mood:<id> (значение), mood_day:<id> (по какой день посчитано),
##   mood_talk:<id> / mood_gift:<id> / mood_run:<id> (день последнего взаимодействия / подарка / забега),
##   флаг mood_init:<id> (персонажа уже начали считать).

const FILE := "res://data/interactions/mood.json"
const LOVE := "love"
const HAPPY := "happy"
const NEUTRAL := "neutral"
const SAD := "sad"
const NAMES := {LOVE: "влюблённое", HAPPY: "радостное", NEUTRAL: "нейтральное", SAD: "грустное"}
const FACTORS := ["talk", "gift", "run"]
## Дольше этого не пересчитываем (вдруг день прыгнул далеко) — всё равно уже на нуле.
const MAX_DAYS := 60
## Настроение — от 0 до MAX_VALUE.
const MAX_VALUE := 100

static var _data: Dictionary = {}

static func _cfg() -> Dictionary:
	if _data.is_empty():
		if FileAccess.file_exists(FILE):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
			if parsed is Dictionary:
				_data = parsed
		if _data.is_empty():
			_data = {"start": 60}
	return _data

static func reload() -> void:
	_data = {}

## У кого есть настроение: те, с кем есть взаимодействия (вайфу и НПС).
static func has_mood(id: String) -> bool:
	return Interactions.supports(id, Interactions.KIND_CUTE)

static func _key(what: String, id: String) -> String:
	return "%s:%s" % [what, NpcTrust.normalize(id)]

static func _cnt(what: String, id: String) -> int:
	return StoryState_.get_counter(_key(what, id)) if StoryState_ != null else 0

static func _put(what: String, id: String, v: int) -> void:
	if StoryState_ != null and _cnt(what, id) != v:
		StoryState_.add_counter(_key(what, id), v - _cnt(what, id))

## Насколько быстро меняется от уровня доверия: 1 + level_speed * уровень / максимум.
static func speed(id: String) -> float:
	var max_lvl := NpcTrust.MAX_LEVEL if NpcTrust.is_npc(id) else UnitRoster.RELATIONSHIP_MAX
	var lvl := Interactions.level(id)
	return 1.0 + float(_cfg().get("level_speed", 1.0)) * float(lvl) / float(maxi(1, max_lvl))

## Начать считать персонажа (с сегодняшнего дня, настроение start) и досчитать прошедшие дни.
static func _update(id: String) -> void:
	if StoryState_ == null or not has_mood(id):
		return
	var today := DayCycle.day_number()
	var init := _key("mood_init", id)
	if not StoryState_.has_flag(init):
		StoryState_.set_flag(init, true)
		_put("mood", id, int(_cfg().get("start", 60)))
		_put("mood_day", id, today)
		for f in FACTORS:
			_put("mood_" + f, id, today)
		return
	var from := _cnt("mood_day", id)
	if from >= today:
		return
	var v := float(_cnt("mood", id))
	var k := speed(id)
	var decay: Dictionary = _cfg().get("decay", {})
	var love_from := float(_cfg().get("love_from", 101))
	var love_mult := float(_cfg().get("love_decay_mult", 1.0))
	for d in range(maxi(from + 1, today - MAX_DAYS + 1), today + 1):
		var day_k := k * (love_mult if v >= love_from else 1.0)   ## влюблена — штрафы сильнее
		for f in FACTORS:
			if f == "run" and NpcTrust.is_npc(id):
				continue
			var rule: Dictionary = decay.get(f, {})
			if d - _cnt("mood_" + String(f), id) > int(rule.get("grace", 1)):
				v -= float(rule.get("per_day", 0)) * day_k
	_put("mood", id, clampi(roundi(v), 0, 100))
	_put("mood_day", id, today)

## Настроение 0..100 (нет настроения — 50).
static func value(id: String) -> int:
	if not has_mood(id):
		return 50
	_update(id)
	return _cnt("mood", id)

## "love" / "happy" / "neutral" / "sad".
static func state(id: String) -> String:
	if not has_mood(id):
		return NEUTRAL
	var v := value(id)
	if v >= int(_cfg().get("love_from", 101)):
		return LOVE
	if v >= int(_cfg().get("happy_from", 70)):
		return HAPPY
	if v < int(_cfg().get("sad_below", 35)):
		return SAD
	return NEUTRAL

static func state_name(id: String) -> String:
	return String(NAMES.get(state(id), ""))

## Поднять / опустить на amount (с учётом уровня доверия).
static func change(id: String, amount: float) -> void:
	if not has_mood(id):
		return
	_update(id)
	_put("mood", id, clampi(roundi(float(_cnt("mood", id)) + amount * speed(id)), 0, 100))

## Админка / тесты: поставить ровно v.
static func set_value(id: String, v: int) -> void:
	if not has_mood(id):
		return
	_update(id)
	_put("mood", id, clampi(v, 0, 100))

## Все, у кого сейчас есть настроение: героини из отряда (кроме главных героев) и НПС.
static func all_ids() -> Array:
	var out: Array = []
	if UnitRoster_ != null:
		for id in UnitRoster_.get_unlocked_unit_ids():
			if has_mood(id):
				out.append(id)
	for id in NpcTrust.NPC_IDS:
		out.append(id)
	return out

## Взаимодействие (любое): первое за день поднимает настроение.
static func on_talk(id: String) -> void:
	if not has_mood(id):
		return
	_update(id)
	var today := DayCycle.day_number()
	if _cnt("mood_talk", id) == today:
		return
	_put("mood_talk", id, today)
	change(id, float((_cfg().get("gain", {}) as Dictionary).get("talk", 0)))

## Подарок: настроение + mood из gifts.json.
static func on_gift(id: String, amount: float) -> void:
	if not has_mood(id):
		return
	_update(id)
	_put("mood_gift", id, DayCycle.day_number())
	change(id, amount)

## Сходила в забег в отряде.
static func on_run(id: String) -> void:
	if not has_mood(id):
		return
	_update(id)
	_put("mood_run", id, DayCycle.day_number())
	change(id, float((_cfg().get("gain", {}) as Dictionary).get("run", 0)))

## Множитель доверия за забег.
static func battle_trust_mult(id: String) -> float:
	if not has_mood(id):
		return 1.0
	return float((_cfg().get("battle_trust", {}) as Dictionary).get(state(id), 1.0))

## Отказывается ли от взаимодействия (бросок шанса).
static func refuses(id: String) -> bool:
	if not has_mood(id):
		return false
	return randf() < float((_cfg().get("refuse_chance", {}) as Dictionary).get(state(id), 0.0))

## Смайлик настроения (для меню взаимодействий).
static func icon(id: String) -> Texture2D:
	var p := String((_cfg().get("icons", {}) as Dictionary).get(state(id), ""))
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null

## Реплики отказа: из папки love персонажа (refuse_<настроение> или refuse), иначе фраза из mood.json.
static func refuse_lines(id: String) -> Array:
	var st := state(id)
	var fallback := [{"speaker": id, "text": String((_cfg().get("refuse", {}) as Dictionary).get(st, "Не сейчас."))}]
	var lines := Interactions.love_lines(id, "refuse_" + st, [])
	if lines.is_empty():
		lines = Interactions.love_lines(id, "refuse", fallback)
	return lines
