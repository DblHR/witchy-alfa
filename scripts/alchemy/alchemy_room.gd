extends Control
## Алхимия: цепочка мини-игр.
## 1) кнопка «Рецепт» слева сверху открывает окно выбора -> 2) справа полка: ячейки с ингредиентами
##    рецепта; ячейку тянем мышкой (появляется предмет с 2D-физикой) или кликаем — предмет сам летит в котёл
## 3) кидаем нужное в котёл СВЕРХУ -> 4) помешиваем круговым зажатием -> 5) маятник -> зелье.
## «Повторить» рядом с рецептом варит прошлый рецепт сразу, без мини-игр.
## Верстка задана долями экрана (дизайн 1920x1080), фон — alchemyBG.png, котёл — cauldron.png поверх.

const _BodyScript := preload("res://scripts/alchemy/ingredient_body.gd")
const _PendulumScript := preload("res://scripts/alchemy/pendulum_meter.gd")
const _StirScript := preload("res://scripts/alchemy/stirring_minigame.gd")

const BG_PATH := "res://assets/pics/bigPics/backgrounds/alchemyBG.png"
const CAULDRON_PATH := "res://assets/pics/alchemy/cauldron.png"
const HOME_ICON := "res://assets/pics/icons/buttons/homeButton.png"
const FARM_ICON := "res://assets/pics/icons/buttons/farmButton.png"
const SHOP_ICON := "res://assets/pics/icons/buttons/shopButton.png"

# --- Раскладка (доли экрана: x, y, w, h) ---
const R_RECIPE_BTN := Rect2(0.02, 0.025, 0.30, 0.10)
const R_REPEAT_BTN := Rect2(0.33, 0.025, 0.34, 0.10)
const R_HINT := Rect2(0.02, 0.145, 0.60, 0.05)
const R_CHECKLIST := Rect2(0.02, 0.21, 0.27, 0.20)
const R_RESET := Rect2(0.30, 0.215, 0.105, 0.045)
const R_SHELF := Rect2(0.705, 0.20, 0.28, 0.79)
const R_RECIPE_POPUP := Rect2(0.14, 0.12, 0.72, 0.76)
const SLOT_SIZE := Vector2(150, 168)
## Предмет, брошенный мимо котла, через столько секунд возвращается в ячейку.
const RETURN_AFTER := 2.2
## Клик по ячейке (без перетаскивания): предмет сам летит в котёл за это время.
const TOSS_TIME := 0.75
const POT_CENTER := Vector2(0.31, 0.745)
const STIR_SIZE := 740.0
## Горло котла (триггер): всё, что оказалось здесь, считается брошенным в котёл.
const R_POT_MOUTH := Rect2(0.09, 0.70, 0.465, 0.30)

const DEBUG_WALLS := false

enum Stage { PICK, ADD, STIR, PENDULUM, DONE }

var _stage: int = Stage.PICK
var _recipe_id := ""
var _accepted: Dictionary = {}      # ключ ингредиента (id или группа «staff_rN») -> сколько уже брошено
var _accepted_items: Dictionary = {} # конкретный item_id -> сколько штук в котле (их и спишем)
var _attempts := 0
var _stir_score := 0.0
var _rng := RandomNumberGenerator.new()
var _size := Vector2(1920, 1080)

var _world: Node2D
var _pot_area: Area2D
var _cauldron_art: TextureRect
var _hint_label: Label
var _checklist_box: VBoxContainer
var _checklist_panel: PanelContainer
var _legend_box: GridContainer
var _shelf_note: Label
var _recipe_button: Button
var _repeat_button: Button
var _recipe_popup: Control
var _recipe_grid: GridContainer
var _recipe_buttons: Dictionary = {}
## Рецепт, сваренный последним (на сеанс игры): его варит кнопка «Повторить».
static var _last_brewed := ""
var _press_time := 0.0
var _press_pos := Vector2.ZERO
var _reset_button: Button
var _stir: _StirScript
var _pendulum: _PendulumScript
var _result_panel: PanelContainer
var _result_label: Label
var _result_icon: TextureRect
var _toast: Label
var _toast_tween: Tween

var _dragged: _BodyScript = null
var _drag_offset := Vector2.ZERO
var _drag_vel := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _miss_lock_until := 0.0
var _mouse := Vector2.ZERO   ## позиция мыши в координатах вьюпорта (из событий)

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # иначе корневой Control съедает клики и _unhandled_input их не видит
	_size = get_viewport_rect().size
	UIThemeHelper.apply_pink_theme(self)
	_build_backdrop()
	_build_world()
	_build_shelf_panel()
	_build_stage_overlays()
	_build_top_ui()
	_build_checklist()
	_build_nav()
	_build_result_panel()
	_build_toast()
	if Inventory_ != null and not Inventory_.changed.is_connected(_on_inventory_changed):
		Inventory_.changed.connect(_on_inventory_changed)
	_spawn_shelf()
	_set_stage(Stage.PICK)

