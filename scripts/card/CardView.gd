extends Panel
class_name CardView
## Прямоугольник-карта. Сам ничего не решает: при нажатии шлёт сигнал,
## перетаскиванием и розыгрышем занимается CardBattle.

signal pressed(view: CardView)

const CARD_SIZE := Vector2(150, 210)

## Арт на фоне карт героя (из assets/pics/ready but not used, уменьшен до 336x501).
## У героев без арта (воин, общие карты) остаётся цветной заливка.
const ART_PATHS := {
	"witch": "res://assets/pics/cards/art/witch/witch.png",
	"luisa": "res://assets/pics/cards/art/luisa/luisa.png",
	"aki": "res://assets/pics/cards/art/aki/aki.png",
	"fufu": "res://assets/pics/cards/art/fufu/fufu.png",
}
## Арты лежат по папкам героинь: assets/pics/cards/art/<героиня>/…
## Арт карты по виду: <героиня>/<героиня>_atk.png — карта наносит урон,
## <героиня>_sup.png — не наносит (ульта — по тому же правилу). Это полный рисунок карты
## с табличкой «Атака»/«Поддержка» сверху: он занимает всю карту, название опускается под табличку.
## Нет такого арта — старый вариант: <героиня>.png (ART_PATHS) или цветная заливка с рамкой цвета вида.
const TAG_ART_PATH := "res://assets/pics/cards/art/%s/%s_%s.png"
## Уникальный рисунок карты: <героиня>/<id карты>.png (общие карты — common/<id>.png), 840×1253,
## без таблички сверху — табличка берётся с арта по виду и остаётся видна над рисунком.
## Нет файла — карта показывает общий арт героини по виду.
const CARD_ART_PATH := "res://assets/pics/cards/art/%s/%s.png"
static var _card_art_cache: Dictionary = {}
## Доля высоты арта по виду, занятая табличкой сверху (до рамки рисунка).
const HEADER_FRACTION := 0.15
const TAG_ART_SUFFIX := {"attack": "atk", "support": "sup"}
## Раскладка текста на арте с табличкой.
## Название — в верхней полосе (где на арте была табличка), справа от цены.
const TAG_TITLE_POS := Vector2(22, 3)
const TAG_TITLE_RIGHT := 6.0
const TAG_DESC_POS := Vector2(12, 38)
## Цвет фона верхней полосы рисунков (под название).
const HEADER_BG := Color(13.0 / 255.0, 11.0 / 255.0, 14.0 / 255.0)
## Подложка по виду для карт без арта: assets/pics/cards/frames/<вид>.png (необязательно).
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
const HOVER_SCALE := 1.9
## Карты в руке показывают описание только при наведении (и пока их тащат).
## В окнах колоды/сброса и в инвентаре описание видно всегда.
const DESC_ON_HOVER_ONLY := true
## Подложка под описанием: тёмная плашка, чтобы цветной текст читался на любом арте.
const DESC_PLATE_COLOR := Color(0.03, 0.01, 0.06, 0.82)
const DESC_PLATE_PAD := Vector2(5, 3)
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
var _desc: RichTextLabel
var _desc_plate: Panel
var _affordable: bool = true
var _cost_label: Label
var _cost_style: StyleBoxFlat
var _cost_value: int = 0
var _gray_overlay: Panel
var _hover_tween: Tween
var _hover_z_set := false

## Шрифт карт в режиме MSDF: текст остаётся чётким при любом увеличении (наведение ×1.9,
## превью в окнах). Обычный растровый шрифт при масштабировании узла размывается.
static var _card_theme: Theme

static func card_theme() -> Theme:
	if _card_theme != null:
		return _card_theme
	_card_theme = Theme.new()
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var f := (base as FontFile).duplicate() as FontFile
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16   # обводка до 8 px остаётся ровной
		f.msdf_size = 48
		f.generate_mipmaps = true
		_card_theme.default_font = f
	return _card_theme

func _ready() -> void:
	for ch in get_children():
		if ch is Label and ch.has_meta("want_rect"):
			var r: Rect2 = ch.get_meta("want_rect")
			(ch as Label).position = r.position
			(ch as Label).size = r.size

