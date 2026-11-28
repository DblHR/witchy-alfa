extends Control

const FRAME_GOLD := Color(0.96, 0.83, 0.22, 1.0)
const FRAME_SILVER := Color(0.88, 0.80, 0.88, 0.92)
const FRAME_EMPTY := Color(0.56, 0.44, 0.60, 0.72)
const TEAM_SLOT_SCENE := preload("res://ui/TeamSlot.tscn")
## Отряд — чибики на площадке (TeamSlot в режиме chibi). Ширина слота = шаг между ними.
const SLOT_SIZE := Vector2(260, 450)
const SLOT_GAP := 0.0
## Площадка под отрядом: центр, полуоси эллипса; кружки-места под каждым слотом.
const STAGE_CENTER := Vector2(960, 532)
const STAGE_RADII := Vector2(470, 62)
const SPOT_RADII := Vector2(92, 20)
const ROSTER_CARD_SIZE := Vector2(203, 276)

@onready var team_slot0: TeamSlot = %TeamSlot0
@onready var team_slot1: TeamSlot = %TeamSlot1
@onready var team_slot2: TeamSlot = %TeamSlot2
@onready var team_slot3: TeamSlot = %TeamSlot3
@onready var team_row: Control = %TeamRow
@onready var party_level: SpinBox = %PartyLevel
@onready var picker: CharacterPickerPopup = %CharacterPickerPopup
@onready var meta_info: Label = %MetaInfo
@onready var hub: BaseButton = %HomeButton
@onready var start_button: BaseButton = %StartButton
@onready var card_battle_toggle: CheckButton = %CardBattleToggle
@onready var roster_panel: Panel = %RosterPanel
@onready var roster_row: HBoxContainer = %RosterRow
@onready var loadout_panel: Panel = %LoadoutPanel
@onready var food_button: Button = %FoodButton
@onready var artifact_button: Button = %ArtifactButton
@onready var potion_button: Button = %PotionButton
## Второй слот зелья: создаётся в коде рядом с первым (два слота на забег).
var potion_button2: Button
var _potion_slot := 0
## Приманка: взять/не брать в забег (одна на забег).
var lure_button: Button
@onready var admin_panel: Panel = %AdminPanel
@onready var gold_label: Label = %GoldLabel
@onready var stage: Control = %Stage
@onready var admin_toggle_button: Button = %AdminToggleButton
@onready var admin_content: Control = %AdminContent
@onready var add_unit_in_roaster: OptionButton = %AddUnitInRoaster
@onready var delete_unit_in_roaster: OptionButton = %DeleteUnitInRoaster
@onready var roster_apply_button: Button = %ApplyButton

var _team_slots: Array[TeamSlot] = []
var _slot_base_positions: Array[Vector2] = []
var _slot_tweens: Dictionary = {}

var _drag_slot: TeamSlot = null
var _drag_source_index: int = -1
var _drag_hover_insert_pos: int = -1
var _drag_pointer_offset := Vector2.ZERO
var _drag_preview_order: Array[int] = []

var _roster_drag_id: String = ""
var _roster_drag_pointer_offset := Vector2.ZERO
var _drag_preview: TeamSlot = null

var _roster_cards: Array[TeamSlot] = []

var _item_popup: PopupPanel = null
var _item_popup_title: Label = null
var _item_popup_grid: GridContainer = null
## Описание предмета под сеткой выбора: при наведении — эффект наведённого, иначе — выбранного.
var _item_popup_info: RichTextLabel = null
var _popup_kind: String = ""

var _admin_open := false
var _empty_hint: Label = null
## Клик по героине (в отряде или в списке) — выбор её карт; кнопка «Колода» — вся стартовая колода.
var _deck_menu: PartyDeckMenu
var _deck_button: Button
## Кнопка «Колода» — под кнопкой «В бой».
const DECK_BUTTON_RECT := Rect2(1462, 420, 246, 96)

## Размер отряда и тестовый переключатель «ядра команды».
## CORE_LOCK=true возвращает старую привязку: ведьма/воин — золотой лидер, его нельзя убрать.
const PARTY_SIZE := 3
const CORE_LOCK := false

func _ready() -> void:
	UIThemeHelper.apply_pink_theme(self)
	_team_slots = [team_slot0, team_slot1, team_slot2]
	if team_slot3 != null:
		team_slot3.visible = false
		team_slot3.can_drag = false
		team_slot3.can_pick = false
	DungRun.party_slot_count = PARTY_SIZE
	for i in range(_team_slots.size()):
		var slot := _team_slots[i]
		slot.ui_index = i
		slot.set_chibi_mode(true)
		slot.can_drag = true
		slot.can_pick = true
		if not slot.pressed.is_connected(_on_slot_pressed):
			slot.pressed.connect(_on_slot_pressed)
		if not slot.drag_started.is_connected(_on_slot_drag_started):
			slot.drag_started.connect(_on_slot_drag_started)
		if not slot.drag_moved.is_connected(_on_slot_drag_moved):
			slot.drag_moved.connect(_on_slot_drag_moved)
		if not slot.drag_released.is_connected(_on_slot_drag_released):
			slot.drag_released.connect(_on_slot_drag_released)

	var go_hub := func() -> void:
		SceneRouter_.go_to_hub()
	if not hub.pressed.is_connected(go_hub):
		hub.pressed.connect(go_hub)
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if card_battle_toggle != null:
		card_battle_toggle.visible = false  # старого боя больше нет, переключать нечего

	_ensure_party_ids_shape()
	_ensure_default_party()
	_ensure_default_leader()
	party_level.value = DungRun.party_level

	_setup_visual_shell()
	_setup_scene_widgets()
	_build_item_popup()
	_build_deck_ui()

	await get_tree().process_frame
	_capture_slot_positions()
	_reset_slot_layout_instant()
	_refresh_team_ui()
	_refresh_loadout_ui()
	_refresh_roster_strip()
	_refresh_admin_panel()
	_refresh_gold()

	if DungRun != null and not DungRun.changed.is_connected(_on_external_state_changed):
		DungRun.changed.connect(_on_external_state_changed)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh_loadout_ui):
		Inventory_.changed.connect(_refresh_loadout_ui)
	if UnitRoster_ != null and not UnitRoster_.changed.is_connected(_on_roster_changed):
		UnitRoster_.changed.connect(_on_roster_changed)

func _exit_tree() -> void:
	if DungRun != null and DungRun.changed.is_connected(_on_external_state_changed):
		DungRun.changed.disconnect(_on_external_state_changed)
	if Inventory_ != null and Inventory_.changed.is_connected(_refresh_loadout_ui):
		Inventory_.changed.disconnect(_refresh_loadout_ui)
	if UnitRoster_ != null and UnitRoster_.changed.is_connected(_on_roster_changed):
		UnitRoster_.changed.disconnect(_on_roster_changed)

