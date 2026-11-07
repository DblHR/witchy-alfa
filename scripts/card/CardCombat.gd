extends RefCounted
class_name CardCombat
## Ядро карточного боя без UI: команды, щиты, статусы, намерения врагов, урон и лечение.
## Ничего не знает ни про конкретные карты, ни про конкретные статусы, ни про героев:
##   - что делает карта, решают её эффекты (scripts/card/effects/, CardEffect);
##   - что делает статус, решает его описание (scripts/card/statuses/, CardStatus);
##   - пассивки героев подписываются на сигналы ниже (scripts/card/passives/, CardPassive).
## О том, что показать, сообщает сигналами (их слушает CardBattle).

## Всплывающая надпись над юнитом.
signal floated(unit: Unit, text: String, color: Color, font_size: int)
## По юниту прошёл удар (hp_damage — сколько дошло до HP, 0 — всё съел щит).
signal hurt(unit: Unit, hp_damage: int)
## Юнит погиб.
signal died(unit: Unit)
## Игровые события для пассивок. source может быть null (Горение и т.п.).
signal damage_dealt(source: Unit, target: Unit, amount: int)
signal card_played(card: CardInstance, caster: Unit)
## Карта просит сбросить N карт из руки на выбор игрока (рукой распоряжается CardBattle).
signal discard_requested(count: int)
## На юнита наложен статус (враги-боссы реагируют: Фуфу выплёвывает героиню от оглушения).
signal status_added(unit: Unit, id: String)
## Приманка добила врага (EffLure) — CardBattle решает, поймана ли героиня.
signal lure_kill(unit: Unit)

const LOW_HP_RATIO := 0.5          ## «мало HP» = не больше половины

const COL_DAMAGE := Color(1.0, 0.35, 0.35)
const COL_SHIELD := Color(0.65, 0.85, 1.0)
const COL_HEAL := Color(0.45, 1.0, 0.55)
const COL_STATUS := Color(1.0, 0.92, 0.45)

## Команды. Массивы общие с CardBattle (он их заполняет), здесь только читаются.
var heroes: Array[Unit] = []
var enemies: Array[Unit] = []

## Щиты: Unit -> int.
var shields: Dictionary = {}
## Статусы: Unit -> { id статуса: {"stacks": int, "turns": int} }.
var statuses: Dictionary = {}
## Намерения врагов на этот ход: Unit -> EnemyMove (выбирает EnemyDef, см. enemies/).
var intents: Dictionary = {}
## Сейчас ход врагов. Длительные статусы, наложенные на героинь в ход врагов, получают +1 ход,
## иначе они истекли бы в конце этого же раунда и не повлияли бы на ход игрока.
var enemy_phase := false
## Посох и еда забега (CardRelics): меняют урон карт героинь. null — без предметов.
var relics: CardRelics = null
## Надбавки к цене карт владельца: id героя -> +N. Активные и отложенные на след. ход.
var surcharge: Dictionary = {}
var pending_surcharge: Dictionary = {}
## Добавка к урону каждой карты (чёрная статуя).
var damage_bonus: int = 0

## Новая комната: всё боевое состояние с нуля.
func reset() -> void:
	shields.clear()
	statuses.clear()
	intents.clear()
	surcharge.clear()
	pending_surcharge.clear()
	enemy_phase = false

# --- Команды -----------------------------------------------------------------

static func is_alive(u: Unit) -> bool:
	return u != null and not u.is_dead and u.hp > 0

static func is_low_hp(u: Unit) -> bool:
	return u != null and float(u.hp) <= float(u.max_hp) * LOW_HP_RATIO

## Как в старом бою: слева «передний» — последний живой в списке, справа — первый.
## Проглоченная героиня не в строю: передней становится следующая.
func front_hero() -> Unit:
	for i in range(heroes.size() - 1, -1, -1):
		if is_alive(heroes[i]) and not has_status(heroes[i], CardStatuses.SWALLOWED):
			return heroes[i]
	return null

## Героини, которых враги могут выбрать целью (живые и не проглоченные), от задней к передней.
func targetable_heroes() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in heroes:
		if is_alive(u) and not has_status(u, CardStatuses.SWALLOWED):
			out.append(u)
	return out

## Героиня не может играть карты и ульту: оглушена или проглочена.
func hero_disabled(unit: Unit) -> bool:
	return unit != null and skips_turn(unit)

func front_enemy() -> Unit:
	for u in enemies:
		if is_alive(u):
			return u
	return null

func alive_heroes() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in heroes:
		if is_alive(u):
			out.append(u)
	return out

func alive_enemies() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in enemies:
		if is_alive(u):
			out.append(u)
	return out

func hero_by_id(id: String) -> Unit:
	if id == "":
		return null
	for u in heroes:
		if u != null and u.data != null and u.data.id == id:
			return u
	return null

func is_enemy(unit: Unit) -> bool:
	return enemies.has(unit)

