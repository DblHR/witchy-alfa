extends CanvasLayer

@onready var catcher: Control = $Catcher
@onready var pause_menu: CanvasLayer = $PauseMenu

var _is_open := false

func _ready() -> void:
	# Менеджер паузы должен получать input И ДО паузы, и ВО ВРЕМЯ паузы.
	# PROCESS_MODE_WHEN_PAUSED ломает включение паузы (узел "просыпается" только когда пауза уже включена).
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# ВАЖНО: включаем input для этого узла
	set_process_unhandled_input(true)

	# Прячем меню
	if pause_menu.has_method("close"):
		pause_menu.call("close")
	else:
		pause_menu.visible = false

	# Ловец нужен, чтобы при открытом меню клики не проходили "сквозь" в бой.
	catcher.focus_mode = Control.FOCUS_ALL
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catcher.visible = false
	catcher.grab_focus()

	_build_pause_button()
	# Окно / полный экран и размер окна из настроек (user://settings.cfg).
	GameSettings.apply_display()
	# Свечение при наведении — на все кнопки-картинки игры (ButtonGlow), по мере их появления.
	get_tree().node_added.connect(_on_node_added)

	# Подключаем сигналы меню, если они есть
	if pause_menu.has_signal("resume_requested"):
		pause_menu.connect("resume_requested", Callable(self, "_on_resume"))
	if pause_menu.has_signal("main_menu_requested"):
		pause_menu.connect("main_menu_requested", Callable(self, "_on_main_menu"))
	if pause_menu.has_signal("quit_requested"):
		pause_menu.connect("quit_requested", Callable(self, "_on_quit"))

## Что делает Esc:
##   1) открыта пауза — закрывает настройки / паузу;
##   2) открыто дополнительное окно (EscClose: меню колоды, просмотр карт, окно кормления…) — закрывает его;
##   3) дом и забег (PAUSE_SCENES) — открывает паузу;
##   4) инвентарь, алхимия, ферма, лавка, подготовка (HOME_ON_ESC_SCENES) — домой.
## Сцена может временно запретить уход по Esc: метод esc_blocked() -> true (экскурсия Рикки).
const PAUSE_SCENES := ["res://scenes/Hub.tscn", "res://scenes/card/CardBattle.tscn"]
const HOME_ON_ESC_SCENES := [
	"res://scenes/Inventory.tscn", "res://scripts/alchemy/Alchemy.tscn", "res://scenes/Farm.tscn",
	"res://scenes/Shop.tscn", "res://scenes/Setup.tscn",
]
## Где на экране кнопка паузы (в доме на её месте сердечко — там только Esc).
const PAUSE_BUTTON_SCENES := ["res://scenes/card/CardBattle.tscn"]

## F11 и Alt+Enter — полный экран / окно (везде, в том числе в паузе и в диалогах).
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	if k.physical_keycode == KEY_F11 or ((k.physical_keycode == KEY_ENTER or k.physical_keycode == KEY_KP_ENTER) and k.alt_pressed):
		GameSettings.toggle_fullscreen()
		get_viewport().set_input_as_handled()

## ESC ловим в _unhandled_input: сначала его получают сцены (свои окна закрывают сами), и только
## если никто не забрал — EscClose / пауза / домой.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		return
	if _is_open:
		get_viewport().set_input_as_handled()
		# Открыты настройки — ESC возвращает в меню паузы, а не закрывает всё.
		if pause_menu.has_method("is_settings_open") and pause_menu.call("is_settings_open"):
			pause_menu.call("close_settings")
			return
		close()
		return
	if EscClose.modal_open(get_tree()):
		return
	if EscClose.close_top(get_tree()):
		get_viewport().set_input_as_handled()
		return
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	if PAUSE_SCENES.has(path):
		get_viewport().set_input_as_handled()
		open()
	elif HOME_ON_ESC_SCENES.has(path):
		if DialogueManager_ != null and DialogueManager_.is_showing():
			return   ## посреди диалога домой не уходим
		if scene.has_method("esc_blocked") and bool(scene.call("esc_blocked")):
			return
		get_viewport().set_input_as_handled()
		SceneRouter_.go_to_hub()

# --- Кнопка паузы на экране и подсветка кнопок ----------------------------------

