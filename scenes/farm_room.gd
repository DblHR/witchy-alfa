extends Control

@onready var background: TextureRect = %Background
@onready var farm_slots: Control = %FarmSlots
## Всё, что на ферме нарисовано (фон, ведьмочка, стол, горшки), лежит в World — он чуть больше
## экрана и плавно катается за курсором: чем дальше курсор от центра, тем сильнее сдвиг.
@onready var world: Control = %World
@onready var witch: TextureRect = %Witch
@onready var witch_zones: Node2D = %WitchZones

## Скорость, с которой фон догоняет курсор (больше — резче).
const PAN_SMOOTH := 5.0
## Картинки фермы: nighttime/ и daytime/ — по времени суток, сама папка — не зависящие от него (DayCycle).
const WITCH_DIR := "res://assets/farm/background/"
const WITCH_BASE := "witch"

var _pan_base := Vector2.ZERO   ## положение World при курсоре в центре (как в сцене)
var _pan_max := Vector2.ZERO    ## на сколько можно сдвинуть (сколько фона за краями экрана)
var _pan := Vector2.ZERO
var _witch_token := 0

var pots: Array[FarmPot] = []
var _seed_popup: Control
var _seed_grid: GridContainer
var _seed_popup_title: Label
var _selected_slot_for_planting: int = -1

func _ready() -> void:
	get_tree().paused = false
	UIThemeHelper.apply_pink_theme(self)
	_apply_catalog_assets()
	_apply_day_phase()
	HubMenu.attach(self)   ## меню комнат сверху справа (Лавка, Ферма, Алхимия, Дом)
	_collect_pots()
	_setup_pan()
	_build_seed_popup()
	_refresh_all()
	if FarmState_.state_changed.is_connected(_refresh_all) == false:
		FarmState_.state_changed.connect(_refresh_all)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh_all):
		Inventory_.changed.connect(_refresh_all)

func _exit_tree() -> void:
	if is_instance_valid(FarmState_) and FarmState_.state_changed.is_connected(_refresh_all):
		FarmState_.state_changed.disconnect(_refresh_all)
	if Inventory_ != null and Inventory_.changed.is_connected(_refresh_all):
		Inventory_.changed.disconnect(_refresh_all)

func _apply_catalog_assets() -> void:
	if AssetCatalog_ == null:
		return
	var bg := AssetCatalog_.get_ui_texture("farm_bg")
	if bg != null:
		background.texture = bg

# --- Фон за курсором ---------------------------------------------------------

func _setup_pan() -> void:
	_pan_base = world.position
	var vs := get_viewport_rect().size
	var left := -_pan_base
	var right := world.size + _pan_base - vs
	_pan_max = Vector2(maxf(0.0, minf(left.x, right.x)), maxf(0.0, minf(left.y, right.y)))
	_pan = _pan_base

func _process(delta: float) -> void:
	# Курсор ушёл с самой комнаты (на кнопку, окно) — курсор-рука выключается.
	if CursorFx_.is_touch_cursor() and get_viewport().gui_get_hovered_control() != self:
		CursorFx_.set_touch_cursor(false)
	if world == null:
		return
	var vs := get_viewport_rect().size
	var c := vs * 0.5
	var k := ((get_viewport().get_mouse_position() - c) / c).clamp(Vector2(-1, -1), Vector2(1, 1))
	var target := _pan_base - k * _pan_max
	_pan = _pan.lerp(target, 1.0 - exp(-PAN_SMOOTH * delta))
	world.position = _pan.round()

# --- Ведьмочка: клик по зонам (World/WitchZones) -----------------------------

func _witch_zone_at(global_p: Vector2) -> WitchZone:
	if witch_zones == null:
		return null
	for z in witch_zones.get_children():
		if z is WitchZone and (z as WitchZone).has_global_point(global_p):
			return z as WitchZone
	return null

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Над ведьмочкой — курсор-рука (CursorFx).
		CursorFx_.set_touch_cursor(_witch_zone_at((event as InputEventMouseMotion).global_position) != null)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var z := _witch_zone_at((event as InputEventMouseButton).global_position)
		if z != null:
			accept_event()
			witch_react(z.sprite, z.duration)

## Сменить спрайт ведьмочки на duration секунд (новая реакция прерывает прошлую).
func witch_react(sprite: String, duration: float) -> void:
	var tex := _witch_tex(sprite)
	if tex == null:
		return
	_witch_token += 1
	var token := _witch_token
	witch.texture = tex
	await get_tree().create_timer(maxf(0.1, duration)).timeout
	if token == _witch_token and is_instance_valid(witch):
		witch.texture = _witch_tex(WITCH_BASE)

func _witch_tex(sprite: String) -> Texture2D:
	return DayCycle.room_texture(WITCH_DIR, sprite)

## Картинки под время суток; лунный свет из окна — только ночью.
func _apply_day_phase() -> void:
	DayCycle.apply_textures(self)
	for n in ["World/Moonlight", "World/MoonlightBack"]:
		var m := get_node_or_null(n) as CanvasItem
		if m != null:
			m.visible = DayCycle.is_night()