## Очарованный враг бьёт ближайшего живого соседа по строю.
func charm_victim(enemy: Unit) -> Unit:
	var idx := enemies.find(enemy)
	var best: Unit = null
	var best_dist := 999
	for i in range(enemies.size()):
		var u := enemies[i]
		if u == enemy or not is_alive(u):
			continue
		var d := absi(i - idx)
		if d < best_dist:
			best_dist = d
			best = u
	return best

# --- Статусы -----------------------------------------------------------------

func stacks(unit: Unit, id: String) -> int:
	var s: Dictionary = statuses.get(unit, {}).get(id, {})
	return int(s.get("stacks", 0))

func turns(unit: Unit, id: String) -> int:
	var s: Dictionary = statuses.get(unit, {}).get(id, {})
	return int(s.get("turns", 0))

func has_status(unit: Unit, id: String) -> bool:
	return statuses.get(unit, {}).has(id)

## Наложить статус. Для «стаковых» важен stacks, для «длительных» — turns, для Горения — оба.
func add_status(unit: Unit, id: String, add_stacks: int, add_turns: int, quiet: bool = false) -> void:
	if not is_alive(unit):
		return
	var def := CardStatuses.get_status(id)
	if def == null:
		push_warning("CardCombat: неизвестный статус «%s»" % id)
		return
	if enemy_phase and add_turns > 0 and def.kind == CardStatus.Kind.DURATION and heroes.has(unit):
		add_turns += 1
	var per_unit: Dictionary = statuses.get(unit, {})
	var s: Dictionary = per_unit.get(id, {"stacks": 0, "turns": 0})
	var old := int(s["stacks"])
	def.merge(s, add_stacks, add_turns)
	per_unit[id] = s
	statuses[unit] = per_unit
	if not quiet:
		floated.emit(unit, def.float_text(add_stacks, add_turns), def.color, 26)
	def.on_added(self, unit, old, s)
	_cleanup(unit, id)
	status_added.emit(unit, id)

## Оглушить на ход (героиню в ход врагов — до конца её следующего хода).
func stun(unit: Unit) -> void:
	if not is_alive(unit):
		return
	add_status(unit, CardStatuses.STUN, 0, 1, true)
	floated.emit(unit, "Оглушена!" if heroes.has(unit) else "Оглушён!", COL_STATUS, 26)

## Снять стаки (n <= 0 — все). Возвращает, сколько снято.
func remove_stacks(unit: Unit, id: String, n: int = 0, quiet: bool = false) -> int:
	if not has_status(unit, id):
		return 0
	var s: Dictionary = statuses[unit][id]
	var have := int(s["stacks"])
	var take := have if n <= 0 else mini(n, have)
	if take <= 0:
		return 0
	s["stacks"] = have - take
	var def := CardStatuses.get_status(id)
	if not quiet:
		floated.emit(unit, "%s −%d" % [def.title, take], def.color, 26)
	_cleanup(unit, id)
	return take

func add_turns(unit: Unit, id: String, n: int) -> void:
	if not has_status(unit, id):
		return
	var s: Dictionary = statuses[unit][id]
	s["turns"] = int(s["turns"]) + n
	floated.emit(unit, "%s +%d х." % [CardStatuses.get_status(id).title, n], CardStatuses.get_status(id).color, 26)

func trigger_status(unit: Unit, id: String) -> void:
	if not has_status(unit, id):
		return
	CardStatuses.get_status(id).trigger(self, unit, statuses[unit][id])
	_cleanup(unit, id)

func _cleanup(unit: Unit, id: String) -> void:
	var per_unit: Dictionary = statuses.get(unit, {})
	if per_unit.has(id) and not CardStatuses.get_status(id).is_active(per_unit[id]):
		per_unit.erase(id)

## Пары [CardStatus, данные] — копия, чтобы хуки могли менять статусы во время обхода.
func _status_list(unit: Unit) -> Array:
	var out: Array = []
	var per_unit: Dictionary = statuses.get(unit, {})
	for id in per_unit.keys():
		out.append([CardStatuses.get_status(id), per_unit[id]])
	return out

func skips_turn(unit: Unit) -> bool:
	for pair in _status_list(unit):
		if pair[0].skips_turn:
			return true
	return false

func is_charmed(unit: Unit) -> bool:
	for pair in _status_list(unit):
		if pair[0].charms:
			return true
	return false

func status_text(unit: Unit) -> String:
	var parts := PackedStringArray()
	for pair in _status_list(unit):
		parts.append(pair[0].label(pair[1]))
	return ", ".join(parts)

func _run_hook(units: Array, hook: StringName) -> void:
	for u in units:
		for pair in _status_list(u):
			if not is_alive(u):
				break
			pair[0].call(hook, self, u, pair[1])
			_cleanup(u, pair[0].id)

# --- Ход ---------------------------------------------------------------------

## Цена карты с учётом надбавок владельца.
func effective_cost(card: CardInstance) -> int:
	if card.owner_id == "":
		return card.cost
	return card.cost + int(surcharge.get(card.owner_id, 0))

## Начало хода игрока: отложенные надбавки к цене вступают в силу.
func begin_player_turn() -> void:
	surcharge = pending_surcharge.duplicate()
	pending_surcharge.clear()

func end_player_turn() -> void:
	_run_hook(alive_heroes() + alive_enemies(), &"on_player_turn_end")

