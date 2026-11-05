extends RefCounted
class_name CardInstance
## Экземпляр карты в бою: CardDef + владелец. Описание уже посчитано от характеристик владельца.
## Создаётся через CardLibrary (CardInstance.from_def), UI читает только поля ниже.

enum Target {
	FRONT_ENEMY,   ## передний враг, играется отпусканием вне руки
	ALL_ENEMIES,   ## все враги, играется отпусканием вне руки
	SELF,          ## сам владелец карты, играется отпусканием вне руки
	CHOSEN_ENEMY,  ## враг на выбор: перетащить на него
	CHOSEN_ALLY,   ## союзник на выбор: перетащить на него
}

var def: CardDef
var id: String = ""
var title: String = ""
var description: String = ""
var cost: int = 1
var target: Target = Target.FRONT_ENEMY
var color: Color = Color(0.45, 0.45, 0.5, 1.0)
## Кто владеет картой: id героя (например "witch") или "" для общих карт.
var owner_id: String = ""
var owner_name: String = "Общая"
var tags: PackedStringArray = PackedStringArray()
var effects: Array[CardEffect] = []
## Ульта: играется кнопкой, cost — размер шкалы заряда (энергия ульты героя).
var is_ult: bool = false
## Сгорает: после розыгрыша не уходит в сброс, а выходит из игры
## (exhaust_scope: до конца боя или до конца забега). Несыгранная карта сбрасывается как обычная.
var exhaust: bool = false
var exhaust_scope: CardDef.Exhaust = CardDef.Exhaust.NONE

static func from_def(d: CardDef, owner: Unit, p_color: Color, p_owner_name: String) -> CardInstance:
	var c := CardInstance.new()
	c.def = d
	c.id = d.id
	c.title = d.title
	c.cost = d.cost
	c.target = d.target
	c.tags = d.tags
	c.exhaust_scope = d.exhaust
	c.exhaust = d.exhaust != CardDef.Exhaust.NONE
	c.effects = d.effects
	c.color = p_color
	c.owner_name = p_owner_name
	if owner != null and owner.data != null:
		c.owner_id = owner.data.id
	c.description = d.build_description(owner)
	return c

func has_tag(tag: String) -> bool:
	return tags.has(tag)

## Вид для подложки карты: ult / attack / support.
func get_kind() -> String:
	if is_ult:
		return "ult"
	return CardDef.TAG_ATTACK if has_tag(CardDef.TAG_ATTACK) else CardDef.TAG_SUPPORT

## Описание без тегов [d] [s] [h] [e] (для подсказок и логов).
static func strip_markup(text: String) -> String:
	var out := text
	for tag in ["d", "s", "h", "e"]:
		out = out.replace("[%s]" % tag, "").replace("[/%s]" % tag, "")
	return out

func plain_description() -> String:
	return strip_markup(description)
