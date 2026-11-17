extends Panel
class_name TeamSlot

signal pressed(slot_index: int)
signal drag_started(slot_index: int, pointer_offset: Vector2)
signal drag_moved(slot_index: int, global_mouse: Vector2)
signal drag_released(slot_index: int, global_mouse: Vector2)

@export var ui_index: int = 0
@export var can_pick: bool = true
@export var can_drag: bool = true

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %Name

var character_id: String = ""
var _border_color: Color = Color(0.7, 0.7, 0.7, 0.9)
var _mouse_down := false
var _drag_started := false
var _press_local_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_style()

func set_frame_color(c: Color) -> void:
	_border_color = c
	_update_style()

## --- Значок класса в левом верхнем углу карточки героини ---
## Картинка: assets/ui/classes/<класс>.png, где класс — из CharacterData.unit_class:
## воин -> fighter, маг -> mage, саппорт -> support, танк -> tank. Нет картинки — подпись словом.
const CLASS_ICON_DIR := "res://assets/ui/classes/"
const CLASS_ICON_FILES := {"воин": "fighter", "маг": "mage", "саппорт": "support", "танк": "tank"}
const CLASS_ICON_SIZE := 0.24   ## доля ширины карточки

var _class_icon: TextureRect
var _class_label: Label

static func class_icon_path(unit_class: String) -> String:
	return CLASS_ICON_DIR + String(CLASS_ICON_FILES.get(unit_class, unit_class)) + ".png"

func set_character(id: String, display_name: String, tex: Texture2D) -> void:
	character_id = id
	if not is_node_ready():
		await ready
	name_label.text = display_name
	portrait.texture = tex
	portrait.modulate = Color.WHITE if tex != null else Color(1, 1, 1, 0.0)
	_update_class_icon()

func _update_class_icon() -> void:
	var data: CharacterData = CharDB.get_by_id(character_id) if character_id != "" and CharDB != null else null
	var cls := data.unit_class if data != null else ""
	if _class_icon == null:
		_class_icon = TextureRect.new()
		_class_icon.name = "ClassIcon"
		_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_class_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_class_icon)
		_class_label = Label.new()
		_class_label.name = "ClassLabel"
		_class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_class_label.add_theme_font_size_override("font_size", 15)
		_class_label.add_theme_color_override("font_color", Color.WHITE)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.06, 0.18, 0.85)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 7
		sb.content_margin_right = 7
		sb.content_margin_top = 1
		sb.content_margin_bottom = 2
		_class_label.add_theme_stylebox_override("normal", sb)
		add_child(_class_label)
	var path := class_icon_path(cls)
	var has_icon := cls != "" and ResourceLoader.exists(path)
	var side := maxf(28.0, size.x * CLASS_ICON_SIZE)
	_class_icon.visible = has_icon
	_class_icon.texture = load(path) as Texture2D if has_icon else null
	_class_icon.position = Vector2(8, 8)
	_class_icon.size = Vector2(side, side)
	_class_icon.tooltip_text = cls
	_class_label.visible = cls != "" and not has_icon
	_class_label.text = cls
	_class_label.position = Vector2(8, 8)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_down = true
			_drag_started = false
			_press_local_offset = event.position
		else:
			if _mouse_down and _drag_started:
				drag_released.emit(ui_index, get_global_mouse_position())
			elif _mouse_down and can_pick:
				pressed.emit(ui_index)
			_mouse_down = false
	elif event is InputEventMouseMotion and _mouse_down and can_drag:
		if not _drag_started and event.relative.length() > 3.0:
			_drag_started = true
			drag_started.emit(ui_index, _press_local_offset)
		if _drag_started:
			drag_moved.emit(ui_index, get_global_mouse_position())

func _update_style() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_width_left = 5
	sb.border_width_right = 5
	sb.border_width_top = 5
	sb.border_width_bottom = 5
	sb.border_color = _border_color
	sb.corner_radius_top_left = 22
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	add_theme_stylebox_override("panel", sb)
