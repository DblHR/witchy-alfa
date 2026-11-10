extends Control
class_name DialogueOverlay
## Окно диалога (VN): портреты, плашка с именем, текст с «печатной машинкой», кнопки.
##
## Портреты ставятся по правилам VnPortraits (одна высота, голова у верхней линии, тело по центру
## места): говорящий — яркий и чуть крупнее, остальные притушены. Появление и уход — плавные.
## Клик / пробел / Enter: допечатать реплику, затем следующая. Кнопки: История, Авто, Пропустить,
## Скрыть (посмотреть на картинку; любой клик возвращает окно).
##
## Реплика — Dictionary (из StoryDialogueDB.resolve_lines): speaker, speaker_name, text,
## characters [{id, portrait, slot?}], active_character. Старые ресурсы DialogueLine тоже читаются.

signal sequence_finished

# --- Раскладка (экран 1920×1080; на широком экране кадр по центру) -----------
const FRAME := Vector2(1920, 1080)
const BOX_RECT := Rect2(110, 792, 1700, 250)
const TEXT_RECT := Rect2(170, 846, 1580, 170)
const NAME_POS := Vector2(150, 752)
const BUTTONS_RIGHT := 1800.0
const BUTTONS_Y := 738.0
const BUTTON_SIZE := Vector2(168, 46)
## Центры мест для 1, 2 и 3 персонажей.
const SLOT_X := {1: [960.0], 2: [480.0, 1440.0], 3: [340.0, 960.0, 1580.0]}
const SLOT_NAMES := {"left": 0, "center": 1, "right": 2}
## Когда на экране трое — все чуть мельче, чтобы не закрывали друг друга.
const SHRINK_FOR_THREE := 0.84

# --- Текст и поведение ---------------------------------------------------------
const TEXT_SIZE := 34
const NAME_SIZE := 30
const CHARS_PER_SEC := 70.0
const AUTO_BASE_DELAY := 1.1       ## пауза после допечатки в режиме «Авто»
const AUTO_PER_CHAR := 0.035
const DIM_INACTIVE := Color(0.58, 0.55, 0.64)
const INACTIVE_SCALE := 0.965
const FADE_TIME := 0.28

const BOX_BG := Color(0.11, 0.05, 0.15, 0.92)
const BOX_BORDER := Color(1.0, 0.80, 0.90, 0.55)
const BTN_BG := Color(0.24, 0.12, 0.30, 0.95)
const BTN_HOVER := Color(0.42, 0.20, 0.46, 1.0)
const BTN_ON := Color(0.80, 0.30, 0.56, 1.0)

@onready var blur_rect: ColorRect = %BlurRect

var _frame: Control          ## кадр 1920×1080
var _stage: Control          ## портреты
var _ui: Control             ## окно текста, имя, кнопки
var _box: Panel
var _name_plate: PanelContainer
var _name_label: Label
var _text: Label
var _arrow: Label
var _buttons: Dictionary = {}
var _history_panel: Control
var _history_text: RichTextLabel
var _hidden_hint: Label

var _lines: Array = []
var _index: int = -1
var _auto_mode := false
var _auto_token := 0         ## каждый новый запуск/отмена авто-таймера обесценивает старые таймеры
var _finished := false
var _history: Array = []     ## [[имя, цвет, текст]]
var _on_finished: Callable = Callable()
var _sequence_characters: Array = []
var _portraits: Dictionary = {}   ## id -> TextureRect
var _typing := false
var _shown := 0.0
var _ui_hidden := false
var _time := 0.0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_fit_frame)
	_fit_frame()

# --- Построение ---------------------------------------------------------------

