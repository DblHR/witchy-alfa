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
##   CardUltSplash  — заставка ульты по центру экрана
##   CardRun        — генерация и состояние забега; окна забега — *Popup / EventScreen
##   enemies/       — враги: EnemyDef (ходы, фазы), EnemyMove, EnemyApi; реестр EnemyDefs
##   CardBalance    — общие числа: рост от уровня, опыт, доверие, общие карты
##
## Из общего состояния читается отряд из Setup (DungRun.party_ids / party_level /
## party_slot_count).
## Опыт и доверие копятся за забег и начисляются только в конце (победа или поражение);
## выход из забега кнопкой «Выйти» их не даёт.
## Конец забега: FarmState_.advance_day() -> DungRun.on_run_finished_refresh_shops() -> хаб.
## BattleActor используется как «тупой» виджет (читает только Unit/CharacterData).

const BATTLE_ACTOR_SCENE: PackedScene = preload("res://scenes/BattleActor.tscn")
const VICTORY_TEXTURE: Texture2D = preload("res://assets/pics/bigPics/endscreen/victory.png")
const DEFEAT_TEXTURE: Texture2D = preload("res://assets/pics/bigPics/endscreen/defeat.png")
const _TargetRing := preload("res://scripts/card/TargetRing.gd")
const _TargetMark := preload("res://scripts/card/TargetMark.gd")

# --- Правила прототипа (все числа тестовые) ----------------------------------
const ENERGY_PER_TURN := 3
const HAND_SIZE := 5
## Щит держится до начала следующего хода игрока (после удара врагов).
const SHIELD_EXPIRES_ON_NEW_TURN := true

## Добыча и дары забега (тестовые).
const LOOT_GOLD_BASE := 4         ## золото с врага = 4 + номер комнаты (как в автобаттлере)
const LOOT_QUARTZ_CHANCE := 0.10  ## шанс кварца с каждого врага
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
## Слотов врагов: 4 в сцене + 5-й для призывов босса.
const ENEMY_SLOTS := 5
const EXTRA_ENEMY_SLOT_POS := Vector2(1790, 700)
## В бою с боссом враги раздвигаются: босс крупный, а к нему приходят призванные.
const BOSS_SLOT_POS: Array[Vector2] = [Vector2(1060, 715), Vector2(1335, 640), Vector2(1490, 728), Vector2(1650, 632), Vector2(1800, 722)]


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
var _right_slot_default: Array[Vector2] = []

var _combat := CardCombat.new()
## Через него враги действуют (EnemyDef/EnemyMove): правила + призыв/исчезновение на сцене.
var _api: EnemyApi
## Посох и еда забега (DungRun.relics): хуки боя.
var _relics: CardRelics
## Номер хода в текущем бою (1 — первый): бонусы Данго/Желе/статуй.
var _turn_no := 0
## Статистика забега для итогового окна (CardRunStats).
var _stats := CardRunStats.new()
## Итоговая статистика скрыта (видно картинку победы/поражения).
var _stats_hidden := true
var _stats_panel: PanelContainer
var _stats_toggle: Button
## Пойманные приманкой за этот забег — строки для итога.
var _captured_lines: PackedStringArray = []
## Слоты зелий на этот забег (id зелий; «» — пусто или уже выпито). Берутся из DungRun.selected_potion_ids.
var _potions: Array[String] = []
## Баффы забега (под золотом) и слоты зелий (внизу слева, над колодой).
var _buff_bar: CardBuffBar
var _potion_bar: CardBuffBar
const POTION_BAR_POS := Vector2(24, 890)
## Зелья забега: сила (числа — тут, описание — RunItems.POTION_DEFS).
const POTION_HEAL := 0.40
const POTION_ENERGY := 2
var _deck := CardDeck.new()
var _sleeve: CardSleeve
var _ults: CardUltBar
var _pile_popup: CardPilePopup
var _admin: CardBattleAdmin
## Админ: следующий клик по юниту убивает его.
var _admin_kill_mode := false
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
## Сколько карт игрок ещё должен сбросить из руки (эффект «сбросьте карту»). Пока > 0 —
## клик по карте в руке сбрасывает её, остальные действия недоступны.
var _discard_left := 0
var _discard_prompt: Label
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
	_combat.discard_requested.connect(_on_discard_requested)
	_combat.status_added.connect(_on_status_added)
	_combat.lure_kill.connect(_on_lure_kill)

	_run = CardRun.new()
	_api = EnemyApi.new(_combat, self, _run.rng)
	DungRun.begin_card_run()
	_relics = CardRelics.new(DungRun.relics, _run.rng)
	_combat.relics = _relics
	_combat.stats = _stats
	_stats.gold_start = DungRun.gold
	_potions.assign(DungRun.selected_potion_ids)
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

	_admin = CardBattleAdmin.new()
	hud.add_child(_admin)
	_admin.setup(self)

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
	for id in room.get("enemies", []):
		var def := EnemyDefs.get_def(String(id))
		if def == null:
			push_warning("CardBattle: враг не найден в EnemyDefs: %s" % id)
			continue
		right_team.append(def.make_unit(_run.floor_no, _run.rng))
		if right_team.size() >= ENEMY_SLOTS:
			break

# --- Расстановка на сцене ----------------------------------------------------

func _cache_world_slots() -> void:
	_left_world_slots.clear()
	_right_world_slots.clear()
	for i in [3, 2, 1, 0]:
		_left_world_slots.append(left_world.get_node_or_null("LeftSlot%d" % i) as Node2D)
	for i in range(4):
		_right_world_slots.append(right_world.get_node_or_null("RightSlot%d" % i) as Node2D)
	# 5-й слот — для призывов (Фуфу зовёт слизней, а потом Аки с Луисой).
	while _right_world_slots.size() < ENEMY_SLOTS:
		var extra := Node2D.new()
		extra.name = "RightSlot%d" % _right_world_slots.size()
		extra.position = EXTRA_ENEMY_SLOT_POS
		extra.visible = false
		right_world.add_child(extra)
		_right_world_slots.append(extra)
	_right_slot_default.clear()
	for slot in _right_world_slots:
		_right_slot_default.append(slot.position if slot != null else Vector2.ZERO)

