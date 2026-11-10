extends RefCounted
class_name CardRunStats
## Статистика карточного забега для итогового окна: кто сколько нанёс урона (картами и
## эффектами), вылечил, дал щита (и сколько щита реально поглотило удары), сколько карт сыграно
## и сброшено, кого победили. Копится весь забег (все бои).
##
## Кто действует, CardCombat знает по combat.credit: id героини, «common» (общие карты),
## «lure». Горение и прочие статусы запоминают, кто их наложил (s["src"]).

## Особые «авторы» действий (не героини).
const COMMON := "common"
const LURE := "lure"
const NAMES := {COMMON: "Общие карты", LURE: "Приманка"}

## автор -> {dmg_card, dmg_effect, kills, heal, shield, shield_eff, played, ults}
var actors: Dictionary = {}
## Порядок строк в таблице.
var order: Array[String] = []
## героиня -> {taken, absorbed, deaths}
var heroes: Dictionary = {}
## id врага (EnemyDef) -> побеждено
var kills_by_enemy: Dictionary = {}
## Щит на юните: очередь [автор, сколько] — поглощение засчитывается тем, кто дал щит раньше.
var _shield_ledger: Dictionary = {}

var cards_played := 0
var cards_discarded_turn := 0   ## не сыграны и ушли в сброс в конце хода
var cards_discarded_effect := 0 ## сброшены картами («Влажный поцелуй»)
var cards_sleeved := 0
var cards_burned := 0           ## сгорели до конца забега (приманка)
var potions: Array[String] = []
var turns := 0
var battles_won := 0
var rooms_done := 0
var gold_start := 0
var start_msec := 0
var best_hit := 0
var best_hit_by := ""
var best_heal := 0
var best_heal_by := ""

func _init() -> void:
	start_msec = Time.get_ticks_msec()

func _a(id: String) -> Dictionary:
	if not actors.has(id):
		actors[id] = {"dmg_card": 0, "dmg_effect": 0, "kills": 0, "heal": 0, "shield": 0, "shield_eff": 0, "played": 0, "ults": 0}
		order.append(id)
	return actors[id]

func _h(id: String) -> Dictionary:
	if not heroes.has(id):
		heroes[id] = {"taken": 0, "absorbed": 0, "deaths": 0}
	return heroes[id]

## Автор розыгрыша карты.
static func credit_for_card(card: CardInstance) -> String:
	if card.owner_id != "":
		return card.owner_id
	if card.id == "lure":
		return LURE
	return COMMON

static func actor_name(id: String) -> String:
	if NAMES.has(id):
		return String(NAMES[id])
	var d: CharacterData = CharDB.get_by_id(id) if CharDB != null else null
	return d.display_name if d != null else id

# --- Хуки из CardCombat ------------------------------------------------------

func on_damage(credit: String, dmg: int, by_card: bool, killed: bool, card_title: String) -> void:
	if credit == "" or dmg <= 0:
		return
	var a := _a(credit)
	a["dmg_card" if by_card else "dmg_effect"] = int(a["dmg_card" if by_card else "dmg_effect"]) + dmg
	if killed:
		a["kills"] = int(a["kills"]) + 1
	if dmg > best_hit:
		best_hit = dmg
		var who := actor_name(credit)
		var what := card_title if card_title != "" else "эффект"
		best_hit_by = what if what == who else "%s (%s)" % [what, who]

func on_taken(hero_id: String, dmg: int) -> void:
	if dmg > 0:
		_h(hero_id)["taken"] = int(_h(hero_id)["taken"]) + dmg

func on_heal(credit: String, amount: int) -> void:
	if credit == "" or amount <= 0:
		return
	var a := _a(credit)
	a["heal"] = int(a["heal"]) + amount
	if amount > best_heal:
		best_heal = amount
		best_heal_by = actor_name(credit)

