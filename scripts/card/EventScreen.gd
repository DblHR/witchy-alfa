extends Control
class_name EventScreen
## Ивент-комната карточного забега на весь экран, как в старом режиме: фон с NPC,
## вступительный диалог из StoryDialogueDB, слева заголовок/описание/кнопки.
## Лавка, медсестра, сундук (на весь экран, клик открывает), статуя.
## Все изменения состояния делает CardBattle через run_* (экран только показывает и вызывает).
## Сигнал finished — игрок нажал «Идти дальше».

signal finished

## Медсестра Ноктрис: одна платная услуга из трёх за заход.
const NURSE_HEAL_PERCENT := 0.5
const NURSE_REVIVE_PERCENT := 0.3
const NURSE_HEAL_PRICE := 25
const NURSE_REVIVE_PRICE := 45

const LEFT_X := 120.0
const TITLE_RECT := Rect2(120, 60, 860, 110)
const DESC_RECT := Rect2(120, 180, 860, 340)
const OPTIONS_RECT := Rect2(120, 560, 800, 360)
const CONTINUE_RECT := Rect2(120, 947, 320, 68)
const STATUE_RECT := Rect2(1097, 306, 660, 800)
const SHOP_CARD_ZOOM := 1.4

## Фоны лавки и медсестры уже содержат нарисованную панель и монету: текст кладём на неё тёмным.
const PANEL_TITLE_RECT := Rect2(110, 112, 980, 90)
const PANEL_DESC_RECT := Rect2(110, 206, 980, 190)
const PANEL_OPTIONS_RECT := Rect2(110, 430, 980, 440)
const PANEL_CARDS_POS := Vector2(110, 420)
const PANEL_CONTINUE_POS := Vector2(110, 900)
const PANEL_TEXT := Color(0.27, 0.12, 0.30)
const PANEL_TITLE := Color(0.78, 0.22, 0.52)
const COIN_TEXT_POS := Vector2(1590, 46)

const TITLES := {
	"shop": "Тихая лавка Сессилии",
	"nurse": "Медсестра Ноктрис",
	"chest": "Сундук",
}

var battle: Node
var room: Dictionary

var _bg: TextureRect
var _shade: TextureRect
var _chest_pic: TextureRect
var _npc: TextureRect
var _title: Label
var _desc: Label
var _options: VBoxContainer
var _cards: HBoxContainer
var _continue: Button
var _gold_label: Label
var _chest_waiting := false
var _image_open := false
var _intro: Dictionary = {}
var _intro_waiting := false

func setup(p_battle: Node, p_room: Dictionary) -> void:
	battle = p_battle
	room = p_room
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg = _make_full_texture()
	_bg.texture = AssetCatalog_.get_event_background(_event_enum(), _variant_enum()) if AssetCatalog_ != null else null
	add_child(_bg)

	_chest_pic = _make_full_texture()
	_chest_pic.visible = false
	add_child(_chest_pic)

	_npc = TextureRect.new()
	_npc.position = STATUE_RECT.position
	_npc.size = STATUE_RECT.size
	_npc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_npc.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_npc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_npc)

	# Мягкое затемнение слева, чтобы текст читался поверх любого фона.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.05, 0.02, 0.12, 0.72))
	grad.set_color(1, Color(0.05, 0.02, 0.12, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	_shade = TextureRect.new()
	_shade.texture = gt
	_shade.position = Vector2.ZERO
	_shade.size = Vector2(1120, 1080)
	_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shade.stretch_mode = TextureRect.STRETCH_SCALE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)

	_title = RunUiKit.make_label("", 64, RunUiKit.GOLD, false)
	_title.position = TITLE_RECT.position
	_title.size = TITLE_RECT.size
	_title.add_theme_constant_override("outline_size", 8)
	add_child(_title)

	_desc = RunUiKit.make_label("", 32, Color.WHITE, false, true)
	_desc.position = DESC_RECT.position
	_desc.size = DESC_RECT.size
	_desc.add_theme_constant_override("outline_size", 8)
	add_child(_desc)

	_options = VBoxContainer.new()
	_options.position = OPTIONS_RECT.position
	_options.size = OPTIONS_RECT.size
	_options.add_theme_constant_override("separation", 14)
	_options.mouse_filter = Control.MOUSE_FILTER_IGNORE   # контейнеры не должны перекрывать кнопки соседей
	add_child(_options)

	_cards = HBoxContainer.new()
	_cards.position = Vector2(LEFT_X, 520)
	_cards.size = Vector2(900, 410)
	_cards.add_theme_constant_override("separation", 16)
	_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cards)

	_continue = RunUiKit.make_button("ИДТИ ДАЛЬШЕ", CONTINUE_RECT.size, 30)
	_continue.position = CONTINUE_RECT.position
	_continue.size = CONTINUE_RECT.size
	_continue.pressed.connect(func() -> void:
		finished.emit()
		queue_free()
	)
	add_child(_continue)

	# Золото и прогресс забега сверху (общий HUD закрыт этим экраном).
	_gold_label = RunUiKit.make_label("", 26, Color(1.0, 0.88, 0.4), false)
	_gold_label.size = Vector2(520, 36)
	_gold_label.add_theme_constant_override("outline_size", 6)
	add_child(_gold_label)
	var run: CardRun = battle.call("get_run")
	var progress := RunProgress.new()
	progress.position = Vector2(0, 14)
	progress.size = Vector2(1920, 30)
	add_child(progress)
	progress.setup(run.total_rooms(), run.index)

	_begin_intro.call_deferred()

