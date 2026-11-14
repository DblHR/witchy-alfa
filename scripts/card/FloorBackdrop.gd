class_name FloorBackdrop
extends Node2D
## Фон этажа слоями: небо -> облака (медленно плывут слева направо) -> земля.
## Кадр 1920×1080, узел ставится в левый верхний угол экрана.
## Новый этаж — добавить набор картинок в FLOORS и передать номер в floor_no.

const FLOORS := {
	1: {
		"sky": "res://assets/backgrounds/floor1/bg_1floor_sky.png",
		"clouds": "res://assets/backgrounds/floor1/bg_1floor_clouds.png",
		"ground": "res://assets/backgrounds/floor1/bg_1floor_ground.png",
	},
}
## Скорость облаков, пикселей в секунду (весь проход экрана ~ 2.5 минуты).
const CLOUD_SPEED := 12.0
const FRAME := Vector2(1920, 1080)

@export var floor_no := 1

var _clouds: Array[Sprite2D] = []
var _offset := 0.0

func _ready() -> void:
	var set_: Dictionary = FLOORS.get(floor_no, FLOORS[1])
	_add_layer(String(set_["sky"]), "Sky")
	var tex := load(String(set_["clouds"])) as Texture2D
	if tex != null:
		# Две копии облаков подряд: когда первая уходит за правый край, она встаёт слева.
		for i in range(2):
			var s := _make_sprite(tex, "Clouds%d" % i)
			_clouds.append(s)
		_offset = randf() * FRAME.x   ## каждый раз облака с разного места
		_place_clouds()
	_add_layer(String(set_["ground"]), "Ground")

func _add_layer(path: String, node_name: String) -> void:
	var tex := load(path) as Texture2D
	if tex != null:
		_make_sprite(tex, node_name)

func _make_sprite(tex: Texture2D, node_name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = tex
	s.centered = false
	s.scale = FRAME / tex.get_size()
	add_child(s)
	return s

func _process(delta: float) -> void:
	if _clouds.is_empty():
		return
	_offset = fmod(_offset + CLOUD_SPEED * delta, FRAME.x)
	_place_clouds()

func _place_clouds() -> void:
	_clouds[0].position.x = _offset
	_clouds[1].position.x = _offset - FRAME.x
