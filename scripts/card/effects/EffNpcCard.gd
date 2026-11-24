extends CardEffect
class_name EffNpcCard
## Карты НПС без урона: сам эффект делает бой (CardBattle._on_npc_card) по сигналу.
##   "noctris"  — в следующем выборе комнаты точно будет лишняя карта комнаты медсестры;
##   "sessilia" — случайное зелье сразу выпивается (из запаса не тратится).

@export var npc_kind: String = ""

func apply(ctx: CardContext) -> void:
	ctx.combat.npc_card_played.emit(npc_kind)
