extends StatusEffect
class_name SlowEffect

@export var mult: float = 0.8  # например 0.8 = -20%

# Важно: _init должен допускать вызов без аргументов, иначе Resource нельзя создать из инспектора.
func _init(multiplier: float = 0.8, dur: float = 1.0) -> void:
	mult = multiplier
	duration = dur
	time_left = dur
	icon = null
	ui_name = "Slow" if ui_name == "" else ui_name

func on_apply(unit: Unit) -> void:
	unit.aps_mult *= mult

func on_expire(unit: Unit) -> void:
	# возвращаем обратно
	if mult != 0.0:
		unit.aps_mult /= mult
