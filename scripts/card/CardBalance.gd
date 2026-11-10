extends RefCounted
class_name CardBalance
## Общие числа баланса в одном месте: рост от уровня, опыт, доверие, общие карты.
## Всё тестовое — крутить здесь, а не по скриптам.

# --- Уровни ------------------------------------------------------------------
## Рост характеристик: +10% от базы за каждый уровень после первого (уровень 10 = ×1.9).
const GROWTH_PER_LEVEL := 0.10
## Этажей 7, каждый ограничивает рост 10 уровнями (этаж 1 — до 10, этаж 2 — до 20…).
const LEVELS_PER_FLOOR := 10
const FLOOR_COUNT := 7
const MAX_LEVEL := LEVELS_PER_FLOOR * FLOOR_COUNT

## Множитель от уровня: 1.0 на 1-м, 1.9 на 10-м, 7.9 на 70-м.
static func level_mult(level: int) -> float:
	return 1.0 + GROWTH_PER_LEVEL * float(maxi(level, 1) - 1)

static func scale_by_level(base: int, level: int) -> int:
	return roundi(float(base) * level_mult(level))

## Потолок уровня для этажа.
static func level_cap(floor_no: int) -> int:
	return clampi(floor_no, 1, FLOOR_COUNT) * LEVELS_PER_FLOOR

## Сила врагов этажа: этаж 1 = ×1.0, каждый следующий — как +9 уровней героя.
static func floor_mult(floor_no: int) -> float:
	return level_mult(1 + (maxi(floor_no, 1) - 1) * (LEVELS_PER_FLOOR - 1))

# --- Сила врагов ---------------------------------------------------------------
## Общие ручки сложности поверх чисел в EnemyDefs: HP врагов и сила их ходов (урон, щиты, лечение).
## HP героинь — hero_hp_mult (поверх base_hp × рост от уровня).
## Цель: забег 10–12 минут (полный на 10 комнат — до 15); отряд без Фуфу
##   до 5–7 уровня до босса не доходит, на 7–9 доходит и иногда побеждает, на 10 проходит спокойно.
## Подобрано прогоном ботом (без событий, еды, посохов и зелий; ведьма + воин + Аки/Луиса,
## 24 забега на уровень; разброс ±15%):
##   ур. 3 — до Фуфу доходит ~1 из 8;   ур. 5–6 — ~45%, побеждает редко (~10%);
##   ур. 7 — ~60%, побед ~30%;           ур. 8–9 — ~85%, побед ~45–55%;   ур. 10 — ~95%, побед ~65%.
## Забег 18–24 хода (было 40–50). Было 1.0 / 1.6 / 1.8, Фуфу 900.
static var hero_hp_mult := 0.75
static var enemy_hp_mult := 1.1
static var enemy_power_mult := 4.6
## Босс (ранг S) бьёт слабее обычных врагов (× к enemy_power_mult): трудность забега — в дороге до босса.
static var boss_power_mult := 0.45

# --- Опыт ---------------------------------------------------------------------
## Сколько «средних» забегов на каждый уровень внутри этажа: с 1-го до 10-го уровня — 9 шагов,
## 2+2+2+3+3+3+4+4+5 = 28 забегов, вровень с доверием (10 уровней за 28 забегов).
## Последнее число — переход на следующий этаж (10 → 11), он доступен только со 2-го этажа.
const RUNS_PER_LEVEL: Array[int] = [2, 2, 2, 3, 3, 3, 4, 4, 5, 5]
## Сколько опыта даёт «средний» пройденный забег 1-го этажа (≈ 11 слизней + элитка + босс).
const XP_PER_RUN := 200
## Опыт за врага по рангу (на 1-м этаже; дальше × floor_mult).
const XP_BY_RANK := {"B": 10, "A": 25, "S": 60}

static func xp_to_next_level(level: int) -> int:
	var lvl := maxi(level, 1)
	var floor_no := (lvl - 1) / LEVELS_PER_FLOOR + 1
	var runs: int = RUNS_PER_LEVEL[(lvl - 1) % LEVELS_PER_FLOOR]
	return roundi(float(XP_PER_RUN * runs) * floor_mult(floor_no))

static func xp_for_kill(rank: String, floor_no: int) -> int:
	return roundi(float(int(XP_BY_RANK.get(rank, 10))) * floor_mult(floor_no))

# --- Доверие ------------------------------------------------------------------
## Очки доверия на каждый уровень отношений (1 очко = 1 забег с героиней в отряде).
const TRUST_STEPS: Array[int] = [1, 2, 2, 2, 3, 3, 3, 4, 4, 4]
const TRUST_PER_RUN := 1

## Уровень отношений по накопленным очкам.
static func trust_level(points: int) -> int:
	var lvl := 0
	var need := 0
	for step in TRUST_STEPS:
		need += step
		if points < need:
			break
		lvl += 1
	return lvl

## Сколько очков нужно, чтобы ровно достигнуть уровня.
static func trust_points_for_level(level: int) -> int:
	var total := 0
	for i in range(clampi(level, 0, TRUST_STEPS.size())):
		total += TRUST_STEPS[i]
	return total

# --- Общие карты и статусы ---------------------------------------------------
## Удар / Щит из общей колоды: база на 1-м уровне отряда, растут на +10% за уровень.
## (Множитель применяется ко всем эффектам без владельца — CardEffect.scaled.)
static func party_level() -> int:
	return maxi(1, int(DungRun.party_level)) if DungRun != null else 1

## Горение: урон за стак на 1-м уровне отряда, растёт с уровнем отряда.
const BURN_PER_STACK := 5

static func burn_per_stack() -> int:
	return scale_by_level(BURN_PER_STACK, party_level())

