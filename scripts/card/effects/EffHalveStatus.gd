extends CardEffect
class_name EffHalveStatus
## Снять половину стаков статуса (с округлением вниз): «Повалить» снимает половину Нажима.

@export var status: String = ""

func _apply_one(ctx: CardContext, target: Unit) -> void:
	var n := ctx.combat.stacks(target, status)
	if n >= 2:
		ctx.combat.remove_stacks(target, status, n / 2)

func describe(_caster: Unit, card_target: CardInstance.Target) -> String:
	return "Снимает половину [e]%s[/e] %s." % [status_title(status), target_phrase(card_target)]
