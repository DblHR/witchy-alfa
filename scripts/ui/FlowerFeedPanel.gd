extends Control
class_name FlowerFeedPanel
## Окно кормления цветка Рикки — на панельке, которую Рикка держит в руках (rikka_with_flower.png):
## инвентарь, клик по предмету — скормить 1 шт., правый клик — всю стопку; Рикка доплачивает золотом
## (RunItems.get_flower_pay). «Откатить» — вернуть последнее скормленное (и отдать золото обратно).
## Квестовые предметы и рецепты не едятся. Само окно прозрачное — фон рисует картинка Рикки.

signal fed(item_id: String, amount: int, gold: int)
signal close_requested

## Тёмная панелька на картинке Рикки (экран 1920×1080: x 1183-1801, y 415-1000), с отступом внутрь.
const RECT := Rect2(1198, 426, 590, 562)
const COLUMNS := 4
const SLOT := Vector2(128, 146)
const SLOT_GAP := 12
const FADE := 0.22
const TITLE_COLOR := Color(1.0, 0.80, 0.92)
const TEXT_COLOR := Color(0.97, 0.91, 0.95)
const PRICE_COLOR := Color(1.0, 0.86, 0.42)

var _title: Label
var _hint: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _undo_btn: Button
var _close_btn: Button
var _fade: Tween
## Что скормлено за этот заход в лавку: [{id, n, gold}] — для «Откатить».
var _history: Array = []

static func _light_label(font_px: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _init() -> void:
	name = "FlowerFeedPanel"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP

	_title = _light_label(36, TITLE_COLOR)
	_title.position = Vector2(8, 0)
	_title.size = Vector2(RECT.size.x - 16, 48)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.clip_text = true
	add_child(_title)

	_hint = _light_label(17, Color(TEXT_COLOR, 0.75))
	_hint.position = Vector2(8, 48)
	_hint.size = Vector2(RECT.size.x - 16, 48)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.text = "ЛКМ — скормить 1 шт., ПКМ — всю стопку"
	add_child(_hint)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(8, 104)
	_scroll.size = Vector2(RECT.size.x - 10, 318)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	_scroll.add_child(_grid)

	_status = _light_label(20, TEXT_COLOR)
	_status.position = Vector2(8, 430)
	_status.size = Vector2(RECT.size.x - 16, 34)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.clip_text = true
	add_child(_status)

	_undo_btn = Button.new()
	_undo_btn.text = "↶  Откатить"
	_undo_btn.position = Vector2(8, 482)
	_undo_btn.size = Vector2(250, 58)
	ShopUi.style_button(_undo_btn, 24)
	_undo_btn.pressed.connect(undo)
	add_child(_undo_btn)

	_close_btn = Button.new()
	_close_btn.text = "К лавке"
	_close_btn.position = Vector2(RECT.size.x - 8 - 210, 482)
	_close_btn.size = Vector2(210, 58)
	ShopUi.style_button(_close_btn, 24)
	_close_btn.pressed.connect(func() -> void: close_requested.emit())
	add_child(_close_btn)
	visible = false

func _ready() -> void:
	if Inventory_ != null:
		Inventory_.changed.connect(_on_inventory_changed)

func _exit_tree() -> void:
	if Inventory_ != null and Inventory_.changed.is_connected(_on_inventory_changed):
		Inventory_.changed.disconnect(_on_inventory_changed)

func open() -> void:
	_status.text = ""
	refresh()
	_fade_to(true)

func close() -> void:
	_fade_to(false)

## Открыто (или открывается), а не закрывается.
func is_open() -> bool:
	return visible and not _closing

var _closing := false

func _fade_to(on: bool, delay: float = 0.0) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_closing = not on
	if on:
		visible = true
	_fade = create_tween()
	if delay > 0.0:
		_fade.tween_interval(delay)
	_fade.tween_property(self, "modulate:a", 1.0 if on else 0.0, FADE)
	if not on:
		_fade.tween_callback(func() -> void: visible = false)

## Появиться с задержкой (пока Рикка меняется на картинку с панелькой).
func open_after(delay: float) -> void:
	_status.text = ""
	refresh()
	modulate.a = 0.0
	visible = true
	_fade_to(true, delay)

func _on_inventory_changed() -> void:
	if visible:
		refresh()

func refresh() -> void:
	_title.text = "Покормить: %s" % RikkaFlower.flower_name()
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var any := false
	if Inventory_ != null:
		for e in Inventory_.get_sorted_item_entries():
			var id := String(e.get("id", ""))
			var n := int(e.get("count", 0))
			if n <= 0 or not RunItems.can_feed_flower(id):
				continue
			_grid.add_child(_make_slot(id, n, e.get("icon") as Texture2D))
			any = true
	if not any:
		var empty := _light_label(22, TEXT_COLOR)
		empty.text = "Нечем кормить: в сумке нет подходящих вещей."
		_grid.add_child(empty)
	_undo_btn.disabled = _history.is_empty()
	_undo_btn.tooltip_text = "" if _history.is_empty() else "Вернуть: %s ×%d (−%d зол.)" % [
		RunItems.get_item_name(String(_history[-1]["id"])), int(_history[-1]["n"]), int(_history[-1]["gold"])]

func _make_slot(id: String, count: int, icon: Texture2D) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT
	b.focus_mode = Control.FOCUS_NONE
	b.button_mask = MOUSE_BUTTON_MASK_LEFT   ## правый клик (вся стопка) — в gui_input
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(1, 1, 1, 0.07) if st == "normal" else (Color(1.0, 0.75, 0.9, 0.20) if st == "hover" else Color(1, 1, 1, 0.12))
		sb.set_border_width_all(2 if st == "hover" else 1)
		sb.border_color = Color(1.0, 0.78, 0.92, 0.55 if st == "hover" else 0.18)
		sb.set_corner_radius_all(14)
		b.add_theme_stylebox_override(st, sb)
	var pay := RunItems.get_flower_pay(id)
	b.tooltip_text = "%s ×%d\n%s\nРикка доплатит: %d зол. за штуку" % [RunItems.get_item_name(id), count, RunItems.get_item_desc(id), pay]
	var pic := TextureRect.new()
	pic.texture = icon
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.position = Vector2(14, 10)
	pic.size = Vector2(SLOT.x - 28, 92)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	var cnt := Label.new()
	cnt.text = "×%d" % count
	cnt.position = Vector2(0, 4)
	cnt.size = Vector2(SLOT.x - 8, 30)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cnt.add_theme_font_size_override("font_size", 22)
	cnt.add_theme_color_override("font_color", TEXT_COLOR)
	b.add_child(cnt)
	var price := Label.new()
	price.text = "+%d зол." % pay
	price.position = Vector2(0, SLOT.y - 42)
	price.size = Vector2(SLOT.x, 36)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_size_override("font_size", 22)
	price.add_theme_color_override("font_color", PRICE_COLOR)
	b.add_child(price)
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			b.accept_event()
			feed(id, Inventory_.get_item_count(id)))
	b.pressed.connect(func() -> void: feed(id, 1))
	return b

