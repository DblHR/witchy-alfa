extends Control
class_name CardPilePopup
## Окно просмотра стопки карт (колода, сброс, сгоревшие). Закрывается кликом мимо или кнопкой.

var _title: Label
var _flow: HFlowContainer

func _init() -> void:
	name = "PilePopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	z_index = 50

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
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
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Отступы, чтобы значки цены на краях карт не обрезались областью прокрутки.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)

	_flow = HFlowContainer.new()
	_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_flow.add_theme_constant_override("h_separation", 14)
	_flow.add_theme_constant_override("v_separation", 14)
	margin.add_child(_flow)

	var close_btn := Button.new()
	close_btn.text = "Закрыть"
	close_btn.custom_minimum_size = Vector2(0, 52)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)

## Показывает стопку. extra — дополнительный раздел ниже (например, «Сгорело до конца боя»).
func open(title: String, cards: Array[CardInstance], extra_title: String = "", extra: Array[CardInstance] = []) -> void:
	_title.text = "%s: %d" % [title, cards.size()]
	for c in _flow.get_children():
		_flow.remove_child(c)
		c.queue_free()

	if cards.is_empty() and extra.is_empty():
		_flow.add_child(_make_label("Пусто", 24))
	else:
		_add_cards(cards)
	if not extra.is_empty():
		var header := _make_label("%s: %d" % [extra_title, extra.size()], 24)
		header.custom_minimum_size = Vector2(1000, 40)
		header.add_theme_color_override("font_color", Color(1.0, 0.7, 0.35))
		_flow.add_child(header)
		_add_cards(extra)
	visible = true

func close() -> void:
	visible = false

## Сортируем по владельцу и названию, чтобы не выдавать порядок добора.
func _add_cards(cards: Array[CardInstance]) -> void:
	var sorted: Array[CardInstance] = cards.duplicate()
	sorted.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return (a.owner_id + a.title) < (b.owner_id + b.title)
	)
	for card in sorted:
		var view := CardView.new()
		view.setup(card, false)
		_flow.add_child(view)

static func _make_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	return l
