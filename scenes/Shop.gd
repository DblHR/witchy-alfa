extends Control

const GRID_SLOT_COUNT := 6

@onready var gold_label: Label = %GoldLabel
@onready var seed_label: Label = %SeedLabel
@onready var info_label: Label = %InfoLabel
@onready var home_button: TextureButton = %HomeButton
@onready var stock_grid: GridContainer = %StockGrid

var _pending_shop_dialogue: Dictionary = {}

func _ready() -> void:
	UIThemeHelper.apply_pink_theme(self)
	home_button.pressed.connect(func(): SceneRouter_.go_to_hub())
	if DungRun != null and not DungRun.changed.is_connected(_refresh):
		DungRun.changed.connect(_refresh)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh):
		Inventory_.changed.connect(_refresh)
	DungRun.ensure_ground_shop_stock()
	_build_stock_grid()
	_refresh()
	call_deferred("_show_rabbit_shop_greeting")

func _exit_tree() -> void:
	if DungRun != null and DungRun.changed.is_connected(_refresh):
		DungRun.changed.disconnect(_refresh)
	if Inventory_ != null and Inventory_.changed.is_connected(_refresh):
		Inventory_.changed.disconnect(_refresh)

func _show_rabbit_shop_greeting() -> void:
	_pending_shop_dialogue = {}
	if StoryDialogueDB_ == null or DialogueManager_ == null:
		return
	_pending_shop_dialogue = StoryDialogueDB_.pick_npc_dialogue("rabbit_shop", "event")
	if _pending_shop_dialogue.is_empty():
		_pending_shop_dialogue = StoryDialogueDB_.pick_npc_dialogue("rabbit_shop", "flag")
	if _pending_shop_dialogue.is_empty():
		return
	var lines := StoryDialogueDB_.resolve_lines(_pending_shop_dialogue)
	if lines.is_empty():
		return
	DialogueManager_.show_sequence(lines, Callable(self, "_on_rabbit_shop_dialogue_finished"))

func _on_rabbit_shop_dialogue_finished() -> void:
	if not _pending_shop_dialogue.is_empty() and StoryDialogueDB_ != null:
		var dialogue_id := String(_pending_shop_dialogue.get("id", ""))
		if dialogue_id != "" and StoryState_ != null:
			StoryState_.mark_dialogue_seen(dialogue_id)
		StoryDialogueDB_.apply_effects(_pending_shop_dialogue.get("on_finish", {}))
	_pending_shop_dialogue = {}
	_refresh()

func _build_stock_grid() -> void:
	for child in stock_grid.get_children():
		child.queue_free()
	for i in range(GRID_SLOT_COUNT):
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 250)
		button.clip_contents = true
		button.pressed.connect(_on_stock_pressed.bind(i))
		stock_grid.add_child(button)
		var box := VBoxContainer.new()
		box.name = "Content"
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.anchors_preset = Control.PRESET_FULL_RECT
		box.offset_left = 12
		box.offset_top = 12
		box.offset_right = -12
		box.offset_bottom = -12
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		button.add_child(box)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = Vector2(100, 100)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var title := Label.new()
		title.name = "Title"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.add_theme_font_size_override("font_size", 20)
		box.add_child(title)
		var price := Label.new()
		price.name = "Price"
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price.add_theme_font_size_override("font_size", 22)
		box.add_child(price)

func _on_stock_pressed(slot_idx: int) -> void:
	var item_id := DungRun.buy_ground_shop_item(slot_idx)
	if item_id == "":
		_refresh("Не удалось купить предмет.")
		return
	_refresh("Куплено: %s" % RunItems.get_item_name(item_id))

func _refresh(message: String = "") -> void:
	gold_label.text = "Золото: %d" % DungRun.gold
	seed_label.text = "Семена: %d | Ведьмины семена: %d | Кварц: %d | Зелье слаймов: %d" % [Inventory_.get_item_count("slimeflower_seed"), Inventory_.get_item_count("witchflower_seed"), Inventory_.get_item_count("quartz"), Inventory_.get_item_count("slime_potion")]
	info_label.text = "В лавке всегда можно докупить семена, кварц и часть расходников."
	if StoryState_ != null and StoryState_.is_quest_active("find_warrior"):
		info_label.text += "\n\nКролик просила присмотреться к слухам о пропавшем воине. Комната для этого квеста будет подключена позже."
	if message != "":
		info_label.text += "\n\n" + message
	for i in range(min(stock_grid.get_child_count(), DungRun.ground_shop_item_ids.size())):
		var button := stock_grid.get_child(i) as Button
		var item_id := DungRun.ground_shop_item_ids[i]
		if item_id == "":
			_populate_shop_card(button, "", null, 0, "", true)
			continue
		var price := RunItems.get_item_price(item_id)
		var disabled := DungRun.gold < price
		if RunItems.is_unique_item(item_id) and Inventory_ != null and Inventory_.has_item(item_id):
			disabled = true
		_populate_shop_card(button, RunItems.get_item_name(item_id), Inventory_.get_item_icon(item_id), price, "%s\n[%s]\n%s" % [RunItems.get_item_name(item_id), RunItems.get_item_kind_label(item_id), RunItems.get_item_desc(item_id)], disabled)

func _populate_shop_card(button: Button, title_text: String, icon_tex: Texture2D, price: int, tooltip: String, disabled: bool) -> void:
	var box := button.get_node("Content") as VBoxContainer
	var icon := box.get_node("Icon") as TextureRect
	var title := box.get_node("Title") as Label
	var price_label := box.get_node("Price") as Label
	button.tooltip_text = tooltip
	button.disabled = disabled
	icon.texture = icon_tex
	title.text = "Пусто" if title_text == "" else title_text
	price_label.text = "" if title_text == "" else "%dg" % price
