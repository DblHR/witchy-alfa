extends CardEffect
class_name EffBurnClimax
## «Кульминация» (ульта ведьмочки): горящий враг сразу получает весь урон, который горение
## ещё нанесло бы — урон за ход × оставшиеся ходы (горение не снимается).
## На негорящего врага накладывается Горение stacks на turns ходов.

@export var stacks: int = 3
@export var turns: int = 3

func value(_caster: Unit) -> int:
	return stacks

func bonus_value(_caster: Unit) -> int:
	return turns

func deals_damage() -> bool:
	return true

func _apply_one(ctx: CardContext, target: Unit) -> void:
	if ctx.combat.has_status(target, CardStatuses.BURN):
		var s: Dictionary = ctx.combat.statuses[target][CardStatuses.BURN]
		var dmg := BurnStatus.damage_of(s) * maxi(1, int(s["turns"]))
		ctx.combat.deal_damage(ctx.caster, target, dmg, true)
	else:
		ctx.combat.add_status(target, CardStatuses.BURN, stacks, turns)

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	return "Горящие %s получают урон горения × оставшиеся ходы; остальным [e]Горение %d[/e] (%d х.)." % [target_phrase(card_target), stacks, turns]
