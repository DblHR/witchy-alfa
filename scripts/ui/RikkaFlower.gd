extends TextureRect
class_name RikkaFlower
## Цветок Рикки в её лавке (появляется с 3-го уровня отряда). Клик по самому цветку (не по прозрачному
## краю): в первый раз — сцена знакомства (rikka_flower_intro, игрок даёт ему имя), дальше — окно
## кормления (FlowerFeedPanel). Пока сцену не смотрели, над цветком «!».

signal clicked

const TEXTURE := "res://assets/npc/rikka/igor_the_plant.png"
const STOOL_TEXTURE := "res://assets/npc/rikka/stool.png"
## Где стоит (экран 1920×1080): цветок — на табуретке слева от Рикки, ножки табуретки уходят
## под нижний край. FOOT — точка, где низ цветка (горшка) стоит на табуретке; картинка цветка
## вписывается в MAX_SIZE и ставится низом на FOOT (так встаёт и другая картинка — Бингус).
const FOOT := Vector2(978, 1007)
const MAX_SIZE := Vector2(320, 460)
const STOOL_RECT := Rect2(811, 948, 335, 152)
## Старое — прямоугольник цветка по умолчанию (для тестов и пузырей).
const RECT := Rect2(818, 576, 320, 460)
## Где «!» над цветком (доля размера картинки).
const BADGE_POS := Vector2(0.80, 0.06)
const NPC_ID := "rikka_flower"
const INTRO_ID := "rikka_flower_intro"
const UNLOCK_LEVEL := 3

var _image: Image
## Рикка за цветком: курсор над прозрачной частью цветка «проходит» к ней (обводка, клик).
var below: NpcBubbles
var _hovered := false
var _chomp: Tween

## Цветок уже стоит в лавке: уровень отряда 3+ (или знакомство уже было).
static func is_unlocked() -> bool:
	if StoryState_ != null and StoryState_.has_seen_dialogue(INTRO_ID):
		return true
	return DungRun != null and DungRun.party_level >= UNLOCK_LEVEL

static func intro_seen() -> bool:
	return StoryState_ != null and StoryState_.has_seen_dialogue(INTRO_ID)

## Имя цветка, которое дал игрок (до знакомства — «Цветочек»).
static func flower_name() -> String:
	return StoryState_.get_custom_name(NPC_ID, "Цветочек") if StoryState_ != null else "Цветочек"

## Имя для меню (окно кормления): особые имена показываются по таблице display (name_rules.json).
static func display_name() -> String:
	return NameRules.display_name(NPC_ID, flower_name())

## Табуретка под цветком (отдельная картинка, ставится перед цветком).
static func make_stool() -> TextureRect:
	var t := TextureRect.new()
	t.name = "FlowerStool"
	t.texture = load(STOOL_TEXTURE) as Texture2D if ResourceLoader.exists(STOOL_TEXTURE) else null
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	t.position = STOOL_RECT.position
	t.size = STOOL_RECT.size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

func _init() -> void:
	name = "RikkaFlower"
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	refresh_texture()
	mouse_filter = Control.MOUSE_FILTER_PASS
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(func() -> void:
		_set_hover(false)
		if below != null:
			below.unhover())

func _ready() -> void:
	refresh_badge()
	GalleryData.mark_seen(TEXTURE)   ## в галерее — в разделе Рикки

## Загрузить картинку; если Godot её не импортировал (битый .import) — прочитать файл напрямую.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var t := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if t != null:
			return t
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

## Картинка по имени (особое имя — своя картинка, см. NameRules) и место на табуретке.
func refresh_texture() -> void:
	var path := NameRules.texture_for(NPC_ID)
	if path == "":
		path = TEXTURE
	texture = _load_texture(path)
	_image = null
	if texture == null:
		position = RECT.position
		size = RECT.size
	else:
		var ts := texture.get_size()
		var k := minf(MAX_SIZE.x / ts.x, MAX_SIZE.y / ts.y)
		var img := texture.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		var bottom := ts.y
		if img != null:
			var used := img.get_used_rect()
			if used.size.y > 0:
				bottom = float(used.end.y)
		size = ts * k
		position = Vector2(FOOT.x - size.x * 0.5, FOOT.y - bottom * k)
	pivot_offset = Vector2(size.x * 0.5, size.y)
	if is_inside_tree():
		refresh_badge()

func refresh_badge() -> void:
	var news := StoryDialogueDB_ != null and StoryDialogueDB_.npc_has_news(NPC_ID)
	NotifyBadge.attach(self, news, Vector2(size.x * BADGE_POS.x, size.y * BADGE_POS.y))

## Цветок что-то съел: «ам!» — сжался и подпрыгнул.
func chomp() -> void:
	if _chomp != null and _chomp.is_valid():
		_chomp.kill()
	scale = Vector2.ONE
	_chomp = create_tween()
	_chomp.tween_property(self, "scale", Vector2(1.08, 0.90), 0.07)
	_chomp.tween_property(self, "scale", Vector2(0.95, 1.07), 0.09)
	_chomp.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Непрозрачный пиксель картинки под точкой p (локально)?
func pixel_hit(p: Vector2) -> bool:
	if texture == null:
		return Rect2(Vector2.ZERO, size).has_point(p)
	var ts := texture.get_size()
	var k := minf(size.x / ts.x, size.y / ts.y)
	var draw := ts * k
	var uv := (p - (size - draw) * 0.5) / draw
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return false
	if _image == null:
		_image = texture.get_image()
		if _image != null and _image.is_compressed():
			_image.decompress()
	if _image == null:
		return true
	return _image.get_pixelv(Vector2i(int(uv.x * _image.get_width()), int(uv.y * _image.get_height()))).a > 0.4

func _set_hover(on: bool) -> void:
	if on == _hovered:
		return
	_hovered = on
	HoverOutline.set_on(self, on)   ## тонкая обводка вместо подсветки
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW

func _on_gui_input(event: InputEvent) -> void:
	if DialogueManager_ != null and DialogueManager_.is_showing():
		_set_hover(false)
		return
	var is_click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not (event is InputEventMouseMotion or is_click):
		return
	var hit := pixel_hit(event.position)
	_set_hover(hit)
	if hit:
		if below != null:
			below.unhover()
		if is_click:
			accept_event()
			clicked.emit()
	elif below != null:
		below.pointer_at(get_global_transform() * event.position, is_click)
