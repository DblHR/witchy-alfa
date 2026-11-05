extends CardEffect
class_name EffExtendStatus
## Продлить уже висящий статус на N ходов (на целях без статуса ничего не делает).

@export var status: String = ""
@export var turns: int = 1

func value(_caster: Unit) -> int:
	return turns

func _apply_one(ctx: CardContext, target: Unit) -> void:
	ctx.combat.add_turns(target, status, turns)

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	return "[e]%s[/e] +%d х. %s." % [status_title(status), turns, target_phrase(card_target)]
