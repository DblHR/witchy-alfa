class_name CardStatusFx
extends RefCounted
## Статусы на самом персонаже в бою, пока действуют: мягкое свечение вокруг («аура», цвета статусов)
## и маленькие значки статусов, которые летают снизу вверх / сверху вниз / кружат вокруг головы.
## Что как летает — data/battle/status_fx.json. Вызывается из CardBattle._refresh_actor.
## Всё — в узле StatusFx актёра (свечение — за спрайтом, значки — перед ним).

const FILE := "res://data/battle/status_fx.json"
const AURA_TEX_SIZE := 128

static var _cfg: Dictionary = {}
static var _aura_tex: Texture2D

static func _config() -> Dictionary:
	if _cfg.is_empty():
		if FileAccess.file_exists(FILE):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
			if parsed is Dictionary:
				_cfg = parsed
		if _cfg.is_empty():
			_cfg = {"aura": true, "default": {"mode": "rise"}}
	return _cfg

static func reload() -> void:
	_cfg = {}

static func _fx_of(status_id: String) -> Dictionary:
	var out: Dictionary = (_config().get("default", {}) as Dictionary).duplicate()
	out.merge((_config().get("statuses", {}) as Dictionary).get(status_id, {}), true)
	return out

## Мягкое круглое пятно (белое, края тают) — для свечения.
static func _aura_texture() -> Texture2D:
	if _aura_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = AURA_TEX_SIZE
		t.height = AURA_TEX_SIZE
		_aura_tex = t
	return _aura_tex

## Видимая часть спрайта актёра (в координатах актёра).
static func _body_rect(actor: BattleActor) -> Rect2:
	var spr := actor.sprite
	if spr == null or spr.texture == null:
		return Rect2(-80, -300, 160, 300)
	var r := spr.get_rect()
	var sc := spr.scale.abs()
	return Rect2(spr.position + r.position * sc, r.size * sc)

