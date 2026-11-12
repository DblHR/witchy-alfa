extends RefCounted
class_name CardRun
## Состояние и генерация забега карточного боя: 8-10 комнат, босс в последней,
## ивенты, выбор пути. Здесь только данные, без UI (UI — в CardBattle и *Popup/EventScreen).
##
## Комната — Dictionary:
##   kind: "battle" | "elite" | "boss" | "event" | "quest"
##   quest: id квеста (для kind == "quest"; «find_warrior» — бой с Фуфу, после него воин в ростере)
##   event: "shop" | "nurse" | "chest" | "statue" (для kind == "event")
##   variant: "white" | "black" (статуя)
##   enemies: Array[String] — id врагов из EnemyDefs (в порядке строя, первый — передний)
##   boss: bool
##   used: bool — ивент уже отыгран; stock — ассортимент лавки

const MIN_ROOMS := 8
const MAX_ROOMS := 10
## Босс этажа (его же можно получить в отряд после первой победы — UnitRoster_.unlock_boss_once).
const BOSS_ID := "fufu"
## Этаж забега. Пока есть только 1-й (слизни); от этажа — сила врагов и потолок уровня.
const FLOOR := 1

## Шансы (как в старом забеге): 70% бой, 30% ивент; ивенты поровну.
const BATTLE_CHANCE := 0.70
const EVENT_WEIGHTS := {"chest": 25, "statue": 25, "shop": 25, "nurse": 25}
## С какого уровня отряда встречается ивент-комната (до этого на её месте — бой).
## Пока все с 1-го: открытие по уровням (2 / 4 / 6) не понравилось — поставить числа, чтобы вернуть.
const EVENT_MIN_LEVEL := {"chest": 1, "shop": 1, "nurse": 1, "statue": 1}

## Элитная комната (слизнедевочка ранга A + слизень): шанс среди боёв, не раньше этой комнаты.
const ELITE_CHANCE := 0.25
const ELITE_FROM_ROOM := 3
const ELITE_MAX := 2
const STATUE_CHARGES := 3

## Квест «Пропавший воин» (выдаёт Рикка на 2-м уровне): пока он активен, с этим шансом
## следующая дверь — квестовая комната (единственная). Не позже комнаты QUEST_FORCE_ROOM.
const QUEST_ID := "find_warrior"
const QUEST_ROOM_CHANCE := 0.35
const QUEST_FORCE_ROOM := 3
var quest_placed := false

## Колода комнат («ограниченный рандом»). После комнаты игроку сдаются 2-3 карты из неё;
## выбранная уходит из колоды, остальные остаются. Первая комната (бой), комната перед боссом
## (лавка или медсестра) и босс — вне колоды.
##   battle / elite — бой и элита; chest, nurse, shop — ивенты; statue_white / statue_black — статуи.
const ROOM_DECK := {"battle": 9, "elite": 3, "chest": 3, "nurse": 2, "shop": 1, "statue_white": 1, "statue_black": 1}
## Сколько ивент-комнат можно пройти подряд: после стольких в следующей раздаче только бои.
const MAX_EVENTS_IN_ROW := 1
var room_deck: Array[String] = []
var _events_in_row := 0

var rng := RandomNumberGenerator.new()
var floor_no: int = FLOOR
## Опыт, набранный за забег. Начисляется отряду только в конце (победа/поражение), не при выходе.
var xp_gained: int = 0
var _elites: int = 0
var rooms: Array[Dictionary] = []
var index: int = 0
var pending_choices: Array[Dictionary] = []

## Карты, добытые за забег (id из CardLibrary). Добавляются в колоду каждой комнаты.
var bonus_cards: Array[String] = []
## Карты, сгоревшие до конца забега (id, по одному на каждую сгоревшую копию; например приманка).
## Из колоды следующих комнат убирается столько же копий.
var burned_for_run: Array[String] = []

func burned_count(card_id: String) -> int:
	return burned_for_run.count(card_id)
## Статуи: сколько ближайших побед действует дар.
var white_charges: int = 0   ## лечение после победы
var black_charges: int = 0   ## +урон картам в бою

func _init(run_seed: int = -1) -> void:
	if run_seed < 0:
		rng.randomize()
	else:
		rng.seed = run_seed
	var total := rng.randi_range(MIN_ROOMS, MAX_ROOMS)
	rooms.clear()
	for i in range(total):
		rooms.append({})
	rooms[0] = make_room(0)
	index = 0
	for kind in ROOM_DECK:
		for _k in range(int(ROOM_DECK[kind])):
			room_deck.append(String(kind))

func total_rooms() -> int:
	return rooms.size()

func room(i: int = -1) -> Dictionary:
	var k := index if i < 0 else i
	if k < 0 or k >= rooms.size():
		return {}
	return rooms[k]

