extends AbilityStep
class_name SelectFrontEnemyStep

func run(rt: AbilityRuntime) -> void:
	var t = rt.sim.get_front_alive(rt.enemies())
	rt.targets = []
	if t != null:
		rt.targets.append(t)