# --- Вступительный диалог ----------------------------------------------------

func _begin_intro() -> void:
	var event_id := String(room.get("event", ""))
	if event_id == "shop" and StoryState_ != null and not bool(room.get("visit_counted", false)):
		room["visit_counted"] = true
		StoryState_.add_counter("lamia_visits", 1)
	var lines: Array = []
	if StoryDialogueDB_ != null and DialogueManager_ != null and not bool(room.get("intro_seen", false)):
		var npc_override := "lamia" if event_id == "shop" else ""
		_intro = StoryDialogueDB_.pick_intro_for_event(_event_enum(), _variant_enum(), npc_override)
		if not _intro.is_empty():
			lines = StoryDialogueDB_.resolve_lines(_intro)
	room["intro_seen"] = true
	if lines.is_empty():
		_rebuild()
		return
	_set_controls_visible(false)
	_intro_waiting = true
	DialogueManager_.show_sequence(lines, Callable(self, "_on_intro_finished"))
	_intro_watchdog()

## Страховка: если окно диалога по какой-то причине не появилось, не оставляем игрока на пустом экране.
func _intro_watchdog() -> void:
	await get_tree().create_timer(0.7).timeout
	if not _intro_waiting or not is_inside_tree():
		return
	var overlay = DialogueManager_._overlay
	if overlay == null or not is_instance_valid(overlay) or not overlay.visible:
		push_warning("EventScreen: диалог не показан, пропускаю вступление")
		_on_intro_finished()

func _on_intro_finished() -> void:
	if not is_inside_tree() or not _intro_waiting:
		return   ## уже обработано (диалог и страховка не должны сработать дважды)
	_intro_waiting = false
	if not _intro.is_empty() and StoryDialogueDB_ != null:
		var dialogue_id := String(_intro.get("id", ""))
		if dialogue_id != "" and StoryState_ != null:
			StoryState_.mark_dialogue_seen(dialogue_id)
		StoryDialogueDB_.apply_effects(_intro.get("on_finish", {}))
	_intro = {}
	_rebuild()

func _set_controls_visible(on: bool) -> void:
	for c in [_title, _desc, _options, _cards, _continue, _shade]:
		c.visible = on

# --- Общее -------------------------------------------------------------------

func _make_full_texture() -> TextureRect:
	var t := TextureRect.new()
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _event_enum() -> int:
	match String(room.get("event", "")):
		"shop": return RoomParams.EventType.SHOP
		"nurse": return RoomParams.EventType.NURSE
		"chest": return RoomParams.EventType.CHEST
		"statue": return RoomParams.EventType.STATUE
	return RoomParams.EventType.NONE

func _variant_enum() -> int:
	match String(room.get("variant", "")):
		"white": return RoomParams.StatueVariant.WHITE
		"black": return RoomParams.StatueVariant.BLACK
	return RoomParams.StatueVariant.NONE

func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()

func _say(text: String) -> void:
	_desc.text = text

func _gold() -> int:
	return int(battle.call("run_gold"))

func _add_option(text: String, callback: Callable, disabled: bool = false) -> Button:
	var b := RunUiKit.make_button(text, Vector2(0, 80), 30)
	b.disabled = disabled
	b.pressed.connect(callback)
	_options.add_child(b)
	return b

