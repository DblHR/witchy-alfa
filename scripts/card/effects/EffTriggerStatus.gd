extends CardEffect
class_name EffTriggerStatus
## Заставить статус сработать прямо сейчас (Горение тикает, не тратя длительность).

@export var status: String = ""

func deals_damage() -> bool:
	return status == CardStatuses.BURN

func _apply_one(ctx: CardContext, target: Unit) -> void:
	ctx.combat.trigger_status(target, status)

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	return "[e]%s[/e] срабатывает %s." % [status_title(status), target_phrase(card_target)]
