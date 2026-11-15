extends Node
class_name CardBanter
## Разговоры отряда между комнатами — теми же пузырями (BattleSpeechLayer), что и боевые фразы.
## Данные: data/banter/*.json, список "camp" (см. data/banter/README.md).
## Два момента: "loot" — окно добычи сразу после боя, "choice" — выбор следующей комнаты.

const LINE_GAP := 3.3            ## пауза между репликами, сек (пузырь живёт ~3 сек + затухание)

var speech_layer: BattleSpeechLayer
## Callable(hero_id: String) -> BattleActor (живой герой) или null.
var actor_for_hero: Callable
## Callable() -> Array[String]: id живых героев в отряде.
var alive_hero_ids: Callable

var _token: int = 0
var _last_entry: String = ""
var _playing: bool = false

func _ready() -> void:
	BanterDB.ensure_loaded()

func stop() -> void:
	_token += 1
	_playing = false
	if speech_layer != null:
		speech_layer.clear_lines()

## Один разговор в момент moment ("loot" / "choice"). ctx — что известно о забеге
## (after_room, offered, hero_low_hp, hero_dead, room_index); party добавится сам.
func play_camp(moment: String = "choice", ctx: Dictionary = {}) -> void:
	if _playing or speech_layer == null or not actor_for_hero.is_valid() or not alive_hero_ids.is_valid():
		return
	if GameSettings.banter_mult() <= 0.0:
		return   ## реплики выключены в настройках
	# Будет ли вообще разговор в этот момент: settings.json → "camp": {"choice_chance", "loot_chance"}.
	var camp_cfg = BanterDB.settings.get("camp", {})
	var moment_chance := float(camp_cfg.get(moment + "_chance", 1.0)) if camp_cfg is Dictionary else 1.0
	if randf() >= clampf(moment_chance * GameSettings.banter_mult(), 0.0, 1.0):
		return
	var alive: Array = []
	alive.assign(alive_hero_ids.call())
	if alive.is_empty():
		return
	var full := ctx.duplicate()
	full["party"] = alive
	var entry := _pick_entry(moment, full)
	if entry.is_empty():
		return
	_token += 1
	var token := _token
	_playing = true
	var id := String(entry.get("id", ""))
	_last_entry = id
	if bool(entry.get("once", false)):
		BanterDB.mark_once(id)
	for pair in entry.get("lines", []):
		if token != _token or not is_inside_tree():
			return
		var who := ""
		var text := ""
		if pair is Array and pair.size() >= 2:
			who = String(pair[0])
			text = BanterDB.pick_text(pair[1])
		elif pair is Dictionary:
			who = String(pair.get("speaker", ""))
			text = BanterDB.pick_text(pair.get("text", ""))
		var actor = actor_for_hero.call(who)
		if actor == null:
			continue
		speech_layer.show_line_for_actor(actor, BanterDB.fill(text, full))
		await get_tree().create_timer(LINE_GAP).timeout
	if token == _token:
		_playing = false

func _speakers_of(entry: Dictionary) -> Array:
	var out: Array = []
	for pair in entry.get("lines", []):
		var who := ""
		if pair is Array and pair.size() >= 1:
			who = String(pair[0])
		elif pair is Dictionary:
			who = String(pair.get("speaker", ""))
		if who != "" and not out.has(who):
			out.append(who)
	return out

func _pick_entry(moment: String, ctx: Dictionary) -> Dictionary:
	var party: Array = ctx["party"]
	var candidates: Array = []
	for e in BanterDB.camp_entries:
		var when := String(e.get("when", "choice"))
		if when != "any" and when != moment:
			continue
		var id := String(e.get("id", ""))
		if id == _last_entry:
			continue
		if bool(e.get("once", false)) and BanterDB.once_used(id):
			continue
		var ok := true
		for who in _speakers_of(e):
			if not party.has(who):
				ok = false
				break
		if not ok or not BanterDB.check(e.get("conditions", {}), ctx):
			continue
		if randf() >= clampf(float(e.get("chance", 1.0)), 0.0, 1.0):
			continue
		candidates.append(e)
	return BanterDB.pick_weighted(candidates)
