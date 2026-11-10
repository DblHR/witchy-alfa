extends RefCounted
class_name CardRelics
## Баффы забега в карточном бою: посох, еда, статуи и выпитые зелья.
## Что взято — DungRun.relics (на старте забега туда кладутся выбранный посох и одна съеденная еда,
## см. DungRun.begin_card_run). Статуи и зелья добавляет CardBattle.
##
## CardBattle зовёт хуки: начало боя, начало хода, розыгрыш карты, урон по героине, конец боя.
## CardCombat зовёт modify_hero_damage на каждый удар картой героинь.
## Всё, что бафф сделал за забег, копится в stats — это видно во всплывашке иконки (CardBuffBar).
##
## Посохи (три редкости — отдельные предметы *_common / *_rare / *_legendary):
##   Кривой  — каждый удар: шанс ×2 / ×3 или промах.
##   Звёздный — весь урон героинь +8% / +15% / +25%.
##   Сердца  — в начале боя Слабость всем врагам на 1 / 2 / 3 хода (+ очарование случайного).
##   Данго   — в начале боя 1 / 2 / 3 случайных баффа: +1 карта, +1 энергия, Слабость всем.
##   Слизней — (только легендарный) любая карта с шансом 20% даёт всем врагам липкую слизь.
## Еда (одна на забег):
##   Шашлык — в начале каждого боя лечит отряд на 8% макс. HP.
##   Стейк  — один раз за забег: героиня упала ниже 30% HP — лечится на 40%.
##   Желе   — в первом ходу каждого боя +1 карта.
##   Яблоко в карамели — первая атака в каждом бою наносит +60% урона.
## Статуи (на STATUE_ROOMS боевых комнат):
##   Белая — +1 энергия в первые 2 хода боя, после победы отряд лечится на 10% макс. HP.
##   Чёрная — +1 карта в первые 2 хода боя, урон карт +20%.
## Зелья (CardBattle, слоты): Фиал ярости — урон карт +30% до конца хода.

# --- Числа -------------------------------------------------------------------
## Кривой посох по редкости: [шанс ×2, шанс ×3, шанс промаха].
const CROOKED := {
## В среднем: обычный +5%, редкий +18%, легендарный +36% урона (было −10% / 0% / +25%:
## обычный и редкий в среднем били слабее, чем без посоха).
	"stick_staff_common": [0.15, 0.0, 0.10],
	"stick_staff_rare": [0.20, 0.03, 0.08],
	"stick_staff_legendary": [0.25, 0.08, 0.05],
}
## Звёздный — надёжный: чуть меньше Кривого в среднем, зато без промахов.
const STAR_BONUS := {"mace_staff_common": 0.08, "mace_staff_rare": 0.15, "mace_staff_legendary": 0.25}
## Посох сердца: ходов Слабости всем врагам в начале боя (бой теперь ~3 хода).
const HEART_WEAK_TURNS := {"heart_staff_common": 1, "heart_staff_rare": 2, "heart_staff_legendary": 3}
const HEART_CHARM_TURNS := 1
## Данго: сколько баффов из трёх.
const DANGO_BUFFS := {"dango_staff_common": 1, "dango_staff_rare": 2, "dango_staff_legendary": 3}
const DANGO_WEAK_TURNS := 1
const SLIME_STAFF_CHANCE := 0.20
const SLIME_STAFF_STACKS := 1

const KEBAB_HEAL := 0.08
const STEAK_THRESHOLD := 0.30
const STEAK_HEAL := 0.40
const JELLY_CARDS := 1
const APPLE_BONUS := 0.60

const STATUE_ROOMS := 3
const STATUE_TURNS := 2
const WHITE_ENERGY := 1
const WHITE_HEAL := 0.10
const BLACK_CARDS := 1
const BLACK_BONUS := 0.20
const RAGE_BONUS := 0.30

## Особые id баффов (не предметы).
const STATUE_WHITE := "statue_white"
const STATUE_BLACK := "statue_black"
const RAGE := "rage_phial"

var items: Array[String] = []
var rng: RandomNumberGenerator

## Статуи в этом бою (у CardRun — оставшиеся боевые комнаты).
var white_active := false
var black_active := false
## Фиал ярости выпит в этот ход.
var rage_active := false

