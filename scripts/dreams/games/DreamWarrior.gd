extends DreamGame
## Воин убегает от огромной Фуфу (как динозаврик): навстречу едут слизни — прыгать пробелом / W / ↑.
## Перепрыгнул — очко. Врезался — спотыкается, Фуфу подбирается ближе, очка нет.
## speed — скорость, speed_up — разгон в секунду, gap — пауза между слизнями (сек), jump_speed, gravity.

const RUNNER_X := 700.0
const GROUND := 780.0
const FUFU_X := 230.0

var warrior: Sprite2D
var fufu: Sprite2D
var obstacles: Array[Sprite2D] = []
var vy := 0.0
var y := 0.0          ## высота прыжка (0 — на земле, минус — вверх)
var speed := 0.0
var next_in := 1.0
var stumble := 0.0
var t := 0.0

func build() -> void:
	fufu = make_sprite(char_texture("fufu"), 640)
	fufu.position = Vector2(FUFU_X, GROUND + 30)
	fufu.flip_h = true
	warrior = make_sprite(char_texture("warrior"), 300)
	warrior.position = Vector2(RUNNER_X, GROUND)
	warrior.flip_h = true
	speed = cf("speed", 620)

func play(delta: float) -> void:
	t += delta
	speed += cf("speed_up", 14) * delta
	# прыжок
	if y < 0.0 or vy < 0.0:
		vy += cf("gravity", 3600) * delta
		y += vy * delta
		if y >= 0.0:
			y = 0.0
			vy = 0.0
	var bob := 0.0 if y < 0.0 else absf(sin(t * 14.0)) * -10.0
	stumble = maxf(0.0, stumble - delta)
	warrior.position = Vector2(RUNNER_X - stumble * 60.0, GROUND + y + bob)
	warrior.rotation = -0.5 * stumble
	fufu.position.y = GROUND + 30 + absf(sin(t * 7.0)) * -26.0
	fufu.position.x = lerpf(fufu.position.x, FUFU_X + (90.0 if stumble > 0.0 else 0.0), delta * 4.0)
	# слизни навстречу
	next_in -= delta
	if next_in <= 0.0:
		next_in = cf_range("gap", Vector2(1.1, 2.0))
		var s := make_sprite(slime_texture(), randf_range(90.0, 130.0))
		s.position = Vector2(2050, GROUND)
		s.set_meta("passed", false)
		s.set_meta("hit", false)
		obstacles.append(s)
	for s: Sprite2D in obstacles.duplicate():
		s.position.x -= speed * delta
		s.position.y = GROUND - absf(sin(t * 9.0 + s.position.x * 0.01)) * 12.0
		var w := float(s.texture.get_width()) * s.scale.x * 0.35
		var h := float(s.texture.get_height()) * s.scale.y * 0.7
		if not bool(s.get_meta("hit")) and absf(s.position.x - RUNNER_X) < w + 40.0 and -y < h:
			_hit(s)
		elif not bool(s.get_meta("passed")) and not bool(s.get_meta("hit")) and s.position.x < RUNNER_X - w - 40.0:
			s.set_meta("passed", true)
			add_points(1, Vector2(RUNNER_X, GROUND - 340.0))
		if s.position.x < -200.0:
			obstacles.erase(s)
			s.queue_free()

func jump() -> void:
	if y >= 0.0 and vy >= 0.0 and stumble <= 0.0:
		vy = -cf("jump_speed", 1250)
		y = -1.0

func _hit(s: Sprite2D) -> void:
	s.set_meta("hit", true)
	stumble = 0.8
	warrior.modulate = Color(1, 0.5, 0.5)
	warrior.create_tween().tween_property(warrior, "modulate", Color.WHITE, 0.5)
	float_text("Ай!", warrior.position + Vector2(0, -330), Color(1, 0.6, 0.6))
	hop(fufu, 40.0, 0.35)
