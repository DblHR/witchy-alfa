extends Panel
class_name CardView
## Прямоугольник-карта. Сам ничего не решает: при нажатии шлёт сигнал,
## перетаскиванием и розыгрышем занимается CardBattle.

signal pressed(view: CardView)

const CARD_SIZE := Vector2(150, 210)

## Арт на фоне карт героя (из assets/pics/ready but not used, уменьшен до 336x501).
## У героев без арта (воин, общие карты) остаётся цветной заливка.
const ART_PATHS := {
	"witch": "res://assets/pics/cards/art/witch.png",
	"luisa": "res://assets/pics/cards/art/luisa.png",
	"aki": "res://assets/pics/cards/art/aki.png",
	"fufu": "res://assets/pics/cards/art/fufu.png",
}
## Подложка карты по виду (CardInstance.get_kind()). Если файла нет — рамка красится в цвет вида.
## Положи PNG 150x210 (или пропорционально) в эту папку: attack.png, support.png, ult.png.
const FRAME_PATH := "res://assets/pics/cards/frames/%s.png"
const KIND_BORDER := {
	"attack": Color(0.92, 0.32, 0.32),
	"support": Color(0.38, 0.85, 0.5),
	"ult": Color(1.0, 0.82, 0.3),
}
static var _frame_cache: Dictionary = {}

## Цвета разметки в описаниях (см. CardLibrary).
const MARKUP_COLORS := {
	"d": "#ff6b6b",   # урон
	"s": "#6ec8ff",   # щит
	"h": "#6dff8e",   # лечение
	"e": "#ff7fd0",   # эффекты и статусы
}
const COST_COLOR_LOW := Color(0.22, 0.62, 0.30, 1.0)    ## цена 0-1
const COST_COLOR_MID := Color(0.86, 0.68, 0.14, 1.0)    ## цена 2
const COST_COLOR_HIGH := Color(0.80, 0.24, 0.24, 1.0)   ## цена 3 и выше
const COST_COLOR_DISABLED := Color(0.40, 0.40, 0.44, 1.0)
const GRAY_OVERLAY := Color(0.38, 0.38, 0.42, 0.74)
const HOVER_SCALE := 1.28
const HOVER_TIME := 0.09

const ART_INSET := 3.0
const ART_CORNER_RADIUS := 10.0
const ART_DIM_TOP := 0.45      ## затемнение под названием
const ART_DIM_MID := 0.15
const ART_DIM_TEXT := 0.50     ## затемнение под описанием
const ART_DIM_BOTTOM := 0.75

