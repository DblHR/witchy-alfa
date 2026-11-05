extends Node2D
class_name CardBattle
## Карточный бой: сцена, ход боя, рука и перетаскивание карт, комнаты забега.
##
## Части вынесены в отдельные скрипты:
##   CardCombat     — ядро правил: команды, щиты, статусы, урон (без UI и без знания карт)
##   effects/       — эффекты карт (урон, щит, статусы…); карты — ресурсы CardDef в resources/cards
##   statuses/      — описания статусов (Горение, Слизи, Нажим…), реестр CardStatuses
##   passives/      — пассивки героев (подписываются на сигналы CardCombat)
##   CardDeck       — колода, рука, сброс, сгоревшие карты (данные)
##   CardSleeve     — зона рукава и её карты
##   CardUltBar     — колонка ульт и заряд
##   CardPilePopup  — окно просмотра колоды/сброса
##   CardActorFx    — подписи над актёрами, idle, прыжок, всплывающий текст
##   CardDragPortrait — портрет героини, выезжающий слева при перетаскивании её карты
##   CardRun        — генерация и состояние забега; окна забега — *Popup / EventScreen
##
## Из общего состояния читается отряд из Setup (DungRun.party_ids / party_level /
## party_slot_count) и эстус (DungRun.estus_stacks / estus_power).
## Конец забега: FarmState_.advance_day() -> DungRun.on_run_finished_refresh_shops() -> хаб.
## BattleActor используется как «тупой» виджет (читает только Unit/CharacterData).

const BATTLE_ACTOR_SCENE: PackedScene = preload("res://scenes/BattleActor.tscn")
const VICTORY_TEXTURE: Texture2D = preload("res://assets/pics/bigPics/endscreen/victory.png")
const DEFEAT_TEXTURE: Texture2D = preload("res://assets/pics/bigPics/endscreen/defeat.png")
const _TargetRing := preload("res://scripts/card/TargetRing.gd")
const _TargetMark := preload("res://scripts/card/TargetMark.gd")

# --- Правила прототипа (все числа тестовые) ----------------------------------
const ENEMY_ID := "base_slime"

const ENERGY_PER_TURN := 3
const HAND_SIZE := 5
const FILLER_ATTACK_COUNT := 4
const FILLER_SHIELD_COUNT := 2
## Щит держится до начала следующего хода игрока (после удара врагов).
const SHIELD_EXPIRES_ON_NEW_TURN := true

## Добыча и дары забега (тестовые).
const LOOT_GOLD_BASE := 4         ## золото с врага = 4 + номер комнаты (как в автобаттлере)
const LOOT_XP_BASE := 6           ## опыт с врага = 6 + 2 × номер комнаты
const LOOT_XP_PER_ROOM := 2
const LOOT_QUARTZ_CHANCE := 0.10  ## шанс кварца с каждого врага
const WHITE_STATUE_HEAL_PERCENT := 0.12   ## белая статуя: +12% макс. HP после победы
const BLACK_STATUE_BONUS := 2     ## +урон каждой карте, пока действует чёрная статуя
const CHEST_GOLD_BASE := 12
const CHEST_GOLD_PER_ROOM := 5

# --- Раскладка ---------------------------------------------------------------
const HAND_CENTER_X := 960.0
const HAND_TOP_Y := 845.0
const HAND_GAP := 16.0
## Зона «вернуть в руку» (невидимая): ниже линии и между рукавом и кнопкой «Завершить ход».
## Карты без выбора цели играются в любой точке вне неё.
const RETURN_RECT := Rect2(460, 770, 1130, 310)
## Высота прыжка героя при ульте (при обычной карте — CardActorFx.HOP_HEIGHT).
const ULT_HOP_HEIGHT := 34.0


@onready var room_label: Label = %RoomLabel
@onready var hint_label: Label = %HintLabel
@onready var exit_button: Button = %ExitButton
@onready var left_world: Node2D = %LeftSlotsWorld
@onready var right_world: Node2D = %RightSlotsWorld
@onready var hud: Control = %Hud
@onready var hand_layer: Control = %HandLayer
@onready var deck_button: Button = %DeckButton
@onready var discard_button: Button = %DiscardButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var energy_label: Label = %EnergyLabel
@onready var end_overlay: Control = %EndOverlay
@onready var end_image: TextureRect = %EndImage
@onready var end_text: Label = %EndText
@onready var end_button: Button = %EndButton

var left_team: Array[Unit] = []
var right_team: Array[Unit] = []
var left_actors: Array[BattleActor] = []
var right_actors: Array[BattleActor] = []
## Unit -> BattleActor (раньше каждый поиск перебирал и копировал списки актёров).
var _actor_of: Dictionary = {}

var _left_world_slots: Array[Node2D] = []
var _right_world_slots: Array[Node2D] = []

var _combat := CardCombat.new()
var _deck := CardDeck.new()
var _sleeve: CardSleeve
var _ults: CardUltBar
var _pile_popup: CardPilePopup
var _drag_portrait: CardDragPortrait

var _hand_views: Array[CardView] = []
var _dragging: CardView = null
var _drag_grab_offset := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _has_last_mouse := false
var _highlights: Array[Control] = []
var _active_rings: Array[Node2D] = []

