extends RefCounted
class_name CardActorFx
## Визуал актёров карточного боя: подписи над головой, idle-покачивание, прыжок, всплывающий текст.
## Только статические функции; состояние анимаций хранится в meta самого актёра.

const IDLE_SWAY_X := 5.0          ## покачивание влево-вправо, px
const IDLE_BOB_Y := 3.0           ## лёгкие подпрыгивания, px
const IDLE_PERIOD_MIN := 0.95     ## половина периода качания, сек (случайно в диапазоне)
const IDLE_PERIOD_MAX := 1.35
const HOP_HEIGHT := 24.0          ## прыжок героя при розыгрыше его карты

const COL_INTENT := Color(1.0, 0.55, 0.45, 1.0)

# --- Подписи над актёром (щит, намерение, статусы) ---------------------------

static func _make_label(label_name: String, pos: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = label_name
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 4)
	label.visible = false
	return label

static func shield_label(actor: BattleActor) -> Label:
	var label := actor.get_node_or_null("ShieldLabel") as Label
	if label == null:
		label = _make_label("ShieldLabel", Vector2(-45, -308), Vector2(90, 26), 18, CardCombat.COL_SHIELD)
		actor.add_child(label)
	return label

static func intent_label(actor: BattleActor) -> Label:
	var label := actor.get_node_or_null("IntentLabel") as Label
	if label == null:
		label = _make_label("IntentLabel", Vector2(-130, -350), Vector2(260, 34), 22, COL_INTENT)
		label.add_theme_constant_override("outline_size", 6)
		actor.add_child(label)
	return label

## Ряд значков статусов над юнитом (по центру). Пересобирается в refresh_status_icons.
const STATUS_ICON_SIZE := 36.0
const STATUS_ROW_W := 260.0
static var _status_icons: Dictionary = {}

static func status_row(actor: BattleActor) -> HBoxContainer:
	var row := actor.get_node_or_null("StatusRow") as HBoxContainer
	if row == null:
		row = HBoxContainer.new()
		row.name = "StatusRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 3)
		row.position = Vector2(-STATUS_ROW_W * 0.5, -404)
		row.size = Vector2(STATUS_ROW_W, STATUS_ICON_SIZE)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		actor.add_child(row)
	return row