func _setup_visual_shell() -> void:
	if party_level != null:
		party_level.visible = false
	if picker != null:
		picker.visible = false
	if meta_info != null:
		meta_info.visible = false

	var viewport_size := get_viewport_rect().size
	var total_team_width := SLOT_SIZE.x * _team_slots.size() + SLOT_GAP * float(_team_slots.size() - 1)
	var team_x = floor((viewport_size.x - total_team_width) * 0.5)
	var team_y := STAGE_CENTER.y + 28.0 - SLOT_SIZE.y   ## ноги чибиков — на площадке
	team_row.position = Vector2(team_x, team_y)
	team_row.size = Vector2(total_team_width, SLOT_SIZE.y)

	for i in range(_team_slots.size()):
		var slot := _team_slots[i]
		slot.size = SLOT_SIZE
		slot.position = Vector2(i * (SLOT_SIZE.x + SLOT_GAP), 0)
		slot.custom_minimum_size = SLOT_SIZE

	for b in [hub, start_button]:
		_add_hover_bounce(b)
	if stage != null:
		stage.draw.connect(_draw_stage)
		stage.queue_redraw()

	_style_panel(loadout_panel, Color(0.34, 0.21, 0.36, 0.36), 26, Color(1, 1, 1, 0.08), 2)
	_style_panel(roster_panel, Color(0.56, 0.33, 0.60, 0.20), 18, Color(1, 1, 1, 0.08), 2)
	_style_panel(admin_panel, Color(0.20, 0.11, 0.22, 0.88), 22, Color(1, 1, 1, 0.10), 2)

## Кнопка чуть увеличивается при наведении.
func _add_hover_bounce(b: Control) -> void:
	if b == null:
		return
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pivot_offset = b.size * 0.5
	b.mouse_entered.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2(1.07, 1.07), 0.1))
	b.mouse_exited.connect(func() -> void:
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))

## Площадка под отрядом: большой эллипс и кружки под каждым местом.
func _draw_stage() -> void:
	var o := STAGE_CENTER - stage.position
	_draw_ellipse(stage, o, STAGE_RADII, Color(1, 1, 1, 0.10), Color(1, 1, 1, 0.30))
	for i in range(_team_slots.size()):
		var cx := team_row.position.x + (i + 0.5) * (SLOT_SIZE.x + SLOT_GAP) - stage.position.x
		_draw_ellipse(stage, Vector2(cx, o.y + 6), SPOT_RADII, Color(1, 1, 1, 0.14), Color(1, 0.9, 1, 0.45))

static func _draw_ellipse(ci: CanvasItem, c: Vector2, r: Vector2, fill: Color, line: Color) -> void:
	var pts := PackedVector2Array()
	for k in range(49):
		var a := TAU * float(k) / 48.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	ci.draw_colored_polygon(pts.slice(0, 48), fill)
	ci.draw_polyline(pts, line, 2.0, true)

