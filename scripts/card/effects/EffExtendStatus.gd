extends CardEffect
class_name EffExtendStatus
## Усилить уже висящий статус: +N ходов и/или +N стаков (на целях без статуса ничего не делает).
## «Распаляющее касание»: каждому горящему врагу +1 стак и +1 ход горения.
## У улучшенной карты без чисел: +1 стак (или +1 ход, если стаков нет) — CardEffect.status_bonus.

@export var status: String = ""
@export var turns: int = 1
@export var stacks: int = 0

func _stacks() -> int:
	return stacks + (CardEffect.status_bonus(self) if stacks > 0 else 0)

func _turns() -> int:
	return turns + (CardEffect.status_bonus(self) if stacks <= 0 and turns > 0 else 0)

func value(_caster: Unit) -> int:
	return _turns()

func bonus_value(_caster: Unit) -> int:
	return _stacks()

func _apply_one(ctx: CardContext, target: Unit) -> void:
	if not ctx.combat.has_status(target, status):
		return
	if _stacks() > 0:
		ctx.combat.add_status(target, status, _stacks(), 0)
	if _turns() > 0:
		ctx.combat.add_turns(target, status, _turns())

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	var parts := PackedStringArray()
	if _stacks() > 0:
		parts.append("+%d стак" % _stacks())
	if _turns() > 0:
		parts.append("+%d х." % _turns())
	return "[e]%s[/e] %s %s." % [status_title(status), " и ".join(parts), target_phrase(card_target)]

func upgrade_note() -> String:
	return "+%d стак" % CardBalance.UPGRADE_STATUS_BONUS if stacks > 0 else "+%d ход" % CardBalance.UPGRADE_STATUS_BONUS
