extends Node
class_name CardAutoBot
## Автобой: бот проходит забег за игрока (кнопка «Автобой» в бою; ещё раз — выключить).
## Не идеальный игрок, а простые правила:
##  • бой — разыгрывает самую выгодную карту за энергию, пока есть что разыграть, потом «Завершить ход».
##    Выгода карты: урон (добить врага — много очков), лечение (кто сильнее ранен — тем ценнее),
##    щит (если враги собираются бить), статусы; ульта — как только заряжена;
##  • сброс по просьбе карты — самые дорогие из оставшихся;
##  • добыча — «Дальше»; выбор комнаты — по HEAL_AT: ранены — к медсестре, если она есть, и мимо
##    элиты; иначе обычный бой → элита → события; лавку обходит (ничего не покупает);
##  • медсестра (Ноктрис) — воскрешает павшую или лечит самую раненую, если хватает золота;
##    лавка, сундук, статуя — открыть / принять и идти дальше;
##  • диалоги — листает; вопросы (поимка) — случайный ответ;
##  • конец забега — выключается, итог смотрит игрок.
## Скорость — STEP (секунд между действиями).

signal toggled_bot(on: bool)

const STEP := 0.45
## Пауза между действиями (тесты могут ускорить).
var step := STEP
## Средний запас HP отряда (доля), ниже которого бот идёт лечиться к медсестре и обходит элиту.
const HEAL_AT := 0.55
## Медсестра: лечить, если у кого-то HP ниже этой доли.
const NURSE_HEAL_BELOW := 0.6
const MAX_ACTIONS_PER_TURN := 30

var battle: Node
var enabled := false
var _cool := 0.0
var _working := false
var _actions := 0

func setup(p_battle: Node) -> void:
	battle = p_battle
	process_mode = Node.PROCESS_MODE_PAUSABLE

func set_enabled(on: bool) -> void:
	enabled = on
	_cool = 0.2
	toggled_bot.emit(on)

func _process(delta: float) -> void:
	if not enabled or _working or battle == null:
		return
	_cool -= delta
	if _cool > 0.0:
		return
	_cool = step
	_working = true
	await _tick()
	_working = false

func _tick() -> void:
	if bool(battle.get("_ended")):
		if battle.end_overlay.visible:
			set_enabled(false)   ## итог забега — игроку
		elif DialogueManager_ != null and DialogueManager_.is_showing():
			_dialogue_step()
		return
	if DialogueManager_ != null and DialogueManager_.is_showing():
		_dialogue_step()
		return
	var ui: Node = battle.get("_ui_layer")
	for c in (ui.get_children() if ui != null else []):
		if c.is_queued_for_deletion():
			continue
		if c is EventScreen:
			_event_step(c as EventScreen)
			return
		if c is LootPopup:
			_press_button_in(c, "Дальше")
			return
		if c is RoomCardHand:
			_choose_room(c as RoomCardHand)
			return
	var shrine := battle.right_world.get_node_or_null("StatueShrine") as StatueShrine
	if shrine != null and not shrine.is_queued_for_deletion() and shrine.interactive:
		shrine.set_interactive(false)   ## как клик по статуе
		shrine.clicked.emit()
		return
	await _battle_step()

# --- Диалоги ----------------------------------------------------------------------

func _dialogue_step() -> void:
	var ov = DialogueManager_._overlay
	if ov == null or not is_instance_valid(ov):
		return
	if ov._notice != null and is_instance_valid(ov._notice):
		ov._notice.close()
		return
	if ov._name_box != null and is_instance_valid(ov._name_box):
		ov._name_box._confirm()
		return
	if not ov._choices.is_empty():
		var buttons: Array = ov._choice_box.get_children().filter(func(b) -> bool: return b is Button and not (b as Button).disabled)
		if not buttons.is_empty():
			(buttons[randi() % buttons.size()] as Button).pressed.emit()
		return
	ov._advance()

# --- Комнаты ----------------------------------------------------------------------

## Средний запас HP живых героинь (павшие считаются за 0).
func _party_hp_ratio() -> float:
	var heroes: Array = battle.run_heroes()
	if heroes.is_empty():
		return 1.0
	var sum := 0.0
	for h in heroes:
		var d: Dictionary = h
		sum += 0.0 if bool(d["dead"]) else float(d["hp"]) / maxf(1.0, float(d["max_hp"]))
	return sum / float(heroes.size())

func _room_score(room: Dictionary, hurt: bool) -> float:
	var kind := String(room.get("kind", ""))
	var event := String(room.get("event", ""))
	match kind:
		"event":
			match event:
				"noctris": return 100.0 if hurt else 5.0
				"shop": return 1.0
				"chest": return 40.0
				"statue": return 30.0
			return 20.0
		"elite": return 5.0 if hurt else 45.0
		"boss": return 60.0
		"quest": return 55.0
	return 50.0 if not hurt else 35.0

