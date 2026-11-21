@tool
extends Node2D
class_name HubStar
## Звёздочка на ниточке в доме (Hub.tscn → Stars → Star1…). Сам узел — точка на потолке, где
## привязана ниточка; звёздочка висит ниже на rope_length. В редакторе видно, как она висит в покое
## (двигайте узел и меняйте длину ниточки). В игре качается — физика в HubStars.gd.

@export var texture: Texture2D:
	set(v):
		texture = v
		queue_redraw()
## Длина ниточки от потолка до макушки звезды, px.
@export var rope_length := 150.0:
	set(v):
		rope_length = v
		queue_redraw()
@export var star_scale := 1.0:
	set(v):
		star_scale = v
		queue_redraw()
## Радиус для столкновений (у самой картинки), px при star_scale = 1.
@export var radius := 36.0
@export var rope_color := Color(0.10, 0.08, 0.12, 0.95)
@export var rope_width := 2.5

## Состояние (экранные координаты центра звезды), ведёт HubStars.
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var rot := 0.0
var rot_vel := 0.0
var glow := 0.0          ## 0..1 — лёгкое свечение
var touch_time := 0.0    ## сколько секунд её уже тянут
var sparkle_left := 0.0  ## сколько ещё сыпать блёстки
var particles: CPUParticles2D

## Где ниточка крепится к звезде: на столько выше центра.
func top_offset() -> float:
	return (texture.get_height() if texture != null else 80.0) * 0.43 * star_scale

func hit_radius() -> float:
	return radius * star_scale

## Длина от точки на потолке до центра звезды в покое.
func rest_length() -> float:
	return rope_length + top_offset()

func _ready() -> void:
	pos = to_global(Vector2(0, rest_length()))
	if not Engine.is_editor_hint():
		_build_particles()

func _build_particles() -> void:
	particles = CPUParticles2D.new()
	particles.name = "Sparkles"
	particles.emitting = false
	particles.local_coords = false
	particles.amount = 22
	particles.lifetime = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = hit_radius() * 0.7
	particles.direction = Vector2(0, 1)
	particles.spread = 180.0
	particles.gravity = Vector2(0, 220)
	particles.initial_velocity_min = 20.0
	particles.initial_velocity_max = 80.0
	particles.scale_amount_min = 0.12
	particles.scale_amount_max = 0.35
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.97, 0.7, 1.0))
	ramp.add_point(0.5, Color(1.0, 0.85, 0.35, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.8, 0.3, 0.0))
	particles.color_ramp = ramp
	var gt := GradientTexture2D.new()
	gt.width = 32
	gt.height = 32
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.35, Color(1, 1, 1, 0.9))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	gt.gradient = g
	particles.texture = gt
	add_child(particles)

func _draw() -> void:
	if texture == null:
		return
	var c: Vector2
	var r := 0.0
	if Engine.is_editor_hint():
		c = Vector2(0, rest_length())
	else:
		c = to_local(pos)
		r = rot
	var top := c + Vector2(0, -top_offset()).rotated(r)
	draw_line(Vector2.ZERO, top, rope_color, rope_width, true)
	var ts := texture.get_size()
	if glow > 0.01:
		# Мягкий ореол — едва заметный.
		draw_set_transform(c, r, Vector2.ONE * star_scale * 1.2)
		draw_texture(texture, -ts * 0.5, Color(1.0, 0.92, 0.55, 0.22 * glow))
	draw_set_transform(c, r, Vector2.ONE * star_scale)
	draw_texture(texture, -ts * 0.5, Color(1.0 + 0.12 * glow, 1.0 + 0.1 * glow, 1.0 + 0.02 * glow, 1.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)
