extends ColorRect
class_name CardSleeve
## Рукав: зона слева от руки, куда можно отложить карту. Отложенная карта не сбрасывается
## в конце хода и в следующий ход возвращается в руку, а добирается на столько же меньше.
## Здесь только зона и её карты; колодой и рукой распоряжается CardBattle.

## Клик по карте в рукаве (CardBattle возвращает её в руку).
signal card_clicked(card: CardInstance)

## Сколько карт можно отложить (растёт с метапрогрессией).
const SLOTS := 1
const RECT := Rect2(250, 790, 190, 262)
const CARD_OFFSET := Vector2(20, 42)
const COLOR_IDLE := Color(0.35, 0.2, 0.45, 0.35)
const COLOR_ACTIVE := Color(0.75, 0.45, 0.95, 0.6)

var cards: Array[CardInstance] = []
var _label: Label
var _views: Array[CardView] = []

func _init() -> void:
	name = "SleeveZone"
	color = COLOR_IDLE
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

func _ready() -> void:
	refresh()

static func in_zone(point: Vector2) -> bool:
	return RECT.has_point(point)

func set_hover(on: bool) -> void:
	color = COLOR_ACTIVE if on else COLOR_IDLE

func is_full() -> bool:
	return cards.size() >= SLOTS

## Точка, откуда «вылетает» карта, вынутая из рукава.
func card_origin() -> Vector2:
	return global_position + CARD_OFFSET

func put(card: CardInstance) -> void:
	cards.append(card)
	refresh()
	if not _views.is_empty():
		var v := _views[-1]
		v.modulate.a = 0.0
		v.create_tween().tween_property(v, "modulate:a", 1.0, 0.18)

func take(card: CardInstance) -> bool:
	var idx := cards.find(card)
	if idx == -1:
		return false
	cards.remove_at(idx)
	refresh()
	return true

## Забрать все карты (начало хода).
func take_all() -> Array[CardInstance]:
	var out := cards.duplicate()
	cards.clear()
	refresh()
	return out

func clear() -> void:
	cards.clear()
	refresh()

## Герой выбыл — его карты пропадают и из рукава.
func remove_owner(owner_id: String) -> void:
	for i in range(cards.size() - 1, -1, -1):
		if cards[i].owner_id == owner_id:
			cards.remove_at(i)
	refresh()

## Перерисовывает рукав: настоящие карты в зоне; клик по карте — вынуть обратно в руку.
func refresh() -> void:
	for v in _views:
		if is_instance_valid(v):
			v.queue_free()
	_views.clear()
	if cards.is_empty():
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.text = "Рукав\n\nперетащи сюда карту — она вернётся в руку в следующий ход" if SLOTS == 1 else "Рукав 0/%d" % SLOTS
		_label.add_theme_font_size_override("font_size", 17)
		return
	_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_label.text = "Рукав %d/%d" % [cards.size(), SLOTS]
	_label.add_theme_font_size_override("font_size", 20)
	var x := CARD_OFFSET.x
	for c in cards:
		var cv := CardView.new()
		cv.setup(c, true)
		add_child(cv)
		cv.position = Vector2(x, CARD_OFFSET.y)
		cv.home_position = cv.position
		cv.pressed.connect(func(view: CardView) -> void: card_clicked.emit(view.card))
		_views.append(cv)
		x += 14.0
