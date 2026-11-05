extends StatusEffect
class_name StunEffect

func _init(dur: float = 2.0) -> void:
	duration = dur
	time_left = dur
	if ui_name == "":
		ui_name = "Stun"

func blocks_attacks() -> bool:
	return true

func blocks_casting() -> bool:
	return true
