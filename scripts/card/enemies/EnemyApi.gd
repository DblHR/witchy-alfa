extends RefCounted
class_name EnemyApi
## Всё, чем враг может действовать: правила боя (CardCombat) и сцена (призыв, исчезновение,
## «проглотить героиню»). Сцену представляет CardBattle — он реализует методы enemy_*.
## Ходы врагов (EnemyMove) и их описания (EnemyDef) работают только через этот объект.

var combat: CardCombat
var battle: Object      ## CardBattle: enemy_summon / enemy_vanish / enemy_set_hero_hidden / enemy_reroll
var rng: RandomNumberGenerator

func _init(p_combat: CardCombat, p_battle: Object, p_rng: RandomNumberGenerator) -> void:
	combat = p_combat
	battle = p_battle
	rng = p_rng

# --- Числа -------------------------------------------------------------------

## Число хода с силой этажа врага.
static func scaled(me: Unit, base: int) -> int:
	return roundi(float(base) * float(me.ai.get("mult", 1.0)) * CardBalance.enemy_power_mult)

## Урон за удар, который увидит игрок (Слабость и т.п. уже учтены).
func shown_damage(me: Unit, move: EnemyMove) -> int:
	if move.kind == EnemyMove.Kind.DIGEST:
		var hero: Unit = me.ai.get("swallowed")
		return EnemyFufu.digest_damage(hero) if hero != null else 0
	return combat.effective_damage(me, scaled(me, move.damage))

# --- Кого видеть -------------------------------------------------------------

func heroes() -> Array[Unit]:
	return combat.targetable_heroes()

func front_hero() -> Unit:
	return combat.front_hero()

func allies_of(me: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in combat.alive_enemies():
		if u != me:
			out.append(u)
	return out

## Ближайший живой сосед по строю (или null).
func neighbour_of(me: Unit) -> Unit:
	return combat.charm_victim(me)

## Самый раненый союзник (по доле HP), включая себя. null — все целы.
func most_wounded(me: Unit, include_self: bool = true) -> Unit:
	var best: Unit = null
	var best_ratio := 1.0
	for u in combat.alive_enemies():
		if u == me and not include_self:
			continue
		var r := float(u.hp) / float(maxi(1, u.max_hp))
		if r < best_ratio - 0.001:
			best_ratio = r
			best = u
	return best

func aim_targets(me: Unit, aim: EnemyMove.Aim) -> Array[Unit]:
	var hs := heroes()
	var out: Array[Unit] = []
	if hs.is_empty():
		return out
	match aim:
		EnemyMove.Aim.ALL_HEROES:
			out = hs
		EnemyMove.Aim.RANDOM_HERO:
			out.append(hs[rng.randi_range(0, hs.size() - 1)])
		EnemyMove.Aim.BACK_HERO:
			out.append(hs[0])
		EnemyMove.Aim.LOWEST_HERO:
			var low := hs[0]
			for u in hs:
				if u.hp < low.hp:
					low = u
			out.append(low)
		_:
			var f := front_hero()
			if f != null:
				out.append(f)
	return out

func support_targets(me: Unit, how: String) -> Array[Unit]:
	var out: Array[Unit] = []
	match how:
		"neighbour":
			var n := neighbour_of(me)
			out.append(n if n != null else me)
		"wounded":
			var w := most_wounded(me)
			out.append(w if w != null else me)
		"wounded_other":
			var w2 := most_wounded(me, false)
			if w2 == null:
				w2 = neighbour_of(me)
			out.append(w2 if w2 != null else me)
		"front":
			var f := combat.front_enemy()
			out.append(f if f != null else me)
		"all":
			out = combat.alive_enemies()
		_:
			out.append(me)
	return out

# --- Действия ----------------------------------------------------------------

## Удар врага по героине (щит съедает урон; статусы атакующего и цели учтены).
func hit(me: Unit, target: Unit, base_damage: int) -> void:
	combat.deal_damage(me, target, scaled(me, base_damage), false)

## Выполнить ход: сначала поля (урон, статус, щит, лечение), потом custom.
func execute(me: Unit, move: EnemyMove) -> void:
	if move.damage > 0 and not move.manual_damage:
		var targets := aim_targets(me, move.aim)
		for t in targets:
			for i in range(maxi(1, move.hits)):
				if not CardCombat.is_alive(me) or not CardCombat.is_alive(t):
					break
				hit(me, t, move.damage)
			if move.status != "" and CardCombat.is_alive(t):
				combat.add_status(t, move.status, move.status_stacks, move.status_turns)
	elif move.status != "":
		for t in aim_targets(me, move.aim):
			combat.add_status(t, move.status, move.status_stacks, move.status_turns)
	if move.shield > 0:
		for u in support_targets(me, move.support_aim):
			combat.add_shield(u, scaled(me, move.shield))
	if move.heal > 0:
		for u in support_targets(me, move.support_aim):
			combat.heal(u, scaled(me, move.heal))
	if move.custom.is_valid():
		move.custom.call(self, me, move)

# --- Сцена -------------------------------------------------------------------

## Призвать врагов по id (EnemyDefs). hp > 0 — задать HP вместо обычного. Возвращает новых.
func summon(ids: Array, hp: int = 0, near: Unit = null) -> Array[Unit]:
	var out: Array[Unit] = []
	out.assign(battle.call("enemy_summon", ids, hp, near))
	return out

## Убрать врага без смерти и добычи (призванные исчезают вместе с боссом).
func vanish(u: Unit) -> void:
	battle.call("enemy_vanish", u)

func set_hero_hidden(hero: Unit, hidden: bool) -> void:
	battle.call("enemy_set_hero_hidden", hero, hidden)

## Выбрать врагу новое намерение прямо сейчас.
func reroll(me: Unit) -> void:
	battle.call("enemy_reroll", me)

func say(u: Unit, text: String, color: Color = CardCombat.COL_STATUS) -> void:
	combat.floated.emit(u, text, color, 28)
