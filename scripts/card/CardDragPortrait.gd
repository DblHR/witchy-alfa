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
## Прозрачность, когда карту бросают на союзника: портрет не должен закрывать цели.
const DIM_ALPHA := 0.3

var _rect: TextureRect
var _tween: Tween
var _shown_id := ""
static var _cropped: Dictionary = {}   ## Texture2D -> AtlasTexture без прозрачных полей

func _init() -> void:
	name = "DragPortrait"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect = TextureRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_rect.modulate.a = 0.0
	_rect.visible = false
	add_child(_rect)

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

## dimmed — полупрозрачный портрет (для карт, которые бросают на союзников).
func show_for(data: CharacterData, dimmed: bool = false) -> void:
	var tex := portrait_for(data)
	if tex == null:
		hide_portrait()
		return
	if _shown_id == data.id and _rect.visible:
		return
	_shown_id = data.id
	var cropped := _crop(tex)
	var screen := get_viewport_rect().size
	var h := screen.y * HEIGHT_RATIO
	var w := h * float(cropped.get_width()) / float(maxi(1, cropped.get_height()))
	_rect.texture = cropped
	_rect.size = Vector2(w, h)
	var target := Vector2(-w * LEFT_OVERHANG, screen.y - h)
	_rect.position = target - Vector2(SLIDE_DISTANCE, 0)
	_rect.modulate.a = 0.0
	_rect.visible = true
	_kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_rect, "position", target, SLIDE_IN_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_rect, "modulate:a", DIM_ALPHA if dimmed else 1.0, SLIDE_IN_TIME * 0.7)

func hide_portrait() -> void:
	_shown_id = ""
	if not _rect.visible:
		return
	_kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_rect, "position:x", _rect.position.x - SLIDE_DISTANCE, SLIDE_OUT_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_rect, "modulate:a", 0.0, SLIDE_OUT_TIME)
	_tween.chain().tween_callback(func() -> void: _rect.visible = false)

func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

static func _crop(tex: Texture2D) -> Texture2D:
	if _cropped.has(tex):
		return _cropped[tex]
	var out: Texture2D = tex
	var img := tex.get_image()
	if img != null:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size != img.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(used)
			out = atlas
	_cropped[tex] = out
	return out