func _exit_tree() -> void:
	if Inventory_ != null and Inventory_.changed.is_connected(_on_inventory_changed):
		Inventory_.changed.disconnect(_on_inventory_changed)

# ---------------------------------------------------------------------------
# Построение сцены
# ---------------------------------------------------------------------------

func _frac(r: Rect2) -> Rect2:
	return Rect2(r.position * _size, r.size * _size)

func _place(c: Control, r: Rect2) -> void:
	var px := _frac(r)
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = px.position
	c.size = px.size

func _build_backdrop() -> void:
	var bg := TextureRect.new()
	bg.texture = load(BG_PATH)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Котёл — картинка того же размера, что и фон; кладём поверх целиком.
	_cauldron_art = TextureRect.new()
	_cauldron_art.texture = load(CAULDRON_PATH)
	_cauldron_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cauldron_art.stretch_mode = TextureRect.STRETCH_SCALE
	_cauldron_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cauldron_art)
	_cauldron_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _build_shelf_panel() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.13, 0.72)
	sb.border_color = Color(0.95, 0.80, 0.90, 0.40)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(22)
	sb.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	_place(panel, R_SHELF)
	move_child(panel, _world.get_index())  # полка под физическими телами
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := Label.new()
	title.text = "Ингредиенты"
	title.add_theme_font_size_override("font_size", 28)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title)
	_shelf_note = Label.new()
	_shelf_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shelf_note.custom_minimum_size = Vector2(300, 0)
	_shelf_note.add_theme_font_size_override("font_size", 20)
	_shelf_note.add_theme_color_override("font_color", Color(0.86, 0.80, 0.92))
	_shelf_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_shelf_note)
	_legend_box = GridContainer.new()
	_legend_box.columns = 3
	_legend_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend_box.add_theme_constant_override("h_separation", 14)
	_legend_box.add_theme_constant_override("v_separation", 14)
	box.add_child(_legend_box)

func _build_world() -> void:
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	# Пол и стены экрана.
	_add_wall(Vector2(-200, _size.y + 24), Vector2(_size.x + 200, _size.y + 24), 48.0)
	_add_wall(Vector2(-24, -600), Vector2(-24, _size.y + 100), 48.0)
	_add_wall(Vector2(_size.x + 24, -600), Vector2(_size.x + 24, _size.y + 100), 48.0)
	_add_wall(Vector2(-100, -600), Vector2(_size.x + 100, -600), 48.0)
	# Бока котла: ломаные по контуру картинки. Сверху котёл открыт.
	var left := [Vector2(0.092, 0.675), Vector2(0.040, 0.80), Vector2(0.020, 0.90), Vector2(0.020, 1.03)]
	var right := [Vector2(0.568, 0.70), Vector2(0.596, 0.76), Vector2(0.608, 0.88), Vector2(0.608, 1.03)]
	for chain in [left, right]:
		for i in range(chain.size() - 1):
			_add_wall(chain[i] * _size, chain[i + 1] * _size, 36.0)
	# Триггер: горло котла.
	_pot_area = Area2D.new()
	_pot_area.collision_layer = 0
	_pot_area.collision_mask = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	var mouth := _frac(R_POT_MOUTH)
	rs.size = mouth.size
	cs.shape = rs
	cs.position = mouth.position + mouth.size * 0.5
	_pot_area.add_child(cs)
	_world.add_child(_pot_area)
	_pot_area.body_entered.connect(_on_pot_body_entered)

func _add_wall(a: Vector2, b: Vector2, thick: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var mat := PhysicsMaterial.new()
	mat.friction = 0.8
	mat.bounce = 0.15
	body.physics_material_override = mat
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(a.distance_to(b), thick)
	shape.shape = rs
	body.position = (a + b) * 0.5
	body.rotation = (b - a).angle()
	body.add_child(shape)
	_world.add_child(body)
	if DEBUG_WALLS:
		var vis := ColorRect.new()
		vis.color = Color(1, 0, 0, 0.35)
		vis.size = rs.size
		vis.position = -rs.size * 0.5
		vis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(vis)

func _build_stage_overlays() -> void:
	_stir = _StirScript.new()
	_stir.visible = false
	add_child(_stir)
	_stir.size = Vector2(STIR_SIZE, STIR_SIZE)
	_stir.position = POT_CENTER * _size - Vector2(STIR_SIZE, STIR_SIZE) * 0.5
	_stir.finished.connect(_on_stir_finished)
	_pendulum = _PendulumScript.new()
	_pendulum.visible = false
	add_child(_pendulum)
	_pendulum.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var k := _size.y / 1080.0
	_pendulum.arc_center = Vector2(607.0, 1024.0) * k
	_pendulum.arc_radius = 690.0 * k
	_pendulum.arc_width = 52.0 * k
	_pendulum.stopped.connect(_on_pendulum_stopped)

func _panel_style(alpha: float = 0.72) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.13, alpha)
	sb.border_color = Color(0.95, 0.80, 0.90, 0.40)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(12)
	return sb

