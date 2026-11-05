extends RefCounted
class_name CardRun
## Состояние и генерация забега карточного боя: 8-10 комнат, босс в последней,
## ивенты, выбор пути. Здесь только данные, без UI (UI — в CardBattle и *Popup/EventScreen).
##
## Комната — Dictionary:
##   kind: "battle" | "boss" | "event"
##   event: "shop" | "nurse" | "chest" | "statue" (для kind == "event")
##   variant: "white" | "black" (статуя)
##   count, hp, atk_min, atk_max, enemy_id, boss — параметры боя
##   used: bool — ивент уже отыгран; stock — ассортимент лавки

const MIN_ROOMS := 8
const MAX_ROOMS := 10
const ENEMY_ID := "base_slime"
const BOSS_ID := "fufu"

## Шансы (как в старом забеге): 70% бой, 30% ивент; ивенты поровну.
const BATTLE_CHANCE := 0.70
const EVENT_WEIGHTS := {"chest": 25, "statue": 25, "shop": 25, "nurse": 25}

## Тестовые числа боёв (баланс потом).
const BOSS_HP := 160
const BOSS_ATK_MIN := 6
const BOSS_ATK_MAX := 9
const STATUE_CHARGES := 3

var rng := RandomNumberGenerator.new()
var rooms: Array[Dictionary] = []
var index: int = 0
var pending_choices: Array[Dictionary] = []

## Карты, добытые за забег (id из CardLibrary). Добавляются в колоду каждой комнаты.
var bonus_cards: Array[String] = []
## Карты, сгоревшие до конца забега (id, по одному на каждую сгоревшую копию; например эстус).
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
		return {
			"kind": "boss", "event": "", "boss": true, "enemy_id": BOSS_ID,
			"count": 1, "hp": BOSS_HP, "atk_min": BOSS_ATK_MIN, "atk_max": BOSS_ATK_MAX, "used": false,
		}
	if i == n - 2:
		# Перед боссом всегда безопасная комната: лавка или медсестра.
		return _event_room("shop" if rng.randf() < 0.5 else "nurse")
	if rng.randf() < BATTLE_CHANCE:
		return _battle_room(i, n)
	return _event_room(_pick_weighted(EVENT_WEIGHTS))

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

func _battle_room(i: int, _n: int) -> Dictionary:
	var count := clampi(1 + int(floor(float(i + 1) * 0.45)), 1, 4)
	var hp := 24.0 + 2.5 * float(i)
	if count == 1:
		hp *= 1.5   # одинокий слизень плотнее, как в первых тестовых комнатах
	var atk_min := 2 + int(floor(float(i) / 2.5))
	return {
		"kind": "battle", "event": "", "boss": false, "enemy_id": ENEMY_ID,
		"count": count, "hp": int(round(hp)), "atk_min": atk_min, "atk_max": atk_min + 1, "used": false,
	}

func _event_room(event_id: String) -> Dictionary:
	var r := {"kind": "event", "event": event_id, "boss": false, "used": false}
	if event_id == "statue":
		r["variant"] = "white" if rng.randf() < 0.5 else "black"
	return r

## Варианты следующей комнаты (2-3 двери). Перед боссом и за комнату до него — одна дверь.
func prepare_choices() -> void:
	pending_choices.clear()
	var next_i := index + 1
	if next_i >= rooms.size():
		return
	var n := rooms.size()
	if next_i >= n - 2:
		pending_choices.append(make_room(next_i))
		return
	var options := rng.randi_range(2, 3)
	for _k in range(options):
		pending_choices.append(make_room(next_i))

func choose(choice_index: int) -> Dictionary:
	if pending_choices.is_empty():
		return {}
	choice_index = clampi(choice_index, 0, pending_choices.size() - 1)
	index += 1
	rooms[index] = pending_choices[choice_index]
	pending_choices.clear()
	return rooms[index]

# --- Описания для UI ---------------------------------------------------------

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
		"boss": return "Босс"
		"event": return event_name(String(r.get("event", "")), String(r.get("variant", "")))
	return "?"

static func room_hint(r: Dictionary) -> String:
	match String(r.get("kind", "")):
		"battle":
			var c := int(r.get("count", 1))
			return "Врагов: %d\nУдар: %d-%d" % [c, int(r.get("atk_min", 0)), int(r.get("atk_max", 0))]
		"boss":
			return "Финал забега.\nУдар: %d-%d" % [int(r.get("atk_min", 0)), int(r.get("atk_max", 0))]
		"event":
			match String(r.get("event", "")):
				"shop": return "Купить карты\nи лечение"
				"nurse": return "Лечение или\nвоскрешение"
				"chest": return "Золото и\nдобыча"
				"statue":
					return "Лечит после\nпобед" if String(r.get("variant", "")) == "white" else "Усиливает урон\nкарт"
	return ""
