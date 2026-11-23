extends RefCounted
class_name CardKeywords
## Ключевые слова карт: что значит «Нажим», «Липкая слизь», «На крючке»… Описание на карте короткое,
## а при наведении на карту рядом выезжают плашки с расшифровкой (HoverTips) — как в Slay the Spire.
##
## Ищутся внутри разметки [e]…[/e] описания карты (и [s] — щит). Статусы берут название, цвет, значок
## и описание из CardStatuses (там же — ограничение по стакам). Новое слово — строка в STEMS
## (начало слова в нижнем регистре -> id статуса) или в MECHANICS (своё описание).

## Начало слова -> id статуса. Порядок важен: «жар тела» раньше, чем «жар».
const STEMS := [
	["жар тела", CardStatuses.HEAT_BODY],
	["липк", CardStatuses.STICKY_SLIME],
	["обволак", CardStatuses.WRAP_SLIME],
	["горен", CardStatuses.BURN],
	["горящ", CardStatuses.BURN],
	["нажим", CardStatuses.NAZHIM],
	["слабост", CardStatuses.WEAK],
	["уязвим", CardStatuses.VULN],
	["оглуш", CardStatuses.STUN],
	["очаров", CardStatuses.CHARM],
	["усилен", CardStatuses.EMPOWER],
	["подстав", CardStatuses.EXPOSED],
	["крюч", CardStatuses.LURED],
	["одноразов", "@single_use"],
	["тратится", "@consumed"],
]

## Слова-правила (не статусы): заголовок, цвет, описание.
const MECHANICS := {
	"@single_use": ["Одноразовая", Color(1.0, 0.82, 0.48), "После розыгрыша сгорает до конца забега."],
	"@consumed": ["Тратится", Color(1.0, 0.82, 0.48), "Берётся из инвентаря и после розыгрыша пропадает."],
	"@shield": ["Щит", Color(0.62, 0.7, 1.0), "Принимает урон на себя, пока не кончится. Щиты отряда спадают в начале вашего хода, щиты врагов — в начале их хода."],
}

static var _seg_regex: RegEx

## id ключевых слов в описании (по порядку появления, без повторов).
static func ids_in(description: String) -> Array[String]:
	var out: Array[String] = []
	if _seg_regex == null:
		_seg_regex = RegEx.create_from_string("\\[e\\](.*?)\\[/e\\]")
	for m in _seg_regex.search_all(description):
		var low := m.get_string(1).to_lower()
		for pair in STEMS:
			var id := String(pair[1])
			if low.contains(String(pair[0])) and not out.has(id):
				out.append(id)
				if id == CardStatuses.HEAT_BODY:
					break   ## «Жар тела» — это не «Горение»
	if description.contains("[s]") and not out.has("@shield"):
		out.append("@shield")
	return out

## Статусы, упомянутые в обычном тексте (описание статуса или намерения): «…— оглушение» -> stun.
static func ids_in_plain(text: String, exclude: Array = []) -> Array[String]:
	var out: Array[String] = []
	var low := text.to_lower()
	for pair in STEMS:
		var id := String(pair[1])
		if id.begins_with("@") or exclude.has(id) or out.has(id):
			continue
		if low.contains(String(pair[0])):
			if id == CardStatuses.BURN and low.contains("жар тела") and not low.contains("горен"):
				continue
			out.append(id)
	return out

## Плашки со статусами, о которых говорится в тексте (кроме exclude) — вторым рядом подсказки.
static func related_boxes(text: String, exclude: Array = []) -> Array:
	var out: Array = []
	for id in ids_in_plain(text, exclude):
		var b := box_for(id)
		if not b.is_empty():
			out.append(b)
	return out

## Плашка для ключевого слова (статус или правило).
static func box_for(id: String) -> Dictionary:
	if MECHANICS.has(id):
		var m: Array = MECHANICS[id]
		return HoverTips.box(String(m[0]), String(m[2]), m[1])
	var st := CardStatuses.get_status(id)
	if st == null:
		return {}
	return HoverTips.box(st.title, st.full_info(), st.color, st.icon_path)

## Плашки для карты.
static func boxes_for_card(card: CardInstance) -> Array:
	var out: Array = []
	if card == null:
		return out
	var ids := ids_in(card.description)
	for id in ids:
		var b := box_for(id)
		if not b.is_empty():
			out.append(b)
	# Статусы, которые упоминаются в описаниях уже показанных (Липкая слизь -> Оглушение), — тоже.
	var shown: Array = ids.duplicate()
	for id in ids:
		var st := CardStatuses.get_status(id)
		if st == null:
			continue
		for extra in ids_in_plain(st.info, shown):
			shown.append(extra)
			var b := box_for(extra)
			if not b.is_empty():
				out.append(b)
	return out