func _build_top_ui() -> void:
	# Кнопка рецепта: показывает выбранное, по нажатию — окно выбора.
	_recipe_button = Button.new()
	_recipe_button.focus_mode = Control.FOCUS_NONE
	_recipe_button.expand_icon = true
	_recipe_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_recipe_button.add_theme_constant_override("icon_max_width", 72)
	_recipe_button.add_theme_font_size_override("font_size", 28)
	_recipe_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_top_button(_recipe_button, Color(0.42, 0.22, 0.46))
	_recipe_button.pressed.connect(_open_recipe_popup)
	add_child(_recipe_button)
	_place(_recipe_button, R_RECIPE_BTN)
	# «Повторить»: прошлый рецепт сразу, без мини-игр.
	_repeat_button = Button.new()
	_repeat_button.focus_mode = Control.FOCUS_NONE
	_repeat_button.expand_icon = true
	_repeat_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_repeat_button.add_theme_constant_override("icon_max_width", 64)
	_repeat_button.add_theme_font_size_override("font_size", 24)
	_repeat_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_top_button(_repeat_button, Color(0.24, 0.36, 0.30))
	_repeat_button.pressed.connect(_on_repeat_pressed)
	add_child(_repeat_button)
	_place(_repeat_button, R_REPEAT_BTN)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 24)
	_hint_label.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.12, 1))
	_hint_label.add_theme_constant_override("outline_size", 8)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)
	_place(_hint_label, R_HINT)
	_build_recipe_popup()
	_refresh_top_buttons()

func _style_top_button(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = color
		if state == "hover":
			sb.bg_color = color.lightened(0.15)
		elif state == "pressed":
			sb.bg_color = color.darkened(0.15)
		elif state == "disabled":
			sb.bg_color = Color(color.r, color.g, color.b, 0.45)
		sb.bg_color.a = minf(sb.bg_color.a, 0.94)
		sb.border_color = Color(0.95, 0.80, 0.90, 0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(20)
		sb.set_content_margin_all(14)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.55))

func _refresh_top_buttons() -> void:
	if _recipe_button == null:
		return
	if _recipe_id == "":
		_recipe_button.text = "Выбрать рецепт  ▾"
		_recipe_button.icon = null
	else:
		_recipe_button.text = "Рецепт: %s  ▾" % AlchemyDB.get_recipe_name(_recipe_id)
		_recipe_button.icon = Inventory_.get_item_icon(AlchemyDB.get_result_item_id(_recipe_id)) if Inventory_ != null else null
	_recipe_button.disabled = _stage == Stage.STIR or _stage == Stage.PENDULUM or _stage == Stage.DONE
	if _last_brewed == "" or not AlchemyDB.is_known(_last_brewed):
		_repeat_button.text = "Повторно приготовить прошлый рецепт: пока нечего"
		_repeat_button.icon = null
		_repeat_button.disabled = true
		_repeat_button.tooltip_text = "Сварите что-нибудь — и это можно будет повторять одной кнопкой, без мини-игр."
	else:
		var can := AlchemyDB.can_craft(_last_brewed)
		_repeat_button.text = "Повторно приготовить: %s" % AlchemyDB.get_recipe_name(_last_brewed)
		if not can:
			_repeat_button.text += "\n(не хватает ингредиентов)"
		_repeat_button.icon = Inventory_.get_item_icon(AlchemyDB.get_result_item_id(_last_brewed)) if Inventory_ != null else null
		_repeat_button.disabled = not can or _stage == Stage.STIR or _stage == Stage.PENDULUM or _stage == Stage.DONE
		_repeat_button.tooltip_text = "Без мини-игр. Нужно: %s" % AlchemyDB.get_recipe_summary(_last_brewed)
	_repeat_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if _repeat_button.disabled else Control.CURSOR_POINTING_HAND

## Сварить прошлый рецепт сразу (ингредиенты списываются, мини-игр нет).
func _on_repeat_pressed() -> void:
	if _last_brewed == "" or not AlchemyDB.can_craft(_last_brewed):
		return
	var before := {}
	for id in RunItems.all_item_ids():
		before[id] = Inventory_.get_item_count(id)
	if not AlchemyDB.craft(_last_brewed):
		return
	var got := AlchemyDB.get_result_item_id(_last_brewed)
	for id in RunItems.all_item_ids():
		if Inventory_.get_item_count(id) > int(before.get(id, 0)):
			got = id
	_accepted.clear()
	_accepted_items.clear()
	_spawn_shelf()
	_pulse_cauldron()
	_say("Готово: %s (всего %d)" % [RunItems.get_item_name(got), Inventory_.get_item_count(got)], Color(0.7, 1.0, 0.75))
	_refresh_checklist()

# --- Окно выбора рецепта ----------------------------------------------------

