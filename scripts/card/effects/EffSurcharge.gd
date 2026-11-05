extends CardEffect
class_name EffSurcharge
## Карты владельца дороже на N в следующий ход (цена за мощный приём Воина).

@export var amount: int = 1

func value(_caster: Unit) -> int:
	return amount

func apply(ctx: CardContext) -> void:
	if ctx.caster != null:
		ctx.combat.add_surcharge(ctx.caster.data.id, amount)

func describe(_caster: Unit, _card_target: CardInstance.Target) -> String:
	return "Карты героя: +%d к цене в след. ход." % amount