## Раскладка слотов врагов: обычная или раздвинутая для босса.
func _layout_enemy_slots(boss: bool) -> void:
	for i in range(_right_world_slots.size()):
		var slot := _right_world_slots[i]
		if slot != null:
			slot.position = BOSS_SLOT_POS[i] if boss and i < BOSS_SLOT_POS.size() else _right_slot_default[i]

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
		actor.is_boss = unit.enemy_def != null and unit.enemy_def.is_boss()
	actor.bind(unit, is_left)
	if not is_left:
		CardActorFx.fit_bars_to_sprite(actor)
		var name_l := CardActorFx.name_label(actor)
		name_l.text = unit.data.display_name
		name_l.visible = true
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
			var move: EnemyMove = _combat.intents[unit]
			if _combat.skips_turn(unit):
				intent_label.text = "Оглушён"
				intent_label.add_theme_color_override("font_color", CardCombat.COL_STATUS)
			elif _combat.is_charmed(unit):
				intent_label.text = ("Бьёт своих: %d" % _api.shown_damage(unit, move)) if move.damage > 0 else "Очарован"
				intent_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.85))
			else:
				intent_label.text = move.intent_text(_api.shown_damage(unit, move))
				var col := move.intent_color()
				if move.damage > 0 and _api.shown_damage(unit, move) < EnemyApi.scaled(unit, move.damage):
					col = CardCombat.COL_SHIELD   # ослаблен — удар меньше обычного
				intent_label.add_theme_color_override("font_color", col)

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
	if actor != null:
		if hp_damage > 0:
			actor.flash_red()
		_refresh_actor(actor)
	if hp_damage > 0 and unit.enemy_def != null and right_team.has(unit):
		unit.enemy_def.on_hurt(_api, unit, hp_damage)
	if hp_damage > 0 and left_team.has(unit):
		_relics.on_hero_hurt(_combat, unit)

func _on_unit_died(unit: Unit) -> void:
	if left_team.has(unit):
		_stats.on_hero_died(unit.data.id)
		_purge_cards_of(unit)
	elif right_team.has(unit):
		_combat.intents.erase(unit)
		_on_enemy_killed(unit)
		if unit.enemy_def != null:
			unit.enemy_def.on_death(_api, unit)

func _on_status_added(unit: Unit, id: String) -> void:
	if unit.enemy_def != null and right_team.has(unit) and CardCombat.is_alive(unit):
		unit.enemy_def.on_status(_api, unit, id)

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
	_float_stack.clear()
	refresh_run_hud()

	if String(room.get("kind", "")) == "event":
		await _start_event_room(room)
		return
	if String(room.get("kind", "")) == "quest":
		await _play_quest_intro(room)
		_quest_add_hero("warrior")

	_set_battle_ui(true)
	_room_loot = {"gold": 0, "xp": 0, "items": {}}
	_spawn_enemies(room)
	_layout_enemy_slots(bool(room.get("boss", false)))
	_populate_world_slots()
	_ults.refresh()

	_sleeve.clear()
	_deck.start_battle(_build_battle_deck())
	_refresh_pile_buttons()
	_relics.on_battle_start(_combat, _run.white_charges > 0, _run.black_charges > 0)
	_turn_no = 0

	BattleBanter_.start_battle(self)
	BattleBanter_.trigger("battle_start")
	await _begin_player_turn()

## Колода на бой: карты живых героев (выбранные в Setup), общие карты и добытые карты.
func _build_battle_deck() -> Array[CardInstance]:
	var cards := CardLibrary.base_deck(left_team)
	for card_id in _run.bonus_cards:
		var owner_id := CardLibrary.owner_of(card_id)
		var owner := _combat.hero_by_id(owner_id)
		if owner_id != "" and not CardCombat.is_alive(owner):
			continue
		var bonus := CardLibrary.card_by_id(card_id, owner)
		if bonus != null:
			cards.append(bonus)
	# Приманка: одна на забег, пока не разыграна (потом сгорает до конца забега).
	if DungRun.take_lure and Inventory_.has_item(DungRun.LURE_ITEM):
		cards.append(CardLibrary.lure_card())
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
	_stats.turns += 1
	_energy = ENERGY_PER_TURN
	_turn_no += 1
	_energy += int(_relics.turn_bonus(_turn_no).get("energy", 0))
	_combat.enemy_phase = false
	_combat.begin_player_turn()
	_combat.roll_intents(_api)
	_refresh_all_actors()
	await _deal_new_hand()

func _clear_hand_views() -> void:
	_set_discard_left(0)
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
		v.set_affordable(cost <= _energy and not _card_blocked(v.card))

func _deal_new_hand() -> void:
	_busy = true
	# Карты из рукава возвращаются в руку первыми, добирается на столько же меньше.
	var from_sleeve := _sleeve.take_all()
	_deck.hand.append_array(from_sleeve)
	var extra := int(_relics.turn_bonus_cache.get("cards", 0))
	_relics.turn_bonus_cache["cards"] = 0
	var drawn := _deck.draw(maxi(0, HAND_SIZE + extra - from_sleeve.size()))
	_refresh_pile_buttons()
	for c in from_sleeve + drawn:
		_add_card_view(c)
	_layout_hand(true)
	_refresh_energy()
	await _wait(0.3)
	await _auto_play_charmed()
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
	if _discard_left > 0:
		return false
	return not _busy and not _ended and _dragging == null