## Каждый живой враг заранее выбирает ход (EnemyDef.choose) — игрок видит его намерение.
func roll_intents(api: EnemyApi) -> void:
	intents.clear()
	for u in alive_enemies():
		roll_intent(api, u)

func roll_intent(api: EnemyApi, u: Unit) -> void:
	if u.enemy_def == null or not is_alive(u):
		intents.erase(u)
		return
	var move := u.enemy_def.choose(api, u)
	u.enemy_def.on_chosen(u, move)
	intents[u] = move

## Урон с учётом статусов атакующего (Слабость, Усиление): так игрок видит реальный удар.
func effective_damage(unit: Unit, amount: int) -> int:
	return _modify_dealt(unit, amount)

## Начало хода врагов: статусы вроде Горения срабатывают. true — кто-то получил урон.
func enemy_turn_start() -> bool:
	var before := _damage_events
	_run_hook(alive_enemies() + alive_heroes(), &"on_enemy_turn_start")
	return _damage_events != before

## Конец раунда (после ударов врагов): длительные статусы теряют ход.
func end_round() -> void:
	_run_hook(alive_enemies() + alive_heroes(), &"on_round_end")

func clear_shields() -> void:
	shields.clear()

# --- Карты -------------------------------------------------------------------

## Применяет эффекты карты (или ульты) от имени caster к целям, выбранным при розыгрыше.
## mirrored — карту разыгрывает очарованная героиня (урон по своим, поддержка врагам).
func play_card(card: CardInstance, caster: Unit, targets: Array[Unit], mirrored: bool = false) -> void:
	var ctx := CardContext.new(self, caster, targets, card)
	ctx.mirrored = mirrored
	for e in card.effects:
		if e != null:
			e.apply(ctx)
	card_played.emit(card, caster)

# --- Урон, щит, лечение ------------------------------------------------------

var _damage_events := 0

func _modify_dealt(source: Unit, amount: int) -> int:
	if source == null:
		return amount
	for pair in _status_list(source):
		amount = pair[0].modify_dealt(self, source, pair[1], amount)
	return amount

## Урон от source по target. from_card — урон картой (на него действует чёрная статуя;
## только картам героинь и общим, не врагам).
## Учитывает статусы атакующего (Слабость, Усиление) и цели (Уязвимость), затем щит.
func deal_damage(source: Unit, target: Unit, amount: int, from_card: bool = true) -> void:
	if not is_alive(target) or amount <= 0:
		return
	var dmg := amount + (damage_bonus if from_card and not is_enemy(source) else 0)
	dmg = _modify_dealt(source, dmg)
	if from_card and relics != null and not is_enemy(source):
		dmg = relics.modify_hero_damage(self, target, dmg)
		if dmg <= 0:
			return
	for pair in _status_list(target):
		dmg = pair[0].modify_taken(self, target, pair[1], dmg)
	_damage_events += 1
	var shield_before := shield_of(target)
	apply_damage(target, dmg)
	damage_dealt.emit(source, target, dmg)
	var absorbed := mini(shield_before, dmg)
	if absorbed > 0 and source != null:
		for pair in _status_list(target):
			pair[0].on_shield_hit(self, target, pair[1], source, absorbed)

## Урон сначала съедает щит, остаток идёт в HP. Статусы здесь не учитываются.
func apply_damage(unit: Unit, amount: int) -> void:
	var shield := int(shields.get(unit, 0))
	var absorbed := mini(shield, amount)
	if absorbed > 0:
		shields[unit] = shield - absorbed
	var dmg := amount - absorbed
	var killed := false
	if dmg > 0:
		killed = unit.take_damage(dmg)
	hurt.emit(unit, dmg)
	if dmg > 0 and not killed:
		for pair in _status_list(unit):
			pair[0].on_hp_lost(self, unit, pair[1], dmg)
			_cleanup(unit, pair[0].id)
	if dmg > 0:
		floated.emit(unit, "-%d" % dmg, COL_DAMAGE, 34)
	if absorbed > 0:
		floated.emit(unit, "щит -%d" % absorbed, COL_SHIELD, 26)
	if killed:
		statuses.erase(unit)
		died.emit(unit)

func shield_of(unit: Unit) -> int:
	return int(shields.get(unit, 0))

func add_shield(unit: Unit, amount: int) -> void:
	if not is_alive(unit) or amount <= 0:
		return
	shields[unit] = shield_of(unit) + amount
	floated.emit(unit, "+%d щит" % amount, COL_SHIELD, 26)

## Лечение; возвращает, сколько HP реально восстановлено.
func heal(unit: Unit, amount: int) -> int:
	if not is_alive(unit) or amount <= 0:
		return 0
	var before := unit.hp
	unit.hp = mini(unit.max_hp, unit.hp + amount)
	floated.emit(unit, "+%d HP" % (unit.hp - before), COL_HEAL, 26)
	return unit.hp - before

func add_surcharge(owner_id: String, amount: int) -> void:
	if owner_id != "":
		pending_surcharge[owner_id] = int(pending_surcharge.get(owner_id, 0)) + amount
