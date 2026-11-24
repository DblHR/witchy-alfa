extends Control
## Дом (хаб): фон из трёх слоёв (стены — котёл — передний план, все в Hub.tscn), персонажи ростера
## гуляют по маршрутам (Hub.tscn → Routes, линии HomeRoute; в игре их не видно), меню комнат сверху
## справа (HubMenu), котёл — вход в алхимию.
## Живые мелочи (все узлами в Hub.tscn — двигайте там): звёздочки на ниточках (Stars, HubStars),
## тыква-котик и камин — клик вкл/выкл (Pumpkin, Fireplace, HubToggle), магический круг у котла
## (MagicEffect) — проявляется, если держать курсор на котле.

@onready var start_run: TextureButton = %StartRunButton
@onready var inv: TextureButton = %InventoryButton
@onready var walkers_back: Node2D = $WalkersBack
@onready var walkers_front: Node2D = $WalkersFront
@onready var drag_layer: Node2D = $DragLayer
@onready var routes_root: Node2D = $Routes
@onready var cauldron_layer: TextureRect = $CauldronLayer
@onready var foreground: TextureRect = $Foreground
@onready var menu: HubMenu = $HubMenu
@onready var stars: HubStars = $Stars
@onready var pumpkin: HubToggle = $Pumpkin
@onready var fireplace: HubToggle = $Fireplace
@onready var magic_effect: TextureRect = $MagicEffect
## Небо за домом (HubSky): звёзды, луна-котик, облака, ёлки. Видно через прозрачные места BackGround.
@onready var sky: HubSky = $Sky
@onready var background: TextureRect = $BackGround

## Магический круг: через сколько секунд на котле начинает проявляться, за сколько проявляется
## полностью и за сколько гаснет, когда курсор ушёл.
const MAGIC_DELAY := 2.0
const MAGIC_FADE_IN := 5.0
const MAGIC_FADE_OUT := 1.2
var _magic_hold := 0.0

func _ready() -> void:
	get_tree().paused = false
	# Картинки под время суток (DayCycle: night_hub -> day_hub, если есть дневные).
	DayCycle.apply_textures(self)
	start_run.pressed.connect(_on_start_run)
	inv.pressed.connect(func(): SceneRouter_.go_to_inventory())
	_collect_routes()
	_spawn_walkers()
	# Котла ещё нет (покупается у Рикки) — слоя с котлом (котёл и коврик) не видно, клика нет.
	cauldron_layer.visible = AlchemyDB.has_cauldron()
	magic_effect.visible = cauldron_layer.visible
	magic_effect.modulate.a = 0.0
	_build_cauldron_bubbles()
	_build_door_hint()
	_setup_home_props()
	_refresh_badges()
	if UnitRoster_ != null and not UnitRoster_.changed.is_connected(_refresh_badges):
		UnitRoster_.changed.connect(_refresh_badges)
	if StoryState_ != null and StoryState_.has_signal("changed") and not StoryState_.changed.is_connected(_refresh_badges):
		StoryState_.changed.connect(_refresh_badges)
	call_deferred("_play_pending_story_dialogue")

## «!» на инвентаре (новые очки улучшения карт) и над героиней с новой сценой. «!» лавки — в HubMenu.
func _refresh_badges() -> void:
	if not is_inside_tree():
		return
	NotifyBadge.attach(inv, UnitRoster_ != null and UnitRoster_.upgrade_news(UnitRoster_.UPGRADE_SEEN_INVENTORY))
	for id in walkers:
		var w: HomeWalker = walkers[id]
		if not is_instance_valid(w):
			continue
		var has_news := StoryDialogueDB_ != null and StoryDialogueDB_.npc_has_news(String(id), [HUB_TALK_TYPE])
		NotifyBadge.attach(w.badge_anchor, has_news, Vector2(-20, 0))
	if menu != null:
		menu.refresh_badges()

# --- Маршруты -------------------------------------------------------------------------
var routes: Array[HomeRoute] = []

func _collect_routes() -> void:
	routes.clear()
	for c in routes_root.get_children():
		var r := c as HomeRoute
		if r != null and r.points.size() >= 2:
			r.rebuild()
			routes.append(r)