## Два слота зелий в одну строку вместо одной кнопки.
func _build_potion_slots() -> void:
	var box := potion_button.get_parent()
	var idx := potion_button.get_index()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	box.move_child(row, idx)
	potion_button.reparent(row)
	potion_button2 = Button.new()
	row.add_child(potion_button2)
	for b in [potion_button, potion_button2]:
		b.custom_minimum_size = Vector2(63, 96)
		b.expand_icon = true
	lure_button = Button.new()
	lure_button.custom_minimum_size = Vector2(132, 96)
	lure_button.expand_icon = true
	lure_button.toggle_mode = true
	box.add_child(lure_button)
	# Раскладка слева: посох + еда, два зелья (круглые), приманка.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(top)
	box.move_child(top, 0)
	artifact_button.reparent(top)
	food_button.reparent(top)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	(box as BoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	for b in [artifact_button, food_button, lure_button]:
		b.custom_minimum_size = Vector2(118, 118)
	for b in [potion_button, potion_button2]:
		b.custom_minimum_size = Vector2(112, 112)
	lure_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lure_button.toggled.connect(func(on: bool) -> void:
		DungRun.take_lure = on
		_refresh_loadout_ui()
	)

func _setup_scene_widgets() -> void:
	_build_potion_slots()
	for button in [food_button, artifact_button, potion_button, potion_button2, lure_button]:
		_style_loadout_button(button)
	for button in [potion_button, potion_button2]:   ## зелья — круглые
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb := (button.get_theme_stylebox(st) as StyleBoxFlat)
			if sb != null:
				sb = sb.duplicate()
				sb.set_corner_radius_all(56)
				button.add_theme_stylebox_override(st, sb)
	food_button.pressed.connect(func() -> void:
		_open_item_popup("food")
	)
	artifact_button.pressed.connect(func() -> void:
		_open_item_popup("artifact")
	)
	potion_button.pressed.connect(func() -> void:
		_potion_slot = 0
		_open_item_popup("potion")
	)
	potion_button2.pressed.connect(func() -> void:
		_potion_slot = 1
		_open_item_popup("potion")
	)

	_style_primary_button(admin_toggle_button, Color(0.25, 0.14, 0.28, 0.95), Color(0.16, 0.08, 0.18, 1.0), 18)
	admin_toggle_button.add_theme_font_size_override("font_size", 24)
	if not admin_toggle_button.pressed.is_connected(_toggle_admin_panel):
		admin_toggle_button.pressed.connect(_toggle_admin_panel)
	if add_unit_in_roaster != null and not add_unit_in_roaster.item_selected.is_connected(_on_admin_option_changed):
		add_unit_in_roaster.item_selected.connect(_on_admin_option_changed)
	if delete_unit_in_roaster != null and not delete_unit_in_roaster.item_selected.is_connected(_on_admin_option_changed):
		delete_unit_in_roaster.item_selected.connect(_on_admin_option_changed)
	if not roster_apply_button.pressed.is_connected(_on_admin_apply_pressed):
		roster_apply_button.pressed.connect(_on_admin_apply_pressed)
	_style_primary_button(roster_apply_button, Color(0.56, 0.88, 0.16, 0.98), Color(0.15, 0.28, 0.08, 1.0), 18)
	roster_apply_button.add_theme_font_size_override("font_size", 20)
	_sync_admin_panel_visuals(true)
	_update_admin_apply_button_state()

func _prepare_transparent_click_button(button: BaseButton) -> void:
	if button == null:
		return
	button.modulate = Color(1, 1, 1, 0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if button is TextureButton:
		button.ignore_texture_size = true

func _style_primary_button(button: Button, bg: Color, border: Color, radius: int) -> void:
	if button == null:
		return
	button.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_top = 4
	sb.border_width_bottom = 4
	sb.border_color = border
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", sb)

func _style_panel(panel: Panel, bg: Color, radius: int, border: Color, border_width: int) -> void:
	if panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.border_color = border
	panel.add_theme_stylebox_override("panel", sb)

func _style_loadout_button(button: Button) -> void:
	if button == null:
		return
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.expand_icon = true
	button.flat = false
	button.text = ""
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.42, 0.25, 0.44, 0.88)
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(0.22, 0.10, 0.25, 1.0)
	button.add_theme_stylebox_override("normal", sb)
	button.add_theme_stylebox_override("hover", sb)
	button.add_theme_stylebox_override("pressed", sb)


func _build_item_popup() -> void:
	if _item_popup != null:
		return

	_item_popup = PopupPanel.new()
	_item_popup.name = "LoadoutPopup"
	_item_popup.visible = false
	_item_popup.size = Vector2i(420, 350)
	_item_popup.exclusive = true
	add_child(_item_popup)

	var popup_panel_style := StyleBoxFlat.new()
	popup_panel_style.bg_color = Color(0.18, 0.10, 0.20, 0.97)
	popup_panel_style.corner_radius_top_left = 24
	popup_panel_style.corner_radius_top_right = 24
	popup_panel_style.corner_radius_bottom_left = 24
	popup_panel_style.corner_radius_bottom_right = 24
	popup_panel_style.border_width_left = 3
	popup_panel_style.border_width_right = 3
	popup_panel_style.border_width_top = 3
	popup_panel_style.border_width_bottom = 3
	popup_panel_style.border_color = Color(0.56, 0.44, 0.60, 1.0)   ## как у меню колоды
	popup_panel_style.border_width_left = 4
	popup_panel_style.border_width_right = 4
	popup_panel_style.border_width_top = 4
	popup_panel_style.border_width_bottom = 4
	_item_popup.add_theme_stylebox_override("panel", popup_panel_style)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 18
	root.offset_top = 18
	root.offset_right = -18
	root.offset_bottom = -18
	_item_popup.add_child(root)

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 14)
	root.add_child(outer)

	_item_popup_title = Label.new()
	_item_popup_title.text = "Выбор"
	_item_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_popup_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_item_popup_title.custom_minimum_size = Vector2(0, 48)
	_item_popup_title.add_theme_font_size_override("font_size", 36)
	_item_popup_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.94))
	outer.add_child(_item_popup_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)

	_item_popup_grid = GridContainer.new()
	_item_popup_grid.columns = 5
	_item_popup_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_popup_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_popup_grid.add_theme_constant_override("h_separation", 12)
	_item_popup_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_item_popup_grid)

	_item_popup_info = RichTextLabel.new()
	_item_popup_info.bbcode_enabled = true
	_item_popup_info.fit_content = true
	_item_popup_info.scroll_active = false
	_item_popup_info.custom_minimum_size = Vector2(0, 130)
	_item_popup_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_item_popup_info.add_theme_font_size_override("normal_font_size", 22)
	_item_popup_info.add_theme_font_size_override("bold_font_size", 26)
	var info_sb := StyleBoxFlat.new()
	info_sb.bg_color = Color(0.10, 0.05, 0.12, 0.85)
	info_sb.set_corner_radius_all(14)
	info_sb.set_content_margin_all(12)
	_item_popup_info.add_theme_stylebox_override("normal", info_sb)
	outer.add_child(_item_popup_info)

	var close_button := Button.new()
	close_button.text = "Закрыть"
	close_button.custom_minimum_size = Vector2(320, 56)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_primary_button(
		close_button,
		Color(0.42, 0.22, 0.46, 0.98),
		Color(0.18, 0.08, 0.20, 1.0),
		18
	)
	close_button.add_theme_font_size_override("font_size", 26)
	close_button.pressed.connect(func() -> void:
		if _item_popup != null:
			_item_popup.hide()
	)
	outer.add_child(close_button)


func _capture_slot_positions() -> void:

	_slot_base_positions.clear()
	for slot in _team_slots:
		_slot_base_positions.append(slot.position)
		slot.pivot_offset = slot.size * 0.5

func _kill_slot_tween(slot: TeamSlot) -> void:
	if slot == null:
		return
	if _slot_tweens.has(slot):
		var tween: Tween = _slot_tweens[slot]
		if tween != null and is_instance_valid(tween):
			tween.kill()
		_slot_tweens.erase(slot)

func _reset_slot_layout_instant() -> void:
	for i in range(_team_slots.size()):
		var slot := _team_slots[i]
		_kill_slot_tween(slot)
		slot.position = _slot_base_positions[i]
		slot.scale = Vector2.ONE
		slot.modulate = Color.WHITE
		slot.z_index = i

