extends Control
## Экран отношений с персонажем (открывается из сердечка в доме: LoveMenu → SceneRouter_.go_to_love).
## Сцена своя на каждого персонажа: scenes/love/<id>_love.tscn (сейчас fufu_love.tscn) —
## во весь экран карточка интеракций из assets/characters/<id>/interactive/, кнопка «Назад».
## Интерактив добавлять прямо в сцену персонажа.

@export var unit_id := ""

@onready var back_button: TextureButton = %BackButton

func _ready() -> void:
	get_tree().paused = false
	back_button.pressed.connect(func() -> void: SceneRouter_.go_to_hub())

func _unhandled_input(event: InputEvent) -> void:
	# Esc здесь — тоже «Назад» (пауза не нужна).
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		SceneRouter_.go_to_hub()
