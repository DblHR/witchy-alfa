extends Ability
class_name WarriorSkillAbility

func execute(sim, caster: Unit, caster_is_left: bool) -> void:
	if sim == null or caster == null or caster.is_dead:
		return
	var target_team = sim.right_team if caster_is_left else sim.left_team
	var target = sim.get_front_alive(target_team)
	if target == null:
		return
	var stacks := _consume_stacks(target)
	if stacks <= 0:
		return
	var heal_amount = max(1, int(round(float(caster.max_hp) * 0.05 * float(stacks))))
	caster.hp = min(caster.max_hp, caster.hp + heal_amount)

func ai_can_cast(sim, caster: Unit, caster_is_left: bool) -> bool:
	if sim == null or caster == null or caster.is_dead:
		return false
	var target_team = sim.right_team if caster_is_left else sim.left_team
	var target = sim.get_front_alive(target_team)
	return _get_stacks_effect(target) != null

func _consume_stacks(target: Unit) -> int:
	var eff := _get_stacks_effect(target)
	if eff == null:
		return 0
	var removed := eff.remove_all_stacks()
	target.effects.erase(eff)
	return removed

func _get_stacks_effect(target: Unit) -> WeakeningStacksEffect:
	if target == null:
		return null
	for eff in target.effects:
		if eff is WeakeningStacksEffect:
			return eff as WeakeningStacksEffect
	return null