## Линии, которые стыкуются с концом линии route (at_end) или с её началом: [[линия, входим_с_начала], ...].
func connections_at(route: HomeRoute, at_end: bool) -> Array:
	var p := route.end_point() if at_end else route.start_point()
	var out: Array = []
	for r in routes:
		if r == route:
			continue
		if r.start_point().distance_to(p) <= HomeRoute.JOIN_DIST:
			out.append([r, true])
		elif r.end_point().distance_to(p) <= HomeRoute.JOIN_DIST:
			out.append([r, false])
	return out

## Ближайшее к точке место маршрута: [линия, расстояние вдоль неё].
func nearest_spot(p: Vector2) -> Array:
	var best: HomeRoute = null
	var best_d := 0.0
	var best_dist := INF
	for r in routes:
		var n := r.nearest(p)
		if float(n["dist"]) < best_dist:
			best_dist = float(n["dist"])
			best = r
			best_d = float(n["d"])
	return [best, best_d]

# --- Персонажи ------------------------------------------------------------------------
## Кто живёт дома (если есть в ростере; ведьмочка — всегда). Картинка — <id>_battle.png.
const HOME_UNITS := ["witch", "warrior", "aki", "luisa", "fufu"]
const SPRITE_PATH := "res://assets/characters/%s/%s_battle.png"
## Где персонажи появляются (линии без кровати, случайно).
var walkers: Dictionary = {}   ## id -> HomeWalker

var _walker_hider: VnSpriteHider

func _spawn_walkers() -> void:
	for id in HOME_UNITS:
		_spawn_walker(id)
	# Пока открыт диалог (VN), гуляющие по дому прячутся — на экране только портреты из диалога.
	_walker_hider = VnSpriteHider.attach(self, walkers.values().map(func(w: HomeWalker) -> CanvasItem: return w))
	# Персонаж вступил в отряд прямо сейчас (воин после квеста, пойманная в забеге) — появляется сразу.
	if UnitRoster_ != null and not UnitRoster_.changed.is_connected(_spawn_new_walkers):
		UnitRoster_.changed.connect(_spawn_new_walkers)

func _spawn_new_walkers() -> void:
	for id in HOME_UNITS:
		if not walkers.has(id):
			var w := _spawn_walker(id)
			if w != null and _walker_hider != null:
				_walker_hider.add_item(w)

## Один гуляющий персонаж (если он есть в ростере и у него есть картинка). Уже есть — null.
func _spawn_walker(id: String) -> HomeWalker:
	if walkers.has(id):
		return null
	if id != "witch" and (UnitRoster_ == null or not UnitRoster_.has_unit(id)):
		return null
	var walk_routes := routes.filter(func(r: HomeRoute) -> bool: return r.action == "")
	if walk_routes.is_empty():
		return null
	var path := SPRITE_PATH % [id, id]
	if not ResourceLoader.exists(path):
		return null
	var w := HomeWalker.new()
	w.setup(id, load(path) as Texture2D, self)
	w.route_changed.connect(func(x: HomeWalker) -> void: _sync_layer.call_deferred(x))
	walkers_front.add_child(w)
	var r: HomeRoute = walk_routes[randi() % walk_routes.size()]
	w.place(r, randf_range(0.1, 0.9) * r.length())
	w.body.flip_h = randf() < 0.5
	walkers[id] = w
	return w

## Персонаж на линии «за котлом» — под слоем котла, иначе — над ним; пока тащим — поверх всего.
func _sync_layer(w: HomeWalker) -> void:
	if not is_instance_valid(w):
		return
	var target: Node2D = walkers_front
	if w.state == HomeWalker.State.DRAG:
		target = drag_layer
	elif w.route != null and w.route.layer == 0:
		target = walkers_back
	if w.get_parent() != target:
		w.reparent(target, true)

# --- Котёл: вход в алхимию -----------------------------------------------------------
## Где котёл (клик — алхимия). Дно с ковриком не считается.
const CAULDRON_RECT := Rect2(780, 755, 260, 235)
var _bubbles: CPUParticles2D
var _cauldron_hover := false

func _build_cauldron_bubbles() -> void:
	_bubbles = CauldronBubbles.make(Vector2(905, 782), Vector2(70, 6))
	add_child(_bubbles)
	move_child(_bubbles, cauldron_layer.get_index() + 1)

