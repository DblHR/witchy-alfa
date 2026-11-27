extends DreamGame
## Ведьмочка рисует слизней: перед ней появляется набросок слизня, под ним стрелки
## (обычный — arrows_normal, элитный — arrows_elite). Нажимать стрелки / WASD по порядку —
## с каждой верной слизень «прорисовывается»; все верно — готов, очко, следующий.
## Ошибка — стрелки сбрасываются, начинать этого слизня заново.

const ARROW := "res://assets/ui/dreams/arrow.png"
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const ARROW_SIZE := 96.0
const ARROW_GAP := 112.0
const SLIME_POS := Vector2(1180, 690)
const ARROW_Y := 770.0
const COL_DONE := Color(0.55, 1.0, 0.6)
const COL_WRONG := Color(1.0, 0.4, 0.4)

var witch: Sprite2D
var slime: Sprite2D
var arrows: Array[Sprite2D] = []
var seq: Array[Vector2i] = []
var pos := 0
var elite := false
var _slime_scale := Vector2.ONE

func build() -> void:
	witch = make_sprite(char_texture("witch"), 340)
	witch.position = Vector2(560, 760)
	witch.flip_h = true   ## смотрит на слизня
	_next_slime()

func play(delta: float) -> void:
	witch.position.y = 760 + sin(Time.get_ticks_msec() * 0.004) * 4.0
	if slime != null:
		slime.scale = _slime_scale * Vector2(1.0 + sin(Time.get_ticks_msec() * 0.006) * 0.02, 1.0)

func _next_slime() -> void:
	elite = randf() < cf("elite_chance", 0.3)
	slime = make_sprite(slime_texture("slime_purple" if elite else ""), 300.0 if elite else 210.0)
	slime.position = SLIME_POS
	_slime_scale = slime.scale
	if elite:
		slime.self_modulate = Color(1.0, 0.92, 1.15)
	slime.modulate = Color(1, 1, 1, 0.22)   ## пока только набросок
	slime.scale = _slime_scale * 0.2
	slime.create_tween().tween_property(slime, "scale", _slime_scale, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var n := int(cfg.get("arrows_elite" if elite else "arrows_normal", 4 if elite else 3))
	seq.clear()
	for a in arrows:
		a.queue_free()
	arrows.clear()
	pos = 0
	var x0 := SLIME_POS.x - ARROW_GAP * float(n - 1) * 0.5
	for i in n:
		var d: Vector2i = DIRS[randi() % DIRS.size()]
		seq.append(d)
		var a := make_icon(load(ARROW) as Texture2D, ARROW_SIZE)
		a.position = Vector2(x0 + ARROW_GAP * i, ARROW_Y)
		a.rotation = Vector2(d).angle() + PI * 0.5
		arrows.append(a)

func key(dir: Vector2i) -> void:
	if slime == null or seq.is_empty():
		return
	if dir == seq[pos]:
		arrows[pos].modulate = COL_DONE
		pos += 1
		slime.modulate.a = 0.22 + 0.78 * float(pos) / float(seq.size())
		hop(witch, 14.0, 0.18)
		if pos >= seq.size():
			_done()
	else:
		for a in arrows:
			a.modulate = COL_WRONG
			a.create_tween().tween_property(a, "modulate", Color.WHITE, 0.35)
		pos = 0
		slime.modulate.a = 0.22
		var x := slime.position.x
		var tw := slime.create_tween()
		for dx in [-14.0, 14.0, -8.0, 0.0]:
			tw.tween_property(slime, "position:x", x + dx, 0.05)

func _done() -> void:
	add_points(1, slime.position + Vector2(0, -200))
	var s := slime
	slime = null
	seq.clear()
	hop(s, 40.0, 0.3)
	var tw := s.create_tween()
	tw.tween_interval(0.3)
	tw.tween_property(s, "position:x", 2100.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(s.queue_free)
	for a in arrows:
		poof(a, 0.25)
	arrows.clear()
	await get_tree().create_timer(0.25).timeout
	if running:
		_next_slime()
