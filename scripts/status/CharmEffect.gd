extends StatusEffect
class_name CharmEffect

func _init(dur: float = 2.0) -> void:
	duration = dur
	time_left = dur
	icon = load("res://assets/ui/status/charm_status.png")
	ui_name = "Charm" if ui_name == "" else ui_name

func blocks_casting() -> bool:
	return true

func flips_faction_for_autoattacks() -> bool:
	return true