func _cauldron_at(p: Vector2) -> bool:
	return cauldron_layer.visible and CAULDRON_RECT.has_point(p) and _opaque(cauldron_layer, p)

func _set_cauldron_hover(on: bool) -> void:
	if on == _cauldron_hover:
		return
	_cauldron_hover = on
	_bubbles.emitting = on

# --- Дверной проём: ферма и лавка ----------------------------------------------------
## Наведение на дверной проём — над ним всплывают значки фермы и лавки. Переход — клик по значку
## (по самому проёму клик ничего не делает). Значки видны, пока курсор на проёме или на них.
const DOOR_RECT := Rect2(1462, 195, 290, 355)
const DOOR_ICON_SIZE := Vector2(120, 120)
const DOOR_ICON_GAP := 14.0
## Значок: картинка и куда ведёт (SceneRouter_).
const DOOR_ICONS := [
	["farm", "res://assets/ui/buttons/farmButton.png", "go_to_farm"],
	["shop", "res://assets/ui/buttons/shopButton.png", "go_to_shop"],
]
const DOOR_ICON_HOVER_SCALE := 1.12
var _door_icons: Dictionary = {}   ## id -> TextureRect
var _door_hover := false
var _door_hot := ""                ## значок под курсором
var _door_tween: Tween

func _build_door_hint() -> void:
	var total := DOOR_ICON_SIZE.x * DOOR_ICONS.size() + DOOR_ICON_GAP * (DOOR_ICONS.size() - 1)
	var x := DOOR_RECT.get_center().x - total * 0.5
	for d in DOOR_ICONS:
		var icon := TextureRect.new()
		icon.name = "Door_" + String(d[0])
		icon.texture = load(String(d[1])) as Texture2D
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size = DOOR_ICON_SIZE
		icon.pivot_offset = DOOR_ICON_SIZE * 0.5
		icon.position = Vector2(x, _door_icon_y(false))
		icon.modulate.a = 0.0
		icon.visible = false
		add_child(icon)
		move_child(icon, foreground.get_index() + 1)
		_door_icons[String(d[0])] = icon
		x += DOOR_ICON_SIZE.x + DOOR_ICON_GAP

func _door_icon_y(shown: bool) -> float:
	return DOOR_RECT.position.y + (40.0 if shown else 60.0)

## Курсор на проёме (значки показываются).
func _door_at(p: Vector2) -> bool:
	return DOOR_RECT.has_point(p) or (_door_hover and _door_icon_at(p) != "")

## Значок под курсором ("" — нет). Только пока значки показаны.
func _door_icon_at(p: Vector2) -> String:
	if not _door_hover:
		return ""
	for id in _door_icons.keys():
		var icon: TextureRect = _door_icons[id]
		if Rect2(icon.position, icon.size).has_point(p):
			return String(id)
	return ""

func _set_door_hover(on: bool) -> void:
	if on != _door_hover:
		_door_hover = on
		if _door_tween != null and _door_tween.is_valid():
			_door_tween.kill()
		_door_tween = create_tween().set_parallel(true)
		for icon: TextureRect in _door_icons.values():
			if on:
				icon.visible = true
			_door_tween.tween_property(icon, "modulate:a", 1.0 if on else 0.0, 0.15)
			_door_tween.tween_property(icon, "position:y", _door_icon_y(on), 0.15)
		if not on:
			_door_tween.chain().tween_callback(func() -> void:
				for icon: TextureRect in _door_icons.values():
					icon.visible = _door_hover)
	var hot := _door_icon_at(get_viewport().get_mouse_position()) if on else ""
	if hot != _door_hot:
		_door_hot = hot
		for id in _door_icons.keys():
			var icon: TextureRect = _door_icons[id]
			icon.create_tween().tween_property(icon, "scale", Vector2.ONE * (DOOR_ICON_HOVER_SCALE if id == hot else 1.0), 0.1)

func _go_door(id: String) -> void:
	for d in DOOR_ICONS:
		if String(d[0]) == id:
			SceneRouter_.call(String(d[2]))

# --- Мышь: наведение, клик, перетаскивание ----------------------------------------------
const HUB_TALK_TYPE := "hub_talk"
const DRAG_START_PX := 12.0
var _hovered: HomeWalker
var _pressed: HomeWalker
var _press_pos := Vector2.ZERO
var _dragging := false
var _talking := ""