func _build_recipe_popup() -> void:
	_recipe_popup = Control.new()
	_recipe_popup.visible = false
	_recipe_popup.z_index = 40
	_recipe_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_recipe_popup)
	_recipe_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_recipe_popup.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_recipe_popup.visible = false
	)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_recipe_popup.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(0.96))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_recipe_popup.add_child(panel)
	_place(panel, R_RECIPE_POPUP)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var title := Label.new()
	title.text = "Выберите рецепт"
	title.add_theme_font_size_override("font_size", 34)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "Закрыть"
	close.focus_mode = Control.FOCUS_NONE
	close.custom_minimum_size = Vector2(160, 50)
	close.pressed.connect(func() -> void: _recipe_popup.visible = false)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_recipe_grid = GridContainer.new()
	_recipe_grid.columns = 3
	_recipe_grid.add_theme_constant_override("h_separation", 14)
	_recipe_grid.add_theme_constant_override("v_separation", 14)
	_recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_grid)

func _open_recipe_popup() -> void:
	if _stage == Stage.STIR or _stage == Stage.PENDULUM or _stage == Stage.DONE:
		return
	_rebuild_recipe_cards()
	_recipe_popup.visible = true

## Карточки рецептов: сначала открытые, потом закрытые. На карточке — что нужно и сколько есть.
func _rebuild_recipe_cards() -> void:
	for c in _recipe_grid.get_children():
		_recipe_grid.remove_child(c)
		c.queue_free()
	_recipe_buttons.clear()
	var ids := AlchemyDB.get_recipe_ids()
	ids.sort_custom(func(a: String, b: String) -> bool:
		if AlchemyDB.is_known(a) != AlchemyDB.is_known(b):
			return AlchemyDB.is_known(a)
		return AlchemyDB.get_recipe_name(a) < AlchemyDB.get_recipe_name(b)
	)
	for recipe_id in ids:
		var known := AlchemyDB.is_known(recipe_id)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(430, 150)
		b.clip_contents = true
		b.disabled = not known
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if known else Control.CURSOR_ARROW
		b.tooltip_text = AlchemyDB.get_recipe_desc(recipe_id) if known else "Рецепт можно найти в сундуке или купить у Рикки."
		_style_top_button(b, Color(0.50, 0.26, 0.52) if recipe_id == _recipe_id else Color(0.30, 0.18, 0.36))
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 14)
		b.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 14)
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = Inventory_.get_item_icon(AlchemyDB.get_result_item_id(recipe_id)) if Inventory_ != null else null
		icon.custom_minimum_size = Vector2(96, 96)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate.a = 1.0 if known else 0.35
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(col)
		var name_l := Label.new()
		name_l.text = AlchemyDB.get_recipe_name(recipe_id) if known else "??? Не открыт"
		name_l.add_theme_font_size_override("font_size", 26)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(name_l)
		if known:
			var ing := AlchemyDB.get_ingredients(recipe_id)
			var keys: Array = ing.keys()
			keys.sort()
			for k in keys:
				var need := int(ing[k])
				var have := AlchemyDB.count_have(String(k))
				var l := Label.new()
				l.text = "%s  %d / %d" % [AlchemyDB.ingredient_name(String(k)), mini(have, 99), need]
				l.add_theme_font_size_override("font_size", 19)
				l.add_theme_color_override("font_color", Color(0.6, 0.95, 0.65) if have >= need else Color(1.0, 0.6, 0.6))
				l.mouse_filter = Control.MOUSE_FILTER_IGNORE
				col.add_child(l)
		b.pressed.connect(func() -> void:
			_recipe_popup.visible = false
			_on_recipe_pressed(recipe_id)
		)
		_recipe_grid.add_child(b)
		_recipe_buttons[recipe_id] = b

func _build_checklist() -> void:
	_checklist_panel = PanelContainer.new()
	_checklist_panel.add_theme_stylebox_override("panel", _panel_style(0.68))
	add_child(_checklist_panel)
	_place(_checklist_panel, R_CHECKLIST)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	_checklist_panel.add_child(outer)
	var t := Label.new()
	t.text = "В котёл нужно:"
	t.add_theme_font_size_override("font_size", 22)
	outer.add_child(t)
	_checklist_box = VBoxContainer.new()
	_checklist_box.add_theme_constant_override("separation", 6)
	outer.add_child(_checklist_box)
	_reset_button = Button.new()
	_reset_button.text = "Начать заново"
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.pressed.connect(_on_reset_pressed)
	add_child(_reset_button)
	_place(_reset_button, R_RESET)

