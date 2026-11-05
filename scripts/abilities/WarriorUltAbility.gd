extends Ability
class_name WarriorUltAbility

func _init() -> void:
	use_full_energy = true

func execute(sim, caster: Unit, caster_is_left: bool) -> void:
	if sim == null or caster == null or caster.is_dead:
		return
	var target_team = sim.right_team if caster_is_left else sim.left_team
	var target = sim.get_front_alive(target_team)
	if target != null:
		_add_stacks(target, 4)
	caster.add_effect(SlowEffect.new(0.7, 3.0))

func _add_stacks(target: Unit, amount: int) -> void:
	if target == null or amount <= 0:
		return
	for eff in target.effects:
		if eff is WeakeningStacksEffect:
			(eff as WeakeningStacksEffect).add_stacks(amount)
			return
	var new_eff := WeakeningStacksEffect.new(amount)
	target.add_effect(new_eff)
