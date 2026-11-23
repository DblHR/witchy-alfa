extends ColorRect
class_name CardSleeve
## Рукав: зона справа от руки (между рукой и кнопкой «Завершить ход»), куда можно отложить карту. Отложенная карта не сбрасывается
## в конце хода и в следующий ход возвращается в руку, а добирается на столько же меньше.
## Здесь только зона и её карты; колодой и рукой распоряжается CardBattle.

## Клик по карте в рукаве (CardBattle возвращает её в руку).
signal card_clicked(card: CardInstance)

## Сколько карт можно отложить (растёт с метапрогрессией).
const SLOTS := 1
## Рукав на 35% меньше прежнего (190×262): картинка и карта в нём.
const RECT := Rect2(1428, 882, 124, 170)
## Карта в рукаве уменьшена (CARD_SCALE) и стоит по центру картинки.
const CARD_SCALE := 0.65
const CARD_OFFSET := Vector2(13, 17)
## Картинка рукава (вместо цветной плашки с подписью). Пока над ним тащат карту — светится.
const ART_PATH := "res://assets/ui/battle/sleeve.png"
const ART_IDLE := Color(1, 1, 1, 1)
const ART_ACTIVE := Color(1.35, 1.2, 1.45, 1)
## Без картинки — старая плашка.
const COLOR_IDLE := Color(0.35, 0.2, 0.45, 0.35)
const COLOR_ACTIVE := Color(0.75, 0.45, 0.95, 0.6)

var cards: Array[CardInstance] = []
var _label: Label
var _views: Array[CardView] = []
var _art: TextureRect

func _init() -> void:
	name = "SleeveZone"
	color = COLOR_IDLE
	position = RECT.position
	size = RECT.size
	# Наведение — подсказка, что такое рукав (HoverTips). Клики проходят дальше.
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_show_tip)
	mouse_exited.connect(func() -> void: HoverTips.hide_tips(self))
	if ResourceLoader.exists(ART_PATH):
		color = Color(0, 0, 0, 0)
		_art = TextureRect.new()
		_art.name = "Art"
		_art.texture = load(ART_PATH) as Texture2D
		_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_art)
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

## Что написано в подсказке рукава.
const TIP_TITLE := "Рукав"
const TIP_TEXT := "Перетащите сюда карту — она не уйдёт в сброс в конце хода и в следующий ход вернётся в руку (добор будет на одну карту меньше). Клик по карте в рукаве — вернуть её в руку сейчас."

func _show_tip() -> void:
	HoverTips.show_tips(self, HoverTips.screen_rect.bind(self), [HoverTips.box(TIP_TITLE, TIP_TEXT, Color(0.8, 0.7, 1.0))])

func set_hover(on: bool) -> void:
	if on:
		HoverTips.hide_tips(self)
	if _art != null:
		_art.modulate = ART_ACTIVE if on else ART_IDLE
	else:
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
			var host: Node = v.get_parent()
			(host if host != self and host != null else v).queue_free()
	_views.clear()
	_label.visible = _art == null or SLOTS > 1   ## с картинкой подписи не нужны (кроме счётчика, если мест больше одного)
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
		# Карта в уменьшенной рамке: увеличение при наведении работает относительно неё.
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.scale = Vector2(CARD_SCALE, CARD_SCALE)
		holder.position = Vector2(x, CARD_OFFSET.y)
		add_child(holder)
		var cv := CardView.new()
		cv.setup(c, true)
		holder.add_child(cv)
		cv.position = Vector2.ZERO
		cv.home_position = cv.position
		cv.pressed.connect(func(view: CardView) -> void: card_clicked.emit(view.card))
		_views.append(cv)
		x += 14.0
