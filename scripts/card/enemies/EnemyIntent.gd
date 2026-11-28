extends RefCounted
class_name EnemyIntent
## Намерение врага значками (как в Slay the Spire): над врагом — ряд значков с числами,
## при наведении на значок — что он значит (+ окошко со статусом, если враг его повесит).
##
## Значки — assets/ui/battle/intent_*.png. Нет картинки (например, призыва) — вместо значка надпись.
## Одна «часть» намерения — словарь:
##   icon   — путь к картинке (или "")
##   label  — надпись вместо значка, если картинки нет
##   text   — число рядом со значком (может быть пустым)
##   color  — цвет числа
##   tip    — подсказка при наведении (bbcode)
##   status — id статуса, описание которого показать рядом (или "")

const ICON_ATTACK := "res://assets/ui/battle/intent_attack.png"
const ICON_SHIELD := "res://assets/ui/battle/intent_apply_shield.png"
const ICON_POSITIVE := "res://assets/ui/battle/intent_apply_positive.png"
const ICON_NEGATIVE := "res://assets/ui/battle/intent_apply_negative.png"
## Призыв: картинки пока нет — появится, как только файл ляжет сюда.
const ICON_SUMMON := "res://assets/ui/battle/intent_summon.png"
const ICON_STUN := "res://assets/ui/status/stun_status.png"

const COL_NUMBER := Color(1.0, 1.0, 1.0)
const COL_WEAKENED := Color(0.62, 0.78, 1.0)   ## удар ослаблен (Слабость) — число голубое
const COL_CHARM := Color(1.0, 0.55, 0.85)

## Статусы, которые враги вешают на себя / своих (остальные — на отряд, это «негативный эффект»).
const POSITIVE_STATUSES := [CardStatuses.EMPOWER, CardStatuses.HEAT_BODY]

const AIM_TEXT := {
	EnemyMove.Aim.FRONT_HERO: "переднему персонажу",
	EnemyMove.Aim.ALL_HEROES: "каждому персонажу",
	EnemyMove.Aim.RANDOM_HERO: "случайному персонажу",
	EnemyMove.Aim.BACK_HERO: "заднему персонажу",
	EnemyMove.Aim.LOWEST_HERO: "самому раненому персонажу",
}
const AIM_TARGET := {
	EnemyMove.Aim.FRONT_HERO: "на переднего персонажа",
	EnemyMove.Aim.ALL_HEROES: "на всех персонажей",
	EnemyMove.Aim.RANDOM_HERO: "на случайного персонажа",
	EnemyMove.Aim.BACK_HERO: "на заднего персонажа",
	EnemyMove.Aim.LOWEST_HERO: "на самого раненого персонажа",
}
const SUPPORT_TEXT := {
	"self": "себе",
	"neighbour": "соседу",
	"wounded": "самому раненому из своих",
	"wounded_other": "самому раненому соседу",
	"front": "переднему из своих",
	"all": "всем своим",
}

static func _part(icon: String, label: String, text: String, tip: String, color: Color = COL_NUMBER, status: String = "") -> Dictionary:
	return {"icon": icon, "label": label, "text": text, "tip": tip, "color": color, "status": status}

static func _head(move: EnemyMove) -> String:
	return "[b]%s[/b]\n" % move.title if move.title != "" else ""

