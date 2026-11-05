extends AbilityStep
class_name ApplyEffectStep

@export var effect: Resource

func run(rt: AbilityRuntime) -> void:
	if effect == null:
		return

	for t in rt.targets:
		if t != null and not t.is_dead:
			# ВАЖНО: на каждую цель нужен отдельный инстанс эффекта
			var inst := effect.duplicate(true)
			t.add_effect(inst)
			if rt.sim != null and rt.sim.has_method("_dbg"):
				var en := "" if t.data == null else t.data.display_name
				rt.sim._dbg("ApplyEffect %s -> %s" % [inst.get_class(), en])
