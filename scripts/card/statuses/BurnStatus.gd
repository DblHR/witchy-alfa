extends CardStatus
class_name BurnStatus
## Горение: в начале хода врагов наносит урон = стаки × урон за стак и теряет ход длительности.
## Урон за стак не зависит от характеристик — только от уровня отряда (CardBalance.burn_per_stack).
## Сила копится (не больше MAX_STACKS), длительность берётся максимальная.

const MAX_STACKS := 5

func _init() -> void:
	super("burn", "Горение", Kind.STACKS_DURATION, Color(1.0, 0.6, 0.3))
	max_stacks = MAX_STACKS

static func damage_of(s: Dictionary) -> int:
	return int(s["stacks"]) * CardBalance.burn_per_stack()

func label(s: Dictionary) -> String:
	return "%s %d (%d х.): %d урона" % [title, int(s["stacks"]), int(s["turns"]), damage_of(s)]

func on_enemy_turn_start(combat: CardCombat, unit: Unit, s: Dictionary) -> void:
	combat.deal_status_damage(unit, damage_of(s), s)
	s["turns"] = int(s["turns"]) - 1

## Длительность тикает при срабатывании, а не в конце раунда.
func on_round_end(_combat: CardCombat, _unit: Unit, _s: Dictionary) -> void:
	pass

func trigger(combat: CardCombat, unit: Unit, s: Dictionary) -> void:
	combat.deal_damage(null, unit, damage_of(s), false)