var _energy: int = 0
var _room_index: int = 0
## Сколько плавающих надписей уже показано над юнитом в этом действии (чтобы не налезали).
var _float_stack: Dictionary = {}
var _busy := false
var _ended := false
var _end_victory := false

var _run: CardRun
var _banter: CardBanter
var _gold_label: Label
var _progress: RunProgress
var _room_loot: Dictionary = {}   ## что выпало в этой комнате: gold, xp, items
var _ui_layer: Node               ## сюда добавляются окна забега (над остальным UI)

func _ready() -> void:
	set_process(false)   # _process нужен только во время перетаскивания
	# Один кадр на то, чтобы контейнеры посчитали размеры.
	await get_tree().process_frame

	room_label.text = "Карточный бой"
	# Лог событий боя на экран не выводится: всё видно по всплывающим числам над персонажами.
	hint_label.visible = false

	exit_button.pressed.connect(_on_exit_pressed)
	end_button.pressed.connect(_on_end_button_pressed)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	deck_button.pressed.connect(func() -> void: _open_pile(true))
	discard_button.pressed.connect(func() -> void: _open_pile(false))

	end_overlay.visible = false
	# Старые узлы сцены (зона розыгрыша и жёлтая рамка цели) больше не используются.
	%PlayZone.visible = false
	%TargetHighlight.visible = false

	_combat.heroes = left_team
	_combat.enemies = right_team
	_combat.floated.connect(_float_for)
	_combat.hurt.connect(_on_unit_hurt)
	_combat.died.connect(_on_unit_died)

	_run = CardRun.new()
	_ui_layer = hud.get_parent()
	_build_run_hud()
	_cache_world_slots()
	_spawn_heroes()
	for u in left_team:
		if u.data.card_passive != null:
			u.data.card_passive.attach(_combat, u)

	_ults = CardUltBar.new()
	hud.add_child(_ults)
	_ults.build(left_team)
	_ults.ult_pressed.connect(_on_ult_pressed)

	_pile_popup = CardPilePopup.new()
	hud.add_child(_pile_popup)

	_sleeve = CardSleeve.new()
	hud.add_child(_sleeve)
	_sleeve.card_clicked.connect(_on_sleeve_card_clicked)

	# Портрет при перетаскивании: под рукой, но над миром.
	_drag_portrait = CardDragPortrait.new()
	hud.add_child(_drag_portrait)
	hud.move_child(_drag_portrait, hand_layer.get_index())
	for u in left_team:
		CardDragPortrait.warm_up(u.data)

	_setup_banter()
	await _start_room(0)

func _exit_tree() -> void:
	if BattleBanter_ != null:
		BattleBanter_.end_battle()

# --- Команды -----------------------------------------------------------------

func _make_unit(id: String, level: int) -> Unit:
	var data: CharacterData = CharDB.get_by_id(id)
	if data == null:
		push_warning("CardBattle: персонаж не найден в CharDB: %s" % id)
		return null
	return Unit.new(data, level)

func _spawn_heroes() -> void:
	left_team.clear()
	var level := maxi(1, DungRun.party_level)
	var slot_count := mini(DungRun.party_slot_count, DungRun.party_ids.size())
	for i in range(slot_count):
		var id: String = DungRun.party_ids[i]
		if id == "":
			continue
		var unit := _make_unit(id, level)
		if unit != null:
			left_team.append(unit)
	# Страховка: если отряд пуст, берём ведьму, чтобы сцена не была пустой.
	if left_team.is_empty():
		var fallback := _make_unit("witch", level)
		if fallback != null:
			left_team.append(fallback)

func _spawn_enemies(room: Dictionary) -> void:
	right_team.clear()
	for i in range(int(room["count"])):
		var enemy := _make_unit(String(room.get("enemy_id", ENEMY_ID)), 1)
		if enemy == null:
			continue
		enemy.make_enemy(0, 0)
		enemy.max_hp = int(room["hp"])
		enemy.hp = enemy.max_hp
		right_team.append(enemy)

# --- Расстановка на сцене ----------------------------------------------------

func _cache_world_slots() -> void:
	_left_world_slots.clear()
	_right_world_slots.clear()
	for i in [3, 2, 1, 0]:
		_left_world_slots.append(left_world.get_node_or_null("LeftSlot%d" % i) as Node2D)
	for i in range(4):
		_right_world_slots.append(right_world.get_node_or_null("RightSlot%d" % i) as Node2D)

func _clear_slot(slot: Node2D) -> void:
	for c in slot.get_children():
		slot.remove_child(c)
		c.queue_free()
	slot.visible = false

func _spawn_actor(slot: Node2D, unit: Unit, is_left: bool) -> BattleActor:
	var actor := BATTLE_ACTOR_SCENE.instantiate() as BattleActor
	slot.visible = true
	slot.add_child(actor)
	if not is_left:
		actor.is_boss = bool(_run.room(_room_index).get("boss", false))
	actor.bind(unit, is_left)
	CardActorFx.setup_overlays(actor, not is_left)
	_actor_of[unit] = actor
	return actor