func _build() -> void:
	_frame = Control.new()
	_frame.size = FRAME
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# Затемнение сцены под диалогом: портреты читаются на любом фоне.
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.02, 0.09, 0.5)
	dim.position = Vector2(-2000, -1000)
	dim.size = FRAME + Vector2(4000, 2000)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(dim)

	_stage = Control.new()
	_stage.size = FRAME
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_stage)

	# Мягкое затемнение снизу: портреты уходят в тень за окном текста.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.06, 0.02, 0.10, 0.0))
	grad.set_color(1, Color(0.06, 0.02, 0.10, 0.97))
	grad.add_point(0.55, Color(0.06, 0.02, 0.10, 0.93))   # низ портретов тонет в тени до края картинки
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2(-2000, 640)
	shade.size = Vector2(FRAME.x + 4000, 440)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(shade)

	_ui = Control.new()
	_ui.size = FRAME
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_ui)

	_box = Panel.new()
	_box.position = BOX_RECT.position
	_box.size = BOX_RECT.size
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BOX_BG
	sb.set_corner_radius_all(28)
	sb.set_border_width_all(2)
	sb.border_color = BOX_BORDER
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 14
	_box.add_theme_stylebox_override("panel", sb)
	_ui.add_child(_box)

	_text = Label.new()
	_text.position = TEXT_RECT.position
	_text.size = TEXT_RECT.size
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("font_size", TEXT_SIZE)
	_text.add_theme_constant_override("line_spacing", 8)
	_text.add_theme_color_override("font_color", Color(0.99, 0.97, 1.0))
	_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_text.add_theme_constant_override("shadow_offset_x", 0)
	_text.add_theme_constant_override("shadow_offset_y", 2)
	_text.add_theme_constant_override("outline_size", 0)
	_ui.add_child(_text)

	_name_plate = PanelContainer.new()
	_name_plate.position = NAME_POS
	_name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_name_plate)
	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", NAME_SIZE)
	_name_label.add_theme_color_override("font_color", Color.WHITE)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_plate.add_child(_name_label)

	_arrow = Label.new()
	_arrow.text = "▼"
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.add_theme_font_size_override("font_size", 26)
	_arrow.add_theme_color_override("font_color", Color(1.0, 0.82, 0.92))
	_arrow.position = Vector2(BOX_RECT.end.x - 62, BOX_RECT.end.y - 56)
	_ui.add_child(_arrow)

	var defs := [["skip", "Пропустить"], ["auto", "Авто"], ["log", "История"], ["hide", "Скрыть"]]
	var x := BUTTONS_RIGHT
	for d in defs:
		x -= BUTTON_SIZE.x
		var b := _make_button(String(d[1]))
		b.position = Vector2(x, BUTTONS_Y)
		_ui.add_child(b)
		_buttons[String(d[0])] = b
		x -= 10.0
	(_buttons["skip"] as Button).pressed.connect(_on_skip_pressed)
	(_buttons["auto"] as Button).pressed.connect(_on_auto_pressed)
	(_buttons["log"] as Button).pressed.connect(_on_log_pressed)
	(_buttons["hide"] as Button).pressed.connect(func() -> void: _set_ui_hidden(true))

	_hidden_hint = Label.new()
	_hidden_hint.text = "Клик — вернуть окно"
	_hidden_hint.visible = false
	_hidden_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hidden_hint.position = Vector2(FRAME.x - 330, FRAME.y - 54)
	_hidden_hint.add_theme_font_size_override("font_size", 22)
	_hidden_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_hidden_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hidden_hint.add_theme_constant_override("outline_size", 6)
	_frame.add_child(_hidden_hint)

	_build_history()

func _button_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(23)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.93, 0.6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	return sb

## Кнопка-пилюля: подсвечивается и чуть растёт под курсором, проседает при нажатии.
func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size = BUTTON_SIZE
	b.custom_minimum_size = BUTTON_SIZE
	b.pivot_offset = BUTTON_SIZE * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(1, 0.95, 0.98))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _button_style(BTN_BG))
	b.add_theme_stylebox_override("hover", _button_style(BTN_HOVER))
	b.add_theme_stylebox_override("pressed", _button_style(BTN_ON))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.mouse_entered.connect(func() -> void: _tween_scale(b, 1.07))
	b.mouse_exited.connect(func() -> void: _tween_scale(b, 1.0))
	b.button_down.connect(func() -> void: _tween_scale(b, 0.94))
	b.button_up.connect(func() -> void: _tween_scale(b, 1.07 if b.is_hovered() else 1.0))
	return b

