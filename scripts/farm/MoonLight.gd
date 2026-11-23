@tool
extends Node2D
class_name MoonLight
## Лунный свет из окна на ведьмочку (ферма): несколько мягких лучей и пылинки-светлячки в них.
## Лучи по очереди медленно проявляются и гаснут, пылинки плывут вдоль луча, появляются и пропадают.
##
## Всё настраивается в инспекторе (Farm.tscn → World/Moonlight и World/MoonlightBack), видно в редакторе:
##   window_rect — через какое место проходят лучи (окно), target — куда (на ведьмочку),
##   extend_back — насколько лучи продолжаются назад за окно (начало уходит за край экрана),
##   spread — разброс, length — длина после окна, width_start / width_end — толщина у окна и у конца,
##   ray_alpha — яркость, color — цвет лучей, mote_count — сколько блёсток, mote_colors / mote_weights —
##   цвета блёсток и как часто какой.
## Два узла: MoonlightBack — за ведьмочкой (между фоном и ней), Moonlight — перед ней.
## Лучи рисуются сложением цвета (как свет).

@export var window_rect: Rect2 = Rect2(260, 60, 360, 560)
@export var target: Vector2 = Vector2(1280, 760)
@export_range(0.0, 0.8) var spread: float = 0.22
@export var length: float = 1150.0
@export var extend_back: float = 1400.0
@export var width_start: float = 26.0
@export var width_end: float = 120.0
@export var ray_count: int = 6
@export_range(0.0, 1.0) var ray_alpha: float = 0.16
@export var color: Color = Color(0.45, 0.76, 1.0)
@export var mote_count: int = 26
@export var mote_size: Vector2 = Vector2(2.0, 5.0)
@export var mote_speed: float = 22.0
@export var seed_value: int = 7
## Цвета блёсток и их доли: белый и голубой чаще, синий и фиолетовый реже.
@export var mote_colors: PackedColorArray = PackedColorArray([Color(1, 1, 1), Color(0.6, 0.88, 1.0), Color(0.3, 0.45, 1.0), Color(0.72, 0.45, 1.0)])
@export var mote_weights: PackedFloat32Array = PackedFloat32Array([0.38, 0.38, 0.12, 0.12])

var _rays: Array[Dictionary] = []    ## {from, dir, w0, w1, len, speed, phase}
var _motes: Array[Dictionary] = []   ## {ray, t, life, age, size, drift}
var _time := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	_build()

func _build() -> void:
	_rng.seed = seed_value
	_rays.clear()
	_motes.clear()
	var c := window_rect.get_center()
	var base := (target - c).normalized()
	for i in range(maxi(1, ray_count)):
		var from := Vector2(_rng.randf_range(window_rect.position.x, window_rect.end.x), _rng.randf_range(window_rect.position.y, window_rect.end.y))
		var dir := base.rotated(_rng.randf_range(-spread, spread) * 0.5)
		_rays.append({
			"from": from, "dir": dir,
			"w0": width_start * _rng.randf_range(0.6, 1.3), "w1": width_end * _rng.randf_range(0.6, 1.3),
			"len": length * _rng.randf_range(0.75, 1.1),
			"speed": _rng.randf_range(0.25, 0.6), "phase": _rng.randf_range(0.0, TAU),
		})
	for i in range(maxi(0, mote_count)):
		_motes.append(_new_mote(true))

func _new_mote(random_age: bool) -> Dictionary:
	var life := _rng.randf_range(3.0, 7.0)
	return {
		"ray": _rng.randi() % maxi(1, _rays.size()),
		"t": _rng.randf_range(0.05, 0.85),
		"side": _rng.randf_range(-0.45, 0.45),
		"life": life, "age": _rng.randf_range(0.0, life) if random_age else 0.0,
		"size": _rng.randf_range(mote_size.x, mote_size.y),
		"color": _pick_mote_color(),
		"wobble": _rng.randf_range(0.0, TAU),
	}

