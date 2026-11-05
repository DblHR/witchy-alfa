extends Control
class_name DialogueOverlay

signal sequence_finished

const ACTIVE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const INACTIVE_MODULATE := Color(0.84, 0.81, 0.85, 1.0)
const SLOT_RECTS := {
	"left": Rect2(25, -40, 680, 900),
	"center": Rect2(620, -40, 680, 900),
	"right": Rect2(1215, -40, 680, 900),
}

@onready var blur_rect: ColorRect = %BlurRect
@onready var left_portrait: TextureRect = %LeftPortrait
@onready var central_portrait: TextureRect = %CentralPortrait
@onready var right_portrait: TextureRect = %RightPortrait
@onready var text_box: Panel = %TextBox
@onready var speaker_name: Label = %SpeakerName
@onready var body_text: Label = %BodyText
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton
@onready var auto_button: Button = %AutoButton
@onready var log_button: Button = %LogButton
@onready var hide_ui_button: CheckButton = %HideUIButton

var _lines: Array = []
var _index: int = -1
var _auto_mode: bool = false
var _auto_delay: float = 2.0
var _auto_token: int = 0         ## каждый новый запуск/отмена авто-таймера обесценивает старые таймеры
var _finished: bool = false
var _history: PackedStringArray = []
var _on_finished: Callable = Callable()
var _sequence_characters: Array = []

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_text.clip_text = false
	next_button.pressed.connect(_show_next_line)
	skip_button.pressed.connect(_on_skip_pressed)
	auto_button.pressed.connect(_on_auto_pressed)
	log_button.pressed.connect(_on_log_pressed)
	hide_ui_button.toggled.connect(_on_hide_ui_toggled)
	if blur_rect != null and not blur_rect.gui_input.is_connected(_on_blur_rect_gui_input):
		blur_rect.gui_input.connect(_on_blur_rect_gui_input)
	_reset_portrait_modulates()

func show_sequence(lines: Array, on_finished: Callable = Callable()) -> void:
	_lines = lines.duplicate()
	_sequence_characters = _collect_sequence_characters(_lines)
	_index = -1
	_history.clear()
	_auto_mode = false
	_on_finished = on_finished
	_finished = false
	auto_button.text = "АВТО"
	visible = true
	text_box.visible = true
	hide_ui_button.button_pressed = false
	_show_next_line()

func show_sequence_resource(seq: DialogueSequence, on_finished: Callable = Callable()) -> void:
	if seq == null:
		_finish_sequence()
		return
	show_sequence(seq.lines, on_finished)

func _on_blur_rect_gui_input(event: InputEvent) -> void:
	if not visible or get_tree().paused:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_show_next_line()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_show_next_line()
		get_viewport().set_input_as_handled()

func _show_next_line() -> void:
	_cancel_auto_timer()
	_index += 1
	if _index >= _lines.size():
		_finish_sequence()
		return
	var line = _lines[_index]
	_apply_line(line)
	if _auto_mode:
		_schedule_auto_advance()

func _apply_line(line) -> void:
	if line == null:
		return
	var active_slot := "none"
	speaker_name.text = String(_read_line_value(line, "speaker_name", ""))
	body_text.text = String(_read_line_value(line, "text", ""))
	var characters = _read_line_value(line, "characters", [])
	var active_character := String(_read_line_value(line, "active_character", _read_line_value(line, "speaker", "")))
	if not (characters is Array) or characters.is_empty():
		characters = _sequence_characters
	if characters is Array and not characters.is_empty():
		_apply_character_portraits(_unique_characters(characters), active_character)
	else:
		left_portrait.texture = _as_texture(_read_line_value(line, "left_portrait", null))
		central_portrait.texture = _as_texture(_read_line_value(line, "center_portrait", null))
		right_portrait.texture = _as_texture(_read_line_value(line, "right_portrait", null))
		active_slot = String(_read_line_value(line, "active_slot", "none"))
		left_portrait.visible = left_portrait.texture != null
		central_portrait.visible = central_portrait.texture != null
		right_portrait.visible = right_portrait.texture != null
		_layout_legacy_portraits()
		_apply_portrait_focus(active_slot)
	_history.append("%s: %s" % [speaker_name.text, body_text.text])

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
			var portrait = _read_line_value(line, "center_portrait", null)
			_add_unique_character(result, {"id": speaker_id, "portrait": portrait})
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

