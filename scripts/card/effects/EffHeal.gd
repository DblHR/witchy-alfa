extends CardEffect
class_name EffHeal
## Лечение. Скейл по умолчанию — от магии.

@export var base: int = 0
@export var atk_ratio: float = 0.0
@export var mag_ratio: float = 0.0
## Если у цели мало HP (≤ 50%): ещё столько-то от основного лечения (1.0 = вдвое больше).
@export var low_hp_bonus_mult: float = 0.0
## Умножить на число живых целей карты (ульта Фуфу: лечится за каждого задетого).
@export var per_card_target: bool = false

func value(caster: Unit) -> int:
	return scaled(base, atk_ratio, mag_ratio, caster)

func bonus_value(caster: Unit) -> int:
	return roundi(float(value(caster)) * low_hp_bonus_mult)

func _apply_one(ctx: CardContext, target: Unit) -> void:
	var amount := value(ctx.caster)
	if per_card_target:
		var hit := 0
		for u in ctx.targets:
			if CardCombat.is_alive(u):
				hit += 1
		amount *= hit
	if low_hp_bonus_mult > 0.0 and CardCombat.is_low_hp(target):
		amount += bonus_value(ctx.caster)
	ctx.combat.heal(target, amount)

func describe(caster: Unit, card_target: CardInstance.Target) -> String:
	var text := "Лечит %s на [h]%d[/h]" % [target_phrase(card_target), value(caster)]
	if per_card_target:
		text += " за каждую цель"
	if low_hp_bonus_mult > 0.0:
		text += ", при HP ≤50%% ещё [h]+%d[/h]" % bonus_value(caster)
	return text + "."
