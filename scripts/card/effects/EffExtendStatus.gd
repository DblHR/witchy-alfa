extends CardEffect
class_name EffExtendStatus
## Усилить уже висящий статус: +N ходов и/или +N стаков (на целях без статуса ничего не делает).
## «Распаляющее касание»: каждому горящему врагу +1 стак и +1 ход горения.

@export var status: String = ""
@export var turns: int = 1
@export var stacks: int = 0

func value(_caster: Unit) -> int:
	return turns

func bonus_value(_caster: Unit) -> int:
	return stacks

func _apply_one(ctx: CardContext, target: Unit) -> void:
	if not ctx.combat.has_status(target, status):
		return
	if stacks > 0:
		ctx.combat.add_status(target, status, stacks, 0)
	if turns > 0:
		ctx.combat.add_turns(target, status, turns)

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	var parts := PackedStringArray()
	if stacks > 0:
		parts.append("+%d стак" % stacks)
	if turns > 0:
		parts.append("+%d х." % turns)
	return "[e]%s[/e] %s %s." % [status_title(status), " и ".join(parts), target_phrase(card_target)]