func setup(c: CardInstance, is_interactive: bool = true) -> void:
	card = c
	interactive = is_interactive
	theme = card_theme()
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
	var kind := _frame_kind(c)
	var tag_art := _get_tag_art(c.owner_id, kind)
	var card_art := _get_card_art(c.owner_id, c.id)
	var has_art := false
	if tag_art != null or card_art != null:
		# Полный рисунок карты: своя рамка и табличка уже на нём. Уникальный рисунок карты
		# ложится поверх общего арта по виду — табличка «Атака»/«Поддержка» остаётся сверху.
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(0, 0, 0, 0)
		_add_full_art(tag_art, card_art)
		has_art = true
	else:
		var frame_tex := _get_frame(kind)
		var frame_on_top := frame_tex != null and _is_overlay(frame_tex)
		if not frame_on_top:
			_add_frame(kind, frame_tex, sb)
		has_art = _add_art(c)
		if frame_on_top:
			_add_frame(kind, frame_tex, sb)
	# Серая вуаль лежит под текстом: нехватка энергии не мешает читать описание.
	_gray_overlay = _make_gray_overlay()
	add_child(_gray_overlay)

	var full_art := tag_art != null or card_art != null
	var title_pos := TAG_TITLE_POS if full_art else Vector2(24, 12)
	var title_w := (CARD_SIZE.x - TAG_TITLE_POS.x - TAG_TITLE_RIGHT) if full_art else CARD_SIZE.x - 30.0
	var title := _make_title(c.title, title_pos, title_w)
	add_child(title)
	if c.locked:
		_setup_locked(full_art)
		return
	# Название в две строки — описание опускается.
	var extra := 0.0 if full_art else title.size.y - TITLE_LINE_H
	if full_art:
		_add_description(c.description, TAG_DESC_POS + Vector2(0, extra), Vector2(CARD_SIZE.x - TAG_DESC_POS.x * 2.0, 140 - extra))
	else:
		_add_description(c.description, Vector2(10, 46 + extra), Vector2(CARD_SIZE.x - 20, 130 - extra))
	_set_desc_visible(not (interactive and DESC_ON_HOVER_ONLY))

	var owner_label := _make_label(c.owner_name, 14, Vector2(0, 182), Vector2(CARD_SIZE.x, 22))
	owner_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	add_child(owner_label)

	add_child(_make_cost_badge(c.cost))

	if has_art:
		owner_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))

	if interactive:
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)

## Название карты: шрифт уменьшается, пока строка не влезет; не влезла и на минимальном —
## переносится на две строки.
const TITLE_SIZES := [15, 14, 13, 12]
const TITLE_WRAP_SIZE := 12
const TITLE_LINE_H := 24.0

## Название в верхней полосе рисунка: в одну строку, если влезает крупно (15–14), иначе —
## в две строки читаемым шрифтом (13–11). Две строки чуть выходят за полосу вниз (до описания).
const BAND_TITLE_SIZES := [15, 14]
const BAND_TITLE_WRAP_SIZES := [13, 12, 11]
const BAND_TITLE_WRAP_H := 37.0
const BAND_TITLE_LINE_SPACING := -3

