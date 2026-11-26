class_name DreamGame
extends Node2D
## Основа мини-игры сна. Живёт в DreamScreen (поле — фон боевой локации 1920×1080).
## Игра считает очки (add_points), может отнять время (screen.add_time). Пока running == false
## (отсчёт перед стартом, конец) — ничего не двигается и кнопки не работают.
## Свой код игры: build() — расставить всё, play(delta) — кадр игры, key(dir) — нажатие стрелки,
## jump() — пробел. Стрелки и WASD (по физическим клавишам — работает и в русской раскладке).

signal points_changed(points: int)

## Пол боевой локации: линия «земли» для игр сбоку и поле для игр сверху.
const GROUND_Y := 770.0
const FIELD := Rect2(140, 590, 1640, 220)
const CHIBI := "res://assets/characters/%s/%s_battle.png"
const NPC := "res://assets/npc/%s/%s.png"
const SLIMES := "res://assets/enemies/slimes/"
const SLIME_COLORS := ["slime_green", "slime_blue", "slime_pink", "slime_purple"]

var dream_id := ""
var cfg: Dictionary = {}
var screen: Node
var running := false
var points := 0

## Переопределить в игре.
func build() -> void:
	pass

func play(_delta: float) -> void:
	pass

func key(_dir: Vector2i) -> void:
	pass

func jump() -> void:
	pass

func _process(delta: float) -> void:
	if running:
		play(delta)

func add_points(n: int, at: Vector2 = Vector2.INF) -> void:
	points = maxi(0, points + n)
	points_changed.emit(points)
	if at != Vector2.INF and n != 0:
		float_text(("+%d" % n) if n > 0 else str(n), at, Color(1, 0.95, 0.6) if n > 0 else Color(1, 0.5, 0.5))

## Нажатия: стрелки / WASD -> key(Vector2i), пробел -> jump().
func _unhandled_input(e: InputEvent) -> void:
	if not running or not (e is InputEventKey) or not e.pressed or e.echo:
		return
	var k := (e as InputEventKey).physical_keycode
	match k:
		KEY_UP, KEY_W:
			key(Vector2i.UP)
			jump()
		KEY_DOWN, KEY_S:
			key(Vector2i.DOWN)
		KEY_LEFT, KEY_A:
			key(Vector2i.LEFT)
		KEY_RIGHT, KEY_D:
			key(Vector2i.RIGHT)
		KEY_SPACE:
			jump()
		_:
			return
	get_viewport().set_input_as_handled()

## Куда зажаты стрелки / WASD сейчас (для бега).
static func held_dir() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		v.y += 1.0
	return v.normalized() if v != Vector2.ZERO else v

func cf(key_name: String, def: float) -> float:
	return float(cfg.get(key_name, def))

func cf_range(key_name: String, def: Vector2) -> float:
	var a = cfg.get(key_name, [def.x, def.y])
	if a is Array and (a as Array).size() >= 2:
		return randf_range(float(a[0]), float(a[1]))
	return float(a)

# --- Картинки ----------------------------------------------------------------------

static var _crops: Dictionary = {}

## Картинка персонажа: героини — чибик <id>_battle.png, НПС — портрет (обрезан по краям рисунка).
static func char_texture(id: String) -> Texture2D:
	var p := CHIBI % [id, id]
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	p = NPC % [id, id]
	if not ResourceLoader.exists(p):
		return null
	if _crops.has(p):
		return _crops[p]
	var tex := load(p) as Texture2D
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(img.get_used_rect())
		_crops[p] = at
		return at
	return tex

static func slime_texture(color: String = "") -> Texture2D:
	if color == "":
		color = SLIME_COLORS[randi() % SLIME_COLORS.size()]
	return load(SLIMES + color + ".png") as Texture2D

## Спрайт «ногами» в точке (0,0): высота height px.
func make_sprite(tex: Texture2D, height: float, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	if tex != null:
		var k := height / float(tex.get_height())
		s.scale = Vector2(k, k)
		s.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	(parent if parent != null else self).add_child(s)
	return s

## Значок (центр в 0,0) размером size px.
func make_icon(tex: Texture2D, size: float, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	if tex != null:
		var k := size / float(maxi(tex.get_width(), tex.get_height()))
		s.scale = Vector2(k, k)
	(parent if parent != null else self).add_child(s)
	return s

func float_text(text: String, at: Vector2, col: Color = Color(1, 0.95, 0.6), size: int = 40) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.2))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(200, 60)
	l.position = at - Vector2(100, 30)
	l.z_index = 100
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 70.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)

## Подпрыгнуть-покачаться (живой персонаж): небольшой прыжок спрайта.
func hop(s: Node2D, height: float = 24.0, time: float = 0.25) -> void:
	var y := s.position.y
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", y - height, time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", y, time * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Сплющить и исчезнуть.
func poof(s: Node2D, time: float = 0.3) -> void:
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "scale", s.scale * Vector2(1.4, 0.3), time)
	tw.tween_property(s, "modulate:a", 0.0, time)
	tw.chain().tween_callback(s.queue_free)
