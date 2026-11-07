extends CardStatus
class_name HeatBodyStatus
## «Жар тела» (ведьмочка): пока висит, враг, ударивший по щиту героини, получает
## Горение BURN_STACKS на BURN_TURNS ход(а).

const BURN_STACKS := 1
const BURN_TURNS := 1

func _init() -> void:
	super(CardStatuses.HEAT_BODY, "Жар тела", Kind.DURATION, Color(1.0, 0.5, 0.3))

func on_shield_hit(combat: CardCombat, _unit: Unit, _s: Dictionary, attacker: Unit, _absorbed: int) -> void:
	if attacker != null and combat.is_enemy(attacker) and CardCombat.is_alive(attacker):
		combat.add_status(attacker, CardStatuses.BURN, BURN_STACKS, BURN_TURNS)
