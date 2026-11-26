extends DreamGame
## Аки лечит всех подряд: Аки парит сверху, внизу идут «пациенты» (слизни, Луиса, ведьмочка, воин…).
## ↓ / S — бросить лечебную слизь. Попала в пациента — очко. Но если внизу Фуфу — не бросать:
## попала в Фуфу — таймер минус fufu_penalty секунд.
## fufu_chance, walk_speed [от, до], spawn_every [от, до], throw_speed.

const GOO := "res://assets/items/loot/slime_goop.png"
const AKI_POS := Vector2(960, 400)
const GROUND := 780.0
const HIT_W := 90.0
const THROW_COOLDOWN := 0.3
const PATIENTS := ["slime", "slime", "luisa", "witch", "warrior"]

var aki: Sprite2D
var patients: Array[Sprite2D] = []
var blobs: Array[Sprite2D] = []
var next_in := 0.5
var cooldown := 0.0
var t := 0.0

func build() -> void:
	aki = make_sprite(char_texture("aki"), 300)
	aki.position = AKI_POS

func play(delta: float) -> void:
	t += delta
	aki.position = AKI_POS + Vector2(sin(t * 1.3) * 30.0, sin(t * 2.6) * 10.0)
	cooldown = maxf(0.0, cooldown - delta)
	next_in -= delta
	if next_in <= 0.0:
		next_in = cf_range("spawn_every", Vector2(0.9, 1.6))
		_spawn()
	for p: Sprite2D in patients.duplicate():
		p.position.x += float(p.get_meta("v")) * delta
		p.position.y = GROUND - absf(sin(t * 8.0 + p.position.x * 0.01)) * 10.0
		if p.position.x < -200.0 or p.position.x > 2120.0:
			patients.erase(p)
			p.queue_free()
	for b: Sprite2D in blobs.duplicate():
		b.position.y += cf("throw_speed", 1300) * delta
		b.rotation += delta * 6.0
		if b.position.y >= GROUND - 120.0:
			blobs.erase(b)
			_land(b)

func _spawn() -> void:
	var is_fufu := randf() < cf("fufu_chance", 0.22)
	var kind: String = "fufu" if is_fufu else PATIENTS[randi() % PATIENTS.size()]
	var tex := slime_texture() if kind == "slime" else char_texture(kind)
	var p := make_sprite(tex, 170.0 if kind == "slime" else 290.0)
	var from_left := randf() < 0.5
	p.position = Vector2(-150.0 if from_left else 2070.0, GROUND)
	var v := cf_range("walk_speed", Vector2(260, 420))
	p.set_meta("v", v if from_left else -v)
	p.set_meta("kind", kind)
	p.set_meta("healed", false)
	p.flip_h = not from_left
	patients.append(p)

func key(dir: Vector2i) -> void:
	if dir != Vector2i.DOWN or cooldown > 0.0:
		return
	cooldown = THROW_COOLDOWN
	var b := make_icon(load(GOO) as Texture2D, 60)
	b.position = aki.position + Vector2(0, -40)
	b.z_index = 10
	blobs.append(b)
	hop(aki, 12.0, 0.15)

func _land(b: Sprite2D) -> void:
	var target: Sprite2D = null
	for p in patients:
		if not bool(p.get_meta("healed")) and absf(p.position.x - b.position.x) < HIT_W:
			target = p
			break
	poof(b, 0.2)
	if target == null:
		return
	target.set_meta("healed", true)
	if String(target.get_meta("kind")) == "fufu":
		screen.add_time(-cf("fufu_penalty", 5))
		float_text("Эй! −%d сек" % int(cf("fufu_penalty", 5)), target.position + Vector2(0, -280), Color(1, 0.45, 0.45))
		target.modulate = Color(1, 0.6, 0.6)
		target.set_meta("v", float(target.get_meta("v")) * 1.6)
		return
	add_points(1, target.position + Vector2(0, -260))
	target.modulate = Color(1.0, 0.8, 0.95)
	hop(target, 36.0, 0.3)
	target.set_meta("v", float(target.get_meta("v")) * 1.5)