## Добавка текущего хода (turn_bonus): карты забирает раздача руки.
var turn_bonus_cache: Dictionary = {}
## Бонусы первого хода этого боя (Данго, Желе).
var first_turn_cards := 0
var first_turn_energy := 0
## Яблоко: первая атака боя ещё не сыграна / сейчас разыгрывается первая атака.
var _apple_ready := false
var _apple_active := false

## id баффа -> {dmg, heal, cards, energy, procs, miss, weak, charm, sticky}: что сделано за забег.
var stats: Dictionary = {}

func _init(p_items: Array = [], p_rng: RandomNumberGenerator = null) -> void:
	for id in p_items:
		items.append(String(id))
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()

func has(id: String) -> bool:
	return items.has(id)

func _staff(prefix: String) -> String:
	for id in items:
		if id.begins_with(prefix):
			return id
	return ""

func _count(id: String, key: String, amount: int = 1) -> void:
	if id == "" or amount == 0:
		return
	var s: Dictionary = stats.get(id, {})
	s[key] = int(s.get(key, 0)) + amount
	stats[id] = s

func stat(id: String, key: String) -> int:
	return int(Dictionary(stats.get(id, {})).get(key, 0))

## Короткие имена взятых предметов.
func names() -> PackedStringArray:
	var out := PackedStringArray()
	for id in items:
		out.append(RunItems.get_item_name(id))
	return out

## Строка статистики за забег для всплывашки (пусто — бафф ещё ничего не сделал).
func stats_text(id: String) -> String:
	var parts := PackedStringArray()
	if stat(id, "dmg") > 0:
		parts.append("доп. урона: %d" % stat(id, "dmg"))
	if stat(id, "heal") > 0:
		parts.append("вылечено: %d HP" % stat(id, "heal"))
	if stat(id, "cards") > 0:
		parts.append("лишних карт: %d" % stat(id, "cards"))
	if stat(id, "energy") > 0:
		parts.append("лишней энергии: %d" % stat(id, "energy"))
	if stat(id, "double") > 0:
		parts.append("удвоений: %d" % stat(id, "double"))
	if stat(id, "triple") > 0:
		parts.append("утроений: %d" % stat(id, "triple"))
	if stat(id, "miss") > 0:
		parts.append("промахов: %d" % stat(id, "miss"))
	if stat(id, "weak") > 0:
		parts.append("ослаблено врагов: %d" % stat(id, "weak"))
	if stat(id, "charm") > 0:
		parts.append("очаровано: %d" % stat(id, "charm"))
	if stat(id, "sticky") > 0:
		parts.append("слизь сработала: %d раз" % stat(id, "sticky"))
	if parts.is_empty():
		return "За этот забег: пока ничего."
	return "За этот забег: " + ", ".join(parts) + "."

# --- Начало боя и ходов ------------------------------------------------------