func _build_nav() -> void:
	var defs := [
		[HOME_ICON, Rect2(1755, 8, 149, 149), func() -> void: SceneRouter_.go_to_hub()],
		[FARM_ICON, Rect2(1577, 10, 150, 150), func() -> void: SceneRouter_.go_to_farm()],
		[SHOP_ICON, Rect2(1411, 10, 150, 150), func() -> void: SceneRouter_.go_to_shop()],
	]
	for d in defs:
		var b := TextureButton.new()
		b.texture_normal = load(d[0])
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.focus_mode = Control.FOCUS_NONE
		add_child(b)
		b.position = (d[1] as Rect2).position
		b.size = (d[1] as Rect2).size
		b.pressed.connect(d[2])
		if d[0] == SHOP_ICON:
			NotifyBadge.attach(b, StoryDialogueDB_ != null and StoryDialogueDB_.npc_has_quest_offer("rabbit_shop"))

func _build_result_panel() -> void:
	_result_panel = PanelContainer.new()
	_result_panel.visible = false
	_result_panel.add_theme_stylebox_override("panel", _panel_style(0.92))
	_result_panel.z_index = 20
	add_child(_result_panel)
	_place(_result_panel, Rect2(0.30, 0.34, 0.40, 0.30))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_result_panel.add_child(box)
	_result_icon = TextureRect.new()
	_result_icon.custom_minimum_size = Vector2(120, 120)
	_result_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_result_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_result_icon)
	_result_label = Label.new()
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 28)
	box.add_child(_result_label)
	var ok := Button.new()
	ok.text = "Отлично"
	ok.custom_minimum_size = Vector2(0, 54)
	ok.focus_mode = Control.FOCUS_NONE
	ok.pressed.connect(_on_result_closed)
	box.add_child(ok)

func _build_toast() -> void:
	_toast = Label.new()
	_toast.visible = false
	_toast.z_index = 30
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_size_override("font_size", 30)
	_toast.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.12, 1))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	_place(_toast, Rect2(0.05, 0.62, 0.50, 0.06))

func _say(text: String, color: Color = Color.WHITE) -> void:
	_toast.text = text
	_toast.modulate = Color(color.r, color.g, color.b, 1.0)
	_toast.visible = true
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)

# ---------------------------------------------------------------------------
# Стадии
# ---------------------------------------------------------------------------

func _set_stage(stage: int) -> void:
	_stage = stage
	_stir.visible = stage == Stage.STIR
	if stage != Stage.STIR:
		_stir.cancel()
	if stage != Stage.PENDULUM:
		_pendulum.hide_meter()
	_checklist_panel.visible = stage == Stage.ADD
	_reset_button.visible = stage != Stage.PICK and stage != Stage.DONE
	_refresh_top_buttons()
	match stage:
		Stage.PICK:
			_hint_label.text = "Нажмите «Выбрать рецепт» слева сверху."
		Stage.ADD:
			_hint_label.text = "Тяните ингредиенты из ячеек справа в котёл — или просто кликайте по ячейке."
		Stage.STIR:
			_hint_label.text = "Зажмите левую кнопку мыши и мешайте по кругу."
		Stage.PENDULUM:
			_hint_label.text = "Нажмите (клик / пробел), когда маятник на зелёном."
		Stage.DONE:
			_hint_label.text = ""
	_refresh_checklist()

func _on_recipe_pressed(recipe_id: String) -> void:
	if _stage == Stage.STIR or _stage == Stage.PENDULUM or _stage == Stage.DONE:
		return   # во время варки рецепт менять нельзя
	_recipe_id = recipe_id
	_accepted.clear()
	_accepted_items.clear()
	_attempts = 0
	_spawn_shelf()
	_set_stage(Stage.ADD)

func _on_reset_pressed() -> void:
	if _stage == Stage.DONE:
		return
	_accepted.clear()
	_accepted_items.clear()
	_attempts = 0
	_spawn_shelf()
	_set_stage(Stage.ADD if _recipe_id != "" else Stage.PICK)
	_say("Котёл пуст, ингредиенты вернулись на полку", Color(0.9, 0.85, 1.0))

## Ключ ингредиента: для улучшения посохов все посохи нужной редкости — одна группа.
func _key(item_id: String) -> String:
	return AlchemyDB.ingredient_key(_recipe_id, item_id)

func _need(item_id: String) -> int:
	if _recipe_id == "":
		return 0
	return int(AlchemyDB.get_ingredients(_recipe_id).get(_key(item_id), 0))

## Сколько штук этого предмета уже в котле (считается по предметам, не по группам).
func _in_pot(item_id: String) -> int:
	return int(_accepted_items.get(item_id, 0))

func _all_added() -> bool:
	if _recipe_id == "":
		return false
	var ing := AlchemyDB.get_ingredients(_recipe_id)
	for id in ing.keys():
		if int(_accepted.get(String(id), 0)) < int(ing[id]):
			return false
	return true

