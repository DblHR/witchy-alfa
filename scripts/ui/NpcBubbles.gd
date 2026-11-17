extends Node
class_name NpcBubbles
## Дежурные фразы NPC пузырями (Сессилия, Ноктрис, Рикка): пузырь у NPC, клик по самой картинке
## (не по прозрачному краю) — ещё одна случайная дежурная фраза. Пока открыт диалог (VN),
## картинка NPC прячется, пузыри убираются.
##
##   var nb := NpcBubbles.attach(host_control, npc_sprite, "lamia")
##   nb.say(lines)            ## показать реплики по очереди
##   nb.say_random_bark()     ## случайная дежурная фраза этого NPC

## Где у NPC появляется пузырь: точка под нижним краем пузыря, экран 1920×1080.
## Пузыри ниже лица — на уровне пояса/подола. Подвинуть — здесь.
const BUBBLE_POS := {
	"lamia": Vector2(1330, 905),
	"nurse": Vector2(1340, 905),
	"rabbit_shop": Vector2(1330, 905),
}
const DEFAULT_POS := Vector2(1340, 905)
## Пауза между репликами одной фразы, если в ней несколько строк, сек.
const LINE_GAP := 3.2

var npc_id := ""
## Доп. условие «сейчас кликать нельзя» (например, открыта картинка услуги). Возвращает bool.
var blocked: Callable

var _host: Control
var _sprite: TextureRect
var _layer: BattleSpeechLayer
var _anchor: Node2D
var _hider: VnSpriteHider
var _token := 0
var _last_bark_id := ""
var _hovered := false
var _image: Image
var _image_tex: Texture2D

static func attach(host: Control, sprite: TextureRect, p_npc_id: String) -> NpcBubbles:
	var nb := NpcBubbles.new()
	nb.name = "NpcBubbles"
	nb.npc_id = p_npc_id
	nb._host = host
	nb._sprite = sprite
	host.add_child(nb)
	# Слой пузырей — поверх всего, что уже есть у host.
	nb._layer = BattleSpeechLayer.new()
	nb._layer.name = "NpcBubbleLayer"
	nb._layer.bubble_offset = Vector2.ZERO
	nb._layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	nb._layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(nb._layer)
	nb._anchor = Node2D.new()
	nb._anchor.name = "NpcBubbleAnchor"
	host.add_child(nb._anchor)
	if sprite != null:
		sprite.mouse_filter = Control.MOUSE_FILTER_PASS
		sprite.gui_input.connect(nb._on_sprite_gui_input)
		nb._hider = VnSpriteHider.attach(nb, [sprite])
	return nb

## Пузыри поверх элементов, добавленных host-ом позже.
func raise_layer() -> void:
	if _layer != null and _layer.get_parent() != null:
		_layer.get_parent().move_child(_layer, -1)

func _ready() -> void:
	if DialogueManager_ != null and not DialogueManager_.showing_changed.is_connected(_on_vn_changed):
		DialogueManager_.showing_changed.connect(_on_vn_changed)

func _exit_tree() -> void:
	if DialogueManager_ != null and DialogueManager_.showing_changed.is_connected(_on_vn_changed):
		DialogueManager_.showing_changed.disconnect(_on_vn_changed)

func _on_vn_changed(on: bool) -> void:
	if on:
		clear()
		_set_hover(false)

## Показать реплики пузырями по очереди (берётся только текст).
func say(lines: Array) -> void:
	if _layer == null:
		return
	_token += 1
	var token := _token
	_anchor.global_position = BUBBLE_POS.get(npc_id, DEFAULT_POS)
	_layer.clear_lines()
	for l in lines:
		if token != _token or not is_inside_tree():
			return
		var text := String(l.get("text", "")).strip_edges()
		if text == "":
			continue
		_layer.show_line_for_actor(_anchor, text)
		await get_tree().create_timer(LINE_GAP).timeout

## Ещё одна случайная дежурная фраза этого NPC (не та же, что в прошлый раз).
func say_random_bark() -> void:
	if StoryDialogueDB_ == null or npc_id == "":
		return
	var pool: Array = StoryDialogueDB_.routine_dialogues(npc_id)
	if pool.size() > 1:
		pool = pool.filter(func(d): return String(d.get("id", "")) != _last_bark_id)
	if pool.is_empty():
		return
	var d: Dictionary = pool[randi() % pool.size()]
	_last_bark_id = String(d.get("id", ""))
	say(StoryDialogueDB_.resolve_lines(d))

func clear() -> void:
	_token += 1
	if _layer != null:
		_layer.clear_lines()

func has_bubble() -> bool:
	return _layer != null and _layer._active_bubble != null and is_instance_valid(_layer._active_bubble)

## Пиксель картинки NPC под точкой p (локально) непрозрачный? (картинка вписана с сохранением пропорций)
func pixel_hit(p: Vector2) -> bool:
	if _sprite == null or not _sprite.visible:
		return false
	var tex := _sprite.texture
	if tex == null:
		return false
	var box := _sprite.size
	var ts := tex.get_size()
	var k := minf(box.x / ts.x, box.y / ts.y)
	var draw := ts * k
	var off := (box - draw) * 0.5
	var uv := (p - off) / draw
	if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0:
		return false
	if _image_tex != tex:
		_image_tex = tex
		_image = tex.get_image()
		if _image != null and _image.is_compressed():
			_image.decompress()
	if _image == null:
		return true
	var px := Vector2i(int(uv.x * _image.get_width()), int(uv.y * _image.get_height()))
	return _image.get_pixelv(px).a > 0.4

func _is_blocked() -> bool:
	if DialogueManager_ != null and DialogueManager_.is_showing():
		return true
	return blocked.is_valid() and bool(blocked.call())

func _set_hover(on: bool) -> void:
	if on == _hovered or _sprite == null:
		return
	_hovered = on
	## self_modulate: modulate.a занят прятанием на время диалога.
	var a := _sprite.self_modulate.a   ## альфа может быть занята (Рикка с панелькой в лавке)
	_sprite.self_modulate = Color(1.12, 1.08, 1.12, a) if on else Color(1, 1, 1, a)
	_sprite.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW

func _on_sprite_gui_input(event: InputEvent) -> void:
	if _is_blocked():
		_set_hover(false)
		return
	if event is InputEventMouseMotion:
		_set_hover(pixel_hit(event.position))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if pixel_hit(event.position):
			_sprite.accept_event()
			say_random_bark()
