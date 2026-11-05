extends AbilityStep
class_name DealDamageStep

@export var amount: int = 0
@export var use_caster_damage: bool = false
@export var do_flash: bool = true

func run(rt: AbilityRuntime) -> void:
	if amount == 0 and not use_caster_damage:
		return

	var dmg = rt.caster.damage if use_caster_damage else amount

	for t in rt.targets:
		if t != null and not t.is_dead:
			rt.sim._deal_damage(rt.caster_is_left, t, dmg, do_flash)