func _animate_slot_to(slot: TeamSlot, target_pos: Vector2, target_scale: Vector2 = Vector2.ONE, z_index_value: int = -1, duration: float = 0.14) -> void:
	_kill_slot_tween(slot)
	if z_index_value >= 0:
		slot.z_index = z_index_value
	var tween := create_tween()
	_slot_tweens[slot] = tween
	tween.finished.connect(func() -> void:
		if _slot_tweens.get(slot) == tween:
			_slot_tweens.erase(slot)
	)
	tween.set_parallel(true)
	tween.tween_property(slot, "position", target_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(slot, "modulate", Color.WHITE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _ensure_default_leader() -> void:
	if DungRun.leader_id == "" or not DungRun.party_ids.has(DungRun.leader_id):
		for id in DungRun.party_ids:
			if id != "":
				DungRun.leader_id = id
				return
		DungRun.leader_id = ""

func _ensure_party_ids_shape() -> void:
	if DungRun.party_ids == null:
		DungRun.party_ids = []
	while DungRun.party_ids.size() < PARTY_SIZE:
		DungRun.party_ids.append("")
	if DungRun.party_ids.size() > PARTY_SIZE:
		var trimmed: Array[String] = []
		for i in range(PARTY_SIZE):
			trimmed.append(DungRun.party_ids[i])
		DungRun.party_ids = trimmed

func _ensure_default_party() -> void:
	for id in DungRun.party_ids:
		if id != "":
			return
	# Только для самого первого запуска (в _ready): ведьма, если она есть, иначе первый открытый.
	var pool: Array[String] = UnitRoster_.get_unlocked_unit_ids() if UnitRoster_ != null else ["witch"]
	var first: String = "witch"
	if not pool.has("witch"):
		first = ""
		for pid in pool:
			if pid != "" and pid != "base_slime":
				first = pid
				break
	DungRun.party_ids[0] = first
	DungRun.leader_id = first

func _on_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= DungRun.party_ids.size():
		return
	if not CORE_LOCK:
		if DungRun.party_ids[slot_index] != "":
			_open_deck_editor(DungRun.party_ids[slot_index])
		return
	if DungRun.party_ids[slot_index] == "" or DungRun.party_ids[slot_index] != DungRun.leader_id:
		return
	_toggle_gold_slot_character(slot_index)

func _toggle_gold_slot_character(slot_index: int) -> void:
	var current_id := DungRun.party_ids[slot_index]
	var unlocked := UnitRoster_.get_unlocked_unit_ids() if UnitRoster_ != null else ["witch"]
	var candidates: Array[String] = []
	for id in ["witch", "warrior"]:
		if unlocked.has(id):
			candidates.append(id)
	if candidates.is_empty():
		return
	var next_idx := 0
	var current_pos := candidates.find(current_id)
	if current_pos != -1:
		next_idx = (current_pos + 1) % candidates.size()
	var target_id := candidates[next_idx]
	var target_slot := _find_party_slot_by_id(target_id)
	if target_slot != -1 and target_slot != slot_index:
		DungRun.party_ids[target_slot] = current_id
	DungRun.party_ids[slot_index] = target_id
	DungRun.leader_id = target_id
	_ensure_default_leader()
	_refresh_team_ui()
	_refresh_roster_strip()

func _find_party_slot_by_id(unit_id: String) -> int:
	for i in range(DungRun.party_ids.size()):
		if DungRun.party_ids[i] == unit_id:
			return i
	return -1

func _is_id_taken_elsewhere(id: String, except_slot: int) -> bool:
	for i in range(DungRun.party_ids.size()):
		if i != except_slot and DungRun.party_ids[i] == id:
			return true
	return false

func _on_slot_drag_started(slot_index: int, pointer_offset: Vector2) -> void:
	if slot_index < 0 or slot_index >= _team_slots.size():
		return
	if DungRun.party_ids[slot_index] == "":
		return
	_drag_slot = _team_slots[slot_index]
	_kill_slot_tween(_drag_slot)
	_drag_source_index = slot_index
	_drag_hover_insert_pos = _find_insert_position_for_drag(slot_index, _slot_base_positions[slot_index].x + SLOT_SIZE.x * 0.5)
	_drag_pointer_offset = pointer_offset
	_drag_slot.scale = Vector2(1.03, 1.03)
	_drag_slot.modulate = Color(1, 1, 1, 0.97)
	_drag_slot.z_index = 100
	_rebuild_drag_preview_order(_drag_hover_insert_pos)
	_animate_drag_preview_order()

func _on_slot_drag_moved(_slot_index: int, global_mouse: Vector2) -> void:
	if _drag_slot == null:
		return
	var local := team_row.get_global_transform().affine_inverse() * global_mouse
	_drag_slot.position = local - _drag_pointer_offset
	var drag_center_x := _drag_slot.position.x + SLOT_SIZE.x * 0.5
	var new_insert := _find_insert_position_for_drag(_drag_source_index, drag_center_x)
	if new_insert != _drag_hover_insert_pos:
		_drag_hover_insert_pos = new_insert
		_rebuild_drag_preview_order(_drag_hover_insert_pos)
		_animate_drag_preview_order()

func _on_slot_drag_released(_slot_index: int, global_mouse: Vector2) -> void:
	if _drag_slot == null:
		return
	var preview_order := _drag_preview_order.duplicate()
	if _is_over_roster_strip(global_mouse):
		var dragged_unit_id := DungRun.party_ids[_drag_source_index]
		if CORE_LOCK and dragged_unit_id != "" and dragged_unit_id == DungRun.leader_id:
			_drag_slot = null
			_drag_source_index = -1
			_drag_hover_insert_pos = -1
			_drag_preview_order.clear()
			_refresh_team_ui()
			_refresh_roster_strip()
			return
		_clear_slot(_drag_source_index)
		_drag_slot = null
		_drag_source_index = -1
		_drag_hover_insert_pos = -1
		_drag_preview_order.clear()
		_refresh_team_ui()
		_refresh_roster_strip()
		return
	if not preview_order.is_empty():
		_apply_preview_order(preview_order)
	_drag_slot = null
	_drag_source_index = -1
	_drag_hover_insert_pos = -1
	_drag_preview_order.clear()
	_refresh_team_ui()
	_refresh_roster_strip()

func _apply_preview_order(preview_order: Array[int]) -> void:
	if preview_order.size() != _team_slots.size():
		return
	var old_party: Array[String] = []
	for id in DungRun.party_ids:
		old_party.append(id)
	for new_index in range(preview_order.size()):
		var old_index := preview_order[new_index]
		if old_index >= 0 and old_index < old_party.size():
			DungRun.party_ids[new_index] = old_party[old_index]
	_ensure_default_leader()

func _clear_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= DungRun.party_ids.size():
		return
	DungRun.party_ids[slot_index] = ""
	_ensure_default_leader()

func _find_insert_position_for_drag(source_index: int, drag_center_x: float) -> int:
	var insert_pos := 0
	for i in range(_slot_base_positions.size()):
		if i == source_index:
			continue
		var center_x := _slot_base_positions[i].x + SLOT_SIZE.x * 0.5
		if drag_center_x > center_x:
			insert_pos += 1
	return clampi(insert_pos, 0, _team_slots.size() - 1)

func _rebuild_drag_preview_order(insert_pos: int) -> void:
	_drag_preview_order.clear()
	for i in range(_team_slots.size()):
		if i != _drag_source_index:
			_drag_preview_order.append(i)
	insert_pos = clampi(insert_pos, 0, _drag_preview_order.size())
	_drag_preview_order.insert(insert_pos, _drag_source_index)

func _animate_drag_preview_order() -> void:
	if _drag_preview_order.size() != _team_slots.size():
		return
	for target_pos in range(_drag_preview_order.size()):
		var slot_index := _drag_preview_order[target_pos]
		var slot := _team_slots[slot_index]
		if slot == _drag_slot:
			continue
		_animate_slot_to(slot, _slot_base_positions[target_pos], Vector2.ONE, target_pos)

func _find_slot_index_at_global(global_pos: Vector2) -> int:
	for i in range(_team_slots.size()):
		if _team_slots[i].get_global_rect().has_point(global_pos):
			return i
	return -1

func _is_over_roster_strip(global_pos: Vector2) -> bool:
	if roster_panel == null:
		return false
	var rect := roster_panel.get_global_rect()
	if rect.has_point(global_pos):
		return true
	return global_pos.y >= rect.position.y - 28.0

func _update_empty_hint() -> void:
	if _empty_hint == null:
		_empty_hint = Label.new()
		_empty_hint.text = "Выбери хотя бы одного героя"
		_empty_hint.add_theme_font_size_override("font_size", 28)
		_empty_hint.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		_empty_hint.add_theme_color_override("font_outline_color", Color(0.2, 0.05, 0.25))
		_empty_hint.add_theme_constant_override("outline_size", 6)
		_empty_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_empty_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_empty_hint.position = Vector2(560, 330)
		_empty_hint.size = Vector2(800, 40)
		team_row.get_parent().add_child(_empty_hint)
	_empty_hint.visible = _party_is_empty()

func _refresh_team_ui(reset_layout: bool = true) -> void:
	_update_empty_hint()
	for i in range(min(DungRun.party_slot_count, _team_slots.size())):
		var slot := _team_slots[i]
		var id := DungRun.party_ids[i]
		var border := FRAME_EMPTY
		if id != "":
			border = FRAME_GOLD if (CORE_LOCK and id == DungRun.leader_id) else FRAME_SILVER
		slot.set_frame_color(border)
		if id == "":
			slot.set_character("", "", null)
		else:
			var data: CharacterData = CharDB.get_by_id(id)
			var tex: Texture2D = null
			var label := id
			if data != null:
				label = data.display_name
				tex = data.battle_texture   ## чибик на площадке — картинка из боя
			slot.set_character(id, label, tex)
	if reset_layout:
		_reset_slot_layout_instant()

func _refresh_roster_strip() -> void:
	if roster_row == null:
		return
	for child in roster_row.get_children():
		child.queue_free()
	_roster_cards.clear()
	var ids: Array[String] = UnitRoster_.get_unlocked_unit_ids() if UnitRoster_ != null else ["warrior", "witch"]
	for id in ids:
		if id == "" or id == "base_slime":
			continue
		var card: TeamSlot = TEAM_SLOT_SCENE.instantiate()
		card.custom_minimum_size = ROSTER_CARD_SIZE
		card.size = ROSTER_CARD_SIZE
		card.scale = Vector2.ONE
		card.can_pick = true   # клик — выбор карт; в отряд — только перетаскиванием
		card.can_drag = true
		card.ui_index = _roster_cards.size()
		card.set_meta("unit_id", id)
		card.pressed.connect(func(_i: int) -> void: _open_deck_editor(id))
		var data: CharacterData = CharDB.get_by_id(id)
		var tex: Texture2D = null
		if data != null:
			tex = data.card_portrait if data.card_portrait != null else (data.icon if data.icon != null else data.battle_texture)
		card.drag_started.connect(_on_roster_card_drag_started.bind(card))
		card.drag_moved.connect(_on_roster_card_drag_moved)
		card.drag_released.connect(_on_roster_card_drag_released)
		roster_row.add_child(card)
		card.set_character(id, _get_character_display_name(id), tex)
		card.set_frame_color(FRAME_GOLD if DungRun.party_ids.has(id) else FRAME_SILVER)
		_roster_cards.append(card)

func _on_roster_card_drag_started(_slot_index: int, pointer_offset: Vector2, card: TeamSlot) -> void:
	_roster_drag_id = String(card.get_meta("unit_id", ""))
	_roster_drag_pointer_offset = pointer_offset * card.scale
	if _roster_drag_id == "":
		return
	if _drag_preview != null:
		_drag_preview.queue_free()
	_drag_preview = TEAM_SLOT_SCENE.instantiate()
	add_child(_drag_preview)
	_drag_preview.size = SLOT_SIZE
	_drag_preview.custom_minimum_size = SLOT_SIZE
	_drag_preview.set_chibi_mode(true)   ## тащим из ростера уже чибика
	_roster_drag_pointer_offset = Vector2(SLOT_SIZE.x * 0.5, SLOT_SIZE.y * 0.62)
	_drag_preview.can_drag = false
	_drag_preview.can_pick = false
	_drag_preview.z_index = 200
	var data: CharacterData = CharDB.get_by_id(_roster_drag_id)
	var tex: Texture2D = null
	if data != null:
		tex = data.battle_texture
	_drag_preview.set_character(_roster_drag_id, _get_character_display_name(_roster_drag_id), tex)
	_drag_preview.set_frame_color(FRAME_SILVER)
	_drag_preview.modulate = Color(1, 1, 1, 0.95)

func _on_roster_card_drag_moved(_slot_index: int, global_mouse: Vector2) -> void:
	if _drag_preview == null:
		return
	_drag_preview.global_position = global_mouse - _roster_drag_pointer_offset

func _on_roster_card_drag_released(_slot_index: int, global_mouse: Vector2) -> void:
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null
	if _roster_drag_id == "":
		return
	var target_index := _find_slot_index_at_global(global_mouse)
	if target_index != -1:
		_drop_roster_into_slot(_roster_drag_id, target_index)
	_roster_drag_id = ""

## Героиня из ростера брошена на слот отряда. Пустой слот — встаёт туда. Занятый — меняется:
## если она уже в отряде, две героини меняются слотами; если нет — занимавшая слот уходит
## обратно в ростер (и если та была лидером, лидером становится новая).
func _drop_roster_into_slot(unit_id: String, target_index: int) -> void:
	var occupant := DungRun.party_ids[target_index]
	if occupant == unit_id:
		return
	var from_index := _find_party_slot_by_id(unit_id)
	if from_index != -1:
		DungRun.party_ids[from_index] = occupant
	elif occupant != "" and occupant == DungRun.leader_id:
		DungRun.leader_id = unit_id
	DungRun.party_ids[target_index] = unit_id
	_ensure_default_leader()
	_refresh_team_ui()
	_refresh_roster_strip()

# --- Колода ----------------------------------------------------------------

func _build_deck_ui() -> void:
	var ui_root := team_row.get_parent()
	_deck_button = Button.new()
	_deck_button.text = "Колода"
	_deck_button.focus_mode = Control.FOCUS_NONE
	_deck_button.position = DECK_BUTTON_RECT.position
	_deck_button.size = DECK_BUTTON_RECT.size
	_deck_button.add_theme_font_size_override("font_size", 30)
	_style_primary_button(_deck_button, Color(0.42, 0.22, 0.46, 0.98), Color(0.18, 0.08, 0.20, 1.0), 22)
	_deck_button.pressed.connect(_open_deck_preview)
	ui_root.add_child(_deck_button)
	_add_hover_bounce(_deck_button)
	_deck_menu = PartyDeckMenu.new()
	ui_root.add_child(_deck_menu)
	EscClose.register(_deck_menu, _deck_menu.close)

## Клик по персонажу — то же меню колоды, его столбик подсвечен.
func _open_deck_editor(unit_id: String) -> void:
	if unit_id == "" or _deck_menu == null:
		return
	_deck_menu.open(unit_id)

## Меню колоды: столбики персонажей отряда и общие карты, там же выбор карт на бой.
func _open_deck_preview() -> void:
	if _deck_menu != null:
		_deck_menu.open()

func _refresh_admin_panel() -> void:
	if add_unit_in_roaster == null or delete_unit_in_roaster == null:
		return
	var add_selected := String(add_unit_in_roaster.get_item_metadata(add_unit_in_roaster.selected)) if add_unit_in_roaster.item_count > 0 and add_unit_in_roaster.selected >= 0 else ""
	var del_selected := String(delete_unit_in_roaster.get_item_metadata(delete_unit_in_roaster.selected)) if delete_unit_in_roaster.item_count > 0 and delete_unit_in_roaster.selected >= 0 else ""

	add_unit_in_roaster.clear()
	delete_unit_in_roaster.clear()
	_add_empty_option(add_unit_in_roaster)
	_add_empty_option(delete_unit_in_roaster)

	var all_ids := _get_all_admin_character_ids()
	var unlocked := UnitRoster_.get_unlocked_unit_ids() if UnitRoster_ != null else []
	for id in all_ids:
		var title := _get_character_display_name(id)
		if not unlocked.has(id):
			add_unit_in_roaster.add_item(title)
			add_unit_in_roaster.set_item_metadata(add_unit_in_roaster.item_count - 1, id)
		if (not CORE_LOCK or (id != "warrior" and id != "witch")) and unlocked.has(id):
			delete_unit_in_roaster.add_item(title)
			delete_unit_in_roaster.set_item_metadata(delete_unit_in_roaster.item_count - 1, id)

	_select_option_by_metadata(add_unit_in_roaster, add_selected)
	_select_option_by_metadata(delete_unit_in_roaster, del_selected)
	add_unit_in_roaster.disabled = add_unit_in_roaster.item_count <= 1
	delete_unit_in_roaster.disabled = delete_unit_in_roaster.item_count <= 1
	_update_admin_apply_button_state()

func _add_empty_option(button: OptionButton) -> void:
	if button == null:
		return
	button.add_item("— Никого —")
	button.set_item_metadata(button.item_count - 1, "")

func _get_selected_option_metadata(button: OptionButton) -> String:
	if button == null or button.item_count == 0 or button.selected < 0:
		return ""
	return String(button.get_item_metadata(button.selected))

func _on_admin_option_changed(_index: int) -> void:
	_update_admin_apply_button_state()

func _update_admin_apply_button_state() -> void:
	if roster_apply_button == null:
		return
	var add_value := _get_selected_option_metadata(add_unit_in_roaster)
	var del_value := _get_selected_option_metadata(delete_unit_in_roaster)
	roster_apply_button.disabled = add_value == "" and del_value == ""

func _get_all_admin_character_ids() -> Array[String]:
	var out: Array[String] = []
	if CharDB == null:
		return out
	for key in CharDB.by_id.keys():
		var id := String(key)
		if id == "" or id == "base_slime":
			continue
		out.append(id)
	out.sort()
	if out.has("warrior"):
		out.erase("warrior")
		out.push_front("warrior")
	if out.has("witch"):
		out.erase("witch")
		var pos := 1 if out.size() >= 1 else 0
		out.insert(pos, "witch")
	return out

func _get_character_display_name(id: String) -> String:
	var data: CharacterData = CharDB.get_by_id(id)
	return data.display_name if data != null and data.display_name != "" else id

func _select_option_by_metadata(button: OptionButton, value: String) -> void:
	if button == null or button.item_count == 0:
		return
	for i in range(button.item_count):
		if String(button.get_item_metadata(i)) == value:
			button.select(i)
			return
	button.select(0)

func _on_admin_apply_pressed() -> void:
	var changed := false
	if add_unit_in_roaster != null and add_unit_in_roaster.item_count > 0 and add_unit_in_roaster.selected >= 0:
		var add_id := String(add_unit_in_roaster.get_item_metadata(add_unit_in_roaster.selected))
		if add_id != "" and UnitRoster_ != null:
			changed = UnitRoster_.unlock_unit(add_id) or changed
	if delete_unit_in_roaster != null and delete_unit_in_roaster.item_count > 0 and delete_unit_in_roaster.selected >= 0:
		var delete_id := String(delete_unit_in_roaster.get_item_metadata(delete_unit_in_roaster.selected))
		if delete_id != "" and UnitRoster_ != null and UnitRoster_.remove_unit(delete_id):
			for i in range(DungRun.party_ids.size()):
				if DungRun.party_ids[i] == delete_id:
					DungRun.party_ids[i] = ""
			_ensure_default_leader()
			changed = true
	if changed:
		_refresh_team_ui()
		_refresh_roster_strip()
	_select_option_by_metadata(add_unit_in_roaster, "")
	_select_option_by_metadata(delete_unit_in_roaster, "")
	_refresh_admin_panel()
	_update_admin_apply_button_state()

func _toggle_admin_panel() -> void:
	_admin_open = not _admin_open
	_sync_admin_panel_visuals()

func _sync_admin_panel_visuals(_immediate: bool = false) -> void:
	if admin_panel == null or admin_content == null or admin_toggle_button == null:
		return
	# Админ-панели закрыты, пока нет доступа (AdminAccess) — не видно и не нажать.
	admin_panel.visible = AdminAccess.unlocked()
	admin_content.visible = _admin_open
	admin_panel.custom_minimum_size.y = 270 if _admin_open else 62
	admin_panel.size.y = admin_panel.custom_minimum_size.y
	# Нижний край на месте: раскрывается вверх.
	admin_panel.position.y = 1022.0 - admin_panel.size.y
	admin_toggle_button.text = "Админ ▾" if _admin_open else "Админ ▸"

func _open_item_popup(kind: String) -> void:
	if _item_popup == null:
		return
	_popup_kind = kind
	match kind:
		"food":
			_item_popup_title.text = "Выбор еды"
		"artifact":
			_item_popup_title.text = "Выбор посоха"
		_:
			_item_popup_title.text = "Выбор зелья"
	_rebuild_item_popup_grid()
	_show_popup_info(_current_popup_id())
	_item_popup.popup_centered(Vector2i(780, 640))

func _rebuild_item_popup_grid() -> void:
	if _item_popup_grid == null:
		return

	for child in _item_popup_grid.get_children():
		child.queue_free()

	var entries := _get_popup_entries(_popup_kind)
	for entry in entries:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(126, 126)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.text = ""
		btn.icon = entry.get("icon", null)
		btn.tooltip_text = String(entry.get("tooltip", ""))

		var id := String(entry.get("id", ""))
		btn.pressed.connect(_on_popup_entry_pressed.bind(_popup_kind, id))
		btn.mouse_entered.connect(_show_popup_info.bind(id))
		btn.mouse_exited.connect(func() -> void: _show_popup_info(_current_popup_id()))

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.43, 0.26, 0.45, 0.94)
		sb.corner_radius_top_left = 18
		sb.corner_radius_top_right = 18
		sb.corner_radius_bottom_left = 18
		sb.corner_radius_bottom_right = 18
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
		sb.border_color = Color(0.17, 0.07, 0.18, 1.0)

		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)

		_item_popup_grid.add_child(btn)


