extends Control
class_name HubRosterMenu
## Кнопка «кто живёт дома» (слева сверху в доме). Нажали — вниз выпадает столбик всех персонажей
## из ростера (HubResidents.available): цветной — живёт дома, серый — нет.
## Серый → заселяется (заходит через дверь), цветной → становится серым и испаряется из дома.
## Дома не больше HubResidents.MAX (5) — шестого не пустит (кнопка качнётся).
## Столбик не заезжает ниже Column (там инвентарь): что не влезло — листается колёсиком или
## перетаскиванием. Никаких подложек — только портреты.
## Двигать — в scenes/ui/HubRosterMenu.tscn (RosterButton, Column).

const ITEM_SIZE := Vector2(136, 105)
const GAP := 12.0
const SLIDE_TIME := 0.22
const STAGGER := 0.035
const WHEEL_STEP := 60.0
## Сдвиг мыши, после которого нажатие считается перетаскиванием (а не кликом).
const DRAG_THRESHOLD := 8.0
const GRAY_SHADER := preload("res://ui/gray.gdshader")
const SPRITE_PATH := "res://assets/characters/%s/%s_battle.png"

## Открыт ли (помнится, пока игра запущена).
static var expanded := false

@onready var button: TextureButton = $RosterButton
@onready var column: Control = $Column
@onready var list: Control = $Column/List

var _items: Dictionary = {}   ## id -> TextureButton
var _scroll := 0.0
var _press_y := -1.0
var _press_scroll := 0.0
var _dragged := false
var _tween: Tween

func _ready() -> void:
	z_index = 50
	button.pivot_offset = button.size * 0.5
	button.pressed.connect(_on_button)
	column.clip_contents = true
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_apply(expanded, false)
	if UnitRoster_ != null and not UnitRoster_.changed.is_connected(_on_roster_changed):
		UnitRoster_.changed.connect(_on_roster_changed)

func _on_roster_changed() -> void:
	_build()
	_apply(expanded, false)

func hub() -> Node:
	return get_parent()

func _build() -> void:
	for b in _items.values():
		(b as Node).queue_free()
	_items.clear()
	var y := 0.0
	for id in HubResidents.available():
		var b := TextureButton.new()
		b.name = "%sItem" % id
		var path := SPRITE_PATH % [id, id]
		b.texture_normal = CharacterBust.texture(load(path) as Texture2D, id) if ResourceLoader.exists(path) else null
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.focus_mode = Control.FOCUS_NONE
		b.size = ITEM_SIZE
		b.position = Vector2((column.size.x - ITEM_SIZE.x) * 0.5, y)
		b.pivot_offset = ITEM_SIZE * 0.5
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.set_meta("no_glow", true)
		b.set_meta("y", y)
		var m := ShaderMaterial.new()
		m.shader = GRAY_SHADER
		b.material = m
		b.button_down.connect(_on_item_down)
		b.pressed.connect(_on_item.bind(id))
		b.gui_input.connect(_on_item_input)
		list.add_child(b)
		_items[id] = b
		y += ITEM_SIZE.y + GAP
	list.size = Vector2(column.size.x, maxf(0.0, y - GAP))
	_refresh_colors()
	_set_scroll(_scroll)
	button.visible = not _items.is_empty()

## Цветные — кто дома, серые — кто нет.
func _refresh_colors() -> void:
	var home := HubResidents.residents()
	for id in _items.keys():
		var b: TextureButton = _items[id]
		(b.material as ShaderMaterial).set_shader_parameter("amount", 0.0 if home.has(String(id)) else 1.0)

func _on_item(id: String) -> void:
	if _dragged:
		return
	var b: TextureButton = _items.get(id)
	var on := not HubResidents.is_resident(id)
	var ok: bool = hub().call("set_resident", id, on) if hub() != null and hub().has_method("set_resident") else HubResidents.set_resident(id, on)
	if not ok:
		_shake(b)
		return
	_refresh_colors()
	if b != null:
		b.scale = Vector2(0.88, 0.88)
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _shake(b: Control) -> void:
	if b == null:
		return
	var x := b.position.x
	var tw := b.create_tween()
	for dx in [-10.0, 10.0, -6.0, 6.0, 0.0]:
		tw.tween_property(b, "position:x", x + dx, 0.05)

# --- Прокрутка: колесо и перетаскивание -----------------------------------------------

func _max_scroll() -> float:
	return maxf(0.0, list.size.y - column.size.y)

func _set_scroll(v: float) -> void:
	_scroll = clampf(v, 0.0, _max_scroll())
	list.position.y = -_scroll

func _on_item_down() -> void:
	_press_y = get_global_mouse_position().y
	_press_scroll = _scroll
	_dragged = false

func _on_item_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_scroll(_scroll + WHEEL_STEP)
			accept_event()
		elif e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_scroll(_scroll - WHEEL_STEP)
			accept_event()
	elif e is InputEventMouseMotion and _press_y >= 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var dy := get_global_mouse_position().y - _press_y
		if absf(dy) > DRAG_THRESHOLD:
			_dragged = true
		if _dragged:
			_set_scroll(_press_scroll - dy)

func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		_press_y = -1.0
		if _dragged:
			# Отпустили после перетаскивания — клик не считается (сброс после pressed).
			call_deferred("_clear_drag")

func _clear_drag() -> void:
	_dragged = false

# --- Открыть / закрыть -----------------------------------------------------------------

func _on_button() -> void:
	expanded = not expanded
	_apply(expanded, true)

func _apply(open: bool, animated: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var home_y := -ITEM_SIZE.y
	if not animated:
		for b in _items.values():
			b.position.y = float(b.get_meta("y")) if open else home_y
			b.modulate.a = 1.0 if open else 0.0
			b.visible = open
		return
	_tween = create_tween().set_parallel(true)
	button.scale = Vector2(0.86, 0.86)
	_tween.tween_property(button, "scale", Vector2.ONE, SLIDE_TIME * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var order: Array = _items.values()
	if not open:
		order.reverse()
	var i := 0
	for b: TextureButton in order:
		var delay := STAGGER * i
		i += 1
		if open:
			b.visible = true
			_tween.tween_property(b, "position:y", float(b.get_meta("y")), SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(b, "modulate:a", 1.0, SLIDE_TIME * 0.7).set_delay(delay)
		else:
			_tween.tween_property(b, "position:y", home_y - _scroll, SLIDE_TIME * 0.8).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.tween_property(b, "modulate:a", 0.0, SLIDE_TIME * 0.8).set_delay(delay)
	_tween.chain().tween_callback(func() -> void:
		for b in _items.values():
			b.visible = open)
