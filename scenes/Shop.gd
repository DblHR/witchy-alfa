extends Control

const GRID_SLOT_COUNT := 6
## Рикка уже поздоровалась сегодня (сбрасывается после забега — DungRun.on_run_finished_refresh_shops).
const GREETED_FLAG := "rikka_greeted_today"

@onready var gold_label: Label = %GoldLabel
@onready var seed_label: Label = %SeedLabel
@onready var info_label: Label = %InfoLabel
@onready var stock_grid: GridContainer = %StockGrid

var _pending_shop_dialogue: Dictionary = {}
## Пузыри дежурных фраз Рикки и клик по ней (как у Сессилии и Ноктрис в забеге).
var _bubbles: NpcBubbles
## Цветок Рикки (с 3-го уровня отряда) и окно его кормления.
var _flower: RikkaFlower
var _feed_panel: FlowerFeedPanel
## Рикка с панелькой в руках (на ней окно кормления) — поверх обычной Рикки, плавная смена.
const RIKKA_WITH_FLOWER := "res://assets/npc/rikka/rikka_with_flower.png"
## Где Рикка с панелькой на экране (картинка 988×1280 — рамка своя, не как у обычной Рикки).
const RIKKA_WITH_FLOWER_RECT := Rect2(1016, 40, 909, 1178)
const SWAP_TIME := 0.35
var _rikka: TextureRect
var _rikka_alt: TextureRect
var _swap: Tween
## Экскурсия при первом заходе (scenes/npc/RikkaTour.tscn): пока идёт — лавка закрыта.
const TOUR_SCENE := "res://scenes/npc/RikkaTour.tscn"
const TOUR_FADE := 0.25
var _tour: RikkaTour
var _tour_blocker: Control
var _tour_glow: Dictionary = {}   ## индекс ячейки -> Tween подсветки

func _ready() -> void:
	UIThemeHelper.apply_pink_theme(self)
	# Рикка — отдельной картинкой поверх фона (на фоне её больше нет).
	var bg := get_node_or_null("background")
	if bg != null:
		var npc := ShopUi.make_npc_sprite("rikka")
		add_child(npc)
		move_child(npc, bg.get_index() + 1)
		_bubbles = NpcBubbles.attach(self, npc, "rikka")
		_rikka = npc
	HubMenu.attach(self)   ## меню комнат сверху справа (Лавка, Ферма, Алхимия, Дом) вместо «назад»
	if DungRun != null and not DungRun.changed.is_connected(_refresh):
		DungRun.changed.connect(_refresh)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh):
		Inventory_.changed.connect(_refresh)
	DungRun.ensure_ground_shop_stock()
	_build_stock_grid()
	_build_flower()
	_refresh()
	call_deferred("_show_rikka_greeting")

func _exit_tree() -> void:
	if DungRun != null and DungRun.changed.is_connected(_refresh):
		DungRun.changed.disconnect(_refresh)
	if Inventory_ != null and Inventory_.changed.is_connected(_refresh):
		Inventory_.changed.disconnect(_refresh)

func _show_rikka_greeting() -> void:
	_pending_shop_dialogue = {}
	if StoryDialogueDB_ == null or DialogueManager_ == null:
		return
	# Сюжетные диалоги (квесты, разовые сцены) — окном диалога (VN), всегда.
	var d := StoryDialogueDB_.pick_npc_dialogue("rikka", "event")
	if d.is_empty():
		d = StoryDialogueDB_.pick_npc_dialogue("rikka", "flag")
	if not d.is_empty() and not StoryDialogueDB_.is_routine(d):
		var lines := StoryDialogueDB_.resolve_lines(d)
		if not lines.is_empty():
			_pending_shop_dialogue = d
			if String(d.get("tour", "")) != "":
				_lock_shop(true)   ## сразу: между VN и экскурсией тоже ничего не нажать
			DialogueManager_.show_sequence(lines, Callable(self, "_on_rikka_dialogue_finished"))
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

func _on_rikka_dialogue_finished() -> void:
	# После VN — экскурсия по лавке ("tour": id диалога с репликами и анимациями).
	var tour_id := String(_pending_shop_dialogue.get("tour", ""))
	if tour_id != "":
		await _run_tour(tour_id)
	if not _pending_shop_dialogue.is_empty() and StoryDialogueDB_ != null:
		var dialogue_id := String(_pending_shop_dialogue.get("id", ""))
		if dialogue_id != "" and StoryState_ != null:
			StoryState_.mark_dialogue_seen(dialogue_id)
		StoryDialogueDB_.apply_effects(_pending_shop_dialogue.get("on_finish", {}))
	_pending_shop_dialogue = {}
	DungRun.ensure_lure_in_shop()
	_refresh()

# --- Экскурсия Рикки (первый заход) -------------------------------------------

## Невидимая заглушка поверх всей лавки: ни купить, ни уйти (меню), ни тыкнуть Рикку/цветок.
## Клик по ней — «дочитал, дальше».
func _lock_shop(on: bool) -> void:
	if on:
		if _tour_blocker != null:
			return
		_tour_blocker = Control.new()
		_tour_blocker.name = "TourBlocker"
		_tour_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_tour_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
		_tour_blocker.z_index = 100
		_tour_blocker.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and _tour != null:
				_tour.skip_reading())
		add_child(_tour_blocker)
	elif _tour_blocker != null:
		_tour_blocker.queue_free()
		_tour_blocker = null

func is_tour_running() -> bool:
	return _tour_blocker != null