func _refresh_checklist() -> void:
	for c in _checklist_box.get_children():
		_checklist_box.remove_child(c)
		c.queue_free()
	if _recipe_id != "":
		var ing := AlchemyDB.get_ingredients(_recipe_id)
		var ids: Array = ing.keys()
		ids.sort()
		for id in ids:
			var item_id := String(id)
			var need := int(ing[id])
			var got := int(_accepted.get(item_id, 0))
			var have := AlchemyDB.count_have(item_id)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var icon := TextureRect.new()
			icon.texture = AlchemyDB.ingredient_icon(item_id)
			icon.custom_minimum_size = Vector2(36, 36)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var lbl := Label.new()
			var done := got >= need
			var short := have < need
			lbl.text = "%s %s  %d / %d" % ["✓" if done else "•", AlchemyDB.ingredient_name(item_id), got, need]
			if short and not done:
				lbl.text += "   (в сумке только %d)" % have
			lbl.add_theme_font_size_override("font_size", 22)
			lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6) if done else (Color(1.0, 0.5, 0.5) if short else Color.WHITE))
			row.add_child(lbl)
			_checklist_box.add_child(row)
	_refresh_legend()

## Ячейки полки: ингредиенты выбранного рецепта (для улучшения посохов — каждый подходящий посох).
## В ячейке — сколько ещё лежит (без тех, что уже в котле или летят).
func _refresh_legend() -> void:
	for c in _legend_box.get_children():
		_legend_box.remove_child(c)
		c.queue_free()
	if Inventory_ == null:
		return
	if _recipe_id == "":
		_shelf_note.text = "Сначала выберите рецепт — здесь появится то, что для него нужно."
		_shelf_note.visible = true
		return
	var any := false
	for id in AlchemyDB.get_shelf_ids(_recipe_id):
		if _need(id) <= 0:
			continue
		var have := Inventory_.get_item_count(id)
		if have <= 0 and AlchemyDB.is_group(_key(id)):
			continue   # посохи, которых нет, не показываем
		any = true
		_legend_box.add_child(_make_slot(id, maxi(0, have - _in_pot(id) - _live_count(id))))
	_shelf_note.text = "Тяните в котёл или кликайте. Промахнулись — предмет вернётся в ячейку." if any else "Для этого рецепта у вас пока ничего нет."
	_shelf_note.visible = true

func _make_slot(item_id: String, left: int) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.tooltip_text = "%s\n%s" % [RunItems.get_item_name(item_id), RunItems.get_item_desc(item_id)]
	var need_more := int(_accepted.get(_key(item_id), 0)) < _need(item_id)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.11, 0.26, 0.92)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.85, 0.55, 0.75) if (need_more and left > 0) else Color(1, 1, 1, 0.2)
	slot.add_theme_stylebox_override("panel", sb)
	if left > 0:
		slot.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = Inventory_.get_item_icon(item_id)
	icon.position = Vector2((SLOT_SIZE.x - 92.0) * 0.5, 8)
	icon.size = Vector2(92, 92)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate.a = 1.0 if left > 0 else 0.3
	slot.add_child(icon)
	var name_l := Label.new()
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.text = RunItems.get_item_name(item_id)
	name_l.position = Vector2(4, 100)
	name_l.size = Vector2(SLOT_SIZE.x - 8, 44)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.add_theme_font_size_override("font_size", 16)
	name_l.add_theme_constant_override("line_spacing", -3)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(name_l)
	var count_l := Label.new()
	count_l.text = "×%d" % left
	count_l.position = Vector2(0, 142)
	count_l.size = Vector2(SLOT_SIZE.x, 24)
	count_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_l.add_theme_font_size_override("font_size", 20)
	count_l.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5) if left > 0 else Color(1, 1, 1, 0.4))
	count_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(count_l)
	slot.gui_input.connect(func(ev: InputEvent) -> void: _on_slot_input(ev, item_id))
	return slot

## Ячейка: зажали — в руке появляется предмет; отпустили сразу — он сам летит в котёл.
func _on_slot_input(ev: InputEvent, item_id: String) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		if _stage != Stage.ADD or _dragged != null:
			return
		if Inventory_.get_item_count(item_id) - _in_pot(item_id) - _live_count(item_id) <= 0:
			return
		var body := _BodyScript.new()
		body.setup(item_id, Inventory_.get_item_icon(item_id))
		body.position = _mouse
		_world.add_child(body)
		_grab(body, Vector2.ZERO)
		_press_time = Time.get_ticks_msec() / 1000.0
		_press_pos = _mouse
		_refresh_legend.call_deferred()
	elif _dragged != null:
		var quick := Time.get_ticks_msec() / 1000.0 - _press_time < 0.3 and _mouse.distance_to(_press_pos) < 24.0
		if quick:
			_toss(_dragged)
		else:
			_release()

## Бросок в котёл по дуге (клик по ячейке): в полёте предмет ни за что не цепляется.
func _toss(ib: _BodyScript) -> void:
	_dragged = null
	if not is_instance_valid(ib):
		return
	var target := Vector2(POT_CENTER.x * _size.x + _rng.randf_range(-60.0, 60.0), R_POT_MOUTH.position.y * _size.y + 30.0)
	var g := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)) * ib.gravity_scale
	var d := target - ib.global_position
	ib.freeze = false
	ib.collision_mask = 0
	ib.linear_damp = 0.0
	ib.z_index = 5
	ib.linear_velocity = Vector2(d.x / TOSS_TIME, (d.y - 0.5 * g * TOSS_TIME * TOSS_TIME) / TOSS_TIME)
	ib.angular_velocity = _rng.randf_range(-5.0, 5.0)
	_schedule_return(ib)