func _tween_scale(c: Control, k: float) -> void:
	var t := c.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(c, "scale", Vector2.ONE * k, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _build_history() -> void:
	_history_panel = Control.new()
	_history_panel.visible = false
	_history_panel.size = FRAME
	_history_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.add_child(_history_panel)
	_history_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_history_panel.visible = false
	)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.01, 0.06, 0.7)
	dim.position = Vector2(-2000, -500)
	dim.size = FRAME + Vector2(4000, 1000)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history_panel.add_child(dim)
	var panel := Panel.new()
	panel.position = Vector2(260, 90)
	panel.size = Vector2(1400, 900)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.05, 0.14, 0.97)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(2)
	sb.border_color = BOX_BORDER
	panel.add_theme_stylebox_override("panel", sb)
	_history_panel.add_child(panel)
	var title := Label.new()
	title.text = "История"
	title.position = Vector2(44, 24)
	title.add_theme_font_size_override("font_size", 36)
	panel.add_child(title)
	var close := _make_button("Закрыть")
	close.position = Vector2(panel.size.x - BUTTON_SIZE.x - 36, 26)
	close.pressed.connect(func() -> void: _history_panel.visible = false)
	panel.add_child(close)
	_history_text = RichTextLabel.new()
	_history_text.bbcode_enabled = true
	_history_text.position = Vector2(44, 96)
	_history_text.size = Vector2(panel.size.x - 88, panel.size.y - 130)
	_history_text.scroll_following = true
	_history_text.add_theme_font_size_override("normal_font_size", 26)
	_history_text.add_theme_font_size_override("bold_font_size", 26)
	_history_text.add_theme_constant_override("line_separation", 6)
	panel.add_child(_history_text)

## Кадр 1920×1080 — по центру по ширине и прижат к низу (на широких экранах).
func _fit_frame() -> void:
	if _frame == null:
		return
	_frame.position = Vector2((size.x - FRAME.x) * 0.5, size.y - FRAME.y)

# --- Запуск -------------------------------------------------------------------

func show_sequence(lines: Array, on_finished: Callable = Callable()) -> void:
	_lines = lines.duplicate()
	_sequence_characters = _collect_sequence_characters(_lines)
	_index = -1
	_history.clear()
	_auto_mode = false
	_on_finished = on_finished
	_finished = false
	_refresh_auto_button()
	for id in _portraits.keys():
		(_portraits[id] as Node).queue_free()
	_portraits.clear()
	visible = true
	_set_ui_hidden(false)
	_history_panel.visible = false
	modulate.a = 0.0
	var t := create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(self, "modulate:a", 1.0, 0.2)
	_show_next_line()

func show_sequence_resource(seq: DialogueSequence, on_finished: Callable = Callable()) -> void:
	if seq == null:
		_finish_sequence()
		return
	show_sequence(seq.lines, on_finished)

# --- Ввод ---------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	var click := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		click = true
	elif event is InputEventScreenTouch and event.pressed:
		click = true
	if click:
		accept_event()
		_advance()

func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or get_tree().paused or _history_panel.visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()

## Клик: вернуть скрытое окно -> допечатать реплику -> следующая реплика.
func _advance() -> void:
	if _ui_hidden:
		_set_ui_hidden(false)
		return
	if _typing:
		_finish_typing()
		return
	_show_next_line()

## Сразу следующая реплика (без «допечатать»): кнопки и авто-режим.
func _show_next_line() -> void:
	_cancel_auto_timer()
	_index += 1
	if _index >= _lines.size():
		_finish_sequence()
		return
	_apply_line(_lines[_index])

# --- Реплика ------------------------------------------------------------------