func _on_card_pressed(v: CardView) -> void:
	if _discard_left > 0 and not _busy and not _ended:
		_discard_from_hand(v)
		return
	if not _can_act():
		return
	_dragging = v
	_drag_grab_offset = _mouse_pos() - v.global_position
	v.begin_drag()
	hand_layer.move_child(v, -1)
	var owner := _combat.hero_by_id(v.card.owner_id)
	if owner != null:
		_drag_portrait.show_for(owner.data)
	set_process(true)
	_update_drag_feedback()

## Позиция мыши: берём из последнего события (get_mouse_position не обновляется синтетическим вводом).
func _mouse_pos() -> Vector2:
	return _last_mouse if _has_last_mouse else get_viewport().get_mouse_position()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_mouse = (event as InputEventMouse).position
		_has_last_mouse = true
	if _admin_kill_mode and event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_LEFT:
			var u := _unit_at(right_actors, _mouse_pos())
			if u == null:
				u = _unit_at(left_actors, _mouse_pos())
			if u != null:
				admin_kill(u)
		admin_set_kill_mode(false)
		return
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
	_drag_portrait.update_hover(point)
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
	if _card_blocked(v.card):
		var owner := _combat.hero_by_id(v.card.owner_id)
		var why := "Проглочена" if _combat.has_status(owner, CardStatuses.SWALLOWED) else "Оглушена"
		CardActorFx.spawn_float_text(hud, v.global_position + Vector2(-10, -40), "%s — не может действовать" % why, CardCombat.COL_STATUS, 22)
		v.move_to(v.home_position)
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
	_stats.cards_sleeved += 1
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
		_stats.cards_burned += 1
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
	_stats.on_card_played(card, false)
	if card.id == "lure":
		Inventory_.remove_item(DungRun.LURE_ITEM, 1)
	_relics.before_card(card)
	_combat.play_card(card, caster, targets)
	_relics.after_card(_combat, card)
	_ults.gain(card.owner_id)
	CardActorFx.hop(_find_actor(caster))
	if card.owner_id != "":
		BattleBanter_.trigger("ability_cast" if card.cost >= 2 else "basic_attack", {"speaker_id": card.owner_id})
	_refresh_all_actors()
	_check_end()

## Добыча с врага: золото растёт с комнатой, опыт — от ранга врага и этажа, слизь со слизней,
## 10% на кварц. Золото и предметы выдаются сразу; опыт копится в забеге (_run.xp_gained)
## и начисляется в конце забега.
func _on_enemy_killed(enemy: Unit) -> void:
	var gold_gain := LOOT_GOLD_BASE + _room_index
	var rank := enemy.enemy_def.rank if enemy.enemy_def != null else "B"
	_stats.on_enemy_killed(enemy.enemy_def.id if enemy.enemy_def != null else enemy.data.id)
	var xp_gain := CardBalance.xp_for_kill(rank, _run.floor_no)
	DungRun.gain_gold(gold_gain)
	_run.xp_gained += xp_gain
	_room_loot["gold"] = int(_room_loot.get("gold", 0)) + gold_gain
	_room_loot["xp"] = int(_room_loot.get("xp", 0)) + xp_gain
	if enemy.enemy_def != null and enemy.enemy_def.drops_goop:
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

	# 1. Рука уходит в сброс.
	_stats.cards_discarded_turn += _hand_views.size()
	_clear_hand_views()
	_combat.end_player_turn()
	_relics.on_turn_end()
	_refresh_all_actors()
	refresh_run_hud()
	await _wait(0.3)

	# 2. Щиты врагов сгорают (держались весь ход игрока); статусы начала хода врагов
	#    (Горение жжёт до их ударов).
	_combat.enemy_phase = true
	_float_stack.clear()
	if SHIELD_EXPIRES_ON_NEW_TURN:
		_combat.clear_side_shields(true)
		_refresh_all_actors()
	if _combat.enemy_turn_start():
		_refresh_all_actors()
		await _wait(0.5)
		if _check_end():
			return

	# 3. Враги выполняют свои намерения (кто с приоритетом — раньше: кислотный снимает щиты
	#    до ударов остальных). Призванные в этот ход ходят со следующего.
	for enemy in _enemy_turn_order():
		if not CardCombat.is_alive(enemy):
			continue
		var move: EnemyMove = _combat.intents.get(enemy)
		if move == null:
			continue
		_float_stack.clear()
		if _combat.skips_turn(enemy):
			await _wait(0.35)
			continue
		var enemy_actor := _find_actor(enemy)
		if _combat.is_charmed(enemy):
			# Очарованный враг бьёт ближайшего союзника (следующего живого врага), если ход — удар.
			var victim := _combat.charm_victim(enemy)
			if victim == null or move.damage <= 0:
				await _wait(0.35)
				continue
			if enemy_actor != null:
				enemy_actor.play_attack_bounce(-1)
			for i in range(maxi(1, move.hits)):
				_combat.deal_damage(enemy, victim, EnemyApi.scaled(enemy, move.damage), false)
		else:
			if enemy_actor != null:
				enemy_actor.play_attack_bounce(-1)
			enemy.enemy_def.act(_api, enemy, move)
		_refresh_all_actors()
		await _wait(0.5)
		if _check_end():
			return

	# 4. Конец раунда: длительные статусы теряют ход.
	_combat.end_round()

	# 5. Щиты героинь сгорают, новый ход: энергия, новые намерения, новая рука.
	if SHIELD_EXPIRES_ON_NEW_TURN:
		_combat.clear_side_shields(false)
	await _begin_player_turn()

# --- Окончание боя -----------------------------------------------------------

## Порядок хода врагов: сначала ходы с приоритетом, дальше — по строю.
func _enemy_turn_order() -> Array[Unit]:
	var rows: Array = []
	var alive := _combat.alive_enemies()
	for i in range(alive.size()):
		var move: EnemyMove = _combat.intents.get(alive[i])
		rows.append([-(move.priority if move != null else 0), i, alive[i]])
	rows.sort()
	var out: Array[Unit] = []
	for r in rows:
		out.append(r[2])
	return out

