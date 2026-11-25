extends Node2D
class_name HomeWalker
## Персонаж в доме (Hub): ходит по маршрутам HomeRoute туда-сюда, на стыках иногда переходит на
## другую линию, на кровати делает своё действие (прыгает / лежит), подпрыгивает по клику, его можно
## перетащить мышкой и поставить на любое место маршрута. Позиция узла = ноги.

## Действие на кровати: "jump" — прыгает, "lie" — лежит (пока картинка смерти <id>_dead.png).
const BED_ACTIONS := {"witch": "jump", "warrior": "jump", "aki": "jump", "fufu": "lie", "luisa": "lie"}
## Рост персонажа на экране, px (от макушки до пяток), одинаковый на обоих этажах.
## Отдельно для каждого — множитель в data/characters/sizes.json (CharSizes).
const HEIGHT_PX := 440.0
const WALK_SPEED_MIN := 80.0
const WALK_SPEED_MAX := 130.0
const IDLE_MIN := 1.4
const IDLE_MAX := 4.0
## Шанс после паузы пойти к концу линии (а там — шанс перейти на соседнюю линию).
const CHANCE_GO_TO_END := 0.4
const CHANCE_SWITCH_LINE := 0.65
## Шанс, стоя у кровати, запрыгнуть на неё (если линия кровати рядом).
const CHANCE_BED := 0.5
## Чем больше народу уже на кровати, тем охотнее туда прыгают: + столько за каждого
## (и с таким же шансом за каждого идут к краю линии, где кровать).
const BED_CROWD_BONUS := 0.2
## На кровати рядом друг с другом: сдвиг по x для каждого следующего.
const BED_CROWD_SHIFT := 70.0
const BED_TIME_MIN := 6.0
const BED_TIME_MAX := 12.0
const STEP_BOB := 6.0
const STEP_PERIOD := 0.32
const HOP_HEIGHT := 44.0
const HOP_TIME := 0.42
const BREATH := 0.012
const BREATH_PERIOD := 2.4

## Бросок (отпустили, пока тащили): летит со скоростью курсора, падает, отскакивает от пола,
## приземляется на линию маршрута под собой (Hub.floor_crossing).
const GRAVITY := 3600.0
const THROW_MAX := 1400.0          ## быстрее не летит, px/с
const THROW_KEEP := 0.75           ## какая доля скорости курсора достаётся персонажу
const AIR_DRAG := 1.35             ## торможение в воздухе по горизонтали (доля в секунду)
const BOUNCE := 0.25               ## отскок от пола: доля вертикальной скорости
const BOUNCE_MIN_VY := 450.0       ## медленнее — уже не отскакивает, приземляется
const WALL_BOUNCE := 0.5           ## отскок от краёв экрана
const AIR_TILT := 0.00028          ## наклон в полёте от горизонтальной скорости
const FLY_BOUNDS := Rect2(40, -600, 1840, 1720)

signal route_changed(walker: HomeWalker)

var unit_id := ""
var body: Sprite2D
var badge_anchor: Control
var base_tex: Texture2D
var bed_tex: Texture2D        ## картинка «лежит» (или null — тогда прыгает)
var home: Node                ## Hub: routes, layer_for(route), connections_at(route, at_end)
var route: HomeRoute
var dist := 0.0

enum State { IDLE, WALK, HOP, BED, DRAG, FALL, FROZEN, FLY }
var state := State.IDLE

var _scale := 1.0
var _target := 0.0
var _speed := 100.0
var _go_end := -1              ## 0 — идёт к началу линии, 1 — к концу, -1 — просто гуляет
var _idle_left := 1.0
var _t := 0.0
var _tween: Tween
var _bed_left := 0.0
var _hover := false
var _poke_tex: Texture2D
var _drag_offset := Vector2.ZERO
var _vel := Vector2.ZERO
var _fly_time := 0.0
var _drag_samples: Array = []   ## [время, точка] — скорость курсора для броска
var _last_x := 0.0
var _lying := false             ## лежит (lie_down) — встаёт по stand_up, разморозке или если схватили