static func _root(actor: BattleActor) -> Node2D:
	var root := actor.get_node_or_null("StatusFx") as Node2D
	if root == null:
		root = Node2D.new()
		root.name = "StatusFx"
		actor.add_child(root)
		var aura := Sprite2D.new()
		aura.name = "Aura"
		aura.texture = _aura_texture()
		aura.visible = false
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD   ## светится на любом фоне
		aura.material = add
		actor.add_child(aura)
		actor.move_child(aura, 0)   ## за спрайтом
		var tw := aura.create_tween().set_loops()
		tw.tween_property(aura, "self_modulate:a", 0.6, 1.1).set_trans(Tween.TRANS_SINE)
		tw.tween_property(aura, "self_modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	return root

## pairs — [CardStatus, данные] (как у ряда значков). alive=false — всё убрать.
static func refresh(actor: BattleActor, pairs: Array, alive: bool) -> void:
	if actor == null:
		return
	var root := _root(actor)
	var aura := actor.get_node_or_null("Aura") as Sprite2D
	var want: Dictionary = {}   ## id -> [CardStatus, fx]
	if alive:
		for pair in pairs:
			var st: CardStatus = pair[0]
			want[st.id] = [st, _fx_of(st.id)]
	# Убрать то, чего больше нет.
	for c in root.get_children():
		if not want.has(String(c.get_meta("status_id", ""))):
			_fade_out(c)
	# Добавить новое.
	var body := _body_rect(actor)
	for id in want.keys():
		var st: CardStatus = want[id][0]
		var fx: Dictionary = want[id][1]
		if root.has_node(NodePath(_node_name(String(id)))):
			continue
		var node := _make_fx(st, fx, body)
		if node != null:
			node.name = _node_name(String(id))
			node.set_meta("status_id", String(id))
			root.add_child(node)
	# Свечение: смесь цветов статусов.
	if aura != null:
		var on := bool(_config().get("aura", true)) and not want.is_empty()
		aura.visible = on
		if on:
			var col := Color(0, 0, 0, 0)
			for id in want.keys():
				col += _color_of(want[id][0], want[id][1])
			col /= float(want.size())
			col.a = float(_config().get("aura_alpha", 0.4))
			aura.modulate = col
			aura.position = body.get_center()
			var k: Array = _config().get("aura_size", [1.7, 1.25])
			aura.scale = Vector2(body.size.x * float(k[0]), body.size.y * float(k[1])) / float(AURA_TEX_SIZE)

static func _node_name(id: String) -> String:
	return "Fx_" + id

static func _color_of(st: CardStatus, fx: Dictionary) -> Color:
	var c := String(fx.get("color", ""))
	return Color.html(c) if c != "" and Color.html_is_valid(c) else st.color

static func _icon(st: CardStatus) -> Texture2D:
	var p := st.icon_path
	return load(p) as Texture2D if p != "" and ResourceLoader.exists(p) else null

static func _make_fx(st: CardStatus, fx: Dictionary, body: Rect2) -> Node2D:
	var mode := String(fx.get("mode", "rise"))
	var tex := _icon(st)
	if mode == "none" or tex == null:
		return Node2D.new()   ## пустышка — чтобы не пересоздавать каждый раз
	var size := float(fx.get("size", 28))
	var amount := maxi(1, int(fx.get("amount", 3)))
	var speed := float(fx.get("speed", 1.0))
	if mode == "orbit":
		var orb := Orbit.new()
		orb.setup(tex, amount, size, speed, Vector2(body.get_center().x, body.position.y + body.size.y * 0.12), Vector2(body.size.x * 0.45, body.size.y * 0.06))
		return orb
	var p := CPUParticles2D.new()
	p.texture = tex
	p.amount = amount
	p.lifetime = 2.0 / maxf(0.2, speed)
	p.preprocess = p.lifetime
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(body.size.x * 0.42, body.size.y * 0.12)
	var k := size / float(maxi(tex.get_width(), tex.get_height()))
	p.scale_amount_min = k * 0.8
	p.scale_amount_max = k * 1.1
	p.direction = Vector2.UP if mode == "rise" else Vector2.DOWN
	p.spread = 12.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 45.0 * speed
	p.initial_velocity_max = 75.0 * speed
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.75, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	# Снизу вверх — от ног, сверху вниз — от макушки.
	if mode == "rise":
		p.position = Vector2(body.get_center().x, body.end.y - body.size.y * 0.15)
	else:
		p.position = Vector2(body.get_center().x, body.position.y + body.size.y * 0.15)
	p.emitting = true
	return p

static func _fade_out(n: Node) -> void:
	n.set_meta("status_id", "")
	n.name = "Fx_gone_%d" % n.get_instance_id()
	if n is CPUParticles2D:
		(n as CPUParticles2D).emitting = false
		n.get_tree().create_timer((n as CPUParticles2D).lifetime).timeout.connect(n.queue_free)
	elif n is CanvasItem:
		var tw := (n as CanvasItem).create_tween()
		tw.tween_property(n, "modulate:a", 0.0, 0.3)
		tw.tween_callback(n.queue_free)
	else:
		n.queue_free()

## Значки кружат вокруг головы (эллипс; за головой — полупрозрачнее).
class Orbit extends Node2D:
	var _icons: Array[Sprite2D] = []
	var _center := Vector2.ZERO
	var _radius := Vector2(60, 10)
	var _speed := 1.0
	var _t := 0.0

	func setup(tex: Texture2D, amount: int, size: float, speed: float, center: Vector2, radius: Vector2) -> void:
		_center = center
		_radius = radius
		_speed = speed
		var k := size / float(maxi(tex.get_width(), tex.get_height()))
		for i in amount:
			var s := Sprite2D.new()
			s.texture = tex
			s.scale = Vector2(k, k)
			add_child(s)
			_icons.append(s)
		_place()

	func _process(delta: float) -> void:
		_t += delta * 1.6 * _speed
		_place()

	func _place() -> void:
		var n := _icons.size()
		for i in n:
			var a := _t + TAU * float(i) / float(n)
			var s := _icons[i]
			s.position = _center + Vector2(cos(a) * _radius.x, sin(a) * _radius.y)
			s.modulate.a = 0.55 if sin(a) < 0.0 else 0.95
