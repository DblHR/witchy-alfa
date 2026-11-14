extends Node
class_name BattleBanterManager
## Реплики-пузыри в бою. Фразы — data/banter/*.json, список "battle" (см. data/banter/README.md).
## CardBattle сообщает о событиях: trigger("kill_enemy", {"actor": "aki", "enemy": "shlep", ...}).
## Здесь выбирается подходящая фраза (триггер, кто говорит, условия, шанс, кулдауны) и показывается.

## Значения по умолчанию. Всё это можно переопределить в data/banter/settings.json ("settings").
const GLOBAL_COOLDOWN_SEC := 3.2   ## общая пауза между любыми фразами (кроме «важных» триггеров), сек
const REPLY_GAP := 2.4             ## пауза перед ответной репликой (поле "reply"), сек

## Триггер -> chance: шанс, что на событие вообще кто-то ответит; cooldown: пауза триггера (сек);
## about: кто говорит по умолчанию (actor — тот, кто действовал; target — на ком событие;
## other — кто-то третий; any — любой); important: игнорирует общую паузу.
const TRIGGERS := {
	"battle_start": {"chance": 0.8, "cooldown": 0.0, "about": "any", "important": true},
	"turn_start": {"chance": 0.3, "cooldown": 10.0, "about": "any", "important": false},
	"card_played": {"chance": 0.3, "cooldown": 3.5, "about": "actor", "important": false},
	"ult": {"chance": 0.85, "cooldown": 0.0, "about": "actor", "important": true},
	"kill_enemy": {"chance": 0.55, "cooldown": 3.0, "about": "actor", "important": false},
	"last_enemy": {"chance": 0.5, "cooldown": 0.0, "about": "any", "important": false},
	"status_applied": {"chance": 0.3, "cooldown": 4.0, "about": "actor", "important": false},
	"heal": {"chance": 0.45, "cooldown": 4.0, "about": "actor", "important": false},
	"shield": {"chance": 0.25, "cooldown": 5.0, "about": "actor", "important": false},
	"ally_down": {"chance": 1.0, "cooldown": 0.0, "about": "other", "important": true},
	"ally_low_hp": {"chance": 0.7, "cooldown": 6.0, "about": "target", "important": false},
	"big_hit": {"chance": 0.45, "cooldown": 5.0, "about": "target", "important": false},
	"enemy_low_hp": {"chance": 0.4, "cooldown": 6.0, "about": "any", "important": false},
	"capture": {"chance": 1.0, "cooldown": 0.0, "about": "any", "important": true},
	"victory": {"chance": 0.6, "cooldown": 0.0, "about": "any", "important": true},
}

func _trigger_info(trigger_name: String) -> Dictionary:
	var info: Dictionary = TRIGGERS.get(trigger_name, {"chance": 0.3, "cooldown": GLOBAL_COOLDOWN_SEC, "about": "any", "important": false}).duplicate()
	var custom = BanterDB.settings.get("triggers", {})
	if custom is Dictionary and custom.get(trigger_name) is Dictionary:
		info.merge(custom[trigger_name], true)
	return info

func _setting(key: String, fallback: float) -> float:
	return float(BanterDB.settings.get(key, fallback))

var battle_sim: Node = null
var speech_layer: BattleSpeechLayer = null
var _played_once: Dictionary = {}
var _line_cooldowns: Dictionary = {}
var _global_cooldown_until: float = 0.0
var _trigger_cooldowns: Dictionary = {}
var _battle_token := 0

func _ready() -> void:
	BanterDB.ensure_loaded()

func start_battle(sim: Node) -> void:
	battle_sim = sim
	speech_layer = sim.get_node_or_null("%BattleSpeechLayer") as BattleSpeechLayer
	_reset()

func end_battle() -> void:
	if speech_layer != null:
		speech_layer.clear_lines()
	battle_sim = null
	speech_layer = null
	_reset()

func _reset() -> void:
	_battle_token += 1
	_played_once.clear()
	_line_cooldowns.clear()
	_global_cooldown_until = 0.0
	_trigger_cooldowns.clear()

