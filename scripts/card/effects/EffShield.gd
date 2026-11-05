extends CardEffect
class_name EffShield
## Щит. Скейл по умолчанию — от магии (можно и от атаки, если герою так задумано).

@export var base: int = 0
@export var atk_ratio: float = 0.0
@export var mag_ratio: float = 0.0

func value(caster: Unit) -> int:
	return scaled(base, atk_ratio, mag_ratio, caster)

func _apply_one(ctx: CardContext, target: Unit) -> void:
	ctx.combat.add_shield(target, value(ctx.caster))

func describe(caster: Unit, card_target: CardInstance.Target) -> String:
	return "[s]+%d[/s] щита %s." % [value(caster), target_phrase(card_target)]
