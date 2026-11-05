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

var _active := false
var _pos := 0.0        ## 0..1 вдоль дуги
var _dir := 1.0
var _zone_center := 0.5
var _flash := 0.0
var _flash_ok := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)

func begin(rng: RandomNumberGenerator, speed_scale: float = 1.0) -> void:
	_zone_center = rng.randf_range(0.2, 0.8)
	_pos = 0.0 if rng.randf() < 0.5 else 1.0
	_dir = 1.0 if _pos == 0.0 else -1.0
	sweep_time = 1.35 / maxf(speed_scale, 0.2)
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