func on_shield(credit: String, unit: Unit, amount: int) -> void:
	if amount <= 0:
		return
	var who := credit if credit != "" else "_other"
	if credit != "":
		_a(credit)["shield"] = int(_a(credit)["shield"]) + amount
	var q: Array = _shield_ledger.get(unit, [])
	q.append([who, amount])
	_shield_ledger[unit] = q

## Щит поглотил удар: засчитываем «эффективный щит» тем, кто его дал (по очереди).
func on_shield_absorbed(unit: Unit, absorbed: int, unit_is_hero: bool) -> void:
	if absorbed <= 0:
		return
	if unit_is_hero:
		_h(unit.data.id)["absorbed"] = int(_h(unit.data.id)["absorbed"]) + absorbed
	var q: Array = _shield_ledger.get(unit, [])
	var left := absorbed
	while left > 0 and not q.is_empty():
		var e: Array = q[0]
		var take := mini(left, int(e[1]))
		if String(e[0]) != "_other":
			_a(String(e[0]))["shield_eff"] = int(_a(String(e[0]))["shield_eff"]) + take
		e[1] = int(e[1]) - take
		left -= take
		if int(e[1]) <= 0:
			q.pop_front()
	_shield_ledger[unit] = q

## Щиты сгорели (начало хода) или сняты (кислота).
func on_shields_cleared(unit: Unit = null) -> void:
	if unit == null:
		_shield_ledger.clear()
	else:
		_shield_ledger.erase(unit)

# --- Хуки из CardBattle ------------------------------------------------------

func on_card_played(card: CardInstance, is_ult: bool) -> void:
	var a := _a(credit_for_card(card))
	if is_ult:
		a["ults"] = int(a["ults"]) + 1
	else:
		a["played"] = int(a["played"]) + 1
		cards_played += 1

func on_hero_died(hero_id: String) -> void:
	_h(hero_id)["deaths"] = int(_h(hero_id)["deaths"]) + 1

func on_enemy_killed(enemy_id: String) -> void:
	kills_by_enemy[enemy_id] = int(kills_by_enemy.get(enemy_id, 0)) + 1

# --- Итоговый текст ----------------------------------------------------------

func total(key: String) -> int:
	var n := 0
	for id in actors:
		n += int(actors[id][key])
	return n

static func _fmt_time(ms: int) -> String:
	var s := ms / 1000
	return "%d:%02d" % [s / 60, s % 60]

