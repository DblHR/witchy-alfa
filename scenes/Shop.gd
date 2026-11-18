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
## Пузыри дежурных фраз Рикки и клик по ней (как у Сессилии и Ноктрис в забеге).
var _bubbles: NpcBubbles
## Цветок Рикки (с 3-го уровня отряда) и окно его кормления.
var _flower: RikkaFlower
var _feed_panel: FlowerFeedPanel
## Рикка с панелькой в руках (на ней окно кормления) — поверх обычной Рикки, плавная смена.
const RIKKA_WITH_FLOWER := "res://assets/npc/rikka/rikka_with_flower.png"
const SWAP_TIME := 0.35
var _rikka: TextureRect
var _rikka_alt: TextureRect
var _swap: Tween

func _ready() -> void:
	UIThemeHelper.apply_pink_theme(self)
	# Рикка — отдельной картинкой поверх фона (на фоне её больше нет).
	var bg := get_node_or_null("background")
	if bg != null:
		var npc := ShopUi.make_npc_sprite("rabbit_shop")
		add_child(npc)
		move_child(npc, bg.get_index() + 1)
		_bubbles = NpcBubbles.attach(self, npc, "rabbit_shop")
		_rikka = npc
	home_button.pressed.connect(func(): SceneRouter_.go_to_hub())
	if DungRun != null and not DungRun.changed.is_connected(_refresh):
		DungRun.changed.connect(_refresh)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh):
		Inventory_.changed.connect(_refresh)
	DungRun.ensure_ground_shop_stock()
	_build_stock_grid()
	_build_flower()
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
	# Сюжетные диалоги (квесты, разовые сцены) — окном диалога (VN), всегда.
	var d := StoryDialogueDB_.pick_npc_dialogue("rabbit_shop", "event")
	if d.is_empty():
		d = StoryDialogueDB_.pick_npc_dialogue("rabbit_shop", "flag")
	if not d.is_empty() and not StoryDialogueDB_.is_routine(d):
		var lines := StoryDialogueDB_.resolve_lines(d)
		if not lines.is_empty():
			_pending_shop_dialogue = d
			DialogueManager_.show_sequence(lines, Callable(self, "_on_rabbit_shop_dialogue_finished"))
			return
	# Обычное приветствие — пузырём у Рикки (при каждом заходе), без окна диалога.
	if d.is_empty() or _bubbles == null:
		return
	_bubbles.raise_layer()
	_bubbles.say(StoryDialogueDB_.resolve_lines(d))
	# Приманка докладывается в лавку раз в день (как раньше — после первого приветствия за день).
	var first_today := StoryState_ == null or not StoryState_.has_flag(GREETED_FLAG)
	if StoryState_ != null:
		StoryState_.set_flag(GREETED_FLAG, true)
		StoryState_.mark_dialogue_seen(String(d.get("id", "")))
	if first_today:
		DungRun.ensure_lure_in_shop()
		_refresh()

func _on_rabbit_shop_dialogue_finished() -> void:
	if not _pending_shop_dialogue.is_empty() and StoryDialogueDB_ != null:
		var dialogue_id := String(_pending_shop_dialogue.get("id", ""))
		if dialogue_id != "" and StoryState_ != null:
			StoryState_.mark_dialogue_seen(dialogue_id)
		StoryDialogueDB_.apply_effects(_pending_shop_dialogue.get("on_finish", {}))
	_pending_shop_dialogue = {}
	DungRun.ensure_lure_in_shop()
	_refresh()

# --- Цветок Рикки -------------------------------------------------------------

