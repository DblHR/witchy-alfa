extends EffHeal
class_name EffEstusHeal
## Лечение эстусом: процент от макс. HP цели. Процент — прокачка (DungRun.estus_power),
## а не характеристики героя. В описании {0} — этот процент.

func value(_caster: Unit) -> int:
	return DungRun.estus_power if DungRun != null else CardBalance.ESTUS_BASE_PERCENT

func _apply_one(ctx: CardContext, target: Unit) -> void:
	ctx.combat.heal(target, ceili(float(target.max_hp) * float(value(ctx.caster)) / 100.0))

func describe(caster: Unit, card_target: CardInstance.Target) -> String:
	return "Лечит %s на [h]%d%%[/h] макс. HP." % [target_phrase(card_target), value(caster)]