func _populate_world_slots() -> void:
	left_actors.clear()
	right_actors.clear()
	_actor_of.clear()
	for slot in _left_world_slots + _right_world_slots:
		if slot != null:
			_clear_slot(slot)

	var left_start := maxi(0, _left_world_slots.size() - left_team.size())
	for i in range(left_team.size()):
		var idx := left_start + i
		if idx >= _left_world_slots.size():
			break
		if _left_world_slots[idx] != null:
			left_actors.append(_spawn_actor(_left_world_slots[idx], left_team[i], true))
	for i in range(mini(right_team.size(), _right_world_slots.size())):
		if _right_world_slots[i] != null:
			right_actors.append(_spawn_actor(_right_world_slots[i], right_team[i], false))
	for a in left_actors + right_actors:
		CardActorFx.start_idle(a)

func _find_actor(unit: Unit) -> BattleActor:
	var a: BattleActor = _actor_of.get(unit)
	return a if is_instance_valid(a) else null

func _refresh_actor(actor: BattleActor) -> void:
	if actor == null or actor.unit == null:
		return
	var unit := actor.unit
	if unit.is_dead:
		CardActorFx.stop_idle(actor)
	actor.update_visual()

	var shield := _combat.shield_of(unit)
	var shield_label := CardActorFx.shield_label(actor)
	shield_label.text = "Щит: %d" % shield
	shield_label.visible = shield > 0 and not unit.is_dead

	var intent_label := actor.get_node_or_null("IntentLabel") as Label
	if intent_label != null:
		var has_intent := _combat.intents.has(unit) and not unit.is_dead and not _ended
		intent_label.visible = has_intent
		if has_intent:
			if _combat.skips_turn(unit):
				intent_label.text = "Оглушён"
				intent_label.add_theme_color_override("font_color", CardCombat.COL_STATUS)
			elif _combat.is_charmed(unit):
				intent_label.text = "Бьёт своих: %d" % _combat.effective_intent(unit)
				intent_label.add_theme_color_override("font_color", CardCombat.COL_HEAL)
			else:
				intent_label.text = "Удар: %d" % _combat.effective_intent(unit)
				intent_label.add_theme_color_override("font_color", CardCombat.COL_SHIELD if _combat.intent_reduced(unit) else CardActorFx.COL_INTENT)

	var status_label := actor.get_node_or_null("StatusLabel") as Label
	if status_label != null:
		var text := _combat.status_text(unit)
		status_label.text = text
		status_label.visible = text != "" and not unit.is_dead

func _refresh_all_actors() -> void:
	for a in left_actors + right_actors:
		_refresh_actor(a)
	_ults.refresh()

# --- Отклик на события CardCombat --------------------------------------------

func _on_unit_hurt(unit: Unit, hp_damage: int) -> void:
	var actor := _find_actor(unit)
	if actor == null:
		return
	if hp_damage > 0:
		actor.flash_red()
	_refresh_actor(actor)

func _on_unit_died(unit: Unit) -> void:
	if left_team.has(unit):
		_purge_cards_of(unit)
	elif right_team.has(unit):
		_on_enemy_killed(unit)

func _float_for(unit: Unit, text: String, color: Color, font_size: int = 26) -> void:
	var actor := _find_actor(unit)
	if actor == null:
		return
	var n := int(_float_stack.get(unit, 0))
	_float_stack[unit] = n + 1
	CardActorFx.spawn_float_text(hud, actor.global_position + Vector2(-40, -240 - 34 * n), text, color, font_size)

# --- Комнаты и раздача -------------------------------------------------------

func _start_room(index: int) -> void:
	_busy = true
	_clear_hand_views()
	_room_index = index
	var room := _run.room(index)
	room_label.text = "Комната %d / %d" % [index + 1, _run.total_rooms()]

	_combat.reset()
	_combat.damage_bonus = BLACK_STATUE_BONUS if _run.black_charges > 0 else 0
	_float_stack.clear()
	refresh_run_hud()

	if String(room.get("kind", "")) == "event":
		await _start_event_room(room)
		return

	_set_battle_ui(true)
	_room_loot = {"gold": 0, "xp": 0, "items": {}}
	_spawn_enemies(room)
	_populate_world_slots()
	_ults.refresh()

	_sleeve.clear()
	_deck.start_battle(_build_battle_deck())
	_refresh_pile_buttons()

	BattleBanter_.start_battle(self)
	BattleBanter_.trigger("battle_start")
	await _begin_player_turn()

## Колода на бой: карты живых героев, добытые карты, филлеры и эстус. Сброс пуст.
func _build_battle_deck() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for u in left_team:
		if u == null or u.is_dead:
			continue
		cards.append_array(CardLibrary.hero_deck(u))
	for card_id in _run.bonus_cards:
		var owner_id := CardLibrary.owner_of(card_id)
		var owner := _combat.hero_by_id(owner_id)
		if owner_id != "" and not CardCombat.is_alive(owner):
			continue
		var bonus := CardLibrary.card_by_id(card_id, owner)
		if bonus != null:
			cards.append(bonus)
	cards.append_array(CardLibrary.filler_cards(FILLER_ATTACK_COUNT, FILLER_SHIELD_COUNT))
	cards.append_array(CardLibrary.estus_cards(DungRun.estus_stacks))
	return _without_run_burned(cards)