## panel=true: лавка/медсестра (текст на нарисованной панели фона), иначе — текст на затемнении слева.
func _apply_layout(panel: bool) -> void:
	_shade.visible = not panel
	_title.position = PANEL_TITLE_RECT.position if panel else TITLE_RECT.position
	_title.size = PANEL_TITLE_RECT.size if panel else TITLE_RECT.size
	_desc.position = PANEL_DESC_RECT.position if panel else DESC_RECT.position
	_desc.size = PANEL_DESC_RECT.size if panel else DESC_RECT.size
	_options.position = PANEL_OPTIONS_RECT.position if panel else OPTIONS_RECT.position
	_options.size = PANEL_OPTIONS_RECT.size if panel else OPTIONS_RECT.size
	_cards.position = PANEL_CARDS_POS
	_continue.position = PANEL_CONTINUE_POS if panel else CONTINUE_RECT.position
	var outline := 0 if panel else 8
	_title.add_theme_color_override("font_color", PANEL_TITLE if panel else RunUiKit.GOLD)
	_desc.add_theme_color_override("font_color", PANEL_TEXT if panel else Color.WHITE)
	_title.add_theme_constant_override("outline_size", outline)
	_desc.add_theme_constant_override("outline_size", outline)
	if panel:
		_gold_label.position = COIN_TEXT_POS
		_gold_label.text = "%d" % _gold()
	else:
		_gold_label.position = Vector2(24, 22)
		_gold_label.text = "Золото: %d" % _gold()

func _rebuild() -> void:
	_chest_waiting = false
	_desc.position = DESC_RECT.position
	_desc.size = DESC_RECT.size
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_set_controls_visible(true)
	_clear(_options)
	_clear(_cards)
	battle.call("refresh_run_hud")
	var event_id := String(room.get("event", ""))
	_apply_layout(event_id == "shop" or event_id == "nurse")
	_title.text = String(TITLES.get(event_id, CardRun.event_name(event_id, String(room.get("variant", "")))))
	_title.visible = true
	_chest_pic.visible = false
	_npc.texture = null
	_continue.text = "ИДТИ ДАЛЬШЕ"
	_continue.visible = true
	_continue.disabled = _image_open
	match event_id:
		"shop": _build_shop()
		"nurse": _build_nurse()
		"chest": _build_chest()
		"statue": _build_statue()

# --- Лавка Сессилии ---------------------------------------------------------

func _build_shop() -> void:
	_desc.text = "Сессилия раскладывает товар: дороже, чем у Рикки, зато наборами и с редкими находками."
	for offer in battle.call("run_lamia_stock", room):
		_add_offer(offer)

func _add_offer(offer: Dictionary) -> void:
	var id := String(offer["id"])
	var count := int(offer.get("count", 1))
	var sold := bool(offer.get("sold", false))
	var label := RunItems.get_item_name(id) + (" ×%d" % count if count > 1 else "")
	var text := ("%s — продано" % label) if sold else ("%s — %d зол." % [label, int(offer["price"])])
	var b := _add_option(text, func() -> void: _on_buy(offer), sold or _gold() < int(offer["price"]))
	b.icon = Inventory_.get_item_icon(id) if Inventory_ != null else null
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 64)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 84)
	b.tooltip_text = "%s [%s]\n%s" % [RunItems.get_item_name(id), RunItems.get_item_kind_label(id), RunItems.get_item_desc(id)]

func _on_buy(offer: Dictionary) -> void:
	if not bool(battle.call("run_buy_offer", offer)):
		_say("Не хватает золота.")
		return
	_rebuild()
	_say("Куплено: %s." % RunItems.get_item_name(String(offer["id"])))

# --- Медсестра Ноктрис -------------------------------------------------------

func _build_nurse() -> void:
	var used := bool(room.get("used", false))
	if used:
		_desc.text = "Ноктрис уже помогла отряду. Одна услуга за визит."
		return
	_desc.text = "Ноктрис окажет одну услугу на выбор."
	var gold := _gold()
	_add_option("Вылечить героиню на %d%% HP — %d зол." % [int(NURSE_HEAL_PERCENT * 100.0), NURSE_HEAL_PRICE], func() -> void: _pick_hero(false), not bool(battle.call("run_has_wounded")) or gold < NURSE_HEAL_PRICE)
	_add_option("Воскресить героиню с %d%% HP — %d зол." % [int(NURSE_REVIVE_PERCENT * 100.0), NURSE_REVIVE_PRICE], func() -> void: _pick_hero(true), not bool(battle.call("run_has_dead")) or gold < NURSE_REVIVE_PRICE)