func _pick_mote_color() -> Color:
	if mote_colors.is_empty():
		return Color.WHITE
	var total := 0.0
	for i in range(mote_colors.size()):
		total += mote_weights[i] if i < mote_weights.size() else 1.0
	var r := _rng.randf() * total
	for i in range(mote_colors.size()):
		r -= mote_weights[i] if i < mote_weights.size() else 1.0
		if r <= 0.0:
			return mote_colors[i]
	return mote_colors[mote_colors.size() - 1]

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_build()   ## в редакторе — сразу видно правки в инспекторе
	_time += delta
	for i in range(_motes.size()):
		var m: Dictionary = _motes[i]
		m["age"] = float(m["age"]) + delta
		var r: Dictionary = _rays[int(m["ray"]) % _rays.size()]
		m["t"] = float(m["t"]) + mote_speed * delta / maxf(1.0, float(r["len"]))
		if float(m["age"]) >= float(m["life"]) or float(m["t"]) > 1.0:
			_motes[i] = _new_mote(false)
	queue_redraw()

## Яркость луча сейчас (0..1): медленно проявляется и гаснет.
func _ray_level(r: Dictionary) -> float:
	var w := 0.5 + 0.5 * sin(_time * float(r["speed"]) + float(r["phase"]))
	return w * w

## Отрезок луча от a до b (толщина wa -> wb): по оси цвет ca -> cb, по краям edge.
func _ray_part(a: Vector2, b: Vector2, n: Vector2, wa: float, wb: float, ca: Color, cb: Color, edge: Color) -> void:
	draw_polygon(PackedVector2Array([a - n * wa, a, b, b - n * wb]), PackedColorArray([edge, ca, cb, edge]))
	draw_polygon(PackedVector2Array([a, a + n * wa, b + n * wb, b]), PackedColorArray([ca, edge, edge, cb]))

func _draw() -> void:
	if _rays.is_empty():
		return
	for r in _rays:
		var lvl := _ray_level(r)
		if lvl <= 0.01:
			continue
		var dir: Vector2 = r["dir"]
		var n := dir.orthogonal()
		var to: Vector2 = Vector2(r["from"]) + dir * float(r["len"])
		# Начало луча — далеко за окном (за краем экрана), чтобы его не было видно.
		var from: Vector2 = Vector2(r["from"]) - dir * extend_back
		var a := ray_alpha * lvl
		var c0 := Color(color.r, color.g, color.b, a)
		var c1 := Color(color.r, color.g, color.b, 0.0)
		var win: Vector2 = r["from"]
		var w_back := float(r["w0"]) * 0.35
		var w_win := float(r["w0"]) * 0.5
		var w_end := float(r["w1"]) * 0.5
		# До окна (из-за края экрана) — ровный свет, после окна — гаснет к концу.
		# Мягкие края: середина ярче, края прозрачные (по две половинки на отрезок).
		_ray_part(from, win, n, w_back, w_win, c0, c0, c1)
		_ray_part(win, to, n, w_win, w_end, c0, c1, c1)
	for m in _motes:
		var r: Dictionary = _rays[int(m["ray"]) % _rays.size()]
		var t := float(m["t"])
		var dir: Vector2 = r["dir"]
		var n := dir.orthogonal()
		var half := lerpf(float(r["w0"]), float(r["w1"]), t) * 0.5
		var wob := sin(_time * 1.3 + float(m["wobble"])) * 6.0
		var p: Vector2 = Vector2(r["from"]) + dir * float(r["len"]) * t + n * (float(m["side"]) * half + wob)
		var life := float(m["life"])
		var age := float(m["age"])
		var fade := clampf(minf(age, life - age) / 1.0, 0.0, 1.0) * (1.0 - t * 0.6)
		var sz := float(m["size"])
		var mc: Color = m["color"]
		draw_circle(p, sz * 1.9, Color(mc.r, mc.g, mc.b, 0.14 * fade))
		draw_circle(p, sz, Color(mc.r, mc.g, mc.b, 0.6 * fade))