## Убирает из колоды карты, сгоревшие до конца забега (по копии на каждое сгорание).
func _without_run_burned(cards: Array[CardInstance]) -> Array[CardInstance]:
	var left: Dictionary = {}
	for id in _run.burned_for_run:
		left[id] = int(left.get(id, 0)) + 1
	var out: Array[CardInstance] = []
	for c in cards:
		if int(left.get(c.id, 0)) > 0:
			left[c.id] -= 1
			continue
		out.append(c)
	return out

func _begin_player_turn() -> void:
	_energy = ENERGY_PER_TURN
	_combat.begin_player_turn()
	var room := _run.room(_room_index)
	_combat.roll_intents(int(room["atk_min"]), int(room["atk_max"]))
	_refresh_all_actors()
	await _deal_new_hand()

func _clear_hand_views() -> void:
	for v in _hand_views:
		v.fly_to_and_free(_discard_pos())
	_hand_views.clear()
	_deck.discard_hand()
	_refresh_pile_buttons()

func _refresh_energy() -> void:
	energy_label.text = "Энергия: %d/%d" % [_energy, ENERGY_PER_TURN]
	for v in _hand_views:
		var cost := _combat.effective_cost(v.card)
		v.set_cost_text(cost, cost > v.card.cost)
		v.set_affordable(cost <= _energy)

func _deal_new_hand() -> void:
	_busy = true
	# Карты из рукава возвращаются в руку первыми, добирается на столько же меньше.
	var from_sleeve := _sleeve.take_all()
	_deck.hand.append_array(from_sleeve)
	var drawn := _deck.draw(maxi(0, HAND_SIZE - from_sleeve.size()))
	_refresh_pile_buttons()
	for c in from_sleeve + drawn:
		_add_card_view(c)
	_layout_hand(true)
	_refresh_energy()
	await _wait(0.3)
	_busy = false

func _add_card_view(c: CardInstance) -> CardView:
	var v := CardView.new()
	v.setup(c, true)
	hand_layer.add_child(v)
	v.position = deck_button.get_global_rect().get_center() - CardView.CARD_SIZE * 0.5
	v.pressed.connect(_on_card_pressed)
	v.appear()
	_hand_views.append(v)
	return v

func _hand_slot_position(index: int, count: int) -> Vector2:
	var total := count * CardView.CARD_SIZE.x + (count - 1) * HAND_GAP
	var x := HAND_CENTER_X - total * 0.5 + index * (CardView.CARD_SIZE.x + HAND_GAP)
	return Vector2(x, HAND_TOP_Y)

func _layout_hand(animated: bool) -> void:
	var n := _hand_views.size()
	for i in range(n):
		var v := _hand_views[i]
		v.home_position = _hand_slot_position(i, n)
		if v == _dragging:
			continue
		if animated:
			v.move_to(v.home_position)
		else:
			v.position = v.home_position

func _wait(seconds: float) -> void:
	# Твин привязан к узлу: если сцену закрыли, ожидание просто не продолжится.
	var t := create_tween()
	t.tween_interval(seconds)
	await t.finished

func _refresh_pile_buttons() -> void:
	deck_button.text = "Колода: %d" % _deck.draw_pile.size()
	discard_button.text = "Сброс: %d" % _deck.discard_pile.size()

func _discard_pos() -> Vector2:
	return discard_button.get_global_rect().get_center() - CardView.CARD_SIZE * 0.5

func _open_pile(is_draw_pile: bool) -> void:
	if _dragging != null:
		return
	if is_draw_pile:
		_pile_popup.open("Колода", _deck.draw_pile)
	else:
		_pile_popup.open("Сброс", _deck.discard_pile, "Сгорело", _deck.burned_pile)

# --- Перетаскивание ----------------------------------------------------------

func _can_act() -> bool:
	return not _busy and not _ended and _dragging == null

func _on_card_pressed(v: CardView) -> void:
	if not _can_act():
		return
	_dragging = v
	_drag_grab_offset = _mouse_pos() - v.global_position
	v.begin_drag()
	hand_layer.move_child(v, -1)
	var owner := _combat.hero_by_id(v.card.owner_id)
	if owner != null:
		_drag_portrait.show_for(owner.data, v.card.target == CardInstance.Target.CHOSEN_ALLY)
	set_process(true)
	_update_drag_feedback()

## Позиция мыши: берём из последнего события (get_mouse_position не обновляется синтетическим вводом).
func _mouse_pos() -> Vector2:
	return _last_mouse if _has_last_mouse else get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_mouse = (event as InputEventMouse).position
		_has_last_mouse = true
	if _dragging == null:
		return
	if event is InputEventMouseMotion:
		_dragging.global_position = _mouse_pos() - _drag_grab_offset
		_update_drag_feedback()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		_finish_drag()

func _process(_delta: float) -> void:
	# Страховка: если отпускание кнопки «потерялось» (например, пауза), не застреваем.
	if _dragging != null and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()

## Цели карт без выбора цели.
func _zone_targets(card: CardInstance) -> Array[Unit]:
	var out: Array[Unit] = []
	match card.target:
		CardInstance.Target.FRONT_ENEMY:
			var e := _combat.front_enemy()
			if e != null:
				out.append(e)
		CardInstance.Target.ALL_ENEMIES:
			out.append_array(_combat.alive_enemies())
		CardInstance.Target.SELF:
			var h := _combat.hero_by_id(card.owner_id)
			if CardCombat.is_alive(h):
				out.append(h)
	return out

