extends Panel
class_name FlowerFeedPanel
## Окно кормления цветка Рикки (справа, на месте Рикки): инвентарь, клик по предмету — скормить 1 шт.,
## правый клик — всю стопку; Рикка доплачивает золотом (RunItems.get_flower_pay). «Откатить» —
## вернуть последнее скормленное (и отдать золото обратно). Квестовые предметы и рецепты не едятся.

signal fed(item_id: String, amount: int, gold: int)

const RECT := Rect2(1172, 104, 716, 912)
const COLUMNS := 5
const SLOT := Vector2(122, 150)
const SLOT_GAP := 12

var _title: Label
var _hint: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _status: Label
var _undo_btn: Button
var _close_btn: Button
## Что скормлено за этот заход в лавку: [{id, n, gold}] — для «Откатить».
var _history: Array = []

func _init() -> void:
	name = "FlowerFeedPanel"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.96, 0.90, 0.98)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.31, 0.15, 0.25)
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 12
	add_theme_stylebox_override("panel", sb)

	_title = Label.new()
	_title.position = Vector2(34, 22)
	_title.size = Vector2(RECT.size.x - 68, 64)
	ShopUi.style_title(_title)
	_title.add_theme_font_size_override("font_size", 46)
	_title.clip_text = true
	add_child(_title)

	_hint = Label.new()
	_hint.position = Vector2(34, 92)
	_hint.size = Vector2(RECT.size.x - 68, 70)
	ShopUi.style_text(_hint, 22)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.text = "Клик — скормить 1 шт., правый клик — всю стопку. Рикка доплачивает за корм."
	add_child(_hint)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(30, 170)
	_scroll.size = Vector2(RECT.size.x - 52, 600)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	_scroll.add_child(_grid)

	_status = Label.new()
	_status.position = Vector2(34, 780)
	_status.size = Vector2(RECT.size.x - 68, 40)
	ShopUi.style_text(_status, 22)
	_status.clip_text = true
	add_child(_status)

	_undo_btn = Button.new()
	_undo_btn.text = "↶  Откатить"
	_undo_btn.position = Vector2(34, 830)
	_undo_btn.size = Vector2(260, 60)
	ShopUi.style_button(_undo_btn, 26)
	_undo_btn.pressed.connect(undo)
	add_child(_undo_btn)

	_close_btn = Button.new()
	_close_btn.text = "Закрыть"
	_close_btn.position = Vector2(RECT.size.x - 34 - 220, 830)
	_close_btn.size = Vector2(220, 60)
	ShopUi.style_button(_close_btn, 26)
	_close_btn.pressed.connect(close)
	add_child(_close_btn)
	visible = false

func _ready() -> void:
	if Inventory_ != null:
		Inventory_.changed.connect(_on_inventory_changed)

func _exit_tree() -> void:
	if Inventory_ != null and Inventory_.changed.is_connected(_on_inventory_changed):
		Inventory_.changed.disconnect(_on_inventory_changed)

func open() -> void:
	visible = true
	_status.text = ""
	refresh()

func close() -> void:
	visible = false

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
		var empty := Label.new()
		empty.text = "Нечем кормить: в сумке нет подходящих вещей."
		ShopUi.style_text(empty, 24)
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
		sb.bg_color = Color(0.80, 0.70, 0.72, 0.55) if st == "normal" else (Color(0.86, 0.66, 0.74, 0.85) if st == "hover" else Color(0.72, 0.56, 0.62, 0.9))
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
	cnt.add_theme_color_override("font_color", ShopUi.TEXT_COLOR)
	b.add_child(cnt)
	var price := Label.new()
	price.text = "+%d зол." % pay
	price.position = Vector2(0, SLOT.y - 42)
	price.size = Vector2(SLOT.x, 36)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price.add_theme_font_size_override("font_size", 22)
	price.add_theme_color_override("font_color", ShopUi.TITLE_COLOR)
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
