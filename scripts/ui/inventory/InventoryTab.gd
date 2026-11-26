extends TextureButton
class_name InventoryTab
## Вкладка книги инвентаря (Inventory.tscn → Book): торчит из-под страниц.
## При наведении «вытаскивается» наружу (out_dir) — каждый раз чуть по-своему: насколько
## (hover_out: от..до), сдвиг вбок (hover_side), наклон (wiggle_deg), увеличение (hover_scale),
## и обводится светлым контуром (outline_color, outline_width). Выбранная — выдвинута на selected_out.
## Кликается только видимая часть: непрозрачная и не под страницами (page_rect — в координатах Book).
## Все числа — в пикселях картинки книги (Book масштабирован).

@export var out_dir := Vector2.LEFT
@export var hover_out := Vector2(26.0, 46.0)
@export var hover_side := 10.0
@export var wiggle_deg := 3.5
@export var hover_scale := Vector2(1.03, 1.07)
@export var selected_out := 20.0
@export var page_rect := Rect2(101, 43, 2404, 1451)
@export var outline_color := Color(1.0, 0.93, 0.98)
@export var outline_width := 10.0
@export var anim_time := 0.22

const OUTLINE_SHADER := preload("res://scripts/ui/inventory/tab_outline.gdshader")

## Куда вкладка возвращается (её место в сцене); move_home() — переставить (фильтры фракций).
var base_position := Vector2.ZERO
var _hover := false
var _mask: BitMap
var _tw: Tween

func _init() -> void:
	set_meta("no_glow", true)   ## своя подсветка вместо ButtonGlow

func _ready() -> void:
	base_position = position
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	pivot_offset = size * 0.5
	var m := ShaderMaterial.new()
	m.shader = OUTLINE_SHADER
	m.set_shader_parameter("outline_color", outline_color)
	m.set_shader_parameter("width", 0.0)
	material = m
	if texture_normal != null:
		var img := texture_normal.get_image()
		if img != null:
			if img.is_compressed():
				img.decompress()
			_mask = BitMap.new()
			_mask.create_from_image_alpha(img, 0.3)
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)
	toggled.connect(func(_on: bool) -> void: _to_rest())
	_to_rest(true)

func _has_point(p: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(p):
		return false
	if _mask != null:
		var ms := _mask.get_size()
		var mp := Vector2i(int(p.x * float(ms.x) / maxf(1.0, size.x)), int(p.y * float(ms.y) / maxf(1.0, size.y)))
		if mp.x < 0 or mp.y < 0 or mp.x >= ms.x or mp.y >= ms.y or not _mask.get_bitv(mp):
			return false
	return not page_rect.has_point(get_transform() * p)

## Новое «своё место» (например, вкладка фракции уехала на закладку и обратно).
func move_home(pos: Vector2, animate: bool = true) -> void:
	base_position = pos
	_hover = false
	_to_rest(not animate)

func _on_enter() -> void:
	if disabled:
		return
	_hover = true
	var side := Vector2(-out_dir.y, out_dir.x)
	var pos := base_position + out_dir * randf_range(hover_out.x, hover_out.y) + side * randf_range(-hover_side, hover_side)
	var k := randf_range(hover_scale.x, hover_scale.y)
	_animate(pos, deg_to_rad(randf_range(-wiggle_deg, wiggle_deg)), Vector2(k, k), outline_width)

func _on_exit() -> void:
	_hover = false
	_to_rest()

func _to_rest(instant: bool = false) -> void:
	if _hover:
		return
	var pos := base_position + out_dir * (selected_out if button_pressed else 0.0)
	if instant:
		if _tw != null:
			_tw.kill()
		position = pos
		rotation = 0.0
		scale = Vector2.ONE
		return
	_animate(pos, 0.0, Vector2.ONE, 0.0)

func _animate(pos: Vector2, rot: float, sc: Vector2, line: float) -> void:
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "position", pos, anim_time)
	_tw.tween_property(self, "rotation", rot, anim_time)
	_tw.tween_property(self, "scale", sc, anim_time)
	_tw.tween_property(material, "shader_parameter/width", line, anim_time * 0.7).set_trans(Tween.TRANS_SINE)
