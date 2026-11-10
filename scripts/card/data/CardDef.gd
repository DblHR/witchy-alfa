extends Resource
class_name CardDef
## Описание карты (ресурс .tres). Лежит в resources/cards/<герой>/ и подключается
## к персонажу через CharacterData.card_pool (или ult_card для ульты).
##
## Описание — шаблон: {0} заменяется главным числом эффекта №0, {0b} — его доп. числом,
## {1} — эффекта №1 и т.д. Числа считаются от характеристик владельца, поэтому на карте
## всегда видно реальное значение. Пустое описание — собирается автоматически из эффектов.

## Сгорание: куда девается карта после розыгрыша.
enum Exhaust {
	NONE,    ## обычная карта — в сброс
	BATTLE,  ## сгорает до конца боя (в следующей комнате снова в колоде)
	RUN,     ## сгорает до конца забега (приманка)
}

const TAG_ATTACK := "attack"    ## наносит урон
const TAG_SUPPORT := "support"  ## всё остальное

@export var id: String = ""
@export var title: String = ""
@export var cost: int = 1
@export var target: CardInstance.Target = CardInstance.Target.FRONT_ENEMY
## Теги: attack — всё, что наносит урон; support — всё остальное.
@export var tags: PackedStringArray = PackedStringArray([TAG_ATTACK])
## Сгорание после розыгрыша. Несыгранная карта в любом случае уходит в сброс.
@export var exhaust: Exhaust = Exhaust.NONE
@export_multiline var description: String = ""
@export var effects: Array[CardEffect] = []

func has_tag(tag: String) -> bool:
	return tags.has(tag)

func deals_damage() -> bool:
	for e in effects:
		if e != null and e.deals_damage():
			return true
	return false

## Какой тег карте положен по правилу «урон — атака, остальное — поддержка».
func expected_tag() -> String:
	return TAG_ATTACK if deals_damage() else TAG_SUPPORT

func build_description(caster: Unit) -> String:
	if description.strip_edges() == "":
		var lines := PackedStringArray()
		for e in effects:
			if e != null:
				var line := e.describe(caster, target)
				if line != "":
					lines.append(line)
		return "\n".join(lines)
	var text := description
	for i in range(effects.size()):
		if effects[i] == null:
			continue
		text = text.replace("{%db}" % i, str(effects[i].bonus_value(caster)))
		text = text.replace("{%d}" % i, str(effects[i].value(caster)))
	return text
