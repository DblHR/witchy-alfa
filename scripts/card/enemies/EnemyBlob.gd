extends EnemyDef
class_name EnemyBlob
## Большая блёба: крупнее остальных. Как только HP падает до половины — делится на две
## маленькие блёбы (сама исчезает). У каждой — доля оставшегося HP.

const SPLIT_AT := 0.5
## Сколько от оставшегося HP получает каждая половинка.
const CHILD_HP_SHARE := 0.6
const CHILD_ID := "blob_mini"

func on_hurt(api: EnemyApi, me: Unit, _amount: int) -> void:
	if not CardCombat.is_alive(me) or bool(me.ai.get("split", false)):
		return
	if float(me.hp) > float(me.max_hp) * SPLIT_AT:
		return
	me.ai["split"] = true
	var child_hp := maxi(1, roundi(float(me.hp) * CHILD_HP_SHARE))
	api.say(me, "Делится!", CardCombat.COL_STATUS)
	api.vanish(me)
	api.summon([CHILD_ID, CHILD_ID], child_hp, me)
