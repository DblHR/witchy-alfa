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
	_load_names()
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

## Проверка диалога при загрузке: предупреждения в консоль Godot, если картинки "cg" нет на диске
## (игра молча покажет диалог без неё). {hero_id} проверяется для обоих героев.
func _check_dialogue(d: Dictionary, path: String) -> void:
	var lines = d.get("lines", [])
	if not (lines is Array):
		push_warning("Диалоги: %s, «%s» — lines должно быть списком [...]" % [path.get_file(), String(d.get("id", ""))])
		return
	for i in range((lines as Array).size()):
		var l = lines[i]
		if not (l is Dictionary):
			push_warning("Диалоги: %s, «%s» — реплика %d не в фигурных скобках" % [path.get_file(), String(d.get("id", "")), i + 1])
			continue
		var cg := String(l.get("cg", ""))
		if cg == "":
			continue
		for hero in (StoryState.MAIN_HERO_OPTIONS if cg.contains("{hero_id}") else [""]):
			var cg_path := cg.replace("{hero_id}", String(hero))
			if not ResourceLoader.exists(cg_path):
				push_warning("Диалоги: %s, «%s», реплика %d — нет картинки %s" % [path.get_file(), String(d.get("id", "")), i + 1, cg_path])

func _register_dialogue(entry, path: String) -> void:
	if not (entry is Dictionary):
		return
	var d: Dictionary = entry.duplicate(true)
	var id := String(d.get("id", ""))
	if id == "":
		push_warning("StoryDialogueDB: dialogue without id in %s" % path)
		return
	d["_source_path"] = path
	if dialogues_by_id.has(id):
		push_warning("Диалоги: id «%s» повторяется (%s и %s) — останется последний" % [id, String(dialogues_by_id[id].get("_source_path", "")).get_file(), path.get_file()])
	_check_dialogue(d, path)
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

## Любой доступный диалог указанного типа (без привязки к NPC), с учётом priority/weight.
## Например "after_run" — сцены, которые играются в хабе после конца забега.
func pick_dialogue_of_type(wanted_type: String) -> Dictionary:
	var best: Dictionary = {}
	for d in dialogues_by_id.values():
		if String(d.get("type", "")) != wanted_type or not _can_play(d):
			continue
		if best.is_empty() or int(d.get("priority", 0)) > int(best.get("priority", 0)):
			best = d
	return best

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

## Зажигает ли диалог значок «!». Можно задать прямо: "notify": true / false.
## По умолчанию: сцены с героинями дома (hub_talk) — да; остальные — только если диалог что-то
## меняет (есть on_finish: предмет, квест, флаг...) или выдаёт предмет репликой (give_item).
func _dialogue_notifies(d: Dictionary) -> bool:
	if d.has("notify"):
		return bool(d["notify"])
	if String(d.get("type", "")) == "hub_talk":
		return true
	var fin = d.get("on_finish", {})
	if fin is Dictionary and not (fin as Dictionary).is_empty():
		return true
	for l in d.get("lines", []):
		if l is Dictionary and (l.has("give_item") or l.has("notice")):
			return true
	return false

## --- Дежурные фразы (пузыри у NPC в ивент-комнатах) ---
## Дежурная = не разовая (once), ничего не меняет (нет on_finish), без выбора / выдачи предметов /
## уведомлений, и все реплики — самого NPC. Такие диалоги в ивент-комнатах показываются пузырём
## рядом с NPC, а не окном VN. Тип "bark" — только для пузырей (клик по NPC), в VN не попадает никогда.
const BARK_TYPE := "bark"

func is_routine(d: Dictionary) -> bool:
	if d.is_empty() or bool(d.get("once", false)):
		return false
	var fin = d.get("on_finish", {})
	if fin is Dictionary and not (fin as Dictionary).is_empty():
		return false
	var npc := String(d.get("npc", ""))
	for l in d.get("lines", []):
		if not (l is Dictionary):
			return false
		if l.has("choices") or l.has("give_item") or l.has("notice") or String(l.get("cg", "")) != "":
			return false
		if String(l.get("speaker", npc)) != npc:
			return false
	return true

