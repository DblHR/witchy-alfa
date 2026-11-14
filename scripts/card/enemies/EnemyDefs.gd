extends RefCounted
class_name EnemyDefs
## Реестр врагов: id -> EnemyDef. Числа — для 1-го этажа (дальше × CardBalance.floor_mult).
## Все цифры тестовые: героини 1-го уровня ~360-520 HP, карта бьёт ~12-20.
##
## Этаж 1 (слизни):
##   B: Шлёпыш, Пузырь, Большая блёба, Кислотный (+ мини-версии для призыва и деления)
##   A: Аки, Луиса (элитные комнаты)
##   S: Фуфу (босс, EnemyFufu)

const SPRITES := "res://assets/enemies/slimes/"

## Кто может встретиться в обычной комнате 1-го этажа и элитной.
const FLOOR1_B: Array[String] = ["shlep", "bubble", "blob", "acid"]
const FLOOR1_A: Array[String] = ["aki_enemy", "luisa_enemy"]
const FLOOR1_BOSS := "fufu"

static var _all: Dictionary = {}

static func get_def(id: String) -> EnemyDef:
	if _all.is_empty():
		_register_all()
	return _all.get(id)

static func title_of(id: String) -> String:
	var d := get_def(id)
	return d.title if d != null else id

static func _add(d: EnemyDef) -> void:
	_all[d.id] = d

static func _mv(id: String, title: String, kind: EnemyMove.Kind, weight: int) -> EnemyMove:
	var m := EnemyMove.new(id, title, kind)
	m.weight = weight
	return m

static func _register_all() -> void:
	_add(_shlep("shlep", "Шлёпыш", 68, 78, 1.0, 1.0))
	_add(_shlep("mini_shlep", "Мини-шлёпыш", 30, 34, 0.7, 0.6))
	_add(_bubble("bubble", "Пузырь", 56, 64, 1.0, 1.0))
	_add(_bubble("mini_bubble", "Мини-пузырь", 26, 30, 0.7, 0.6))
	_add(_acid("acid", "Кислотный", 62, 70, 1.0, 1.0))
	_add(_acid("mini_acid", "Мини-кислотный", 28, 32, 0.7, 0.6))
	_add(_blob())
	_add(_blob_mini())
	_add(_aki())
	_add(_luisa())
	_add(EnemyFufu.new())
	_fufu_moves(get_def("fufu"))

# --- B: слизни ---------------------------------------------------------------

## Шлёпыш: обычно просто шлёпает, иногда плюётся липкой слизью (5 новых стаков — оглушение).
static func _shlep(id: String, title: String, hp_min: int, hp_max: int, size: float, k: float) -> EnemyDef:
	var d := EnemyDef.new(id, title, "B")
	d.texture_path = SPRITES + "slime_green.png"
	d.hp_min = hp_min
	d.hp_max = hp_max
	d.visual_scale = size
	var m := d.add(_mv("slap", "Шлепок", EnemyMove.Kind.ATTACK, 70))
	m.damage = roundi(16 * k)
	m = d.add(_mv("spit", "Липкий плевок", EnemyMove.Kind.ATTACK, 30))
	m.damage = roundi(8 * k)
	m.status = CardStatuses.STICKY_SLIME
	m.status_stacks = 2
	m.max_in_row = 1
	return d

## Пузырь: прикрывает и подлечивает соседей, сам бьёт слабо.
static func _bubble(id: String, title: String, hp_min: int, hp_max: int, size: float, k: float) -> EnemyDef:
	var d := EnemyDef.new(id, title, "B")
	d.texture_path = SPRITES + "slime_blue.png"
	d.hp_min = hp_min
	d.hp_max = hp_max
	d.visual_scale = size
	var m := d.add(_mv("wrap", "Обволочь", EnemyMove.Kind.DEFEND, 40))
	m.shield = roundi(18 * k)
	m.support_aim = "neighbour"
	m.intent = "Щит соседу"
	m = d.add(_mv("patch", "Подлатать", EnemyMove.Kind.HEAL, 35))
	m.heal = roundi(16 * k)
	m.support_aim = "wounded_other"
	m.intent = "Лечит соседа"
	m.cond = func(api: EnemyApi, me: Unit) -> bool: return api.most_wounded(me, false) != null
	m = d.add(_mv("poke", "Тычок", EnemyMove.Kind.ATTACK, 25))
	m.damage = roundi(9 * k)
	return d

## Кислотный: разъедает щиты всех героинь раньше, чем ударят остальные.
static func _acid(id: String, title: String, hp_min: int, hp_max: int, size: float, k: float) -> EnemyDef:
	var d := EnemyDef.new(id, title, "B")
	d.texture_path = SPRITES + "slime_purple.png"
	d.hp_min = hp_min
	d.hp_max = hp_max
	d.visual_scale = size
	var m := d.add(_mv("corrode", "Разъедание", EnemyMove.Kind.DEBUFF, 45))
	m.damage = roundi(8 * k)
	m.priority = 10
	m.max_in_row = 1
	m.intent = "Снять щиты + {d}"
	# Щиты снимаются до удара, поэтому урон наносит сам custom.
	m.manual_damage = true
	m.custom = func(api: EnemyApi, me: Unit, mv: EnemyMove) -> void:
		for h in api.heroes():
			if api.combat.shield_of(h) > 0:
				api.combat.remove_shield(h)
				api.say(h, "Щит разъеден!", CardCombat.COL_SHIELD)
		var f := api.front_hero()
		if f != null:
			api.hit(me, f, mv.damage)
	m = d.add(_mv("acid_spit", "Едкий плевок", EnemyMove.Kind.ATTACK, 55))
	m.damage = roundi(12 * k)
	m.status = CardStatuses.VULN
	m.status_turns = 1
	return d