## Что получит карта, если отпустить её в точке. Пустой список — «не сыграть».
func _drop_targets(card: CardInstance, point: Vector2) -> Array[Unit]:
	var out: Array[Unit] = []
	match card.target:
		CardInstance.Target.CHOSEN_ENEMY:
			var enemy := _unit_at(right_actors, point)
			if enemy != null:
				out.append(enemy)
		CardInstance.Target.CHOSEN_ALLY:
			var hero := _unit_at(left_actors, point)
			if hero != null:
				out.append(hero)
		_:
			if not RETURN_RECT.has_point(point):
				out = _zone_targets(card)
	return out

func _update_drag_feedback() -> void:
	if _dragging == null:
		return
	var point := _mouse_pos()
	var over_sleeve := CardSleeve.in_zone(point)
	_sleeve.set_hover(over_sleeve)
	_show_highlights([] as Array[Unit] if over_sleeve else _drop_targets(_dragging.card, point))

func _get_highlight(i: int) -> Control:
	while _highlights.size() <= i:
		var mark := Control.new()
		mark.set_script(_TargetMark)
		mark.visible = false
		hud.add_child(mark)
		_highlights.append(mark)
	return _highlights[i]

## Подсветка целей: кольцо под ногами и стрелка над головой.
## Союзники — зелёные, враги — красные.
func _show_highlights(units: Array[Unit]) -> void:
	_hide_rings()
	var shown := 0
	for u in units:
		var actor := _find_actor(u)
		if actor == null:
			continue
		var col: Color = _TargetRing.COLOR_ALLY if left_team.has(u) else _TargetRing.COLOR_ENEMY
		var rect := _actor_hit_rect(actor)
		var h := _get_highlight(shown)
		h.global_position = rect.position
		h.size = rect.size
		h.set("color", col)
		h.visible = true
		var ring := _ring_for(actor)
		ring.call("show_ring", clampf(rect.size.x * 0.42, 50.0, 120.0), col)
		_active_rings.append(ring)
		shown += 1
	for i in range(shown, _highlights.size()):
		_highlights[i].visible = false

func _hide_highlights() -> void:
	for h in _highlights:
		h.visible = false
	_hide_rings()

## Кольцо — первый ребёнок актёра, поэтому лежит под его спрайтом.
func _ring_for(actor: BattleActor) -> Node2D:
	var ring := actor.get_node_or_null("TargetRing") as Node2D
	if ring == null:
		ring = Node2D.new()
		ring.name = "TargetRing"
		ring.set_script(_TargetRing)
		actor.add_child(ring)
		actor.move_child(ring, 0)
		ring.global_scale = Vector2.ONE
		ring.visible = false
	return ring

func _hide_rings() -> void:
	for r in _active_rings:
		if is_instance_valid(r):
			r.call("hide_ring")
	_active_rings.clear()

func _actor_hit_rect(actor: BattleActor) -> Rect2:
	var rect := Rect2(actor.global_position + Vector2(-110, -260), Vector2(220, 300))
	var sprite := actor.sprite
	if sprite != null and sprite.texture != null:
		rect = sprite.get_global_transform() * sprite.get_rect()
	return rect.grow(20.0)

## Живой юнит под курсором среди актёров (если несколько — ближайший к центру).
func _unit_at(actors: Array[BattleActor], point: Vector2) -> Unit:
	var best: Unit = null
	var best_dist := INF
	for actor in actors:
		if actor == null or actor.unit == null or actor.unit.is_dead:
			continue
		var rect := _actor_hit_rect(actor)
		if not rect.has_point(point):
			continue
		var d := rect.get_center().distance_to(point)
		if d < best_dist:
			best_dist = d
			best = actor.unit
	return best

func _finish_drag() -> void:
	var v := _dragging
	if v == null:
		return
	_dragging = null
	set_process(false)
	_drag_portrait.hide_portrait()
	_hide_highlights()
	_sleeve.set_hover(false)
	v.end_drag()

	var point := _mouse_pos()
	if CardSleeve.in_zone(point):
		_put_in_sleeve(v)
		return
	var targets := _drop_targets(v.card, point)
	if targets.is_empty():
		v.move_to(v.home_position)   # не разыграна — обратно в руку
		return
	if _combat.effective_cost(v.card) > _energy:
		CardActorFx.spawn_float_text(hud, v.global_position + Vector2(-10, -40), "Не хватает энергии", CardCombat.COL_DAMAGE, 22)
		v.move_to(v.home_position)
		return
	_play_card(v, targets)

# --- Рукав -------------------------------------------------------------------

func _on_sleeve_card_clicked(card: CardInstance) -> void:
	if not _can_act():
		return
	_take_from_sleeve(card)

func _take_from_sleeve(c: CardInstance) -> void:
	if not _sleeve.take(c):
		return
	_deck.hand.append(c)
	var nv := _add_card_view(c)
	nv.position = _sleeve.card_origin()
	_layout_hand(true)
	_refresh_energy()

