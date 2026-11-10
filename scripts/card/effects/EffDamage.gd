extends CardEffect
class_name EffDamage
## Урон. Скейл по умолчанию — от атаки.
## Можно привязать к стакам статуса на цели: «за каждый стак» или «+N за каждый стак».

enum StackMode {
	NONE,            ## просто урон
	PER_STACK,       ## урон × стаки (нет стаков — нет урона)
	PLUS_PER_STACK,  ## урон + bonus_per_stack × стаки
	HIT_PER_STACK,   ## отдельный удар за каждый стак (нет стаков — нет ударов)
	HIT_PLUS_PER_STACK,  ## 1 гарантированный удар + по удару за каждый стак
}

@export var base: int = 0
@export var atk_ratio: float = 0.0
@export var mag_ratio: float = 0.0
@export var stack_status: String = ""
@export var stack_mode: StackMode = StackMode.NONE
## Для PLUS_PER_STACK: сколько урона за стак — постоянное число и/или доля Атаки владельца.
@export var bonus_per_stack: int = 0
@export var bonus_atk_ratio: float = 0.0
## Сколько раз ударить (для режимов без «удара за стак»): «Серия толчков» — 3 удара.
@export var hits: int = 1
## Снять все стаки после удара.
@export var consume_stacks: bool = false
## После каждого удара добавить цели столько стаков stack_status (урон следующего удара растёт):
## «Серия толчков» — каждый толчок +1 Нажим.
@export var stacks_per_hit: int = 0

func value(caster: Unit) -> int:
	return scaled(base, atk_ratio, mag_ratio, caster)

func bonus_value(caster: Unit) -> int:
	return bonus_per_stack + (scaled(0, bonus_atk_ratio, 0.0, caster) if bonus_atk_ratio > 0.0 else 0)

func deals_damage() -> bool:
	return true

func _apply_one(ctx: CardContext, target: Unit) -> void:
	var amount := value(ctx.caster)
	if stack_mode == StackMode.HIT_PER_STACK or stack_mode == StackMode.HIT_PLUS_PER_STACK:
		var n_hits := ctx.combat.stacks(target, stack_status)
		if stack_mode == StackMode.HIT_PLUS_PER_STACK:
			n_hits += 1
		if consume_stacks and stack_status != "":
			ctx.combat.remove_stacks(target, stack_status)
		for i in range(n_hits):
			if not CardCombat.is_alive(target):
				break
			ctx.combat.deal_damage(ctx.caster, target, amount, true)
		return
	if stack_status != "" and stack_mode != StackMode.NONE:
		var n := ctx.combat.stacks(target, stack_status)
		if stack_mode == StackMode.PER_STACK:
			if n <= 0:
				return
			amount *= n
		else:
			amount += bonus_value(ctx.caster) * n
	if consume_stacks and stack_status != "":
		ctx.combat.remove_stacks(target, stack_status)
	for i in range(maxi(1, hits)):
		if not CardCombat.is_alive(target):
			break
		if i > 0 and stacks_per_hit > 0 and stack_mode == StackMode.PLUS_PER_STACK:
			amount = value(ctx.caster) + bonus_value(ctx.caster) * ctx.combat.stacks(target, stack_status)
		ctx.combat.deal_damage(ctx.caster, target, amount, true)
		if stacks_per_hit > 0 and stack_status != "" and CardCombat.is_alive(target):
			ctx.combat.add_status(target, stack_status, stacks_per_hit, 0)

func describe(caster: Unit, card_target: CardInstance.Target) -> String:
	var who := target_phrase(card_target)
	match stack_mode:
		StackMode.PER_STACK:
			return "[d]%d[/d] урона %s за стак: [e]%s[/e]." % [value(caster), who, status_title(stack_status)]
		StackMode.HIT_PER_STACK:
			return "[d]%d[/d] урона %s, удар за каждый стак: [e]%s[/e]." % [value(caster), who, status_title(stack_status)]
		StackMode.HIT_PLUS_PER_STACK:
			return "[d]%d[/d] урона %s, ещё удар за каждый стак: [e]%s[/e]." % [value(caster), who, status_title(stack_status)]
		StackMode.PLUS_PER_STACK:
			return "[d]%d[/d] урона %s, [d]+%d[/d] за стак: [e]%s[/e]." % [value(caster), who, bonus_value(caster), status_title(stack_status)]
	if hits > 1:
		return "%d удара по [d]%d[/d] урона %s." % [hits, value(caster), who]
	return "[d]%d[/d] урона %s." % [value(caster), who]
