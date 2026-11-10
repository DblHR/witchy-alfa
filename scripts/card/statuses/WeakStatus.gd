extends CardStatus
class_name WeakStatus
## Слабость: удары владельца слабее на четверть (но не ниже 1).
## Было «−2 урона» — осталось с чисел до ×10 и почти ничего не делало.

const MULT := 0.75

func _init() -> void:
	super("weak", "Слабость", Kind.DURATION)

func modify_dealt(_combat: CardCombat, _unit: Unit, _s: Dictionary, amount: int) -> int:
	return maxi(1, roundi(float(amount) * MULT)) if amount > 0 else amount
