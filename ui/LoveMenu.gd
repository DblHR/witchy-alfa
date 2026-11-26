extends Control
class_name LoveMenu
## Сердечко в доме (слева сверху, правее кнопки «кто живёт дома»). Пока героиня с отношениями одна —
## нажатие сразу открывает её экран; когда их больше — вниз выезжает столбик кнопок персонажей,
## ещё раз — прячутся (как меню «…» сверху справа).
## Нажатие на персонажа — его экран отношений (SceneRouter_.go_to_love → scenes/love/<id>_love.tscn).
## Кнопки персонажей берутся из папки BUTTONS_DIR: картинка <id>Button.png — кнопка персонажа
## <id> (например fufuButton.png → Фуфу). Кнопка видна, только когда персонаж уже в отряде.
## Новый персонаж с отношениями — просто положить его кнопку в эту папку.
## Двигать сердечко и столбик — в scenes/ui/LoveMenu.tscn (HeartButton, Column: первая кнопка — у
## верхнего края Column, следующие — ниже).

signal character_pressed(unit_id: String)

const BUTTONS_DIR := "res://assets/ui/buttons/love/"
const BUTTON_SUFFIX := "Button.png"
## Размер кнопки персонажа в ряду и промежуток между ними.
const BUTTON_SIZE := Vector2(136, 112)
const GAP := 14.0
const SLIDE_TIME := 0.22
const STAGGER := 0.035

## Открыто ли (запоминается, пока игра запущена).
static var expanded := false

@onready var heart: TextureButton = $HeartButton
@onready var column: Control = $Column
var _buttons: Array[TextureButton] = []
var _open_pos: Dictionary = {}
var _tween: Tween

func _ready() -> void:
	z_index = 50
	heart.pivot_offset = heart.size * 0.5
	heart.pressed.connect(_on_heart)
	_build()
	if _buttons.size() <= 1:
		expanded = false
	_apply(expanded, false)

## Персонажи с отношениями: [{id, texture}] по картинкам в BUTTONS_DIR (только те, кто в отряде).
static func love_characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files := ResourceLoader.list_directory(BUTTONS_DIR)
	var ids: Array[String] = []
	for f in files:
		if f.ends_with(BUTTON_SUFFIX):
			ids.append(f.trim_suffix(BUTTON_SUFFIX))
	ids.sort()
	for id in ids:
		if CharDB != null and CharDB.get_by_id(id) == null:
			continue   ## в папке не только кнопки персонажей (например sexButton.png)
		if UnitRoster_ != null and not UnitRoster_.has_unit(id):
			continue
		var tex := load(BUTTONS_DIR + id + BUTTON_SUFFIX) as Texture2D
		if tex != null:
			out.append({"id": id, "texture": tex})
	return out

func _build() -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_open_pos.clear()
	var y := 0.0
	for c in love_characters():
		var b := TextureButton.new()
		b.name = "%sButton" % String(c["id"])
		b.texture_normal = c["texture"]
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.focus_mode = Control.FOCUS_NONE
		b.size = BUTTON_SIZE
		b.pivot_offset = BUTTON_SIZE * 0.5
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var id := String(c["id"])
		var data: CharacterData = CharDB.get_by_id(id) if CharDB != null else null
		b.tooltip_text = data.display_name if data != null else ""
		b.pressed.connect(func() -> void:
			character_pressed.emit(id)
			_open_love(id))
		add_child(b)
		_buttons.append(b)
		_open_pos[b] = Vector2(column.position.x + (column.size.x - BUTTON_SIZE.x) * 0.5,
			column.position.y + y)
		y += BUTTON_SIZE.y + GAP
	# Пока в отряде нет ни одной героини с экраном отношений — сердечка нет.
	heart.visible = not _buttons.is_empty()

## Днём на экран отношений не пускают: героиня говорит реплику "day_refusal" из своей папки love
## (assets/characters/<id>/love/interactions.json). Сексуальные взаимодействия — только ночью.
func _open_love(id: String) -> void:
	if DayCycle.is_night():
		SceneRouter_.go_to_love(id)
		return
	if DialogueManager_ == null or DialogueManager_.is_showing():
		return
	var lines := Interactions.day_refusal_lines(id)
	if not lines.is_empty():
		DialogueManager_.show_sequence(lines)

func character_ids() -> Array[String]:
	var out: Array[String] = []
	for b in _buttons:
		out.append(String(b.name).trim_suffix("Button"))
	return out

## Пока героиня с отношениями одна (Фуфу) — сердечко сразу открывает её экран; больше — столбик.
func _on_heart() -> void:
	if _buttons.size() == 1:
		heart.scale = Vector2(0.86, 0.86)
		heart.create_tween().tween_property(heart, "scale", Vector2.ONE, SLIDE_TIME * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var id := character_ids()[0]
		character_pressed.emit(id)
		_open_love(id)
		return
	expanded = not expanded
	_apply(expanded, true)

func _home() -> Vector2:
	return heart.position + (heart.size - BUTTON_SIZE) * 0.5

func _apply(open: bool, animated: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var home := _home()
	if not animated:
		for b in _buttons:
			b.position = _open_pos[b] if open else home
			b.modulate.a = 1.0 if open else 0.0
			b.scale = Vector2.ONE if open else Vector2(0.4, 0.4)
			b.visible = open
		return
	_tween = create_tween().set_parallel(true)
	# Сердечко «бьётся» при нажатии.
	heart.scale = Vector2(0.86, 0.86)
	_tween.tween_property(heart, "scale", Vector2.ONE, SLIDE_TIME * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var order := _buttons.duplicate()
	if not open:
		order.reverse()
	var i := 0
	for b: TextureButton in order:
		var delay := STAGGER * i
		i += 1
		if open:
			b.visible = true
			_tween.tween_property(b, "position", _open_pos[b], SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(b, "modulate:a", 1.0, SLIDE_TIME * 0.7).set_delay(delay)
			_tween.tween_property(b, "scale", Vector2.ONE, SLIDE_TIME).set_delay(delay)
		else:
			_tween.tween_property(b, "position", home, SLIDE_TIME * 0.8).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.tween_property(b, "modulate:a", 0.0, SLIDE_TIME * 0.8).set_delay(delay)
			_tween.tween_property(b, "scale", Vector2(0.4, 0.4), SLIDE_TIME * 0.8).set_delay(delay)
	_tween.chain().tween_callback(func() -> void:
		for b in _buttons:
			b.visible = open)