## Все дежурные фразы NPC, доступные сейчас (условия выполнены): для клика по NPC.
func routine_dialogues(npc_id: String) -> Array:
	var out: Array = []
	for d in dialogues_by_npc.get(npc_id, []):
		var t := String(d.get("type", ""))
		if not ["event", "flag", BARK_TYPE].has(t):
			continue
		if is_routine(d) and check_conditions(d.get("conditions", {})):
			out.append(d)
	return out

## Есть ли у NPC/героини что-то новое для значка «!»: квест или ещё не виденный разовый диалог
## (once: true) нужного типа, условия которого уже выполнены и который что-то даёт
## (см. _dialogue_notifies). Диалоги с "chance" не считаются.
func npc_has_news(npc_id: String, types: Array = ["event"]) -> bool:
	if npc_has_quest_offer(npc_id):
		return true
	for d in dialogues_by_npc.get(npc_id, []):
		if not bool(d.get("once", false)) or d.has("chance") or not types.has(String(d.get("type", ""))):
			continue
		if not _dialogue_notifies(d):
			continue
		if StoryState_ != null and StoryState_.has_seen_dialogue(String(d.get("id", ""))):
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
			return "sessilia"
		RoomParams.EventType.NOCTRIS:
			return "noctris"
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

## Поля реплики (пустая строка или нет поля — стандартное значение):
##   speaker      — id говорящего (witch, rikka, ...)
##   speaker_name — имя на плашке только в этой реплике; пусто — имя из data/characters/names.json
##                  (например «Девушка-кролик», пока Рикка не представилась)
##   emotion      — эмоция говорящего: картинка assets/characters/<id>/emotions/<id>_<emotion>.png
##                  (у NPC — assets/npc/<id>/emotions/: noctris_confusion.png, rikka_happy.png)
##                  (или <emotion>.png); "emotion": "shy" → fufu_shy.png. Нет файла — обычный портрет
## У каждого персонажа в characters тоже можно указать name и emotion.
##   "hero"       — особый id для speaker и characters: подставляется главный герой, выбранный
##                  игроком (Ведьмочка или Воин, настройки паузы). Его имя и портрет/эмоции берутся
##                  у настоящего персонажа. В тексте и speaker_name {hero} заменяется на имя героя.
##                  В пути "cg" {hero_id} заменяется на id героя (witch / warrior) — своя картинка
##                  на каждого: "cg": "res://.../fufu_hug_{hero_id}.png".
func resolve_lines(dialogue: Dictionary) -> Array:
	var out: Array = []
	var cast := _dialogue_cast(dialogue)
	## Эмоции на сцене: у говорящего — "emotion" реплики, у остальных — последняя их эмоция
	## (своя реплика или поле "emotions": {"rikka": "grumpy", "hero": "smile"}); держится, пока не сменят.
	var faces := {}
	for raw_line in dialogue.get("lines", []):
		if raw_line is String:
			out.append({"speaker_name": "", "text": String(raw_line)})
		elif raw_line is Dictionary:
			var line: Dictionary = raw_line
			var sp := _cast_key(String(line.get("speaker", line.get("speaker_id", ""))))
			if sp != "":
				faces[sp] = String(line.get("emotion", ""))
			if line.get("emotions") is Dictionary:
				for k in line["emotions"]:
					faces[_cast_key(String(k))] = String(line["emotions"][k])
			# Без "characters" на сцене все, кто говорит в этом диалоге (а не только говорящий сейчас).
			if cast.size() > 1 and not line.has("characters"):
				line = line.duplicate(true)
				var chars: Array = []
				for cid in cast:
					chars.append({"id": cid, "emotion": String(faces.get(cid, ""))})
				line["characters"] = chars
			out.append(_resolve_line(line))
	return out

