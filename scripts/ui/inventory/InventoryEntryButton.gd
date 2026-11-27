extends TextureButton
class_name InventoryEntryButton

signal entry_pressed(entry_id: String)

@onready var background_panel: Panel = %BackgroundPanel
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var count_badge: Label = %CountBadge

var entry_id: String = ""

func _ready() -> void:
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	pressed.connect(func() -> void:
		entry_pressed.emit(entry_id)
	)
	mouse_entered.connect(func() -> void:
		if not button_pressed and not disabled:
			background_panel.modulate = Color(1.0, 0.96, 0.88, 0.92)
	)
	mouse_exited.connect(func() -> void:
		if not button_pressed:
			background_panel.modulate = Color(1, 1, 1, 0.72)
	)

const WIDE_SIZE := Vector2(440, 96)
## Плитка героини в разделе «Персонажи» (картинка — CharacterBust, по бюст).
const BUST_SIZE := Vector2(222, 210)

func setup(data: Dictionary) -> void:
	if not is_node_ready():
		await ready

	entry_id = String(data.get("id", ""))
	title_label.text = String(data.get("title", ""))
	subtitle_label.text = String(data.get("subtitle", ""))
	icon_rect.texture = data.get("icon", null)
	icon_rect.visible = icon_rect.texture != null

	var count := int(data.get("count", -1))
	count_badge.visible = count >= 0
	count_badge.text = "×%d" % count if count >= 0 else ""

	var compact := bool(data.get("compact", false))
	custom_minimum_size = Vector2(148, 132) if compact else Vector2(300, 148)
	if compact:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_label.position = Vector2(12, 90)
		title_label.size = Vector2(124, 30)
		title_label.add_theme_font_size_override("font_size", 32)

		subtitle_label.visible = false
		subtitle_label.text = ""

		icon_rect.position = Vector2(26, 12)
		icon_rect.size = Vector2(96, 72)
		icon_rect.custom_minimum_size = Vector2(96, 72)

		count_badge.position = Vector2(12, 102)
		count_badge.size = Vector2(56, 24)
	else:
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.position = Vector2(108, 20)
		title_label.size = Vector2(170, 28)
		title_label.add_theme_font_size_override("font_size", int(data.get("title_font_size", 20)))

		subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		subtitle_label.visible = String(data.get("subtitle", "")) != ""
		subtitle_label.position = Vector2(108, 58)
		subtitle_label.size = Vector2(170, 62)

		icon_rect.position = Vector2(9, 12)
		icon_rect.size = Vector2(84, 84)
		icon_rect.custom_minimum_size = Vector2(84, 84)

		count_badge.position = Vector2(13, 117)
		count_badge.size = Vector2(56, 28)

	# Большая плитка героини (раздел «Персонажи»): картинка по бюст и имя под ней.
	if bool(data.get("bust", false)):
		custom_minimum_size = BUST_SIZE
		icon_rect.position = Vector2(10, 10)
		icon_rect.size = Vector2(BUST_SIZE.x - 20, BUST_SIZE.y - 56)
		icon_rect.custom_minimum_size = icon_rect.size
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.position = Vector2(10, BUST_SIZE.y - 46)
		title_label.size = Vector2(BUST_SIZE.x - 20, 38)
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", Color(0.33, 0.16, 0.38))
		title_label.add_theme_constant_override("outline_size", 0)
		subtitle_label.visible = false
		count_badge.visible = false
		# Число на плитке (галерея: «открыто / всего») — в левом верхнем углу.
		var badge := String(data.get("badge", ""))
		if badge != "":
			count_badge.visible = true
			count_badge.text = badge
			count_badge.position = Vector2(14, 12)
			count_badge.size = Vector2(maxf(56.0, 16.0 + 11.0 * badge.length()), 30)
			count_badge.add_theme_font_size_override("font_size", 20)

	# Широкая строка без значка (энциклопедия): заголовок и подпись во всю ширину страницы.
	if bool(data.get("wide", false)):
		custom_minimum_size = Vector2(WIDE_SIZE.x, WIDE_SIZE.y)
		title_label.position = Vector2(20, 12)
		title_label.size = Vector2(WIDE_SIZE.x - 40, 30)
		subtitle_label.position = Vector2(20, 46)
		subtitle_label.size = Vector2(WIDE_SIZE.x - 40, 40)

	# Закрытое место («?» под будущего персонажа): не нажимается, полупрозрачное.
	var locked := bool(data.get("locked", false))
	disabled = locked
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	if locked:
		title_label.add_theme_color_override("font_color", Color(0.55, 0.48, 0.55))
		modulate.a = 0.85

	var selected := bool(data.get("selected", false))
	set_selected(selected)

func set_selected(selected: bool) -> void:
	button_pressed = selected
	if selected:
		background_panel.modulate = Color(1.0, 0.93, 0.72, 0.98)
	else:
		background_panel.modulate = Color(1, 1, 1, 0.72)
