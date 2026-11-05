extends CanvasLayer
class_name DebugStoryPanel

var _panel: PanelContainer
var _status_label: Label

func _ready() -> void:
	layer = 128
	_build_ui()
	_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_toggle()
		get_viewport().set_input_as_handled()

func _toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh_status()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "StoryDebugPanel"
	_panel.offset_left = 32
	_panel.offset_top = 32
	_panel.offset_right = 600
	_panel.offset_bottom = 860
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "Story Debug / F9"
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(520, 150)
	box.add_child(_status_label)

	_add_button(box, "Reload JSON dialogues", _reload_dialogues)
	_add_button(box, "Force dungeon Lamia shop", _force_lamia_shop_room)
	_add_button(box, "Force chest room", _force_chest_room)
	_add_button(box, "Force ??? warrior quest room", _force_warrior_quest_room)
	_add_button(box, "Start quest: lamia_headphones", _start_lamia_headphones)
	_add_button(box, "Give item: warm_headphones", _give_headphones)
	_add_button(box, "Complete quest: lamia_headphones", _complete_lamia_headphones)
	_add_button(box, "Reset lamia headphones quest", _reset_lamia_headphones)
	_add_button(box, "+1 lamia_visits", _add_lamia_visit)
	_add_button(box, "Start quest: find_warrior", _start_find_warrior)
	_add_button(box, "Reset quest: find_warrior", _reset_find_warrior)
	_add_button(box, "Set party level to 3", _set_party_level_3)
	_add_button(box, "Refresh status", _refresh_status)
	_add_button(box, "Close", _toggle)

func _add_button(parent: Node, text: String, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(520, 38)
	b.pressed.connect(callback)
	parent.add_child(b)

func _refresh_status() -> void:
	var lamia_status := ""
	var warrior_status := ""
	var visits := 0
	var has_item := false
	var flags_text := ""
	var level := 0
	if StoryState_ != null:
		lamia_status = StoryState_.get_quest_status("lamia_headphones")
		warrior_status = StoryState_.get_quest_status("find_warrior")
		visits = StoryState_.get_counter("lamia_visits")
		flags_text = str(StoryState_.flags)
	if Inventory_ != null:
		has_item = Inventory_.has_item("warm_headphones")
	if DungRun != null:
		level = DungRun.party_level
	_status_label.text = "party_level: %d\nlamia_headphones: %s\nlamia_visits: %d\nwarm_headphones: %s\nfind_warrior: %s\nflags: %s" % [
		level,
		lamia_status if lamia_status != "" else "not_started",
		visits,
		str(has_item),
		warrior_status if warrior_status != "" else "not_started",
		flags_text,
	]

func _reload_dialogues() -> void:
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.reload()
	_refresh_status()

func _start_lamia_headphones() -> void:
	if StoryState_ != null:
		StoryState_.start_quest("lamia_headphones")
	_refresh_status()

func _give_headphones() -> void:
	if Inventory_ != null and not Inventory_.has_item("warm_headphones"):
		Inventory_.add_item("warm_headphones", 1)
	_refresh_status()

func _complete_lamia_headphones() -> void:
	if StoryState_ != null:
		StoryState_.complete_quest("lamia_headphones")
	if Inventory_ != null and Inventory_.has_item("warm_headphones"):
		Inventory_.remove_item("warm_headphones", 1)
	_refresh_status()

func _reset_lamia_headphones() -> void:
	if StoryState_ != null:
		StoryState_.quests.erase("lamia_headphones")
		StoryState_.seen_dialogues.erase("lamia_headphones_start")
		StoryState_.seen_dialogues.erase("lamia_headphones_finish")
		StoryState_.set_flag("lamia_asked_for_headphones", false)
	if Inventory_ != null and Inventory_.has_item("warm_headphones"):
		Inventory_.remove_item("warm_headphones", 1)
	_refresh_status()

func _add_lamia_visit() -> void:
	if StoryState_ != null:
		StoryState_.add_counter("lamia_visits", 1)
	_refresh_status()

func _start_find_warrior() -> void:
	if StoryState_ != null:
		StoryState_.start_quest("find_warrior")
		StoryState_.set_flag("heard_about_lost_warrior", true)
	_refresh_status()

func _reset_find_warrior() -> void:
	if StoryState_ != null:
		StoryState_.quests.erase("find_warrior")
		StoryState_.seen_dialogues.erase("rabbit_shop_warrior_hint")
		StoryState_.set_flag("heard_about_lost_warrior", false)
		StoryState_.set_flag("find_warrior_room_done", false)
		StoryState_.seen_dialogues.erase("find_warrior_room_intro")
		StoryState_.seen_dialogues.erase("find_warrior_after_battle")
	_refresh_status()

func _set_party_level_3() -> void:
	if DungRun != null:
		DungRun.party_level = max(DungRun.party_level, 3)
		DungRun.emit_changed()
	_refresh_status()

func _force_lamia_shop_room() -> void:
	var room := _ensure_current_room()
	room.room_type = RoomParams.RoomType.EVENT
	room.event_type = RoomParams.EventType.SHOP
	room.event_npc_id = "lamia"
	room.used = false
	room.shop_refreshed = true
	room.shop_item_ids = RunItems.random_item_ids(DungRun.rng, DungRun.EVENT_SHOP_SLOT_COUNT, DungRun.get_owned_unique_artifacts())
	push_warning("DebugStoryPanel: комнаты старого забега удалены, переход пропущен")

func _force_chest_room() -> void:
	var room := _ensure_current_room()
	room.room_type = RoomParams.RoomType.EVENT
	room.event_type = RoomParams.EventType.CHEST
	room.event_npc_id = ""
	room.used = false
	room.quest_id = ""
	push_warning("DebugStoryPanel: комнаты старого забега удалены, переход пропущен")

func _force_warrior_quest_room() -> void:
	if StoryState_ != null:
		StoryState_.start_quest("find_warrior")
	var room := _ensure_current_room()
	room.room_type = RoomParams.RoomType.EVENT
	room.event_type = RoomParams.EventType.QUEST
	room.event_npc_id = ""
	room.quest_id = "find_warrior"
	room.used = false
	push_warning("DebugStoryPanel: комнаты старого забега удалены, переход пропущен")

func _ensure_current_room() -> RoomParams:
	var room := DungRun.get_current_room() if DungRun != null else null
	if room != null:
		return room
	room = RoomParams.new()
	room.index = 0
	if DungRun != null:
		DungRun.rooms.clear()
		DungRun.rooms.append(room)
		DungRun.room_index = 0
	return room
