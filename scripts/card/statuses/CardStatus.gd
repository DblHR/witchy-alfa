extends RefCounted
class_name CardStatus
## Описание статуса карточного боя: как он складывается, как отображается и что делает.
## Сам статус на юните — это просто словарь {stacks, turns} внутри CardCombat;
## поведение живёт здесь, в хуках. Новый статус = новый подкласс (или экземпляр с параметрами)
## и одна строчка регистрации в CardStatuses.

enum Kind {
	STACKS,           ## копит стаки, не исчезает сам (Нажим, Слизь)
	DURATION,         ## длится N ходов (Слабость, Уязвимость, Оглушение)
	STACKS_DURATION,  ## сила + длительность (Горение)
}

var id: String = ""
var title: String = ""
var kind: Kind = Kind.STACKS
var color: Color = Color(1.0, 0.92, 0.45)
var max_stacks: int = 99
## Флаги для хода врага: пропускает ход / бьёт своих.
var skips_turn := false
var charms := false

func _init(p_id: String = "", p_title: String = "", p_kind: Kind = Kind.STACKS, p_color: Color = Color(1.0, 0.92, 0.45)) -> void:
	id = p_id
	title = p_title
	kind = p_kind
	color = p_color

func is_active(s: Dictionary) -> bool:
	match kind:
		Kind.DURATION:
			return int(s["turns"]) > 0
		Kind.STACKS_DURATION:
			return int(s["stacks"]) > 0 and int(s["turns"]) > 0
		_:
			return int(s["stacks"]) > 0

## Как новое наложение складывается с уже висящим статусом.
func merge(s: Dictionary, stacks: int, turns: int) -> void:
	s["stacks"] = clampi(int(s["stacks"]) + stacks, 0, max_stacks)
	s["turns"] = maxi(int(s["turns"]), turns)

## Подпись над юнитом.
func label(s: Dictionary) -> String:
	match kind:
		Kind.DURATION:
			return "%s (%d)" % [title, int(s["turns"])]
		Kind.STACKS_DURATION:
			return "%s %d (%d)" % [title, int(s["stacks"]), int(s["turns"])]
		_:
			return "%s %d" % [title, int(s["stacks"])]

## Всплывающий текст при наложении.
func float_text(stacks: int, _turns: int) -> String:
	if kind == Kind.DURATION:
		return title
	return "%s +%d" % [title, stacks]

# --- Хуки (по умолчанию ничего не делают) ------------------------------------

## После наложения. old_stacks — сколько было до.
func on_added(_combat: CardCombat, _unit: Unit, _old_stacks: int, _s: Dictionary) -> void:
	pass

## Урон, который наносит владелец статуса.
func modify_dealt(_combat: CardCombat, _unit: Unit, _s: Dictionary, amount: int) -> int:
	return amount

## Урон, который получает владелец статуса (до щита).
func modify_taken(_combat: CardCombat, _unit: Unit, _s: Dictionary, amount: int) -> int:
	return amount

## Владелец потерял HP (урон после щита).
func on_hp_lost(_combat: CardCombat, _unit: Unit, _s: Dictionary, _amount: int) -> void:
	pass

## Удар attacker пришёлся в щит юнита (absorbed — сколько съел щит). «Жар тела» поджигает обидчика.
func on_shield_hit(_combat: CardCombat, _unit: Unit, _s: Dictionary, _attacker: Unit, _absorbed: int) -> void:
	pass

## Начало хода врагов (Горение жжёт здесь).
func on_enemy_turn_start(_combat: CardCombat, _unit: Unit, _s: Dictionary) -> void:
	pass

## Конец хода игрока (Усиление спадает здесь).
func on_player_turn_end(_combat: CardCombat, _unit: Unit, _s: Dictionary) -> void:
	pass

## Конец раунда (после ударов врагов). По умолчанию длительные статусы теряют ход.
func on_round_end(_combat: CardCombat, _unit: Unit, s: Dictionary) -> void:
	if kind != Kind.STACKS:
		s["turns"] = int(s["turns"]) - 1

## Принудительное срабатывание картой (ульта Ведьмы «Пожар»).
func trigger(_combat: CardCombat, _unit: Unit, _s: Dictionary) -> void:
	pass
