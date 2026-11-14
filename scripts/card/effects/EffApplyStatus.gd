extends CardEffect
class_name EffApplyStatus
## Наложить статус. Стаки и длительность постоянны (не скейлятся).
## У улучшенной карты без чисел: +1 стак (или +1 ход, если стаков нет) — CardEffect.status_bonus.

@export var status: String = ""
@export var stacks: int = 0
@export var turns: int = 0

func _stacks() -> int:
	return stacks + (CardEffect.status_bonus(self) if stacks > 0 else 0)

func _turns() -> int:
	return turns + (CardEffect.status_bonus(self) if stacks <= 0 and turns > 0 else 0)

func value(_caster: Unit) -> int:
	return _stacks()

func bonus_value(_caster: Unit) -> int:
	return _turns()

func _apply_one(ctx: CardContext, target: Unit) -> void:
	ctx.combat.add_status(target, status, _stacks(), _turns())

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	var def := CardStatuses.get_status(status)
	var who := target_phrase(card_target)
	if def != null and def.kind == CardStatus.Kind.DURATION:
		return "[e]%s[/e] %s (%d х.)." % [def.title, who, _turns()]
	if def != null and def.kind == CardStatus.Kind.STACKS_DURATION:
		return "[e]%s %d[/e] %s (%d х.)." % [def.title, _stacks(), who, _turns()]
	return "[e]%s +%d[/e] %s." % [status_title(status), _stacks(), who]

## Что даёт улучшение этой карте (строка для описания).
func upgrade_note() -> String:
	return "+%d стак" % CardBalance.UPGRADE_STATUS_BONUS if stacks > 0 else "+%d ход" % CardBalance.UPGRADE_STATUS_BONUS