func is_last(i: int = -1) -> bool:
	var k := index if i < 0 else i
	return k >= rooms.size() - 1

## Новая комната на позицию i по тем же правилам, что в старом забеге.
func make_room(i: int) -> Dictionary:
	var n := rooms.size()
	if i == 0:
		return _battle_room(0, n)
	if i == n - 1:
		return {"kind": "boss", "event": "", "boss": true, "enemies": [EnemyDefs.FLOOR1_BOSS], "used": false}
	var events := unlocked_events()
	if i == n - 2:
		# Перед боссом безопасная комната: лавка или медсестра (что открыто); иначе любая открытая, иначе бой.
		var safe: Array[String] = []
		for id in ["shop", "nurse"]:
			if events.has(id):
				safe.append(id)
		if not safe.is_empty():
			return _event_room(safe[rng.randi_range(0, safe.size() - 1)])
		if not events.is_empty():
			return _event_room(_pick_weighted(events))
		return _battle_room(i, n)
	if rng.randf() < BATTLE_CHANCE or events.is_empty():
		if i >= ELITE_FROM_ROOM and _elites < ELITE_MAX and rng.randf() < ELITE_CHANCE:
			_elites += 1
			return _elite_room()
		return _battle_room(i, n)
	return _event_room(_pick_weighted(events))

## Ивенты, открытые на текущем уровне отряда: {id: вес}.
static func unlocked_events() -> Dictionary:
	var lvl := maxi(1, int(DungRun.party_level)) if DungRun != null else 99
	var out := {}
	for id in EVENT_WEIGHTS:
		if lvl >= int(EVENT_MIN_LEVEL.get(id, 1)):
			out[id] = EVENT_WEIGHTS[id]
	return out

func _pick_weighted(weights: Dictionary) -> String:
	var total := 0
	for k in weights:
		total += int(weights[k])
	var roll := rng.randi_range(1, total)
	for k in weights:
		roll -= int(weights[k])
		if roll <= 0:
			return String(k)
	return String(weights.keys()[0])

## Обычный бой: слизни ранга B. «Вес» комнаты растёт с номером: Шлёпыш/Пузырь/Кислотный — 1,
## Большая блёба — 2 (она делится). Пузырь один не ходит — он прикрывает соседей.
func _battle_room(i: int, _n: int) -> Dictionary:
	var budget := clampi(1 + int(floor(float(i + 1) * 0.5)), 1, 4)
	var enemies: Array[String] = []
	var left := budget
	while left > 0 and enemies.size() < 4:
		var pick := String(EnemyDefs.FLOOR1_B[rng.randi_range(0, EnemyDefs.FLOOR1_B.size() - 1)])
		if pick == "blob" and (left < 2 or enemies.has("blob")):
			pick = "shlep"
		if pick == "bubble" and (enemies.is_empty() and left == 1):
			pick = "shlep"
		enemies.append(pick)
		left -= 2 if pick == "blob" else 1
	# Бойцы впереди, Пузырь (поддержка) позади.
	enemies.sort_custom(func(a: String, b: String) -> bool: return a != "bubble" and b == "bubble")
	return {"kind": "battle", "event": "", "boss": false, "enemies": enemies, "used": false}

## Элита: Аки или Луиса и слизень перед ней.
func _elite_room() -> Dictionary:
	var girl := String(EnemyDefs.FLOOR1_A[rng.randi_range(0, EnemyDefs.FLOOR1_A.size() - 1)])
	var front := "shlep" if rng.randf() < 0.5 else "acid"
	return {"kind": "elite", "event": "", "boss": false, "enemies": [front, girl], "used": false}

## Квест на воина активен, а его комнату ещё не проходили.
static func quest_due() -> bool:
	return StoryState_ != null and StoryState_.is_quest_active(QUEST_ID) and not StoryState_.has_flag("find_warrior_room_done")

## Квестовая комната: сценка, потом бой с Фуфу (как с боссом; проиграть — нормально).
static func quest_room() -> Dictionary:
	return {"kind": "quest", "quest": QUEST_ID, "event": "", "boss": true, "enemies": [EnemyDefs.FLOOR1_BOSS], "used": false}

func _event_room(event_id: String) -> Dictionary:
	var r := {"kind": "event", "event": event_id, "boss": false, "used": false}
	if event_id == "statue":
		r["variant"] = "white" if rng.randf() < 0.5 else "black"
	return r

