extends CardStatus
class_name ExposedStatus
## «Подставлена» (Фуфу, «Подставить задницу»): пока действует, каждые DAMAGE_PER_STACK урона,
## дошедшего до HP владельца, дают ему +1 обволакивающую слизь. Длится до конца раунда.
## Остаток урона копится в данных статуса (ключ "carry").

## Сколько урона по HP за 1 стак. Подобрано под масштаб ×10 (удар врага 1-го этажа ≈ 15-30).
const DAMAGE_PER_STACK := 25

func _init() -> void:
	super("exposed", "Подставлена", Kind.DURATION, Color(1.0, 0.5, 0.75))

func on_hp_lost(combat: CardCombat, unit: Unit, s: Dictionary, amount: int) -> void:
	if amount <= 0 or DAMAGE_PER_STACK <= 0:
		return
	var carry := int(s.get("carry", 0)) + amount
	var gain := carry / DAMAGE_PER_STACK
	s["carry"] = carry % DAMAGE_PER_STACK
	if gain > 0:
		combat.add_status(unit, CardStatuses.WRAP_SLIME, gain, 0)
