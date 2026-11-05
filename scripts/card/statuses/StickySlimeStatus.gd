extends CardStatus
class_name StickySlimeStatus
## Липкая слизь (на врагах): каждый раз, когда стаков становится кратно STUN_EVERY
## (4, 8, 12…), враг оглушается на ход. Снятие стаков оглушения не даёт.

const STUN_EVERY := 4

func _init() -> void:
	super("sticky_slime", "Липкая слизь", Kind.STACKS, Color(0.55, 1.0, 0.45))

func on_added(combat: CardCombat, unit: Unit, old_stacks: int, s: Dictionary) -> void:
	if not combat.is_enemy(unit) or STUN_EVERY <= 0:
		return
	if int(s["stacks"]) / STUN_EVERY > old_stacks / STUN_EVERY:
		combat.add_status(unit, "stun", 0, 1, true)
		combat.floated.emit(unit, "Оглушён!", CardCombat.COL_STATUS, 26)
