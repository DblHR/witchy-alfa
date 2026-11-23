extends Control
## Главное меню. Слои (MainMenu.tscn): фон → ведьмочка (Witch: чуть парит сама по себе; зоны
## клика Witch/Canvas/Zones — как на ферме, картинки assets/ui/menu/<sprite>.png; рука — сердечко
## на ладошке, точка Witch/Canvas/HeartAt) → панель → кнопки. Новая игра / загрузка — через выбор
## слота (SaveSlotMenu), настройки — то же окно, что в паузе (SettingsPanel).

const NORMAL_COLOR := Color(1.0, 1.0, 1.0, 0.94)
const HOVER_COLOR := Color(1.0, 0.72, 0.9, 1.0)
const PRESS_COLOR := Color(1.0, 0.38, 0.72, 1.0)
const DISABLED_COLOR := Color(0.55, 0.55, 0.6, 0.45)
const GLOW_COLOR := Color(1.0, 0.18, 0.64, 1.0)

const HEART_FADE_DURATION := 2.2
const HEART_SPIN_SPEED := 1.15
const HEART_MIN_SCALE_X := 0.16
const HEART_GLOW_BASE := 0.42
const HEART_GLOW_PULSE := 0.34
const HEART_GLOW_SCALE := 1.16
const HEART_TINT_SOFT := Color(1.0, 0.9, 0.96, 1.0)
const HEART_TINT_BRIGHT := Color(1.0, 0.72, 0.9, 1.0)

@onready var menu_layer: Control = $MenuLayer
@onready var pre_layer: Control = $PreLayer
@onready var heart: TextureRect = $PreLayer/Heart
@onready var heart_glow: TextureRect = $PreLayer/HeartGlow
@onready var click_glow: TextureRect = $PreLayer/ClickGlow
@onready var click_button: TextureButton = %ClickButton
@onready var start_button: TextureButton = %StartButton
@onready var load_button: TextureButton = %LoadButton
@onready var options_button: TextureButton = %OptionsButton
@onready var quit_button: TextureButton = %QuitButton
@onready var witch: Node2D = $Witch
@onready var witch_sprite: Sprite2D = $Witch/Canvas/Sprite
@onready var witch_zones: Node2D = $Witch/Canvas/Zones
@onready var heart_at: Marker2D = $Witch/Canvas/HeartAt

## Ведьмочка парит: насколько (px) и как быстро (рад/с) по x и y, и лёгкий наклон.
const FLOAT_AMP := Vector2(20.0, 20.0)
const FLOAT_SPEED := Vector2(0.8, 0.8)
const FLOAT_TILT := 0.02
const WITCH_DIR := "res://assets/ui/menu/"
## Сердечко на ладошке: сколько висит, размер, как высоко подпрыгивает и как быстро крутится.
const PALM_HEART_TIME := 5.0
const PALM_HEART_SIZE := 80.0
const PALM_HEART_REGION := Rect2(582, 142, 742, 705)
const PALM_HEART_HOP := 22.0
const PALM_HEART_HOP_SPEED := 2.4
const PALM_HEART_SPIN := 2.6

var _witch_base := Vector2.ZERO
var _witch_tex: Texture2D
var _witch_token := 0
var _float_t := 0.0
var _palm_heart: Sprite2D
var _palm_heart_t := 0.0
var _palm_heart_left := 0.0
var _slot_menu: SaveSlotMenu
var _settings_overlay: Control
var _settings: SettingsPanel

var _button_glows: Dictionary = {}
var _hovered_buttons: Dictionary = {}
var _pressed_buttons: Dictionary = {}
var _pre_menu_time := 0.0
var _heart_fade_tween: Tween
var _menu_transition_tween: Tween
var _click_prompt_ready := false
var _transitioning_to_menu := false

func _ready() -> void:
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_button_map()
	_setup_menu_buttons()
	_setup_click_prompt()
	_setup_witch()
	_setup_slot_menu()
	_setup_settings()
	set_process(true)
	_start_pre_menu_sequence()




func _process(delta: float) -> void:
	_pre_menu_time += delta
	_animate_heart(delta)
	_animate_click_prompt(delta)
	_animate_witch(delta)

# --- Ведьмочка -----------------------------------------------------------------

