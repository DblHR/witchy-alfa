extends RefCounted
class_name CardLibrary
## Доступ к картам. Сами карты — ресурсы CardDef в resources/cards/:
##   resources/cards/<герой>/*.tres — карты героя (подключены в CharacterData.card_pool / ult_card)
##   resources/cards/common/*.tres  — общие карты (филлеры, эстус)
## Здесь только сборка экземпляров для боя и поиск по id. Каждый вызов создаёт НОВЫЕ экземпляры.
##
## Разметка в описаниях: [d]урон[/d] красным, [s]щит[/s] голубым, [h]лечение[/h] зелёным,
## [e]эффект[/e] розовым. Остальной текст белый.

const FILLER_STRIKE: CardDef = preload("res://resources/cards/common/filler_strike.tres")
const FILLER_SHIELD: CardDef = preload("res://resources/cards/common/filler_shield.tres")
const ESTUS: CardDef = preload("res://resources/cards/common/estus.tres")

const COLOR_FILLER := Color(0.45, 0.45, 0.50, 1.0)
const COLOR_ESTUS := Color(0.86, 0.55, 0.16, 1.0)

## Экземпляр карты героя. owner — юнит (его характеристики идут в числа карты).
static func hero_card(d: CardDef, owner: Unit) -> CardInstance:
	return CardInstance.from_def(d, owner, owner.data.card_color, owner.data.display_name)

## Колода героя на бой: пул карт, обрезанный по лимиту ранга.
## (Позже здесь будет выбранная игроком колода из открытых карт.)
static func hero_deck(owner: Unit) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var data := owner.data
	var cap := data.card_cap()
	if data.card_pool.size() > cap:
		push_warning("CardLibrary: у %s карт больше лимита ранга (%d > %d)" % [data.id, data.card_pool.size(), cap])
	for i in range(mini(cap, data.card_pool.size())):
		if data.card_pool[i] != null:
			out.append(hero_card(data.card_pool[i], owner))
	return out

## Все карты пула героя (для экрана персонажа), с числами для данного уровня.
static func hero_pool(owner: Unit) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for d in owner.data.card_pool:
		if d != null:
			out.append(hero_card(d, owner))
	return out

## Ульта героя. cost = энергия ульты героя (CharacterData.max_energy). null, если ульты нет.
static func ult_for(owner: Unit) -> CardInstance:
	if owner == null or owner.data == null or owner.data.ult_card == null:
		return null
	var c := hero_card(owner.data.ult_card, owner)
	c.is_ult = true
	c.cost = maxi(1, owner.data.max_energy)
	return c

## Общие карты. Слабее карт героев, характеристиками не скейлятся.
static func filler_cards(attack_count: int, shield_count: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in range(attack_count):
		out.append(CardInstance.from_def(FILLER_STRIKE, null, COLOR_FILLER, "Общая"))
	for i in range(shield_count):
		out.append(CardInstance.from_def(FILLER_SHIELD, null, COLOR_FILLER, "Общая"))
	return out

## Карты эстуса: по одной на стак, лечат на DungRun.estus_power и сгорают до конца забега.
static func estus_cards(stacks: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in range(maxi(0, stacks)):
		out.append(CardInstance.from_def(ESTUS, null, COLOR_ESTUS, "Эстус"))
	return out

## id карты -> [CardDef, id героя]. Строится один раз по пулам всех персонажей.
static var _index: Dictionary = {}

static func _build_index() -> void:
	_index.clear()
	for d in [FILLER_STRIKE, FILLER_SHIELD]:
		_index[d.id] = [d, ""]
	if CharDB == null:
		return
	for data in CharDB.by_id.values():
		var cd := data as CharacterData
		for d in cd.card_pool:
			if d != null:
				if _index.has(d.id):
					push_warning("CardLibrary: id карты повторяется: %s" % d.id)
				_index[d.id] = [d, cd.id]

static func def_by_id(card_id: String) -> CardDef:
	if _index.is_empty():
		_build_index()
	var entry: Array = _index.get(card_id, [])
	return entry[0] if not entry.is_empty() else null

## id героя, которому принадлежит карта («» — общая или не найдена).
static func owner_of(card_id: String) -> String:
	if _index.is_empty():
		_build_index()
	var entry: Array = _index.get(card_id, [])
	return entry[1] if not entry.is_empty() else ""

## Новый экземпляр карты по id. Для карты героя нужен его юнит (иначе null).
static func card_by_id(card_id: String, owner: Unit = null) -> CardInstance:
	var d := def_by_id(card_id)
	if d == null:
		return null
	if owner_of(card_id) == "":
		return CardInstance.from_def(d, null, COLOR_FILLER, "Общая")
	if owner == null:
		return null
	return hero_card(d, owner)

## Проверка данных: тег карты должен совпадать с правилом «урон — атака, остальное — поддержка».
static func validate(d: CardDef) -> void:
	if d == null:
		return
	if not d.has_tag(d.expected_tag()):
		push_warning("CardLibrary: у карты %s тег %s, а по эффектам положен %s" % [d.id, d.tags, d.expected_tag()])