func setup(p_id: String, tex: Texture2D, p_home: Node) -> void:
	unit_id = p_id
	name = "Walker_" + p_id
	base_tex = tex
	home = p_home
	body = Sprite2D.new()
	body.name = "Body"
	body.texture = tex
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(body)
	var feet := _feet_y(tex)
	var top := _top_y(tex)
	_scale = HEIGHT_PX * CharSizes.scale_of(p_id) / maxf(1.0, feet - top)
	body.scale = Vector2(_scale, _scale)
	body.offset = Vector2(-tex.get_width() * 0.5, -feet)
	badge_anchor = Control.new()
	badge_anchor.name = "BadgeAnchor"
	badge_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_anchor.size = Vector2(1, 1)
	badge_anchor.position = Vector2(-20, -HEIGHT_PX * CharSizes.scale_of(p_id) - 50)
	add_child(badge_anchor)
	if String(BED_ACTIONS.get(p_id, "jump")) == "lie":
		bed_tex = CharacterPhases.dead_texture(tex)
	_last_x = position.x

## Поставить на линию route в точку d.
func place(r: HomeRoute, d: float) -> void:
	route = r
	dist = d
	position = r.point_at(d)
	route_changed.emit(self)

func _ready() -> void:
	_idle_left = randf_range(0.3, 1.5)

# --- Каждый кадр: ходьба / пауза / дыхание ------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	match state:
		State.IDLE:
			_breathe()
			_idle_left -= delta
			if _idle_left <= 0.0:
				_decide()
		State.WALK:
			_walk_step(delta)
		State.FLY:
			_fly_step(delta)
		State.BED:
			_bed_left -= delta
			if bed_tex != null and body.texture == bed_tex:
				_breathe()
			if _bed_left <= 0.0:
				_leave_bed()
		_:
			pass

func _breathe() -> void:
	var s := 1.0 + BREATH * (0.5 - 0.5 * cos(_t * TAU / BREATH_PERIOD))
	body.scale = Vector2(_scale, _scale * s)
	body.position.y = 0.0

func _walk_step(delta: float) -> void:
	var dir := signf(_target - dist)
	dist = move_toward(dist, _target, _speed * delta)
	position = route.point_at(dist)
	# Смотрит, куда идёт (картинки смотрят влево; flip_h — вправо).
	if absf(position.x - _last_x) > 0.05:
		_face_right(position.x > _last_x)
	_last_x = position.x
	body.position.y = -absf(sin(_t * PI / STEP_PERIOD)) * STEP_BOB
	body.scale = Vector2(_scale, _scale)
	if is_equal_approx(dist, _target) or dir == 0.0:
		body.position.y = 0.0
		_arrived()

func _face_right(right: bool) -> void:
	body.flip_h = right

# --- Решения -------------------------------------------------------------------------

func _decide() -> void:
	if route == null:
		return
	if route.action == "bed":
		_leave_bed()
		return
	# Есть событие с этим персонажем на его линии (HubEvents, "seek") — пойти к тому месту.
	var events = home.get("events") if home != null else null
	if events != null:
		var sd: float = events.seek_dist(self)
		if sd >= 0.0:
			_go_end = -1
			_walk_to(sd)
			return
	# Кто-то уже на кровати — тянет туда же (если кровать у края этой линии).
	var crowd: int = home.bed_occupants() if home != null and home.has_method("bed_occupants") else 0
	if crowd > 0:
		for end in [0, 1]:
			var opts: Array = home.connections_at(route, end == 1)
			if opts.any(func(o) -> bool: return (o[0] as HomeRoute).action == "bed") and randf() < BED_CROWD_BONUS * crowd:
				_go_end = end
				_walk_to(0.0 if end == 0 else route.length())
				return
	if randf() < CHANCE_GO_TO_END:
		_go_end = 0 if randf() < 0.5 else 1
		_walk_to(0.0 if _go_end == 0 else route.length())
	else:
		_go_end = -1
		var L := route.length()
		var t := randf_range(0.0, L)
		if absf(t - dist) < minf(120.0, L * 0.4):
			t = clampf(dist + (1.0 if randf() < 0.5 else -1.0) * minf(220.0, L * 0.6), 0.0, L)
		_walk_to(t)

func _walk_to(d: float) -> void:
	_target = clampf(d, 0.0, route.length())
	_speed = randf_range(WALK_SPEED_MIN, WALK_SPEED_MAX)
	state = State.WALK

