extends EffDamage
class_name EffLure
## Приманка: фиксированный урон base (не растёт от уровня, в отличие от общих карт).
##  - добила врага-героиню — CardCombat.lure_kill → CardBattle ловит её в ростер (или даёт копию);
##  - не добила — с шансом base% (урон карты = шанс) героиня «клюёт» (статус «На крючке»):
##    теперь её поймает любой добивающий удар. Поймать можно только добив.
##  - цель получает Очарование на CHARM_TURNS ходов.

const CHARM_TURNS := 3

func value(_caster: Unit) -> int:
	return base

func deals_damage() -> bool:
	return true

func _apply_one(ctx: CardContext, target: Unit) -> void:
	var was_alive := CardCombat.is_alive(target)
	var hooked_before := ctx.combat.has_status(target, CardStatuses.LURED)
	ctx.combat.deal_damage(ctx.caster, target, base, true)
	if was_alive and not CardCombat.is_alive(target):
		if not hooked_before:   ## если уже была на крючке — её поймал сам CardCombat
			ctx.combat.lure_kill.emit(target)
	elif was_alive and ctx.combat.can_be_lured(target) and randf() * 100.0 < float(base):
		ctx.combat.add_status(target, CardStatuses.LURED, 1, 0)
	if CardCombat.is_alive(target):
		ctx.combat.add_status(target, CardStatuses.CHARM, 0, CHARM_TURNS)