## id персонажа на сцене: главный герой (witch/warrior/hero) -> "hero", остальные как есть.
func _cast_key(sid: String) -> String:
	if sid == "" or sid == "narrator":
		return ""
	return HERO_ALIAS if _hero_id(sid) == get_main_hero_id() else sid

## Кто говорит в диалоге (по порядку появления, главный герой — последним, как в остальных сценах:
## NPC слева, герой справа).
func _dialogue_cast(dialogue: Dictionary) -> Array:
	var cast: Array = []
	var hero_in := false
	for l in dialogue.get("lines", []):
		if not (l is Dictionary):
			continue
		var sid := String(l.get("speaker", l.get("speaker_id", "")))
		if sid == "" or sid == "narrator":
			continue
		if _hero_id(sid) == get_main_hero_id():
			hero_in = true
		elif not cast.has(sid):
			cast.append(sid)
	if hero_in:
		cast.append(HERO_ALIAS)
	return cast

## Id главного героя ("witch"/"warrior"), которым заменяется "hero" в диалогах.
const HERO_ALIAS := "hero"

func get_main_hero_id() -> String:
	if StoryState_ != null and StoryState_.has_method("get_main_hero"):
		return String(StoryState_.get_main_hero())
	return "witch"

func _hero_id(character_id: String) -> String:
	return get_main_hero_id() if character_id == HERO_ALIAS else character_id

func _hero_text(text: String) -> String:
	if text.contains("{hero}"):
		text = text.replace("{hero}", get_character_name(get_main_hero_id()))
	return names_text(text)

## {name:ключ} -> имя, которое придумал игрок (StoryState_.custom_names), например {name:rikka_flower}.
## Пока имени нет — подставляется DEFAULT_CUSTOM_NAMES или пусто.
const DEFAULT_CUSTOM_NAMES := {"rikka_flower": "цветочек"}
func names_text(text: String) -> String:
	if not text.contains("{name:"):
		return text
	var re := RegEx.new()
	re.compile("\\{name:([a-z0-9_]+)\\}")
	for m in re.search_all(text):
		var key := m.get_string(1)
		var v: String = StoryState_.get_custom_name(key, String(DEFAULT_CUSTOM_NAMES.get(key, ""))) if StoryState_ != null else ""
		text = text.replace(m.get_string(0), v)
	return text

func _resolve_line(raw: Dictionary) -> Dictionary:
	var line := raw.duplicate(true)
	var speaker_id := _hero_id(String(line.get("speaker", line.get("speaker_id", ""))))
	if line.has("speaker"):
		line["speaker"] = speaker_id
	if line.has("text"):
		line["text"] = _hero_text(String(line["text"]))
	if line.has("speaker_name"):
		line["speaker_name"] = _hero_text(String(line["speaker_name"]))
	# Картинка под выбранного героя: "cg": ".../fufu_hug_{hero_id}.png" -> fufu_hug_witch / fufu_hug_warrior.
	if line.has("cg") and String(line["cg"]).contains("{hero_id}"):
		line["cg"] = String(line["cg"]).replace("{hero_id}", get_main_hero_id())
	if line.has("choices") and line["choices"] is Array:
		for ch in line["choices"]:
			if ch is Dictionary and ch.has("text"):
				ch["text"] = _hero_text(String(ch["text"]))
	var emotion := String(line.get("emotion", ""))
	if String(line.get("speaker_name", "")) == "":
		line["speaker_name"] = get_character_name(speaker_id)
	if line.has("characters"):
		var resolved_chars: Array = []
		for c in line.get("characters", []):
			if not (c is Dictionary):
				continue
			var rc: Dictionary = c.duplicate(true)
			var cid := _hero_id(String(rc.get("id", "")))
			rc["id"] = cid
			if String(rc.get("name", "")) == "":
				rc["name"] = get_character_name(cid)
			var c_emotion := String(rc.get("emotion", ""))
			if c_emotion == "" and cid == speaker_id:
				c_emotion = emotion
			if c_emotion == "" and line.get("emotions") is Dictionary:
				for k in line["emotions"]:
					if _hero_id(String(k)) == cid:
						c_emotion = String(line["emotions"][k])
			if not (rc.get("portrait") is Texture2D):
				rc["portrait"] = get_character_portrait(cid, c_emotion)
			resolved_chars.append(rc)
		line["characters"] = resolved_chars
	elif speaker_id != "":
		line["characters"] = [{"id": speaker_id, "portrait": get_character_portrait(speaker_id, emotion)}]
	if not line.has("active_character") and speaker_id != "":
		line["active_character"] = speaker_id
	return line

