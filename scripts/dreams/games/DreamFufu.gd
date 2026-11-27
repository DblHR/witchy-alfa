extends DreamGame
## Фуфу хочет есть: бегать по полю (стрелки / WASD) и ловить тех, кто появляется (слизни, элитные
## слизни, ведьмочка, воин — без НПС). Очки и редкость — prey в dreams.json (points, weight).
## Убегают от Фуфу, когда она близко. max_prey — сколько на поле сразу.

const EAT_DIST := 90.0
const FLEE_DIST := 260.0
const FLEE_K := 0.55   ## доля скорости Фуфу, с которой убегают

var fufu: Sprite2D
var prey: Array[Sprite2D] = []
var _fufu_scale := Vector2.ONE
var next_in := 0.2

func build() -> void:
	fufu = make_sprite(char_texture("fufu"), 280)
	fufu.position = Vector2(960, 760)
	_fufu_scale = fufu.scale

func _depth(y: float) -> float:
	return lerpf(0.8, 1.05, (y - FIELD.position.y) / FIELD.size.y)

func play(delta: float) -> void:
	var speed := cf("move_speed", 560)
	var d := held_dir()
	var p := fufu.position + d * speed * delta
	fufu.position = Vector2(clampf(p.x, FIELD.position.x, FIELD.end.x), clampf(p.y, FIELD.position.y + 40, FIELD.end.y))
	if d.x != 0.0:
		fufu.flip_h = d.x > 0.0
	fufu.scale = _fufu_scale * _depth(fufu.position.y)
	fufu.z_index = int(fufu.position.y)
	next_in -= delta
	if next_in <= 0.0 and prey.size() < int(cf("max_prey", 5)):
		next_in = 0.6
		_spawn()
	for s: Sprite2D in prey.duplicate():
		var to_f: Vector2 = fufu.position - s.position
		var v: Vector2 = s.get_meta("v")
		if to_f.length() < FLEE_DIST:
			v = -to_f.normalized() * speed * FLEE_K
		elif randf() < delta * 0.8:
			v = Vector2.from_angle(randf() * TAU) * speed * 0.3
		s.set_meta("v", v)
		var np: Vector2 = s.position + v * delta
		if np.x < FIELD.position.x or np.x > FIELD.end.x:
			v.x = -v.x
		if np.y < FIELD.position.y + 40 or np.y > FIELD.end.y:
			v.y = -v.y
		s.set_meta("v", v)
		s.position = Vector2(clampf(np.x, FIELD.position.x, FIELD.end.x), clampf(np.y, FIELD.position.y + 40, FIELD.end.y))
		s.scale = Vector2(s.get_meta("base")) * _depth(s.position.y)
		s.z_index = int(s.position.y)
		if v.x != 0.0:
			s.flip_h = v.x > 0.0
		if s.position.distance_to(fufu.position) < EAT_DIST:
			_eat(s)

func _pick_kind() -> String:
	var table: Dictionary = cfg.get("prey", {"slime": {"weight": 1, "points": 1}})
	var total := 0.0
	for k in table.keys():
		total += float(table[k].get("weight", 1))
	var r := randf() * total
	for k in table.keys():
		r -= float(table[k].get("weight", 1))
		if r <= 0.0:
			return String(k)
	return String(table.keys()[0])

func _spawn() -> void:
	var kind := _pick_kind()
	var s: Sprite2D
	match kind:
		"slime":
			s = make_sprite(slime_texture(), 140)
		"elite":
			s = make_sprite(slime_texture("slime_purple"), 200)
			s.self_modulate = Color(1.0, 0.92, 1.15)
		_:
			s = make_sprite(char_texture(kind), 260)
	for tries in 10:
		s.position = Vector2(randf_range(FIELD.position.x + 40, FIELD.end.x - 40), randf_range(FIELD.position.y + 60, FIELD.end.y))
		if s.position.distance_to(fufu.position) > 380.0:
			break
	s.set_meta("kind", kind)
	s.set_meta("base", s.scale)
	s.set_meta("v", Vector2.from_angle(randf() * TAU) * 120.0)
	s.modulate.a = 0.0
	s.create_tween().tween_property(s, "modulate:a", 1.0, 0.3)
	prey.append(s)

func _eat(s: Sprite2D) -> void:
	prey.erase(s)
	var table: Dictionary = cfg.get("prey", {})
	var pts := int((table.get(String(s.get_meta("kind")), {}) as Dictionary).get("points", 1))
	add_points(pts, fufu.position + Vector2(0, -280))
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position", fufu.position + Vector2(0, -120), 0.18)
	tw.tween_property(s, "scale", s.scale * 0.1, 0.18)
	tw.chain().tween_callback(s.queue_free)
	hop(fufu, 22.0, 0.2)
