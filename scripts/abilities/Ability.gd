extends Resource
class_name Ability

@export var name: String = ""
@export var icon: Texture2D

# Стоимость энергии. Для ульты можно поставить use_full_energy=true.
@export var cost: int = 0
@export var use_full_energy: bool = false

# Общий хелпер: повторяет старый скейл из BattleSim, чтобы поведение не поплыло.
func scaled_amount(base_amount: int, caster: Unit) -> int:
	var amt := base_amount
	# Простой скейл от уровня кастера (только для героев/компаньонов).
	# Враги не используют level scaling (uses_level_scaling=false).
	if caster != null and caster.uses_level_scaling and caster.level > 1:
		var mult := 1.0 + 0.15 * float(caster.level - 1)
		amt = int(round(float(amt) * mult))
	return amt

func execute(_sim, _caster: Unit, _caster_is_left: bool) -> void:
	# override
	pass

func ai_can_cast(_sim, _caster: Unit, _caster_is_left: bool) -> bool:
	# override when needed
	return true