## pairs — [CardStatus, данные]. Значок + «xN», если стаков больше одного; без значка — короткая надпись.
static func refresh_status_icons(actor: BattleActor, pairs: Array, visible: bool) -> void:
	var row := status_row(actor)
	for c in row.get_children():
		c.queue_free()
	row.visible = visible and not pairs.is_empty()
	if not row.visible:
		return
	for pair in pairs:
		var st: CardStatus = pair[0]
		var data: Dictionary = pair[1]
		var n := st.badge_count(data)
		var tex: Texture2D = null
		if st.icon_path != "":
			if not _status_icons.has(st.icon_path):
				_status_icons[st.icon_path] = load(st.icon_path) as Texture2D
			tex = _status_icons[st.icon_path]
		var cell := Control.new()
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if tex != null:
			cell.custom_minimum_size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
			var r := TextureRect.new()
			r.texture = tex
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.size = Vector2(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_child(r)
			if n > 1:
				var lab := _make_label("Count", Vector2(STATUS_ICON_SIZE - 26, STATUS_ICON_SIZE - 18), Vector2(32, 22), 16, Color.WHITE)
				lab.text = "x%d" % n
				lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lab.visible = true
				cell.add_child(lab)
		else:
			var chip := _make_label("Chip", Vector2.ZERO, Vector2.ZERO, 15, st.color)
			chip.text = st.title + (" x%d" % n if n > 1 else "")
			chip.visible = true
			chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cell.custom_minimum_size = Vector2(chip.get_combined_minimum_size().x + 4.0, STATUS_ICON_SIZE)
			chip.size = cell.custom_minimum_size
			cell.add_child(chip)
		row.add_child(cell)

## Имя врага под ногами (чтобы различать слизней).
static func name_label(actor: BattleActor) -> Label:
	var label := actor.get_node_or_null("NameLabel") as Label
	if label == null:
		label = _make_label("NameLabel", Vector2(-110, 14), Vector2(220, 26), 17, Color(1.0, 0.92, 0.95, 0.95))
		actor.add_child(label)
	return label

## Верх непрозрачной части картинки (кэш по текстуре), в пикселях текстуры.
static var _top_cache: Dictionary = {}

static func _opaque_top(tex: Texture2D) -> int:
	if tex == null:
		return 0
	if _top_cache.has(tex):
		return int(_top_cache[tex])
	var top := 0
	var img := tex.get_image()
	if img != null:
		top = img.get_used_rect().position.y
	_top_cache[tex] = top
	return top

## Низкий спрайт (слизень): полоска HP и подписи опускаются к его макушке, а не висят в воздухе.
static func fit_bars_to_sprite(actor: BattleActor) -> void:
	var spr := actor.sprite
	if spr == null or spr.texture == null or actor.hp_bar == null:
		return
	var h := float(spr.texture.get_height())
	var local_top := spr.offset.y - h * 0.5 + float(_opaque_top(spr.texture))
	var top_y := spr.position.y + local_top * spr.scale.y
	var delta := (top_y - 34.0) - actor.hp_bar.position.y
	if delta <= 0.0:
		return
	actor.hp_bar.position.y += delta
	actor.hp_label.position.y += delta

## Убираем с актёра то, что относится к старому бою (APS, энергия), и добавляем подписи.
## Раскладка — от полоски HP (у разных персонажей она на разной высоте), снизу вверх:
## щит, намерение (только у врагов), статусы.
static func setup_overlays(actor: BattleActor, is_enemy: bool) -> void:
	actor.aps_label.visible = false
	actor.en_bar.visible = false
	actor.en_label.visible = false
	var y := actor.hp_bar.position.y if actor.hp_bar != null else -280.0
	var shield := shield_label(actor)
	y -= shield.size.y + 2.0
	shield.position.y = y
	if is_enemy:
		var intent := intent_label(actor)
		y -= intent.size.y
		intent.position.y = y
	var row := status_row(actor)
	row.position.y = y - STATUS_ICON_SIZE - 4.0

# --- Всплывающий текст -------------------------------------------------------

static func spawn_float_text(parent: Node, pos: Vector2, text: String, color: Color, font_size: int = 26) -> void:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", pos.y - 70.0, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	t.chain().tween_callback(l.queue_free)

## Крупная надпись по центру (ульта).
static func show_banner(parent: Node, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(560, 300)
	l.size = Vector2(800, 80)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = l.size * 0.5
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	l.add_theme_constant_override("outline_size", 10)
	l.scale = Vector2(1.5, 1.5)
	l.modulate.a = 0.0
	parent.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "modulate:a", 1.0, 0.12)
	t.parallel().tween_property(l, "scale", Vector2.ONE, 0.18)
	t.tween_interval(0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)

# --- Idle и прыжок -----------------------------------------------------------

## Idle: спрайт лениво покачивается влево-вправо и чуть подпрыгивает. Фаза и скорость у каждого свои.
static func start_idle(actor: BattleActor) -> void:
	if actor == null or actor.unit == null or actor.unit.is_dead or actor.sprite == null or not actor.is_inside_tree():
		return
	stop_idle(actor)
	var token := randi() + 1
	actor.set_meta("idle_token", token)
	actor.set_meta("idle_base", actor.sprite.position)
	# Случайный старт, чтобы юниты не качались хором.
	# Слабая ссылка: актёр может исчезнуть раньше таймера (враг поделился или ушёл с боссом).
	var ref: WeakRef = weakref(actor)
	actor.get_tree().create_timer(randf_range(0.0, IDLE_PERIOD_MAX)).timeout.connect(func() -> void:
		var a := ref.get_ref() as BattleActor
		if a != null and int(a.get_meta("idle_token", 0)) == token and a.is_inside_tree():
			_run_idle_tweens(a)
	)

static func _run_idle_tweens(actor: BattleActor) -> void:
	var spr := actor.sprite
	var base: Vector2 = actor.get_meta("idle_base")
	var half := randf_range(IDLE_PERIOD_MIN, IDLE_PERIOD_MAX)
	var t := actor.create_tween().set_loops()
	t.tween_property(spr, "position:x", base.x + IDLE_SWAY_X, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(spr, "position:x", base.x - IDLE_SWAY_X, half * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(spr, "position:x", base.x, half).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var b := actor.create_tween().set_loops()
	b.tween_property(spr, "position:y", base.y - IDLE_BOB_Y, half * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	b.tween_property(spr, "position:y", base.y, half * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	actor.set_meta("idle_tweens", [t, b])

static func stop_idle(actor: BattleActor) -> void:
	if actor == null:
		return
	actor.set_meta("idle_token", 0)
	if not actor.has_meta("idle_tweens"):
		return
	for t in actor.get_meta("idle_tweens"):
		if t is Tween and t.is_valid():
			t.kill()
	actor.remove_meta("idle_tweens")
	if actor.has_meta("idle_base") and actor.sprite != null:
		actor.sprite.position = actor.get_meta("idle_base")

## Прыжок актёра (герой разыграл свою карту / ульту). Двигается весь актёр целиком.
static func hop(actor: BattleActor, height: float = HOP_HEIGHT) -> void:
	if actor == null or actor.unit == null or actor.unit.is_dead or not actor.is_inside_tree():
		return
	if actor.has_meta("hop_tween"):
		var old = actor.get_meta("hop_tween")
		if old is Tween and old.is_valid():
			old.kill()
	var base_y: float = actor._base_position.y
	actor.position.y = base_y
	var t := actor.create_tween()
	t.tween_property(actor, "position:y", base_y - height, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(actor, "position:y", base_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(actor, "position:y", base_y - height * 0.25, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(actor, "position:y", base_y, 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	actor.set_meta("hop_tween", t)