func _apply_line(line) -> void:
	if line == null:
		return
	var speaker := String(_read_line_value(line, "speaker_name", ""))
	var body := String(_read_line_value(line, "text", ""))
	var active := String(_read_line_value(line, "active_character", _read_line_value(line, "speaker", "")))
	var characters = _read_line_value(line, "characters", [])
	if not (characters is Array) or characters.is_empty():
		characters = _legacy_characters(line)
		if characters.is_empty():
			characters = _sequence_characters
		else:
			active = "_" + String(_read_line_value(line, "active_slot", "none"))
	_show_characters(_unique_characters(characters), active)

	var color := VnPortraits.name_color(active)
	_name_label.text = speaker
	_name_plate.visible = speaker != ""
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(color.r * 0.85, color.g * 0.85, color.b * 0.85, 0.97)
	ns.set_corner_radius_all(18)
	ns.set_border_width_all(2)
	ns.border_color = Color(1, 1, 1, 0.55)
	ns.content_margin_left = 26
	ns.content_margin_right = 26
	ns.content_margin_top = 6
	ns.content_margin_bottom = 8
	_name_plate.add_theme_stylebox_override("panel", ns)
	_name_plate.reset_size()

	_text.text = body
	_text.visible_characters = 0
	_shown = 0.0
	_typing = body != ""
	_arrow.visible = not _typing
	_history.append([speaker, color, body])
	if not _typing:
		_on_line_shown()

func _finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_arrow.visible = true
	_on_line_shown()

func _on_line_shown() -> void:
	if _auto_mode:
		_schedule_auto_advance()

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	if _typing:
		_shown += CHARS_PER_SEC * delta
		_text.visible_characters = int(_shown)
		if int(_shown) >= _text.get_total_character_count():
			_finish_typing()
	if _arrow.visible:
		_arrow.position.y = BOX_RECT.end.y - 56 + sin(_time * 5.0) * 4.0

# --- Портреты -----------------------------------------------------------------

