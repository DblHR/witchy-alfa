extends CanvasLayer
class_name CardUltSplash
## Заставка ульты: экран вспыхивает белым, по центру появляется картинка ульты,
## белое затухает, картинка плавно покачивается влево-вправо и через несколько секунд пропадает.
## Клик в любом месте — пропустить. Картинка: CharacterData.ult_splash, а если пусто —
## файл в assets/pics/ui/battle pics/, имя которого начинается с id героини и содержит «ult»
## (например fufu_ult.png).

signal finished

const PICS_DIR := "res://assets/pics/ui/battle pics"
## Тайминги, сек.
const WHITE_FADE_TIME := 1.4     ## белый экран затухает
const SHOW_TIME := 3.2           ## сколько картинка на экране после вспышки (до начала исчезновения)
const FADE_OUT_TIME := 0.45
const SKIP_FADE_TIME := 0.18
## Размер картинки: доля высоты экрана.
const HEIGHT_RATIO := 0.9
## Покачивание.
const SWAY_X := 18.0
const SWAY_PERIOD := 1.6
const SWAY_ROT_DEG := 1.2

var _white: ColorRect
var _dim: ColorRect
var _pic: TextureRect
var _tween: Tween
var _sway: Tween
var _done := false
static var _cache: Dictionary = {}   ## id -> Texture2D или null

func _init() -> void:
	layer = 40
	name = "UltSplash"

## Картинка ульты героини или null.
static func splash_for(data: CharacterData) -> Texture2D:
	if data == null:
		return null
	if data.ult_splash != null:
		return data.ult_splash
	if _cache.has(data.id):
		return _cache[data.id]
	var found: Texture2D = null
	for f in DirAccess.get_files_at(PICS_DIR):
		var file := f.trim_suffix(".remap").trim_suffix(".import")
		var low := file.to_lower()
		if not low.ends_with(".png") and not low.ends_with(".webp") and not low.ends_with(".jpg"):
			continue
		if low.begins_with(data.id.to_lower()) and low.contains("ult"):
			found = load(PICS_DIR + "/" + file)
			break
	_cache[data.id] = found
	return found

## Показать заставку. await splash.finished — когда она закончилась (или её пропустили).
func play(tex: Texture2D) -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(_on_input)
	add_child(root)

	_dim = ColorRect.new()
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.05, 0.02, 0.08, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_dim)

	var screen := root.get_viewport_rect().size
	var h := screen.y * HEIGHT_RATIO
	var w := h * float(tex.get_width()) / float(maxi(1, tex.get_height()))
	_pic = TextureRect.new()
	_pic.texture = tex
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.size = Vector2(w, h)
	_pic.position = (screen - _pic.size) * 0.5
	_pic.pivot_offset = _pic.size * 0.5
	_pic.scale = Vector2(1.08, 1.08)
	root.add_child(_pic)

	_white = ColorRect.new()
	_white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_white.color = Color(1, 1, 1, 1)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_white)

	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_white, "color:a", 0.0, WHITE_FADE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_pic, "scale", Vector2.ONE, WHITE_FADE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(maxf(0.0, SHOW_TIME - WHITE_FADE_TIME))
	_tween.chain().tween_callback(func() -> void: _fade_out(FADE_OUT_TIME))
	_start_sway()

func _start_sway() -> void:
	var base_x := _pic.position.x
	var rot := deg_to_rad(SWAY_ROT_DEG)
	_sway = create_tween().set_loops()
	_sway.tween_property(_pic, "position:x", base_x + SWAY_X, SWAY_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sway.parallel().tween_property(_pic, "rotation", rot, SWAY_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_sway.tween_property(_pic, "position:x", base_x - SWAY_X, SWAY_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sway.parallel().tween_property(_pic, "rotation", -rot, SWAY_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sway.tween_property(_pic, "position:x", base_x, SWAY_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_sway.parallel().tween_property(_pic, "rotation", 0.0, SWAY_PERIOD * 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _on_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_fade_out(SKIP_FADE_TIME)

func _fade_out(time: float) -> void:
	if _done:
		return
	_done = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_pic, "modulate:a", 0.0, time)
	_tween.tween_property(_dim, "color:a", 0.0, time)
	_tween.tween_property(_white, "color:a", 0.0, time)
	_tween.chain().tween_callback(func() -> void:
		if _sway != null and _sway.is_valid():
			_sway.kill()
		finished.emit()
		queue_free()
	)
