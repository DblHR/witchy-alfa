extends Control
class_name CardDragPortrait
## Портрет героини, выезжающий слева, пока игрок тащит её карту (как в CZN).
## Картинка: CharacterData.drag_portrait, а если пусто — res://assets/pics/ui/battle pics/<id>_card.png.
## Прозрачные поля картинки обрезаются автоматически (один раз на картинку).

const PORTRAIT_DIR := "res://assets/pics/ui/battle pics/%s_card.png"
## Высота портрета в долях высоты экрана.
const HEIGHT_RATIO := 0.88
## Насколько портрет «заходит» за левый край экрана (доля ширины картинки).
const LEFT_OVERHANG := 0.12
const SLIDE_IN_TIME := 0.22
const SLIDE_OUT_TIME := 0.16
## Откуда выезжает: столько пикселей левее конечной точки.
const SLIDE_DISTANCE := 260.0
## Прозрачность, когда курсор над самой картинкой (чтобы видеть, что под ней).
## В остальное время портрет непрозрачный.
const DIM_ALPHA := 0.3
const DIM_FADE_TIME := 0.12
## Точка считается «на картинке», если пиксель там непрозрачнее этого.
const HIT_ALPHA := 0.15
## Плавное покачивание, пока портрет на экране (как у чиби на поле, только медленнее и мягче).
const SWAY_X := 9.0          ## влево-вправо, px
const SWAY_X_PERIOD := 2.6   ## полный цикл, сек
const BOB_Y := 6.0           ## вверх-вниз, px
const BOB_Y_PERIOD := 3.4
const SWAY_ROT_DEG := 0.8    ## лёгкий наклон

var _slide: Control      ## выезжает/уезжает
var _rect: TextureRect   ## внутри _slide, покачивается
var _tween: Tween
var _sway: Array[Tween] = []
var _shown_id := ""
var _hit_image: Image      ## для проверки, что курсор над непрозрачной частью
var _hit_region := Rect2() ## область обрезанной картинки внутри _hit_image
var _dimmed := false
var _dim_tween: Tween
static var _cropped: Dictionary = {}   ## Texture2D -> AtlasTexture без прозрачных полей

func _init() -> void:
	name = "DragPortrait"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slide = Control.new()
	_slide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide.modulate.a = 0.0
	_slide.visible = false
	add_child(_slide)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_slide.add_child(_rect)

## Картинка для героини или null, если её нет.
static func portrait_for(data: CharacterData) -> Texture2D:
	if data == null:
		return null
	if data.drag_portrait != null:
		return data.drag_portrait
	var path := PORTRAIT_DIR % data.id
	if ResourceLoader.exists(path):
		return load(path)
	return null

## Заранее обрезать картинку, чтобы первое перетаскивание не подтормаживало.
static func warm_up(data: CharacterData) -> void:
	var tex := portrait_for(data)
	if tex != null:
		_crop(tex)

func show_for(data: CharacterData) -> void:
	var tex := portrait_for(data)
	if tex == null:
		hide_portrait()
		return
	if _shown_id == data.id and _slide.visible:
		return
	_shown_id = data.id
	var cropped := _crop(tex)
	var screen := get_viewport_rect().size
	var h := screen.y * HEIGHT_RATIO
	var w := h * float(cropped.get_width()) / float(maxi(1, cropped.get_height()))
	_rect.texture = cropped
	_prepare_hit_test(tex, cropped)
	_dimmed = false
	_rect.modulate.a = 1.0
	_rect.size = Vector2(w, h)
	_rect.position = Vector2.ZERO
	_rect.rotation = 0.0
	_rect.pivot_offset = Vector2(w * 0.5, h)   # качается от «ног», а не от центра
	# Чуть ниже края экрана, чтобы при покачивании вверх не было видно обреза снизу.
	var target := Vector2(-w * LEFT_OVERHANG, screen.y - h + BOB_Y)
	_slide.position = target - Vector2(SLIDE_DISTANCE, 0)
	_slide.modulate.a = 0.0
	_slide.visible = true
	_kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_slide, "position", target, SLIDE_IN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_slide, "modulate:a", 1.0, SLIDE_IN_TIME * 0.7)
	_start_sway()

## Вызывается при каждом движении мыши во время перетаскивания.
func update_hover(point: Vector2) -> void:
	if not _slide.visible or _shown_id == "":
		return
	var over := _is_over_picture(point)
	if over == _dimmed:
		return
	_dimmed = over
	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = create_tween()
	_dim_tween.tween_property(_rect, "modulate:a", DIM_ALPHA if over else 1.0, DIM_FADE_TIME)

static var _images: Dictionary = {}   ## Texture2D -> Image (картинка читается с GPU один раз)

func _prepare_hit_test(tex: Texture2D, cropped: Texture2D) -> void:
	if not _images.has(tex):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		_images[tex] = img
	_hit_image = _images[tex]
	if cropped is AtlasTexture:
		_hit_region = (cropped as AtlasTexture).region
	elif _hit_image != null:
		_hit_region = Rect2(Vector2.ZERO, _hit_image.get_size())

func _is_over_picture(point: Vector2) -> bool:
	var local := _rect.get_global_transform().affine_inverse() * point
	if not Rect2(Vector2.ZERO, _rect.size).has_point(local):
		return false
	if _hit_image == null or _hit_region.size.x <= 0.0:
		return true
	var uv := local / _rect.size
	var px := Vector2i(_hit_region.position + uv * _hit_region.size)
	px = px.clamp(Vector2i.ZERO, _hit_image.get_size() - Vector2i.ONE)
	return _hit_image.get_pixelv(px).a > HIT_ALPHA

func _start_sway() -> void:
	_stop_sway()
	var rot := deg_to_rad(SWAY_ROT_DEG)
	var sx := _rect.create_tween().set_loops()
	sx.tween_property(_rect, "position:x", SWAY_X, SWAY_X_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sx.parallel().tween_property(_rect, "rotation", rot, SWAY_X_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	sx.tween_property(_rect, "position:x", -SWAY_X, SWAY_X_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sx.parallel().tween_property(_rect, "rotation", -rot, SWAY_X_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sx.tween_property(_rect, "position:x", 0.0, SWAY_X_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sx.parallel().tween_property(_rect, "rotation", 0.0, SWAY_X_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var sy := _rect.create_tween().set_loops()
	sy.tween_property(_rect, "position:y", -BOB_Y, BOB_Y_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sy.tween_property(_rect, "position:y", 0.0, BOB_Y_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sway = [sx, sy]

func _stop_sway() -> void:
	for t in _sway:
		if t.is_valid():
			t.kill()
	_sway.clear()

func hide_portrait() -> void:
	_shown_id = ""
	if not _slide.visible:
		return
	_kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_slide, "position:x", _slide.position.x - SLIDE_DISTANCE, SLIDE_OUT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_slide, "modulate:a", 0.0, SLIDE_OUT_TIME)
	_tween.chain().tween_callback(func() -> void:
		_slide.visible = false
		_stop_sway()
	)

func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

static func _crop(tex: Texture2D) -> Texture2D:
	if _cropped.has(tex):
		return _cropped[tex]
	var out: Texture2D = tex
	var img := tex.get_image()
	if img != null and img.is_compressed():
		img.decompress()
	_images[tex] = img
	if img != null:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size != img.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(used)
			out = atlas
	_cropped[tex] = out
	return out