## Нет живых слева/справа -> поражение/победа/ничья.
## Возвращает true, если дальше ход продолжать нельзя (переход в комнату или конец боя).
func _check_end() -> bool:
	if _ended:
		return true
	var left_alive := not _combat.alive_heroes().is_empty()
	var right_alive := _combat.front_enemy() != null
	if left_alive and right_alive:
		return false

	# Квестовый бой (Фуфу и воин): квест засчитан при любом исходе.
	if String(_run.room(_room_index).get("kind", "")) == "quest":
		_finish_quest_room(_run.room(_room_index))

	# Комната зачищена, но это не босс — награда, выбор пути, дальше.
	if left_alive and String(_run.room(_room_index).get("kind", "")) != "boss":
		_busy = true
		_on_room_cleared()
		return true

	var is_draw := not left_alive and not right_alive
	_finish_run(left_alive and not is_draw, is_draw)
	return true

# --- Админ-панель (CardBattleAdmin) ----------------------------------------

func admin_can_act() -> bool:
	return not _ended and not _busy

func admin_heal(heroes: bool) -> void:
	if _ended:
		return
	_float_stack.clear()
	for u in (left_team if heroes else right_team):
		if CardCombat.is_alive(u):
			_combat.heal(u, u.max_hp - u.hp)
	_refresh_all_actors()

func admin_set_kill_mode(on: bool) -> void:
	_admin_kill_mode = on and admin_can_act()
	_admin.show_kill_mode(_admin_kill_mode)

## Мгновенно убить юнита (щит не спасает). Добыча и выбывание карт — как при обычной смерти.
func admin_kill(u: Unit, check_end: bool = true) -> void:
	if not CardCombat.is_alive(u) or not admin_can_act():
		return
	_float_stack.clear()
	_combat.remove_shield(u)
	_combat.apply_damage(u, u.hp)
	_refresh_all_actors()
	if check_end:
		_check_end()

func admin_clear_room() -> void:
	if not admin_can_act():
		return
	for e in _combat.alive_enemies():
		admin_kill(e, false)
	_check_end()

func admin_lose() -> void:
	if not admin_can_act():
		return
	for h in _combat.alive_heroes():
		admin_kill(h, false)
	_check_end()

func admin_charge_ults() -> void:
	if _ended:
		return
	_ults.charge_all()
	_ults.refresh()

# --- Сброс карты на выбор ----------------------------------------------------

func _on_discard_requested(count: int) -> void:
	_set_discard_left(_discard_left + count)

func _set_discard_left(n: int) -> void:
	_discard_left = mini(n, _hand_views.size()) if n > 0 else 0
	if _discard_prompt == null:
		_discard_prompt = Label.new()
		_discard_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_discard_prompt.position = Vector2(560, 760)
		_discard_prompt.size = Vector2(800, 40)
		_discard_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_discard_prompt.add_theme_font_size_override("font_size", 28)
		_discard_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
		_discard_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		_discard_prompt.add_theme_constant_override("outline_size", 8)
		hud.add_child(_discard_prompt)
	_discard_prompt.visible = _discard_left > 0
	if _discard_left > 0:
		_discard_prompt.text = "Выберите карту для сброса" if _discard_left == 1 else "Выберите карты для сброса: %d" % _discard_left

func _discard_from_hand(v: CardView) -> void:
	if not _deck.discard_card(v.card):
		return
	_hand_views.erase(v)
	_stats.cards_discarded_effect += 1
	v.fly_to_and_free(_discard_pos())
	_layout_hand(true)
	_refresh_pile_buttons()
	_refresh_energy()
	_set_discard_left(_discard_left - 1)

func _finish_run(victory: bool, is_draw: bool) -> void:
	_set_discard_left(0)
	_ended = true
	_busy = true
	_end_victory = victory
	_refresh_all_actors()
	if victory:
		_stats.battles_won += 1
	if victory and String(_run.room(_room_index).get("kind", "")) == "boss" and UnitRoster_ != null:
		UnitRoster_.unlock_boss_once(CardRun.BOSS_ID)
	var level_before := maxi(1, DungRun.party_level)
	var xp_before := int(DungRun.xp)
	var summary := _apply_run_progress()
	for line in _captured_lines:
		summary.append(line)
	_show_end_overlay(victory, is_draw)
	_show_run_summary(summary)
	# Полоска опыта поверх картинки: проявляется, заполняется и гаснет.
	var xp_bar := CardXpBar.new()
	xp_bar.position = Vector2((1920.0 - CardXpBar.PANEL_SIZE.x) * 0.5, 36)
	end_overlay.add_child(xp_bar)
	xp_bar.play(level_before, xp_before, _run.xp_gained, _run.floor_no)

## Конец забега (победа или поражение): опыт отряду и доверие героиням из отряда.
## Возвращает строки итога для экрана конца.
func _apply_run_progress() -> PackedStringArray:
	var lines := PackedStringArray()
	var res: Dictionary = DungRun.apply_run_xp(_run.xp_gained, _run.floor_no)
	var xp_line := "Опыт отряда: +%d" % int(res.get("gained", 0))
	if int(res.get("levels", 0)) > 0:
		xp_line += " — уровень %d!" % int(res.get("level", 1))
	else:
		xp_line += " (уровень %d, %d/%d)" % [int(res.get("level", 1)), DungRun.xp, DungRun.xp_to_next_level()]
	if bool(res.get("capped", false)):
		xp_line += "\nПотолок этажа: уровень %d" % CardBalance.level_cap(_run.floor_no)
	lines.append(xp_line)
	if UnitRoster_ != null:
		for id in DungRun.party_ids:
			var data: CharacterData = CharDB.get_by_id(String(id)) if String(id) != "" else null
			if data == null:
				continue
			var before := UnitRoster_.get_relationship(data.id)
			UnitRoster_.add_trust(data.id, CardBalance.TRUST_PER_RUN)
			var after := UnitRoster_.get_relationship(data.id)
			var t := "%s: доверие +%d" % [data.display_name, CardBalance.TRUST_PER_RUN]
			if after > before:
				t += " — уровень отношений %d!" % after
			lines.append(t)
	return lines

