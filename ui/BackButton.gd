extends TextureButton
class_name BackButton
## Кнопка «назад» (стрелка, assets/ui/buttons/back.png): по нажатию — в комнату target
## (SceneRouter_.go_to_<target>, по умолчанию — домой). Стоит узлом в сцене: двигайте как удобно.

@export var target := "hub"

func _ready() -> void:
	if texture_normal == null:
		texture_normal = load("res://assets/ui/buttons/back.png") as Texture2D
	ignore_texture_size = true
	stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if tooltip_text == "":
		tooltip_text = "Назад"
	pressed.connect(_go)
	mouse_entered.connect(func() -> void: _bounce(1.06))
	mouse_exited.connect(func() -> void: _bounce(1.0))

func _go() -> void:
	if DialogueManager_ != null and DialogueManager_.is_showing():
		return
	if SceneRouter_ != null and SceneRouter_.has_method("go_to_" + target):
		SceneRouter_.call("go_to_" + target)

func _bounce(s: float) -> void:
	pivot_offset = size * 0.5
	create_tween().tween_property(self, "scale", Vector2(s, s), 0.1)
