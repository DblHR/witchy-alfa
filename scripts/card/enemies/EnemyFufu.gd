extends EnemyDef
class_name EnemyFufu
## Фуфу — босс 1-го этажа. Фазы на каждые 25% потерянного HP (намерение меняется сразу):
##   75% — призывает двух случайных мини-слизней;
##   50% — глотает переднюю героиню. Выплюнет, если Фуфу оглушить или за это время нанести ей
##         SPIT_DAMAGE_SHARE от макс. HP. Иначе на своём следующем ходу «переваривает»:
##         героиня получает DIGEST_SHARE от своего макс. HP (щит не спасает) и выходит наружу;
##   25% — зовёт на помощь Аки и Луису.
## Убить Фуфу = победа: все призванные исчезают, добивать их не нужно.

const PHASES: Array[float] = [0.75, 0.5, 0.25]
const PHASE_MOVES: Array[String] = ["summon_minis", "swallow", "summon_girls"]
const MINI_POOL: Array[String] = ["mini_shlep", "mini_bubble", "mini_acid", "blob_mini"]
const GIRLS: Array[String] = ["aki_enemy", "luisa_enemy"]
const SPIT_DAMAGE_SHARE := 0.10
const DIGEST_SHARE := 0.60

var _phase_moves: Dictionary = {}
var _digest: EnemyMove

func _init() -> void:
	super("fufu", "Фуфу", "S")
	char_id = "fufu"
	drops_goop = true
	hp_min = 520
	hp_max = 520

	var m := EnemyMove.new("summon_minis", "Позвать малышей", EnemyMove.Kind.SUMMON)
	m.intent = "Призыв слизней"
	m.custom = func(api: EnemyApi, me: Unit, _mv: EnemyMove) -> void:
		var ids: Array = []
		for i in range(2):
			ids.append(MINI_POOL[api.rng.randi_range(0, MINI_POOL.size() - 1)])
		api.summon(ids, 0, me)
	_phase_moves["summon_minis"] = m

	m = EnemyMove.new("swallow", "Проглотить", EnemyMove.Kind.SWALLOW)
	m.custom = func(api: EnemyApi, me: Unit, _mv: EnemyMove) -> void:
		swallow(api, me)
	_phase_moves["swallow"] = m

	m = EnemyMove.new("summon_girls", "Девочки, помогите!", EnemyMove.Kind.SUMMON)
	m.intent = "Зовёт Аки и Луису"
	m.custom = func(api: EnemyApi, me: Unit, _mv: EnemyMove) -> void:
		api.summon(GIRLS, 0, me)
	_phase_moves["summon_girls"] = m

	_digest = EnemyMove.new("digest", "Переварить", EnemyMove.Kind.DIGEST)
	_digest.custom = func(api: EnemyApi, me: Unit, _mv: EnemyMove) -> void:
		digest(api, me)

## Урон «переваривания» по героине.
static func digest_damage(hero: Unit) -> int:
	return roundi(float(hero.max_hp) * DIGEST_SHARE) if hero != null else 0

static func is_phase_move(move: EnemyMove) -> bool:
	return move != null and PHASE_MOVES.has(move.id)

func choose(api: EnemyApi, me: Unit) -> EnemyMove:
	if me.ai.get("swallowed") != null:
		return _digest
	var pending: Array = me.ai.get("pending", [])
	if not pending.is_empty():
		return _phase_moves[pending[0]]
	return super.choose(api, me)

func act(api: EnemyApi, me: Unit, move: EnemyMove) -> void:
	if is_phase_move(move):
		var pending: Array = me.ai.get("pending", [])
		pending.erase(move.id)
		me.ai["pending"] = pending
	super.act(api, me, move)

func on_hurt(api: EnemyApi, me: Unit, amount: int) -> void:
	if not CardCombat.is_alive(me):
		return
	# Проглоченная героиня: копим урон — набрали долю макс. HP, Фуфу выплёвывает.
	if me.ai.get("swallowed") != null:
		me.ai["swallow_taken"] = int(me.ai.get("swallow_taken", 0)) + amount
		if int(me.ai["swallow_taken"]) >= ceili(float(me.max_hp) * SPIT_DAMAGE_SHARE):
			spit(api, me)
	# Пороги фаз.
	var done: Array = me.ai.get("phases_done", [])
	var pending: Array = me.ai.get("pending", [])
	var added := false
	for i in range(PHASES.size()):
		if done.has(i) or float(me.hp) > float(me.max_hp) * PHASES[i]:
			continue
		done.append(i)
		pending.append(PHASE_MOVES[i])
		added = true
	me.ai["phases_done"] = done
	me.ai["pending"] = pending
	# Новая фаза — намерение меняется сразу (если она сейчас не глотает/не переваривает).
	if added and api.combat.intents.has(me):
		var cur: EnemyMove = api.combat.intents[me]
		if not is_phase_move(cur) and cur != _digest:
			api.reroll(me)

func on_status(api: EnemyApi, me: Unit, status_id: String) -> void:
	if status_id == CardStatuses.STUN and me.ai.get("swallowed") != null:
		spit(api, me)

func on_death(api: EnemyApi, me: Unit) -> void:
	if me.ai.get("swallowed") != null:
		spit(api, me)
	for u in api.allies_of(me):
		api.vanish(u)

# --- Проглотить / выплюнуть / переварить ------------------------------------

func swallow(api: EnemyApi, me: Unit) -> void:
	var hero := api.front_hero()
	if hero == null:
		return
	api.combat.add_status(hero, CardStatuses.SWALLOWED, 1, 0)
	me.ai["swallowed"] = hero
	me.ai["swallow_taken"] = 0
	api.set_hero_hidden(hero, true)
	api.say(me, "Ам!", Color(1.0, 0.45, 0.8))

func spit(api: EnemyApi, me: Unit) -> void:
	var hero: Unit = me.ai.get("swallowed")
	if hero == null:
		return
	me.ai.erase("swallowed")
	me.ai.erase("swallow_taken")
	api.combat.remove_stacks(hero, CardStatuses.SWALLOWED, 0, true)
	api.set_hero_hidden(hero, false)
	api.say(hero, "Выплюнута!", CardCombat.COL_HEAL)
	# Если уже собиралась переваривать — выбирает другое действие.
	if CardCombat.is_alive(me) and api.combat.intents.get(me) == _digest:
		api.reroll(me)

func digest(api: EnemyApi, me: Unit) -> void:
	var hero: Unit = me.ai.get("swallowed")
	if hero == null:
		return
	var dmg := digest_damage(hero)
	me.ai.erase("swallowed")
	me.ai.erase("swallow_taken")
	api.combat.remove_stacks(hero, CardStatuses.SWALLOWED, 0, true)
	api.set_hero_hidden(hero, false)
	api.combat.remove_shield(hero)
	api.combat.apply_damage(hero, dmg)
