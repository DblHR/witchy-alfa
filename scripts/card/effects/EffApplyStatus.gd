extends CardEffect
class_name EffApplyStatus
## Наложить статус. Стаки и длительность постоянны (не скейлятся).

@export var status: String = ""
@export var stacks: int = 0
@export var turns: int = 0

func value(_caster: Unit) -> int:
	return stacks

func bonus_value(_caster: Unit) -> int:
	return turns

func _apply_one(ctx: CardContext, target: Unit) -> void:
	ctx.combat.add_status(target, status, stacks, turns)

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	var def := CardStatuses.get_status(status)
	var who := target_phrase(card_target)
	if def != null and def.kind == CardStatus.Kind.DURATION:
		return "[e]%s[/e] %s (%d х.)." % [def.title, who, turns]
	if def != null and def.kind == CardStatus.Kind.STACKS_DURATION:
		return "[e]%s %d[/e] %s (%d х.)." % [def.title, stacks, who, turns]
	return "[e]%s +%d[/e] %s." % [status_title(status), stacks, who]
