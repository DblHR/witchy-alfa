extends Node2D
class_name HomeWalker
## Персонаж в доме (Hub): ходит по маршрутам HomeRoute туда-сюда, на стыках иногда переходит на
## другую линию, на кровати делает своё действие (прыгает / лежит), подпрыгивает по клику, его можно
## перетащить мышкой и поставить на любое место маршрута. Позиция узла = ноги.

## Действие на кровати: "jump" — прыгает, "lie" — лежит (пока картинка смерти <id>_dead.png).
const BED_ACTIONS := {"witch": "jump", "warrior": "jump", "aki": "jump", "fufu": "lie", "luisa": "lie"}
## Рост персонажа на экране, px (от макушки до пяток), одинаковый на обоих этажах.
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
const BED_TIME_MIN := 6.0
const BED_TIME_MAX := 12.0
const STEP_BOB := 6.0
const STEP_PERIOD := 0.32
const HOP_HEIGHT := 44.0
const HOP_TIME := 0.42
const BREATH := 0.012
const BREATH_PERIOD := 2.4

signal route_changed(walker: HomeWalker)

var unit_id := ""
var body: Sprite2D
var badge_anchor: Control
var base_tex: Texture2D
var bed_tex: Texture2D        ## картинка «лежит» (или null — тогда прыгает)
var home: Node                ## Hub: routes, layer_for(route), connections_at(route, at_end)
var route: HomeRoute
var dist := 0.0

enum State { IDLE, WALK, HOP, BED, DRAG, FALL, FROZEN }
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
var _last_x := 0.0

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
	_scale = HEIGHT_PX / maxf(1.0, feet - top)
	body.scale = Vector2(_scale, _scale)
	body.offset = Vector2(-tex.get_width() * 0.5, -feet)
	badge_anchor = Control.new()
	badge_anchor.name = "BadgeAnchor"
	badge_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_anchor.size = Vector2(1, 1)
	badge_anchor.position = Vector2(-20, -HEIGHT_PX - 50)
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
		if not beds.is_empty() and randf() < CHANCE_BED:
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
	place(bed, bed.length())
	position = from
	var to := bed.end_point()
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
	if body.texture != base_tex:
		body.texture = base_tex
		body.offset = Vector2(-base_tex.get_width() * 0.5, -_feet_y(base_tex))
	_poke_tex = null
	state = State.DRAG
	_drag_offset = position - mouse
	body.position.y = 0.0
	body.scale = Vector2(_scale, _scale)

func drag_to(mouse: Vector2) -> void:
	var to := mouse + _drag_offset
	# Покачивается за курсором.
	body.rotation = lerpf(body.rotation, clampf((to.x - position.x) * 0.012, -0.35, 0.35), 0.3)
	position = to

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

# --- Разное --------------------------------------------------------------------------

## Замереть на время разговора и продолжить.
func set_frozen(on: bool) -> void:
	if on:
		if state == State.WALK:
			body.position.y = 0.0
		set_meta("frozen_from", state)
		state = State.FROZEN
	elif state == State.FROZEN:
		var was := int(get_meta("frozen_from", State.IDLE))
		state = State.BED if was == State.BED else State.IDLE
		_idle_left = randf_range(0.6, 1.5)

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
