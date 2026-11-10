extends Control
class_name CardXpBar
## Полоска опыта на экране конца забега: проявляется сверху, заполняется на полученный опыт
## (с переходами через уровни), потом гаснет. Подробности остаются в статистике.

const BAR_SIZE := Vector2(900, 30)
const PANEL_SIZE := Vector2(1000, 120)
const FILL_SPEED := 0.55      ## доля полоски в секунду
const HOLD_AFTER := 1.6       ## сколько держится после заполнения
const GOLD := Color(1.0, 0.84, 0.38)

var _level := 1
var _xp := 0.0
var _left := 0.0
var _cap := 10
var _need := 100.0
var _title: Label
var _gain: Label
var _count: Label
var _flash := 0.0
var _running := false

## level_before / xp_before — до начисления, gained — сколько получено, floor_no — этаж (потолок уровня).
func play(level_before: int, xp_before: int, gained: int, floor_no: int) -> void:
	_level = maxi(1, level_before)
	_xp = float(maxi(0, xp_before))
	_left = float(maxi(0, gained))
	_cap = CardBalance.level_cap(floor_no)
	_need = float(maxi(1, CardBalance.xp_to_next_level(_level)))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	_title = _label(30, GOLD, Vector2(50, 8), HORIZONTAL_ALIGNMENT_LEFT)
	_gain = _label(26, Color.WHITE, Vector2(50, 8), HORIZONTAL_ALIGNMENT_RIGHT)
	_gain.text = "+%d опыта" % gained
	_count = _label(20, Color(1, 1, 1, 0.9), Vector2(50, 86), HORIZONTAL_ALIGNMENT_CENTER)
	_refresh_text()
	modulate.a = 0.0
	var t := create_tween()
	t.tween_interval(0.5)
	t.tween_property(self, "modulate:a", 1.0, 0.45)
	t.tween_callback(func() -> void: _running = true)

func _label(font_px: int, color: Color, pos: Vector2, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(BAR_SIZE.x, 36)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 7)
	add_child(l)
	return l

func _refresh_text() -> void:
	if _level >= _cap:
		_title.text = "Уровень %d — потолок этажа" % _level
		_count.text = ""
	else:
		_title.text = "Уровень %d" % _level
		_count.text = "%d / %d" % [int(_xp), int(_need)]

func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 1.6)
	if _running:
		if _level >= _cap or _left <= 0.0:
			_running = false
			var t := create_tween()
			t.tween_interval(HOLD_AFTER)
			t.tween_property(self, "modulate:a", 0.0, 0.7)
			t.tween_callback(queue_free)
		else:
			var step := minf(_left, _need * FILL_SPEED * delta)
			step = minf(step, _need - _xp)
			_xp += step
			_left -= step
			if _xp >= _need - 0.001:
				_level += 1
				_xp = 0.0
				_need = float(maxi(1, CardBalance.xp_to_next_level(_level)))
				_flash = 1.0
			_refresh_text()
	queue_redraw()

func _draw() -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.03, 0.10, 0.72)
	panel.set_corner_radius_all(20)
	panel.set_border_width_all(2)
	panel.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.45 + 0.5 * _flash)
	draw_style_box(panel, Rect2(Vector2.ZERO, PANEL_SIZE))
	var r := Rect2(Vector2(50, 52), BAR_SIZE)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.16, 0.10, 0.22, 0.95)
	back.set_corner_radius_all(15)
	draw_style_box(back, r)
	var ratio := 1.0 if _level >= _cap else clampf(_xp / _need, 0.0, 1.0)
	if ratio > 0.01:
		var fill := StyleBoxFlat.new()
		fill.bg_color = GOLD.lerp(Color.WHITE, 0.6 * _flash)
		fill.set_corner_radius_all(15)
		draw_style_box(fill, Rect2(r.position, Vector2(maxf(30.0, r.size.x * ratio), r.size.y)))
	if _flash > 0.0:
		draw_style_box(_glow(_flash), r.grow(6.0 * _flash))

func _glow(k: float) -> StyleBoxFlat:
	var g := StyleBoxFlat.new()
	g.bg_color = Color(1, 1, 1, 0.0)
	g.set_corner_radius_all(18)
	g.set_border_width_all(4)
	g.border_color = Color(1.0, 0.95, 0.7, k)
	return g