## Итог забега: панель со статистикой (CardRunStats) поверх картинки победы/поражения.
## Сначала панель скрыта; кнопка под «КОНЧИТЬ» показывает/прячет её.
const STATS_RECT := Rect2(60, 190, 1500, 860)
const STATS_TOGGLE_RECT := Rect2(1593, 760, 288, 91)

func _show_run_summary(lines: PackedStringArray) -> void:
	if _stats_panel == null:
		_stats_panel = PanelContainer.new()
		_stats_panel.position = STATS_RECT.position
		_stats_panel.size = STATS_RECT.size
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.07, 0.03, 0.10, 0.86)
		bg.set_corner_radius_all(18)
		bg.set_border_width_all(2)
		bg.border_color = Color(1.0, 0.85, 0.55, 0.35)
		bg.content_margin_left = 24
		bg.content_margin_right = 24
		bg.content_margin_top = 16
		bg.content_margin_bottom = 16
		_stats_panel.add_theme_stylebox_override("panel", bg)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_stats_panel.add_child(scroll)
		var text := RichTextLabel.new()
		text.name = "RunSummary"
		text.bbcode_enabled = true
		text.fit_content = true
		text.scroll_active = false
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("normal_font_size", 20)
		text.add_theme_font_size_override("bold_font_size", 20)
		text.add_theme_color_override("default_color", Color(0.96, 0.93, 1.0))
		text.add_theme_constant_override("table_h_separation", 18)
		scroll.add_child(text)
		end_overlay.add_child(_stats_panel)
		_stats_toggle = Button.new()
		_stats_toggle.position = STATS_TOGGLE_RECT.position
		_stats_toggle.size = STATS_TOGGLE_RECT.size
		_stats_toggle.focus_mode = Control.FOCUS_NONE
		_stats_toggle.add_theme_font_size_override("font_size", 22)
		_stats_toggle.pressed.connect(func() -> void: _set_stats_hidden(not _stats_hidden))
		end_overlay.add_child(_stats_toggle)
	var label := _stats_panel.find_child("RunSummary", true, false) as RichTextLabel
	var rooms := "Комнат пройдено: %d / %d" % [_room_index + (1 if _end_victory else 0), _run.total_rooms()]
	label.text = _stats.to_bbcode(_relics, lines, DungRun.gold, rooms)
	# Сначала — только картинка победы/поражения; статистика по кнопке рядом с «КОНЧИТЬ».
	_set_stats_hidden(true)

func _set_stats_hidden(hidden: bool) -> void:
	_stats_hidden = hidden
	if _stats_panel != null:
		_stats_panel.visible = not hidden
	if _stats_toggle != null:
		_stats_toggle.text = "Показать статистику" if hidden else "Скрыть статистику"
	end_text.visible = not hidden

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

# --- Оглушение и очарование героинь ------------------------------------------

## Карта героини, которая сейчас не может действовать (оглушена или проглочена).
func _card_blocked(card: CardInstance) -> bool:
	if card.owner_id == "":
		return false
	return _combat.hero_disabled(_combat.hero_by_id(card.owner_id))

## Очарованная героиня: при раздаче её карты в руке сами разыгрываются против своих —
## урон по союзницам, щиты и лечение врагам. Энергия не тратится, очарование спадает.
func _auto_play_charmed() -> void:
	for hero in _combat.alive_heroes():
		if not _combat.has_status(hero, CardStatuses.CHARM):
			continue
		var own: Array[CardView] = []
		for v in _hand_views:
			if v.card.owner_id == hero.data.id:
				own.append(v)
		if not own.is_empty():
			_float_stack.clear()
			_float_for(hero, "Очарована!", Color(1.0, 0.55, 0.85), 30)
			await _wait(0.45)
		for v in own:
			if not CardCombat.is_alive(hero) or _ended:
				break
			if not _hand_views.has(v):
				continue
			_float_stack.clear()
			var targets := _mirrored_targets(v.card, hero)
			_hand_views.erase(v)
			_deck.play_card(v.card)
			if v.card.exhaust:
				v.burn_and_free()
			else:
				v.play_and_free()
			_layout_hand(true)
			_refresh_pile_buttons()
			CardActorFx.hop(_find_actor(hero))
			if not targets.is_empty():
				_stats.on_card_played(v.card, false)
				_combat.play_card(v.card, hero, targets, true)
			_refresh_all_actors()
			_refresh_energy()
			await _wait(0.55)
			if _check_end():
				return
		_combat.statuses.get(hero, {}).erase(CardStatuses.CHARM)
		_refresh_all_actors()

