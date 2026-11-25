extends Control
class_name InteractionMenu
## Всплывающее меню сексуальных взаимодействий (Interactions, kind "lewd") — кнопка SEX на экране
## отношений. (Несексуальные — в окне диалога, VN: см. Interactions.menu_lines / DialogueOverlay.)
## Открывается возле точки anchor; клик мимо или Esc — закрыть.
## Строка действия: «Обнимашки  +5♥»; закрытое — «с 2 ур.», сделанное сегодня — «завтра».
##
## open(...) возвращает меню; выбор — сигнал chosen(action_id) (у доп. пунктов — их callback).

signal chosen(action_id: String)
signal closed

const PANEL_W := 420.0
const ROW_H := 54.0
const COLOR_TEXT := Color(0.33, 0.16, 0.38)
const COLOR_PANEL := Color(0.99, 0.95, 0.9, 0.97)
const COLOR_BORDER := Color(0.62, 0.3, 0.6)
const COLOR_BTN := Color(0.45, 0.22, 0.47)
const COLOR_BTN_HOVER := Color(0.6, 0.3, 0.6)
const COLOR_BTN_OFF := Color(0.72, 0.64, 0.7)

var char_id := ""
var kind := Interactions.KIND_CUTE
var _panel: PanelContainer

## extra: доп. пункты сверху — [{"title": "Поговорить", "callback": Callable, "badge": true}].
static func open(parent: Node, p_char_id: String, p_kind: String, anchor: Vector2, extra: Array = []) -> InteractionMenu:
	var m := InteractionMenu.new()
	m.char_id = p_char_id
	m.kind = p_kind
	m.name = "InteractionMenu"
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_STOP
	m.z_index = 60
	parent.add_child(m)
	m._build(anchor, extra)
	EscClose.register(m, m.close)
	return m

func close() -> void:
	if is_queued_for_deletion():
		return
	closed.emit()
	queue_free()

func _gui_input(event: InputEvent) -> void:
	# Клик мимо меню — закрыть.
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		close()

func _build(anchor: Vector2, extra: Array) -> void:
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = COLOR_BORDER
	sb.shadow_color = Color(0.2, 0.05, 0.2, 0.3)
	sb.shadow_size = 10
	sb.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.custom_minimum_size.x = PANEL_W
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	var head := Label.new()
	head.text = _header_text()
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", COLOR_TEXT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(head)
	for e in extra:
		var cb: Callable = e.get("callback", Callable())
		var b := _row(String(e.get("title", "")), "", true)
		if bool(e.get("badge", false)):
			b.text += "  !"
		b.pressed.connect(func() -> void:
			close()
			if cb.is_valid():
				cb.call())
		box.add_child(b)
	for a in Interactions.actions(kind):
		var id := String(a["id"])
		var st := Interactions.state(char_id, id)
		var right := "+%d ♥" % int(a.get("trust", 0))
		match st:
			Interactions.State.LOCKED:
				right = "с %d ур." % int(a.get("unlock", 0))
			Interactions.State.USED_TODAY:
				right = ""   ## можно ещё раз, но доверие — только завтра
			Interactions.State.NIGHT_ONLY:
				right = "ночью"
		var b := _row(String(a.get("title", id)), right, Interactions.can_do(char_id, id))
		b.name = "Action_" + id
		b.pressed.connect(func() -> void:
			close()
			chosen.emit(id))
		box.add_child(b)
	# Рядом с точкой, но в пределах экрана.
	_panel.reset_size()
	var vp := get_viewport_rect().size
	var p := anchor - Vector2(_panel.size.x * 0.5, _panel.size.y + 10.0)
	p.x = clampf(p.x, 10.0, vp.x - _panel.size.x - 10.0)
	p.y = clampf(p.y, 10.0, vp.y - _panel.size.y - 10.0)
	_panel.position = p
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_panel, "modulate:a", 1.0, 0.12)

func _header_text() -> String:
	var who := StoryDialogueDB_.get_character_name(char_id) if StoryDialogueDB_ != null else char_id
	var lvl := Interactions.level(char_id)
	if NpcTrust.is_npc(char_id):
		var pr := NpcTrust.progress(char_id)
		if lvl >= NpcTrust.MAX_LEVEL:
			return "%s · доверие %d/%d" % [who, lvl, NpcTrust.MAX_LEVEL]
		return "%s · доверие %d/%d (ещё %d)" % [who, lvl, NpcTrust.MAX_LEVEL, int(pr["need"]) - int(pr["into_level"])]
	return "%s · доверие %d ур." % [who, lvl]

func _row(text: String, right: String, enabled: bool) -> Button:
	var b := Button.new()
	b.text = text if right == "" else "%s   %s" % [text, right]
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	b.add_theme_font_size_override("font_size", 22)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(14)
		s.set_content_margin_all(8)
		s.bg_color = COLOR_BTN_OFF if st == "disabled" else (COLOR_BTN_HOVER if st == "hover" else COLOR_BTN)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", Color(1, 0.96, 0.99))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	return b

## Всплывающая надпись (поднимается и тает).
static func float_text(host: Node, at: Vector2, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", Color(1.0, 0.55, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.25))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.z_index = 70
	host.add_child(l)
	l.reset_size()
	l.position = at - Vector2(l.size.x * 0.5, l.size.y)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 90.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.9)
	t.chain().tween_callback(l.queue_free)
