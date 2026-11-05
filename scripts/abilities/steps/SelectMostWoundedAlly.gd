extends AbilityStep
class_name SelectMostWoundedAllyStep

func run(rt: AbilityRuntime) -> void:
	var t = rt.sim._get_most_wounded_ally(rt.allies())
	rt.targets = []
	if t != null:
		rt.targets.append(t)
