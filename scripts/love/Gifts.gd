class_name Gifts
extends RefCounted
## Подарки героиням-вайфу и НПС (главным героям — нет). Что можно дарить и что это даёт —
## data/interactions/gifts.json (id предмета из инвентаря). Пока подарок один — морковка
## (предмет "gift", она же приманка для забега; продаётся у Рикки).
## Дарят в меню взаимодействий (окно диалога): вариант «Подарить …» под действиями.
## Одному персонажу — один подарок в день (DayCycle); даёт доверие и настроение (Mood).
## Счётчик StoryState gift_day:<id> — в какой день дарили последний раз.

const FILE := "res://data/interactions/gifts.json"
const DAY_COUNTER := "gift_day:%s"

static var _data: Dictionary = {}

static func _all() -> Dictionary:
	if _data.is_empty():
		if FileAccess.file_exists(FILE):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
			if parsed is Dictionary:
				_data = (parsed as Dictionary).get("gifts", {})
	return _data

static func reload() -> void:
	_data = {}

static func can_receive(char_id: String) -> bool:
	return Interactions.supports(char_id, Interactions.KIND_CUTE)

static func gift(item_id: String) -> Dictionary:
	return _all().get(item_id, {})

## id подарков по порядку.
static func ids() -> Array:
	var out: Array = _all().keys()
	out.sort_custom(func(a, b) -> bool: return int(gift(a).get("order", 0)) < int(gift(b).get("order", 0)))
	return out

static func count(item_id: String) -> int:
	return Inventory_.get_item_count(item_id) if Inventory_ != null else 0

static func gifted_today(char_id: String) -> bool:
	if StoryState_ == null:
		return false
	return StoryState_.get_counter(DAY_COUNTER % NpcTrust.normalize(char_id)) == DayCycle.day_number()

## Варианты для меню взаимодействий: {text, gift, with, disabled}.
static func choice_entries(char_id: String) -> Array:
	var out: Array = []
	if not can_receive(char_id):
		return out
	var today := gifted_today(char_id)
	for id in ids():
		var g := gift(String(id))
		var n := count(String(id))
		var title := String(g.get("title", "Подарить"))
		var text := "%s (x%d)   +%d ♥" % [title, n, int(g.get("trust", 0))]
		if n <= 0:
			text = "%s   (нет в сумке)" % title
		elif today:
			text = "%s   (сегодня уже дарили)" % title
		out.append({"text": text, "gift": String(id), "with": char_id, "disabled": n <= 0 or today})
	return out

## Подарить: предмет уходит из сумки, доверие и настроение. Возвращает доверие (-1 — нельзя).
static func give(char_id: String, item_id: String) -> int:
	if not can_receive(char_id) or gifted_today(char_id) or count(item_id) <= 0 or StoryState_ == null:
		return -1
	var g := gift(item_id)
	if g.is_empty():
		return -1
	Inventory_.remove_item(item_id, 1)
	var key := DAY_COUNTER % NpcTrust.normalize(char_id)
	StoryState_.add_counter(key, DayCycle.day_number() - StoryState_.get_counter(key))
	var amount := int(g.get("trust", 0))
	if NpcTrust.is_npc(char_id):
		NpcTrust.add(char_id, amount)
	elif UnitRoster_ != null:
		UnitRoster_.add_trust(char_id, amount)
	Mood.on_gift(char_id, float(g.get("mood", 0)))
	return amount

## Реплики: из папки love (gift_<предмет> или gift), иначе lines из gifts.json ("who" — кому дарим).
static func lines(char_id: String, item_id: String) -> Array:
	var fallback: Array = []
	for l in gift(item_id).get("lines", []):
		if l is Dictionary:
			var d := (l as Dictionary).duplicate(true)
			if String(d.get("speaker", "")) == "who":
				d["speaker"] = char_id
			fallback.append(d)
	if fallback.is_empty():
		fallback.append({"speaker": "hero", "text": "*%s*" % String(gift(item_id).get("title", "Подарок"))})
	var out := Interactions.love_lines(char_id, "gift_" + item_id, [])
	if out.is_empty():
		out = Interactions.love_lines(char_id, "gift", fallback)
	return out
