extends Control
class_name PendulumMeter
## Маятник: ползунок бегает по дуге туда-обратно (от краёв отражается, не исчезает).
## Нужно нажать в момент, когда он над зелёной зоной. Дуга рисуется по эллипсу внутри
## собственного прямоугольника, так что форму задаёт размер контрола.

signal stopped(hit: bool, accuracy: float)

@export var sweep_time: float = 1.35          ## секунд на путь от одного края до другого
@export var zone_width: float = 0.16          ## ширина зелёной зоны (доля дуги)
@export var arc_color: Color = Color(0.62, 0.40, 0.72, 0.92)
@export var zone_color: Color = Color(0.45, 0.88, 0.50, 0.95)
@export var marker_color: Color = Color(1.0, 0.92, 0.55, 1.0)
@export var from_angle_deg: float = 220.0     ## начало дуги (слева)
@export var to_angle_deg: float = 308.0       ## конец дуги (справа)
## Окружность дуги в координатах контрола (контрол растягивается на весь экран).
## Значения подогнаны под дугу, нарисованную в alchemyBG.png.
@export var arc_center: Vector2 = Vector2(607.0, 1024.0)
@export var arc_radius: float = 690.0
@export var arc_width: float = 52.0

## Картинки (если заданы — рисуются вместо простых линий):
##   arc_texture — сама дуга (assets/alchemy/alchemy_minigame.png). Окружность дуги на картинке —
##                 TEX_CENTER / TEX_RADIUS; картинка масштабируется так, чтобы совпасть с arc_center/arc_radius;
##   zone_texture — оранжевая зона, куда нужно попасть (поворачивается по дуге, длина — zone_width);
##   cursor_texture — сердечко, которое бегает по дуге.
@export var arc_texture: Texture2D
@export var zone_texture: Texture2D
@export var cursor_texture: Texture2D
## Окружность центральной линии дуги на картинке alchemy_minigame.png (пиксели картинки) и толщина полосы.
const TEX_CENTER := Vector2(597.0, 914.0)
const TEX_RADIUS := 837.5
const TEX_BAND := 58.0
## Ширина зоны на картинке зоны (пиксели) и её толщина.
const ZONE_TEX_W := 251.0
const ZONE_TEX_H := 59.0
## Размер сердечка относительно толщины полосы.
@export var cursor_scale: float = 1.9

## Секунд на путь от края до края (было 1.35).
const SWEEP_TIME := 1.1
var _active := false
var _pos := 0.0        ## 0..1 вдоль дуги
var _dir := 1.0
var _zone_center := 0.5
var _flash := 0.0
var _flash_ok := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

## С картинкой зоны ширина зоны (доля дуги) берётся из самой картинки — попадание совпадает с тем, что видно.
func _sync_zone_width() -> void:
	if arc_texture == null or zone_texture == null:
		return
	var total := deg_to_rad(absf(to_angle_deg - from_angle_deg)) * TEX_RADIUS
	if total > 0.0:
		zone_width = clampf(ZONE_TEX_W / total, 0.02, 0.9)

func begin(rng: RandomNumberGenerator, speed_scale: float = 1.0) -> void:
	_sync_zone_width()
	_zone_center = rng.randf_range(0.2, 0.8)
	_pos = 0.0 if rng.randf() < 0.5 else 1.0
	_dir = 1.0 if _pos == 0.0 else -1.0
	sweep_time = SWEEP_TIME / maxf(speed_scale, 0.2)
	_active = true
	visible = true
	set_process(true)
	queue_redraw()

func is_active() -> bool:
	return _active

func stop_meter() -> void:
	_active = false
	set_process(false)
	queue_redraw()

func hide_meter() -> void:
	stop_meter()
	visible = false

