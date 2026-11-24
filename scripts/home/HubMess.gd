extends TextureRect
class_name HubMess
## Грязь в доме (паутина, лужи, пятна) — Hub.tscn → Mess / MessTop. Появляется в начале игры
## (после обучения) и убирается игроком; когда убрано всё — HubCleaning выдаёт награду.
##
## Двигать / менять картинку — в сцене. Настройки:
##   clicks   — сколько кликов, чтобы убрать (каждый клик — бледнее, с «пуф»);
##   shake    — убирается не кликами, а если помотать звёздочки (паутина на звёздах);
##   covers   — какой предмет (HubToggle) закрыт этой грязью: пока грязь есть, он выключен.
## Клик по грязи над кликабельным предметом ещё и нажимает этот предмет (включает камин и т.п.).
## Что уже убрано — помнится в сохранении (флаг "hub_clean_<имя узла>").

@export var clicks: int = 3
@export var shake: bool = false
@export var covers: NodePath
## Сколько надо «намотать» звёздочками (сумма скоростей × время, px), чтобы паутина спала.
@export var shake_needed: float = 2600.0

signal cleaned(mess: HubMess)

var _left := 0
var _shaken := 0.0
var _img: Image

const FLAG_PREFIX := "hub_clean_"

func flag() -> String:
	return FLAG_PREFIX + String(name)

func is_clean() -> bool:
	return StoryState_ != null and StoryState_.has_flag(flag())

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left = maxi(1, clicks)

## Попадает ли точка экрана в непрозрачную часть (с запасом — паутина тонкая).
func hit(p: Vector2) -> bool:
	if not is_visible_in_tree() or shake or texture == null:
		return false
	var lp := get_global_transform().affine_inverse() * p
	if not Rect2(Vector2.ZERO, size).has_point(lp):
		return false
	if _img == null:
		_img = texture.get_image()
		if _img != null and _img.is_compressed():
			_img.decompress()
	if _img == null:
		return true
	# Ищем непрозрачный пиксель рядом (радиус ~12 px), чтобы по тонкой паутине было легко попасть.
	var k := Vector2(_img.get_width(), _img.get_height()) / size
	var c := Vector2i(lp * k)
	for dy in range(-12, 13, 6):
		for dx in range(-12, 13, 6):
			var q := (c + Vector2i(dx, dy)).clamp(Vector2i.ZERO, Vector2i(_img.get_width() - 1, _img.get_height() - 1))
			if _img.get_pixelv(q).a > 0.2:
				return true
	return false

## Один клик по грязи: бледнеет, на последнем — исчезает.
func scrub() -> void:
	if is_clean():
		return
	_left -= 1
	_poof()
	if _left <= 0:
		_finish()
		return
	var t := create_tween()
	t.tween_property(self, "modulate:a", float(_left) / float(maxi(1, clicks)), 0.15)

## Звёздочки мотаются: amount — сколько «намотали» за кадр.
func shake_by(amount: float) -> void:
	if not shake or is_clean() or not visible:
		return
	_shaken += amount
	modulate.a = clampf(1.0 - _shaken / shake_needed, 0.0, 1.0)
	if _shaken >= shake_needed:
		_finish()

func _finish() -> void:
	if StoryState_ != null:
		StoryState_.set_flag(flag(), true)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.25)
	t.tween_callback(func() -> void: visible = false)
	cleaned.emit(self)

## Облачко пылинок на месте клика.
func _poof() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.lifetime = 0.6
	p.explosiveness = 0.9
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 140.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(0.85, 0.85, 0.95, 0.8)
	var mp := get_viewport().get_mouse_position() if get_viewport() != null else global_position + size * 0.5
	var host: Node = get_parent() if get_parent() != null else self
	host.add_child(p)   ## не внутрь самой грязи — она гаснет
	p.global_position = mp
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
