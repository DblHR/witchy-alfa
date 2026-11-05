extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"
const SAVE_BACKUP_PATH := "user://savegame.bak.json"
const SAVE_TMP_PATH := "user://savegame.tmp.json"
const SAVE_VERSION := 1

var _is_loading := false
var _autosave_enabled := false
var _save_queued := false

func _ready() -> void:
	_connect_signals()

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
	var data := {
		"version": SAVE_VERSION,
		"dungeon_run": DungRun.serialize_state() if DungRun != null else {},
		"farm": FarmState_.serialize_state() if FarmState_ != null else {},
		"inventory": Inventory_.serialize_state() if Inventory_ != null else {},
		"unit_roster": UnitRoster_.serialize_state() if UnitRoster_ != null else {},
		"story": StoryState_.serialize_state() if StoryState_ != null else {},
	}

	# Пишем во временный файл и только потом подменяем сохранение:
	# вылет игры посреди записи больше не оставляет битый savegame.json.
	var file := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open save file for writing: %s" % SAVE_TMP_PATH)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_BACKUP_PATH)
	var err := DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
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
	if parsed is Dictionary:
		return parsed
	return {}

func load_game() -> bool:
	var data := _read_save_file(SAVE_PATH)
	if data.is_empty():
		data = _read_save_file(SAVE_BACKUP_PATH)
		if data.is_empty():
			if FileAccess.file_exists(SAVE_PATH):
				push_error("SaveManager: save file is invalid and no backup is usable")
			return false
		push_warning("SaveManager: main save is broken, restored from backup")
	if int(data.get("version", 1)) > SAVE_VERSION:
		push_warning("SaveManager: save was made by a newer game version")

	_is_loading = true
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


func has_save() -> bool:
	return not _read_save_file(SAVE_PATH).is_empty() or not _read_save_file(SAVE_BACKUP_PATH).is_empty()


func delete_save() -> void:
	for path in [SAVE_PATH, SAVE_BACKUP_PATH, SAVE_TMP_PATH]:
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

func start_new_game() -> void:
	_is_loading = true
	_autosave_enabled = false
	delete_save()
	reset_all_state()
	_is_loading = false
	_autosave_enabled = true
	save_game()

func continue_game() -> bool:
	return load_game()
