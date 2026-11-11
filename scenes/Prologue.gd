extends Control

const PROLOGUE_DIR := "res://assets/pics/bigPics/prologue"
const SCENE_COUNT := 12

@onready var image_rect: TextureRect = %ImageRect
@onready var hint_label: Label = %HintLabel
@onready var fallback_label: Label = %FallbackLabel

var _paths: Array[String] = []
var _textures: Dictionary = {}   ## индекс -> Texture2D; держим только текущий и следующий кадр
var _index: int = 0

func _ready() -> void:
	UIThemeHelper.apply_pink_theme(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_collect_paths()
	_show_current()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_advance()
		accept_event()

## Раньше все 12 картинок грузились сразу (около 100 МБ видеопамяти).
## Теперь только список путей, а текстуры подгружаются по мере показа.
func _collect_paths() -> void:
	_paths.clear()
	for i in range(1, SCENE_COUNT + 1):
		var path := "%s/scene%d.png" % [PROLOGUE_DIR, i]
		if ResourceLoader.exists(path):
			_paths.append(path)

func _texture_at(i: int) -> Texture2D:
	if i < 0 or i >= _paths.size():
		return null
	if not _textures.has(i):
		_textures[i] = load(_paths[i]) as Texture2D
	return _textures[i]

func _trim_cache() -> void:
	for key in _textures.keys():
		if int(key) < _index or int(key) > _index + 1:
			_textures.erase(key)

func _show_current() -> void:
	var has_images := not _paths.is_empty()
	image_rect.visible = has_images
	fallback_label.visible = not has_images
	hint_label.text = "Нажмите в любом месте" if (_index < max(_paths.size(), 1) - 1) else "Нажмите в любом месте, чтобы начать обучение"
	if has_images:
		image_rect.texture = _texture_at(_index)
		_trim_cache()
		_texture_at(_index + 1)
	else:
		fallback_label.text = """Пролог подготовлен, но изображения не найдены по пути:
%s

Как только scene1.png ... scene12.png появятся в проекте, экран начнёт показывать их автоматически.""" % PROLOGUE_DIR

func _advance() -> void:
	var max_count = max(_paths.size(), 1)
	_index += 1
	if _index >= max_count:
		var tutorial := true
		if StoryState_ != null:
			StoryState_.intro_played = true
			tutorial = StoryState_.tutorial_battle_pending and not StoryState_.tutorial_battle_completed
			StoryState_.changed.emit()
		if tutorial:
			# Обучение: бой со слизнем (CardTutorial), после него — хаб и диалог с Риккой.
			CardTutorial.requested = true
			SceneRouter_.go_to_card_battle()
		else:
			SceneRouter_.go_to_hub()
		return
	_show_current()