func _collect_pots() -> void:
	# Индекс горшка берём из сцены (slot_index), а не из порядка нод: порядок задаёт только слои
	# (стол/табурет перекрывают часть горшков).
	pots.clear()
	var found: Array[FarmPot] = []
	for child in farm_slots.get_children():
		if child is FarmPot:
			found.append(child as FarmPot)
	found.sort_custom(func(a: FarmPot, b: FarmPot) -> bool: return a.slot_index < b.slot_index)
	for pot in found:
		if not pot.pressed.is_connected(_on_pot_pressed):
			pot.pressed.connect(_on_pot_pressed)
		pots.append(pot)

func _build_seed_popup() -> void:
	if _seed_popup != null:
		return
	# Затемнение на весь экран: блокирует клики по горшкам под окном, клик мимо закрывает его.
	_seed_popup = Control.new()
	_seed_popup.visible = false
	_seed_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_seed_popup.z_index = 40
	add_child(_seed_popup)
	_seed_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_seed_popup.gui_input.connect(_on_seed_popup_backdrop_input)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.08, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_popup.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_popup.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	_seed_popup_title = Label.new()
	_seed_popup_title.text = "Выберите семена"
	_seed_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_popup_title.add_theme_font_size_override("font_size", 28)
	box.add_child(_seed_popup_title)

	_seed_grid = GridContainer.new()
	_seed_grid.columns = 3
	_seed_grid.add_theme_constant_override("h_separation", 14)
	_seed_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(_seed_grid)

	var cancel := Button.new()
	cancel.text = "Отмена"
	cancel.custom_minimum_size = Vector2(0, 44)
	cancel.pressed.connect(_hide_seed_popup)
	box.add_child(cancel)

func _on_seed_popup_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_seed_popup()

func _unhandled_input(event: InputEvent) -> void:
	if _seed_popup != null and _seed_popup.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_hide_seed_popup()

func _refresh_all() -> void:
	for i in range(pots.size()):
		var pot := pots[i]
		if is_instance_valid(pot):
			# Купленных у Рикки горшков ещё нет — горшка не видно.
			pot.visible = FarmState_.is_pot_unlocked(i)
			pot.refresh()
	_rebuild_seed_popup_buttons()

func _rebuild_seed_popup_buttons() -> void:
	if _seed_grid == null:
		return
	for child in _seed_grid.get_children():
		_seed_grid.remove_child(child)
		child.queue_free()
	for seed_id in FarmState_.get_available_seed_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(190, 210)
		button.clip_contents = true
		button.tooltip_text = RunItems.get_item_desc(seed_id)
		button.pressed.connect(_on_seed_chosen.bind(seed_id))
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		button.add_child(box)
		box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		var icon := TextureRect.new()
		icon.texture = Inventory_.get_item_icon(seed_id)
		icon.custom_minimum_size = Vector2(110, 110)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)
		var name_label := Label.new()
		name_label.text = RunItems.get_item_name(seed_id)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(name_label)
		var count_label := Label.new()
		count_label.text = "×%d" % Inventory_.get_item_count(seed_id)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(count_label)
		_seed_grid.add_child(button)

func _on_pot_pressed(slot_index: int) -> void:
	if not FarmState_.is_pot_unlocked(slot_index):
		return
	var slot := FarmState_.get_slot(slot_index)
	match int(slot.get("stage", FarmState.PlantStage.EMPTY)):
		FarmState.PlantStage.EMPTY:
			var seeds := FarmState_.get_available_seed_ids()
			if seeds.is_empty():
				return
			if seeds.size() == 1:
				FarmState_.plant_seed(slot_index, seeds[0])
			else:
				_selected_slot_for_planting = slot_index
				_seed_popup_title.text = "Выберите семечко для горшка %d" % (slot_index + 1)
				_rebuild_seed_popup_buttons()
				_seed_popup.visible = true
		FarmState.PlantStage.SEED, FarmState.PlantStage.SPROUT:
			if FarmState_.water_slot(slot_index):
				if slot_index >= 0 and slot_index < pots.size():
					pots[slot_index].play_water_flash()
		FarmState.PlantStage.FLOWER:
			var got := FarmState_.roll_harvest(slot)
			if FarmState_.harvest_slot(slot_index):
				Inventory_.add_item(String(got["item"]), int(got["count"]))
				var msg := "+%d %s" % [int(got["count"]), RunItems.get_item_name(String(got["item"]))]
				if String(got["seed"]) != "":
					Inventory_.add_item(String(got["seed"]), 1)
					msg += "\n+1 %s" % RunItems.get_item_name(String(got["seed"]))
				if slot_index >= 0 and slot_index < pots.size():
					_float_text(pots[slot_index], msg)
	_refresh_all()

## Всплывающая надпись над горшком (что собрали).
func _float_text(pot: Control, msg: String) -> void:
	var l := Label.new()
	l.text = msg
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.22))
	l.add_theme_constant_override("outline_size", 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size = Vector2(360, 90)
	l.z_index = 40
	add_child(l)
	var r := pot.get_global_rect()
	l.global_position = Vector2(r.get_center().x - 180, r.position.y - 20)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 80, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.9)
	tw.chain().tween_callback(l.queue_free)

func _on_seed_chosen(seed_id: String) -> void:
	if _selected_slot_for_planting >= 0:
		FarmState_.plant_seed(_selected_slot_for_planting, seed_id)
	_selected_slot_for_planting = -1
	_hide_seed_popup()
	_refresh_all()

func _hide_seed_popup() -> void:
	_selected_slot_for_planting = -1
	if _seed_popup != null:
		_seed_popup.visible = false
