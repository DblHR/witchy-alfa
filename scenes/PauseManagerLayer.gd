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

	# Подключаем сигналы меню, если они есть
	if pause_menu.has_signal("resume_requested"):
		pause_menu.connect("resume_requested", Callable(self, "_on_resume"))
	if pause_menu.has_signal("main_menu_requested"):
		pause_menu.connect("main_menu_requested", Callable(self, "_on_main_menu"))
	if pause_menu.has_signal("quit_requested"):
		pause_menu.connect("quit_requested", Callable(self, "_on_quit"))

## Сцены, где пауза по ESC не нужна (там своё меню / заставка).
const NO_PAUSE_SCENES := ["res://scenes/MainMenu.tscn", "res://scenes/Prologue.tscn"]

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
