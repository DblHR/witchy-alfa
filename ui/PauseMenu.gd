extends CanvasLayer

signal resume_requested
signal abandon_run_requested
signal quit_requested

@onready var panel: Control = $Panel
@onready var background: Control = $BackGround
@onready var resume_btn: Button = $Panel/VBoxContainer/Resume
@onready var abandon_btn: Button = $Panel/VBoxContainer/Abandon
@onready var quit_btn: Button = $Panel/VBoxContainer/Quit

func _ready() -> void:
	# Menu must work while the game is paused.
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	# When hidden, it must NOT block clicks.
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Connect buttons in code (avoids relying on editor connections).
	if resume_btn != null:
		resume_btn.pressed.connect(_on_resume_pressed)
	if abandon_btn != null:
		abandon_btn.pressed.connect(_on_abandon_pressed)
	if quit_btn != null:
		quit_btn.pressed.connect(_on_quit_pressed)

	visible = false

func open() -> void:
	visible = true
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_STOP
	if resume_btn != null:
		resume_btn.focus_mode = Control.FOCUS_ALL
		resume_btn.grab_focus()

func close() -> void:
	visible = false
	if background != null:
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_resume_pressed() -> void:
	emit_signal("resume_requested")

func _on_abandon_pressed() -> void:
	emit_signal("abandon_run_requested")

func _on_quit_pressed() -> void:
	emit_signal("quit_requested")
