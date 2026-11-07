extends EffDamage
class_name EffLure
## Приманка: фиксированный урон base (не растёт от уровня, в отличие от общих карт). Если удар добил врага-героиню —
## CardCombat.lure_kill → CardBattle ловит её в ростер (или даёт копию, если уже есть).

func value(_caster: Unit) -> int:
	return base

func deals_damage() -> bool:
	return true

func _apply_one(ctx: CardContext, target: Unit) -> void:
	var was_alive := CardCombat.is_alive(target)
	ctx.combat.deal_damage(ctx.caster, target, base, true)
	if was_alive and not CardCombat.is_alive(target):
		ctx.combat.lure_kill.emit(target)