## Игрок нажал: оцениваем положение.
func submit() -> void:
	if not _active:
		return
	var dist := absf(_pos - _zone_center)
	var half := zone_width * 0.5
	var hit := dist <= half
	var accuracy := 1.0 - clampf(dist / maxf(half, 0.001), 0.0, 1.0)
	_flash = 0.35
	_flash_ok = hit
	if hit:
		stop_meter()
	queue_redraw()
	stopped.emit(hit, accuracy)

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	if _active:
		_pos += _dir * delta / maxf(sweep_time, 0.05)
		if _pos >= 1.0:
			_pos = 1.0 - (_pos - 1.0)
			_dir = -1.0
		elif _pos <= 0.0:
			_pos = -_pos
			_dir = 1.0
		_pos = clampf(_pos, 0.0, 1.0)
	queue_redraw()
	if not _active and _flash <= 0.0:
		set_process(false)

func _point_at(t: float) -> Vector2:
	var a := deg_to_rad(lerpf(from_angle_deg, to_angle_deg, t))
	return arc_center + Vector2(cos(a), sin(a)) * arc_radius

func _draw_arc_range(t0: float, t1: float, color: Color, width: float) -> void:
	var steps := maxi(4, int(80.0 * absf(t1 - t0)))
	var pts := PackedVector2Array()
	for i in range(steps + 1):
		pts.append(_point_at(lerpf(t0, t1, float(i) / float(steps))))
	draw_polyline(pts, color, width, true)

func _draw() -> void:
	if arc_texture != null:
		_draw_textured()
		return
	var w := arc_width
	_draw_arc_range(0.0, 1.0, Color(0.1, 0.05, 0.14, 0.97), w + 12.0)
	_draw_arc_range(0.0, 1.0, arc_color, w)
	var z0 := clampf(_zone_center - zone_width * 0.5, 0.0, 1.0)
	var z1 := clampf(_zone_center + zone_width * 0.5, 0.0, 1.0)
	_draw_arc_range(z0, z1, zone_color, w)
	var p := _point_at(_pos)
	var col := marker_color
	if _flash > 0.0:
		col = zone_color if _flash_ok else Color(1.0, 0.35, 0.35, 1.0)
	draw_circle(p, w * 0.95, Color(0.08, 0.04, 0.12, 0.9))
	draw_circle(p, w * 0.7, col)

## Вид с картинками: дуга, оранжевая зона поверх, сердечко-курсор.
func _draw_textured() -> void:
	var k := arc_radius / TEX_RADIUS
	draw_texture_rect(arc_texture, Rect2(arc_center - TEX_CENTER * k, arc_texture.get_size() * k), false)
	var band := TEX_BAND * k
	var z0 := clampf(_zone_center - zone_width * 0.5, 0.0, 1.0)
	var z1 := clampf(_zone_center + zone_width * 0.5, 0.0, 1.0)
	var zone_col := Color.WHITE
	if _flash > 0.0 and _flash_ok:
		zone_col = Color(1.4, 1.4, 1.1, 1.0)
	if zone_texture != null:
		var zc := (z0 + z1) * 0.5
		var ang := deg_to_rad(lerpf(from_angle_deg, to_angle_deg, zc))
		# Зона — в своём размере (подогнана под дорожку), только общий масштаб дуги.
		draw_set_transform(_point_at(zc), ang + PI * 0.5, Vector2(k, k))
		var zs := zone_texture.get_size()
		draw_texture(zone_texture, -zs * 0.5, zone_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		_draw_arc_range(z0, z1, zone_color, band)
	var p := _point_at(_pos)
	var col := Color.WHITE
	if _flash > 0.0:
		col = Color(0.7, 1.3, 0.7, 1.0) if _flash_ok else Color(1.3, 0.45, 0.45, 1.0)
	if cursor_texture != null:
		var cs := cursor_texture.get_size()
		var h := band * cursor_scale
		var csize := Vector2(cs.x / cs.y * h, h)
		draw_texture_rect(cursor_texture, Rect2(p - csize * 0.5, csize), false, col)
	else:
		draw_circle(p, band * 0.7, marker_color * col)
