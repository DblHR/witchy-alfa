extends CardStatus
class_name EmpowerStatus
## Усиление: каждый удар владельца сильнее на число стаков. Спадает в конце хода игрока.

func _init() -> void:
	super("empower", "Усиление", Kind.STACKS, Color(1.0, 0.55, 0.75))

func modify_dealt(_combat: CardCombat, _unit: Unit, s: Dictionary, amount: int) -> int:
	return amount + int(s["stacks"]) if amount > 0 else amount

func on_player_turn_end(_combat: CardCombat, _unit: Unit, s: Dictionary) -> void:
	s["stacks"] = 0