## Картинка слоя (во весь экран) непрозрачна в точке p?
static var _layer_images: Dictionary = {}
func _opaque(layer: TextureRect, p: Vector2) -> bool:
	if layer == null or layer.texture == null:
		return false
	var img: Image = _layer_images.get(layer.texture, null)
	if img == null:
		img = layer.texture.get_image()
		if img == null:
			return false
		if img.is_compressed():
			img.decompress()
		_layer_images[layer.texture] = img
	var lp := layer.get_global_transform().affine_inverse() * p
	var k := Vector2(img.get_width() / maxf(1.0, layer.size.x), img.get_height() / maxf(1.0, layer.size.y))
	var px := Vector2i(int(lp.x * k.x), int(lp.y * k.y))
	if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
		return false
	return img.get_pixelv(px).a > 0.5

## Кто под курсором (сверху — тот, кого видно): перетаскиваемый, передний план (никого),
## перед котлом, котёл (никого), за котлом.
func _walker_at(p: Vector2) -> HomeWalker:
	for w in drag_layer.get_children():
		if w is HomeWalker and w.is_over(p):
			return w
	if _opaque(foreground, p):
		return null
	var front := walkers_front.get_children()
	front.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node2D).position.y > (b as Node2D).position.y)
	for w in front:
		if w is HomeWalker and w.is_over(p):
			return w
	if _cauldron_at(p):
		return null
	var back := walkers_back.get_children()
	back.sort_custom(func(a: Node, b: Node) -> bool: return (a as Node2D).position.y > (b as Node2D).position.y)
	for w in back:
		if w is HomeWalker and w.is_over(p):
			return w
	return null

## Курсор над кнопкой или окном (они важнее дома под ними).
func _ui_blocks() -> bool:
	var hc := get_viewport().gui_get_hovered_control()
	return hc != null and hc != self

func _world_locked() -> bool:
	return _talking != "" or (DialogueManager_ != null and DialogueManager_.is_showing()) or get_tree().paused

## Тыква / камин под курсором (если не закрыты передним планом).
func _toggle_at(p: Vector2) -> HubToggle:
	if _opaque(foreground, p):
		return null
	for t: HubToggle in [pumpkin, fireplace]:
		if t != null and t.hit(p):
			return t
	return null

func _process(delta: float) -> void:
	var p := get_viewport().get_mouse_position()
	var over: HomeWalker = null
	var cauldron := false
	var door := false
	var moon := false
	var star := false
	var toggle_hot := false
	if not _world_locked() and not _dragging and not _ui_blocks() and not stars.is_grabbing():
		star = stars.star_at(p) != null
		over = null if star else _walker_at(p)
		cauldron = not star and over == null and not _opaque(foreground, p) and _cauldron_at(p)
		toggle_hot = not star and over == null and not cauldron and _toggle_at(p) != null
		door = not star and over == null and not cauldron and not toggle_hot and _door_at(p)
		moon = not star and over == null and not cauldron and not toggle_hot and not door and _moon_at(p)
	# Круг считает курсор на котле, даже если перед котлом прошёл персонаж.
	var on_cauldron := not _world_locked() and not _ui_blocks() and not stars.is_grabbing() \
		and not _opaque(foreground, p) and _cauldron_at(p)
	_update_magic(on_cauldron, delta)
	if over != _hovered:
		if _hovered != null and is_instance_valid(_hovered):
			_hovered.set_hover(false)
		_hovered = over
		if over != null:
			over.set_hover(true)
	_set_cauldron_hover(cauldron)
	_set_door_hover(door)
	var mess_hot := not _world_locked() and not _ui_blocks() and _mess_at(p) != null
	_shake_cobweb(delta)
	var hand := over != null or cauldron or _door_hot != "" or _dragging or star or toggle_hot or moon or mess_hot
	var drag := _dragging or stars.is_grabbing()
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if drag else (Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW))

