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
	set_process_input(true)

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
	if pause_menu.has_signal("abandon_run_requested"):
		pause_menu.connect("abandon_run_requested", Callable(self, "_on_abandon"))
	if pause_menu.has_signal("quit_requested"):
		pause_menu.connect("quit_requested", Callable(self, "_on_quit"))

func _input(event: InputEvent) -> void:
	# Ловим физический ESC напрямую (не через action), чтобы исключить любые проблемы InputMap
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			toggle()
			get_viewport().set_input_as_handled()

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

func _on_abandon() -> void:
	close()
	SceneRouter_.go_to_setup()

func _on_quit() -> void:
	close()
	get_tree().quit()
