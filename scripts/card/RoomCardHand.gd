class_name RoomCardHand
extends Control
## Выбор следующей комнаты картами в руке: 1-3 карты комнат (CardRun.pending_choices).
## Карту разыгрывают как боевую — вытянуть из руки вверх и отпустить (или просто кликнуть).
## Сигнал chosen(index) — номер выбранной карты.

signal chosen(choice_index: int)

const CARD_SIZE := Vector2(210, 294)
const CARD_GAP := 26.0
const HAND_CENTER_X := 960.0
const HAND_TOP_Y := 762.0
const HOVER_SCALE := 1.22
## Отпустить карту выше этой линии — разыграть; ниже — вернуть в руку.
const PLAY_LINE_Y := 720.0
const CLICK_SLOP := 12.0

const KIND_COLORS := {
	"battle": Color(1.0, 0.55, 0.5),
	"elite": Color(1.0, 0.72, 0.35),
	"boss": Color(1.0, 0.35, 0.35),
	"quest": Color(0.85, 0.6, 1.0),
	"event": Color(0.6, 0.95, 0.75),
}

static var _art_cache: Dictionary = {}

var _cards: Array[Control] = []
var _homes: Array[Vector2] = []
var _drag: Control = null
var _drag_local := Vector2.ZERO
var _press_pos := Vector2.ZERO
var _hovered: Control = null
var _done := false

func setup(rooms: Array[Dictionary], deck_summary: String = "") -> void:
	name = "RoomCardHand"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title := RunUiKit.make_label("Выберите путь" if rooms.size() > 1 else "Дальше — только сюда", 34, RunUiKit.GOLD)
	title.position = Vector2(0, HAND_TOP_Y - 62.0)
	title.size = Vector2(1920, 44)
	title.add_theme_constant_override("outline_size", 8)
	add_child(title)

	if deck_summary != "":
		var deck := RunUiKit.make_label("Колода комнат", 22, RunUiKit.TEXT_DIM)
		deck.position = Vector2(24, 1020)
		deck.size = Vector2(230, 34)
		deck.mouse_filter = Control.MOUSE_FILTER_STOP
		deck.mouse_default_cursor_shape = Control.CURSOR_HELP
		deck.tooltip_text = "Осталось в колоде комнат:\n" + deck_summary.replace(", ", "\n")
		add_child(deck)

	var total := float(rooms.size()) * CARD_SIZE.x + float(rooms.size() - 1) * CARD_GAP
	for i in range(rooms.size()):
		var card := _make_card(rooms[i])
		var home := Vector2(HAND_CENTER_X - total * 0.5 + float(i) * (CARD_SIZE.x + CARD_GAP), HAND_TOP_Y)
		add_child(card)
		_cards.append(card)
		_homes.append(home)
		# Сдача: карты выезжают снизу по очереди.
		card.position = home + Vector2(0, 360)
		card.modulate.a = 0.0
		var tw := card.create_tween().set_parallel(true)
		tw.tween_property(card, "position", home, 0.28).set_delay(0.08 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.08 * float(i))

# --- Карта --------------------------------------------------------------------

func _make_card(room: Dictionary) -> Control:
	var kind := String(room.get("kind", ""))
	var color: Color = KIND_COLORS.get(kind, Color.WHITE)
	var card := Control.new()
	card.size = CARD_SIZE
	card.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE   ## ввод обрабатывает рука целиком (_input)

	var bg := Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.07, 0.17, 0.98)
	sb.border_color = color
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	bg.add_theme_stylebox_override("panel", sb)
	card.add_child(bg)

	var title := RunUiKit.make_label(CardRun.room_title(room), 26, color)
	title.position = Vector2(8, 10)
	title.size = Vector2(CARD_SIZE.x - 16, 36)
	title.clip_text = true
	card.add_child(title)

	var art_rect := Rect2(14, 52, CARD_SIZE.x - 28, 132)
	var tex := _room_art(room)
	if tex != null:
		var frame := Control.new()
		frame.position = art_rect.position
		frame.size = art_rect.size
		frame.clip_contents = true
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var art := TextureRect.new()
		art.texture = tex
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# Картинка-сцена (сундук: широкий кадр с фоном) заполняет окно, спрайт — вписывается целиком.
		var wide := float(tex.get_width()) > float(tex.get_height()) * 1.3
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if wide else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(art)
		art.position = Vector2.ZERO
		art.size = art_rect.size
	else:
		var q := RunUiKit.make_label("?", 96, color)
		q.position = art_rect.position
		q.size = art_rect.size
		q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(q)

	var hint := RunUiKit.make_label(CardRun.room_hint(room), 17, RunUiKit.TEXT_DIM, true, true)
	hint.position = Vector2(10, 190)
	hint.size = Vector2(CARD_SIZE.x - 20, CARD_SIZE.y - 200)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 4)
	hint.add_theme_constant_override("line_spacing", -2)
	card.add_child(hint)
	return card