func _build_flower() -> void:
	if not RikkaFlower.is_unlocked():
		return
	_flower = RikkaFlower.new()
	add_child(_flower)   ## поверх панели лавки (табуретка заходит на её угол)
	_flower.clicked.connect(_on_flower_clicked)
	_flower.below = _bubbles
	_feed_panel = FlowerFeedPanel.new()
	add_child(_feed_panel)
	_feed_panel.fed.connect(_on_flower_fed)
	_feed_panel.close_requested.connect(_close_feed_panel)
	# Рикка с панелькой: дочерний узел обычной Рикки (прячется вместе с ней на время диалогов).
	if _rikka != null and ResourceLoader.exists(RIKKA_WITH_FLOWER):
		_rikka_alt = TextureRect.new()
		_rikka_alt.name = "RikkaWithFlower"
		_rikka_alt.texture = load(RIKKA_WITH_FLOWER)
		_rikka_alt.expand_mode = _rikka.expand_mode
		_rikka_alt.stretch_mode = _rikka.stretch_mode
		_rikka_alt.texture_filter = _rikka.texture_filter
		_rikka_alt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rikka_alt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rikka_alt.modulate.a = 0.0
		_rikka_alt.visible = false
		_rikka.add_child(_rikka_alt)
	if _bubbles != null:
		_bubbles.blocked = func() -> bool: return _feed_panel.is_open()
	if _bubbles != null:
		_bubbles.raise_layer()

func _on_flower_clicked() -> void:
	if not RikkaFlower.intro_seen():
		var d := StoryDialogueDB_.pick_npc_dialogue(RikkaFlower.NPC_ID, "event") if StoryDialogueDB_ != null else {}
		if not d.is_empty() and DialogueManager_ != null:
			if _bubbles != null:
				_bubbles.clear()
			DialogueManager_.show_sequence(StoryDialogueDB_.resolve_lines(d), _on_flower_intro_finished)
			return
		if StoryState_ != null:
			StoryState_.mark_dialogue_seen(RikkaFlower.INTRO_ID)
	if _feed_panel.is_open():
		_close_feed_panel()
	else:
		_open_feed_panel()

## Рикка плавно сменяется на картинку с панелькой, на панельке появляется инвентарь.
func _open_feed_panel() -> void:
	if _bubbles != null:
		_bubbles.clear()   ## пузыри Рикки — там же, где окно
	if _rikka_alt == null:
		_feed_panel.open()
		return
	_swap_rikka(true)
	_feed_panel.open_after(SWAP_TIME * 0.6)

## Назад к обычной лавке: инвентарь гаснет, Рикка возвращается.
func _close_feed_panel() -> void:
	_feed_panel.close()
	if _rikka_alt != null:
		_swap_rikka(false)

func _swap_rikka(with_board: bool) -> void:
	if _swap != null and _swap.is_valid():
		_swap.kill()
	_rikka_alt.visible = true
	_swap = create_tween().set_parallel(true)
	_swap.tween_property(_rikka_alt, "modulate:a", 1.0 if with_board else 0.0, SWAP_TIME)
	_swap.tween_property(_rikka, "self_modulate:a", 0.0 if with_board else 1.0, SWAP_TIME)
	if not with_board:
		_swap.chain().tween_callback(func() -> void: _rikka_alt.visible = false)

func _on_flower_intro_finished() -> void:
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen(RikkaFlower.INTRO_ID)
	_flower.refresh_badge()
	_open_feed_panel()

func _on_flower_fed(_id: String, _n: int, gold: int) -> void:
	_flower.chomp()
	var f := Label.new()
	f.text = "+%d зол." % gold
	f.add_theme_font_size_override("font_size", 40)
	f.add_theme_color_override("font_color", ShopUi.GOLD)
	f.add_theme_color_override("font_outline_color", Color(0.25, 0.10, 0.20))
	f.add_theme_constant_override("outline_size", 10)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.position = _flower.position + Vector2(_flower.size.x * 0.42, 0)
	add_child(f)
	var tw := f.create_tween().set_parallel(true)
	tw.tween_property(f, "position:y", f.position.y - 90, 0.9)
	tw.tween_property(f, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(f.queue_free)

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
	info_label.text = "Товар обновляется после каждого забега."
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