## Положить карту из руки в рукав (бесплатно). Рукав занят — карта из рукава меняется местами.
func _put_in_sleeve(v: CardView) -> void:
	var idx := _deck.hand.find(v.card)
	if idx == -1:
		v.move_to(v.home_position)
		return
	if _sleeve.is_full() and not _sleeve.cards.is_empty():
		_take_from_sleeve(_sleeve.cards[0])
	_deck.hand.erase(v.card)
	_sleeve.put(v.card)
	_hand_views.erase(v)
	v.queue_free()
	_layout_hand(true)
	_refresh_energy()

# --- Розыгрыш карты ----------------------------------------------------------

func _consume_card(v: CardView) -> void:
	_energy = maxi(0, _energy - _combat.effective_cost(v.card))
	_deck.play_card(v.card)
	if v.card.exhaust_scope == CardDef.Exhaust.RUN:
		_run.burned_for_run.append(v.card.id)
		refresh_run_hud()
	_hand_views.erase(v)
	_refresh_pile_buttons()
	if v.card.exhaust:
		v.burn_and_free()
	else:
		v.play_and_free()
	_layout_hand(true)
	_refresh_energy()

func _play_card(v: CardView, targets: Array[Unit]) -> void:
	var card := v.card
	var caster := _combat.hero_by_id(card.owner_id)
	_float_stack.clear()
	_consume_card(v)
	_combat.play_card(card, caster, targets)
	_ults.gain(card.owner_id)
	CardActorFx.hop(_find_actor(caster))
	if card.owner_id != "":
		BattleBanter_.trigger("ability_cast" if card.cost >= 2 else "basic_attack", {"speaker_id": card.owner_id})
	_refresh_all_actors()
	_check_end()

## Добыча с врага — как в автобаттлере: золото и опыт растут с комнатой,
## слизь со слаймов, 10% на кварц. Выдаётся сразу, окно после боя лишь подводит итог.
func _on_enemy_killed(enemy: Unit) -> void:
	var gold_gain := LOOT_GOLD_BASE + _room_index
	var xp_gain := LOOT_XP_BASE + _room_index * LOOT_XP_PER_ROOM
	DungRun.gain_gold(gold_gain)
	DungRun.gain_xp(xp_gain)
	_room_loot["gold"] = int(_room_loot.get("gold", 0)) + gold_gain
	_room_loot["xp"] = int(_room_loot.get("xp", 0)) + xp_gain
	if enemy.data != null and String(enemy.data.id) == "base_slime":
		_add_loot_item("slime_goop", 1)
	if _run.rng.randf() < LOOT_QUARTZ_CHANCE:
		_add_loot_item("quartz", 1)
	refresh_run_hud()

func _add_loot_item(item_id: String, amount: int) -> void:
	Inventory_.add_item(item_id, amount)
	var items: Dictionary = _room_loot["items"]
	items[item_id] = int(items.get(item_id, 0)) + amount

## Герой выбыл — его карты выходят из боя.
func _purge_cards_of(unit: Unit) -> void:
	var id := unit.data.id
	_deck.remove_owner_cards(id)
	_sleeve.remove_owner(id)
	for v in _hand_views.duplicate():
		if v.card.owner_id == id:
			_hand_views.erase(v)
			v.fly_to_and_free(_discard_pos())
	_layout_hand(true)
	_refresh_pile_buttons()
	_refresh_energy()

# --- Ход врагов --------------------------------------------------------------

func _on_end_turn_pressed() -> void:
	if not _can_act():
		return
	_busy = true

	# 1. Рука уходит в сброс (эстус в том числе — сгорает только сыгранный).
	_clear_hand_views()
	_combat.end_player_turn()
	_refresh_all_actors()
	await _wait(0.3)

	# 2. Статусы начала хода врагов (Горение жжёт до их ударов).
	_float_stack.clear()
	if _combat.enemy_turn_start():
		_refresh_all_actors()
		await _wait(0.5)
		if _check_end():
			return

	# 3. Каждый живой враг бьёт переднего героя (если не оглушён).
	for enemy in _combat.alive_enemies():
		_float_stack.clear()
		if _combat.skips_turn(enemy):
			await _wait(0.35)
			continue
		var target := _combat.front_hero()
		if target == null:
			break
		if _combat.is_charmed(enemy):
			# Очарованный враг бьёт ближайшего союзника (следующего живого врага).
			target = _combat.charm_victim(enemy)
			if target == null:
				await _wait(0.35)
				continue
		var enemy_actor := _find_actor(enemy)
		if enemy_actor != null:
			enemy_actor.play_attack_bounce(-1)
		_combat.enemy_attack(enemy, target)
		await _wait(0.45)
		if _check_end():
			return

	# 4. Конец раунда: длительные статусы теряют ход.
	_combat.end_round()

	# 5. Щиты сгорают, новый ход: энергия, новые намерения, новая рука.
	if SHIELD_EXPIRES_ON_NEW_TURN:
		_combat.clear_shields()
	await _begin_player_turn()

# --- Окончание боя -----------------------------------------------------------