func _setup_witch() -> void:
	_witch_base = witch.position
	_witch_tex = witch_sprite.texture
	_palm_heart = Sprite2D.new()
	_palm_heart.name = "PalmHeart"
	_palm_heart.texture = heart.texture
	# heart.png — полноэкранный холст; берём только само сердечко
	_palm_heart.region_enabled = true
	_palm_heart.region_rect = PALM_HEART_REGION
	_palm_heart.visible = false
	heart_at.get_parent().add_child(_palm_heart)

func _animate_witch(delta: float) -> void:
	_float_t += delta
	witch.position = _witch_base + Vector2(sin(_float_t * FLOAT_SPEED.x) * FLOAT_AMP.x, sin(_float_t * FLOAT_SPEED.y) * FLOAT_AMP.y)
	witch.rotation = sin(_float_t * 0.29) * FLOAT_TILT
	if _palm_heart_left > 0.0:
		_palm_heart_left -= delta
		_palm_heart_t += delta
		var base := PALM_HEART_SIZE / maxf(1.0, _palm_heart.region_rect.size.x)
		var pop := minf(1.0, _palm_heart_t / 0.2)
		var hop := absf(sin(_palm_heart_t * PALM_HEART_HOP_SPEED)) * PALM_HEART_HOP
		_palm_heart.position = _heart_point() + Vector2(0, -hop)
		_palm_heart.scale = Vector2(cos(_palm_heart_t * PALM_HEART_SPIN), 1.0) * base * pop
		_palm_heart.modulate.a = clampf(_palm_heart_left / 0.4, 0.0, 1.0)
		if _palm_heart_left <= 0.0:
			_palm_heart.visible = false

func _witch_zone_at(p: Vector2) -> WitchZone:
	if pre_layer.visible or not menu_layer.visible or _overlay_open():
		return null
	for z in witch_zones.get_children():
		if z is WitchZone and (z as WitchZone).in_pose == _pose and (z as WitchZone).has_global_point(p):
			return z as WitchZone
	return null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hot := _witch_zone_at((event as InputEventMouseMotion).global_position) != null
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hot else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var z := _witch_zone_at((event as InputEventMouseButton).global_position)
		if z != null:
			accept_event()
			witch_react(z)

## Текущая поза: пусто — обычная (mainmenu_witch.png), иначе имя картинки позы.
var _pose := ""

## Клик по зоне: картинка зоны на duration секунд (если она уже есть в assets/ui/menu/) и действие.
## "pose" — поза меняется и держится, пока не кликнут по зоне позы ещё раз.
func witch_react(z: WitchZone) -> void:
	if z.action == "heart":
		show_palm_heart()
	if z.action == "pose":
		set_pose("" if _pose != "" else z.sprite)
		return
	var path := WITCH_DIR + z.sprite + ".png"
	if not ResourceLoader.exists(path):
		return
	_witch_token += 1
	var token := _witch_token
	witch_sprite.texture = load(path) as Texture2D
	await get_tree().create_timer(maxf(0.1, z.duration)).timeout
	if token == _witch_token and is_instance_valid(witch_sprite):
		witch_sprite.texture = _pose_texture()

## Сменить позу ("" — обычная). Нет картинки позы — ничего не происходит.
func set_pose(pose: String) -> void:
	if pose != "" and not ResourceLoader.exists(WITCH_DIR + pose + ".png"):
		return
	_witch_token += 1   ## прерываем недосмотренную реакцию
	_pose = pose
	_palm_heart_left = 0.0
	if _palm_heart != null:
		_palm_heart.visible = false
	witch_sprite.texture = _pose_texture()

## Где сердечко в текущей позе: Witch/Canvas/HeartAt_<поза> (если есть), иначе HeartAt.
func _heart_point() -> Vector2:
	if _pose != "":
		var m := heart_at.get_parent().get_node_or_null("HeartAt_" + _pose) as Marker2D
		if m != null:
			return m.position
	return heart_at.position

func current_pose() -> String:
	return _pose

func _pose_texture() -> Texture2D:
	return _witch_tex if _pose == "" else load(WITCH_DIR + _pose + ".png") as Texture2D

## Сердечко на ладошке (крутится и подпрыгивает, двигается вместе с ведьмочкой).
func show_palm_heart() -> void:
	_palm_heart_t = 0.0
	_palm_heart_left = PALM_HEART_TIME
	_palm_heart.visible = true

