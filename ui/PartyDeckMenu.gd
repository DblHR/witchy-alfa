extends Control
class_name PartyDeckMenu
## Меню «Колода» на экране подготовки: столбики — колоды персонажей отряда и общие карты.
## Клик по карте персонажа — взять в бой / не брать (не больше лимита ранга, хотя бы одна карта).
## Выбор сразу сохраняется (UnitRoster_.deck_selection). Ещё не открытые карты — внизу столбика,
## только посмотреть. Общие карты (и приманка, если её берём) — всегда в колоде.

const CARD_ZOOM := 0.86
const COLUMN_CARDS := 2            ## карт в ряд внутри столбика
const OUT_ALPHA := 0.35
const COLUMN_GAP := 26

var _title: Label
var _hint: Label
var _columns: HBoxContainer
var _focus_id := ""

func _init() -> void:
	name = "PartyDeckMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 60

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close())
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.08, 0.20, 0.97)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.56, 0.44, 0.60, 1.0)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	box.add_child(_title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	box.add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1500, 760)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)
	var cc := CenterContainer.new()
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cc)
	_columns = HBoxContainer.new()
	_columns.add_theme_constant_override("separation", COLUMN_GAP)
	_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(_columns)

	var close_btn := Button.new()
	close_btn.text = "Готово"
	close_btn.custom_minimum_size = Vector2(320, 56)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_btn.add_theme_font_size_override("font_size", 26)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	box.add_child(close_btn)

## Открыть; focus_id — чей столбик подсветить (клик по персонажу).
func open(focus_id: String = "") -> void:
	_focus_id = focus_id
	_rebuild()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	global_position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true

func close() -> void:
	visible = false

func _party() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in DungRun.party_ids:
		var d: CharacterData = CharDB.get_by_id(id) if id != "" else null
		if d != null:
			out.append(d)
	return out

func _rebuild(hint: String = "", warn: bool = false) -> void:
	for c in _columns.get_children():
		_columns.remove_child(c)
		c.queue_free()
	var total := 0
	for data in _party():
		total += _add_hero_column(data)
	total += _add_common_column()
	_title.text = "Колода на забег: %d карт" % total
	_hint.text = hint if hint != "" else "Нажмите на карту персонажа, чтобы взять её в бой или убрать"
	if warn:
		_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	else:
		_hint.remove_theme_color_override("font_color")

func _column(title: String, sub: String, highlight: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.06 if not highlight else 0.12)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2 if not highlight else 3)
	sb.border_color = Color(1, 0.8, 0.95, 0.25 if not highlight else 0.8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	_columns.add_child(panel)
	panel.add_child(col)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", Color(1.0, 0.82, 0.94))
	col.add_child(t)
	var s := Label.new()
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_font_size_override("font_size", 17)
	s.modulate = Color(1, 1, 1, 0.75)
	col.add_child(s)
	return col

func _grid(col: VBoxContainer) -> GridContainer:
	var g := GridContainer.new()
	g.columns = COLUMN_CARDS
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	col.add_child(g)
	return g

## Столбик персонажа. Возвращает, сколько его карт идёт в бой.
func _add_hero_column(data: CharacterData) -> int:
	var unit := Unit.new(data, maxi(1, int(DungRun.party_level)))
	var chosen: Array[String] = CardLibrary.deck_keys(data)
	var cap := data.card_cap()
	var col := _column(data.display_name, "в бой: %d / %d" % [chosen.size(), cap], data.id == _focus_id)
	var grid := _grid(col)
	var locked: Array[CardInstance] = []
	for c in CardLibrary.hero_pool(unit):
		if c.locked:
			locked.append(c)
			continue
		var holder := RunUiKit.card_preview(c, CARD_ZOOM)
		var in_deck := chosen.has(c.key)
		if CardLibrary.is_dupe_key(c.key):
			holder.add_child(RunUiKit.card_tag("Дубль", CARD_ZOOM))
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		holder.modulate = Color(1, 1, 1, 1.0 if in_deck else OUT_ALPHA)
		var key := c.key
		var id := data.id
		holder.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_toggle(id, key))
		grid.add_child(holder)
	if not locked.is_empty():
		var lt := Label.new()
		lt.text = "За отношения"
		lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lt.add_theme_font_size_override("font_size", 17)
		lt.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
		col.add_child(lt)
		var lg := _grid(col)
		for c in locked:
			var h := RunUiKit.card_preview(c, CARD_ZOOM)
			h.modulate = Color(1, 1, 1, 0.55)
			lg.add_child(h)
	return chosen.size()

## Общие карты: всегда в колоде (и приманка, если её берём в забег).
func _add_common_column() -> int:
	var col := _column("Общие", "всегда в колоде", false)
	var grid := _grid(col)
	var groups := [
		[CardLibrary.filler_cards(1, 0)[0], CardLibrary.FILLER_ATTACK_COUNT],
		[CardLibrary.filler_cards(0, 1)[0], CardLibrary.FILLER_SHIELD_COUNT],
	]
	var lures := Inventory_.get_item_count(DungRun.LURE_ITEM) if Inventory_ != null else 0
	if DungRun.take_lure and lures > 0:
		groups.append([CardLibrary.lure_card(), 1])
	var n := 0
	for g in groups:
		var holder := RunUiKit.card_preview(g[0], CARD_ZOOM)
		if int(g[1]) > 1:
			holder.add_child(RunUiKit.card_tag("×%d" % int(g[1]), CARD_ZOOM, Color(1.0, 0.8, 0.35)))
		grid.add_child(holder)
		n += int(g[1])
	return n

func _toggle(unit_id: String, key: String) -> void:
	var data: CharacterData = CharDB.get_by_id(unit_id)
	if data == null:
		return
	var chosen: Array[String] = CardLibrary.deck_keys(data)
	if chosen.has(key):
		if chosen.size() <= 1:
			_rebuild("В колоде персонажа должна остаться хотя бы одна карта", true)
			return
		chosen.erase(key)
	else:
		if chosen.size() >= data.card_cap():
			_rebuild("%s: колода заполнена (до %d карт) — сначала уберите другую" % [data.display_name, data.card_cap()], true)
			return
		chosen.append(key)
	UnitRoster_.set_deck_selection(unit_id, chosen)
	_focus_id = unit_id
	_rebuild()