const ROUND_SHADER_CODE := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(144.0, 204.0);
uniform float radius = 10.0;
void fragment() {
	vec2 p = UV * rect_size;
	vec2 d = abs(p - rect_size * 0.5) - (rect_size * 0.5 - vec2(radius));
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - radius;
	COLOR.a *= 1.0 - smoothstep(-1.0, 0.5, dist);
}
"""

static var _art_cache: Dictionary = {}
static var _round_material: ShaderMaterial
static var _dim_texture: GradientTexture2D

var card: CardInstance
var interactive: bool = true
var dragging: bool = false
## Место в руке, куда карта возвращается, если её не удалось разыграть.
var home_position: Vector2 = Vector2.ZERO

var _move_tween: Tween
var _hover: bool = false
var _affordable: bool = true
var _cost_label: Label
var _cost_style: StyleBoxFlat
var _cost_value: int = 0
var _gray_overlay: Panel
var _hover_tween: Tween
var _hover_z_set := false

func setup(c: CardInstance, is_interactive: bool = true) -> void:
	card = c
	interactive = is_interactive
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	# Масштабируем от нижнего края: при наведении карта «вырастает» вверх, не уезжая за экран.
	pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = c.color
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = c.color.lightened(0.55)
	add_theme_stylebox_override("panel", sb)
	_add_frame(c, sb)

	var has_art := _add_art(c)
	# Серая вуаль лежит под текстом: нехватка энергии не мешает читать описание.
	_gray_overlay = _make_gray_overlay()
	add_child(_gray_overlay)

	add_child(_make_label(c.title, 15 if c.title.length() <= 11 else 13, Vector2(24, 12), Vector2(CARD_SIZE.x - 30, 26)))

	add_child(_make_description(c.description, Vector2(10, 46), Vector2(CARD_SIZE.x - 20, 130)))

	var owner_label := _make_label(c.owner_name, 14, Vector2(0, 182), Vector2(CARD_SIZE.x, 22))
	owner_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	add_child(owner_label)

	add_child(_make_cost_badge(c.cost))

	if has_art:
		owner_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))

	if interactive:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

static func _get_frame(kind: String) -> Texture2D:
	if _frame_cache.has(kind):
		return _frame_cache[kind]
	var tex: Texture2D = null
	var path := FRAME_PATH % kind
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_frame_cache[kind] = tex
	return tex

## Подложка по виду карты: спрайт, если он есть, иначе цветная рамка.
func _add_frame(c: CardInstance, sb: StyleBoxFlat) -> void:
	var kind := c.get_kind()
	var tex := _get_frame(kind)
	if tex == null:
		sb.border_color = KIND_BORDER.get(kind, sb.border_color)
		return
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0, 0, 0, 0)
	var f := TextureRect.new()
	f.name = "Frame"
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.position = Vector2.ZERO
	f.size = CARD_SIZE
	f.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	f.stretch_mode = TextureRect.STRETCH_SCALE
	f.texture = tex
	add_child(f)

static func _get_art(owner_id: String) -> Texture2D:
	if _art_cache.has(owner_id):
		return _art_cache[owner_id]
	var tex: Texture2D = null
	var path := String(ART_PATHS.get(owner_id, ""))
	if path != "" and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_art_cache[owner_id] = tex
	return tex

static func _get_round_material() -> ShaderMaterial:
	if _round_material == null:
		var shader := Shader.new()
		shader.code = ROUND_SHADER_CODE
		_round_material = ShaderMaterial.new()
		_round_material.shader = shader
		_round_material.set_shader_parameter("rect_size", CARD_SIZE - Vector2.ONE * ART_INSET * 2.0)
		_round_material.set_shader_parameter("radius", ART_CORNER_RADIUS)
	return _round_material

static func _get_dim_texture() -> GradientTexture2D:
	if _dim_texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.20, 0.32, 0.85, 1.0])
		g.colors = PackedColorArray([
			Color(0.04, 0.02, 0.08, ART_DIM_TOP),
			Color(0.04, 0.02, 0.08, ART_DIM_MID),
			Color(0.04, 0.02, 0.08, ART_DIM_TEXT),
			Color(0.04, 0.02, 0.08, ART_DIM_TEXT),
			Color(0.04, 0.02, 0.08, ART_DIM_BOTTOM),
		])
		_dim_texture = GradientTexture2D.new()
		_dim_texture.gradient = g
		_dim_texture.fill_from = Vector2(0.0, 0.0)
		_dim_texture.fill_to = Vector2(0.0, 1.0)
		_dim_texture.width = 4
		_dim_texture.height = 256
	return _dim_texture

## Арт героя на фоне карты + затемнение, чтобы текст читался. false — арта нет.
func _add_art(c: CardInstance) -> bool:
	var tex := _get_art(c.owner_id)
	if tex == null:
		return false
	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2.ONE * ART_INSET
	art.size = CARD_SIZE - Vector2.ONE * ART_INSET * 2.0
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture = tex
	art.material = _get_round_material()
	add_child(art)
	var dim := TextureRect.new()
	dim.name = "ArtDim"
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.position = art.position
	dim.size = art.size
	dim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dim.stretch_mode = TextureRect.STRETCH_SCALE
	dim.texture = _get_dim_texture()
	dim.material = _get_round_material()
	add_child(dim)
	return true

## Описание с цветной разметкой: [d] урон, [s] щит, [h] лечение, [e] эффект.
func _make_description(text: String, pos: Vector2, box: Vector2) -> RichTextLabel:
	var bb := text
	for tag in MARKUP_COLORS.keys():
		bb = bb.replace("[%s]" % tag, "[color=%s]" % MARKUP_COLORS[tag]).replace("[/%s]" % tag, "[/color]")
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.scroll_active = false
	r.fit_content = false
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.position = pos
	r.size = box
	r.add_theme_font_size_override("normal_font_size", 14)
	r.add_theme_font_size_override("bold_font_size", 14)
	r.add_theme_color_override("default_color", Color.WHITE)
	r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	r.add_theme_constant_override("outline_size", 4)
	r.text = bb
	return r

func _make_gray_overlay() -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.position = Vector2.ONE * ART_INSET
	p.size = CARD_SIZE - Vector2.ONE * ART_INSET * 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = GRAY_OVERLAY
	for corner in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		sb.set("corner_radius_" + corner, 10)
	p.add_theme_stylebox_override("panel", sb)
	p.visible = false
	return p

static func _cost_color(cost: int) -> Color:
	if cost <= 1:
		return COST_COLOR_LOW
	if cost == 2:
		return COST_COLOR_MID
	return COST_COLOR_HIGH

func _refresh_cost_color() -> void:
	if _cost_style != null:
		_cost_style.bg_color = _cost_color(_cost_value) if _affordable else COST_COLOR_DISABLED

func _make_cost_badge(cost: int) -> Panel:
	_cost_value = cost
	var badge := Panel.new()
	badge.position = Vector2(-12, -12)
	badge.size = Vector2(36, 36)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = _cost_color(cost)
	_cost_style = sb
	sb.corner_radius_top_left = 18
	sb.corner_radius_top_right = 18
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1.0, 1.0, 1.0, 0.95)
	badge.add_theme_stylebox_override("panel", sb)
	_cost_label = _make_label(str(cost), 22, Vector2.ZERO, Vector2(36, 36))
	_cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_cost_label)
	return badge

func _make_label(text: String, font_size: int, pos: Vector2, label_size: Vector2, wrap: bool = false) -> Label:
	var l := Label.new()
	# Перенос включаем ДО текста и размера, иначе Label растягивается под всю строку.
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = text
	l.position = pos
	l.size = label_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 4)
	return l

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		pressed.emit(self)

func _on_mouse_entered() -> void:
	if dragging:
		return
	_hover = true
	_animate_hover(true)

func _on_mouse_exited() -> void:
	_hover = false
	_animate_hover(false)

## Наведение: карта подрастает и поднимается поверх соседних, чтобы текст было удобно читать.
func _animate_hover(on: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	if on:
		z_index = 60
		_hover_z_set = true
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE * (HOVER_SCALE if on else 1.0), HOVER_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not on:
		_hover_tween.tween_callback(func() -> void:
			if _hover_z_set and not dragging:
				z_index = 0
				_hover_z_set = false
		)

func _stop_hover() -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover = false
	_hover_z_set = false

## Текущая цена (с учётом надбавок). Красным — если дороже базовой.
func set_cost_text(value: int, raised: bool) -> void:
	if _cost_label == null:
		return
	_cost_label.text = str(value)
	_cost_value = value
	_refresh_cost_color()

## Карты, на которые не хватает энергии, затемняются.
func set_affordable(value: bool) -> void:
	_affordable = value
	_update_tint()

## Серая «вуаль» поверх арта, но под текстом (self_modulate красил бы только фон панели).
func _update_tint() -> void:
	var gray := interactive and not _affordable and not dragging
	if _gray_overlay != null:
		_gray_overlay.visible = gray
	_refresh_cost_color()

# --- Движение и анимации -----------------------------------------------------

func _kill_move() -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = null

func move_to(pos: Vector2, duration: float = 0.18) -> void:
	_kill_move()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func appear() -> void:
	scale = Vector2(0.4, 0.4)
	modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, 0.18)
	t.tween_property(self, "modulate:a", 1.0, 0.12)

func begin_drag() -> void:
	_kill_move()
	_stop_hover()
	dragging = true
	z_index = 100
	scale = Vector2(1.08, 1.08)
	_update_tint()

func end_drag() -> void:
	dragging = false
	z_index = 0
	scale = Vector2.ONE
	_update_tint()

## Карта улетает в точку (обычно к кнопке сброса) и удаляется.
func fly_to_and_free(target: Vector2) -> void:
	_kill_move()
	_stop_hover()
	dragging = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", target, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(self, "scale", Vector2(0.35, 0.35), 0.22)
	t.tween_property(self, "modulate:a", 0.0, 0.14).set_delay(0.08)
	t.chain().tween_callback(queue_free)

## Сгоревшая карта (exhaust): вспыхивает оранжевым, поднимается, сжимается по вертикали и гаснет.
func burn_and_free() -> void:
	_kill_move()
	_stop_hover()
	dragging = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	scale = Vector2.ONE
	pivot_offset = CARD_SIZE * 0.5
	var t := create_tween()
	t.tween_property(self, "modulate", Color(1.6, 0.9, 0.35, 1.0), 0.12)
	t.set_parallel(true)
	t.tween_property(self, "position:y", position.y - 60.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.1, 0.05), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate", Color(1.0, 0.45, 0.1, 0.0), 0.4).set_delay(0.05)
	t.chain().tween_callback(queue_free)

## Сыгранная карта: быстро крутится, чуть вырастает и растворяется на месте.
func play_and_free() -> void:
	_kill_move()
	_stop_hover()
	dragging = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 120
	scale = Vector2.ONE
	pivot_offset = CARD_SIZE * 0.5   # вращаем вокруг центра
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "rotation", TAU * 1.5, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(1.25, 1.25), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector2(0.1, 0.1), 0.26).set_delay(0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(self, "modulate:a", 0.0, 0.2).set_delay(0.22)
	t.chain().tween_callback(queue_free)
