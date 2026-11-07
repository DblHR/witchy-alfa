extends Resource
class_name CardEffect
## Эффект карты. Базовый класс: кому достаётся эффект и как считается число.
## Подклассы переопределяют _apply_one (что сделать с одной целью), value (главное число
## для описания) и describe (автотекст, если у карты нет своего описания).
##
## Числа скейлятся от характеристик владельца карты:
##   значение = base + atk_ratio × Атака + mag_ratio × Магия (округление).
## У общих карт (без владельца: Удар, Щит) base растёт с уровнем отряда (+10% за уровень).
## Стаки статусов и длительность не скейлятся — они постоянны для карты.
##
## Очарованная героиня разыгрывает карты «зеркально» (ctx.mirrored): стороны меняются местами —
## урон летит в своих, щиты и лечение достаются врагам.

enum TargetMode {
	CARD_TARGETS,   ## цели, выбранные картой (передний враг, все враги, выбранный союзник…)
	CASTER,         ## сам владелец карты
	FRONT_ALLY,     ## передний союзник
	ALL_ALLIES,     ## все живые союзники
	FRONT_ENEMY,    ## передний враг
	ALL_ENEMIES,    ## все живые враги
}

@export var target_mode: TargetMode = TargetMode.CARD_TARGETS
## Срабатывает только на целях с этим статусом (id из CardStatuses). Пусто — на всех.
@export var only_if_status: String = ""
## Срабатывает, только если у цели карты (первой выбранной) мало HP (≤ 50%).
## Пример: «Тычок» Фуфу даёт ей щит, если враг уже ранен.
@export var only_if_card_target_low_hp: bool = false

func apply(ctx: CardContext) -> void:
	if only_if_card_target_low_hp and (ctx.targets.is_empty() or not CardCombat.is_low_hp(ctx.targets[0])):
		return
	for u in resolve_targets(ctx):
		_apply_one(ctx, u)

func _apply_one(_ctx: CardContext, _target: Unit) -> void:
	pass

## Главное число эффекта ({N} в описании карты).
func value(_caster: Unit) -> int:
	return 0

## Дополнительное число ({Nb} в описании карты).
func bonus_value(_caster: Unit) -> int:
	return 0

## Автоописание эффекта (разметка [d] [s] [h] [e]).
func describe(_caster: Unit, _card_target: CardInstance.Target) -> String:
	return ""

## Урон ли это (для проверки тега «атака»).
func deals_damage() -> bool:
	return false

func resolve_targets(ctx: CardContext) -> Array[Unit]:
	var raw: Array[Unit] = []
	var mode := target_mode
	if ctx.mirrored:
		mode = _mirror_mode(mode)
	match mode:
		TargetMode.CARD_TARGETS:
			raw = ctx.targets
		TargetMode.CASTER:
			if ctx.caster != null:
				raw.append(ctx.caster)
		TargetMode.FRONT_ALLY:
			var a := ctx.combat.front_hero()
			if a != null:
				raw.append(a)
		TargetMode.ALL_ALLIES:
			raw = ctx.combat.alive_heroes()
		TargetMode.FRONT_ENEMY:
			var e := ctx.combat.front_enemy()
			if e != null:
				raw.append(e)
		TargetMode.ALL_ENEMIES:
			raw = ctx.combat.alive_enemies()
	var out: Array[Unit] = []
	for u in raw:
		if not CardCombat.is_alive(u):
			continue
		if only_if_status != "" and not ctx.combat.has_status(u, only_if_status):
			continue
		out.append(u)
	return out

## Зеркало для очарованной героини: «свои» ↔ «чужие», «себе» — переднему врагу.
static func _mirror_mode(mode: TargetMode) -> TargetMode:
	match mode:
		TargetMode.CASTER, TargetMode.FRONT_ALLY:
			return TargetMode.FRONT_ENEMY
		TargetMode.ALL_ALLIES:
			return TargetMode.ALL_ENEMIES
		TargetMode.FRONT_ENEMY:
			return TargetMode.FRONT_ALLY
		TargetMode.ALL_ENEMIES:
			return TargetMode.ALL_ALLIES
	return mode

static func scaled(base: int, atk_ratio: float, mag_ratio: float, caster: Unit) -> int:
	if caster == null:
		return CardBalance.scale_by_level(base, CardBalance.party_level())
	return base + roundi(atk_ratio * float(caster.attack) + mag_ratio * float(caster.magic))

## «кому» для автотекста.
func target_phrase(card_target: CardInstance.Target) -> String:
	match target_mode:
		TargetMode.CASTER:
			return "себе"
		TargetMode.FRONT_ALLY:
			return "переднему союзнику"
		TargetMode.ALL_ALLIES:
			return "всем союзникам"
		TargetMode.FRONT_ENEMY:
			return "переднему врагу"
		TargetMode.ALL_ENEMIES:
			return "всем врагам"
	match card_target:
		CardInstance.Target.FRONT_ENEMY:
			return "переднему врагу"
		CardInstance.Target.ALL_ENEMIES:
			return "всем врагам"
		CardInstance.Target.SELF:
			return "себе"
		CardInstance.Target.CHOSEN_ENEMY:
			return "выбранному врагу"
		CardInstance.Target.CHOSEN_ALLY:
			return "выбранному союзнику"
	return ""

static func status_title(id: String) -> String:
	var s := CardStatuses.get_status(id)
	return s.title if s != null else id
