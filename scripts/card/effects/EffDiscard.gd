extends CardEffect
class_name EffDiscard
## Сбросить N карт из руки на выбор игрока. Выбор делает CardBattle (через сигнал боя).

@export var count: int = 1

func value(_caster: Unit) -> int:
	return count

func apply(ctx: CardContext) -> void:
	if count > 0:
		ctx.combat.discard_requested.emit(count)

func describe(_caster: Unit, _card_target: CardInstance.Target) -> String:
	return "Сбросьте %d карту из руки." % count if count == 1 else "Сбросьте %d карты из руки." % count