## BBCode для RichTextLabel итогового окна. relics — CardRelics забега, summary — строки прогресса.
func to_bbcode(relics: CardRelics, summary: PackedStringArray, gold_now: int, room_text: String) -> String:
	var t := ""
	var gold := "[color=#ffd36b]"
	var dim := "[color=#c9b8d8]"
	t += "[font_size=30]%sИтог забега[/color][/font_size]\n" % gold
	for line in summary:
		t += "• %s\n" % line
	t += "%s%s · боёв выиграно: %d · ходов: %d · время: %s · золото: %+d[/color]\n\n" % [
		dim, room_text, battles_won, turns, _fmt_time(Time.get_ticks_msec() - start_msec), gold_now - gold_start]

	# --- Таблица по героиням ---
	var all_dmg := total("dmg_card") + total("dmg_effect")
	t += "[font_size=26]%sУрон, лечение, щиты[/color][/font_size]\n" % gold
	t += "[table=8]"
	for h in ["", "Урон картами", "Эффектами", "Всего", "Добито", "Вылечено", "Щит: сработал / дан", "Карт / ульт"]:
		t += "[cell][b]%s[/b]   [/cell]" % h
	for id in order:
		var a: Dictionary = actors[id]
		var dmg := int(a["dmg_card"]) + int(a["dmg_effect"])
		var share := "" if all_dmg <= 0 or dmg <= 0 else " (%d%%)" % roundi(100.0 * dmg / all_dmg)
		var shield := "—" if int(a["shield"]) <= 0 else "%d / %d" % [int(a["shield_eff"]), int(a["shield"])]
		t += "[cell]%s   [/cell][cell]%d[/cell][cell]%d[/cell][cell][b]%d[/b]%s[/cell][cell]%d[/cell][cell]%d[/cell][cell]%s[/cell][cell]%d / %d[/cell]" % [
			actor_name(id), int(a["dmg_card"]), int(a["dmg_effect"]), dmg, share, int(a["kills"]), int(a["heal"]), shield, int(a["played"]), int(a["ults"])]
	t += "[cell][b]Всего[/b][/cell][cell]%d[/cell][cell]%d[/cell][cell][b]%d[/b][/cell][cell]%d[/cell][cell]%d[/cell][cell]%d / %d[/cell][cell]%d[/cell]" % [
		total("dmg_card"), total("dmg_effect"), all_dmg, total("kills"), total("heal"), total("shield_eff"), total("shield"), cards_played]
	t += "[/table]\n"
	if total("shield") > 0:
		t += "%sЭффективность щитов: %d%% (остальное сгорело в начале хода)[/color]\n" % [dim, roundi(100.0 * total("shield_eff") / total("shield"))]
	t += "\n"

	# --- Что получили героини ---
	if not heroes.is_empty():
		t += "[font_size=26]%sПолучено героинями[/color][/font_size]\n" % gold
		for id in heroes:
			var h: Dictionary = heroes[id]
			t += "• %s: урон по HP %d, щит принял %d%s\n" % [actor_name(id), int(h["taken"]), int(h["absorbed"]), (", падала %d раз" % int(h["deaths"])) if int(h["deaths"]) > 0 else ""]
		t += "\n"

	# --- Карты ---
	t += "[font_size=26]%sКарты[/color][/font_size]\n" % gold
	t += "• Сыграно: %d · сброшено в конце хода: %d · сброшено эффектами: %d · отложено в рукав: %d · сгорело до конца забега: %d\n" % [
		cards_played, cards_discarded_turn, cards_discarded_effect, cards_sleeved, cards_burned]
	if best_hit > 0:
		t += "• Самый сильный удар: %d — %s\n" % [best_hit, best_hit_by]
	if best_heal > 0:
		t += "• Самое большое лечение: %d — %s\n" % [best_heal, best_heal_by]
	t += "\n"

	# --- Предметы ---
	var items: Array[String] = []
	if relics != null:
		for id in relics.items:
			items.append("%s — %s" % [RunItems.get_item_name(id), relics.stats_text(id).trim_prefix("За этот забег: ")])
		for pair in [[CardRelics.STATUE_WHITE, "Белая статуя"], [CardRelics.STATUE_BLACK, "Чёрная статуя"], [CardRelics.RAGE, "Фиал ярости"], ["slime_potion", "Зелье слаймов"]]:
			if relics.stats.has(pair[0]):
				items.append("%s — %s" % [pair[1], relics.stats_text(pair[0]).trim_prefix("За этот забег: ")])
	if not potions.is_empty():
		var names := PackedStringArray()
		for p in potions:
			names.append(RunItems.get_potion_name(p))
		items.append("Выпито зелий: %s" % ", ".join(names))
	if not items.is_empty():
		t += "[font_size=26]%sПосох, еда, статуи, зелья[/color][/font_size]\n" % gold
		for line in items:
			t += "• %s\n" % line
		t += "\n"

	# --- Враги ---
	if not kills_by_enemy.is_empty():
		t += "[font_size=26]%sПобеждено врагов: %d[/color][/font_size]\n" % [gold, total_kills()]
		var parts := PackedStringArray()
		for id in kills_by_enemy:
			parts.append("%s ×%d" % [EnemyDefs.title_of(String(id)), int(kills_by_enemy[id])])
		t += "• " + ", ".join(parts) + "\n"
	return t

func total_kills() -> int:
	var n := 0
	for id in kills_by_enemy:
		n += int(kills_by_enemy[id])
	return n
