extends CardStatus
class_name WeakStatus
## Слабость: удар владельца слабее на REDUCTION (но не ниже 1).

const REDUCTION := 2

func _init() -> void:
	super("weak", "Слабость", Kind.DURATION)

func modify_dealt(_combat: CardCombat, _unit: Unit, _s: Dictionary, amount: int) -> int:
	return maxi(1, amount - REDUCTION) if amount > 0 else amount