## Магический круг у котла: курсор на котле дольше MAGIC_DELAY — проявляется за MAGIC_FADE_IN.
func _update_magic(on_cauldron: bool, delta: float) -> void:
	if not magic_effect.visible:
		return
	if on_cauldron:
		_magic_hold += delta
		var target := clampf((_magic_hold - MAGIC_DELAY) / MAGIC_FADE_IN, 0.0, 1.0)
		magic_effect.modulate.a = maxf(magic_effect.modulate.a, target)
	else:
		_magic_hold = 0.0
		magic_effect.modulate.a = move_toward(magic_effect.modulate.a, 0.0, delta / MAGIC_FADE_OUT)

func _input(event: InputEvent) -> void:
	# Звёздочку тянут — ведём её, пока не отпустят (даже над кнопками).
	if stars.is_grabbing():
		if event is InputEventMouseMotion:
			stars.drag_to((event as InputEventMouseMotion).position)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			stars.release()
			get_viewport().set_input_as_handled()
		return
	# Отпускание / перетаскивание доводим до конца, даже если курсор над кнопкой.
	if _pressed != null:
		if event is InputEventMouseMotion:
			var p: Vector2 = event.position
			if not _dragging and p.distance_to(_press_pos) > DRAG_START_PX:
				_dragging = true
				_pressed.set_hover(false)
				_pressed.begin_drag(_press_pos)
				_sync_layer(_pressed)
			if _dragging:
				_pressed.drag_to(p)
			return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			var w := _pressed
			_pressed = null
			get_viewport().set_input_as_handled()
			if _dragging:
				_dragging = false
				var spot := nearest_spot(w.position)
				if spot[0] != null:
					w.drop(spot[0], float(spot[1]))
			else:
				_click(w)
			return
	if _world_locked() or _ui_blocks():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		# Грязь под курсором — оттираем; клик идёт дальше (камин под паутиной ещё и включится).
		var mess := _mess_at(p)
		if mess != null:
			mess.scrub()
			get_viewport().set_input_as_handled()
		var st := stars.star_at(p)
		if st != null:
			stars.grab(st, p)
			get_viewport().set_input_as_handled()
			return
		var w := _walker_at(p)
		if w != null:
			_pressed = w
			_press_pos = p
			get_viewport().set_input_as_handled()
		elif not _opaque(foreground, p) and _cauldron_at(p):
			get_viewport().set_input_as_handled()
			SceneRouter_.go_to_alchemy()
		elif _toggle_at(p) != null:
			get_viewport().set_input_as_handled()
			_toggle_at(p).toggle()
		elif _door_icon_at(p) != "":
			get_viewport().set_input_as_handled()
			_go_door(_door_icon_at(p))
		elif _moon_at(p):
			get_viewport().set_input_as_handled()
			sky.click_moon()

## Луна под курсором и её видно (через прозрачные места дома: стены, передний план, котёл не закрывают).
func _moon_at(p: Vector2) -> bool:
	if sky == null or not sky.moon_at(p):
		return false
	for layer in [background, foreground, cauldron_layer]:
		if layer != null and layer.visible and _opaque(layer, p):
			return false
	return true

# --- Уборка: грязь в доме (HubMess в Mess / MessTop) ------------------------------------
## В начале игры (после обучения) дом грязный: паутина, лужи. Ведьмочка замечает это пузырём.
## Кликами грязь оттирается (по паутине на звёздах — помотать звёздочки). Убрано всё —
## главный герой находит данго-посох (диалог "fireplace_dango" из data/dialogues/hub/home_events.json
## с give_item и «Получено»). В старых сохранениях, где посох уже найден, награды нет.
const MESS_STARTED_FLAG := "hub_mess_started"
const MESS_DONE_FLAG := "hub_mess_done"
const MESS_BUBBLE_FLAG := "hub_mess_bubble_said"
const MESS_BUBBLE_TEXT := "Как же тут грязно... Кто тут жил до меня?"
const FIREPLACE_FLAG := "fireplace_dango_found"
const FIREPLACE_DIALOGUE := "fireplace_dango"
## Книги и весы на заднем фоне — с улучшениями котла (уровень 2 — книги, 3 — весы).
@onready var cauldron_upgrade_1: TextureRect = $CauldronUpgrade1
@onready var cauldron_upgrade_2: TextureRect = $CauldronUpgrade2
var _messes: Array[HubMess] = []
var _bubble_layer: BattleSpeechLayer

func _setup_home_props() -> void:
	var lvl := AlchemyDB.cauldron_level()
	cauldron_upgrade_1.visible = lvl >= 2
	cauldron_upgrade_2.visible = lvl >= 3
	_setup_mess()