func _apply_character_portraits(characters: Array, active_character: String) -> void:
	for portrait in [left_portrait, central_portrait, right_portrait]:
		portrait.texture = null
		portrait.visible = false
		portrait.set_meta("character_id", "")
	var slots := _slots_for_count(characters.size())
	for i in range(min(characters.size(), slots.size())):
		var c = characters[i]
		if not (c is Dictionary):
			continue
		var slot := String(c.get("slot", slots[i]))
		var portrait := _portrait_for_slot(slot)
		if portrait == null:
			continue
		portrait.texture = _as_texture(c.get("portrait", null))
		portrait.visible = portrait.texture != null
		portrait.set_meta("character_id", String(c.get("id", "")))
		_apply_slot_rect(portrait, slot)
	var resolved_active_slot := "none"
	for slot in ["left", "center", "right"]:
		var p := _portrait_for_slot(slot)
		if p != null and String(p.get_meta("character_id", "")) == active_character:
			resolved_active_slot = slot
			break
	_apply_portrait_focus(resolved_active_slot)

func _slots_for_count(count: int) -> Array[String]:
	match clamp(count, 1, 3):
		1:
			return ["center"]
		2:
			return ["left", "right"]
		_:
			return ["left", "center", "right"]

func _portrait_for_slot(slot: String) -> TextureRect:
	match slot:
		"left": return left_portrait
		"center": return central_portrait
		"right": return right_portrait
		_: return null

func _apply_slot_rect(portrait: TextureRect, slot: String) -> void:
	var rect: Rect2 = SLOT_RECTS.get(slot, SLOT_RECTS["center"])
	portrait.anchor_left = 0.0
	portrait.anchor_top = 0.0
	portrait.anchor_right = 0.0
	portrait.anchor_bottom = 0.0
	portrait.offset_left = rect.position.x
	portrait.offset_top = rect.position.y
	portrait.offset_right = rect.position.x + rect.size.x
	portrait.offset_bottom = rect.position.y + rect.size.y
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _layout_legacy_portraits() -> void:
	if left_portrait.visible:
		_apply_slot_rect(left_portrait, "left")
	if central_portrait.visible:
		_apply_slot_rect(central_portrait, "center")
	if right_portrait.visible:
		_apply_slot_rect(right_portrait, "right")

func _read_line_value(line, property_name: String, default_value = null):
	if line == null:
		return default_value
	if line is Dictionary:
		return line.get(property_name, default_value)
	if line is DialogueLine:
		match property_name:
			"speaker_name":
				return line.speaker_name
			"text":
				return line.text
			"left_portrait":
				return line.left_portrait
			"center_portrait":
				return line.center_portrait
			"right_portrait":
				return line.right_portrait
			"active_slot":
				return line.active_slot
	if line is Resource:
		for property_info in line.get_property_list():
			if String(property_info.name) == property_name:
				return line.get(property_name)
	return default_value

func _as_texture(value) -> Texture2D:
	return value if value is Texture2D else null

func _apply_portrait_focus(active_slot: String) -> void:
	_reset_portrait_modulates()
	match active_slot:
		"left":
			_set_portrait_focus(left_portrait, true)
			_set_portrait_focus(central_portrait, false)
			_set_portrait_focus(right_portrait, false)
		"center":
			_set_portrait_focus(left_portrait, false)
			_set_portrait_focus(central_portrait, true)
			_set_portrait_focus(right_portrait, false)
		"right":
			_set_portrait_focus(left_portrait, false)
			_set_portrait_focus(central_portrait, false)
			_set_portrait_focus(right_portrait, true)

func _set_portrait_focus(portrait: TextureRect, is_active: bool) -> void:
	if portrait == null or not portrait.visible:
		return
	portrait.self_modulate = ACTIVE_MODULATE if is_active else INACTIVE_MODULATE

func _reset_portrait_modulates() -> void:
	for portrait in [left_portrait, central_portrait, right_portrait]:
		if portrait != null:
			portrait.self_modulate = ACTIVE_MODULATE

func _finish_sequence() -> void:
	if _finished:
		return
	_finished = true
	_cancel_auto_timer()
	visible = false
	emit_signal("sequence_finished")
	if _on_finished.is_valid():
		_on_finished.call_deferred()

## Таймеры SceneTreeTimer отменить нельзя, поэтому каждый несёт «номер»:
## сработает только тот, который ещё актуален (иначе после ручного клика
## в режиме АВТО лишний таймер пролистывал бы следующую реплику).
func _cancel_auto_timer() -> void:
	_auto_token += 1

func _schedule_auto_advance() -> void:
	_auto_token += 1
	var token := _auto_token
	get_tree().create_timer(_auto_delay).timeout.connect(func() -> void:
		if token == _auto_token and _auto_mode and visible and not _finished:
			_show_next_line()
	)

func _on_skip_pressed() -> void:
	_finish_sequence()

func _on_auto_pressed() -> void:
	_auto_mode = not _auto_mode
	auto_button.text = "АВТО: ВКЛ" if _auto_mode else "АВТО"
	_cancel_auto_timer()
	if _auto_mode and visible:
		_schedule_auto_advance()

func _on_log_pressed() -> void:
	if _history.is_empty():
		return
	print("[DialogueLog]\n" + "\n".join(_history))

func _on_hide_ui_toggled(toggled_on: bool) -> void:
	text_box.visible = not toggled_on