## Части намерения врага me с ходом move.
static func parts(api: EnemyApi, me: Unit, move: EnemyMove) -> Array:
	var out: Array = []
	var combat := api.combat
	if combat.skips_turn(me):
		out.append(_part(ICON_STUN, "Оглушён", "", "[b]Оглушение[/b]\nПротивник оглушён и пропустит ход."))
		return out
	var head := _head(move)
	var dmg := api.shown_damage(me, move)
	if combat.is_charmed(me):
		if move.damage > 0:
			out.append(_part(ICON_ATTACK, "", str(dmg), "[b]Очарование[/b]\nПротивник очарован и ударит своих: %d урона." % dmg, COL_CHARM, CardStatuses.CHARM))
		else:
			out.append(_part(ICON_NEGATIVE, "Очарован", "", "[b]Очарование[/b]\nПротивник очарован и действует против своих.", COL_CHARM, CardStatuses.CHARM))
		return out

	# --- Удар -----------------------------------------------------------------
	if move.kind == EnemyMove.Kind.DIGEST and dmg <= 0:
		out.append(_part("", "Переваривает", "", head + "Противник переваривает проглоченного персонажа: в этот ход не атакует, в конце хода выплюнет."))
	elif move.kind == EnemyMove.Kind.DIGEST:
		out.append(_part(ICON_ATTACK, "", str(dmg), head + "Противник переварит проглоченного персонажа: %d урона, щит не спасёт." % dmg))
	elif move.damage > 0:
		var hits := move.hits
		var per_status := ""
		if move.hits_per_status != "":
			var f := api.front_hero()
			hits = maxi(1, combat.stacks(f, move.hits_per_status)) if f != null else 1
			per_status = move.hits_per_status
		var num := str(dmg) if hits <= 1 else "%d×%d" % [dmg, hits]
		var col := COL_NUMBER
		if dmg < EnemyApi.scaled(me, move.damage):
			col = COL_WEAKENED
		var whom := String(AIM_TEXT.get(move.aim, ""))
		var tip := head
		if hits > 1:
			tip += "Противник планирует атаковать и нанесёт %d раз по %d урона %s." % [hits, dmg, whom]
		else:
			tip += "Противник планирует атаковать и нанесёт %d урона %s." % [dmg, whom]
		if per_status != "":
			tip += " Ударов — по числу стаков «%s», после удара они снимаются." % CardStatuses.get_status(per_status).title
		out.append(_part(ICON_ATTACK, "", num, tip, col))

	# --- Статус на героинь / на себя --------------------------------------------
	if move.status != "":
		var st := CardStatuses.get_status(move.status)
		var st_name := st.title if st != null else move.status
		var amount := ""
		if move.status_stacks > 0:
			amount = " +%d" % move.status_stacks
		elif move.status_turns > 0:
			amount = " (%s)" % CardStatus.turns_text(move.status_turns)
		if POSITIVE_STATUSES.has(move.status):
			out.append(_part(ICON_POSITIVE, "", "", head + "Этот противник повесит позитивный эффект: %s%s." % [st_name, amount], COL_NUMBER, move.status))
		else:
			var where := String(AIM_TARGET.get(move.aim, ""))
			out.append(_part(ICON_NEGATIVE, "", "", head + "Этот противник повесит негативный эффект: %s%s %s." % [st_name, amount, where], COL_NUMBER, move.status))
	elif move.negative_tip != "":
		out.append(_part(ICON_NEGATIVE, "", "", head + move.negative_tip))
	elif move.kind == EnemyMove.Kind.DEBUFF:
		out.append(_part(ICON_NEGATIVE, "", "", head + "Противник помешает отряду."))

	# --- Поддержка -------------------------------------------------------------
	if move.shield > 0:
		var sh := EnemyApi.scaled(me, move.shield)
		out.append(_part(ICON_SHIELD, "", str(sh), head + "Противник поставит щит %d %s." % [sh, String(SUPPORT_TEXT.get(move.support_aim, "себе"))]))
	if move.heal > 0:
		var hl := EnemyApi.scaled(me, move.heal)
		out.append(_part(ICON_POSITIVE, "", str(hl), head + "Противник вылечит %s на %d." % [_heal_whom(move.support_aim), hl]))
	elif move.kind == EnemyMove.Kind.BUFF and move.status == "":
		out.append(_part(ICON_POSITIVE, "", "", head + "Противник усилится."))

	# --- Особые ----------------------------------------------------------------
	match move.kind:
		EnemyMove.Kind.SUMMON:
			out.append(_part(ICON_SUMMON, "Призыв", "", head + "Противник призовёт союзников."))
		EnemyMove.Kind.SPLIT:
			out.append(_part(ICON_SUMMON, "Делится", "", head + "Противник разделится на части."))
		EnemyMove.Kind.SWALLOW:
			out.append(_part(ICON_NEGATIVE, "", "", head + "Противник проглотит переднего персонажа: тот не сможет действовать, а на следующем ходу его переварят.", COL_NUMBER, CardStatuses.SWALLOWED))
	if out.is_empty():
		out.append(_part("", move.intent_text(dmg), "", head.strip_edges()))
	if move.tip != "":
		for p in out:
			p["tip"] = String(p["tip"]) + "\n" + move.tip
	return out

static func _heal_whom(aim: String) -> String:
	match aim:
		"neighbour": return "соседа"
		"wounded": return "самого раненого из своих"
		"wounded_other": return "самого раненого соседа"
		"front": return "переднего из своих"
		"all": return "всех своих"
	return "себя"
