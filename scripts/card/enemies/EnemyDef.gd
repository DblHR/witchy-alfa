extends RefCounted
class_name EnemyDef
## Описание врага: вид, ранг, HP, набор ходов и как он их выбирает.
## Особые враги (Большая блёба, Фуфу) — подклассы с хуками on_hurt / on_status / on_death.
## Все враги собраны в EnemyDefs.

var id: String = ""
var title: String = ""
## B — рядовой, A — элита, S — босс. От ранга зависят опыт и рамка.
var rank: String = "B"
## Картинка (для слизней) или id персонажа из CharDB (слизнедевочки-враги берут его вид).
var texture_path: String = ""
var char_id: String = ""
## Размер относительно обычного (Большая блёба крупнее, мелочь — меньше).
var visual_scale: float = 1.0
var hp_min: int = 10
var hp_max: int = 10
## Слизь с врага (алхимия).
var drops_goop := true
var moves: Array[EnemyMove] = []

func _init(p_id: String = "", p_title: String = "", p_rank: String = "B") -> void:
	id = p_id
	title = p_title
	rank = p_rank

func add(m: EnemyMove) -> EnemyMove:
	moves.append(m)
	return m

func is_boss() -> bool:
	return rank == "S"

# --- Вид ---------------------------------------------------------------------

var _data: CharacterData

## Данные для Unit/BattleActor. У слизней собираются из картинки, у девочек — копия героини.
func char_data() -> CharacterData:
	if _data != null:
		return _data
	if char_id != "" and CharDB != null and CharDB.get_by_id(char_id) != null:
		_data = (CharDB.get_by_id(char_id) as CharacterData).duplicate()
	else:
		_data = CharacterData.new()
		_data.battle_texture = load(texture_path) as Texture2D
		_data.battle_scale = 0.6
		_data.battle_offset_y = -100.0
	_data.id = id
	_data.display_name = title
	_data.unit_class = "босс" if is_boss() else "рядовой враг"
	_data.max_energy = 0
	_data.card_passive = null
	return _data

## Новый враг для боя на этаже floor_no.
func make_unit(floor_no: int, rng: RandomNumberGenerator, hp_override: int = 0) -> Unit:
	var u := Unit.new(char_data(), 1)
	u.make_enemy(0, 0)
	u.enemy_def = self
	u.visual_scale = visual_scale
	var mult := CardBalance.floor_mult(floor_no)
	u.ai = {"mult": mult, "floor": floor_no, "row": 0, "last": "", "cd": {}}
	u.max_hp = hp_override if hp_override > 0 else roundi(float(rng.randi_range(hp_min, hp_max)) * mult * CardBalance.enemy_hp_mult)
	u.hp = u.max_hp
	return u

# --- Выбор хода --------------------------------------------------------------

## Выбрать ход: вес, «не больше N подряд», перезарядка, условие. Особые враги переопределяют.
func choose(api: EnemyApi, me: Unit) -> EnemyMove:
	var cd: Dictionary = me.ai.get("cd", {})
	var pool: Array[EnemyMove] = []
	var total := 0
	for m in moves:
		if m.weight <= 0:
			continue
		if int(cd.get(m.id, 0)) > 0:
			continue
		if String(me.ai.get("last", "")) == m.id and int(me.ai.get("row", 0)) >= m.max_in_row:
			continue
		if m.cond.is_valid() and not bool(m.cond.call(api, me)):
			continue
		pool.append(m)
		total += m.weight
	if pool.is_empty():
		return moves[0]
	var roll := api.rng.randi_range(1, total)
	for m in pool:
		roll -= m.weight
		if roll <= 0:
			return m
	return pool[0]

## Ход выбран и будет показан: обновить счётчики подряд и перезарядки.
func on_chosen(me: Unit, move: EnemyMove) -> void:
	var cd: Dictionary = me.ai.get("cd", {})
	for k in cd.keys():
		cd[k] = int(cd[k]) - 1
		if int(cd[k]) <= 0:
			cd.erase(k)
	if move.cooldown > 0:
		cd[move.id] = move.cooldown   # недоступен столько следующих выборов
	me.ai["cd"] = cd
	if String(me.ai.get("last", "")) == move.id:
		me.ai["row"] = int(me.ai.get("row", 0)) + 1
	else:
		me.ai["row"] = 1
	me.ai["last"] = move.id

# --- Хуки (по умолчанию ничего) ---------------------------------------------

## Враг потерял HP (после щита).
func on_hurt(_api: EnemyApi, _me: Unit, _amount: int) -> void:
	pass

## На врага наложили статус.
func on_status(_api: EnemyApi, _me: Unit, _status_id: String) -> void:
	pass

## Враг погиб.
func on_death(_api: EnemyApi, _me: Unit) -> void:
	pass

## Выполнить ход (по умолчанию — поля хода + custom).
func act(api: EnemyApi, me: Unit, move: EnemyMove) -> void:
	api.execute(me, move)