## Рисунок карты: главный враг комнаты или NPC ивента (обрезан по видимой части).
static func _room_art(room: Dictionary) -> Texture2D:
	var tex: Texture2D = null
	var key := ""
	match String(room.get("kind", "")):
		"battle", "elite", "boss":
			var enemies: Array = room.get("enemies", [])
			if not enemies.is_empty():
				# В элите главная — героиня за слизнем, в остальных — передний враг.
				key = String(enemies[enemies.size() - 1] if String(room.get("kind", "")) == "elite" else enemies[0])
				if _art_cache.has(key):
					return _art_cache[key]
				var def := EnemyDefs.get_def(key)
				if def != null and def.char_data() != null:
					tex = def.char_data().battle_texture
		"event":
			var event_id := String(room.get("event", ""))
			key = event_id
			match event_id:
				"shop": key = "lamia"
				"statue": key = "statue_white" if String(room.get("variant", "")) == "white" else "statue_black"
			if _art_cache.has(key):
				return _art_cache[key]
			if AssetCatalog_ != null:
				tex = AssetCatalog_.get_event_npc_texture(key)
	if tex == null or key == "":
		return null
	# Обрезаем прозрачные поля (у медсестры картинка на весь кадр), чтобы рисунок заполнял карту.
	var out: Texture2D = tex
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0 and used.size != img.get_size():
			var region := img.get_region(used)
			region.generate_mipmaps()   ## картинка сильно уменьшается — без мипмапов рябит
			out = ImageTexture.create_from_image(region)
	_art_cache[key] = out
	return out

# --- Ввод: наведение, перетаскивание, розыгрыш ---------------------------------

func _mouse() -> Vector2:
	return get_global_transform().affine_inverse() * get_viewport().get_mouse_position()

func _card_at(point: Vector2) -> Control:
	# Сверху вниз по порядку отрисовки: наведённая карта рисуется поверх соседей.
	for i in range(get_child_count() - 1, -1, -1):
		var c := get_child(i) as Control
		if c != null and _cards.has(c) and Rect2(Vector2.ZERO, CARD_SIZE).has_point(c.get_transform().affine_inverse() * point):
			return c
	return null

func _input(event: InputEvent) -> void:
	if _done or not is_visible_in_tree():
		return
	if DialogueManager_ != null and DialogueManager_.is_showing():
		return
	if event is InputEventMouseMotion:
		if _drag != null:
			_place_drag()
			get_viewport().set_input_as_handled()
		else:
			_set_hovered(_card_at(_mouse()))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _drag == null:
			var c := _card_at(_mouse())
			if c != null:
				get_viewport().set_input_as_handled()
				_begin_drag(c)
		elif not event.pressed and _drag != null:
			get_viewport().set_input_as_handled()
			_end_drag()

func _set_hovered(c: Control) -> void:
	if c == _hovered:
		return
	if _hovered != null and is_instance_valid(_hovered):
		_scale_to(_hovered, 1.0)
		_hovered.z_index = 0
	_hovered = c
	if c != null:
		_scale_to(c, HOVER_SCALE)
		c.z_index = 10
		move_child(c, -1)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if c != null else Input.CURSOR_ARROW)

func _scale_to(c: Control, s: float) -> void:
	c.create_tween().tween_property(c, "scale", Vector2(s, s), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _begin_drag(c: Control) -> void:
	_drag = c
	_press_pos = _mouse()
	# Точка карты под курсором (в координатах самой карты) — она и останется под курсором.
	_drag_local = (c.get_transform().affine_inverse() * _press_pos).clamp(Vector2.ZERO, CARD_SIZE)
	c.z_index = 20
	move_child(c, -1)

func _place_drag() -> void:
	var s := _drag.scale
	var pivot := _drag.pivot_offset
	_drag.position = _mouse() - pivot - (_drag_local - pivot) * s

func _end_drag() -> void:
	var c := _drag
	_drag = null
	var m := _mouse()
	var clicked := m.distance_to(_press_pos) <= CLICK_SLOP
	if clicked or m.y < PLAY_LINE_Y:
		_choose(_cards.find(c))
		return
	c.z_index = 0
	c.create_tween().tween_property(c, "position", _homes[_cards.find(c)], 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hovered = null
	_scale_to(c, 1.0)

func _choose(index: int) -> void:
	if _done or index < 0:
		return
	_done = true
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	for i in range(_cards.size()):
		var c := _cards[i]
		var tw := c.create_tween().set_parallel(true)
		if i == index:
			# Разыгранная карта вылетает в центр и растворяется.
			tw.tween_property(c, "position", Vector2(HAND_CENTER_X - CARD_SIZE.x * 0.5, 330.0), 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			tw.tween_property(c, "scale", Vector2(1.35, 1.35), 0.3)
			tw.tween_property(c, "modulate:a", 0.0, 0.2).set_delay(0.25)
		else:
			tw.tween_property(c, "position:y", c.position.y + 380.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(c, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.48).timeout
	chosen.emit(index)

func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