## Кнопка паузы = подложка + значок «…» (как кнопки мини-меню HubMenu).
const PAUSE_BUTTON_TEXTURE := "res://assets/ui/buttons/buttonPanel.png"
const PAUSE_BUTTON_ICON := "res://assets/ui/buttons/miniMenuButton.png"
const PAUSE_BUTTON_SIZE := Vector2(72, 72)
## Где кнопка паузы в каждой сцене (левый верхний угол кнопки, экран 1920×1080).
## Нет сцены в списке — PAUSE_BUTTON_DEFAULT_POS.
const PAUSE_BUTTON_DEFAULT_POS := Vector2(16, 16)
const PAUSE_BUTTON_POS := {
	"res://scenes/card/CardBattle.tscn": Vector2(1809, 40),   ## на месте бывшей «Выйти»
}
## Сцены, где своё меню «Главное меню» со своими светящимися кнопками — их не трогаем.
const PAUSE_BUTTON_TUTORIAL_POS := Vector2(1505, 44)
const NO_GLOW_SCENES := ["res://scenes/MainMenu.tscn"]

var _pause_button: TextureButton
var _last_scene_path := ""

func _build_pause_button() -> void:
	_pause_button = TextureButton.new()
	_pause_button.name = "PauseButton"
	_pause_button.texture_normal = load(PAUSE_BUTTON_TEXTURE) as Texture2D
	_pause_button.ignore_texture_size = true
	_pause_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_pause_button.size = PAUSE_BUTTON_SIZE
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.tooltip_text = "Пауза (Esc)"
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = load(PAUSE_BUTTON_ICON) as Texture2D
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_button.add_child(icon)
	_pause_button.visible = false
	_pause_button.pressed.connect(func() -> void:
		if not _is_open and _pause_allowed():
			open()
	)
	add_child(_pause_button)
	move_child(_pause_button, 0)   ## под ловцом кликов и меню
	ButtonGlow.attach(_pause_button)

func _process(_delta: float) -> void:
	# Кнопка видна там, где пауза разрешена; место — своё для каждой сцены.
	var scene := get_tree().current_scene
	var path := scene.scene_file_path if scene != null else ""
	if path != _last_scene_path:
		_last_scene_path = path
		_pause_button.position = PAUSE_BUTTON_POS.get(path, PAUSE_BUTTON_DEFAULT_POS)
		# В обучении в правом верхнем углу «Пропустить обучение» — пауза левее неё.
		if scene != null and scene.get("_tutorial") != null:
			_pause_button.position = PAUSE_BUTTON_TUTORIAL_POS
	# В диалогах кнопку прячем (там свои кнопки сверху); ESC по-прежнему работает.
	var in_dialogue := DialogueManager_ != null and DialogueManager_.is_showing()
	_pause_button.visible = not _is_open and PAUSE_BUTTON_SCENES.has(path) and not in_dialogue

func _on_node_added(node: Node) -> void:
	if node is TextureButton and node != _pause_button:
		_attach_glow.call_deferred(node)

func _attach_glow(node) -> void:   ## без типа: узел мог уже удалиться до отложенного вызова
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene != null and NO_GLOW_SCENES.has(scene.scene_file_path) and (scene == node or scene.is_ancestor_of(node)):
		return
	ButtonGlow.attach(node as TextureButton)

func _pause_allowed() -> bool:
	var scene := get_tree().current_scene
	return scene != null and PAUSE_SCENES.has(scene.scene_file_path)

func toggle() -> void:
	if _is_open:
		close()
	else:
		open()

func open() -> void:
	_is_open = true
	get_tree().paused = true
	catcher.visible = true
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.grab_focus()
	if pause_menu.has_method("open"):
		pause_menu.call("open")
	else:
		pause_menu.visible = true

func close() -> void:
	_is_open = false
	if pause_menu.has_method("close"):
		pause_menu.call("close")
	else:
		pause_menu.visible = false
	catcher.visible = false
	catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().paused = false

func _on_resume() -> void:
	close()

func _on_main_menu() -> void:
	close()
	# Прогресс и так пишется автосейвом при каждом изменении — отдельно сохранять не нужно.
	SceneRouter_.go_to_main_menu()

func _on_quit() -> void:
	close()
	get_tree().quit()
