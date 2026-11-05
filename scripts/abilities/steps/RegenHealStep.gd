extends AbilityStep
class_name RegenHealStep

@export var heal_per_tick: int = 5
@export var ticks: int = 5
@export var interval: float = 1.2
@export var scale_mult: float = 1.0

func run(rt: AbilityRuntime) -> void:
	for t in rt.targets:
		if t != null and not t.is_dead:
			rt.sim._apply_heal(t, max(1, int(round(float(heal_per_tick) * scale_mult))), ticks, interval)