## Скормить n штук предмета: предмет пропадает, Рикка платит.
func feed(id: String, n: int) -> void:
	if Inventory_ == null or n <= 0 or not RunItems.can_feed_flower(id):
		return
	n = mini(n, Inventory_.get_item_count(id))
	if n <= 0 or not Inventory_.remove_item(id, n):
		return
	var gold := RunItems.get_flower_pay(id) * n
	DungRun.gain_gold(gold)
	DungRun.sync_legacy_owned_artifacts_to_inventory()
	_history.append({"id": id, "n": n, "gold": gold})
	_status.text = "%s съел: %s ×%d  (+%d зол.)" % [RikkaFlower.flower_name(), RunItems.get_item_name(id), n, gold]
	fed.emit(id, n, gold)
	refresh()

## Вернуть последнее скормленное (золото забирается обратно).
func undo() -> void:
	if _history.is_empty():
		return
	var last: Dictionary = _history[-1]
	var gold := int(last["gold"])
	if DungRun.gold < gold:
		_status.text = "Не хватает золота, чтобы откатить (нужно %d)." % gold
		return
	_history.pop_back()
	DungRun.spend_gold(gold)
	Inventory_.add_item(String(last["id"]), int(last["n"]))
	DungRun.sync_legacy_owned_artifacts_to_inventory()
	_status.text = "Возвращено: %s ×%d  (−%d зол.)" % [RunItems.get_item_name(String(last["id"])), int(last["n"]), gold]
	refresh()

func history_size() -> int:
	return _history.size()