func _get_popup_entries(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []

	if kind == "artifact":
		out.append({
			"id": "",
			"icon": _make_placeholder_icon(Color(0.48, 0.34, 0.52, 1.0)),
			"tooltip": "Без посоха"
		})
		for id in DungRun.get_selectable_artifact_ids():
			out.append({
				"id": id,
				"icon": Inventory_.get_item_icon(id) if Inventory_ != null else null,
				"tooltip": RunItems.get_item_name(id)
			})

	elif kind == "food":
		out.append({
			"id": "",
			"icon": _make_placeholder_icon(Color(0.48, 0.34, 0.52, 1.0)),
			"tooltip": "Без еды"
		})
		for id in DungRun.get_available_food_ids():
			out.append({
				"id": id,
				"icon": Inventory_.get_item_icon(id) if Inventory_ != null else null,
				"tooltip": RunItems.get_item_name(id)
			})

	else:
		out.append({
			"id": "",
			"icon": _make_placeholder_icon(Color(0.48, 0.34, 0.52, 1.0)),
			"tooltip": "Без зелья"
		})
		for potion_id in DungRun.get_available_potion_ids():
			var item_id := RunItems.get_potion_item_id(potion_id)
			out.append({
				"id": potion_id,
				"icon": Inventory_.get_item_icon(item_id) if Inventory_ != null else null,
				"tooltip": RunItems.get_potion_name(potion_id)
			})

	return out


## Что сейчас выбрано в открытом окне (посох / еда / зелье этого слота).
func _current_popup_id() -> String:
	match _popup_kind:
		"artifact":
			return DungRun.selected_artifact_id
		"food":
			return DungRun.selected_food_id
	return DungRun.selected_potion_ids[_potion_slot] if _potion_slot >= 0 and _potion_slot < DungRun.selected_potion_ids.size() else ""

## Название и эффект предмета (id из окна выбора: у зелий — id зелья, иначе id предмета).
func _loadout_item_text(kind: String, id: String) -> Array[String]:
	if id == "":
		var empty := {"artifact": "Без посоха", "food": "Без еды"}
		return [String(empty.get(kind, "Без зелья")), ""]
	if kind == "artifact" or kind == "food":
		return [RunItems.get_item_name(id), RunItems.get_item_desc(id)]
	return [RunItems.get_potion_name(id), RunItems.get_potion_desc(id)]

func _show_popup_info(id: String) -> void:
	if _item_popup_info == null:
		return
	var t := _loadout_item_text(_popup_kind, id)
	_item_popup_info.text = "[b]%s[/b]\n%s" % [t[0], t[1]] if t[1] != "" else "[b]%s[/b]" % t[0]

func _on_popup_entry_pressed(kind: String, id: String) -> void:
	_match_popup_selection(kind, id)
	if _item_popup != null:
		_item_popup.hide()

func _match_popup_selection(kind: String, id: String) -> void:
	match kind:
		"artifact":
			DungRun.selected_artifact_id = id
		"food":
			DungRun.selected_food_id = id
		_:
			DungRun.set_potion_slot(_potion_slot, id)
			if id != "":
				DungRun.selected_potion_id = id
				DungRun.refresh_selected_potion_charges()
	_refresh_loadout_ui()

func _refresh_loadout_ui() -> void:
	if potion_button == null or artifact_button == null or food_button == null:
		return
	for i in range(2):
		var pid := DungRun.selected_potion_ids[i]
		var pt := _loadout_item_text("potion", pid)
		(potion_button if i == 0 else potion_button2).tooltip_text = "Зелье %d: %s%s" % [i + 1, pt[0] if pid != "" else "пусто", ("\n" + pt[1]) if pt[1] != "" else ""]
	# Пустой слот — полупрозрачная картинка того, что в него кладётся (посох / еда / зелье).
	_set_slot_icon(potion_button, _get_potion_icon(DungRun.selected_potion_ids[0]), SLOT_HINT_ICONS["potion"])
	_set_slot_icon(potion_button2, _get_potion_icon(DungRun.selected_potion_ids[1]), SLOT_HINT_ICONS["potion"])
	_set_slot_icon(artifact_button, _get_item_icon_or_null(DungRun.selected_artifact_id), SLOT_HINT_ICONS["artifact"])
	_set_slot_icon(food_button, _get_item_icon_or_null(DungRun.selected_food_id), SLOT_HINT_ICONS["food"])
	# Подсказка при наведении на слот — сразу эффект, без похода в инвентарь.
	for pair in [[artifact_button, "artifact", DungRun.selected_artifact_id, "Посох"], [food_button, "food", DungRun.selected_food_id, "Еда"]]:
		var t := _loadout_item_text(String(pair[1]), String(pair[2]))
		(pair[0] as Button).tooltip_text = "%s: %s%s" % [pair[3], t[0], ("\n" + t[1]) if t[1] != "" else "\nНажмите, чтобы выбрать."]
	potion_button.disabled = DungRun.get_available_potion_ids().is_empty()
	potion_button2.disabled = potion_button.disabled
	var lures := Inventory_.get_item_count(DungRun.LURE_ITEM) if Inventory_ != null else 0
	lure_button.icon = Inventory_.get_item_icon(DungRun.LURE_ITEM) if Inventory_ != null else null
	lure_button.disabled = lures <= 0
	lure_button.set_pressed_no_signal(DungRun.take_lure and lures > 0)
	lure_button.modulate = Color(1, 1, 1, 1.0 if lure_button.button_pressed else 0.45)
	lure_button.tooltip_text = ("Приманка: берём в забег (в сумке %d)" % lures) if lure_button.button_pressed else ("Приманка: не берём (в сумке %d). Нажмите, чтобы взять." % lures if lures > 0 else "Приманок нет — их продаёт Рикка")
	artifact_button.disabled = false
	food_button.disabled = false
	_refresh_loadout_badges()

## «!» на пустом слоте посоха / еды / зелья, если подходящее лежит в сумке.
func _refresh_loadout_badges() -> void:
	NotifyBadge.attach(artifact_button, DungRun.selected_artifact_id == "" and not DungRun.get_selectable_artifact_ids().is_empty())
	NotifyBadge.attach(food_button, DungRun.selected_food_id == "" and not DungRun.get_available_food_ids().is_empty())
	var avail := DungRun.get_available_potion_ids()
	for i in range(2):
		var other := DungRun.selected_potion_ids[1 - i]
		var free_ids := avail.filter(func(id: String) -> bool: return id != other)
		NotifyBadge.attach(potion_button if i == 0 else potion_button2, DungRun.selected_potion_ids[i] == "" and not free_ids.is_empty())

## Воин уже в ростере, а в слоте еды пусто: один раз — сценка «на пустой желудок не пойду»
## (data/dialogues/story/warrior_food.json, "warrior_empty_stomach"): выдаётся желе и сразу кладётся
## в слот еды. Потом можно жать «В бой» снова. true — сценка запущена, в бой пока не идём.
const WARRIOR_FOOD_FLAG := "warrior_food_talk_done"
const WARRIOR_FOOD_DIALOGUE := "warrior_empty_stomach"
const WARRIOR_FOOD_ITEM := "jelly"

func _warrior_food_talk() -> bool:
	if StoryState_ == null or StoryDialogueDB_ == null or StoryState_.has_flag(WARRIOR_FOOD_FLAG):
		return false
	if UnitRoster_ == null or not UnitRoster_.has_unit("warrior") or DungRun.selected_food_id != "":
		return false
	var d := StoryDialogueDB_.get_dialogue(WARRIOR_FOOD_DIALOGUE)
	if d.is_empty():
		return false
	StoryState_.set_flag(WARRIOR_FOOD_FLAG, true)
	DialogueManager_.show_sequence(StoryDialogueDB_.resolve_lines(d), func() -> void:
		StoryState_.mark_dialogue_seen(WARRIOR_FOOD_DIALOGUE)
		# Желе выдано репликой (give_item) — сразу в слот еды.
		if Inventory_ != null and Inventory_.get_item_count(WARRIOR_FOOD_ITEM) <= 0:
			Inventory_.add_item(WARRIOR_FOOD_ITEM, 1)
		DungRun.selected_food_id = WARRIOR_FOOD_ITEM
		_refresh_loadout_ui()
	)
	return true

## Картинки-подсказки в пустых слотах снаряжения (полупрозрачные).
const SLOT_HINT_ICONS := {
	"artifact": "res://assets/items/staffs/stick_staff.png",
	"food": "res://assets/items/food/steak.png",
	"potion": "res://assets/items/potions/slime_potion.png",
}
const SLOT_HINT_ALPHA := 0.3

func _set_slot_icon(b: Button, tex: Texture2D, hint_path: String) -> void:
	var empty := tex == null
	b.icon = tex if not empty else (load(hint_path) as Texture2D if ResourceLoader.exists(hint_path) else null)
	var c := Color(1, 1, 1, SLOT_HINT_ALPHA) if empty else Color.WHITE
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, c)
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, SLOT_HINT_ALPHA * 0.6) if empty else Color(1, 1, 1, 0.5))