## Цели зеркальной карты: «по врагу» -> по союзнице (не по себе, если есть другие),
## «союзнице/себе» -> переднему врагу.
func _mirrored_targets(card: CardInstance, caster: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	var allies := _combat.targetable_heroes()
	match card.target:
		CardInstance.Target.ALL_ENEMIES:
			out = allies
		CardInstance.Target.CHOSEN_ENEMY, CardInstance.Target.FRONT_ENEMY:
			for i in range(allies.size() - 1, -1, -1):
				if allies[i] != caster:
					out.append(allies[i])
					break
			if out.is_empty() and CardCombat.is_alive(caster):
				out.append(caster)
		_:
			var e := _combat.front_enemy()
			if e != null:
				out.append(e)
	return out

# --- Враги: призыв, исчезновение, проглатывание (зовёт EnemyApi) -----------

## Свободный слот врага: слот near (если он уже мёртв), иначе первый слот с мёртвым, иначе новый.
func _free_enemy_slot(near: Unit) -> int:
	var near_idx := right_team.find(near) if near != null else -1
	if near_idx >= 0 and not CardCombat.is_alive(near):
		return near_idx
	for i in range(right_team.size()):
		if not CardCombat.is_alive(right_team[i]) and i != near_idx:
			return i
	if right_team.size() < mini(ENEMY_SLOTS, _right_world_slots.size()):
		return right_team.size()
	return -1

func enemy_summon(ids: Array, hp: int, near: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for id in ids:
		var def := EnemyDefs.get_def(String(id))
		if def == null:
			continue
		var idx := _free_enemy_slot(near)
		if idx < 0:
			break
		var u := def.make_unit(_run.floor_no, _run.rng, hp)
		var slot := _right_world_slots[idx]
		if idx < right_team.size():
			var old := right_team[idx]
			var old_actor := _find_actor(old)
			if old_actor != null:
				right_actors.erase(old_actor)
			_actor_of.erase(old)
			_combat.intents.erase(old)
			right_team[idx] = u
		else:
			right_team.append(u)
		_clear_slot(slot)
		var actor := _spawn_actor(slot, u, false)
		right_actors.append(actor)
		CardActorFx.start_idle(actor)
		actor.scale = Vector2(0.2, 0.2)
		actor.create_tween().tween_property(actor, "scale", Vector2.ONE * (1.35 if actor.is_boss else 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_combat.roll_intent(_api, u)
		_float_for(u, def.title, CardCombat.COL_STATUS, 22)
		out.append(u)
	_refresh_all_actors()
	return out

## Враг исчезает без смерти и добычи (блёба поделилась, призванные ушли вместе с Фуфу).
func enemy_vanish(u: Unit) -> void:
	if u == null or u.is_dead:
		return
	u.is_dead = true
	u.hp = 0
	_combat.statuses.erase(u)
	_combat.remove_shield(u)
	_combat.intents.erase(u)
	var actor := _find_actor(u)
	if actor != null:
		# Актёр больше не обновляется (иначе update_visual снова показал бы его серым).
		right_actors.erase(actor)
		_actor_of.erase(u)
		CardActorFx.stop_idle(actor)
		var t := actor.create_tween()
		t.tween_property(actor, "modulate:a", 0.0, 0.3)
		t.tween_callback(actor.queue_free)

## Проглоченная героиня пропадает со сцены (подписи и HP остаются).
func enemy_set_hero_hidden(hero: Unit, hidden: bool) -> void:
	var actor := _find_actor(hero)
	if actor != null and actor.sprite != null:
		actor.sprite.visible = not hidden
	_refresh_all_actors()

func enemy_reroll(u: Unit) -> void:
	_combat.roll_intent(_api, u)
	_refresh_actor(_find_actor(u))

# --- Ультимейты --------------------------------------------------------------

func _on_ult_pressed(btn: UltButton) -> void:
	if not _can_act():
		return
	var hero := btn.unit
	if hero == null or hero.is_dead or not btn.is_ready():
		return
	if _combat.hero_disabled(hero):
		CardActorFx.spawn_float_text(hud, btn.global_position + Vector2(60, 0), "Не может действовать", CardCombat.COL_STATUS, 22)
		return
	var ult := _ults.ult_of(hero.data.id)
	if ult == null:
		return
	var targets := _ult_targets(ult, hero)
	if targets.is_empty():
		return

	_ults.spend(hero.data.id)
	_refresh_all_actors()
	var splash_tex := CardUltSplash.splash_for(hero.data)
	if splash_tex != null:
		# Заставка: пока она на экране, ход стоит; эффекты ульты — после неё, чтобы были видны цифры.
		_busy = true
		var splash := CardUltSplash.new()
		add_child(splash)
		splash.play(splash_tex)
		await splash.finished
		_busy = false
		# Пока шла заставка, цель могла смениться (например, уже некого бить) — пересчитаем.
		if ult.target != CardInstance.Target.SELF:
			targets = _ult_targets(ult, hero)
	else:
		CardActorFx.show_banner(hud, "%s — %s" % [hero.data.display_name, ult.title], ult.color.lightened(0.45))
	_float_stack.clear()
	CardActorFx.hop(_find_actor(hero), ULT_HOP_HEIGHT)
	BattleBanter_.trigger("ability_cast", {"speaker_id": hero.data.id})
	_stats.on_card_played(ult, true)
	_relics.before_card(ult)
	_combat.play_card(ult, hero, targets)
	_relics.after_card(_combat, ult)
	_refresh_all_actors()
	_check_end()

func _ult_targets(ult: CardInstance, hero: Unit) -> Array[Unit]:
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
	return targets

# --- Забег: HUD, лагерь между комнатами, награды ----------------------------

func _build_run_hud() -> void:
	_gold_label = Label.new()
	_gold_label.position = Vector2(24, 22)
	_gold_label.size = Vector2(900, 36)
	_gold_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gold_label.add_theme_font_size_override("font_size", 26)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
	_gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_gold_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(_gold_label)

	_buff_bar = CardBuffBar.new()
	_buff_bar.position = Vector2(24, 66)
	hud.add_child(_buff_bar)
	_buff_bar.entry_pressed.connect(_on_buff_pressed)
	_potion_bar = CardBuffBar.new()
	_potion_bar.name = "PotionBar"
	_potion_bar.position = POTION_BAR_POS
	_potion_bar.tip_above = true
	hud.add_child(_potion_bar)
	_potion_bar.entry_pressed.connect(_on_buff_pressed)

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
	var text := "Золото: %d" % DungRun.gold
	_gold_label.text = text
	if _buff_bar != null and _relics != null:
		var all := _buff_entries()
		_potion_bar.set_entries(all.filter(func(d: Dictionary) -> bool: return bool(d.get("potion", false))))
		_buff_bar.set_entries(all.filter(func(d: Dictionary) -> bool: return not bool(d.get("potion", false))))

# --- Приманка ----------------------------------------------------------------

## Приманка добила врага. Героиня (у врага есть char_id) попадает в отряд, а если уже есть — копия.
## Фуфу ловится только после первой победы над ней.
func _on_lure_kill(u: Unit) -> void:
	var def := u.enemy_def
	var char_id := def.char_id if def != null else ""
	if char_id == "" or CharDB.get_by_id(char_id) == null:
		_float_for(u, "Слизни не ловятся", CardCombat.COL_STATUS, 26)
		return
	if def.is_boss() and not UnitRoster_.boss_defeated(char_id):
		_float_for(u, "Её пока не поймать…", CardCombat.COL_STATUS, 26)
		return
	var hero_name := (CharDB.get_by_id(char_id) as CharacterData).display_name
	if UnitRoster_.has_unit(char_id):
		UnitRoster_.add_copy(char_id)
		_float_for(u, "Копия: %s!" % hero_name, Color(1.0, 0.6, 0.85), 32)
		_captured_lines.append("Поймана копия: %s (копий: %d)" % [hero_name, UnitRoster_.get_copies(char_id)])
	else:
		UnitRoster_.unlock_unit(char_id)
		_float_for(u, "Поймана: %s!" % hero_name, Color(1.0, 0.6, 0.85), 34)
		_captured_lines.append("Поймана: %s — теперь в отряде!" % hero_name)

# --- Строка зелий и баффов ---------------------------------------------------

func _buff_entries() -> Array:
	var out: Array = []
	for i in range(_potions.size()):
		var pid := _potions[i]
		if pid == "":
			out.append({"key": "potion:%d" % i, "potion": true, "empty": true, "title": "Пустой слот зелья",
				"desc": "Зелья выбираются перед забегом (до двух). Выпитое зелье слот не возвращает."})
			continue
		var item_id := RunItems.get_potion_item_id(pid)
		out.append({"key": "potion:%d" % i, "potion": true, "icon": Inventory_.get_item_icon(item_id),
			"title": RunItems.get_potion_name(pid), "desc": RunItems.get_potion_desc(pid) + "\nНажмите, чтобы выпить (в свой ход)."})
	for id in _relics.items:
		out.append({"key": id, "icon": Inventory_.get_item_icon(id), "title": RunItems.get_item_name(id),
			"desc": RunItems.get_item_desc(id), "stats": _relics.stats_text(id)})
	if _run.white_charges > 0 or _relics.white_active:
		out.append({"key": CardRelics.STATUE_WHITE, "icon": _statue_icon("statue_white"), "badge": str(_run.white_charges),
			"title": "Дар белой статуи", "desc": "Ещё боёв: %d. +1 энергия в первые 2 хода боя, после победы отряд лечится на 10%% макс. HP." % _run.white_charges,
			"stats": _relics.stats_text(CardRelics.STATUE_WHITE)})
	if _run.black_charges > 0 or _relics.black_active:
		out.append({"key": CardRelics.STATUE_BLACK, "icon": _statue_icon("statue_black"), "badge": str(_run.black_charges),
			"title": "Дар чёрной статуи", "desc": "Ещё боёв: %d. +1 карта в первые 2 хода боя, урон карт +20%%." % _run.black_charges,
			"stats": _relics.stats_text(CardRelics.STATUE_BLACK)})
	if _relics.rage_active or _relics.stat(CardRelics.RAGE, "dmg") > 0:
		out.append({"key": CardRelics.RAGE, "icon": Inventory_.get_item_icon("rage_phial"), "badge": "!" if _relics.rage_active else "",
			"title": "Фиал ярости", "desc": "Урон карт +30% до конца хода." if _relics.rage_active else "Выдохся.",
			"stats": _relics.stats_text(CardRelics.RAGE)})
	return out

func _statue_icon(key: String) -> Texture2D:
	return AssetCatalog_.get_event_npc_texture(key) if AssetCatalog_ != null else null

func _on_buff_pressed(key: String) -> void:
	if not key.begins_with("potion:"):
		return
	var slot := int(key.get_slice(":", 1))
	if slot < 0 or slot >= _potions.size() or _potions[slot] == "":
		return
	if not _can_act():
		return
	var pid := _potions[slot]
	_stats.potions.append(pid)
	if not DungRun.drink_potion(pid):
		_potions[slot] = ""
		refresh_run_hud()
		return
	_potions[slot] = ""
	_float_stack.clear()
	match pid:
		"heal_potion":
			var low: Unit = null
			for u in _combat.alive_heroes():
				if low == null or float(u.hp) / u.max_hp < float(low.hp) / low.max_hp:
					low = u
			if low != null:
				_relics._count("slime_potion", "heal", _combat.heal(low, ceili(float(low.max_hp) * POTION_HEAL)))
		"energy_potion":
			_energy += POTION_ENERGY
			_refresh_energy()
		"battle_potion":
			_relics.rage_active = true
	_refresh_all_actors()
	refresh_run_hud()

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
	for c in [hand_layer, end_turn_button, energy_label, deck_button, discard_button, _ults, _sleeve, _potion_bar]:
		if c != null:
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

# --- Квестовая комната ------------------------------------------------------

## Сценка перед квестовым боем (data/dialogues/quests/warrior_quest.json).
func _play_quest_intro(room: Dictionary) -> void:
	if bool(room.get("intro_seen", false)) or StoryDialogueDB_ == null or DialogueManager_ == null:
		return
	room["intro_seen"] = true
	var d := StoryDialogueDB_.get_dialogue("find_warrior_room_intro")
	var lines := StoryDialogueDB_.resolve_lines(d) if not d.is_empty() else []
	if lines.is_empty():
		return
	_set_battle_ui(false)
	var done := [false]
	DialogueManager_.show_sequence(lines, func() -> void: done[0] = true)
	var waited := 0.0
	while not done[0] and is_inside_tree():
		await get_tree().process_frame
		waited += get_process_delta_time()
		# Страховка: окно диалога не появилось — не держим игрока.
		if waited > 0.7 and (DialogueManager_._overlay == null or not is_instance_valid(DialogueManager_._overlay) or not DialogueManager_._overlay.visible):
			break
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen("find_warrior_room_intro")

## Героиня квеста встаёт в отряд (впереди) с этого боя и до конца забега: её карты в колоде, ульта в колонке.
func _quest_add_hero(hero_id: String) -> void:
	if _combat.hero_by_id(hero_id) != null or left_team.size() >= _left_world_slots.size():
		return
	var unit := _make_unit(hero_id, maxi(1, DungRun.party_level))
	if unit == null:
		return
	left_team.append(unit)
	if unit.data.card_passive != null:
		unit.data.card_passive.attach(_combat, unit)
	var charges: Dictionary = _ults._charge.duplicate()
	_ults.build(left_team)
	for k in charges:
		_ults._charge[k] = charges[k]
	_ults.refresh()
	CardDragPortrait.warm_up(unit.data)

## Бой квестовой комнаты закончился (победа или поражение): воин найден — сценка в хабе после забега.
func _finish_quest_room(room: Dictionary) -> void:
	if bool(room.get("used", false)):
		return
	room["used"] = true
	if StoryState_ == null:
		return
	StoryState_.set_flag("find_warrior_room_done", true)
	StoryState_.set_flag("pending_find_warrior_after_battle", true)
	_captured_lines.append("Воин найден! Он присоединится к отряду дома.")

func _on_room_cleared() -> void:
	await _wait(0.8)
	_clear_hand_views()
	_float_stack.clear()
	_stats.battles_won += 1
	# Статуи: белая лечит после победы; обе тратят одну боевую комнату.
	_relics.on_battle_won(_combat)
	if _run.white_charges > 0:
		_run.white_charges -= 1
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
		_run.white_charges += CardRelics.STATUE_ROOMS
	else:
		_run.black_charges += CardRelics.STATUE_ROOMS
	refresh_run_hud()

## Героини для окна медсестры: [{id, name, hp, max_hp, dead}].
func run_heroes() -> Array:
	var out: Array = []
	for u in left_team:
		if u != null:
			out.append({"id": u.data.id, "name": u.data.display_name, "hp": maxi(0, u.hp), "max_hp": u.max_hp, "dead": u.is_dead})
	return out

func run_heal_hero(hero_id: String, percent: float) -> void:
	var u := _combat.hero_by_id(hero_id)
	if CardCombat.is_alive(u):
		_float_stack.clear()
		_combat.heal(u, ceili(float(u.max_hp) * percent))
		_refresh_all_actors()

func run_revive_hero(hero_id: String, percent: float) -> void:
	for u in left_team:
		if u != null and u.data.id == hero_id and u.is_dead:
			u.is_dead = false
			u.hp = maxi(1, int(float(u.max_hp) * percent))
			_refresh_all_actors()
			CardActorFx.start_idle(_find_actor(u))
			return

## Товары Сессилии для этой комнаты (кешируются в room["stock"]).
func run_lamia_stock(room: Dictionary) -> Array:
	if not room.has("stock"):
		room["stock"] = DungRun.roll_lamia_stock(_run.rng)
	return room["stock"]

## Купить товар Сессилии: золото списывается, предметы — в инвентарь.
func run_buy_offer(offer: Dictionary) -> bool:
	if bool(offer.get("sold", false)) or not run_spend_gold(int(offer.get("price", 0))):
		return false
	Inventory_.add_item(String(offer["id"]), int(offer.get("count", 1)))
	offer["sold"] = true
	return true

## Сундук: золото всегда; кварц, лут с мобов этажа, семена и (редко) неоткрытый рецепт еды —
## каждое со своим шансом. Возвращает текст для окна.
const CHEST_QUARTZ_CHANCE := 0.6
const CHEST_LOOT_CHANCE := 0.5
const CHEST_SEED_CHANCE := 0.2
const CHEST_RECIPE_CHANCE := 0.12

func run_roll_chest(_room: Dictionary) -> String:
	var r := _run.rng
	var gold_amount := CHEST_GOLD_BASE + _room_index * CHEST_GOLD_PER_ROOM
	run_gain_gold(gold_amount)
	var lines: Array[String] = ["Золото ×%d" % gold_amount]
	if r.randf() < CHEST_QUARTZ_CHANCE:
		var q := r.randi_range(1, 3)
		Inventory_.add_item("quartz", q)
		lines.append("Кварц ×%d" % q)
	if r.randf() < CHEST_LOOT_CHANCE:
		var loot_id: String = DungRun.LAMIA_FLOOR_LOOT[r.randi_range(0, DungRun.LAMIA_FLOOR_LOOT.size() - 1)]
		var n := r.randi_range(2, 4)
		Inventory_.add_item(loot_id, n)
		lines.append("%s ×%d" % [RunItems.get_item_name(loot_id), n])
	if r.randf() < CHEST_SEED_CHANCE:
		var seed_id: String = DungRun.RIKKA_SEEDS[r.randi_range(0, DungRun.RIKKA_SEEDS.size() - 1)]
		var sn := r.randi_range(1, 2)
		Inventory_.add_item(seed_id, sn)
		lines.append("%s ×%d" % [RunItems.get_item_name(seed_id), sn])
	var unknown := AlchemyDB.unknown_recipe_items()
	if not unknown.is_empty() and r.randf() < CHEST_RECIPE_CHANCE:
		var rec := unknown[r.randi_range(0, unknown.size() - 1)]
		Inventory_.add_item(rec, 1)
		lines.append("%s — изучен!" % RunItems.get_item_name(rec))
	if StoryState_ != null and StoryState_.is_quest_active("lamia_headphones") and not Inventory_.has_item("warm_headphones"):
		if r.randf() < 0.18:
			Inventory_.add_item("warm_headphones", 1)
			lines.append("Тёплые наушники (между монетами)")
	return "В сундуке:\n" + "\n".join(lines)
