extends Control
class_name CardBuffBar
## Строка под золотом и эстусом (слева сверху): два слота зелий и иконки баффов забега
## (посох, еда, статуи, выпитый Фиал ярости). Наведение — всплывашка с описанием и статистикой
## за забег, клик по зелью — выпить. Что показывать, решает CardBattle (set_entries).
##
## Запись: {key, icon: Texture2D, title, desc, stats, badge, potion: bool, empty: bool}

signal entry_pressed(key: String)

const ICON := Vector2(58, 58)
const GAP := 8
const POTION_BG := Color(0.22, 0.12, 0.30, 0.85)
const BUFF_BG := Color(0.10, 0.05, 0.14, 0.78)
const BORDER := Color(1.0, 0.85, 0.55, 0.55)
const TIP_WIDTH := 420.0

var _row: HBoxContainer
var _tip: PanelContainer
var _tip_title: Label
var _tip_body: Label
var _tip_stats: Label

func _init() -> void:
	name = "BuffBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", GAP)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)

	_tip = PanelContainer.new()
	_tip.visible = false
	_tip.z_index = 80
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.04, 0.12, 0.96)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = BORDER
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_tip.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(box)
	_tip_title = _tip_label(22, Color(1.0, 0.88, 0.5))
	box.add_child(_tip_title)
	_tip_body = _tip_label(18, Color.WHITE)
	box.add_child(_tip_body)
	_tip_stats = _tip_label(16, Color(0.75, 0.9, 1.0))
	box.add_child(_tip_stats)
	add_child(_tip)

func _tip_label(size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(TIP_WIDTH, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l

func set_entries(entries: Array) -> void:
	for c in _row.get_children():
		_row.remove_child(c)
		c.queue_free()
	var potions_done := false
	for e in entries:
		var d: Dictionary = e
		if not bool(d.get("potion", false)) and not potions_done:
			potions_done = true
			if _row.get_child_count() > 0:
				var sep := Control.new()
				sep.custom_minimum_size = Vector2(10, ICON.y)
				sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
				_row.add_child(sep)
		_row.add_child(_make_slot(d))
	_tip.visible = false

func _make_slot(d: Dictionary) -> Control:
	var potion := bool(d.get("potion", false))
	var empty := bool(d.get("empty", false))
	var slot := Panel.new()
	slot.custom_minimum_size = ICON
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	if potion and not empty:
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var sb := StyleBoxFlat.new()
	sb.bg_color = POTION_BG if potion else BUFF_BG
	sb.set_corner_radius_all(int(ICON.x * 0.5) if potion else 12)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.18) if empty else BORDER
	slot.add_theme_stylebox_override("panel", sb)
	var tex: Texture2D = d.get("icon")
	if tex != null and not empty:
		var icon := TextureRect.new()
		# Режим растягивания — до размера, иначе TextureRect раздуется до размера картинки.
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = tex
		icon.position = Vector2(5, 5)
		icon.size = ICON - Vector2(10, 10)
		icon.clip_contents = true
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
	var badge := String(d.get("badge", ""))
	if badge != "":
		var b := Label.new()
		b.text = badge
		b.position = Vector2(ICON.x - 26, ICON.y - 26)
		b.size = Vector2(24, 24)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		b.add_theme_constant_override("outline_size", 5)
		slot.add_child(b)
	slot.mouse_entered.connect(func() -> void: _show_tip(slot, d))
	slot.mouse_exited.connect(func() -> void: _tip.visible = false)
	var key := String(d.get("key", ""))
	slot.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			entry_pressed.emit(key)
	)
	return slot

func _show_tip(slot: Control, d: Dictionary) -> void:
	_tip_title.text = String(d.get("title", ""))
	_tip_body.text = String(d.get("desc", ""))
	var stats := String(d.get("stats", ""))
	_tip_stats.text = stats
	_tip_stats.visible = stats != ""
	_tip.reset_size()
	_tip.position = Vector2(slot.position.x, ICON.y + 10)
	_tip.visible = true