## Нет живых слева/справа -> поражение/победа/ничья.
## Возвращает true, если дальше ход продолжать нельзя (переход в комнату или конец боя).
func _check_end() -> bool:
	if _ended:
		return true
	var left_alive := _combat.front_hero() != null
	var right_alive := _combat.front_enemy() != null
	if left_alive and right_alive:
		return false

	# Комната зачищена, но это не босс — награда, выбор пути, дальше.
	if left_alive and String(_run.room(_room_index).get("kind", "")) != "boss":
		_busy = true
		_on_room_cleared()
		return true

	var is_draw := not left_alive and not right_alive
	_finish_run(left_alive and not is_draw, is_draw)
	return true

func _finish_run(victory: bool, is_draw: bool) -> void:
	_ended = true
	_busy = true
	_end_victory = victory
	_refresh_all_actors()
	_show_end_overlay(victory, is_draw)

func _show_end_overlay(victory: bool, is_draw: bool) -> void:
	end_overlay.visible = true
	if is_draw:
		end_text.text = "Ничья"
		end_image.texture = null
		end_button.text = "Продолжить"
		return
	if victory:
		end_text.text = "УФФ ПОЛЕГЧЕ, КОВБОЙ <3"
		end_image.texture = VICTORY_TEXTURE
	else:
		end_text.text = "ЧЁ ЗА ТЕНТАКЛИ КАКОЙ ХЕНТАЙ"
		end_image.texture = DEFEAT_TEXTURE
	end_button.text = "КОНЧИТЬ"

func _on_end_button_pressed() -> void:
	if not _ended:
		return
	FarmState_.advance_day()
	DungRun.on_run_finished_refresh_shops()
	SceneRouter_.go_to_hub()

func _on_exit_pressed() -> void:
	if _banter != null:
		_banter.stop()
	SceneRouter_.go_to_setup()

# --- Ультимейты --------------------------------------------------------------

func _on_ult_pressed(btn: UltButton) -> void:
	if not _can_act():
		return
	var hero := btn.unit
	if hero == null or hero.is_dead or not btn.is_ready():
		return
	var ult := _ults.ult_of(hero.data.id)
	if ult == null:
		return
	var targets: Array[Unit] = []
	match ult.target:
		CardInstance.Target.ALL_ENEMIES:
			targets.assign(_combat.alive_enemies())
		CardInstance.Target.SELF:
			targets.append(hero)
		_:
			var front := _combat.front_enemy()
			if front != null:
				targets.append(front)
	if targets.is_empty():
		return

	_ults.spend(hero.data.id)
	_float_stack.clear()
	CardActorFx.show_banner(hud, "%s — %s" % [hero.data.display_name, ult.title], ult.color.lightened(0.45))
	CardActorFx.hop(_find_actor(hero), ULT_HOP_HEIGHT)
	BattleBanter_.trigger("ability_cast", {"speaker_id": hero.data.id})
	_combat.play_card(ult, hero, targets)
	_refresh_all_actors()
	_check_end()

# --- Забег: HUD, лагерь между комнатами, награды ----------------------------

func _build_run_hud() -> void:
	_gold_label = Label.new()
	_gold_label.position = Vector2(24, 22)
	_gold_label.size = Vector2(520, 36)
	_gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_label.add_theme_font_size_override("font_size", 26)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_gold_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(_gold_label)

	# Постоянный счётчик прогресса забега сверху по центру.
	_progress = RunProgress.new()
	_progress.position = Vector2(0, 14)
	_progress.size = Vector2(1920, 30)
	hud.add_child(_progress)

func refresh_run_hud() -> void:
	if _gold_label == null:
		return
	if _progress != null:
		_progress.setup(_run.total_rooms(), _room_index)
	var text := "Золото: %d   Эстус: %d/%d" % [DungRun.gold, maxi(0, DungRun.estus_stacks - _run.burned_count("estus")), DungRun.estus_stacks]
	if _run.white_charges > 0:
		text += "   Белая статуя: %d" % _run.white_charges
	if _run.black_charges > 0:
		text += "   Чёрная статуя: %d" % _run.black_charges
	_gold_label.text = text

func _setup_banter() -> void:
	_banter = CardBanter.new()
	add_child(_banter)
	_banter.speech_layer = get_node_or_null("%BattleSpeechLayer") as BattleSpeechLayer
	_banter.actor_for_hero = func(hero_id: String) -> Variant:
		var u := _combat.hero_by_id(hero_id)
		if not CardCombat.is_alive(u):
			return null
		return _find_actor(u)
	_banter.alive_hero_ids = func() -> Array[String]:
		return run_alive_ids()

## Показывает/прячет всё боевое: рука, энергия, колода, ульты, рукав. В лагере остаются только герои и окна.
func _set_battle_ui(on: bool) -> void:
	for c in [hand_layer, end_turn_button, energy_label, deck_button, discard_button, _ults, _sleeve]:
		c.visible = on

## Лагерь: враги убраны, герои стоят и болтают.
func _enter_camp() -> void:
	_busy = true
	_set_battle_ui(false)
	for slot in _right_world_slots:
		if slot != null:
			_clear_slot(slot)
	for u in right_team:
		_actor_of.erase(u)
	right_actors.clear()
	right_team.clear()
	_combat.intents.clear()
	_refresh_all_actors()

func _ui_add(node: Control) -> void:
	_ui_layer.add_child(node)