func _choose_room(hand: RoomCardHand) -> void:
	if bool(hand.get("_done")):
		return
	var rooms: Array = battle.get_run().pending_choices
	if rooms.is_empty():
		return
	var hurt := _party_hp_ratio() < HEAL_AT or bool(battle.run_has_dead())
	var best := 0
	var best_s := -INF
	for i in rooms.size():
		var s := _room_score(rooms[i], hurt) + randf() * 3.0
		if s > best_s:
			best_s = s
			best = i
	hand._choose(best)

func _event_step(screen: EventScreen) -> void:
	if screen.get("_intro_waiting") or screen.get("_leaving"):
		return
	if screen.get("_image_open"):
		# Картинка услуги на весь экран — «кликнуть», чтобы закрыть.
		for c in screen.get_children():
			if c is TextureRect and (c as TextureRect).z_index == 50 and (c as TextureRect).mouse_filter == Control.MOUSE_FILTER_STOP:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = true
				(c as TextureRect).gui_input.emit(e)
				return
		return
	if screen.get("_chest_waiting"):
		screen._on_chest_open()
		return
	var room: Dictionary = screen.get("room")
	if String(room.get("event", "")) == "noctris" and not bool(room.get("used", false)):
		if _nurse(screen):
			return
	screen._on_continue_pressed()

## Медсестра: воскресить павшую, иначе вылечить самую раненую (если ранена заметно). true — что-то сделала.
func _nurse(screen: EventScreen) -> bool:
	var gold := int(battle.run_gold())
	var heroes: Array = battle.run_heroes()
	var dead: Array = heroes.filter(func(h) -> bool: return bool(h["dead"]))
	if not dead.is_empty() and gold >= EventScreen.NOCTRIS_REVIVE_PRICE:
		screen._on_noctris_target(String(dead[0]["id"]), String(dead[0]["name"]), true)
		return true
	var worst: Dictionary = {}
	var worst_r := NURSE_HEAL_BELOW
	for h in heroes:
		if bool(h["dead"]):
			continue
		var r := float(h["hp"]) / maxf(1.0, float(h["max_hp"]))
		if r < worst_r:
			worst_r = r
			worst = h
	if not worst.is_empty() and gold >= EventScreen.NOCTRIS_HEAL_PRICE:
		screen._on_noctris_target(String(worst["id"]), String(worst["name"]), false)
		return true
	return false

func _press_button_in(root: Node, text: String) -> void:
	for b in root.find_children("*", "Button", true, false):
		if (b as Button).text == text and not (b as Button).disabled:
			(b as Button).pressed.emit()
			return

# --- Бой --------------------------------------------------------------------------

func _battle_step() -> void:
	if int(battle.get("_discard_left")) > 0:
		_discard_one()
		return
	if bool(battle.get("_quiz_open")) or not battle._can_act():
		return
	if _actions >= MAX_ACTIONS_PER_TURN:
		_actions = 0
		battle._on_end_turn_pressed()
		return
	# Ульта — как только заряжена.
	for btn in battle._ults.get("_buttons"):
		var ub := btn as UltButton
		if ub != null and ub.unit != null and not ub.unit.is_dead and ub.is_ready() and not battle._combat.hero_disabled(ub.unit):
			_actions += 1
			await battle._on_ult_pressed(ub)
			return
	var best := _best_play()
	if best.is_empty():
		_actions = 0
		battle._on_end_turn_pressed()
		return
	_actions += 1
	battle._play_card(best["view"], best["targets"])

## Сброс: самая дорогая из оставшихся карт.
func _discard_one() -> void:
	var views: Array = battle.get("_hand_views")
	if views.is_empty():
		return
	var worst: CardView = views[0]
	for v in views:
		if (v as CardView).card.cost > worst.card.cost:
			worst = v
	battle._discard_from_hand(worst)

## Лучший ход: {view, targets, score}; нечего разыграть — {}.
func _best_play() -> Dictionary:
	var combat: CardCombat = battle._combat
	var energy := int(battle.get("_energy"))
	var best: Dictionary = {}
	var best_p := 0.0
	var threat := _incoming_damage()
	for v in battle.get("_hand_views"):
		var view := v as CardView
		if view == null or view.card == null:
			continue
		var card := view.card
		var cost := combat.effective_cost(card)
		if cost > energy or battle._card_blocked(card):
			continue
		var caster: Unit = combat.hero_by_id(card.owner_id)
		for targets in _target_options(card, caster):
			var s := _score(card, caster, targets, threat)
			if s <= 0.0:
				continue
			var p := s / maxf(0.6, float(cost))
			if p > best_p:
				best_p = p
				best = {"view": view, "targets": targets, "score": s}
	return best

