extends RefCounted
class_name CardDeck
## Колода, рука и сброс. Чистые данные: ничего не знает про сцены и UI.

var draw_pile: Array[CardInstance] = []
var hand: Array[CardInstance] = []
var discard_pile: Array[CardInstance] = []
## Сгоревшие карты (exhaust): в этом бою в колоду не возвращаются.
## Сгоревшие «до конца забега» запоминает ещё и CardRun (CardRun.burned_for_run).
var burned_pile: Array[CardInstance] = []

func start_battle(cards: Array[CardInstance]) -> void:
	draw_pile.clear()
	draw_pile.append_array(cards)
	hand.clear()
	discard_pile.clear()
	burned_pile.clear()
	draw_pile.shuffle()

## Берёт до `count` карт в руку. Если колода кончилась — сброс перемешивается
## и становится новой колодой. Возвращает реально взятые карты.
func draw(count: int) -> Array[CardInstance]:
	var drawn: Array[CardInstance] = []
	for i in range(count):
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile.append_array(discard_pile)
			discard_pile.clear()
			draw_pile.shuffle()
		var c: CardInstance = draw_pile.pop_back()
		hand.append(c)
		drawn.append(c)
	return drawn

## Разыгранная карта уходит из руки в сброс (или сгорает, если у неё exhaust).
func play_card(card: CardInstance) -> bool:
	var idx := hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
	if card.exhaust:
		burned_pile.append(card)
	else:
		discard_pile.append(card)
	return true

## Сбросить одну карту из руки (эффект «сбросьте карту»).
func discard_card(card: CardInstance) -> bool:
	var idx := hand.find(card)
	if idx == -1:
		return false
	hand.remove_at(idx)
	discard_pile.append(card)
	return true

func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()

## Герой выбыл — его карты уходят из боя (из колоды, руки, сброса и сгоревших).
func remove_owner_cards(owner_id: String) -> void:
	for pile in [draw_pile, hand, discard_pile, burned_pile]:
		for i in range(pile.size() - 1, -1, -1):
			if pile[i].owner_id == owner_id:
				pile.remove_at(i)
