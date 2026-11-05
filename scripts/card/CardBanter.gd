extends Node
class_name CardBanter
## Разговоры отряда между комнатами. Реплики показываются теми же пузырями
## (BattleSpeechLayer), что и боевые фразы. Данные: CardBanterData.

const LINE_GAP := 3.3            ## пауза между репликами, сек (пузырь живёт ~3 сек + затухание)
const EXCHANGE_CHANCE := 0.75    ## шанс диалога вместо одиночной реплики

var speech_layer: BattleSpeechLayer
## Callable(hero_id: String) -> BattleActor (живой герой) или null.
var actor_for_hero: Callable
## Callable() -> Array[String]: id живых героев в отряде.
var alive_hero_ids: Callable

var _token: int = 0
var _last_exchange: String = ""
var _playing: bool = false

func stop() -> void:
	_token += 1
	_playing = false
	if speech_layer != null:
		speech_layer.clear_lines()

## Один разговор между комнатами (диалог, а если пары нет — одиночная реплика).
func play_camp() -> void:
	if _playing or speech_layer == null or not actor_for_hero.is_valid() or not alive_hero_ids.is_valid():
		return
	_token += 1
	var token := _token
	var alive: Array[String] = []
	alive.assign(alive_hero_ids.call())
	if alive.is_empty():
		return
	_playing = true
	for pair in _pick_lines(alive):
		if token != _token or not is_inside_tree():
			return
		var actor = actor_for_hero.call(String(pair[0]))
		if actor == null:
			continue
		speech_layer.show_line_for_actor(actor, String(pair[1]))
		await get_tree().create_timer(LINE_GAP).timeout
	if token == _token:
		_playing = false

func _pick_lines(alive: Array[String]) -> Array:
	var candidates: Array = []
	if randf() < EXCHANGE_CHANCE:
		for ex in CardBanterData.EXCHANGES:
			var ok := true
			for s in ex["speakers"]:
				if not alive.has(String(s)):
					ok = false
			if ok and String(ex["id"]) != _last_exchange:
				candidates.append(ex)
	if not candidates.is_empty():
		var ex: Dictionary = candidates[randi() % candidates.size()]
		_last_exchange = String(ex["id"])
		return ex["lines"]
	var who := alive[randi() % alive.size()]
	var pool: Array = CardBanterData.SOLO.get(who, [])
	if pool.is_empty():
		return []
	return [[who, String(pool[randi() % pool.size()])]]
