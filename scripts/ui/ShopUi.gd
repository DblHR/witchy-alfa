extends RefCounted
class_name ShopUi
## Общий вид лавок (Рикка дома и Сессилия в забеге): цвета текста, карточки товара, кнопки.
## Раскладка одна и та же: заголовок, описание, сетка карточек на светлой панели фона.

const TITLE_COLOR := Color(0.78, 0.22, 0.52)
const TEXT_COLOR := Color(0.27, 0.12, 0.30)
const PLUM := Color(0.50, 0.31, 0.42)
const PLUM_HOVER := Color(0.60, 0.38, 0.51)
const PLUM_PRESSED := Color(0.40, 0.24, 0.34)
const GOLD := Color(1.0, 0.86, 0.42)

## Абсолютные места на экране 1920×1080 (светлая панель нарисована на фоне).
const TITLE_RECT := Rect2(110, 112, 980, 90)
const DESC_RECT := Rect2(110, 206, 980, 150)
const NOTE_RECT := Rect2(110, 366, 980, 44)
const GRID_POS := Vector2(110, 430)
const COIN_TEXT_POS := Vector2(1590, 46)

## Где стоят продавцы и медсестра (фоны теперь без них): прямоугольник картинки на экране 1920×1080.
## Картинка вписывается с сохранением пропорций; выходить за край экрана можно.
const NPC_RECTS := {
	"rabbit_shop": Rect2(1016, 40, 909, 1178),
	"lamia": Rect2(988, 44, 1023, 1078),
	"nurse": Rect2(504, 0, 1920, 1080),
}

## Спрайт продавца справа от панели. id — ключ AssetCatalog (rabbit_shop / lamia / nurse).
static func make_npc_sprite(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.name = "NpcSprite"
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_npc(t, id)
	return t

static func set_npc(t: TextureRect, id: String) -> void:
	var r: Rect2 = NPC_RECTS.get(id, Rect2())
	t.visible = r.size != Vector2.ZERO and AssetCatalog_ != null
	if not t.visible:
		t.texture = null
		return
	t.texture = AssetCatalog_.get_event_npc_texture(id)
	GalleryData.mark_seen_texture(t.texture)   ## встреча с NPC открывает его картинку в галерее
	t.position = r.position
	t.size = r.size

const CARD_SIZE := Vector2(232, 250)
const CARD_GAP := 16

static func _box(color: Color, radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.92, 0.95, 0.55)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

## Сливовая кнопка лавки (товар, услуга, «Идти дальше»).
static func style_button(b: Button, font_px: int = 28) -> void:
	b.add_theme_stylebox_override("normal", _box(PLUM))
	b.add_theme_stylebox_override("hover", _box(PLUM_HOVER))
	b.add_theme_stylebox_override("pressed", _box(PLUM_PRESSED))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0)))
	var off := _box(Color(PLUM.r, PLUM.g, PLUM.b, 0.38))
	off.border_color = Color(1, 1, 1, 0.2)
	b.add_theme_stylebox_override("disabled", off)
	b.add_theme_font_size_override("font_size", font_px)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color(1, 0.92, 0.96))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.6))
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func style_title(l: Label) -> void:
	l.add_theme_font_size_override("font_size", 64)
	l.add_theme_color_override("font_color", TITLE_COLOR)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

static func style_text(l: Label, font_px: int = 30) -> void:
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", TEXT_COLOR)
	l.add_theme_constant_override("outline_size", 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

static func style_gold(l: Label) -> void:
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 6)

## Сетка карточек товара.
static func make_grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.position = GRID_POS
	g.add_theme_constant_override("h_separation", CARD_GAP)
	g.add_theme_constant_override("v_separation", CARD_GAP)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g

static func _label(text: String, font_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.2, 0.06, 0.16))
	l.add_theme_constant_override("outline_size", 4)
	return l

## Карточка товара: иконка, название, цена; ×N в углу для наборов.
## state: "" — можно купить, "poor" — не хватает золота, "sold" — продано, "empty" — пусто.
static func make_item_card(icon: Texture2D, title: String, count: int, price: int, tooltip: String, state: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.clip_contents = true
	style_button(b)
	b.tooltip_text = tooltip
	var gone := state == "sold" or state == "empty"
	b.disabled = state != ""
	if gone:
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW

	var pic := TextureRect.new()
	# Режим растягивания — до текстуры и размера, иначе TextureRect раздуется под картинку.
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture = icon
	pic.position = Vector2((CARD_SIZE.x - 108.0) * 0.5, 14)
	pic.size = Vector2(108, 108)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.modulate = Color(1, 1, 1, 0.3 if gone else (0.6 if state == "poor" else 1.0))
	b.add_child(pic)

	var name_l := _label(title, 21, Color.WHITE)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.position = Vector2(10, 126)
	name_l.size = Vector2(CARD_SIZE.x - 20, 72)
	name_l.add_theme_constant_override("line_spacing", -2)
	name_l.modulate.a = 0.5 if gone else 1.0
	b.add_child(name_l)

	var bottom := "Продано" if state == "sold" else ("Пусто" if state == "empty" else "%d зол." % price)
	var price_l := _label(bottom, 24, Color(1, 1, 1, 0.7) if gone else (Color(1.0, 0.6, 0.6) if state == "poor" else GOLD))
	price_l.position = Vector2(0, 204)
	price_l.size = Vector2(CARD_SIZE.x, 34)
	b.add_child(price_l)

	if count > 1 and not gone:
		var badge := _label("×%d" % count, 24, Color.WHITE)
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.position = Vector2(CARD_SIZE.x - 90, 8)
		badge.size = Vector2(78, 32)
		b.add_child(badge)
	return b
