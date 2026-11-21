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
	# Свечение при наведении — на все кнопки-картинки игры (ButtonGlow), по мере их появления.
	get_tree().node_added.connect(_on_node_added)

	# Подключаем сигналы меню, если они есть
	if pause_menu.has_signal("resume_requested"):
		pause_menu.connect("resume_requested", Callable(self, "_on_resume"))
	if pause_menu.has_signal("main_menu_requested"):
		pause_menu.connect("main_menu_requested", Callable(self, "_on_main_menu"))
	if pause_menu.has_signal("quit_requested"):
		pause_menu.connect("quit_requested", Callable(self, "_on_quit"))

## Сцены, где пауза по ESC не нужна (там своё меню / заставка).
const NO_PAUSE_SCENES := ["res://scenes/MainMenu.tscn", "res://scenes/Prologue.tscn", "res://scenes/love/fufu_love.tscn"]
## Сцены, где кнопки паузы на экране нет (на её месте другое), но Esc паузу открывает.
const NO_PAUSE_BUTTON_SCENES := ["res://scripts/alchemy/Alchemy.tscn"]   ## там слева снизу инвентарь

## ESC ловим в _unhandled_input: сначала его получают сцены (закрыть просмотр картинки
## в галерее, окно семян на ферме и т.п.), и только если никто не забрал — открывается пауза.
func _unhandled_input(event: InputEvent) -> void:
	# Ловим физический ESC напрямую (не через action), чтобы исключить любые проблемы InputMap
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if not _is_open and not _pause_allowed():
				return
			get_viewport().set_input_as_handled()
			# Открыты настройки — ESC возвращает в меню паузы, а не закрывает всё.
			if _is_open and pause_menu.has_method("is_settings_open") and pause_menu.call("is_settings_open"):
				pause_menu.call("close_settings")
				return
			toggle()

# --- Кнопка паузы на экране и подсветка кнопок ----------------------------------

const PAUSE_BUTTON_TEXTURE := "res://assets/ui/buttons/miniMenuButton.png"
const PAUSE_BUTTON_SIZE := Vector2(72, 72)
## Где кнопка паузы в каждой сцене (левый верхний угол кнопки, экран 1920×1080).
## Нет сцены в списке — PAUSE_BUTTON_DEFAULT_POS.
const PAUSE_BUTTON_DEFAULT_POS := Vector2(16, 16)
const PAUSE_BUTTON_POS := {
	"res://scenes/card/CardBattle.tscn": Vector2(1809, 40),   ## на месте бывшей «Выйти»
	"res://scenes/Setup.tscn": Vector2(16, 992),              ## сверху слева заголовок отряда
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
	_pause_button.visible = not _is_open and _pause_allowed() and not in_dialogue and not NO_PAUSE_BUTTON_SCENES.has(path)

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
	if scene == null:
		return false
	return not NO_PAUSE_SCENES.has(scene.scene_file_path)

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
