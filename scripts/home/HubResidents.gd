class_name HubResidents
extends RefCounted
## Кто живёт в доме (гуляет по хабу): не больше MAX, можно и никого.
## Выбирают кнопкой слева сверху (HubRosterMenu). Жить дома могут только персонажи из ростера
## (ведьмочка — всегда), у кого есть картинка для дома (<id>_battle.png).
## Пока игрок ничего не менял — дома первые MAX из доступных. Как только поменял — помнится его выбор
## (флаги StoryState: hub_residents_custom, hub_resident:<id>); новенькие (поймали героиню)
## заселяются сами, если есть место (флаг hub_resident_known:<id> — уже видели).

const MAX := 5
const SPRITE_PATH := "res://assets/characters/%s/%s_battle.png"
## Порядок в списке и по умолчанию.
const ORDER := ["witch", "warrior", "fufu", "aki", "luisa"]
const FLAG_CUSTOM := "hub_residents_custom"
const FLAG_ON := "hub_resident:%s"
const FLAG_KNOWN := "hub_resident_known:%s"

## Все, кто может жить дома (по порядку ORDER, потом остальные из ростера).
static func available() -> Array[String]:
	var out: Array[String] = []
	var ids: Array = ORDER.duplicate()
	if UnitRoster_ != null:
		for id in UnitRoster_.get_unlocked_unit_ids():
			if not ids.has(String(id)):
				ids.append(String(id))
	for id in ids:
		var sid := String(id)
		if sid != "witch" and (UnitRoster_ == null or not UnitRoster_.has_unit(sid)):
			continue
		if not ResourceLoader.exists(SPRITE_PATH % [sid, sid]):
			continue
		out.append(sid)
	return out

static func _custom() -> bool:
	return StoryState_ != null and StoryState_.has_flag(FLAG_CUSTOM)

## Кто сейчас живёт дома.
static func residents() -> Array[String]:
	var all := available()
	var out: Array[String] = []
	if not _custom():
		for id in all:
			if out.size() < MAX:
				out.append(id)
		return out
	_settle_newcomers(all)
	for id in all:
		if StoryState_.has_flag(FLAG_ON % id) and out.size() < MAX:
			out.append(id)
	return out

static func is_resident(id: String) -> bool:
	return residents().has(id)

## Новенькие в ростере заселяются сами, если есть место.
static func _settle_newcomers(all: Array[String]) -> void:
	var count := 0
	for id in all:
		if StoryState_.has_flag(FLAG_ON % id):
			count += 1
	for id in all:
		if StoryState_.has_flag(FLAG_KNOWN % id):
			continue
		StoryState_.set_flag(FLAG_KNOWN % id, true)
		if count < MAX:
			StoryState_.set_flag(FLAG_ON % id, true)
			count += 1

## Заселить / выселить. false — нельзя (уже MAX, нет в ростере).
static func set_resident(id: String, on: bool) -> bool:
	if StoryState_ == null:
		return false
	var now := residents()
	if on == now.has(id):
		return true
	if on and (now.size() >= MAX or not available().has(id)):
		return false
	if not _custom():
		# Первый раз поменяли — запоминаем текущий состав.
		for a in available():
			StoryState_.set_flag(FLAG_KNOWN % a, true)
			StoryState_.set_flag(FLAG_ON % a, now.has(a))
		StoryState_.set_flag(FLAG_CUSTOM, true)
	StoryState_.set_flag(FLAG_ON % id, on)
	return true
