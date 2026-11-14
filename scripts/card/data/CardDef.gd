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

## Как карта улучшается: "numbers" — есть числа от характеристик (урон, щит, лечение): они × UPGRADE_MULT;
## "status" — чисел нет, только статусы: +1 стак/ход первому статусу; "" — улучшать нечего.
func upgrade_kind() -> String:
	for e in effects:
		if e is EffLure:
			continue
		if e is EffDamage or e is EffHeal or e is EffShield:
			if int(e.get("base")) > 0 or float(e.get("atk_ratio")) > 0.0 or float(e.get("mag_ratio")) > 0.0:
				return "numbers"
		elif e is EffConsumeStatus:
			if int(e.base) > 0 or float(e.atk_ratio) > 0.0 or float(e.mag_ratio) > 0.0:
				return "numbers"
	return "status" if upgrade_status_effect() != null else ""

## Эффект-статус, который усиливается у улучшенной карты без чисел.
func upgrade_status_effect() -> CardEffect:
	for e in effects:
		if e is EffApplyStatus and (e.stacks > 0 or e.turns > 0):
			return e
	for e in effects:
		if e is EffExtendStatus and (e.stacks > 0 or e.turns > 0):
			return e
	return null

## Короткая подпись, что даёт улучшение («числа +15%» / «+1 стак»).
func upgrade_note() -> String:
	match upgrade_kind():
		"numbers":
			return "числа +%d%%" % roundi((CardBalance.UPGRADE_MULT - 1.0) * 100.0)
		"status":
			return String(upgrade_status_effect().call("upgrade_note"))
	return ""

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