func mess_active() -> bool:
	return StoryState_ != null and StoryState_.has_flag(MESS_STARTED_FLAG) and not StoryState_.has_flag(MESS_DONE_FLAG)

func _setup_mess() -> void:
	for n in find_children("*", "HubMess", true, false):
		_messes.append(n as HubMess)
	# Обучение пройдено, а уборки ещё не было — дом грязный.
	if StoryState_ != null and not StoryState_.has_flag(MESS_STARTED_FLAG) and not StoryState_.has_flag(MESS_DONE_FLAG) \
			and not StoryState_.tutorial_battle_pending:
		StoryState_.set_flag(MESS_STARTED_FLAG, true)
	var active := mess_active()
	for m in _messes:
		m.visible = active and not m.is_clean()
		m.cleaned.connect(_on_mess_cleaned)
		# Пока предмет под паутиной — он выключен (если его ещё не трогали в этот запуск).
		if m.visible and not m.covers.is_empty():
			var t := m.get_node_or_null(m.covers) as HubToggle
			if t != null and not HubToggle._states.has(String(t.name)):
				t.is_on = false
				t._apply(false)
	if active and not StoryState_.has_flag(MESS_BUBBLE_FLAG):
		_say_mess_bubble()

func _mess_at(p: Vector2) -> HubMess:
	if not mess_active():
		return null
	for i in range(_messes.size() - 1, -1, -1):
		var m := _messes[i]
		if m.visible and not m.is_clean() and m.hit(p):
			return m
	return null

## Паутина на звёздах: спадает, если помотать звёздочки (считаем, сколько они «пролетели»).
func _shake_cobweb(delta: float) -> void:
	if not mess_active():
		return
	var amount := 0.0
	for st in stars.stars():
		if st.vel.length() > 60.0:   ## только когда правда мотают, а не дрожат в покое
			amount += st.vel.length() * delta
	if amount <= 0.5:
		return
	for m in _messes:
		if m.shake and m.visible and not m.is_clean():
			m.shake_by(amount)

func _on_mess_cleaned(_m: HubMess) -> void:
	for m in _messes:
		if not m.is_clean():
			return
	if StoryState_ == null:
		return
	StoryState_.set_flag(MESS_DONE_FLAG, true)
	if StoryState_.has_flag(FIREPLACE_FLAG):
		return
	await get_tree().create_timer(0.6).timeout
	while DialogueManager_.is_showing():
		await get_tree().process_frame
	var d := StoryDialogueDB_.get_dialogue(FIREPLACE_DIALOGUE) if StoryDialogueDB_ != null else {}
	if d.is_empty():
		return
	StoryState_.set_flag(FIREPLACE_FLAG, true)
	DialogueManager_.show_sequence(StoryDialogueDB_.resolve_lines(d), Callable(self, "_on_pending_story_dialogue_finished").bind(d))

## Пузырь над ведьмочкой: «Как же тут грязно...» — когда нет диалога на экране.
func _say_mess_bubble() -> void:
	await get_tree().create_timer(1.0).timeout
	while is_inside_tree() and DialogueManager_.is_showing():
		await get_tree().create_timer(0.3).timeout
	if not is_inside_tree() or not walkers.has("witch"):
		return
	await get_tree().create_timer(0.6).timeout
	var w: HomeWalker = walkers["witch"]
	if not is_instance_valid(w):
		return
	if _bubble_layer == null:
		_bubble_layer = BattleSpeechLayer.new()
		_bubble_layer.name = "HubBubbleLayer"
		_bubble_layer.bubble_offset = Vector2.ZERO
		_bubble_layer.bubble_min_width = 300.0
		_bubble_layer.bubble_max_width = 460.0
		_bubble_layer.bubble_font_px = 26
		_bubble_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bubble_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bubble_layer)
	_bubble_layer.show_line_for_actor(w.head_anchor(), MESS_BUBBLE_TEXT)
	StoryState_.set_flag(MESS_BUBBLE_FLAG, true)

## Картинка «по персонажу кликнули»: assets/characters/<id>/<id>_click.png (тот же холст, что _battle).
const CLICK_SPRITE_PATH := "res://assets/characters/%s/%s_click.png"

