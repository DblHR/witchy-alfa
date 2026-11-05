extends CardStatus
class_name VulnStatus
## Уязвимость: владелец получает на 50% больше урона (округление вверх).

const MULT := 1.5

func _init() -> void:
	super("vuln", "Уязвимость", Kind.DURATION)

func modify_taken(_combat: CardCombat, _unit: Unit, _s: Dictionary, amount: int) -> int:
	return ceili(float(amount) * MULT) if amount > 0 else amount
