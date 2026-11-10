extends Node
class_name StoryDialogueDB

const DIALOGUE_ROOT := "res://data/dialogues"

var dialogues_by_id: Dictionary = {}
var dialogues_by_npc: Dictionary = {}
var dialogues_by_quest: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> void:
	dialogues_by_id.clear()
	dialogues_by_npc.clear()
	dialogues_by_quest.clear()
	_load_folder(DIALOGUE_ROOT)

func _load_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		push_warning("StoryDialogueDB: dialogue folder not found: %s" % path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path := path.path_join(file_name)
		if dir.current_is_dir():
			_load_folder(full_path)
		elif file_name.ends_with(".json"):
			_load_file(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("StoryDialogueDB: cannot open %s" % path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Array:
		for entry in parsed:
			_register_dialogue(entry, path)
	elif parsed is Dictionary:
		if parsed.has("dialogues"):
			for entry in parsed.get("dialogues", []):
				_register_dialogue(entry, path)
		else:
			_register_dialogue(parsed, path)
	else:
		push_warning("StoryDialogueDB: invalid JSON root in %s" % path)

func _register_dialogue(entry, path: String) -> void:
	if not (entry is Dictionary):
		return
	var d: Dictionary = entry.duplicate(true)
	var id := String(d.get("id", ""))
	if id == "":
		push_warning("StoryDialogueDB: dialogue without id in %s" % path)
		return
	d["_source_path"] = path
	dialogues_by_id[id] = d
	var npc_id := String(d.get("npc", ""))
	if npc_id != "":
		if not dialogues_by_npc.has(npc_id):
			dialogues_by_npc[npc_id] = []
		dialogues_by_npc[npc_id].append(d)
	var quest_id := String(d.get("quest", ""))
	if quest_id != "":
		if not dialogues_by_quest.has(quest_id):
			dialogues_by_quest[quest_id] = []
		dialogues_by_quest[quest_id].append(d)

func get_dialogue(dialogue_id: String) -> Dictionary:
	return dialogues_by_id.get(dialogue_id, {})

func pick_npc_dialogue(npc_id: String, wanted_type: String = "") -> Dictionary:
	var candidates: Array = []
	for d in dialogues_by_npc.get(npc_id, []):
		if wanted_type != "" and String(d.get("type", "")) != wanted_type:
			continue
		if not _can_play(d):
			continue
		candidates.append(d)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	var top_priority := int(candidates[0].get("priority", 0))
	var top: Array = []
	for d in candidates:
		if int(d.get("priority", 0)) == top_priority:
			top.append(d)
	var total_weight := 0
	for d in top:
		total_weight += maxi(1, int(d.get("weight", 1)))
	var roll := DungRun.rng.randi_range(1, maxi(total_weight, 1)) if DungRun != null else randi_range(1, maxi(total_weight, 1))
	var acc := 0
	for d in top:
		acc += maxi(1, int(d.get("weight", 1)))
		if roll <= acc:
			return d
	return top[0]

## Есть ли у NPC непрочитанный диалог, который выдаёт квест (для значка «!» на кнопке).
func npc_has_quest_offer(npc_id: String) -> bool:
	for d in dialogues_by_npc.get(npc_id, []):
		var fin = d.get("on_finish", {})
		if not (fin is Dictionary) or not (fin as Dictionary).has("start_quest"):
			continue
		var id := String(d.get("id", ""))
		if bool(d.get("once", false)) and StoryState_ != null and StoryState_.has_seen_dialogue(id):
			continue
		if check_conditions(d.get("conditions", {})):
			return true
	return false

func pick_intro_for_event(event_type: int, statue_variant: int = 0, npc_override: String = "") -> Dictionary:
	var npc_id := npc_override if npc_override != "" else event_type_to_npc_id(event_type, statue_variant)
	var event_d := pick_npc_dialogue(npc_id, "event")
	if not event_d.is_empty():
		return event_d
	return pick_npc_dialogue(npc_id, "flag")

func event_type_to_npc_id(event_type: int, statue_variant: int = 0) -> String:
	match event_type:
		RoomParams.EventType.SHOP:
			return "lamia"
		RoomParams.EventType.NURSE:
			return "nurse"
		RoomParams.EventType.CHEST:
			return "chest"
		RoomParams.EventType.STATUE:
			return "statue_white" if statue_variant == RoomParams.StatueVariant.WHITE else "statue_black"
		RoomParams.EventType.QUEST:
			return "quest"
		_:
			return ""

func pick_quest_room_dialogue(quest_id: String) -> Dictionary:
	var candidates: Array = []
	for d in dialogues_by_quest.get(quest_id, []):
		if String(d.get("type", "")) != "quest_room":
			continue
		if _can_play(d):
			candidates.append(d)
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0))
	)
	return candidates[0]

func resolve_lines(dialogue: Dictionary) -> Array:
	var out: Array = []
	for raw_line in dialogue.get("lines", []):
		if raw_line is String:
			out.append({"speaker_name": "", "text": String(raw_line)})
		elif raw_line is Dictionary:
			out.append(_resolve_line(raw_line))
	return out