func _arrived() -> void:
	if _go_end >= 0:
		var at_end := _go_end == 1
		_go_end = -1
		var options: Array = home.connections_at(route, at_end)
		var beds := options.filter(func(o) -> bool: return (o[0] as HomeRoute).action == "bed")
		var walks := options.filter(func(o) -> bool: return (o[0] as HomeRoute).action != "bed")
		var crowd: int = home.bed_occupants() if home.has_method("bed_occupants") else 0
		if not beds.is_empty() and randf() < minf(0.95, CHANCE_BED + BED_CROWD_BONUS * crowd):
			_go_to_bed(beds[0][0])
			return
		if not walks.is_empty() and randf() < CHANCE_SWITCH_LINE:
			var o: Array = walks[randi() % walks.size()]
			var r: HomeRoute = o[0]
			var from_start: bool = o[1]
			place(r, 0.0 if from_start else r.length())
			# Сразу пройти по новой линии.
			_go_end = -1
			var L := r.length()
			_walk_to(randf_range(L * 0.3, L) if from_start else randf_range(0.0, L * 0.7))
			return
	_idle(randf_range(IDLE_MIN, IDLE_MAX))

func _idle(t: float) -> void:
	state = State.IDLE
	_idle_left = t

# --- Прыжки --------------------------------------------------------------------------

func hop(double: bool = false, then_state: int = State.IDLE) -> void:
	_kill_tween()
	state = State.HOP
	body.position.y = 0.0
	_tween = create_tween()
	var hops := 2 if double else 1
	for i in range(hops):
		var h := HOP_HEIGHT * (1.0 if i == 0 else 0.6)
		_squash_hop(_tween, h)
	_tween.tween_callback(func() -> void:
		if then_state == State.BED:
			state = State.BED
		else:
			_idle(randf_range(IDLE_MIN * 0.6, IDLE_MAX * 0.6)))

func _squash_hop(tw: Tween, h: float) -> void:
	tw.tween_property(body, "scale", Vector2(_scale * 1.06, _scale * 0.92), 0.08)
	tw.tween_property(body, "scale", Vector2(_scale * 0.96, _scale * 1.05), 0.06)
	tw.parallel().tween_property(body, "position:y", -h, HOP_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "position:y", 0.0, HOP_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(body, "scale", Vector2(_scale, _scale), HOP_TIME * 0.5)
	tw.tween_property(body, "scale", Vector2(_scale * 1.05, _scale * 0.95), 0.06)
	tw.tween_property(body, "scale", Vector2(_scale, _scale), 0.1)

## Клик: подпрыгнуть (на кровати — нет). alt — картинка на время прыжка (ведьмочка: фаза 2).
func poke(alt: Texture2D = null, hold: float = 1.1) -> void:
	if state in [State.BED, State.DRAG, State.FALL, State.FROZEN, State.HOP] or _poke_tex != null:
		return
	if alt != null:
		_poke_tex = body.texture
		body.texture = alt
		get_tree().create_timer(hold).timeout.connect(func() -> void:
			if is_instance_valid(body) and _poke_tex != null:
				body.texture = _poke_tex
			_poke_tex = null)
	hop(false)

# --- Кровать -------------------------------------------------------------------------

func _go_to_bed(bed: HomeRoute) -> void:
	_kill_tween()
	var from := position
	var crowd: int = home.bed_occupants() if home.has_method("bed_occupants") else 0
	place(bed, bed.length())
	position = from
	var to := bed.end_point() + Vector2(-BED_CROWD_SHIFT * crowd, 0)
	_face_right(to.x > from.x)
	state = State.HOP
	_tween = create_tween()
	_tween.tween_method(func(k: float) -> void:
		position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 70.0), 0.0, 1.0, 0.5)
	_tween.tween_callback(_start_bed_action)

func _start_bed_action() -> void:
	state = State.BED
	_bed_left = randf_range(BED_TIME_MIN, BED_TIME_MAX)
	_kill_tween()
	if bed_tex != null:
		body.texture = bed_tex
		body.offset = Vector2(-bed_tex.get_width() * 0.5, -_feet_y(bed_tex))
		body.position.y = 0.0
		return
	# Прыгает на кровати: серии прыжков с паузами.
	_tween = create_tween().set_loops()
	for i in range(3):
		_squash_hop(_tween, HOP_HEIGHT * 1.5)
	_tween.tween_interval(0.9)

