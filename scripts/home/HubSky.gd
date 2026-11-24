extends Control
class_name HubSky
## Небо за домом (Hub.tscn → Sky, слой позади BackGround): небо, мерцающие звёздочки, луна-котик,
## плывущие облака, ёлки. Видно через прозрачные «дыры» в картинке дома (окна, крыша).
##
## Узлы — в сцене (двигайте там): SkyBG, SkyStars (звёзды создаются тут, в STAR_AREA), Moon, Clouds
## (Clouds/A и Clouds/B — одна и та же картинка, едут вправо и по кругу), Trees.
## Звёзды: STAR_TEXTURES, раскидываются случайно при каждом заходе, каждая мерцает в своём ритме.
## Луна: чуть колышется в стороны; клик (если её видно) — переключает картинку (MOON_CLICK_TEXTURE и обратно).
## Картинки — из assets/hub/night_hub/ (днём DayCycle подставит day_hub/, если там будут файлы).

@export var cloud_speed: float = 14.0          ## пикселей в секунду, слева направо
@export var star_count: int = 46
@export var star_area: Rect2 = Rect2(0, 0, 1920, 620)
@export var star_scale_min: float = 0.55
@export var star_scale_max: float = 1.15
## Луна чуть-чуть колышется в стороны: размах (px), наклон (градусы), скорость.
@export var moon_sway: float = 7.0
@export var moon_tilt_deg: float = 2.5
@export var moon_sway_speed: float = 0.6

const STAR_TEXTURES := [
	"res://assets/hub/night_hub/homeSkyStar1.png",
	"res://assets/hub/night_hub/homeSkyStar2.png",
	"res://assets/hub/night_hub/homeSkyStar3.png",
	"res://assets/hub/night_hub/homeSkyStar4.png",
	"res://assets/hub/night_hub/homeSkyStar5.png",
]
const MOON_CLICK_TEXTURE := "res://assets/hub/night_hub/homeMoon2.png"

@onready var stars_root: Control = $SkyStars
@onready var moon: TextureRect = $Moon
@onready var clouds: Control = $Clouds

var _stars: Array[Dictionary] = []    ## {node, speed, phase, base}
var _time := 0.0
var _moon_tex: Texture2D
var _moon_base := Vector2.ZERO
var _moon_img: Image

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if moon.texture != null:
		var t := DayCycle.texture(moon.texture.resource_path)
		if t != null:
			moon.texture = t
	_moon_tex = moon.texture
	_moon_base = moon.position
	_apply_moon_texture()
	_scatter_stars()

func _scatter_stars() -> void:
	for c in stars_root.get_children():
		c.queue_free()
	_stars.clear()
	var texs: Array[Texture2D] = []
	for p in STAR_TEXTURES:
		var t := DayCycle.texture(p)
		if t != null:
			texs.append(t)
	if texs.is_empty():
		return
	for i in range(star_count):
		var s := Sprite2D.new()
		s.texture = texs[randi() % texs.size()]
		var sc := randf_range(star_scale_min, star_scale_max)
		s.scale = Vector2(sc, sc)
		s.position = Vector2(randf_range(star_area.position.x, star_area.end.x), randf_range(star_area.position.y, star_area.end.y))
		s.rotation = randf_range(-0.3, 0.3)
		stars_root.add_child(s)
		_stars.append({"node": s, "speed": randf_range(0.7, 2.2), "phase": randf_range(0.0, TAU), "base": sc})

func _process(delta: float) -> void:
	_time += delta
	# Мерцание: прозрачность и чуть-чуть размер, у каждой своя скорость.
	for d in _stars:
		var s: Sprite2D = d["node"]
		var w := 0.5 + 0.5 * sin(_time * float(d["speed"]) + float(d["phase"]))
		s.modulate.a = lerpf(0.25, 1.0, w)
		var k := float(d["base"]) * lerpf(0.85, 1.05, w)
		s.scale = Vector2(k, k)
	# Луна колышется: чуть влево-вправо и чуть наклоняется.
	var sw := sin(_time * moon_sway_speed * TAU * 0.5)
	moon.position = _moon_base + Vector2(sw * moon_sway, 0)
	moon.pivot_offset = moon.size * 0.5
	moon.rotation = deg_to_rad(moon_tilt_deg) * sin(_time * moon_sway_speed * TAU * 0.5 + 0.8)
	# Облака едут вправо; две копии стыкуются, ушедшая за край прыгает назад.
	var w2 := size.x
	for c in clouds.get_children():
		var cr := c as Control
		if cr == null:
			continue
		cr.position.x += cloud_speed * delta
		if cr.position.x >= w2:
			cr.position.x -= w2 * 2.0

## Луна под точкой p (по её непрозрачным пикселям). Видно ли её через дом — проверяет Hub.
func moon_at(p: Vector2) -> bool:
	if moon == null or not moon.visible or moon.texture == null:
		return false
	var lp := moon.get_global_transform().affine_inverse() * p
	if not Rect2(Vector2.ZERO, moon.size).has_point(lp):
		return false
	if _moon_img == null:
		_moon_img = _moon_tex.get_image()
		if _moon_img != null and _moon_img.is_compressed():
			_moon_img.decompress()
	if _moon_img == null:
		return true
	var px := Vector2i(int(lp.x / moon.size.x * _moon_img.get_width()), int(lp.y / moon.size.y * _moon_img.get_height()))
	px = px.clamp(Vector2i.ZERO, Vector2i(_moon_img.get_width() - 1, _moon_img.get_height() - 1))
	return _moon_img.get_pixelv(px).a > 0.5

## Клик по луне: картинка переключается (homeMoon1 <-> homeMoon2) и остаётся, пока не кликнут снова.
## Выбор запоминается в сохранении (флаг MOON_ALT_FLAG). Плюс небольшое подпрыгивание.
const MOON_ALT_FLAG := "hub_moon_alt"

func moon_alt() -> bool:
	return StoryState_ != null and StoryState_.has_flag(MOON_ALT_FLAG)

func _apply_moon_texture() -> void:
	var alt := DayCycle.texture(MOON_CLICK_TEXTURE) if moon_alt() else null
	moon.texture = alt if alt != null else _moon_tex

func click_moon() -> void:
	if StoryState_ != null:
		StoryState_.set_flag(MOON_ALT_FLAG, not moon_alt())
	_apply_moon_texture()
	moon.pivot_offset = moon.size * 0.5
	var t := create_tween()
	t.tween_property(moon, "scale", Vector2(1.08, 0.94), 0.08)
	t.tween_property(moon, "scale", Vector2(0.96, 1.06), 0.1)
	t.tween_property(moon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
