extends AbilityStep
class_name SelectAllEnemiesStep

func run(rt: AbilityRuntime) -> void:
	rt.targets = rt.sim._get_all_alive(rt.enemies())
