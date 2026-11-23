extends CanvasLayer
class_name HoverTips
## Окошки-подсказки при наведении (как в Slay the Spire): столбик тёмных плашек рядом с тем,
## на что навели (карта, значок статуса, значок намерения). Одна общая копия поверх всех сцен.
##
##   HoverTips.show_tips(self, func() -> Rect2: return <прямоугольник на экране>, boxes)
##   HoverTips.hide_tips(self)
##
## boxes — массив словарей {title, text, color, icon}: title — заголовок (цветной, со значком icon),
## text — описание (bbcode). Пустой title — плашка только с текстом.
## Плашки встают справа от прямоугольника (не влезают — слева) и следуют за ним каждый кадр
## (карта в руке при наведении увеличивается). Пропал владелец — подсказки прячутся сами.

const BOX_WIDTH := 380.0
const GAP := 12.0
const SCREEN := Vector2(1920, 1080)
const MARGIN := 8.0
const BG := Color(0.07, 0.04, 0.12, 0.95)
const BORDER := Color(1, 1, 1, 0.22)

static var _inst: HoverTips

var _owner_ref: WeakRef
var _rect_fn: Callable
var _col: VBoxContainer

static func _instance() -> HoverTips:
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_inst = HoverTips.new()
	_inst.name = "HoverTips"
	tree.root.add_child.call_deferred(_inst)
	return _inst

func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_col = VBoxContainer.new()
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 6)
	_col.visible = false
	add_child(_col)

static func show_tips(owner: Object, rect_fn: Callable, boxes: Array) -> void:
	var h := _instance()
	if h == null:
		return
	if boxes.is_empty():
		hide_tips(owner)
		return
	h._owner_ref = weakref(owner)
	h._rect_fn = rect_fn
	for c in h._col.get_children():
		h._col.remove_child(c)
		c.queue_free()
	for b in boxes:
		h._col.add_child(_make_box(b))
	h._col.visible = true
	h._col.reset_size()
	h._place()

## Спрятать (только если сейчас показаны подсказки этого владельца; null — в любом случае).
static func hide_tips(owner: Object = null) -> void:
	if _inst == null or not is_instance_valid(_inst):
		return
	if owner != null and (_inst._owner_ref == null or _inst._owner_ref.get_ref() != owner):
		return
	_inst._owner_ref = null
	_inst._col.visible = false

static func is_shown_for(owner: Object) -> bool:
	return _inst != null and is_instance_valid(_inst) and _inst._col.visible and _inst._owner_ref != null and _inst._owner_ref.get_ref() == owner

## Текст всех плашек (для тестов).
static func shown_text() -> String:
	if _inst == null or not is_instance_valid(_inst) or not _inst._col.visible:
		return ""
	var parts := PackedStringArray()
	for c in _inst._col.get_children():
		var l := c.get_node_or_null("Text") as RichTextLabel
		if l != null:
			parts.append(l.get_parsed_text())
	return " | ".join(parts)

static func box(title: String, text: String, color: Color = Color(1.0, 0.85, 0.95), icon: String = "") -> Dictionary:
	return {"title": title, "text": text, "color": color, "icon": icon}

static func _make_box(b: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	var l := RichTextLabel.new()
	l.name = "Text"
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.custom_minimum_size = Vector2(BOX_WIDTH, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", 18)
	l.add_theme_font_size_override("bold_font_size", 19)
	var t := ""
	var title := String(b.get("title", ""))
	if title != "":
		var icon := String(b.get("icon", ""))
		if icon != "" and ResourceLoader.exists(icon):
			t += "[img=26x26]%s[/img] " % icon
		var col: Color = b.get("color", Color(1.0, 0.85, 0.95))
		t += "[b][color=#%s]%s[/color][/b]" % [col.to_html(false), title]
	var body := String(b.get("text", ""))
	if body != "":
		t += ("\n" if t != "" else "") + body
	l.text = t
	p.add_child(l)
	return p

func _process(_delta: float) -> void:
	if not _col.visible:
		return
	var o: Object = _owner_ref.get_ref() if _owner_ref != null else null
	if o == null or (o is CanvasItem and not (o as CanvasItem).is_visible_in_tree()):
		_owner_ref = null
		_col.visible = false
		return
	_place()

func _place() -> void:
	if not _rect_fn.is_valid():
		return
	var r: Rect2 = _rect_fn.call()
	var sz := _col.get_combined_minimum_size()
	var pos := Vector2(r.end.x + GAP, r.position.y)
	if pos.x + sz.x > SCREEN.x - MARGIN:
		pos.x = r.position.x - GAP - sz.x
	pos.x = clampf(pos.x, MARGIN, SCREEN.x - sz.x - MARGIN)
	pos.y = clampf(pos.y, MARGIN, SCREEN.y - sz.y - MARGIN)
	_col.position = pos
	_col.size = sz

## Прямоугольник узла на экране (с учётом масштаба и камеры).
static func screen_rect(c: CanvasItem) -> Rect2:
	if c == null or not is_instance_valid(c):
		return Rect2()
	var xf := c.get_global_transform_with_canvas()
	var sz := (c as Control).size if c is Control else Vector2.ZERO
	var a := xf * Vector2.ZERO
	var b := xf * sz
	return Rect2(a, b - a).abs()
