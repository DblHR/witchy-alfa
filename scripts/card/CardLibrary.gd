extends RefCounted
class_name CardLibrary
## Доступ к картам. Сами карты — ресурсы CardDef в resources/cards/:
##   resources/cards/<герой>/*.tres — карты героя (подключены в CharacterData.card_pool / ult_card)
##   resources/cards/common/*.tres  — общие карты (филлеры, приманка)
## Здесь только сборка экземпляров для боя и поиск по id. Каждый вызов создаёт НОВЫЕ экземпляры.
##
## Разметка в описаниях: [d]урон[/d] красным, [s]щит[/s] голубым, [h]лечение[/h] зелёным,
## [e]эффект[/e] розовым. Остальной текст белый.

const FILLER_STRIKE: CardDef = preload("res://resources/cards/common/filler_strike.tres")
const FILLER_SHIELD: CardDef = preload("res://resources/cards/common/filler_shield.tres")
const LURE: CardDef = preload("res://resources/cards/common/lure.tres")
const COLOR_LURE := Color(0.88, 0.36, 0.62, 1.0)

const COLOR_FILLER := Color(0.45, 0.45, 0.50, 1.0)

## Экземпляр карты героя. owner — юнит (его характеристики идут в числа карты).
static func hero_card(d: CardDef, owner: Unit) -> CardInstance:
	return CardInstance.from_def(d, owner, owner.data.card_color, owner.data.display_name)

const FILLER_ATTACK_COUNT := 4
const FILLER_SHIELD_COUNT := 2

## С какого уровня отношений открывается i-я карта из unlock_cards: награды равномерно
## до максимума (у A-ранга одна карта — на 10, у S-ранга две — на 5 и 10).
static func unlock_level(data: CharacterData, index: int) -> int:
	var n := maxi(1, data.unlock_cards.size())
	return ceili(float(UnitRoster.RELATIONSHIP_MAX) * float(index + 1) / float(n))

## Открыта ли карта за отношения (у всех, включая ведьмочку и воина).
static func is_unlocked(data: CharacterData, index: int) -> bool:
	if UnitRoster_ == null:
		return false
	return UnitRoster_.get_relationship(data.id) >= unlock_level(data, index)

## Карты героини, которые у игрока есть: стартовые + открытые.
static func owned_defs(data: CharacterData) -> Array[CardDef]:
	var out: Array[CardDef] = []
	for d in data.card_pool:
		if d != null:
			out.append(d)
	for i in range(data.unlock_cards.size()):
		if data.unlock_cards[i] != null and is_unlocked(data, i):
			out.append(data.unlock_cards[i])
	return out

## Карты, которые идут в бой: выбранные на экране Setup (не больше лимита ранга).
## Если игрок ничего не выбирал — первые карты по лимиту.
static func deck_defs(data: CharacterData) -> Array[CardDef]:
	var owned := owned_defs(data)
	var cap := data.card_cap()
	var out: Array[CardDef] = []
	if UnitRoster_ != null and UnitRoster_.has_deck_selection(data.id):
		var chosen := UnitRoster_.get_deck_selection(data.id)
		for d in owned:
			if chosen.has(d.id) and out.size() < cap:
				out.append(d)
		if not out.is_empty():
			return out
	for i in range(mini(cap, owned.size())):
		out.append(owned[i])
	return out

## Колода героя на бой.
static func hero_deck(owner: Unit) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for d in deck_defs(owner.data):
		out.append(hero_card(d, owner))
	return out

## Карты героини для экрана персонажа: сначала имеющиеся, затем ещё не открытые (locked).
static func hero_pool(owner: Unit) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for d in owned_defs(owner.data):
		out.append(hero_card(d, owner))
	for i in range(owner.data.unlock_cards.size()):
		var d := owner.data.unlock_cards[i]
		if d != null and not is_unlocked(owner.data, i):
			var c := hero_card(d, owner)
			c.locked = true
			out.append(c)
	return out

## Колода в начале боя без учёта забега: карты героев + общие карты.
static func base_deck(heroes: Array[Unit]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for u in heroes:
		if u != null and not u.is_dead:
			cards.append_array(hero_deck(u))
	cards.append_array(filler_cards(FILLER_ATTACK_COUNT, FILLER_SHIELD_COUNT))
	return cards

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

## Карта приманки (одна на забег, если её взяли в Setup и она есть в инвентаре).
static func lure_card() -> CardInstance:
	return CardInstance.from_def(LURE, null, COLOR_LURE, "Приманка")

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
		for d in cd.card_pool + cd.unlock_cards:
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