## Имена персонажей в диалогах: data/characters/names.json — {"rikka": "Рикка", ...}.
## Нет в таблице — имя из CharDB, иначе id. Разово другое имя — поле speaker_name в реплике.
const NAMES_FILE := "res://data/characters/names.json"
var _names: Dictionary = {}

func _load_names() -> void:
	_names.clear()
	if not FileAccess.file_exists(NAMES_FILE):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(NAMES_FILE))
	if parsed is Dictionary:
		_names = parsed

func get_character_name(character_id: String) -> String:
	var n := String(_names.get(character_id, ""))
	if n != "":
		return n
	if CharDB != null:
		var cd := CharDB.get_by_id(character_id)
		if cd != null and cd.display_name != "":
			return cd.display_name
	return character_id

## Эмоции: assets/characters/<id>/emotions/<эмоция>.png (у NPC — assets/npc/<папка>/emotions/).
const EMOTIONS_DIR := "res://assets/characters"
const NPC_EMOTIONS_DIR := "res://assets/npc"

func get_character_portrait(character_id: String, emotion: String = "") -> Texture2D:
	if emotion != "" and character_id != "":
		# Файл эмоции: emotions/<id>_<эмоция>.png (fufu_shy.png) или просто emotions/<эмоция>.png.
		# Папка героинь — assets/characters/<id>/, NPC (Рикка, Сессилия, Ноктрис) — assets/npc/<id>/.
		for dir in [EMOTIONS_DIR, NPC_EMOTIONS_DIR]:
			for file in ["%s_%s" % [character_id, emotion], emotion]:
				var path := "%s/%s/emotions/%s.png" % [dir, character_id, file]
				if ResourceLoader.exists(path):
					return load(path) as Texture2D
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
	# "has_any_unit": ["aki", "luisa", "fufu"] — в отряде есть хотя бы одна из них.
	if c.has("has_any_unit"):
		var any_found := false
		for uid in c["has_any_unit"]:
			if UnitRoster_ != null and UnitRoster_.has_unit(String(uid)):
				any_found = true
				break
		if not any_found:
			return false
	# "trust": {"fufu": 3} — уровень доверия (отношений) героини не ниже 3 (как в галерее).
	if c.has("trust") and c["trust"] is Dictionary:
		for key in c["trust"].keys():
			if UnitRoster_ == null or UnitRoster_.get_relationship(String(key)) < int(c["trust"][key]):
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
	# "seen_dialogue": "noctris_first_meeting" — диалог уже был (например, встреча с НПС); можно списком.
	if c.has("seen_dialogue") and StoryState_ != null:
		for did in (c["seen_dialogue"] if c["seen_dialogue"] is Array else [c["seen_dialogue"]]):
			if not StoryState_.has_seen_dialogue(String(did)):
				return false
	if c.has("not_seen_dialogue") and StoryState_ != null:
		for did in (c["not_seen_dialogue"] if c["not_seen_dialogue"] is Array else [c["not_seen_dialogue"]]):
			if StoryState_.has_seen_dialogue(String(did)):
				return false
	if c.has("main_hero") and get_main_hero_id() != String(c["main_hero"]):
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