## Выбор героини для лечения или воскрешения.
func _pick_hero(revive: bool) -> void:
	_clear(_options)
	_desc.text = "Кого воскресить?" if revive else "Кого вылечить?"
	for h in battle.call("run_heroes"):
		var d: Dictionary = h
		var ok_target := bool(d["dead"]) if revive else (not bool(d["dead"]) and int(d["hp"]) < int(d["max_hp"]))
		var label := "%s — %s" % [String(d["name"]), "пала" if bool(d["dead"]) else "%d/%d HP" % [int(d["hp"]), int(d["max_hp"])]]
		var hero_id := String(d["id"])
		var hero_name := String(d["name"])
		_add_option(label, func() -> void: _on_nurse_target(hero_id, hero_name, revive), not ok_target)
	_add_option("Назад", _rebuild)

func _on_nurse_target(hero_id: String, hero_name: String, revive: bool) -> void:
	if not bool(battle.call("run_spend_gold", NURSE_REVIVE_PRICE if revive else NURSE_HEAL_PRICE)):
		_say("Не хватает золота.")
		return
	if revive:
		battle.call("run_revive_hero", hero_id, NURSE_REVIVE_PERCENT)
	else:
		battle.call("run_heal_hero", hero_id, NURSE_HEAL_PERCENT)
	room["used"] = true
	_rebuild()
	_say(("%s снова на ногах." if revive else "Ноктрис подлатала: %s.") % hero_name)
	_show_choice_image("nurse_revive" if revive else "nurse_heal")
## Полноэкранная картинка услуги (как в старом забеге): клик закрывает.
func _show_choice_image(key: String) -> void:
	if AssetCatalog_ == null:
		return
	var tex: Texture2D = AssetCatalog_.get_event_choice_texture(key)
	if tex == null:
		return
	_image_open = true
	_continue.disabled = true
	var img := _make_full_texture()
	img.texture = tex
	img.mouse_filter = Control.MOUSE_FILTER_STOP
	img.z_index = 50
	img.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_image_open = false
			_continue.disabled = false
			img.queue_free()
	)
	add_child(img)

# --- Сундук ------------------------------------------------------------------

func _build_chest() -> void:
	var opened := bool(room.get("used", false))
	_set_chest_picture(opened)
	_shade.visible = false
	_title.visible = false
	_continue.visible = opened
	_continue.position = Vector2(760, CONTINUE_RECT.position.y)
	_place_chest_text()
	if opened:
		_desc.text = String(room.get("chest_text", "Сундук уже открыт."))
		return
	_chest_waiting = true
	_desc.text = "Нажмите на экран, чтобы открыть сундук."

func _place_chest_text() -> void:
	_desc.position = Vector2(220, 720)
	_desc.size = Vector2(1480, 200)
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _set_chest_picture(opened: bool) -> void:
	if AssetCatalog_ != null:
		_chest_pic.texture = AssetCatalog_.get_event_npc_texture("opened_chest" if opened else "chest")
	_chest_pic.visible = _chest_pic.texture != null

func _gui_input(event: InputEvent) -> void:
	if not _chest_waiting or _image_open:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_chest_open()
		accept_event()

func _on_chest_open() -> void:
	if bool(room.get("used", false)):
		return
	room["used"] = true
	room["chest_text"] = String(battle.call("run_roll_chest", room))
	_rebuild()

# --- Статуя ------------------------------------------------------------------

func _build_statue() -> void:
	var white := String(room.get("variant", "")) == "white"
	if AssetCatalog_ != null:
		_npc.texture = AssetCatalog_.get_event_npc_texture("statue_white" if white else "statue_black")
	if white:
		_desc.text = "Белая статуя. На %d боевые комнаты: +1 энергия в первые 2 хода боя, после каждой победы отряд лечится на 10%% макс. HP." % CardRelics.STATUE_ROOMS
	else:
		_desc.text = "Чёрная статуя. На %d боевые комнаты: +1 карта в первые 2 хода боя, урон карт +20%%." % CardRelics.STATUE_ROOMS
	_add_option("Принять дар", _on_statue_take, bool(room.get("used", false)))

func _on_statue_take() -> void:
	if bool(room.get("used", false)):
		return
	room["used"] = true
	battle.call("run_take_statue", String(room.get("variant", "")))
	_rebuild()
	_say("Дар принят.")
