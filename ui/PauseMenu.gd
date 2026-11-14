extends CanvasLayer

signal resume_requested
signal main_menu_requested
signal quit_requested

@onready var panel: Control = $Panel
@onready var background: Control = $BackGround
@onready var resume_btn: Button = $Panel/VBoxContainer/Resume
@onready var settings_btn: Button = $Panel/VBoxContainer/Settings
@onready var main_menu_btn: Button = $Panel/VBoxContainer/MainMenu
@onready var quit_btn: Button = $Panel/VBoxContainer/Quit

## Окно настроек создаётся кодом (ui/SettingsPanel.gd) и открывается поверх паузы вместо панели.
var _settings: SettingsPanel

func _ready() -> void:
	# Menu must work while the game is paused.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# When hidden, it must NOT block clicks.
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect buttons in code (avoids relying on editor connections).
	if resume_btn != null:
		resume_btn.pressed.connect(func(): resume_requested.emit())
	if settings_btn != null:
		settings_btn.pressed.connect(open_settings)
	if main_menu_btn != null:
		main_menu_btn.pressed.connect(func(): main_menu_requested.emit())
	if quit_btn != null:
		quit_btn.pressed.connect(func(): quit_requested.emit())

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_requested.connect(close_settings)
	add_child(_settings)

	visible = false

func open() -> void:
	visible = true
	close_settings()
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_STOP
	if resume_btn != null:
		resume_btn.focus_mode = Control.FOCUS_ALL
		resume_btn.grab_focus()

func close() -> void:
	visible = false
	if _settings != null:
		_settings.visible = false
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func is_settings_open() -> bool:
	return _settings != null and _settings.visible

func open_settings() -> void:
	if _settings == null:
		return
	_settings.refresh()
	_settings.visible = true
	panel.visible = false
	_settings.focus_default()

func close_settings() -> void:
	if _settings != null:
		_settings.visible = false
	if panel != null:
		panel.visible = true
		if visible and settings_btn != null:
			settings_btn.grab_focus()