## Клик по персонажу: с кем есть разговор — разговор (пока только Фуфу), остальные подпрыгивают
## (на кровати — нет) и на время прыжка показывают картинку <id>_click (нет её — ведьмочка «фаза 2»).
func _click(w: HomeWalker) -> void:
	if _can_talk(w.unit_id):
		talk_to(w.unit_id)
		return
	if w.on_bed():
		return
	var click_path := CLICK_SPRITE_PATH % [w.unit_id, w.unit_id]
	if ResourceLoader.exists(click_path):
		w.poke(load(click_path) as Texture2D)
	elif w.unit_id == "witch":
		var alt := CharacterPhases.texture(w.base_tex, 2)
		w.poke(alt if alt != w.base_tex else null)
	else:
		w.poke()

func _can_talk(id: String) -> bool:
	return StoryDialogueDB_ != null and not StoryDialogueDB_.pick_npc_dialogue(id, HUB_TALK_TYPE).is_empty()

func talk_to(id: String) -> void:
	var d := StoryDialogueDB_.pick_npc_dialogue(id, HUB_TALK_TYPE)
	if d.is_empty():
		return
	var lines := StoryDialogueDB_.resolve_lines(d)
	if lines.is_empty():
		return
	_talking = id
	var w: HomeWalker = walkers.get(id, null)
	if w != null:
		w.set_hover(false)
		w.set_frozen(true)   ## стоит на месте, пока говорим
	_hovered = null
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	DialogueManager_.show_sequence(lines, Callable(self, "_on_talk_finished").bind(d))

func _on_talk_finished(dialogue: Dictionary) -> void:
	var w: HomeWalker = walkers.get(_talking, null)
	if w != null and is_instance_valid(w):
		w.set_frozen(false)
	_talking = ""
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen(String(dialogue.get("id", "")))
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.apply_effects(dialogue.get("on_finish", {}))

func _on_start_run() -> void:
	# Тут логично начинать новый забег (seed, сброс золота и т.д.)
	# Но если Вы хотите сохранить "старт run" строго в Setup — можно перенести туда.
	SceneRouter_.go_to_setup()

## Отложенные сюжетные диалоги: флаг StoryState -> id диалога (первый поднятый флаг играется при входе в хаб).
const PENDING_DIALOGUES := [
	["pending_tutorial_rikka", "tutorial_rikka_after"],
	["pending_find_warrior_after_battle", "find_warrior_after_battle"],
]

func _play_pending_story_dialogue() -> void:
	if StoryState_ == null or StoryDialogueDB_ == null:
		return
	for pair in PENDING_DIALOGUES:
		var flag := String(pair[0])
		if not StoryState_.has_flag(flag):
			continue
		StoryState_.set_flag(flag, false)
		var d := StoryDialogueDB_.get_dialogue(String(pair[1]))
		if d.is_empty():
			continue
		var lines := StoryDialogueDB_.resolve_lines(d)
		if lines.is_empty():
			StoryDialogueDB_.apply_effects(d.get("on_finish", {}))
			continue
		DialogueManager_.show_sequence(lines, Callable(self, "_on_pending_story_dialogue_finished").bind(d))
		return
	# Только что вернулись из забега — сцена "after_run", если какая-то доступна (по priority).
	if StoryState_.has_flag(CardBattle.AFTER_RUN_FLAG):
		StoryState_.set_flag(CardBattle.AFTER_RUN_FLAG, false)
		var after := StoryDialogueDB_.pick_dialogue_of_type("after_run")
		if not after.is_empty():
			var after_lines := StoryDialogueDB_.resolve_lines(after)
			if not after_lines.is_empty():
				DialogueManager_.show_sequence(after_lines, Callable(self, "_on_pending_story_dialogue_finished").bind(after))
				return
	# Сюжетных диалогов в очереди нет — может, пора спросить, кто главный герой.
	MainHeroChoicePopup.show_if_needed(self)

func _on_pending_story_dialogue_finished(dialogue: Dictionary) -> void:
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen(String(dialogue.get("id", "")))
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.apply_effects(dialogue.get("on_finish", {}))
	# После диалога с воином (он только что вступил в отряд) — окно выбора главного героя.
	MainHeroChoicePopup.show_if_needed(self)