func _leave_bed() -> void:
	_kill_tween()
	body.texture = base_tex
	body.offset = Vector2(-base_tex.get_width() * 0.5, -_feet_y(base_tex))
	body.position.y = 0.0
	body.scale = Vector2(_scale, _scale)
	# Спрыгнуть к началу линии кровати и перейти на ту линию, что там стыкуется.
	var bed := route
	var to := bed.start_point()
	var options: Array = home.connections_at(bed, false)
	var walks := options.filter(func(o) -> bool: return (o[0] as HomeRoute).action != "bed")
	var from := position
	_face_right(to.x > from.x)
	state = State.HOP
	_tween = create_tween()
	_tween.tween_method(func(k: float) -> void:
		position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 60.0), 0.0, 1.0, 0.45)
	_tween.tween_callback(func() -> void:
		if walks.is_empty():
			place(bed, 0.0)
		else:
			var o: Array = walks[0]
			var r: HomeRoute = o[0]
			place(r, 0.0 if bool(o[1]) else r.length())
		_idle(randf_range(IDLE_MIN, IDLE_MAX)))

func on_bed() -> bool:
	return state == State.BED or (route != null and route.action == "bed")

# --- Перетаскивание ------------------------------------------------------------------

func begin_drag(mouse: Vector2) -> void:
	_kill_tween()
	_lying = false
	body.rotation = 0.0
	if body.texture != base_tex:
		body.texture = base_tex
		body.offset = Vector2(-base_tex.get_width() * 0.5, -_feet_y(base_tex))
	_poke_tex = null
	state = State.DRAG
	_drag_samples.clear()
	_drag_offset = position - mouse
	body.position.y = 0.0
	body.scale = Vector2(_scale, _scale)

func drag_to(mouse: Vector2) -> void:
	var to := mouse + _drag_offset
	var now := Time.get_ticks_msec() / 1000.0
	_drag_samples.append([now, to])
	while _drag_samples.size() > 2 and now - float(_drag_samples[0][0]) > 0.1:
		_drag_samples.pop_front()
	# Покачивается за курсором.
	body.rotation = lerpf(body.rotation, clampf((to.x - position.x) * 0.012, -0.35, 0.35), 0.3)
	position = to

## Скорость курсора за последние ~0.1 с (держали неподвижно — 0).
func throw_velocity() -> Vector2:
	if _drag_samples.size() < 2:
		return Vector2.ZERO
	var now := Time.get_ticks_msec() / 1000.0
	var last: Array = _drag_samples[_drag_samples.size() - 1]
	if now - float(last[0]) > 0.08:
		return Vector2.ZERO
	var first: Array = _drag_samples[0]
	var dt := float(last[0]) - float(first[0])
	if dt <= 0.001:
		return Vector2.ZERO
	return ((last[1] as Vector2) - (first[1] as Vector2)) / dt * THROW_KEEP

## Отпустили: полетели (с нулевой скоростью — просто падает вниз).
func throw(v: Vector2) -> void:
	_kill_tween()
	_drag_samples.clear()
	_vel = v.limit_length(THROW_MAX)
	_fly_time = 0.0
	state = State.FLY
	route_changed.emit(self)

func _fly_step(delta: float) -> void:
	_fly_time += delta
	var prev := position
	_vel.y += GRAVITY * delta
	_vel.x *= maxf(0.0, 1.0 - AIR_DRAG * delta)
	position += _vel * delta
	body.rotation = lerpf(body.rotation, clampf(_vel.x * AIR_TILT, -0.6, 0.6), 0.25)
	if position.x < FLY_BOUNDS.position.x or position.x > FLY_BOUNDS.end.x:
		position.x = clampf(position.x, FLY_BOUNDS.position.x, FLY_BOUNDS.end.x)
		_vel.x = -_vel.x * WALL_BOUNCE
	if position.y < FLY_BOUNDS.position.y:
		position.y = FLY_BOUNDS.position.y
		_vel.y = absf(_vel.y) * WALL_BOUNCE
	if position.x != prev.x:
		_face_right(position.x > prev.x)
	# Упал ниже всего или летает слишком долго — на ближайшее место маршрута.
	if position.y > FLY_BOUNDS.end.y or _fly_time > 5.0:
		var spot: Array = home.nearest_spot(position)
		if spot[0] != null:
			drop(spot[0], float(spot[1]))
		return
	if _vel.y <= 0.0:
		return
	var hit: Array = home.floor_crossing(prev, position)
	if hit.is_empty():
		return
	var r: HomeRoute = hit[0]
	position.y = float(hit[2])
	if _vel.y > BOUNCE_MIN_VY and r.action != "bed":
		_vel.y = -_vel.y * BOUNCE
		_vel.x *= 0.6
		var tw := create_tween()
		tw.tween_property(body, "scale", Vector2(_scale * 1.1, _scale * 0.88), 0.05)
		tw.tween_property(body, "scale", Vector2(_scale, _scale), 0.1)
		return
	_land(r, float(hit[1]))

