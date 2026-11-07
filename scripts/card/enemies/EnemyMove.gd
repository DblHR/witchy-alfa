extends RefCounted
class_name EnemyMove
## Одно действие врага (как карта врага в StS): что показать в намерении и что сделать.
##
## Простые действия собираются из полей (урон, удары, статус, щит, лечение).
## Особые — через custom: Callable(api: EnemyApi, me: Unit, move: EnemyMove) -> void.
## Выбор хода — в EnemyDef.choose (вес, «не больше N раз подряд», перезарядка, условие).

## Короткие названия статусов для подписи намерения («Удар 8 + слизь»).
const SHORT_STATUS := {"sticky_slime": "слизь", "vuln": "уязвимость", "weak": "слабость", "charm": "очарование"}

enum Kind { ATTACK, DEFEND, HEAL, BUFF, DEBUFF, SUMMON, SWALLOW, DIGEST, SPLIT }

## Кого бьёт атака.
enum Aim {
	FRONT_HERO,     ## передняя героиня (основная цель)
	ALL_HEROES,     ## все героини
	RANDOM_HERO,    ## случайная героиня
	BACK_HERO,      ## задняя героиня (самая дальняя от врагов)
	LOWEST_HERO,    ## героиня с наименьшим HP
}

var id: String = ""
var title: String = ""
var kind: Kind = Kind.ATTACK

# --- Атака ---
var damage: int = 0          ## урон за удар на 1-м этаже (дальше × сила этажа, Unit.ai["mult"])
var hits: int = 1
var aim: Aim = Aim.FRONT_HERO

# --- Статус на цель атаки (или на всех героинь, если aim == ALL_HEROES) ---
var status: String = ""
var status_stacks: int = 0
var status_turns: int = 0

# --- Поддержка ---
var shield: int = 0          ## щит на 1-м этаже (кому — support_aim)
var heal: int = 0            ## лечение на 1-м этаже (кому — support_aim)
var support_aim: String = "self"   ## "self" | "neighbour" | "wounded" | "front" | "all"

## Своё поведение (вместо/после полей выше).
var custom: Callable
## Урон наносит сам custom (поле damage — только для подписи намерения).
var manual_damage := false
## Подпись намерения. {d} — урон за удар с учётом статусов, {n} — число ударов.
## Пусто — подпись строится сама.
var intent: String = ""
## Кто ходит раньше в ходе врагов (кислотный снимает щиты до ударов остальных).
var priority: int = 0

# --- Правила выбора (EnemyDef.choose) ---
var weight: int = 10
var max_in_row: int = 2
var cooldown: int = 0        ## сколько ходов после использования ход недоступен
var cond: Callable           ## Callable(api, me) -> bool; пусто — всегда можно

func _init(p_id: String = "", p_title: String = "", p_kind: Kind = Kind.ATTACK) -> void:
	id = p_id
	title = p_title
	kind = p_kind

func is_attack() -> bool:
	return damage > 0 and kind == Kind.ATTACK

## Текст намерения над врагом.
func intent_text(effective_damage: int) -> String:
	var t := intent
	if t == "":
		match kind:
			Kind.ATTACK:
				if aim == Aim.ALL_HEROES:
					t = "Всем {d}"
				elif hits > 1:
					t = "Удар {d}×{n}"
				else:
					t = "Удар {d}"
				if status != "":
					t += " + " + String(SHORT_STATUS.get(status, CardStatuses.get_status(status).title.to_lower()))
			Kind.DEFEND:
				t = "Защита"
			Kind.HEAL:
				t = "Лечение"
			Kind.BUFF:
				t = "Усиление"
			Kind.DEBUFF:
				t = "Помеха"
			Kind.SUMMON:
				t = "Призыв"
			Kind.SWALLOW:
				t = "Проглотить!"
			Kind.DIGEST:
				t = "Переварить {d}"
			Kind.SPLIT:
				t = "Делится"
	return t.replace("{d}", str(effective_damage)).replace("{n}", str(hits))

## Цвет намерения: красный — бьёт, голубой — защищается, зелёный — лечит, жёлтый — прочее.
func intent_color() -> Color:
	match kind:
		Kind.ATTACK, Kind.DIGEST:
			return Color(1.0, 0.55, 0.45)
		Kind.DEFEND:
			return CardCombat.COL_SHIELD
		Kind.HEAL:
			return CardCombat.COL_HEAL
		Kind.SWALLOW:
			return Color(1.0, 0.4, 0.75)
	return CardCombat.COL_STATUS