func _get_item_icon_or_null(item_id: String) -> Texture2D:
	if item_id != "" and Inventory_ != null:
		return Inventory_.get_item_icon(item_id)
	return null

func _get_potion_icon(potion_id: String) -> Texture2D:
	# Пустой слот зелья — без иконки (раньше там был цветной квадрат-заглушка).
	if potion_id == "":
		return null
	var item_id := RunItems.get_potion_item_id(potion_id)
	if item_id != "" and Inventory_ != null:
		return Inventory_.get_item_icon(item_id)
	return null

func _make_placeholder_icon(color: Color) -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(color)
	for x in range(96):
		image.set_pixel(x, 0, Color(0.16, 0.09, 0.18, 1.0))
		image.set_pixel(x, 95, Color(0.16, 0.09, 0.18, 1.0))
	for y in range(96):
		image.set_pixel(0, y, Color(0.16, 0.09, 0.18, 1.0))
		image.set_pixel(95, y, Color(0.16, 0.09, 0.18, 1.0))
	return ImageTexture.create_from_image(image)

func _on_external_state_changed() -> void:
	_refresh_team_ui()
	_refresh_loadout_ui()
	_refresh_gold()

func _refresh_gold() -> void:
	if gold_label != null:
		gold_label.text = "%d" % DungRun.gold

