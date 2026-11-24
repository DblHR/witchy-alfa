extends EffDamage
class_name EffGoldStrike
## Карта Рикки: урон = золото, заработанное за этот забег (DungRun.run_gold_earned) × gold_ratio.
## Карта тратит это золото (сколько есть) — и счётчик «заработано» обнуляется.

@export var gold_ratio: float = 1.0

func value(_caster: Unit) -> int:
	return roundi(float(DungRun.run_gold_earned) * gold_ratio) if DungRun != null else 0

func _apply_one(ctx: CardContext, target: Unit) -> void:
	var amount := value(ctx.caster)
	if amount > 0:
		ctx.combat.deal_damage(ctx.caster, target, amount, true)
	if DungRun != null:
		DungRun.spend_gold(mini(DungRun.gold, DungRun.run_gold_earned))
		DungRun.run_gold_earned = 0
	ctx.combat.npc_card_played.emit("rikka")