## Варианты целей карты (как если бы её отпустили / перетащили на цель).
func _target_options(card: CardInstance, caster: Unit) -> Array:
	var combat: CardCombat = battle._combat
	var out: Array = []
	match card.target:
		CardInstance.Target.CHOSEN_ENEMY:
			for e in combat.alive_enemies():
				var t: Array[Unit] = [e]
				out.append(t)
		CardInstance.Target.CHOSEN_ALLY:
			for h in combat.alive_heroes():
				var t: Array[Unit] = [h]
				out.append(t)
		_:
			var t: Array[Unit] = battle._zone_targets(card)
			if not t.is_empty():
				out.append(t)
	if caster == null and card.owner_id != "":
		return []
	return out

## Сколько урона враги собираются нанести в свой ход (по намерениям).
func _incoming_damage() -> float:
	var combat: CardCombat = battle._combat
	var api = battle.get("_api")
	var total := 0.0
	for e in combat.alive_enemies():
		var move: EnemyMove = combat.intents.get(e)
		if move == null or combat.skips_turn(e):
			continue
		var dmg := float(api.shown_damage(e, move)) if api != null else float(move.damage)
		var n := maxi(1, move.hits)
		if move.aim == EnemyMove.Aim.ALL_HEROES:
			n *= combat.alive_heroes().size()
		total += dmg * float(n)
	return total

func _effect_units(eff: CardEffect, targets: Array[Unit], caster: Unit) -> Array[Unit]:
	var combat: CardCombat = battle._combat
	var out: Array[Unit] = []
	match eff.target_mode:
		CardEffect.TargetMode.CARD_TARGETS:
			out = targets
		CardEffect.TargetMode.CASTER:
			if caster != null:
				out.append(caster)
		CardEffect.TargetMode.FRONT_ALLY:
			var a := combat.front_hero()
			if a != null:
				out.append(a)
		CardEffect.TargetMode.ALL_ALLIES:
			out = combat.alive_heroes()
		CardEffect.TargetMode.FRONT_ENEMY:
			var e := combat.front_enemy()
			if e != null:
				out.append(e)
		CardEffect.TargetMode.ALL_ENEMIES:
			out = combat.alive_enemies()
	var ok: Array[Unit] = []
	for u in out:
		if CardCombat.is_alive(u) and (eff.only_if_status == "" or combat.has_status(u, eff.only_if_status)):
			ok.append(u)
	return ok

## Очки карты на этих целях.
func _score(card: CardInstance, caster: Unit, targets: Array[Unit], threat: float) -> float:
	var combat: CardCombat = battle._combat
	var heroes := combat.alive_heroes()
	# Приманка — только на героиню, которую можно поймать.
	if card.id == "lure":
		for t in targets:
			if t.enemy_def != null and t.enemy_def.char_id != "":
				return 30.0
		return 0.0
	var s := 0.0
	var shields_now := 0.0
	for h in heroes:
		shields_now += float(combat.shield_of(h))
	for eff in card.effects:
		var units := _effect_units(eff, targets, caster)
		if eff is EffDamage:
			var d := eff as EffDamage
			var per := float(d.value(caster)) * float(maxi(1, d.hits))
			for u in units:
				if heroes.has(u):
					s -= per   ## по своим — плохо
					continue
				var left := float(u.hp + combat.shield_of(u))
				s += minf(per, left)
				if per >= left:
					s += 25.0 + float(u.max_hp) * 0.1   ## добить — очень хорошо
		elif eff is EffHeal:
			var hl := eff as EffHeal
			var amount := float(hl.value(caster))
			if hl.max_hp_ratio > 0.0:
				amount = 0.0
			for u in units:
				if not heroes.has(u):
					continue
				var a := amount + (float(u.max_hp) * hl.max_hp_ratio if hl.max_hp_ratio > 0.0 else 0.0)
				var missing := float(u.max_hp - u.hp)
				var ratio := float(u.hp) / maxf(1.0, float(u.max_hp))
				s += minf(a, missing) * (1.4 if ratio < 0.5 else 0.6)
		elif eff is EffShield:
			var sh := float((eff as EffShield).value(caster)) * float(units.size())
			var need := maxf(0.0, threat - shields_now)
			s += minf(sh, need) * 0.9 + maxf(0.0, sh - need) * 0.1
		elif eff is EffApplyStatus:
			var st := eff as EffApplyStatus
			var n := float(maxi(1, maxi(st.stacks, st.turns)))
			for u in units:
				s += (5.0 if heroes.has(u) else 6.0) * n
		else:
			s += 6.0
	return s