func _on_roster_changed() -> void:
	_refresh_team_ui()
	_refresh_roster_strip()
	_refresh_admin_panel()

func _party_is_empty() -> bool:
	for id in DungRun.party_ids:
		if id != "":
			return false
	return true

func _on_start_button_pressed() -> void:
	if _party_is_empty():
		_update_empty_hint()
		return
	if _warrior_food_talk():
		return
	_ensure_default_leader()
	DungRun.party_level = int(party_level.value)
	# Ночь после забега — усталость (DayCycle): 1 — «Может, лучше поспать?» (да — домой, нет — в бой
	# с максимумом энергии 1); 2 — бормотание и в бой с максимумом энергии 0.
	var fatigue := DayCycle.fatigue_for_next_run()
	if fatigue == 0:
		_launch_run(0)
		return
	if DialogueManager_.is_showing():
		return
	var d := StoryDialogueDB_.get_dialogue(DayCycle.DLG_RUN_TIRED if fatigue == 1 else DayCycle.DLG_RUN_MUMBLE)
	StoryState_.set_flag(DayCycle.FLAG_PUSH_ON, false)
	DialogueManager_.show_sequence(StoryDialogueDB_.resolve_lines(d), func() -> void:
		if fatigue == 1 and not StoryState_.has_flag(DayCycle.FLAG_PUSH_ON):
			SceneRouter_.go_to_hub()   ## «Да, отличная идея!» — домой, спать
			return
		StoryState_.set_flag(DayCycle.FLAG_PUSH_ON, false)
		_launch_run(fatigue))

## В бой: день сменяется ночью, усталость — на весь забег (DungRun.run_fatigue).
func _launch_run(fatigue: int) -> void:
	DungRun.run_fatigue = fatigue
	DayCycle.on_run_launched()
	SceneRouter_.go_to_card_battle()