func _resolve_line(raw: Dictionary) -> Dictionary:
	var line := raw.duplicate(true)
	var speaker_id := String(line.get("speaker", line.get("speaker_id", "")))
	if not line.has("speaker_name"):
		line["speaker_name"] = get_character_name(speaker_id)
	if line.has("characters"):
		var resolved_chars: Array = []
		for c in line.get("characters", []):
			if not (c is Dictionary):
				continue
			var rc: Dictionary = c.duplicate(true)
			var cid := String(rc.get("id", ""))
			if not rc.has("name"):
				rc["name"] = get_character_name(cid)
			if not rc.has("portrait"):
				rc["portrait"] = get_character_portrait(cid, String(rc.get("emotion", "")))
			resolved_chars.append(rc)
		line["characters"] = resolved_chars
	elif speaker_id != "":
		line["characters"] = [{"id": speaker_id, "portrait": get_character_portrait(speaker_id, String(line.get("emotion", "")))}]
	if not line.has("active_character") and speaker_id != "":
		line["active_character"] = speaker_id
	return line

func get_character_name(character_id: String) -> String:
	match character_id:
		"rabbit_shop": return "Кролик-торговка"
		"nurse": return "Медсестра"
		"chest": return "Сундук"
		"statue_white": return "Белая статуя"
		"statue_black": return "Чёрная статуя"
		"fufu": return "Фуфу"
		"player": return "Шляпка"
		"lamia": return "Ламия"
		_:
			if CharDB != null:
				var cd := CharDB.get_by_id(character_id)
				if cd != null and cd.display_name != "":
					return cd.display_name
			return character_id

func get_character_portrait(character_id: String, emotion: String = "") -> Texture2D:
	if AssetCatalog_ != null:
		var event_tex := AssetCatalog_.get_event_npc_texture(character_id)
		if event_tex != null:
			return event_tex
	if CharDB != null:
		var cd := CharDB.get_by_id(character_id)
		if cd != null:
			# VN/story dialogues use character cards, not combat sprites.
			# Combat sprites are sized for the battlefield and look wrong in the VN frame.
			if cd.card_portrait != null:
				return cd.card_portrait
			if cd.battle_texture != null:
				return cd.battle_texture
	return null

func _can_play(dialogue: Dictionary) -> bool:
	var id := String(dialogue.get("id", ""))
	if bool(dialogue.get("once", false)) and StoryState_ != null and StoryState_.has_seen_dialogue(id):
		return false
	if not check_conditions(dialogue.get("conditions", {})):
		return false
	if dialogue.has("chance"):
		var chance := clampf(float(dialogue.get("chance", 1.0)), 0.0, 1.0)
		var roll := DungRun.rng.randf() if DungRun != null else randf()
		if roll > chance:
			return false
	return true

func check_conditions(conditions) -> bool:
	if not (conditions is Dictionary):
		return true
	var c: Dictionary = conditions
	if c.has("flag") and StoryState_ != null and not StoryState_.has_flag(String(c["flag"])):
		return false
	if c.has("not_flag") and StoryState_ != null and StoryState_.has_flag(String(c["not_flag"])):
		return false
	if c.has("party_level_min") and DungRun != null and DungRun.party_level < int(c["party_level_min"]):
		return false
	if c.has("rooms_cleared_min") and DungRun != null and DungRun.rooms_cleared < int(c["rooms_cleared_min"]):
		return false
	if c.has("has_unit") and (UnitRoster_ == null or not UnitRoster_.has_unit(String(c["has_unit"]))):
		return false
	if c.has("not_has_unit") and UnitRoster_ != null and UnitRoster_.has_unit(String(c["not_has_unit"])):
		return false
	if c.has("has_item") and (Inventory_ == null or not Inventory_.has_item(String(c["has_item"]))):
		return false
	if c.has("not_has_item") and Inventory_ != null and Inventory_.has_item(String(c["not_has_item"])):
		return false
	if c.has("quest_active") and StoryState_ != null and not StoryState_.is_quest_active(String(c["quest_active"])):
		return false
	if c.has("quest_completed") and StoryState_ != null and not StoryState_.is_quest_completed(String(c["quest_completed"])):
		return false
	if c.has("quest_not_started") and StoryState_ != null and StoryState_.get_quest_status(String(c["quest_not_started"])) != "":
		return false
	if c.has("counter_min") and StoryState_ != null:
		for key in c["counter_min"].keys():
			if StoryState_.get_counter(String(key)) < int(c["counter_min"][key]):
				return false
	if c.has("relationship_min") and StoryState_ != null:
		for key in c["relationship_min"].keys():
			if StoryState_.get_relationship(String(key)) < int(c["relationship_min"][key]):
				return false
	return true

func apply_effects(effects) -> void:
	if not (effects is Dictionary):
		return
	var e: Dictionary = effects
	if StoryState_ != null:
		for flag_id in e.get("set_flags", []):
			StoryState_.set_flag(String(flag_id), true)
		for flag_id in e.get("clear_flags", []):
			StoryState_.set_flag(String(flag_id), false)
		if e.has("start_quest"):
			StoryState_.start_quest(String(e["start_quest"]))
		if e.has("complete_quest"):
			StoryState_.complete_quest(String(e["complete_quest"]))
		if e.has("fail_quest"):
			StoryState_.fail_quest(String(e["fail_quest"]))
		if e.has("add_counters"):
			for key in e["add_counters"].keys():
				StoryState_.add_counter(String(key), int(e["add_counters"][key]))
		if e.has("relationship_add"):
			for key in e["relationship_add"].keys():
				StoryState_.add_relationship(String(key), int(e["relationship_add"][key]))
	if Inventory_ != null:
		if e.has("add_item"):
			Inventory_.add_item(String(e["add_item"]), int(e.get("add_item_amount", 1)))
		if e.has("remove_item"):
			Inventory_.remove_item(String(e["remove_item"]), int(e.get("remove_item_amount", 1)))
	if UnitRoster_ != null and e.has("unlock_unit"):
		UnitRoster_.unlock_unit(String(e["unlock_unit"]))
