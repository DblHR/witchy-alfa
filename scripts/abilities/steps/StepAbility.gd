extends Ability
class_name StepAbility

@export var steps: Array[AbilityStep] = []

func execute(sim, caster: Unit, caster_is_left: bool) -> void:
	if caster == null or caster.is_dead:
		return

	var rt = AbilityRuntime.new(sim, caster, caster_is_left)

	for s in steps:
		if s == null:
			continue
		s.run(rt)