func palm_heart_visible() -> bool:
	return _palm_heart != null and _palm_heart.visible

# --- Слоты и настройки -----------------------------------------------------------

func _setup_slot_menu() -> void:
	_slot_menu = SaveSlotMenu.new()
	add_child(_slot_menu)
	move_child(_slot_menu, pre_layer.get_index())
	_slot_menu.slot_chosen.connect(_on_slot_chosen)

func _setup_settings() -> void:
	_settings_overlay = Control.new()
	_settings_overlay.name = "SettingsOverlay"
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_settings_overlay.visible = false
	_settings_overlay.z_index = 20
	var dim := ColorRect.new()
	dim.color = GameUi.DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(dim)
	_settings = SettingsPanel.new()
	_settings_overlay.add_child(_settings)
	_settings.back_requested.connect(func() -> void: _settings_overlay.visible = false)
	add_child(_settings_overlay)
	_settings.process_mode = Node.PROCESS_MODE_ALWAYS   ## в паузе — WHEN_PAUSED, здесь игра не на паузе
	move_child(_settings_overlay, pre_layer.get_index())
	EscClose.register(_settings_overlay, func() -> void: _settings_overlay.visible = false)

func _overlay_open() -> bool:
	return (_slot_menu != null and _slot_menu.visible) or (_settings_overlay != null and _settings_overlay.visible)

func _on_slot_chosen(slot: int, new_game: bool) -> void:
	if new_game:
		SaveManager_.start_new_game(slot)
		if StoryState_ != null:
			StoryState_.reset_to_defaults()
		SceneRouter_.go_to_prologue()
	else:
		SaveManager_.continue_game(slot)
		SceneRouter_.go_to_hub()





func _setup_button_map() -> void:
	_button_glows = {
		click_button: click_glow,
		start_button: $MenuLayer/StartGlow,
		load_button: $MenuLayer/LoadGlow,
		options_button: $MenuLayer/OptionsGlow,
		quit_button: $MenuLayer/QuitGlow,
	}
	for button_variant in _button_glows.keys():
		var button := button_variant as TextureButton
		_hovered_buttons[button] = false
		_pressed_buttons[button] = false
		button.mouse_entered.connect(_on_button_mouse_entered.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exited.bind(button))
		button.button_down.connect(_on_button_down.bind(button))
		button.button_up.connect(_on_button_up.bind(button))
		button.pressed.connect(_on_any_button_pressed.bind(button))
		_apply_button_visual(button)


func _setup_menu_buttons() -> void:
	start_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	load_button.disabled = not SaveManager_.has_save()
	_apply_button_visual(load_button)
	menu_layer.visible = false
	menu_layer.modulate.a = 0.0


func _setup_click_prompt() -> void:
	click_button.pressed.connect(_on_click_to_start_pressed)
	click_button.modulate.a = 0.0
	click_button.disabled = false
	click_glow.modulate.a = 0.0
	heart.modulate.a = 0.0
	heart_glow.modulate.a = 0.0


