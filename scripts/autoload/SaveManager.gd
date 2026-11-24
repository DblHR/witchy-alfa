extends Node
class_name SaveManager

## Три слота сохранения: user://save_slot1.json … save_slot3.json (+ .bak / .tmp рядом).
## Игра пишет в текущий слот (current_slot) — его выбирают в главном меню (новая игра / загрузка).
const SLOT_COUNT := 3
const SLOT_PATH := "user://save_slot%d.json"
const SLOT_BACKUP_PATH := "user://save_slot%d.bak.json"
const SLOT_TMP_PATH := "user://save_slot%d.tmp.json"
## Старое одиночное сохранение — переезжает в слот 1 при первом запуске.
const LEGACY_SAVE_PATH := "user://savegame.json"
const LEGACY_BACKUP_PATH := "user://savegame.bak.json"
const SAVE_VERSION := 3
## Сохранения версии 1: персонажи-NPC по старым кодовым id -> по именам (step65).
const LEGACY_IDS := [["rabbit_shop", "rikka"], ["nurse", "noctris"], ["lamia", "sessilia"]]

var _is_loading := false
var _autosave_enabled := false
var _save_queued := false
## В какой слот сейчас пишем (1..SLOT_COUNT).
var current_slot := 1
## Сколько секунд наиграно на этом сохранении. Идёт, пока открыта игра (не главное меню)
## и окно игры активно; сохраняется вместе со всем остальным, раз в PLAY_TIME_SAVE_EVERY
## секунд и при закрытии игры.
var play_time := 0.0
const PLAY_TIME_SAVE_EVERY := 60.0
var _play_unsaved := 0.0
var _window_focused := true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   ## пауза (меню на Esc) — тоже время в игре
	_migrate_legacy_save()
	_connect_signals()

func _process(delta: float) -> void:
	if not _counting_play_time():
		return
	play_time += delta
	_play_unsaved += delta
	if _play_unsaved >= PLAY_TIME_SAVE_EVERY:
		save_game()

func _counting_play_time() -> bool:
	if not _autosave_enabled or _is_loading or not _window_focused:
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path != SceneRouter.MAIN_MENU

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_window_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_window_focused = true
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _autosave_enabled and not _is_loading:
				save_game()

## «2 ч 05 мин» / «15 мин» — для меню сохранений.
static func format_play_time(seconds: float) -> String:
	var minutes := floori(seconds / 60.0)
	if minutes < 60:
		return "%d мин" % minutes
	return "%d ч %02d мин" % [floori(minutes / 60.0), minutes % 60]

static func slot_path(slot: int) -> String:
	return SLOT_PATH % slot

static func _backup_path(slot: int) -> String:
	return SLOT_BACKUP_PATH % slot

static func _tmp_path(slot: int) -> String:
	return SLOT_TMP_PATH % slot

## Одиночное сохранение из прошлых версий -> слот 1 (если слот 1 пуст).
func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH) or FileAccess.file_exists(slot_path(1)):
		return
	DirAccess.rename_absolute(LEGACY_SAVE_PATH, slot_path(1))
	if FileAccess.file_exists(LEGACY_BACKUP_PATH):
		DirAccess.rename_absolute(LEGACY_BACKUP_PATH, _backup_path(1))

func _connect_signals() -> void:
	if DungRun != null and not DungRun.changed.is_connected(_on_state_changed):
		DungRun.changed.connect(_on_state_changed)
	if FarmState_ != null and not FarmState_.state_changed.is_connected(_on_state_changed):
		FarmState_.state_changed.connect(_on_state_changed)
	if Inventory_ != null and not Inventory_.changed.is_connected(_on_state_changed):
		Inventory_.changed.connect(_on_state_changed)
	if UnitRoster_ != null and not UnitRoster_.changed.is_connected(_on_state_changed):
		UnitRoster_.changed.connect(_on_state_changed)
	if StoryState_ != null and not StoryState_.changed.is_connected(_on_state_changed):
		StoryState_.changed.connect(_on_state_changed)

## Автосохранение «склеивается»: десять изменений за один кадр = одна запись на диск.
func _on_state_changed() -> void:
	if _is_loading or not _autosave_enabled or _save_queued:
		return
	_save_queued = true
	_flush_autosave.call_deferred()

func _flush_autosave() -> void:
	_save_queued = false
	if _is_loading or not _autosave_enabled:
		return
	save_game()

func save_game() -> bool:
	var slot := clampi(current_slot, 1, SLOT_COUNT)
	var save_path := slot_path(slot)
	var tmp_path := _tmp_path(slot)
	var data := {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"play_time": int(play_time),
		"dungeon_run": DungRun.serialize_state() if DungRun != null else {},
		"farm": FarmState_.serialize_state() if FarmState_ != null else {},
		"inventory": Inventory_.serialize_state() if Inventory_ != null else {},
		"unit_roster": UnitRoster_.serialize_state() if UnitRoster_ != null else {},
		"story": StoryState_.serialize_state() if StoryState_ != null else {},
	}

	# Пишем во временный файл и только потом подменяем сохранение:
	# вылет игры посреди записи больше не оставляет битый savegame.json.
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing: %s" % tmp_path)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	_play_unsaved = 0.0

	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, _backup_path(slot))
	var err := DirAccess.rename_absolute(tmp_path, save_path)
	if err != OK:
		push_error("SaveManager: failed to replace save file (error %d)" % err)
		return false
	return true

