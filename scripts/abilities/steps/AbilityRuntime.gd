extends RefCounted
class_name AbilityRuntime

var sim
var caster: Unit
var caster_is_left: bool

# выбранные цели между шагами
var targets: Array[Unit] = []

func _init(_sim, _caster: Unit, _caster_is_left: bool) -> void:
	sim = _sim
	caster = _caster
	caster_is_left = _caster_is_left

func allies() -> Array:
	return sim.left_team if caster_is_left else sim.right_team

func enemies() -> Array:
	return sim.right_team if caster_is_left else sim.left_team
