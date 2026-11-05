extends Control

@onready var background: TextureRect = %Background
@onready var farm_slots: Control = %FarmSlots
@onready var hub_button: TextureButton = %HubButton
@onready var shop_button: TextureButton = %ShopButton
@onready var alchemy_button: TextureButton = %AlchemyButton

var pots: Array[FarmPot] = []
var _seed_popup: Control
var _seed_grid: GridContainer
var _seed_popup_title: Label
var _selected_slot_for_planting: int = -1

func _ready() -> void:
	get_tree().paused = false
	UIThemeHelper.apply_pink_theme(self)
	_apply_catalog_assets()
	_connect_nav_buttons()
	_collect_pots()
	_build_seed_popup()
	_refresh_all()
	if FarmState_.state_changed.is_connected(_refresh_all) == false:
		FarmState_.state_changed.connect(_refresh_all)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh_all):
		Inventory_.changed.connect(_refresh_all)

func _exit_tree() -> void:
	if is_instance_valid(FarmState_) and FarmState_.state_changed.is_connected(_refresh_all):
		FarmState_.state_changed.disconnect(_refresh_all)
	if Inventory_ != null and Inventory_.changed.is_connected(_refresh_all):
		Inventory_.changed.disconnect(_refresh_all)

func _apply_catalog_assets() -> void:
	if AssetCatalog_ == null:
		return
	var bg := AssetCatalog_.get_ui_texture("farm_bg")
	if bg != null:
		background.texture = bg
	var home_tex := AssetCatalog_.get_ui_texture("farm_btn_home")
	if home_tex != null:
		hub_button.texture_normal = home_tex
	var shop_tex := AssetCatalog_.get_ui_texture("farm_btn_shop")
	if shop_tex != null:
		shop_button.texture_normal = shop_tex
	var alchemy_tex := AssetCatalog_.get_ui_texture("farm_btn_alchemy")
	if alchemy_tex != null:
		alchemy_button.texture_normal = alchemy_tex

func _collect_pots() -> void:
	# Индекс горшка берём из сцены (slot_index), а не из порядка нод: порядок задаёт только слои
	# (стол/табурет перекрывают часть горшков).
	pots.clear()
	var found: Array[FarmPot] = []
	for child in farm_slots.get_children():
		if child is FarmPot:
			found.append(child as FarmPot)
	found.sort_custom(func(a: FarmPot, b: FarmPot) -> bool: return a.slot_index < b.slot_index)
	for pot in found:
		if not pot.pressed.is_connected(_on_pot_pressed):
			pot.pressed.connect(_on_pot_pressed)
		pots.append(pot)

func _connect_nav_buttons() -> void:
	hub_button.pressed.connect(func(): SceneRouter_.go_to_hub())
	shop_button.pressed.connect(func(): SceneRouter_.go_to_shop())
	alchemy_button.pressed.connect(func(): SceneRouter_.go_to_alchemy())

func _build_seed_popup() -> void:
	if _seed_popup != null:
		return
	# Затемнение на весь экран: блокирует клики по горшкам под окном, клик мимо закрывает его.
	_seed_popup = Control.new()
	_seed_popup.visible = false
	_seed_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_seed_popup.z_index = 40
	add_child(_seed_popup)
	_seed_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_seed_popup.gui_input.connect(_on_seed_popup_backdrop_input)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_popup.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_popup.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	_seed_popup_title = Label.new()
	_seed_popup_title.text = "Выберите семена"
	_seed_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_popup_title.add_theme_font_size_override("font_size", 28)
	box.add_child(_seed_popup_title)

	_seed_grid = GridContainer.new()
	_seed_grid.columns = 3
	_seed_grid.add_theme_constant_override("h_separation", 14)
	_seed_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(_seed_grid)

	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_hide_seed_popup)
	box.add_child(cancel)

func _on_seed_popup_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_seed_popup()

func _unhandled_input(event: InputEvent) -> void:
	if _seed_popup != null and _seed_popup.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_seed_popup()

func _refresh_all() -> void:
	for pot in pots:
		if is_instance_valid(pot):
			pot.refresh()
	_rebuild_seed_popup_buttons()

func _rebuild_seed_popup_buttons() -> void:
	if _seed_grid == null:
		return
	for child in _seed_grid.get_children():
		_seed_grid.remove_child(child)
		child.queue_free()
	for seed_id in FarmState_.get_available_seed_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 210)
		button.clip_contents = true
		button.tooltip_text = RunItems.get_item_desc(seed_id)
		button.pressed.connect(_on_seed_chosen.bind(seed_id))
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		button.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		var icon := TextureRect.new()
		icon.texture = Inventory_.get_item_icon(seed_id)
		icon.custom_minimum_size = Vector2(110, 110)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var name_label := Label.new()
		name_label.text = RunItems.get_item_name(seed_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var count_label := Label.new()
		count_label.text = "×%d" % Inventory_.get_item_count(seed_id)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(count_label)
		_seed_grid.add_child(button)

func _on_pot_pressed(slot_index: int) -> void:
	var slot := FarmState_.get_slot(slot_index)
	match int(slot.get("stage", FarmState.PlantStage.EMPTY)):
		FarmState.PlantStage.EMPTY:
			var seeds := FarmState_.get_available_seed_ids()
			if seeds.is_empty():
				return
			if seeds.size() == 1:
				FarmState_.plant_seed(slot_index, seeds[0])
			else:
				_selected_slot_for_planting = slot_index
				_seed_popup_title.text = "Выберите семечко для горшка %d" % (slot_index + 1)
				_rebuild_seed_popup_buttons()
				_seed_popup.visible = true
		FarmState.PlantStage.SEED, FarmState.PlantStage.SPROUT:
			if FarmState_.water_slot(slot_index):
				if slot_index >= 0 and slot_index < pots.size():
					pots[slot_index].play_water_flash()
		FarmState.PlantStage.FLOWER:
			var harvested_item_id := FarmState_.get_harvest_item_id(slot)
			if FarmState_.harvest_slot(slot_index):
				Inventory_.add_item(harvested_item_id, 1)
	_refresh_all()

func _on_seed_chosen(seed_id: String) -> void:
	if _selected_slot_for_planting >= 0:
		FarmState_.plant_seed(_selected_slot_for_planting, seed_id)
	_selected_slot_for_planting = -1
	_hide_seed_popup()
	_refresh_all()

func _hide_seed_popup() -> void:
	_selected_slot_for_planting = -1
	if _seed_popup != null:
		_seed_popup.visible = false
