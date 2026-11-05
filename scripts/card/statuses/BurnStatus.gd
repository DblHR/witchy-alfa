extends CardStatus
class_name BurnStatus
## Горение: в начале хода врагов наносит урон, равный силе, и теряет ход длительности.
## Сила копится, длительность берётся максимальная.

func _init() -> void:
	super("burn", "Горение", Kind.STACKS_DURATION, Color(1.0, 0.6, 0.3))

func on_enemy_turn_start(combat: CardCombat, unit: Unit, s: Dictionary) -> void:
	combat.deal_damage(null, unit, int(s["stacks"]), false)
	s["turns"] = int(s["turns"]) - 1

## Длительность тикает при срабатывании, а не в конце раунда.
func on_round_end(_combat: CardCombat, _unit: Unit, _s: Dictionary) -> void:
	pass

func trigger(combat: CardCombat, unit: Unit, s: Dictionary) -> void:
	combat.deal_damage(null, unit, int(s["stacks"]), false)
