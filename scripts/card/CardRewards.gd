extends RefCounted
class_name CardRewards
## Карты для лавки. Лут боя (золото, слизь, кварц) падает с врагов — см. CardBattle._on_enemy_killed.

const SHOP_CARD_PRICE := {1: 30, 2: 45, 3: 60}

## Случайная карта героев, которые сейчас живы. exclude — id карт, которые уже предложены.
static func roll_card(run: CardRun, alive_hero_ids: Array[String], exclude: Array[String]) -> Dictionary:
	var pool: Array[CardInstance] = []
	for id in alive_hero_ids:
		var data: CharacterData = CharDB.get_by_id(id)
		if data == null:
			continue
		for d in data.card_pool:
			if d != null and not exclude.has(d.id):
				pool.append(CardInstance.from_def(d, null, data.card_color, data.display_name))
	if pool.is_empty():
		return {}
	var picked := pool[run.rng.randi_range(0, pool.size() - 1)]
	return {"type": "card", "card_id": picked.id, "title": "Новая карта", "desc": picked.title}

## Ассортимент лавки: 3 разные карты с ценой.
static func roll_shop_cards(run: CardRun, alive_hero_ids: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var taken: Array[String] = []
	for _i in range(3):
		var r := roll_card(run, alive_hero_ids, taken)
		if r.is_empty():
			break
		taken.append(String(r["card_id"]))
		var d := CardLibrary.def_by_id(String(r["card_id"]))
		r["price"] = int(SHOP_CARD_PRICE.get(clampi(d.cost if d != null else 2, 1, 3), 45))
		out.append(r)
	return out