## Предмет не попал в котёл — через RETURN_AFTER секунд возвращается в ячейку.
func _schedule_return(ib: _BodyScript) -> void:
	await get_tree().create_timer(RETURN_AFTER).timeout
	if not is_instance_valid(ib) or ib.accepted or ib == _dragged or ib.is_queued_for_deletion():
		return
	ib.remove_from_group("ingredient")
	ib.collision_layer = 0
	ib.collision_mask = 0
	ib.freeze = true
	var t := create_tween()
	t.tween_property(ib, "modulate:a", 0.0, 0.25)
	t.tween_callback(ib.queue_free)
	_refresh_legend()

# ---------------------------------------------------------------------------
# Полка и физика
# ---------------------------------------------------------------------------

func _live_count(item_id: String) -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group("ingredient"):
		var ib := b as _BodyScript
		if ib != null and ib.item_id == item_id and not ib.accepted and not ib.is_queued_for_deletion():
			n += 1
	return n

func _clear_shelf() -> void:
	_dragged = null
	for b in get_tree().get_nodes_in_group("ingredient"):
		b.remove_from_group("ingredient")
		b.queue_free()

func _spawn_shelf() -> void:
	_clear_shelf()
	_top_up()

## Полка — ячейки, а не куча: предметы появляются только в руке (см. _on_slot_input).
func _top_up() -> void:
	_refresh_legend()

func _on_inventory_changed() -> void:
	_refresh_checklist()
	_refresh_top_buttons()

func _on_pot_body_entered(body: Node) -> void:
	var ib := body as _BodyScript
	if ib == null or ib == _dragged:
		return   # пока предмет в руке — не засчитываем, только когда отпустили
	_try_accept(ib)

func _try_accept(ib: _BodyScript) -> void:
	if ib.accepted or ib.is_queued_for_deletion():
		return
	if _stage != Stage.ADD:
		_bounce_out(ib)
		if _stage == Stage.PICK:
			_say("Сначала выберите рецепт", Color(1.0, 0.8, 0.5))
		return
	var need := _need(ib.item_id)
	var key := _key(ib.item_id)
	var got := int(_accepted.get(key, 0))
	if need <= 0:
		_bounce_out(ib)
		_say("Это в рецепт не входит", Color(1.0, 0.6, 0.6))
		return
	if got >= need:
		_bounce_out(ib)
		_say("%s уже хватает" % AlchemyDB.ingredient_name(key), Color(1.0, 0.8, 0.5))
		return
	_accepted[key] = got + 1
	_accepted_items[ib.item_id] = _in_pot(ib.item_id) + 1
	ib.accepted = true
	ib.remove_from_group("ingredient")
	# Тело сразу убираем, а «тонущую» иконку показываем отдельным спрайтом
	# (масштабировать RigidBody2D нельзя — физика сбрасывает scale).
	var ghost := Sprite2D.new()
	var src := ib.get_node_or_null("Sprite") as Sprite2D
	if src != null:
		ghost.texture = src.texture
		ghost.scale = src.scale
	ghost.global_position = ib.global_position
	ghost.z_index = 4
	_world.add_child(ghost)
	var t := create_tween().set_parallel(true)
	t.tween_property(ghost, "scale", ghost.scale * 0.3, 0.4)
	t.tween_property(ghost, "position:y", ghost.position.y + 50.0, 0.4)
	t.tween_property(ghost, "modulate:a", 0.0, 0.4)
	t.chain().tween_callback(ghost.queue_free)
	ib.freeze = true
	ib.collision_layer = 0
	ib.collision_mask = 0
	ib.visible = false
	ib.queue_free()
	_pulse_cauldron()
	_refresh_checklist()
	call_deferred("_top_up")
	if _all_added():
		_say("Всё на месте! Мешаем…", Color(0.7, 1.0, 0.75))
		get_tree().create_timer(0.7).timeout.connect(_begin_stir)

func _bounce_out(ib: _BodyScript) -> void:
	ib.freeze = false
	ib.linear_velocity = Vector2(_rng.randf_range(-260.0, 260.0), -1250.0)

func _pulse_cauldron() -> void:
	var t := create_tween()
	t.tween_property(_cauldron_art, "modulate", Color(1.35, 1.2, 1.5, 1.0), 0.08)
	t.tween_property(_cauldron_art, "modulate", Color.WHITE, 0.25)

# --- Перетаскивание ---------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_mouse = (event as InputEventMouse).position