func _start_pre_menu_sequence() -> void:
	if _heart_fade_tween != null:
		_heart_fade_tween.kill()
	_heart_fade_tween = create_tween()
	_heart_fade_tween.set_parallel(true)
	_heart_fade_tween.tween_property(heart, "modulate:a", 1.0, HEART_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_heart_fade_tween.tween_property(click_button, "modulate:a", 1.0, HEART_FADE_DURATION * 0.9).set_delay(0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_heart_fade_tween.tween_property(heart_glow, "modulate:a", HEART_GLOW_BASE, HEART_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_heart_fade_tween.finished.connect(func() -> void:
		_click_prompt_ready = true
		_apply_button_visual(click_button)
	)


func _animate_heart(_delta: float) -> void:
	if not pre_layer.visible:
		return
	var spin_wave: float = absf(cos(_pre_menu_time * HEART_SPIN_SPEED))
	var pulse: float = sin(_pre_menu_time * 3.9) * 0.5 + 0.5
	var scale_x: float = lerpf(HEART_MIN_SCALE_X, 1.0, spin_wave)
	var glow_scale_y: float = HEART_GLOW_SCALE + sin(_pre_menu_time * 1.7) * 0.05
	heart.scale = Vector2(scale_x, 1.0)
	var heart_alpha: float = heart.modulate.a
	var heart_color: Color = HEART_TINT_SOFT.lerp(HEART_TINT_BRIGHT, pulse * 0.8)
	heart_color.a = heart_alpha
	heart.modulate = heart_color
	heart_glow.scale = Vector2(scale_x * (HEART_GLOW_SCALE + pulse * 0.08), glow_scale_y)
	var glow_alpha: float = heart.modulate.a * (HEART_GLOW_BASE + pulse * HEART_GLOW_PULSE)
	heart_glow.modulate = _with_alpha(Color(1.0, 0.2 + pulse * 0.18, 0.75 + pulse * 0.18, 1.0), glow_alpha)


func _animate_click_prompt(_delta: float) -> void:
	if not pre_layer.visible or not _click_prompt_ready:
		return
	var pulse := sin(_pre_menu_time * 4.0) * 0.5 + 0.5
	if not _hovered_buttons[click_button] and not _pressed_buttons[click_button]:
		click_button.modulate = _with_alpha(NORMAL_COLOR, 0.76 + pulse * 0.24)
		click_glow.modulate = _with_alpha(GLOW_COLOR, 0.12 + pulse * 0.16)


func _on_button_mouse_entered(button: TextureButton) -> void:
	_hovered_buttons[button] = true
	_apply_button_visual(button)


func _on_button_mouse_exited(button: TextureButton) -> void:
	_hovered_buttons[button] = false
	_pressed_buttons[button] = false
	_apply_button_visual(button)


func _on_button_down(button: TextureButton) -> void:
	_pressed_buttons[button] = true
	_apply_button_visual(button)
	var press_tween := create_tween()
	press_tween.tween_property(button, "scale", Vector2(0.98, 0.98), 0.06)
	press_tween.tween_property(button, "scale", Vector2.ONE, 0.08)


func _on_button_up(button: TextureButton) -> void:
	_pressed_buttons[button] = false
	_apply_button_visual(button)


func _on_any_button_pressed(button: TextureButton) -> void:
	var glow: TextureRect = _button_glows.get(button)
	if glow == null:
		return
	var flash := create_tween()
	flash.tween_property(glow, "scale", Vector2(1.08, 1.08), 0.07)
	flash.parallel().tween_property(glow, "modulate:a", 0.95, 0.06)
	flash.tween_property(glow, "scale", Vector2.ONE, 0.14)
	flash.parallel().tween_property(glow, "modulate:a", (0.46 if _hovered_buttons[button] else 0.0), 0.16)


func _apply_button_visual(button: TextureButton) -> void:
	var glow: TextureRect = _button_glows.get(button)
	if glow == null:
		return
	button.scale = Vector2.ONE
	glow.scale = Vector2.ONE
	if button.disabled:
		button.modulate = DISABLED_COLOR
		glow.modulate = _with_alpha(GLOW_COLOR, 0.0)
		return
	if _pressed_buttons[button]:
		button.modulate = PRESS_COLOR
		glow.modulate = _with_alpha(GLOW_COLOR, 0.9)
		return
	if _hovered_buttons[button]:
		button.modulate = HOVER_COLOR
		glow.modulate = _with_alpha(GLOW_COLOR, 0.46)
		return
	if button == click_button and _click_prompt_ready and pre_layer.visible:
		# Idle animation for the prompt is handled in _animate_click_prompt.
		return
	button.modulate = NORMAL_COLOR
	glow.modulate = _with_alpha(GLOW_COLOR, 0.0)


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)


func _on_click_to_start_pressed() -> void:
	if _transitioning_to_menu:
		return
	_transitioning_to_menu = true
	click_button.disabled = true
	menu_layer.visible = true
	if _menu_transition_tween != null:
		_menu_transition_tween.kill()
	_menu_transition_tween = create_tween()
	_menu_transition_tween.set_parallel(true)
	_menu_transition_tween.tween_property(pre_layer, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_menu_transition_tween.tween_property(menu_layer, "modulate:a", 1.0, 0.55).set_delay(0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_menu_transition_tween.finished.connect(func() -> void:
		pre_layer.visible = false
	)


func _on_continue_pressed() -> void:
	_slot_menu.open(false)


func _on_new_game_pressed() -> void:
	_slot_menu.open(true)


func _on_options_pressed() -> void:
	_settings.refresh()
	_settings_overlay.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()
