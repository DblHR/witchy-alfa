extends Node
class_name BattleBanterManager

const WITCH_LINES := preload("res://resources/dialogue/battle/witch_lines.tres")
const AKI_LINES := preload("res://resources/dialogue/battle/aki_lines.tres")
const LUISA_LINES := preload("res://resources/dialogue/battle/luisa_lines.tres")
const FUFU_LINES := preload("res://resources/dialogue/battle/fufu_lines.tres")

var battle_sim: Node = null
var speech_layer: BattleSpeechLayer = null
var line_sets: Array[BattleLineSet] = []
var _played_once: Dictionary = {}
var _line_cooldowns: Dictionary = {}
const GLOBAL_COOLDOWN_SEC := 3.2
const TRIGGER_COOLDOWNS := {
	"battle_start": 0.0,
	"basic_attack": 4.5,
	"ability_cast": 6.0,
	"kill_enemy": 5.0,
	"ally_low_hp": 6.0,
	"victory": 0.0,
	"between_rooms": 0.0,
}
const TRIGGER_CHANCE_MULTIPLIERS := {
	"battle_start": 1.0,
	"basic_attack": 0.55,
	"ability_cast": 0.35,
	"kill_enemy": 0.6,
	"ally_low_hp": 0.5,
	"victory": 1.0,
	"between_rooms": 1.0,
}

var _global_cooldown_until: float = 0.0
var _trigger_cooldowns: Dictionary = {}

func _ready() -> void:
	line_sets = [WITCH_LINES, AKI_LINES, LUISA_LINES, FUFU_LINES]

func start_battle(sim: Node) -> void:
	battle_sim = sim
	speech_layer = sim.get_node_or_null("%BattleSpeechLayer") as BattleSpeechLayer
	_played_once.clear()
	_line_cooldowns.clear()
	_global_cooldown_until = 0.0
	_trigger_cooldowns.clear()

func end_battle() -> void:
	if speech_layer != null:
		speech_layer.clear_lines()
	battle_sim = null
	speech_layer = null
	_played_once.clear()
	_line_cooldowns.clear()
	_global_cooldown_until = 0.0
	_trigger_cooldowns.clear()

func trigger(trigger_name: String, context: Dictionary = {}) -> void:
	if battle_sim == null or speech_layer == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < _global_cooldown_until:
		return
	var trigger_ready_at := float(_trigger_cooldowns.get(trigger_name, 0.0))
	if now < trigger_ready_at:
		return
	var requested_speaker_id := String(context.get("speaker_id", ""))
	var candidates: Array[BattleLine] = []
	for set_res in line_sets:
		if set_res == null:
			continue
		for line in set_res.lines:
			if not _matches(line, trigger_name, requested_speaker_id, now):
				continue
			if _roll(_effective_chance(line, trigger_name)):
				candidates.append(line)
	if candidates.is_empty():
		return
	var chosen: BattleLine = candidates[randi() % candidates.size()]
	var actor = _find_actor_for_speaker(chosen.speaker_id)
	if actor == null:
		return
	var accepted := speech_layer.show_line_for_actor(actor, chosen.text)
	if not accepted:
		return

	_mark_line_used(chosen, now)
	_global_cooldown_until = now + GLOBAL_COOLDOWN_SEC
	_trigger_cooldowns[trigger_name] = now + _get_trigger_cooldown(trigger_name)

func _matches(line: BattleLine, trigger_name: String, requested_speaker_id: String, now: float) -> bool:
	if line == null or not line.enabled:
		return false
	if line.trigger != trigger_name:
		return false
	if requested_speaker_id != "" and line.speaker_id != requested_speaker_id:
		return false
	if requested_speaker_id == "" and not _is_speaker_available(line.speaker_id):
		return false
	if line.once_per_battle and _played_once.get(line.line_id, false):
		return false
	var next_time := float(_line_cooldowns.get(line.line_id, 0.0))
	if now < next_time:
		return false
	return true

func _is_speaker_available(speaker_id: String) -> bool:
	return _find_actor_for_speaker(speaker_id) != null

func _find_actor_for_speaker(speaker_id: String):
	if battle_sim == null:
		return null
	var actor_groups: Array = []
	var left_arr = battle_sim.get("left_actors")
	var right_arr = battle_sim.get("right_actors")
	if left_arr is Array:
		actor_groups.append(left_arr)
	if right_arr is Array:
		actor_groups.append(right_arr)
	for arr in actor_groups:
		for actor in arr:
			if actor == null or actor.unit == null or actor.unit.data == null:
				continue
			if actor.unit.is_dead or actor.unit.hp <= 0:
				continue
			if String(actor.unit.data.id) == speaker_id:
				return actor
	return null

func _mark_line_used(line: BattleLine, now: float) -> void:
	if line.line_id != "":
		_played_once[line.line_id] = true
		if line.cooldown_sec > 0.0:
			_line_cooldowns[line.line_id] = now + line.cooldown_sec

func _roll(chance: float) -> bool:
	if chance >= 1.0:
		return true
	if chance <= 0.0:
		return false
	return randf() <= chance

func _effective_chance(line: BattleLine, trigger_name: String) -> float:
	var multiplier := float(TRIGGER_CHANCE_MULTIPLIERS.get(trigger_name, 1.0))
	return clampf(line.chance * multiplier, 0.0, 1.0)

func _get_trigger_cooldown(trigger_name: String) -> float:
	return float(TRIGGER_COOLDOWNS.get(trigger_name, GLOBAL_COOLDOWN_SEC))
