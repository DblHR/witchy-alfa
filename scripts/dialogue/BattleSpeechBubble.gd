extends Control

signal fade_started
signal bubble_finished

@onready var panel: PanelContainer = $BubblePanel
@onready var margin_box: MarginContainer = $BubblePanel/BubbleMargin
@onready var label: Label = $BubblePanel/BubbleMargin/BubbleText

var follow_target: Node2D
var world_offset := Vector2(0, -110)

const MIN_TEXT_WIDTH := 110.0
const MAX_TEXT_WIDTH := 260.0
const SCREEN_MARGIN := 12.0
const TOP_SAFE_AREA := 96.0
const DISPLAY_TIME := 3.0
const FADE_TIME := 1.5

var _is_fading := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2.ZERO
	custom_minimum_size = Vector2.ZERO

	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = Vector2.ZERO
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	margin_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin_box.add_theme_constant_override("margin_left", 18)
	margin_box.add_theme_constant_override("margin_top", 12)
	margin_box.add_theme_constant_override("margin_right", 18)
	margin_box.add_theme_constant_override("margin_bottom", 12)

	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size = Vector2(MIN_TEXT_WIDTH, 0)

func popup_text(text: String) -> void:
	await show_text(text)

func is_fading() -> bool:
	return _is_fading

func can_accept_next_line() -> bool:
	return _is_fading

func show_text(text: String) -> void:
	text = text.strip_edges()
	if text == "":
		queue_free()
		return

	_is_fading = false
	label.text = text
	_resize_to_text(text)
	_update_position()
	modulate.a = 1.0
	visible = true

	await get_tree().create_timer(DISPLAY_TIME).timeout
	if not is_inside_tree():
		return

	_is_fading = true
	emit_signal("fade_started")

	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	await tw.finished
	if is_inside_tree():
		emit_signal("bubble_finished")
		queue_free()

func _resize_to_text(text: String) -> void:
	var max_text_width := minf(MAX_TEXT_WIDTH, get_viewport_rect().size.x - SCREEN_MARGIN * 2.0 - 36.0)
	max_text_width = maxf(max_text_width, MIN_TEXT_WIDTH)

	var font: Font = label.get_theme_font("font")
	var font_size := label.get_theme_font_size("font_size")
	var text_size := Vector2(MIN_TEXT_WIDTH, 28)

	if font != null:
		text_size = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, max_text_width, font_size)

	text_size.x = clampf(ceilf(text_size.x), MIN_TEXT_WIDTH, max_text_width)
	text_size.y = maxf(ceilf(text_size.y), 28.0)

	label.custom_minimum_size = text_size
	label.size = text_size

	var h_margin := float(margin_box.get_theme_constant("margin_left") + margin_box.get_theme_constant("margin_right"))
	var v_margin := float(margin_box.get_theme_constant("margin_top") + margin_box.get_theme_constant("margin_bottom"))
	var bubble_size := Vector2(text_size.x + h_margin, text_size.y + v_margin)

	size = bubble_size
	custom_minimum_size = bubble_size
	panel.custom_minimum_size = bubble_size
	panel.size = bubble_size
	margin_box.position = Vector2.ZERO
	margin_box.size = bubble_size

func _process(_delta: float) -> void:
	_update_position()

func _update_position() -> void:
	if follow_target == null or not is_instance_valid(follow_target):
		return

	var pos := follow_target.get_global_transform_with_canvas().origin + world_offset
	var desired := pos - Vector2(size.x * 0.5, size.y)
	var vp := get_viewport_rect().size

	desired.x = clampf(desired.x, SCREEN_MARGIN, vp.x - size.x - SCREEN_MARGIN)
	desired.y = clampf(desired.y, TOP_SAFE_AREA, vp.y - size.y - SCREEN_MARGIN)

	global_position = desired.round()
