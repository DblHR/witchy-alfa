extends RefCounted
class_name Unit

var data: CharacterData

# Для героев/компаньонов
var level: int = 1
var uses_level_scaling: bool = true

# Для врагов (скейл от комнаты)
var room_hp_bonus: int = 0
var room_damage_bonus: int = 0

# Runtime
var max_hp: int
var hp: int
var damage: int
var aps: float
## Характеристики карточного боя (см. CharacterData).
var attack: int = 0
var magic: int = 0
var energy: int = 0
var max_energy: int
var is_dead: bool = false
var can_attack: bool = true  # позже это будет зависеть от статусов (стан и т.д.)

# Накопитель времени до следующей авто-атаки (в секундах).
# Хранится в Unit, чтобы изменение aps/aps_mult не «сбрасывало» прогресс кулдауна.
var attack_accum: float = 0.0

# AI: накопитель времени до следующего решения (в секундах)
var ai_accum: float = 0.0
var ai_interval: float = 1.0


var effects: Array[StatusEffect] = []
var aps_mult: float = 1.0  # множитель скорости атаки (для замедления)

var first_strike_used: bool = false
var low_hp_rescue_used: bool = false

func reset_for_battle() -> void:
	first_strike_used = false
	low_hp_rescue_used = false
	aps_mult = 1.0
	can_attack = true
	attack_accum = 0.0
	ai_accum = 0.0
	for eff in effects:
		if eff != null:
			eff.on_expire(self)
	effects.clear()

func has_control_effect() -> bool:
	for e in effects:
		if e == null:
			continue
		if e.blocks_attacks() or e.blocks_casting():
			return true
		var n := str(e.ui_name).to_lower()
		if n.find("slow") != -1 or n.find("stun") != -1 or n.find("charm") != -1:
			return true
	return false

func get_final_aps() -> float:
	return maxf(0.0, float(aps) * float(aps_mult))

func reset_ai_interval(rng: RandomNumberGenerator) -> void:
	# небольшая рассинхронизация, чтобы враги не жали всё синхронно
	ai_interval = rng.randf_range(0.8, 1.2)
	ai_accum = 0.0

func add_effect(eff) -> void:
	effects.append(eff)
	eff.on_apply(self)

func process_effects(delta: float) -> void:
	# тикаем все эффекты, удаляем закончившиеся
	for i in range(effects.size() - 1, -1, -1):
		var eff = effects[i]
		eff.update(self, delta)
		if eff.is_finished():
			eff.on_expire(self)
			effects.remove_at(i)

func _init(_data: CharacterData, _level: int = 1):
	data = _data
	level = _level

	if data == null:
		push_error("Unit created with NULL CharacterData!")
		return

	recalc_stats()

func make_enemy(_room_hp_bonus: int, _room_damage_bonus: int) -> void:
	uses_level_scaling = false
	room_hp_bonus = _room_hp_bonus
	room_damage_bonus = _room_damage_bonus
	recalc_stats()

	# Враг на старте комнаты всегда полный
	hp = max_hp
	is_dead = false
	
func take_damage(amount: int) -> bool:
	if is_dead:
		return false

	hp = max(hp - amount, 0)

	if hp == 0 and not is_dead:
		is_dead = true
		return true

	return false

func recalc_stats() -> void:
	if uses_level_scaling:
		var s := data.stats_for_level(level)
		max_hp = int(s["max_hp"])
		attack = int(s["attack"])
		magic = int(s["magic"])
		damage = int(s["damage"])
		aps = float(s["aps"])
		max_energy = data.max_energy
		energy = clamp(energy, 0, max_energy)
	else:
		max_hp = data.base_hp + room_hp_bonus
		attack = data.attack
		magic = data.magic
		damage = data.base_damage + room_damage_bonus
		aps = data.base_aps

	# hp clamp как у вас
	if hp <= 0:
		hp = max_hp
	else:
		hp = min(hp, max_hp)
	is_dead = hp <= 0

func has_attack_block() -> bool:
	for e in effects:
		if e != null and e.blocks_attacks():
			return true
	return false

func has_cast_block() -> bool:
	for e in effects:
		if e != null and e.blocks_casting():
			return true
	return false

func autoattack_faction_flip() -> bool:
	for e in effects:
		if e != null and e.flips_faction_for_autoattacks():
			return true
	return false