func _on_room_cleared() -> void:
	await _wait(0.8)
	_clear_hand_views()
	_float_stack.clear()
	if _run.white_charges > 0:
		_run.white_charges -= 1
		for u in left_team:
			if CardCombat.is_alive(u):
				_combat.heal(u, ceili(float(u.max_hp) * WHITE_STATUE_HEAL_PERCENT))
	if _run.black_charges > 0:
		_run.black_charges -= 1
	_refresh_all_actors()
	refresh_run_hud()
	await _wait(0.4)
	_enter_camp()
	await _show_loot()
	await _choose_path_and_go()

func _show_loot() -> void:
	var popup := LootPopup.new()
	_ui_add(popup)
	popup.setup(_room_loot)
	_banter.play_camp()
	await popup.closed
	await _wait(0.3)

func _choose_path_and_go() -> void:
	_run.prepare_choices()
	if _run.pending_choices.is_empty():
		if UnitRoster_ != null:
			UnitRoster_.unlock_boss_once(CardRun.BOSS_ID)
		_finish_run(true, false)
		return
	var popup := PathPopup.new()
	_ui_add(popup)
	popup.setup(_run)
	_banter.play_camp()
	var choice: int = await popup.chosen
	popup.queue_free()
	_banter.stop()
	_run.choose(choice)
	await _start_room(_run.index)

func _start_event_room(room: Dictionary) -> void:
	right_team.clear()
	_populate_world_slots()
	_enter_camp()
	var screen := EventScreen.new()
	_ui_add(screen)
	screen.setup(self, room)   ## полноэкранная комната с диалогом NPC — реплики отряда тут не нужны
	await screen.finished
	screen.queue_free()
	_banter.stop()
	await _choose_path_and_go()

# --- API для окон забега (EventScreen вызывает по имени) ---------------------

func get_run() -> CardRun:
	return _run

func run_gold() -> int:
	return DungRun.gold

func run_gain_gold(amount: int) -> void:
	DungRun.gain_gold(amount)
	refresh_run_hud()

func run_spend_gold(amount: int) -> bool:
	var ok := DungRun.spend_gold(amount)
	refresh_run_hud()
	return ok

func run_alive_ids() -> Array[String]:
	var out: Array[String] = []
	for u in left_team:
		if u != null and not u.is_dead:
			out.append(u.data.id)
	return out

func run_has_wounded() -> bool:
	for u in left_team:
		if u != null and not u.is_dead and u.hp < u.max_hp:
			return true
	return false

func run_has_dead() -> bool:
	for u in left_team:
		if u != null and u.is_dead:
			return true
	return false

func run_heal_all_flat(amount: int) -> void:
	_float_stack.clear()
	for u in left_team:
		if u != null and not u.is_dead:
			_combat.heal(u, amount)
	_refresh_all_actors()

func run_heal_all_percent(percent: float) -> void:
	_float_stack.clear()
	for u in left_team:
		if u != null and not u.is_dead:
			_combat.heal(u, ceili(float(u.max_hp) * percent))
	_refresh_all_actors()

## Воскрешает первого павшего героя. Возвращает его имя («» — никого).
func run_revive_one(percent: float) -> String:
	for u in left_team:
		if u != null and u.is_dead:
			u.is_dead = false
			u.hp = maxi(1, int(float(u.max_hp) * percent))
			_refresh_all_actors()
			CardActorFx.start_idle(_find_actor(u))
			return u.data.display_name
	return ""

func run_add_card(card_id: String) -> void:
	_run.bonus_cards.append(card_id)

func run_take_statue(variant: String) -> void:
	if variant == "white":
		_run.white_charges += CardRun.STATUE_CHARGES
	else:
		_run.black_charges += CardRun.STATUE_CHARGES
	refresh_run_hud()

## Награда сундука: золото + случайная добавка. Возвращает текст для окна.
func run_roll_chest(_room: Dictionary) -> String:
	var gold_amount := CHEST_GOLD_BASE + _room_index * CHEST_GOLD_PER_ROOM
	run_gain_gold(gold_amount)
	var lines: Array[String] = ["В сундуке было %d золота." % gold_amount]
	if StoryState_ != null and StoryState_.is_quest_active("lamia_headphones") and not Inventory_.has_item("warm_headphones"):
		if _run.rng.randf() < 0.18:
			Inventory_.add_item("warm_headphones", 1)
			lines.append("Между монетами лежали тёплые наушники.")
	# Как в старом сундуке: 80% — доп. лут. Семена теперь берутся отсюда (на боссе будут уникальные).
	# TODO: «случайный предмет/артефакт» (25% доп. лута в старом сундуке) — когда дойдём до артефактов.
	if _run.rng.randf() < 0.80:
		if _run.rng.randf() < 0.45:
			var q := _run.rng.randi_range(1, 3)
			Inventory_.add_item("quartz", q)
			lines.append("Доп. лут: кварц ×%d." % q)
		else:
			var seed_id := "slimeflower_seed" if _run.rng.randf() < 0.6 else "witchflower_seed"
			var n := _run.rng.randi_range(1, 3)
			Inventory_.add_item(seed_id, n)
			lines.append("Доп. лут: %s ×%d." % [RunItems.get_item_name(seed_id), n])
	return "\n".join(lines)