func _unhandled_input(event: InputEvent) -> void:
	if _stage == Stage.PENDULUM:
		var press := false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press = true
		elif event.is_action_pressed("ui_accept"):
			press = true
		if press:
			get_viewport().set_input_as_handled()
			_pendulum_press()
		return
	if _stage != Stage.ADD:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_grab()
		else:
			_release()

func _try_grab() -> void:
	if _dragged != null:
		return
	var mouse := _mouse
	var params := PhysicsPointQueryParameters2D.new()
	params.position = mouse
	params.collide_with_bodies = true
	params.collision_mask = 1
	var hits := _world.get_world_2d().direct_space_state.intersect_point(params, 8)
	var best: _BodyScript = null
	var best_d := 1e9
	for h in hits:
		var ib := h.get("collider") as _BodyScript
		if ib == null or ib.accepted:
			continue
		var d := ib.global_position.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = ib
	if best == null:
		return
	_grab(best, best.global_position - mouse)
	_press_time = 0.0
	get_viewport().set_input_as_handled()

func _grab(body: _BodyScript, offset: Vector2) -> void:
	_dragged = body
	_drag_offset = offset
	_drag_last = body.global_position
	_drag_vel = Vector2.ZERO
	body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	body.freeze = true
	body.collision_mask = 0     # в руке не цепляется за стенки котла
	body.z_index = 5

func _physics_process(delta: float) -> void:
	if _dragged == null or not is_instance_valid(_dragged):
		return
	var target := _mouse + _drag_offset
	target.x = clampf(target.x, 30.0, _size.x - 30.0)
	target.y = clampf(target.y, 30.0, _size.y - 30.0)
	_dragged.global_position = target
	var v := (target - _drag_last) / maxf(delta, 0.001)
	_drag_vel = _drag_vel.lerp(v, 0.35)
	_drag_last = target

func _release() -> void:
	if _dragged == null:
		return
	var ib := _dragged
	_dragged = null
	if not is_instance_valid(ib):
		return
	ib.freeze = false
	ib.collision_mask = 1
	ib.z_index = 0
	ib.linear_velocity = _drag_vel.limit_length(1800.0)
	ib.angular_velocity = _rng.randf_range(-3.0, 3.0)
	_schedule_return(ib)
	# Если отпустили прямо над горлом котла — засчитываем сразу (body_entered в руке игнорируется).
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_instance_valid(ib) and not ib.accepted and _pot_area.overlaps_body(ib):
		_try_accept(ib)

# --- Помешивание ------------------------------------------------------------

func _begin_stir() -> void:
	if _stage != Stage.ADD or not _all_added():
		return
	_clear_shelf_loose_dragged()
	_set_stage(Stage.STIR)
	_stir.begin(1.6, true, 0.18)

func _clear_shelf_loose_dragged() -> void:
	if _dragged != null and is_instance_valid(_dragged):
		_dragged.freeze = false
		_dragged.collision_mask = 1
	_dragged = null

func _on_stir_finished(success: bool, score: float) -> void:
	if _stage != Stage.STIR:
		return
	if not success:
		_say("Смесь расплескалась — мешайте ровнее", Color(1.0, 0.7, 0.6))
		_stir.begin(1.6, true, 0.18)
		return
	_stir_score = score
	_attempts = 0
	_pulse_cauldron()
	_set_stage(Stage.PENDULUM)
	_pendulum.begin(_rng, 1.0)

# --- Маятник ----------------------------------------------------------------

func _pendulum_press() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _miss_lock_until or not _pendulum.is_active():
		return
	_pendulum.submit()

func _on_pendulum_stopped(hit: bool, _accuracy: float) -> void:
	_attempts += 1
	if not hit:
		_miss_lock_until = Time.get_ticks_msec() / 1000.0 + 0.3
		_say("Мимо!", Color(1.0, 0.55, 0.55))
		return
	await get_tree().create_timer(0.45).timeout
	_complete()

func _quality_label() -> String:
	if _attempts <= 1 and _stir_score >= 0.7:
		return "идеальное"
	if _attempts <= 2:
		return "хорошее"
	return "обычное"

func _complete() -> void:
	if Inventory_ == null or _recipe_id == "":
		return
	# Списываем ровно то, что положили в котёл (для улучшения — конкретные посохи).
	for id in _accepted_items.keys():
		Inventory_.remove_item(String(id), int(_accepted_items[id]))
	var result_id := AlchemyDB.roll_result(_recipe_id, _rng)
	Inventory_.add_item(result_id, 1)
	_last_brewed = _recipe_id
	_set_stage(Stage.DONE)
	_result_icon.texture = Inventory_.get_item_icon(result_id)
	_result_label.text = "Готово: %s\nКачество варки: %s" % [RunItems.get_item_name(result_id), _quality_label()]
	_result_panel.visible = true

func _on_result_closed() -> void:
	_result_panel.visible = false
	_accepted.clear()
	_accepted_items.clear()
	_attempts = 0
	_spawn_shelf()
	_set_stage(Stage.ADD if _recipe_id != "" else Stage.PICK)