## Событие боя. Возвращает true, если кто-то что-то сказал.
func trigger(trigger_name: String, context: Dictionary = {}) -> bool:
	if battle_sim == null or speech_layer == null or not is_instance_valid(battle_sim):
		return false
	var info := _trigger_info(trigger_name)
	var now := Time.get_ticks_msec() / 1000.0
	if not bool(info.get("important", false)) and now < _global_cooldown_until:
		return false
	if now < float(_trigger_cooldowns.get(trigger_name, 0.0)):
		return false
	# Сначала — ответит ли кто-то вообще (частота триггера), потом выбор фразы.
	# Ползунок «Частота реплик» в настройках умножает шанс (0% — молчат совсем).
	if randf() >= clampf(float(info.get("chance", 1.0)) * GameSettings.banter_mult(), 0.0, 1.0):
		return false
	var ctx := _full_context(context)
	var candidates: Array = []
	for line in BanterDB.battle_lines:
		if String(line.get("trigger", "")) != trigger_name:
			continue
		if not _matches(line, ctx, String(info.get("about", "any")), now):
			continue
		# "chance" у фразы — насколько она редкая (1.0 по умолчанию: всегда в числе кандидатов).
		if randf() <= clampf(float(line.get("chance", 1.0)), 0.0, 1.0):
			candidates.append(line)
	if candidates.is_empty():
		return false
	var chosen := BanterDB.pick_weighted(candidates)
	var actor = _find_actor(String(chosen.get("speaker", "")), bool(chosen.get("enemy", false)))
	if actor == null:
		return false
	var text := BanterDB.fill(BanterDB.pick_text(chosen.get("text", "")), ctx)
	if not speech_layer.show_line_for_actor(actor, text):
		return false
	var id := String(chosen.get("id", ""))
	_played_once[id] = true
	if float(chosen.get("cooldown", 0.0)) > 0.0:
		_line_cooldowns[id] = now + float(chosen["cooldown"])
	if bool(chosen.get("once", false)):
		BanterDB.mark_once(id)
	_global_cooldown_until = now + _setting("global_cooldown", GLOBAL_COOLDOWN_SEC)
	_trigger_cooldowns[trigger_name] = now + float(info.get("cooldown", 0.0))
	if chosen.has("reply"):
		_play_replies(chosen["reply"], ctx)
	return true

## Контекст + то, что бой знает сам: живой отряд, враги в комнате, тип комнаты, ход.
func _full_context(context: Dictionary) -> Dictionary:
	var ctx := context.duplicate()
	if ctx.has("speaker_id") and not ctx.has("actor"):
		ctx["actor"] = ctx["speaker_id"]
	if battle_sim.has_method("run_alive_ids"):
		ctx["party"] = battle_sim.call("run_alive_ids")
	var enemies: Array = []
	for a in _actors(true):
		enemies.append(String(a.unit.data.id))
	ctx["enemies"] = enemies
	if battle_sim.has_method("banter_room_info"):
		var info: Dictionary = battle_sim.call("banter_room_info")
		for k in info.keys():
			if not ctx.has(k):
				ctx[k] = info[k]
	return ctx

func _matches(line: Dictionary, ctx: Dictionary, default_about: String, now: float) -> bool:
	var id := String(line.get("id", ""))
	var speaker := String(line.get("speaker", ""))
	var is_enemy := bool(line.get("enemy", false))
	if _find_actor(speaker, is_enemy) == null:
		return false
	match String(line.get("about", default_about)):
		"actor":
			if speaker != String(ctx.get("actor", "")):
				return false
		"target":
			if speaker != String(ctx.get("target", "")):
				return false
		"other":
			if speaker == String(ctx.get("actor", "")) or speaker == String(ctx.get("target", "")):
				return false
	if bool(line.get("once_per_battle", false)) and _played_once.has(id):
		return false
	if bool(line.get("once", false)) and BanterDB.once_used(id):
		return false
	if now < float(_line_cooldowns.get(id, 0.0)):
		return false
	return BanterDB.check(line.get("conditions", {}), ctx)

## Ответы: "reply": [{"speaker": "witch", "text": "..."}] — по очереди, если говорящий жив.
func _play_replies(replies, ctx: Dictionary) -> void:
	var token := _battle_token
	for r in (replies if replies is Array else [replies]):
		if not (r is Dictionary):
			continue
		await get_tree().create_timer(_setting("reply_gap", REPLY_GAP)).timeout
		if token != _battle_token or speech_layer == null:
			return
		var actor = _find_actor(String(r.get("speaker", "")), bool(r.get("enemy", false)))
		if actor == null:
			continue
		speech_layer.show_line_for_actor(actor, BanterDB.fill(BanterDB.pick_text(r.get("text", "")), ctx))
		_global_cooldown_until = Time.get_ticks_msec() / 1000.0 + _setting("global_cooldown", GLOBAL_COOLDOWN_SEC)

func _actors(enemies: bool) -> Array:
	if battle_sim == null:
		return []
	var arr = battle_sim.get("right_actors" if enemies else "left_actors")
	var out: Array = []
	if arr is Array:
		for actor in arr:
			if actor == null or not is_instance_valid(actor) or actor.unit == null or actor.unit.data == null:
				continue
			if actor.unit.is_dead or actor.unit.hp <= 0:
				continue
			out.append(actor)
	return out

## Живой герой (или враг, если enemy) с таким id на поле.
func _find_actor(speaker_id: String, enemy: bool = false):
	if speaker_id == "":
		return null
	for actor in _actors(enemy):
		if String(actor.unit.data.id) == speaker_id:
			return actor
	return null
