extends Control

const GRID_SLOT_COUNT := 6
## Рикка уже поздоровалась сегодня (сбрасывается после забега — DungRun.on_run_finished_refresh_shops).
const GREETED_FLAG := "rikka_greeted_today"

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
	# Сюжетные диалоги (квесты) — всегда; обычное приветствие — раз в день (день = забег).
	_pending_shop_dialogue = StoryDialogueDB_.pick_npc_dialogue("rabbit_shop", "event")
	if _pending_shop_dialogue.is_empty():
		if StoryState_ != null and StoryState_.has_flag(GREETED_FLAG):
			return
		_pending_shop_dialogue = StoryDialogueDB_.pick_npc_dialogue("rabbit_shop", "flag")
	if _pending_shop_dialogue.is_empty():
		return
	if StoryState_ != null:
		StoryState_.set_flag(GREETED_FLAG, true)
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

## Лавка в том же виде, что и у Сессилии (ShopUi): заголовок, описание, карточки товара.
func _build_stock_grid() -> void:
	var title := $Panel/Title as Label
	title.text = "Лавка Рикки"
	title.global_position = ShopUi.TITLE_RECT.position
	title.size = ShopUi.TITLE_RECT.size
	ShopUi.style_title(title)
	info_label.global_position = ShopUi.DESC_RECT.position
	info_label.size = ShopUi.DESC_RECT.size
	ShopUi.style_text(info_label, 28)
	seed_label.global_position = ShopUi.NOTE_RECT.position
	seed_label.size = ShopUi.NOTE_RECT.size
	ShopUi.style_text(seed_label, 22)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	gold_label.global_position = ShopUi.COIN_TEXT_POS
	ShopUi.style_gold(gold_label)
	stock_grid.global_position = ShopUi.GRID_POS
	stock_grid.columns = 3
	stock_grid.add_theme_constant_override("h_separation", ShopUi.CARD_GAP)
	stock_grid.add_theme_constant_override("v_separation", ShopUi.CARD_GAP)

func _on_stock_pressed(slot_idx: int) -> void:
	var item_id := DungRun.buy_ground_shop_item(slot_idx)
	if item_id == "":
		_refresh("Не удалось купить предмет.")
		return
	_refresh("Куплено: %s" % RunItems.get_item_name(item_id))

func _refresh(message: String = "") -> void:
	gold_label.text = "%d" % DungRun.gold
	info_label.text = "Кварц и семена есть всегда; ещё еда, обычные посохи, рецепты и ингредиенты. Товар обновляется после каждого забега."
	if StoryState_ != null and StoryState_.is_quest_active("find_warrior"):
		info_label.text += "\nКвест «Пропавший воин»: ищите его в первых комнатах подземелья."
	var note := "Кварц: %d · рецептов еды открыто: %d из %d" % [Inventory_.get_item_count("quartz"), DungRun.known_recipes.size(), DungRun.known_recipes.size() + AlchemyDB.unknown_recipe_items().size()]
	seed_label.text = message if message != "" else note
	for child in stock_grid.get_children():
		stock_grid.remove_child(child)
		child.queue_free()
	for i in range(mini(GRID_SLOT_COUNT, DungRun.ground_shop_item_ids.size())):
		var item_id := DungRun.ground_shop_item_ids[i]
		var card: Button
		if item_id == "":
			card = ShopUi.make_item_card(null, "", 1, 0, "", "sold")
		else:
			var price := RunItems.get_item_price(item_id)
			var state := "poor" if DungRun.gold < price else ""
			if RunItems.is_unique_item(item_id) and Inventory_ != null and Inventory_.has_item(item_id):
				state = "sold"
			card = ShopUi.make_item_card(Inventory_.get_item_icon(item_id), RunItems.get_item_name(item_id), 1, price,
				"%s [%s]\n%s" % [RunItems.get_item_name(item_id), RunItems.get_item_kind_label(item_id), RunItems.get_item_desc(item_id)], state)
			card.pressed.connect(_on_stock_pressed.bind(i))
		stock_grid.add_child(card)