## Большая блёба: крупная и толстая, на половине HP делится на две маленькие (EnemyBlob).
static func _blob() -> EnemyDef:
	var d := EnemyBlob.new("blob", "Большая блёба", "B")
	d.texture_path = SPRITES + "slime_pink.png"
	d.hp_min = 150
	d.hp_max = 166
	d.visual_scale = 1.65
	var m := d.add(_mv("crush", "Придавить", EnemyMove.Kind.ATTACK, 60))
	m.damage = 24
	m = d.add(_mv("swell", "Набухнуть", EnemyMove.Kind.DEFEND, 40))
	m.shield = 22
	m.max_in_row = 1
	return d

static func _blob_mini() -> EnemyDef:
	var d := EnemyDef.new("blob_mini", "Маленькая блёба", "B")
	d.texture_path = SPRITES + "slime_pink.png"
	d.hp_min = 30
	d.hp_max = 36
	d.visual_scale = 0.75
	var m := d.add(_mv("slap", "Шлепок", EnemyMove.Kind.ATTACK, 100))
	m.damage = 10
	return d

# --- A: слизнедевочки --------------------------------------------------------

## Аки: лечит и прикрывает подруг, очаровывает героинь (карты очарованной разыгрываются против своих).
static func _aki() -> EnemyDef:
	var d := EnemyDef.new("aki_enemy", "Аки", "A")
	d.char_id = "aki"
	d.drops_goop = false
	d.hp_min = 230
	d.hp_max = 250
	var m := d.add(_mv("lube", "Смазать подругу", EnemyMove.Kind.HEAL, 30))
	m.heal = 30
	m.support_aim = "wounded"
	m.intent = "Лечит"
	m.cond = func(api: EnemyApi, me: Unit) -> bool: return api.most_wounded(me) != null
	m = d.add(_mv("hug", "Упругие объятия", EnemyMove.Kind.DEFEND, 25))
	m.shield = 28
	m.support_aim = "front"
	m.intent = "Щит переднему"
	m = d.add(_mv("dance", "Танец на шесте", EnemyMove.Kind.DEBUFF, 25))
	m.aim = EnemyMove.Aim.RANDOM_HERO
	m.status = CardStatuses.CHARM
	m.status_turns = 1
	m.cooldown = 2
	m.max_in_row = 1
	m.intent = "Очарование"
	m.cond = func(api: EnemyApi, _me: Unit) -> bool:
		for h in api.heroes():
			if api.combat.has_status(h, CardStatuses.CHARM):
				return false
		return true
	m = d.add(_mv("cheer_slap", "Шлепок", EnemyMove.Kind.ATTACK, 20))
	m.damage = 14
	return d

## Луиса: обмазывает переднюю героиню липкой слизью (5 новых стаков — оглушение), потом порет.
static func _luisa() -> EnemyDef:
	var d := EnemyDef.new("luisa_enemy", "Луиса", "A")
	d.char_id = "luisa"
	d.drops_goop = false
	d.hp_min = 250
	d.hp_max = 270
	var m := d.add(_mv("tentacle", "Нежное щупальце", EnemyMove.Kind.ATTACK, 40))
	m.damage = 14
	m.status = CardStatuses.STICKY_SLIME
	m.status_stacks = 1
	m = d.add(_mv("deep", "Глубокое проникновение", EnemyMove.Kind.DEBUFF, 30))
	m.status = CardStatuses.STICKY_SLIME
	m.status_stacks = 3
	m.max_in_row = 1
	m.intent = "Липкая слизь +3"
	m = d.add(_mv("spank", "Влажная порка", EnemyMove.Kind.ATTACK, 30))
	m.intent = "Порка {d} × слизь"
	m.cond = func(api: EnemyApi, _me: Unit) -> bool:
		var f := api.front_hero()
		return f != null and api.combat.stacks(f, CardStatuses.STICKY_SLIME) >= 2
	# Удар за каждую липкую слизь на передней героине, слизь снимается.
	m.damage = 8
	m.manual_damage = true
	m.custom = func(api: EnemyApi, me: Unit, mv: EnemyMove) -> void:
		var f := api.front_hero()
		if f == null:
			return
		var n := maxi(1, api.combat.stacks(f, CardStatuses.STICKY_SLIME))
		api.combat.remove_stacks(f, CardStatuses.STICKY_SLIME)
		for i in range(n):
			if not CardCombat.is_alive(f) or not CardCombat.is_alive(me):
				break
			api.hit(me, f, mv.damage)
	return d

# --- S: Фуфу -----------------------------------------------------------------

static func _fufu_moves(d: EnemyDef) -> void:
	var m := d.add(_mv("press", "Придавить грудью", EnemyMove.Kind.ATTACK, 40))
	m.damage = 32
	m = d.add(_mv("wave", "Волна слизи", EnemyMove.Kind.ATTACK, 30))
	m.damage = 12
	m.aim = EnemyMove.Aim.ALL_HEROES
	m.status = CardStatuses.STICKY_SLIME
	m.status_stacks = 1
	m = d.add(_mv("bow", "Выход на поклон", EnemyMove.Kind.DEFEND, 30))
	m.shield = 40
	m.aim = EnemyMove.Aim.ALL_HEROES
	m.status = CardStatuses.WEAK
	m.status_turns = 1
	m.max_in_row = 1
	m.intent = "Защита + слабость всем"
