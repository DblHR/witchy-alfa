extends Control
class_name DeckEditorPopup
## Окно выбора карт героини для колоды (экран Setup). Клик по карте — убрать из колоды или
## вернуть. Не больше лимита ранга и хотя бы одна карта. Выбор сразу сохраняется в
## UnitRoster_.deck_selection. Ниже — ещё не полученные карты (только посмотреть).

const OUT_ALPHA := 0.38
const CARD_ZOOM := 1.15

var _data: CharacterData
var _unit: Unit
var _title: Label
var _hint: Label
var _grid: GridContainer
var _locked_title: Label
var _locked_grid: GridContainer
var _chosen: Array[String] = []

func _init() -> void:
	name = "DeckEditor"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 60

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close()
	)
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
	sb.content_margin_top = 20
	sb.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	box.add_child(_title)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	box.add_child(_hint)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1120, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	inner.add_child(margin)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(_grid)
	_locked_title = Label.new()
	_locked_title.text = "Можно получить — за отношения"
	_locked_title.add_theme_font_size_override("font_size", 20)
	_locked_title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	inner.add_child(_locked_title)
	var margin2 := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin2.add_theme_constant_override("margin_" + side, 14)
	inner.add_child(margin2)
	_locked_grid = GridContainer.new()
	_locked_grid.columns = 6
	_locked_grid.add_theme_constant_override("h_separation", 14)
	margin2.add_child(_locked_grid)

	var close_btn := Button.new()
	close_btn.text = "Готово"
	close_btn.custom_minimum_size = Vector2(0, 52)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(close)
	box.add_child(close_btn)

func open_for(unit_id: String) -> void:
	_data = CharDB.get_by_id(unit_id)
	if _data == null:
		return
	_unit = Unit.new(_data, maxi(1, int(DungRun.party_level)))
	_chosen.clear()
	for d in CardLibrary.deck_defs(_data):
		_chosen.append(d.id)
	_rebuild()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	global_position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true

func close() -> void:
	visible = false

func _rebuild() -> void:
	for grid in [_grid, _locked_grid]:
		for c in grid.get_children():
			grid.remove_child(c)
			c.queue_free()
	var cap := _data.card_cap()
	_title.text = "%s — колода %d/%d" % [_data.display_name, _chosen.size(), cap]
	_hint.text = "Нажмите на карту, чтобы убрать её из колоды или вернуть (ранг %s: до %d карт)" % [_data.rank, cap]
	_hint.remove_theme_color_override("font_color")
	var locked := 0
	for c in CardLibrary.hero_pool(_unit):
		var holder := RunUiKit.card_preview(c, CARD_ZOOM)
		if c.locked:
			_locked_grid.add_child(holder)
			locked += 1
			continue
		var in_deck := _chosen.has(c.id)
		holder.mouse_filter = Control.MOUSE_FILTER_STOP
		holder.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		holder.modulate = Color(1, 1, 1, 1.0 if in_deck else OUT_ALPHA)
		if not in_deck:
			var tag := Label.new()
			tag.text = "Не в колоде"
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag.position = Vector2(0, CardView.CARD_SIZE.y * CARD_ZOOM * 0.5 - 16)
			tag.size = Vector2(CardView.CARD_SIZE.x * CARD_ZOOM, 32)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag.add_theme_font_size_override("font_size", 20)
			tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
			tag.add_theme_constant_override("outline_size", 6)
			holder.add_child(tag)
		var card_id := c.id
		holder.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_toggle(card_id)
		)
		_grid.add_child(holder)
	_locked_title.visible = locked > 0
	_locked_grid.visible = locked > 0

func _toggle(card_id: String) -> void:
	var cap := _data.card_cap()
	if _chosen.has(card_id):
		if _chosen.size() <= 1:
			_warn("В колоде должна остаться хотя бы одна карта")
			return
		_chosen.erase(card_id)
	else:
		if _chosen.size() >= cap:
			_warn("Колода заполнена: сначала уберите другую карту")
			return
		_chosen.append(card_id)
	UnitRoster_.set_deck_selection(_data.id, _chosen)
	_rebuild()

func _warn(text: String) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