## Приземлился на линию r в точку d: присесть и стоять (на кровати — её действие).
func _land(r: HomeRoute, d: float) -> void:
	_vel = Vector2.ZERO
	route = r
	dist = r.length() if r.action == "bed" else d
	position = r.point_at(dist)
	state = State.FALL
	route_changed.emit(self)
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(body, "rotation", 0.0, 0.12)
	_tween.parallel().tween_property(body, "scale", Vector2(_scale * 1.1, _scale * 0.88), 0.07)
	_tween.tween_property(body, "scale", Vector2(_scale, _scale), 0.14)
	_tween.tween_callback(func() -> void:
		_last_x = position.x
		if r.action == "bed":
			_start_bed_action()
		else:
			_idle(randf_range(IDLE_MIN, IDLE_MAX)))

## Отпустили: упасть на ближайшее место маршрута (на кровати — сразу её действие).
func drop(r: HomeRoute, d: float) -> void:
	var from := position
	route = r
	dist = d
	var to := r.point_at(d) if r.action != "bed" else r.end_point()
	if r.action == "bed":
		dist = r.length()
	route_changed.emit(self)
	position = from
	state = State.FALL
	_kill_tween()
	_tween = create_tween()
	var t := clampf(from.distance_to(to) / 900.0, 0.15, 0.45)
	_tween.tween_property(self, "position", to, t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(body, "rotation", 0.0, t)
	_tween.tween_property(body, "scale", Vector2(_scale * 1.08, _scale * 0.9), 0.07)
	_tween.tween_property(body, "scale", Vector2(_scale, _scale), 0.12)
	_tween.tween_callback(func() -> void:
		_last_x = position.x
		if r.action == "bed":
			_start_bed_action()
		else:
			_idle(randf_range(IDLE_MIN, IDLE_MAX)))

# --- Для событий (HubEvents): персонаж «заморожен», двигается по сценарию ---------------

## Лечь (картинка смерти <id>_dead.png; нет её — просто завалиться набок). Встать — stand_up().
func lie_down() -> void:
	_kill_tween()
	_lying = true
	body.position.y = 0.0
	body.scale = Vector2(_scale, _scale)
	var t: Texture2D = bed_tex if bed_tex != null else CharacterPhases.dead_texture(base_tex)
	if t != null:
		body.texture = t
		body.offset = Vector2(-t.get_width() * 0.5, -_feet_y(t))
		body.rotation = 0.0
	else:
		body.rotation = PI * 0.45 * (1.0 if body.flip_h else -1.0)

func stand_up() -> void:
	_kill_tween()
	_lying = false
	body.rotation = 0.0
	if body.texture != base_tex:
		body.texture = base_tex
		body.offset = Vector2(-base_tex.get_width() * 0.5, -_feet_y(base_tex))
	body.scale = Vector2(_scale, _scale)
	_tween = create_tween()
	_squash_hop(_tween, HOP_HEIGHT * 0.5)

## Плавно исчезнуть / появиться (ушёл за дверь / вернулся). await fade(...)
func fade(to_alpha: float, time: float = 0.6) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", to_alpha, time)
	await _tween.finished

## Подпрыгнуть на месте (не меняя состояния). await event_hop()
func event_hop() -> void:
	_kill_tween()
	body.position.y = 0.0
	_tween = create_tween()
	_squash_hop(_tween, HOP_HEIGHT)
	await _tween.finished

## Дойти до точки d линии r: по своей линии — пешком, на другую — прыжком. await event_move(...)
func event_move(r: HomeRoute, d: float) -> void:
	_kill_tween()
	var from := position
	var to := r.point_at(d)
	_face_right(to.x > from.x)
	if from.distance_to(to) < 4.0:
		return
	_tween = create_tween()
	if r == route:
		var d0 := dist
		var t := absf(d - d0) / WALK_SPEED_MAX
		_tween.tween_method(func(k: float) -> void:
			dist = lerpf(d0, d, k)
			position = route.point_at(dist)
			body.position.y = -absf(sin(k * t * PI / STEP_PERIOD)) * STEP_BOB, 0.0, 1.0, maxf(0.15, t))
	else:
		route = r
		dist = d
		route_changed.emit(self)
		_tween.tween_method(func(k: float) -> void:
			position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 60.0), 0.0, 1.0, clampf(from.distance_to(to) / 600.0, 0.3, 0.8))
	await _tween.finished
	body.position.y = 0.0
	dist = d
	_last_x = position.x