## Враги уже на поле, первый ход ещё не начался.
func on_battle_start(combat: CardCombat, white: bool = false, black: bool = false) -> void:
	white_active = white
	black_active = black
	rage_active = false
	first_turn_cards = 0
	first_turn_energy = 0
	_apple_ready = has("apple_pie")
	_apple_active = false

	var heart := _staff("heart_staff")
	if heart != "":
		for e in combat.alive_enemies():
			combat.add_status(e, CardStatuses.WEAK, 0, int(HEART_WEAK_TURNS.get(heart, 1)))
			_count(heart, "weak")
		if heart == "heart_staff_legendary":
			var alive := combat.alive_enemies()
			if not alive.is_empty():
				combat.add_status(alive[rng.randi_range(0, alive.size() - 1)], CardStatuses.CHARM, 0, HEART_CHARM_TURNS)
				_count(heart, "charm")

	var dango := _staff("dango_staff")
	if dango != "":
		var buffs := ["card", "energy", "weak"]
		for i in range(buffs.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: String = buffs[i]
			buffs[i] = buffs[j]
			buffs[j] = tmp
		for k in range(int(DANGO_BUFFS.get(dango, 1))):
			match String(buffs[k]):
				"card":
					first_turn_cards += 1
					_count(dango, "cards")
				"energy":
					first_turn_energy += 1
					_count(dango, "energy")
				"weak":
					for e in combat.alive_enemies():
						combat.add_status(e, CardStatuses.WEAK, 0, DANGO_WEAK_TURNS)
						_count(dango, "weak")

	if has("jelly"):
		first_turn_cards += JELLY_CARDS
		_count("jelly", "cards", JELLY_CARDS)
	if has("kebab"):
		for h in combat.alive_heroes():
			_count("kebab", "heal", combat.heal(h, ceili(float(h.max_hp) * KEBAB_HEAL)))

## Добавка к ходу turn_no (1 — первый ход боя): {"cards": n, "energy": n}.
func turn_bonus(turn_no: int) -> Dictionary:
	var cards := 0
	var energy := 0
	if turn_no == 1:
		cards += first_turn_cards
		energy += first_turn_energy
	if turn_no <= STATUE_TURNS:
		if white_active:
			energy += WHITE_ENERGY
			_count(STATUE_WHITE, "energy", WHITE_ENERGY)
		if black_active:
			cards += BLACK_CARDS
			_count(STATUE_BLACK, "cards", BLACK_CARDS)
	turn_bonus_cache = {"cards": cards, "energy": energy}
	return turn_bonus_cache

## Ход игрока закончился: Фиал ярости выдыхается.
func on_turn_end() -> void:
	rage_active = false

## Победа в бою: белая статуя лечит отряд.
func on_battle_won(combat: CardCombat) -> void:
	if white_active:
		for h in combat.alive_heroes():
			_count(STATUE_WHITE, "heal", combat.heal(h, ceili(float(h.max_hp) * WHITE_HEAL)))

# --- Карты и урон ------------------------------------------------------------

## Перед розыгрышем карты героинь (до эффектов).
func before_card(card: CardInstance) -> void:
	_apple_active = _apple_ready and card.get_kind() == "attack"
	if _apple_active:
		_apple_ready = false

## После розыгрыша: посох слизней.
func after_card(combat: CardCombat, _card: CardInstance) -> void:
	_apple_active = false
	if has("slime_staff_legendary") and rng.randf() < SLIME_STAFF_CHANCE:
		_count("slime_staff_legendary", "sticky")
		for e in combat.alive_enemies():
			combat.add_status(e, CardStatuses.STICKY_SLIME, SLIME_STAFF_STACKS, 0)

## Урон картой героинь (или общей картой). 0 — промах.
func modify_hero_damage(combat: CardCombat, target: Unit, dmg: int) -> int:
	var bonuses: Array = []   # [id, доля]
	var star := _staff("mace_staff")
	if star != "":
		bonuses.append([star, float(STAR_BONUS.get(star, 0.0))])
	if _apple_active:
		bonuses.append(["apple_pie", APPLE_BONUS])
	if black_active:
		bonuses.append([STATUE_BLACK, BLACK_BONUS])
	if rage_active:
		bonuses.append([RAGE, RAGE_BONUS])
	var out := float(dmg)
	for b in bonuses:
		var extra := float(dmg) * float(b[1])
		out += extra
		_count(String(b[0]), "dmg", roundi(extra))
	var result := roundi(out)
	var crooked := _staff("stick_staff")
	if crooked != "":
		var c: Array = CROOKED.get(crooked, [0.0, 0.0, 0.0])
		var r := rng.randf()
		if r < float(c[2]):
			_count(crooked, "miss")
			combat.floated.emit(target, "Промах!", CardCombat.COL_STATUS, 28)
			return 0
		r -= float(c[2])
		if r < float(c[1]):
			_count(crooked, "triple")
			_count(crooked, "dmg", result * 2)
			combat.floated.emit(target, "×3!", CardCombat.COL_DAMAGE, 30)
			return result * 3
		r -= float(c[1])
		if r < float(c[0]):
			_count(crooked, "double")
			_count(crooked, "dmg", result)
			combat.floated.emit(target, "×2!", CardCombat.COL_DAMAGE, 30)
			return result * 2
	return result

# --- Урон по героиням --------------------------------------------------------

## Героиня потеряла HP: Стейк (один раз за забег, флаг в DungRun.guardian_cookie_used).
func on_hero_hurt(combat: CardCombat, hero: Unit) -> void:
	if not has("steak") or DungRun.guardian_cookie_used or not CardCombat.is_alive(hero):
		return
	if float(hero.hp) >= float(hero.max_hp) * STEAK_THRESHOLD:
		return
	DungRun.guardian_cookie_used = true
	combat.floated.emit(hero, "Стейк!", CardCombat.COL_HEAL, 30)
	_count("steak", "heal", combat.heal(hero, ceili(float(hero.max_hp) * STEAK_HEAL)))