func _make_title(text: String, pos: Vector2, width: float) -> Label:
	var font: Font = card_theme().default_font
	if font == null:
		font = ThemeDB.fallback_font
	var in_band := pos == TAG_TITLE_POS
	if in_band:
		return _make_band_title(text, font, pos, width)
	for fs in TITLE_SIZES:
		# запас на обводку текста
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width - 10.0:
			return _make_label(text, fs, pos, Vector2(width, TITLE_LINE_H))
	var l := _make_label(text, TITLE_WRAP_SIZE, pos, Vector2(width, TITLE_LINE_H + 14.0), true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l

func _make_band_title(text: String, font: Font, pos: Vector2, width: float) -> Label:
	var band_h := CARD_SIZE.y * HEADER_FRACTION - pos.y
	for fs in BAND_TITLE_SIZES:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width - 12.0:
			return _make_label(text, fs, pos, Vector2(width, band_h))
	# Две строки: делим по пробелу так, чтобы строки были как можно ровнее, и берём самый
	# крупный шрифт, при котором обе влезают. Одно длинное слово — мельче в одну строку.
	var words := text.split(" ", false)
	if words.size() < 2:
		for fs in BAND_TITLE_WRAP_SIZES:
			if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= width - 8.0:
				return _make_label(text, fs, pos, Vector2(width, band_h))
		return _make_label(text, BAND_TITLE_WRAP_SIZES[-1], pos, Vector2(width, band_h))
	var best := ""
	var best_w := INF
	for i in range(1, words.size()):
		var top := " ".join(words.slice(0, i))
		var bottom := " ".join(words.slice(i))
		var w := maxf(font.get_string_size(top, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, font.get_string_size(bottom, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x)
		if w < best_w:
			best_w = w
			best = top + "\n" + bottom
	var wrap_fs: int = BAND_TITLE_WRAP_SIZES[-1]
	for fs in BAND_TITLE_WRAP_SIZES:
		if best_w * float(fs) / 13.0 <= width - 8.0:
			wrap_fs = fs
			break
	var l := _make_label(best, wrap_fs, Vector2(pos.x, 0.0), Vector2(width, BAND_TITLE_WRAP_H))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", BAND_TITLE_LINE_SPACING)
	return l

## Ещё не полученная карта: только подложка, название и «Не получена».
func _setup_locked(has_tag_art: bool) -> void:
	var veil := ColorRect.new()
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.position = Vector2(4, CARD_SIZE.y * HEADER_FRACTION if has_tag_art else 4.0)
	veil.size = Vector2(CARD_SIZE.x - 8, CARD_SIZE.y - veil.position.y - 4)
	veil.color = Color(0.02, 0.0, 0.05, 0.62)
	add_child(veil)
	move_child(veil, get_child_count() - 2)   # под названием
	var lock := _make_label("Не получена", 17, Vector2(0, CARD_SIZE.y * 0.5 - 4), Vector2(CARD_SIZE.x, 30))
	lock.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	add_child(lock)

## Вид подложки: строго по правилу «есть урон — атака, нет — поддержка». У ульты — своя, если есть.
static func _frame_kind(c: CardInstance) -> String:
	var kind := c.get_kind()
	if kind == "ult" and _get_frame("ult") != null:
		return "ult"
	if c.def != null:
		return c.def.expected_tag()
	return CardDef.TAG_SUPPORT if kind == "ult" else kind

static func _get_frame(kind: String) -> Texture2D:
	if _frame_cache.has(kind):
		return _frame_cache[kind]
	var tex: Texture2D = null
	var path := FRAME_PATH % kind
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_frame_cache[kind] = tex
	return tex

static var _overlay_cache: Dictionary = {}

## Рамка (прозрачная середина) или подложка (сплошная).
static func _is_overlay(tex: Texture2D) -> bool:
	if _overlay_cache.has(tex):
		return _overlay_cache[tex]
	var result := false
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var center := img.get_pixel(img.get_width() / 2, img.get_height() / 2)
		result = center.a < 0.5
	_overlay_cache[tex] = result
	return result

## Подложка: спрайт, если он есть, иначе цветная рамка.
func _add_frame(kind: String, tex: Texture2D, sb: StyleBoxFlat) -> void:
	if tex == null:
		sb.border_color = KIND_BORDER.get(kind, sb.border_color)
		return
	# Сплошная подложка заменяет фон карты; рамка (прозрачная середина) — только обводку.
	if not _is_overlay(tex):
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

static var _tag_art_cache: Dictionary = {}

## Арт карты героини по виду («атака»/«поддержка») или null.
## Уникальный рисунок карты (или null).
static func _get_card_art(owner_id: String, card_id: String) -> Texture2D:
	var folder := owner_id if owner_id != "" else "common"
	var key := folder + "/" + card_id
	if _card_art_cache.has(key):
		return _card_art_cache[key]
	var tex: Texture2D = null
	var path := CARD_ART_PATH % [folder, card_id]
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_card_art_cache[key] = tex
	return tex

static func _get_tag_art(owner_id: String, kind: String) -> Texture2D:
	if owner_id == "" or not TAG_ART_SUFFIX.has(kind):
		return null
	var key := owner_id + "/" + kind
	if _tag_art_cache.has(key):
		return _tag_art_cache[key]
	var tex: Texture2D = null
	var path := TAG_ART_PATH % [owner_id, owner_id, TAG_ART_SUFFIX[kind]]
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	_tag_art_cache[key] = tex
	return tex

## Полный рисунок карты на всю карту, с лёгким затемнением под текстом.
## Полный рисунок карты без затемнения: уникальный (если есть) или общий арт героини по виду.
## Табличку «Атака»/«Поддержка» на общем арте закрывает полоса фона — там пишется название карты.
func _add_full_art(tex: Texture2D, card_tex: Texture2D = null) -> void:
	var art := TextureRect.new()
	art.name = "Art"
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.position = Vector2.ZERO
	art.size = CARD_SIZE
	art.texture = card_tex if card_tex != null else tex
	add_child(art)
	if card_tex == null:
		var band := ColorRect.new()
		band.name = "TitleBand"
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.position = Vector2.ZERO
		band.size = Vector2(CARD_SIZE.x, CARD_SIZE.y * HEADER_FRACTION)
		band.color = HEADER_BG
		add_child(band)

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

## Описание + тёмная плашка под ним по высоте текста.
func _add_description(text: String, pos: Vector2, box: Vector2) -> void:
	var fit := _fit_description(CardInstance.strip_markup(text), box)
	_desc_plate = Panel.new()
	_desc_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = DESC_PLATE_COLOR
	sb.set_corner_radius_all(8)
	_desc_plate.add_theme_stylebox_override("panel", sb)
	_desc_plate.position = pos - DESC_PLATE_PAD
	_desc_plate.size = Vector2(box.x, minf(box.y, fit.y)) + DESC_PLATE_PAD * 2.0
	add_child(_desc_plate)
	_desc = _make_description(text, pos, box, int(fit.x))
	add_child(_desc)

func _set_desc_visible(on: bool) -> void:
	if _desc != null:
		_desc.visible = on
	if _desc_plate != null:
		_desc_plate.visible = on

## Описание с цветной разметкой: [d] урон, [s] щит, [h] лечение, [e] эффект.
func _make_description(text: String, pos: Vector2, box: Vector2, font_size: int = -1) -> RichTextLabel:
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
	var fs := font_size if font_size > 0 else int(_fit_description(CardInstance.strip_markup(text), box).x)
	r.add_theme_font_size_override("normal_font_size", fs)
	r.add_theme_font_size_override("bold_font_size", fs)
	r.add_theme_color_override("default_color", Color.WHITE)
	r.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	r.add_theme_constant_override("outline_size", 5)
	r.text = bb
	return r

## Размер шрифта описания: самый крупный, при котором текст влезает в рамку
## и ни одно слово не рвётся посередине.
const DESC_SIZES := [14, 13, 12, 11, 10]
static var _desc_font: Font

## Возвращает (размер шрифта, высота текста).
static func _fit_description(plain: String, box: Vector2) -> Vector2:
	if _desc_font == null:
		var probe := RichTextLabel.new()
		_desc_font = probe.get_theme_font("normal_font")
		probe.free()
	if _desc_font == null:
		return Vector2(DESC_SIZES[0], box.y)
	var width := box.x - 4.0
	for fs in DESC_SIZES:
		var space := _desc_font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var lines := 0
		var fits := true
		for para in plain.split("\n"):
			var line_w := 0.0
			lines += 1
			for word in para.split(" ", false):
				var w := _desc_font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if w > width:
					fits = false
				if line_w > 0.0 and line_w + space + w > width:
					lines += 1
					line_w = w
				else:
					line_w += (space if line_w > 0.0 else 0.0) + w
		var line_h := _desc_font.get_height(fs) + 1.0
		if (fits and lines * line_h <= box.y) or fs == DESC_SIZES[-1]:
			return Vector2(fs, lines * line_h)
	return Vector2(DESC_SIZES[-1], box.y)

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
	l.add_theme_font_size_override("font_size", font_size)
	l.text = text
	l.position = pos
	l.size = label_size
	# Карта собирается до входа в дерево: тогда Label меряет текст шрифтом по умолчанию (16)
	# и раздувается — длинное название уезжало вбок. В дереве размер возвращаем (_ready).
	l.set_meta("want_rect", Rect2(pos, label_size))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_set_desc_visible(true)

func _on_mouse_exited() -> void:
	_hover = false
	_animate_hover(false)
	if not dragging and DESC_ON_HOVER_ONLY:
		_set_desc_visible(false)

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
	_set_desc_visible(true)
	_update_tint()

func end_drag() -> void:
	dragging = false
	z_index = 0
	scale = Vector2.ONE
	if DESC_ON_HOVER_ONLY and interactive:
		_set_desc_visible(false)
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
