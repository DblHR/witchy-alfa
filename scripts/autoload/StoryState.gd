extends Node
class_name StoryState

signal changed

var intro_played: bool = false
var tutorial_battle_pending: bool = false
var tutorial_battle_completed: bool = false
var queued_cutscene_id: String = ""
var queued_cutscene_payload: Dictionary = {}

var flags: Dictionary = {}
var counters: Dictionary = {}
var quests: Dictionary = {}
var seen_dialogues: Dictionary = {}
var relationships: Dictionary = {}

func reset_to_defaults() -> void:
	intro_played = false
	tutorial_battle_pending = true
	tutorial_battle_completed = false
	queued_cutscene_id = ""
	queued_cutscene_payload = {}
	flags.clear()
	counters.clear()
	quests.clear()
	seen_dialogues.clear()
	relationships.clear()
	changed.emit()

func queue_cutscene(cutscene_id: String, payload: Dictionary = {}) -> void:
	queued_cutscene_id = cutscene_id
	queued_cutscene_payload = payload.duplicate(true)
	changed.emit()

func clear_queued_cutscene() -> void:
	queued_cutscene_id = ""
	queued_cutscene_payload = {}
	changed.emit()

func set_flag(flag_id: String, value: bool = true) -> void:
	if flag_id == "":
		return
	flags[flag_id] = value
	changed.emit()

func has_flag(flag_id: String) -> bool:
	return bool(flags.get(flag_id, false))

func add_counter(counter_id: String, amount: int = 1) -> int:
	if counter_id == "":
		return 0
	counters[counter_id] = int(counters.get(counter_id, 0)) + amount
	changed.emit()
	return int(counters[counter_id])

func get_counter(counter_id: String) -> int:
	return int(counters.get(counter_id, 0))

func start_quest(quest_id: String) -> void:
	if quest_id == "":
		return
	if not quests.has(quest_id):
		quests[quest_id] = "active"
		changed.emit()

func complete_quest(quest_id: String) -> void:
	if quest_id == "":
		return
	quests[quest_id] = "completed"
	changed.emit()

func fail_quest(quest_id: String) -> void:
	if quest_id == "":
		return
	quests[quest_id] = "failed"
	changed.emit()

func get_quest_status(quest_id: String) -> String:
	return String(quests.get(quest_id, ""))

func is_quest_active(quest_id: String) -> bool:
	return get_quest_status(quest_id) == "active"

func is_quest_completed(quest_id: String) -> bool:
	return get_quest_status(quest_id) == "completed"

func mark_dialogue_seen(dialogue_id: String) -> void:
	if dialogue_id == "":
		return
	seen_dialogues[dialogue_id] = true
	changed.emit()

func has_seen_dialogue(dialogue_id: String) -> bool:
	return bool(seen_dialogues.get(dialogue_id, false))

func add_relationship(character_id: String, amount: int = 1) -> int:
	if character_id == "":
		return 0
	relationships[character_id] = int(relationships.get(character_id, 0)) + amount
	changed.emit()
	return int(relationships[character_id])

func get_relationship(character_id: String) -> int:
	return int(relationships.get(character_id, 0))

func serialize_state() -> Dictionary:
	return {
		"intro_played": intro_played,
		"tutorial_battle_pending": tutorial_battle_pending,
		"tutorial_battle_completed": tutorial_battle_completed,
		"queued_cutscene_id": queued_cutscene_id,
		"queued_cutscene_payload": queued_cutscene_payload.duplicate(true),
		"flags": flags.duplicate(true),
		"counters": counters.duplicate(true),
		"quests": quests.duplicate(true),
		"seen_dialogues": seen_dialogues.duplicate(true),
		"relationships": relationships.duplicate(true),
	}

func apply_state(data: Dictionary) -> void:
	intro_played = bool(data.get("intro_played", false))
	tutorial_battle_pending = bool(data.get("tutorial_battle_pending", not intro_played))
	tutorial_battle_completed = bool(data.get("tutorial_battle_completed", false))
	queued_cutscene_id = String(data.get("queued_cutscene_id", ""))
	queued_cutscene_payload = data.get("queued_cutscene_payload", {}).duplicate(true)
	flags = data.get("flags", {}).duplicate(true)
	counters = data.get("counters", {}).duplicate(true)
	quests = data.get("quests", {}).duplicate(true)
	seen_dialogues = data.get("seen_dialogues", {}).duplicate(true)
	relationships = data.get("relationships", {}).duplicate(true)
	changed.emit()