## Уйти в дверной проём: дойти до точки to (вглубь проёма), уменьшаясь, темнея и растворяясь.
## back = true — наоборот: появиться в проёме (from = to) и выйти к текущей позиции. await walk_door(...)
const DOOR_SHRINK := 0.82
const DOOR_DARK := Color(0.35, 0.33, 0.5, 0.0)
func walk_door(door: Vector2, time: float = 1.4, back: bool = false) -> void:
	_kill_tween()
	var near := position
	var far := Vector2(door.x, door.y)
	var big := Vector2(_scale, _scale)
	var small := big * DOOR_SHRINK
	_face_right((far.x > near.x) if not back else (near.x > far.x))
	if back:
		position = far
		body.scale = small
		modulate = DOOR_DARK
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "position", near if back else far, time)
	_tween.tween_property(body, "scale", big if back else small, time)
	_tween.tween_property(self, "modulate", Color.WHITE if back else DOOR_DARK, time).set_ease(Tween.EASE_IN if not back else Tween.EASE_OUT)
	# Шаги — покачивание вверх-вниз.
	var steps := maxi(2, roundi(time / 0.32))
	var bob := create_tween()
	for i in steps:
		bob.tween_property(body, "position:y", -10.0, time / float(steps) * 0.5)
		bob.tween_property(body, "position:y", 0.0, time / float(steps) * 0.5)
	await _tween.finished
	if is_instance_valid(bob):
		bob.kill()
	body.position.y = 0.0

## Повернуться лицом к x.
func face_toward(x: float) -> void:
	if absf(x - position.x) > 2.0:
		_face_right(x > position.x)

# --- Разное --------------------------------------------------------------------------

func is_lying() -> bool:
	return _lying

## Замереть на время разговора и продолжить. Уже замер (событие) — так и остаётся «как было до
## события». Лежал (уснул, упал) и его разморозили (например, поговорили) — сначала встаёт.
func set_frozen(on: bool) -> void:
	if on:
		if state == State.WALK:
			body.position.y = 0.0
		if state != State.FROZEN:
			set_meta("frozen_from", state)
		state = State.FROZEN
	elif state == State.FROZEN:
		var was := int(get_meta("frozen_from", State.IDLE))
		state = State.BED if was == State.BED else State.IDLE
		_idle_left = randf_range(0.6, 1.5)
		if _lying and state != State.BED:
			stand_up()
			_idle_left = maxf(_idle_left, 0.8)

## Продолжить идти к точке d своей линии (после события: столкнулись, встали — идут дальше).
func resume_walk(d: float) -> void:
	if route == null or state != State.IDLE:
		return
	_go_end = -1
	_walk_to(d)

## Куда идёт по линии: +1 — к концу, -1 — к началу, 0 — стоит.
func walk_dir() -> float:
	return signf(_target - dist) if state == State.WALK else 0.0

func walk_target() -> float:
	return _target

## Точка над макушкой (для пузыря реплики) — дочерний узел, едет вместе с персонажем.
var _head: Node2D

func head_anchor() -> Node2D:
	if _head == null:
		_head = Node2D.new()
		_head.name = "HeadAnchor"
		add_child(_head)
	if body != null and body.texture != null:
		var r := body.get_rect()
		var top := r.position.y + _top_y(body.texture)
		_head.position = body.position + Vector2(0, top * body.scale.y - 24.0)
	return _head

## Курсор над непрозрачной частью картинки.
func is_over(global_point: Vector2) -> bool:
	if body == null or body.texture == null or not visible:
		return false
	var lp := body.to_local(global_point)
	var r := body.get_rect()
	if not r.has_point(lp):
		return false
	return body.is_pixel_opaque(lp)

func set_hover(on: bool) -> void:
	if on == _hover:
		return
	_hover = on
	HoverOutline.set_on(body, on)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null

# --- Границы картинки (где ноги, где макушка) -----------------------------------------
static var _feet_cache: Dictionary = {}

static func _bbox(tex: Texture2D) -> Rect2i:
	if _feet_cache.has(tex):
		return _feet_cache[tex]
	var r := Rect2i(0, 0, tex.get_width(), tex.get_height())
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		r = img.get_used_rect()
	_feet_cache[tex] = r
	return r

static func _feet_y(tex: Texture2D) -> float:
	var r := _bbox(tex)
	return float(r.position.y + r.size.y)

static func _top_y(tex: Texture2D) -> float:
	return float(_bbox(tex).position.y)
