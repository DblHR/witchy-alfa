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
	set_process(false)   ## включается только пока карточку тащат

func set_frame_color(c: Color) -> void:
	_border_color = c
	_update_style()

## --- Значок класса в левом верхнем углу карточки героини ---
## Картинка: assets/ui/classes/<класс>.png, где класс — из CharacterData.unit_class:
## воин -> fighter, маг -> mage, саппорт -> support, танк -> tank. Нет картинки — подпись словом.
const CLASS_ICON_DIR := "res://assets/ui/classes/"
const CLASS_ICON_FILES := {"воин": "fighter", "маг": "mage", "саппорт": "support", "танк": "tank"}
const CLASS_ICON_SIZE := 0.34   ## доля ширины карточки

var _class_icon: TextureRect
var _class_label: Label

static func class_icon_path(unit_class: String) -> String:
	return CLASS_ICON_DIR + String(CLASS_ICON_FILES.get(unit_class, unit_class)) + ".png"

func set_character(id: String, display_name: String, tex: Texture2D) -> void:
	character_id = id
	if not is_node_ready():
		await ready
	name_label.text = display_name
	if chibi_mode:
		_set_chibi(tex)
		return
	portrait.texture = tex
	portrait.modulate = Color.WHITE if tex != null else Color(1, 1, 1, 0.0)
	_update_class_icon()

# --- Режим «чибик» (экран подготовки: отряд стоит на площадке) ----------------------
## Вместо карточки — персонаж в полный рост (картинка из боя), смотрит вправо, покачивается
## как в бою. Ноги — у нижнего края слота. Рост — CHIBI_HEIGHT × data/characters/sizes.json.
const CHIBI_HEIGHT := 420.0
const CHIBI_FEET_MARGIN := 34.0
const IDLE_SWAY_X := 5.0       ## как в бою (CardActorFx)
const IDLE_BOB_Y := 3.0
var chibi_mode := false
## Sprite2D, а не TextureRect: Control-ы прилипают к целым пикселям (snap_controls_to_pixels),
## и медленное покачивание шло рывками. Node2D двигается плавно.
var _chibi: Sprite2D
var _shadow: Sprite2D
var _chibi_base := Vector2.ZERO
var _idle: Array[Tween] = []

func set_chibi_mode(on: bool) -> void:
	chibi_mode = on
	if not is_node_ready():
		await ready
	for n in ["CardBg", "Clipper", "Shade", "Name"]:
		var c := get_node_or_null(n) as CanvasItem
		if c != null:
			c.visible = not on
	if _class_icon != null:
		_class_icon.visible = false
		_class_label.visible = false
	_update_style()
	if on and not mouse_entered.is_connected(_on_chibi_hover):
		mouse_entered.connect(_on_chibi_hover.bind(true))
		mouse_exited.connect(_on_chibi_hover.bind(false))

func _on_chibi_hover(on: bool) -> void:
	if _chibi != null and _chibi.visible:
		HoverOutline.set_on(_chibi, on)

func _set_chibi(tex: Texture2D) -> void:
	if _chibi == null:
		_chibi = Sprite2D.new()
		_chibi.name = "Chibi"
		_chibi.centered = false
		_chibi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_chibi.flip_h = true   ## картинки смотрят влево, на площадке — вправо (к врагам)
		add_child(_chibi)
	# Тот же персонаж на том же месте — не перезапускаем покачивание (иначе при каждом
	# перетаскивании все начинали анимацию заново).
	if tex != null and _chibi.texture == tex and _chibi.visible and _idle.size() == 2 and _idle[0].is_valid():
		return
	for t in _idle:
		if t.is_valid():
			t.kill()
	_idle.clear()
	_chibi.visible = tex != null
	_chibi.texture = tex
	if _shadow != null:
		_shadow.visible = tex != null
	if tex == null:
		return
	var r := CharSizes.used_rect(tex)
	var k := CHIBI_HEIGHT * CharSizes.scale_of(character_id) / maxf(1.0, float(r.size.y))
	_chibi.scale = Vector2(k, k)
	# Начало координат спрайта — ноги посередине фигуры (с учётом отражения).
	var mid_x := float(r.position.x) + float(r.size.x) * 0.5
	var mirrored_mid := float(tex.get_width()) - mid_x
	_chibi.offset = Vector2(-mirrored_mid, -float(r.position.y + r.size.y))
	_chibi_base = Vector2(size.x * 0.5, size.y - CHIBI_FEET_MARGIN)
	_chibi.position = _chibi_base
	# Тень под ногами (ChibiShadow), стоит на месте, пока чибик покачивается.
	if _shadow == null and ChibiShadow.texture() != null:
		_shadow = ChibiShadow.make()
		add_child(_shadow)
		move_child(_shadow, _chibi.get_index())
	if _shadow != null:
		# Под ногами (а не под серединой картинки с оружием): картинка отражена.
		var feet_dx := (float(tex.get_width()) - ChibiShadow.feet_center_x(tex) - mirrored_mid) * k
		ChibiShadow.place(_shadow, _chibi_base + Vector2(feet_dx, 0), ChibiShadow.width_for(tex, k))
	# Idle как в бою: покачивание влево-вправо и лёгкие подпрыгивания, своя фаза у каждого.
	var half := randf_range(0.95, 1.35)
	var t := create_tween().set_loops()
	t.tween_property(_chibi, "position:x", _chibi_base.x + IDLE_SWAY_X, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_chibi, "position:x", _chibi_base.x - IDLE_SWAY_X, half * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_chibi, "position:x", _chibi_base.x, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var b := create_tween().set_loops()
	b.tween_property(_chibi, "position:y", _chibi_base.y - IDLE_BOB_Y, half * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.tween_property(_chibi, "position:y", _chibi_base.y, half * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_idle = [t, b]

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
				_drag_started = false
				set_process(false)
				drag_released.emit(ui_index, get_global_mouse_position())
			elif _mouse_down and can_pick:
				pressed.emit(ui_index)
			_mouse_down = false
	elif event is InputEventMouseMotion and _mouse_down and can_drag:
		if not _drag_started and event.relative.length() > 3.0:
			_drag_started = true
			set_process(true)
			drag_started.emit(ui_index, _press_local_offset)
		if _drag_started:
			drag_moved.emit(ui_index, get_global_mouse_position())

func _update_style() -> void:
	if chibi_mode:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		return
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

## Отпускание кнопки «потерялось» (Alt+Tab, окно потеряло фокус) — карточку всё равно отпускаем,
## иначе она так и висела на экране.
func _process(_delta: float) -> void:
	if _drag_started and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_force_release()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _drag_started:
			_force_release()
		_mouse_down = false

func _force_release() -> void:
	_drag_started = false
	_mouse_down = false
	set_process(false)
	drag_released.emit(ui_index, get_global_mouse_position())