func _run_tour(tour_id: String) -> void:
	var d := StoryDialogueDB_.get_dialogue(tour_id) if StoryDialogueDB_ != null else {}
	var lines: Array = StoryDialogueDB_.resolve_lines(d) if not d.is_empty() else []
	if lines.is_empty() or not ResourceLoader.exists(TOUR_SCENE) or _rikka == null:
		_lock_shop(false)
		return
	_lock_shop(true)
	if _bubbles != null:
		_bubbles.clear()
	_tour = (load(TOUR_SCENE) as PackedScene).instantiate() as RikkaTour
	add_child(_tour)
	move_child(_tour, $Panel.get_index() + 1)   ## над витриной (руки поверх неё), под меню и пузырями
	_tour.highlight_requested.connect(_tour_highlight)
	_tour.line_requested.connect(func(text: String, at: Vector2) -> void:
		if _bubbles != null:
			_bubbles.say_at(text, at))
	# Обычная Рикка прячется, вместо неё — Рикка экскурсии (та же картинка на том же месте).
	_rikka.visible = false
	_tour.modulate.a = 0.0
	var tw := _tour.create_tween()
	tw.tween_property(_tour, "modulate:a", 1.0, TOUR_FADE)
	await _tour.play(lines)
	_tour_highlight([])
	_rikka.visible = true
	_tour.queue_free()
	_tour = null
	_lock_shop(false)

## Подсветить ячейки витрины (мягко мигают), остальные — обычные.
func _tour_highlight(slots: Array) -> void:
	var cards := stock_grid.get_children()
	for i in _tour_glow.keys():
		var t: Tween = _tour_glow[i]
		if t != null and t.is_valid():
			t.kill()
		if int(i) < cards.size():
			var c := cards[int(i)] as Control
			c.self_modulate = Color.WHITE
			c.scale = Vector2.ONE
	_tour_glow.clear()
	for s in slots:
		var i := int(s)
		if i < 0 or i >= cards.size():
			continue
		var c := cards[i] as Control
		c.pivot_offset = c.size * 0.5
		var t := c.create_tween().set_loops()
		t.tween_property(c, "self_modulate", Color(1.35, 1.2, 1.35), 0.35).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(c, "scale", Vector2(1.05, 1.05), 0.35).set_trans(Tween.TRANS_SINE)
		t.tween_property(c, "self_modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE)
		_tour_glow[i] = t

# --- Цветок Рикки -------------------------------------------------------------

func _build_flower() -> void:
	if not RikkaFlower.is_unlocked():
		return
	add_child(RikkaFlower.make_stool())   ## табуретка, на ней цветок
	_flower = RikkaFlower.new()
	add_child(_flower)   ## поверх панели лавки (табуретка заходит на её угол)
	_flower.clicked.connect(_on_flower_clicked)
	_flower.below = _bubbles
	_feed_panel = FlowerFeedPanel.new()
	add_child(_feed_panel)
	_feed_panel.fed.connect(_on_flower_fed)
	_feed_panel.close_requested.connect(_close_feed_panel)
	_feed_panel.flower_renamed.connect(_on_flower_renamed)
	# Рикка с панелькой: дочерний узел обычной Рикки (прячется вместе с ней на время диалогов).
	if _rikka != null and ResourceLoader.exists(RIKKA_WITH_FLOWER):
		_rikka_alt = TextureRect.new()
		_rikka_alt.name = "RikkaWithFlower"
		_rikka_alt.texture = load(RIKKA_WITH_FLOWER)
		_rikka_alt.expand_mode = _rikka.expand_mode
		_rikka_alt.stretch_mode = _rikka.stretch_mode
		_rikka_alt.texture_filter = _rikka.texture_filter
		_rikka_alt.position = RIKKA_WITH_FLOWER_RECT.position - _rikka.position
		_rikka_alt.size = RIKKA_WITH_FLOWER_RECT.size
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
	_flower.refresh_texture()
	_flower.refresh_badge()
	_open_feed_panel()

## Цветок переименовали в окне кормления: другая картинка и (у особых имён) диалог.
func _on_flower_renamed(new_name: String) -> void:
	_flower.refresh_texture()
	var did := NameRules.dialogue_for(RikkaFlower.NPC_ID, new_name)
	var d := StoryDialogueDB_.get_dialogue(did) if did != "" and StoryDialogueDB_ != null else {}
	if d.is_empty() or DialogueManager_ == null:
		return
	_close_feed_panel()
	if _bubbles != null:
		_bubbles.clear()
	DialogueManager_.show_sequence(StoryDialogueDB_.resolve_lines(d), func() -> void: _open_feed_panel())

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
	# Золото — плашка goldStatus в правом верхнем углу бежевой подложки (Shop.tscn → Panel/GoldStatus).
	stock_grid.global_position = ShopUi.GRID_POS
	stock_grid.columns = 3
	stock_grid.add_theme_constant_override("h_separation", ShopUi.CARD_GAP)
	stock_grid.add_theme_constant_override("v_separation", ShopUi.CARD_GAP)

func _on_stock_pressed(slot_idx: int) -> void:
	# Имя заранее: у котла название меняется после покупки (следующий уровень).
	var bought_name := ""
	if slot_idx >= 0 and slot_idx < DungRun.ground_shop_item_ids.size():
		bought_name = RunItems.get_item_name(DungRun.ground_shop_item_ids[slot_idx])
	var item_id := DungRun.buy_ground_shop_item(slot_idx)
	if item_id == "":
		_refresh("Не удалось купить предмет.")
		return
	_refresh("Куплено: %s" % bought_name)

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
