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

## Магический круг: через сколько секунд на котле начинает проявляться, за сколько проявляется
## полностью и за сколько гаснет, когда курсор ушёл.
const MAGIC_DELAY := 2.0
const MAGIC_FADE_IN := 5.0
const MAGIC_FADE_OUT := 1.2
var _magic_hold := 0.0

func _ready() -> void:
	get_tree().paused = false
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

func _spawn_walkers() -> void:
	var walk_routes := routes.filter(func(r: HomeRoute) -> bool: return r.action == "")
	if walk_routes.is_empty():
		return
	var bodies: Array = []
	for id in HOME_UNITS:
		if id != "witch" and (UnitRoster_ == null or not UnitRoster_.has_unit(id)):
			continue
		var path := SPRITE_PATH % [id, id]
		if not ResourceLoader.exists(path):
			continue
		var w := HomeWalker.new()
		w.setup(id, load(path) as Texture2D, self)
		w.route_changed.connect(func(x: HomeWalker) -> void: _sync_layer.call_deferred(x))
		walkers_front.add_child(w)
		var r: HomeRoute = walk_routes[randi() % walk_routes.size()]
		w.place(r, randf_range(0.1, 0.9) * r.length())
		w.body.flip_h = randf() < 0.5
		walkers[id] = w
		bodies.append(w)
	# Пока открыт диалог (VN), гуляющие по дому прячутся — на экране только портреты из диалога.
	VnSpriteHider.attach(self, bodies)

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

# --- Дверной проём: вход на ферму -----------------------------------------------------
## Где дверной проём (клик — ферма). При наведении над ним всплывает значок фермы.
const DOOR_RECT := Rect2(1462, 195, 290, 355)
const FARM_ICON := "res://assets/ui/buttons/farmButton.png"
var _door_hint: TextureRect
var _door_hover := false
var _door_tween: Tween

func _build_door_hint() -> void:
	_door_hint = TextureRect.new()
	_door_hint.name = "DoorFarmHint"
	_door_hint.texture = load(FARM_ICON) as Texture2D
	_door_hint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_door_hint.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_door_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_hint.size = Vector2(110, 110)
	_door_hint.position = Vector2(DOOR_RECT.get_center().x - 55, DOOR_RECT.position.y + 40)
	_door_hint.modulate.a = 0.0
	add_child(_door_hint)
	move_child(_door_hint, foreground.get_index() + 1)

func _door_at(p: Vector2) -> bool:
	return DOOR_RECT.has_point(p)

func _set_door_hover(on: bool) -> void:
	if on == _door_hover:
		return
	_door_hover = on
	if _door_tween != null and _door_tween.is_valid():
		_door_tween.kill()
	_door_tween = create_tween().set_parallel(true)
	_door_tween.tween_property(_door_hint, "modulate:a", 1.0 if on else 0.0, 0.15)
	var y := DOOR_RECT.position.y + (20.0 if on else 40.0)
	_door_tween.tween_property(_door_hint, "position:y", y, 0.15)

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
	var star := false
	var toggle_hot := false
	if not _world_locked() and not _dragging and not _ui_blocks() and not stars.is_grabbing():
		star = stars.star_at(p) != null
		over = null if star else _walker_at(p)
		cauldron = not star and over == null and not _opaque(foreground, p) and _cauldron_at(p)
		toggle_hot = not star and over == null and not cauldron and _toggle_at(p) != null
		door = not star and over == null and not cauldron and not toggle_hot and _door_at(p)
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
	var hand := over != null or cauldron or door or _dragging or star or toggle_hot
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
		elif _door_at(p):
			get_viewport().set_input_as_handled()
			SceneRouter_.go_to_farm()

## Клик по персонажу: с кем есть разговор — разговор (пока только Фуфу), остальные подпрыгивают
## (на кровати — нет), ведьмочка на миг становится «фазой 2».
func _click(w: HomeWalker) -> void:
	if _can_talk(w.unit_id):
		talk_to(w.unit_id)
		return
	if w.on_bed():
		return
	if w.unit_id == "witch":
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