## Варианты следующей комнаты: 2-3 карты из колоды комнат. Перед боссом и за комнату до него —
## одна карта без выбора (как и квестовая комната).
func prepare_choices() -> void:
	pending_choices.clear()
	var next_i := index + 1
	if next_i >= rooms.size():
		return
	var n := rooms.size()
	if next_i >= n - 2:
		pending_choices.append(make_room(next_i))
		return
	if not quest_placed and quest_due() and (next_i >= QUEST_FORCE_ROOM or rng.randf() < QUEST_ROOM_CHANCE):
		quest_placed = true
		pending_choices.append(quest_room())
		return
	var count := rng.randi_range(2, 3)
	# Тасуем копию колоды и берём сверху подходящие карты (сами карты остаются в колоде до выбора).
	var order := room_deck.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = order[i]
		order[i] = order[j]
		order[j] = tmp
	var events := unlocked_events()
	var fights_only := _events_in_row >= MAX_EVENTS_IN_ROW
	var event_cards := 0
	var seen_events: Dictionary = {}
	var elite_in_hand := false
	for card: String in order:
		if pending_choices.size() >= count:
			break
		var room := {}
		match card:
			"battle":
				room = _battle_room(next_i, n)
			"elite":
				# Элита — не раньше своей комнаты, не больше ELITE_MAX за забег, одна в раздаче.
				if next_i < ELITE_FROM_ROOM or _elites >= ELITE_MAX or elite_in_hand:
					continue
				elite_in_hand = true
				room = _elite_room()
			_:
				var event_id := "statue" if card.begins_with("statue") else card
				# Ивентов в раздаче — не больше, чем «все, кроме одной»; одинаковые не повторяются.
				if fights_only or not events.has(event_id) or seen_events.has(card) or event_cards >= count - 1:
					continue
				seen_events[card] = true
				event_cards += 1
				room = _event_room(event_id)
				if event_id == "statue":
					room["variant"] = "white" if card == "statue_white" else "black"
		room["deck_card"] = card
		pending_choices.append(room)
	# Колода не дала нужного числа карт (кончились бои) — добираем обычными боями.
	while pending_choices.size() < count:
		pending_choices.append(_battle_room(next_i, n))

func choose(choice_index: int) -> Dictionary:
	if pending_choices.is_empty():
		return {}
	choice_index = clampi(choice_index, 0, pending_choices.size() - 1)
	index += 1
	rooms[index] = pending_choices[choice_index]
	pending_choices.clear()
	# Выбранная карта уходит из колоды; остальные остались в ней.
	var card := String(rooms[index].get("deck_card", ""))
	if card != "":
		room_deck.erase(card)
		if card == "elite":
			_elites += 1
	_events_in_row = _events_in_row + 1 if String(rooms[index].get("kind", "")) == "event" else 0
	return rooms[index]

## Что осталось в колоде комнат: «Бой ×9, Элита ×3, …» (для подсказки в UI).
func room_deck_summary() -> String:
	var parts := PackedStringArray()
	for kind in ROOM_DECK:
		var left := room_deck.count(String(kind))
		if left > 0:
			parts.append("%s ×%d" % [deck_card_title(String(kind)), left])
	return ", ".join(parts)

static func deck_card_title(card: String) -> String:
	match card:
		"battle": return "Бой"
		"elite": return "Элита"
		"statue_white": return "Белая статуя"
		"statue_black": return "Чёрная статуя"
	return event_name(card)

# --- Описания для UI ---------------------------------------------------------

## «Шлёпыш ×2, Пузырь» — состав комнаты.
static func enemy_list(r: Dictionary) -> String:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for id in r.get("enemies", []):
		var k := String(id)
		if not counts.has(k):
			order.append(k)
		counts[k] = int(counts.get(k, 0)) + 1
	var parts := PackedStringArray()
	for k in order:
		var n := int(counts[k])
		parts.append(EnemyDefs.title_of(k) + ("" if n == 1 else " ×%d" % n))
	return "\n".join(parts)

static func event_name(event_id: String, variant: String = "") -> String:
	match event_id:
		"shop": return "Лавка ламии"
		"nurse": return "Медсестра"
		"chest": return "Сундук"
		"statue": return "Белая статуя" if variant == "white" else "Чёрная статуя"
	return "Событие"

static func room_title(r: Dictionary) -> String:
	match String(r.get("kind", "")):
		"battle": return "Бой"
		"elite": return "Элита"
		"boss": return "Босс"
		"quest": return "???"
		"event": return event_name(String(r.get("event", "")), String(r.get("variant", "")))
	return "?"

static func room_hint(r: Dictionary) -> String:
	match String(r.get("kind", "")):
		"battle", "elite":
			return enemy_list(r)
		"boss":
			return "Финал забега:\n" + enemy_list(r)
		"quest":
			return "Кто-то зовёт\nна помощь…"
		"event":
			match String(r.get("event", "")):
				"shop": return "Купить карты\nи лечение"
				"nurse": return "Лечение или\nвоскрешение"
				"chest": return "Золото и\nдобыча"
				"statue":
					return "Лечит после\nпобед" if String(r.get("variant", "")) == "white" else "Усиливает урон\nкарт"
	return ""