## Читает и разбирает файл сохранения. Пустой словарь — файла нет или он битый.
func _read_save_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	if text.strip_edges().is_empty():
		return {}
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary and int(parsed.get("version", 1)) < 2:
		# Старые id (флаги, просмотренные диалоги, квесты, карта noctris_heal, комнаты) -> новые.
		for pair in LEGACY_IDS:
			text = text.replace(pair[0], pair[1])
		parsed = JSON.parse_string(text)
	if parsed is Dictionary and int(parsed.get("version", 1)) < 3:
		_migrate_v3(parsed)
	if parsed is Dictionary:
		return parsed
	return {}

## v3: в новой игре нет котла и 2 горшка. Старым сохранениям — котёл (уровни сдвинулись на 1:
## 0 — нет котла) и те же горшки, что были (раньше давали 4 сразу).
func _migrate_v3(data: Dictionary) -> void:
	var story = data.get("story", {})
	if not story is Dictionary:
		return
	var counters = story.get("counters", {})
	if not counters is Dictionary:
		counters = {}
	counters[AlchemyDB.CAULDRON_LEVEL_COUNTER] = int(counters.get(AlchemyDB.CAULDRON_LEVEL_COUNTER, 0)) + 1
	counters[FarmState.POTS_BOUGHT_COUNTER] = int(counters.get(FarmState.POTS_BOUGHT_COUNTER, 0)) + 2
	story["counters"] = counters

func load_game(slot: int = -1) -> bool:
	if slot > 0:
		current_slot = clampi(slot, 1, SLOT_COUNT)
	var data := _read_save_file(slot_path(current_slot))
	if data.is_empty():
		data = _read_save_file(_backup_path(current_slot))
		if data.is_empty():
			if FileAccess.file_exists(slot_path(current_slot)):
				push_error("SaveManager: save file is invalid and no backup is usable")
			return false
		push_warning("SaveManager: main save is broken, restored from backup")
	if int(data.get("version", 1)) > SAVE_VERSION:
		push_warning("SaveManager: save was made by a newer game version")

	_is_loading = true
	play_time = float(data.get("play_time", 0))
	if Inventory_ != null:
		Inventory_.apply_state(data.get("inventory", {}))
	if FarmState_ != null:
		FarmState_.apply_state(data.get("farm", {}))
	if UnitRoster_ != null:
		UnitRoster_.apply_state(data.get("unit_roster", {}))
	if StoryState_ != null:
		StoryState_.apply_state(data.get("story", {}))
	if DungRun != null:
		DungRun.apply_state(data.get("dungeon_run", {}))
		DungRun.sync_legacy_owned_artifacts_to_inventory()
		DungRun.refresh_selected_potion_charges()
	_is_loading = false
	_autosave_enabled = true
	return true


## Есть ли сохранение в слоте (slot = -1 — хоть в одном).
func has_save(slot: int = -1) -> bool:
	if slot < 1:
		for i in range(1, SLOT_COUNT + 1):
			if has_save(i):
				return true
		return false
	return not _read_save_file(slot_path(slot)).is_empty() or not _read_save_file(_backup_path(slot)).is_empty()

## Коротко о слоте для меню: {exists, party_level, gold, units, saved_at (unix, 0 — неизвестно)}.
func slot_info(slot: int) -> Dictionary:
	var data := _read_save_file(slot_path(slot))
	if data.is_empty():
		data = _read_save_file(_backup_path(slot))
	if data.is_empty():
		return {"exists": false}
	var run: Dictionary = data.get("dungeon_run", {}) if data.get("dungeon_run") is Dictionary else {}
	var roster = data.get("unit_roster", {})
	var units := 0
	if roster is Dictionary:
		for k in ["unlocked_unit_ids"]:
			if roster.get(k) is Array:
				units = (roster[k] as Array).size()
				break
	var saved_at := int(data.get("saved_at", 0))
	if saved_at <= 0:
		saved_at = int(FileAccess.get_modified_time(slot_path(slot)))
	return {"exists": true, "party_level": int(run.get("party_level", 1)), "gold": int(run.get("gold", 0)),
		"units": units, "saved_at": saved_at, "play_time": int(data.get("play_time", -1))}   ## -1 — сохранение старше счётчика

func delete_save(slot: int = -1) -> void:
	var s := current_slot if slot < 1 else slot
	for path in [slot_path(s), _backup_path(s), _tmp_path(s)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func reset_all_state() -> void:
	if DungRun != null:
		DungRun.reset_to_defaults()

	if FarmState_ != null:
		FarmState_.reset_to_defaults()

	if Inventory_ != null:
		Inventory_.clear()
	if UnitRoster_ != null:
		UnitRoster_.reset_to_defaults()
	if StoryState_ != null:
		StoryState_.reset_to_defaults()

func start_new_game(slot: int = -1) -> void:
	if slot > 0:
		current_slot = clampi(slot, 1, SLOT_COUNT)
	_is_loading = true
	_autosave_enabled = false
	delete_save(current_slot)
	reset_all_state()
	play_time = 0.0
	_is_loading = false
	_autosave_enabled = true
	save_game()

func continue_game(slot: int = -1) -> bool:
	return load_game(slot)
