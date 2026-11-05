extends CardPassive
class_name SlimeOnHitPassive
## «Каждые N нанесённого урона → +1 стак статуса на цели» (Фуфу: липкая слизь каждые 6 урона).
## Остаток урона копится между ударами в пределах боя.

@export var damage_per_stack: int = 6
@export var status: String = "sticky_slime"

func attach(combat: CardCombat, owner: Unit) -> void:
	if damage_per_stack <= 0:
		return
	var carry := {"v": 0}
	combat.damage_dealt.connect(func(source: Unit, target: Unit, amount: int) -> void:
		if source != owner or not combat.is_enemy(target) or amount <= 0:
			return
		carry["v"] += amount
		var gain: int = carry["v"] / damage_per_stack
		carry["v"] -= gain * damage_per_stack
		if gain > 0 and CardCombat.is_alive(target):
			combat.add_status(target, status, gain, 0)
	)