## Показать набор персонажей: новые плавно входят, лишние уходят, говорящий выделяется.
func _show_characters(characters: Array, active: String) -> void:
	var count := clampi(characters.size(), 0, 3)
	var xs: Array = SLOT_X.get(maxi(count, 1), SLOT_X[1])
	var shrink := SHRINK_FOR_THREE if count >= 3 else 1.0
	var wanted := {}
	for i in range(count):
		var c: Dictionary = characters[i]
		var id := String(c.get("id", ""))
		var tex := c.get("portrait", null) as Texture2D
		if id == "" or tex == null:
			continue
		# Место: по порядку в списке; явный slot ("left" / "center" / "right") важнее.
		var slot_i := i
		var slot_name := String(c.get("slot", ""))
		if SLOT_NAMES.has(slot_name):
			if count >= 3:
				slot_i = int(SLOT_NAMES[slot_name])
			elif count == 2:
				slot_i = 1 if slot_name == "right" else 0
			else:
				slot_i = 0
		wanted[id] = true
		var lay := VnPortraits.layout(id, tex, float(xs[slot_i]), shrink)
		var node: TextureRect = _portraits.get(id)
		var is_new := node == null or not is_instance_valid(node)
		if is_new:
			node = TextureRect.new()
			node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			node.stretch_mode = TextureRect.STRETCH_SCALE
			node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_stage.add_child(node)
			_portraits[id] = node
		node.texture = tex
		node.size = tex.get_size() * float(lay["scale"])
		node.pivot_offset = lay["pivot"]
		var target_pos: Vector2 = lay["position"]
		var is_active := id == active
		var target_mod := Color.WHITE if (is_active or active == "" or bool(lay["picture"])) else DIM_INACTIVE
		var target_scale := Vector2.ONE if target_mod == Color.WHITE else Vector2.ONE * INACTIVE_SCALE
		var t := node.create_tween().set_parallel(true)
		t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		if is_new:
			# Входит со своей стороны экрана.
			var side := -1.0 if float(xs[slot_i]) < FRAME.x * 0.5 - 1.0 else (1.0 if float(xs[slot_i]) > FRAME.x * 0.5 + 1.0 else 0.0)
			node.position = target_pos + Vector2(60.0 * side, 24.0 if side == 0.0 else 0.0)
			node.modulate = Color(target_mod.r, target_mod.g, target_mod.b, 0.0)
			node.scale = target_scale
		t.tween_property(node, "position", target_pos, FADE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(node, "modulate", target_mod, FADE_TIME)
		t.tween_property(node, "scale", target_scale, FADE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if is_active:
			_stage.move_child(node, _stage.get_child_count() - 1)
	for id in _portraits.keys():
		if wanted.has(id):
			continue
		var gone: TextureRect = _portraits[id]
		_portraits.erase(id)
		if is_instance_valid(gone):
			var t2 := gone.create_tween()
			t2.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			t2.tween_property(gone, "modulate:a", 0.0, FADE_TIME)
			t2.tween_callback(gone.queue_free)

func _collect_sequence_characters(lines: Array) -> Array:
	var result: Array = []
	for line in lines:
		if line == null:
			continue
		var characters = _read_line_value(line, "characters", [])
		if characters is Array and not characters.is_empty():
			for c in characters:
				if c is Dictionary:
					_add_unique_character(result, c)
			continue
		var speaker_id := String(_read_line_value(line, "speaker", _read_line_value(line, "speaker_id", "")))
		if speaker_id != "":
			_add_unique_character(result, {"id": speaker_id, "portrait": _read_line_value(line, "center_portrait", null)})
	return result

func _unique_characters(characters: Array) -> Array:
	var result: Array = []
	for c in characters:
		if c is Dictionary:
			_add_unique_character(result, c)
	return result

func _add_unique_character(result: Array, character: Dictionary) -> void:
	var cid := String(character.get("id", ""))
	if cid == "":
		return
	for existing in result:
		if existing is Dictionary and String(existing.get("id", "")) == cid:
			if existing.get("portrait", null) == null and character.get("portrait", null) != null:
				existing["portrait"] = character.get("portrait", null)
			return
	result.append(character.duplicate(true))

## Старый формат (DialogueLine: left/center/right_portrait) -> список персонажей по местам.
func _legacy_characters(line) -> Array:
	var out: Array = []
	for slot in ["left", "center", "right"]:
		var tex = _read_line_value(line, slot + "_portrait", null)
		if tex is Texture2D:
			out.append({"id": "_" + slot, "portrait": tex, "slot": slot})
	return out

func _read_line_value(line, property_name: String, default_value = null):
	if line == null:
		return default_value
	if line is Dictionary:
		return line.get(property_name, default_value)
	if line is Resource:
		for property_info in line.get_property_list():
			if String(property_info.name) == property_name:
				return line.get(property_name)
	return default_value

# --- Конец, авто, кнопки ---------------------------------------------------

func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_typing = false
	_cancel_auto_timer()
	visible = false
	emit_signal("sequence_finished")
	if _on_finished.is_valid():
		_on_finished.call_deferred()

## Таймеры SceneTreeTimer отменить нельзя, поэтому каждый несёт «номер»:
## сработает только тот, который ещё актуален.
func _cancel_auto_timer() -> void:
	_auto_token += 1

func _schedule_auto_advance() -> void:
	_auto_token += 1
	var token := _auto_token
	var delay := clampf(AUTO_BASE_DELAY + AUTO_PER_CHAR * float(_text.text.length()), 1.2, 7.0)
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if token == _auto_token and _auto_mode and visible and not _finished and not _typing and not _ui_hidden and not _history_panel.visible:
			_show_next_line()
	)

func _on_skip_pressed() -> void:
	_finish_sequence()

func _on_auto_pressed() -> void:
	_auto_mode = not _auto_mode
	_refresh_auto_button()
	_cancel_auto_timer()
	if _auto_mode and visible and not _typing:
		_schedule_auto_advance()

func _refresh_auto_button() -> void:
	var b: Button = _buttons.get("auto")
	if b == null:
		return
	b.text = "Авто: вкл" if _auto_mode else "Авто"
	b.add_theme_stylebox_override("normal", _button_style(BTN_ON if _auto_mode else BTN_BG))

func _on_log_pressed() -> void:
	var t := ""
	for e in _history:
		var c: Color = e[1]
		var who := String(e[0])
		if who != "":
			t += "[b][color=#%s]%s[/color][/b]\n" % [c.lightened(0.35).to_html(false), who]
		t += "%s\n\n" % String(e[2])
	_history_text.text = t
	_history_panel.visible = true

## Скрыть окно текста и кнопки, чтобы посмотреть на картинку. Любой клик возвращает.
func _set_ui_hidden(hidden: bool) -> void:
	_ui_hidden = hidden
	if _ui != null:
		_ui.visible = not hidden
		_hidden_hint.visible = hidden
