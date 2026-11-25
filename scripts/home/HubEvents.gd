extends Node
class_name HubEvents
## События чибиков в доме: на местах (камин, котёл…) и встречи двух персонажей.
## Описаны в data/hub/events.json, места — точки Marker2D в Hub.tscn → Spots (двигайте в редакторе).
##
## Событие:
##   "id"        — имя (для отката);
##   "type"      — "spot" (один персонаж у места) или "meet" (все из "who" у места одновременно);
##   "who"       — id персонажа или список id;
##   "spot"      — имя точки в Spots; "radius" — насколько близко (px);
##   "if"        — условия: "fireplace_off", "fireplace_on", "cauldron" (котёл куплен), "night", "day";
##   "chance"    — шанс, когда персонаж(и) подошли (бросается один раз за подход);
##   "cooldown"  — сколько секунд событие потом не повторяется;
##   "seek"      — шанс, что персонаж сам пойдёт к месту, если оно на его линии (0 — не ходит);
##   "steps"     — что происходит, по очереди:
##       {"emote": "angry", "who": "witch"}   — смайлик (assets/ui/emotes/<имя>.png)
##       {"say": "Текст", "who": "warrior"}   — фраза в пузыре
##       {"wait": 0.8}                        — пауза, секунд
##       {"hop": "witch"}                     — подпрыгнуть
##       {"go": "warrior", "to": "CauldronLeft"} — дойти до точки (по линии; на другую линию — прыжком)
##       {"face": "witch", "to": "Cauldron"}  — повернуться к точке
##       {"turn_on": "fireplace"} / {"turn_off": "pumpkin"} — включить / выключить камин, тыкву;
##       {"magic": true} / {"magic": false}   — включить / погасить магический круг у котла;
##       {"brew": "witch", ...}               — сварить у котла: с шансом "chance"[уровень котла]
##           случайное зелье из "potions", иначе "fail" (шлак); кладётся на пол у точки "drop"
##           (HubPile, кликнуть — забрать); удалось — смайлик "good" и фраза "good_say", нет — "bad" / "bad_say";
##       {"give": ["jelly", "steak"], "who": "warrior", "drop": "Cauldron"} — положить на пол одно
##           случайное из списка (можно "count"), смайлик "emote", фраза "say_after".
##   "daily"     — true: не чаще раза в игровой день (DayCycle); у случайных — раз в день каждому.
## Пока идёт событие, его участники не гуляют, а сам дом живёт как обычно.
##
## Случайные события ("type": "random") — не у места, а «иногда»: "chance_per_min" — шанс за минуту,
## "who" — id, список или "*" (любой); что делать — "handler" (код ниже, параметры — в самом событии):
##   "nap"         — лечь спать где стоит (картинка смерти), смайлики zzz; "duration": [от, до] сек;
##   "stairs_fall" — на лестнице спрыгнуть вбок и полежать "lie" сек ("throw": [x, y] — скорость);
##   "eat"         — съесть персонажа рядом ("radius"), через "hold" сек выплюнуть; тот лежит "lie" сек
##                   и показывает смайлик из "reactions" (id -> смайлик);
##   "visit"       — сам идёт к точке "spot" (на другую линию — прыжком) и там делает "steps"
##                   (как у событий на местах); "if" — условия;
##   "flirt"       — подходит к девочке рядом (та же линия, ближе "radius") и подкатывает: фраза из
##                   "lines", её ответ — "replies"[id] или "replies"["*"], смайлики — "reactions"[id];
##                   с шансом "success" ей нравится (heart), иначе он грустит ("after");
##   "slime"       — идёт и оставляет за собой лужицу слизи (HubPile, "count": [от, до] штук);
##   "leave"       — дойти до двери (точка Door), зайти в проём (точка DoorIn), растворяясь,
##                   и уйти из дома на "away": [от, до] сек. Возвращается так же: из проёма к Door.
##   У "nap" можно "lines" — фраза перед сном (одна случайная) и "wake" — фраза, когда встаёт.
##
## События на двоих (тоже "type": "random", второй — кто окажется рядом):
##   "bump" — двое идут по одной линии навстречу и сталкиваются (ближе "gap" px): отлетают
##            ("throw": [x, y]), лежат "lie" сек, встают и идут дальше, куда шли. Здесь вместо
##            "chance_per_min" — "chance": шанс на каждую такую встречу;
##   "rps"  — двое рядом (одна линия, ближе "radius") играют в камень-ножницы-бумагу: смайлики
##            rps_rock / rps_paper / rps_scissors, ничья — переигрывают (до "rounds" раз),
##            победитель радуется ("win"), проигравший — "lose" (смайлик, один из списка).

const FILE := "res://data/hub/events.json"
const CHECK_EVERY := 0.25

var hub: Node
var running := false
var _events: Array = []
var _cooldown: Dictionary = {}
var _inside: Dictionary = {}
var _check := 0.0
var _met: Dictionary = {}       ## "a|b" -> сек: эта пара уже бросала шанс столкновения

func setup(p_hub: Node) -> void:
	hub = p_hub
	name = "HubEvents"
	if FileAccess.file_exists(FILE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if parsed is Dictionary:
			_events = (parsed as Dictionary).get("events", [])

func _process(delta: float) -> void:
	for id in _cooldown.keys():
		_cooldown[id] = float(_cooldown[id]) - delta
	for k in _met.keys():
		_met[k] = float(_met[k]) - delta
		if float(_met[k]) <= 0.0:
			_met.erase(k)
	_check -= delta
	if _check > 0.0 or running or hub == null:
		return
	_check = CHECK_EVERY
	if _busy():
		return
	for ev in _events:
		if not (ev is Dictionary):
			continue
		var id := String(ev.get("id", ""))
		if float(_cooldown.get(id, 0.0)) > 0.0 or not _conditions_ok(ev):
			continue
		if String(ev.get("type", "")) == "random":
			if _try_random(ev):
				return
			continue
		if bool(ev.get("daily", false)) and _done_today(id):
			continue
		var ws := _participants(ev)
		if ws.is_empty():
			continue
		var inside := ws.all(func(w: HomeWalker) -> bool: return _free(w) and _near(w, ev))
		if not inside:
			_inside[id] = false
			continue
		if bool(_inside.get(id, false)):
			continue
		_inside[id] = true
		if randf() < float(ev.get("chance", 1.0)):
			if bool(ev.get("daily", false)):
				_mark_today(id)
			_run(ev, ws)
			return

## Раз в день: счётчик StoryState "hub_daily:<событие>[:<кто>]" = номер дня + 1.
func _daily_key(key: String) -> String:
	return "hub_daily:" + key

func _done_today(key: String) -> bool:
	return StoryState_ != null and StoryState_.get_counter(_daily_key(key)) == DayCycle.day_number() + 1

func _mark_today(key: String) -> void:
	if StoryState_ != null:
		var k := _daily_key(key)
		StoryState_.add_counter(k, DayCycle.day_number() + 1 - StoryState_.get_counter(k))

func _busy() -> bool:
	if DialogueManager_ != null and DialogueManager_.is_showing():
		return true
	return bool(hub.get("_dragging")) or (hub.has_method("_world_locked") and bool(hub.call("_world_locked")))

func _free(w: HomeWalker) -> bool:
	return is_instance_valid(w) and w.state in [HomeWalker.State.IDLE, HomeWalker.State.WALK]

func _participants(ev: Dictionary) -> Array:
	var who = ev.get("who", [])
	var ids: Array = who if who is Array else [who]
	var walkers: Dictionary = hub.get("walkers")
	var out: Array = []
	for id in ids:
		if not walkers.has(String(id)) or not is_instance_valid(walkers[String(id)]):
			return []
		out.append(walkers[String(id)])
	return out

func spot(spot_name: String) -> Node2D:
	return hub.get_node_or_null("Spots/" + spot_name) as Node2D

func _near(w: HomeWalker, ev: Dictionary) -> bool:
	var s := spot(String(ev.get("spot", "")))
	return s != null and w.global_position.distance_to(s.global_position) <= float(ev.get("radius", 150.0))

func _conditions_ok(ev: Dictionary) -> bool:
	for c in ev.get("if", []):
		match String(c):
			"fireplace_off":
				if hub.fireplace == null or hub.fireplace.is_on:
					return false
			"fireplace_on":
				if hub.fireplace == null or not hub.fireplace.is_on:
					return false
			"cauldron":
				if not AlchemyDB.has_cauldron():
					return false
			"night":
				if not DayCycle.is_night():
					return false
			"day":
				if DayCycle.is_night():
					return false
	return true

# --- Случайные события ---------------------------------------------------------------

func _try_random(ev: Dictionary) -> bool:
	var who = ev.get("who", "*")
	var walkers: Dictionary = hub.get("walkers")
	var ids: Array = walkers.keys() if (who is String and String(who) == "*") else (who if who is Array else [who])
	ids.shuffle()
	var p := float(ev.get("chance_per_min", 1.0)) * CHECK_EVERY / 60.0
	var bump := String(ev.get("handler", "")) == "bump"
	for id in ids:
		var w: HomeWalker = walkers.get(String(id))
		if w == null or not _free(w) or w.on_bed() or w.is_lying() or not _random_ok(ev, w):
			continue
		var daily := bool(ev.get("daily", false))
		if daily and _done_today(String(ev.get("id", "")) + ":" + w.unit_id):
			continue
		if bump:
			# Шанс — один раз на встречу этой пары.
			var o := _bump_partner(ev, w)
			var key := (w.unit_id + "|" + o.unit_id) if w.unit_id < o.unit_id else (o.unit_id + "|" + w.unit_id)
			if _met.has(key):
				continue
			_met[key] = 3.0
			if randf() >= float(ev.get("chance", 0.5)):
				continue
		elif randf() >= p:
			continue
		if daily:
			_mark_today(String(ev.get("id", "")) + ":" + w.unit_id)
		_run_random(ev, w)
		return true
	return false

## Подходит ли персонаж для случайного события прямо сейчас.
func _random_ok(ev: Dictionary, w: HomeWalker) -> bool:
	match String(ev.get("handler", "")):
		"stairs_fall":
			if w.route == null or String(w.route.name) != String(ev.get("route", "Stairs")):
				return false
			var k := w.dist / maxf(1.0, w.route.length())
			return k > 0.35 and k < 0.9
		"eat":
			return _eat_victim(ev, w) != null
		"bump":
			return _bump_partner(ev, w) != null
		"rps":
			return _rps_partner(ev, w) != null
		"flirt":
			return _flirt_partner(ev, w) != null
		"visit":
			return spot(String(ev.get("spot", ""))) != null
		"slime":
			# Только на ходу и не на лестнице (лужица должна лежать на полу).
			return w.state == HomeWalker.State.WALK and w.route != null and not (ev.get("skip_routes", ["Stairs"]) as Array).has(String(w.route.name))
		"leave":
			var door := spot("Door")
			if door == null or w.route == null:
				return false
			return float(w.route.nearest(door.global_position)["dist"]) < 40.0
	return true

func _eat_victim(ev: Dictionary, w: HomeWalker) -> HomeWalker:
	var best: HomeWalker = null
	var best_d := float(ev.get("radius", 220.0))
	var walkers: Dictionary = hub.get("walkers")
	for o in walkers.values():
		if o == w or not is_instance_valid(o) or not _free(o) or (o as HomeWalker).on_bed():
			continue
		var d := (o as HomeWalker).global_position.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = o
	return best

## Идёт навстречу w по той же линии и уже совсем близко.
func _bump_partner(ev: Dictionary, w: HomeWalker) -> HomeWalker:
	var dir := w.walk_dir()
	if dir == 0.0 or w.route == null:
		return null
	var walkers: Dictionary = hub.get("walkers")
	for o in walkers.values():
		if o == w or not is_instance_valid(o) or not _free(o):
			continue
		var ow := o as HomeWalker
		if ow.route != w.route or ow.walk_dir() != -dir or ow.is_lying():
			continue
		var gap := (ow.dist - w.dist) * dir
		if gap > 0.0 and gap <= float(ev.get("gap", 70.0)):
			return ow
	return null

## Свободный персонаж на той же линии рядом (для игры).
func _rps_partner(ev: Dictionary, w: HomeWalker) -> HomeWalker:
	if w.route == null:
		return null
	var best: HomeWalker = null
	var best_d := float(ev.get("radius", 320.0))
	var walkers: Dictionary = hub.get("walkers")
	for o in walkers.values():
		if o == w or not is_instance_valid(o) or not _free(o):
			continue
		var ow := o as HomeWalker
		if ow.route != w.route or ow.on_bed() or ow.is_lying():
			continue
		var d := absf(ow.dist - w.dist)
		if d < best_d:
			best_d = d
			best = ow
	return best

func _run_random(ev: Dictionary, w: HomeWalker) -> void:
	running = true
	match String(ev.get("handler", "")):
		"nap":
			await _h_nap(ev, w)
		"bump":
			await _h_bump(ev, w)
		"rps":
			await _h_rps(ev, w)
		"slime":
			_h_slime(ev, w)
		"visit":
			await _h_visit(ev, w)
		"flirt":
			await _h_flirt(ev, w)
		"stairs_fall":
			await _h_stairs_fall(ev, w)
		"eat":
			await _h_eat(ev, w)
		"leave":
			await _h_leave(ev, w)
	_cooldown[String(ev.get("id", ""))] = float(ev.get("cooldown", 60.0))
	running = false

func _range(ev: Dictionary, key: String, dflt: Vector2) -> float:
	var r = ev.get(key, [dflt.x, dflt.y])
	if r is Array and (r as Array).size() >= 2:
		return randf_range(float(r[0]), float(r[1]))
	return float(r)

## Дождаться, пока брошенный персонаж приземлится (не дольше max_time).
func _await_landing(w: HomeWalker, max_time: float = 4.0) -> void:
	var t := 0.0
	while is_instance_valid(w) and w.state in [HomeWalker.State.FLY, HomeWalker.State.FALL] and t < max_time:
		await get_tree().process_frame
		t += get_process_delta_time()

## Полежать secs секунд (если не утащили), показывая смайлик every секунд; потом встать.
func _lie(w: HomeWalker, secs: float, emote_name: String = "", every: float = 0.0) -> void:
	if not is_instance_valid(w) or w.state in [HomeWalker.State.DRAG, HomeWalker.State.FLY]:
		return   ## его как раз держат / бросили
	w.set_frozen(true)
	w.lie_down()
	if emote_name != "":
		hub.chatter.emote(w, emote_name)
	var t := 0.0
	var next := every
	while t < secs:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
		if not is_instance_valid(w) or w.state != HomeWalker.State.FROZEN:
			return   ## подняли / утащили — событие кончилось
		if every > 0.0 and t >= next and emote_name != "":
			next += every
			hub.chatter.emote(w, emote_name)
	w.stand_up()
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(w):
		w.set_frozen(false)

func _h_nap(ev: Dictionary, w: HomeWalker) -> void:
	var lines: Array = ev.get("lines", [])
	if not lines.is_empty():
		w.set_frozen(true)
		hub.chatter.say(w, String(lines[randi() % lines.size()]))
		await get_tree().create_timer(float(ev.get("say_time", 1.8))).timeout
		if not is_instance_valid(w) or w.state != HomeWalker.State.FROZEN:
			return
	await _lie(w, _range(ev, "duration", Vector2(10, 18)), "zzz", 3.0)
	var wake: Array = ev.get("wake", [])
	if not wake.is_empty() and is_instance_valid(w) and w.state == HomeWalker.State.IDLE:
		hub.chatter.say(w, String(wake[randi() % wake.size()]))

## Столкнулись лбами: оба отлетают назад, лежат, встают и идут дальше, куда шли.
func _h_bump(ev: Dictionary, w: HomeWalker) -> void:
	var o := _bump_partner(ev, w)
	if o == null:
		return
	var plan := [[w, w.route, w.walk_target()], [o, o.route, o.walk_target()]]
	var v: Array = ev.get("throw", [260, -420])
	var sx := signf(o.position.x - w.position.x)
	if sx == 0.0:
		sx = 1.0
	hub.chatter.emote(w, "exclaim")
	hub.chatter.emote(o, "exclaim")
	w.throw(Vector2(-sx * float(v[0]), float(v[1])))
	o.throw(Vector2(sx * float(v[0]), float(v[1])))
	await _await_landing(w)
	await _await_landing(o)
	var secs := _range(ev, "lie", Vector2(2.0, 2.0))
	_lie_and_go(o, secs + randf_range(-0.3, 0.3), plan[1])
	await _lie_and_go(w, secs, plan[0])

## Полежать (смайлик sweat), встать и пойти дальше по той же линии к прежней цели.
func _lie_and_go(w: HomeWalker, secs: float, plan: Array) -> void:
	await _lie(w, secs, "sweat")
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(w) and w.route == plan[1]:
		w.resume_walk(float(plan[2]))

const RPS := ["rock", "paper", "scissors"]
## Кто кого бьёт: камень — ножницы, ножницы — бумагу, бумага — камень.
const RPS_BEATS := {"rock": "scissors", "scissors": "paper", "paper": "rock"}

## Камень-ножницы-бумага: подойти, раз-два-три (подпрыгивают), показать, кто что выбросил.
func _h_rps(ev: Dictionary, w: HomeWalker) -> void:
	var o := _rps_partner(ev, w)
	if o == null:
		return
	w.set_frozen(true)
	o.set_frozen(true)
	var side := signf(w.dist - o.dist)
	if side == 0.0:
		side = 1.0
	var stand := clampf(o.dist + side * float(ev.get("distance", 150.0)), 0.0, o.route.length())
	await w.event_move(o.route, stand)
	if not (is_instance_valid(w) and is_instance_valid(o)):
		_unfreeze([w, o])
		return
	w.face_toward(o.position.x)
	o.face_toward(w.position.x)
	hub.chatter.emote(w, "exclaim")
	await get_tree().create_timer(0.7).timeout
	var rounds := int(ev.get("rounds", 3))
	var winner: HomeWalker = null
	var loser: HomeWalker = null
	for r in range(rounds):
		if not _still_frozen([w, o]):
			_unfreeze([w, o])
			return
		hub.chatter.say(w, String(ev.get("shout", "Камень, ножницы, бумага!")) if r == 0 else String(ev.get("again", "Ещё раз!")))
		for i in range(3):
			o.event_hop()
			await w.event_hop()
		var a: String = RPS[randi() % 3]
		var b: String = RPS[randi() % 3]
		hub.chatter.emote(w, "rps_" + a, 1.8)
		hub.chatter.emote(o, "rps_" + b, 1.8)
		await get_tree().create_timer(1.9).timeout
		if a != b:
			winner = w if RPS_BEATS[a] == b else o
			loser = o if winner == w else w
			break
		hub.chatter.emote(w, "dots")
		hub.chatter.emote(o, "dots")
		await get_tree().create_timer(1.0).timeout
	if winner != null and _still_frozen([winner, loser]):
		hub.chatter.emote(winner, String(ev.get("win", "happy")))
		var lose: Array = ev.get("lose", ["sad", "angry"])
		hub.chatter.emote(loser, String(lose[randi() % lose.size()]) if not lose.is_empty() else "sad")
		winner.event_hop()
		await get_tree().create_timer(0.45).timeout
		await winner.event_hop()
		await get_tree().create_timer(1.0).timeout
	_unfreeze([w, o])

func _still_frozen(ws: Array) -> bool:
	return ws.all(func(x) -> bool: return is_instance_valid(x) and (x as HomeWalker).state == HomeWalker.State.FROZEN)

func _unfreeze(ws: Array) -> void:
	for x in ws:
		if is_instance_valid(x):
			(x as HomeWalker).set_frozen(false)

func _h_stairs_fall(ev: Dictionary, w: HomeWalker) -> void:
	var v: Array = ev.get("throw", [-420, -520])
	hub.chatter.emote(w, "exclaim")
	w.throw(Vector2(float(v[0]), float(v[1])))
	await _await_landing(w)
	await _lie(w, float(ev.get("lie", 5.0)), "dots")

func _h_eat(ev: Dictionary, w: HomeWalker) -> void:
	var victim := _eat_victim(ev, w)
	if victim == null:
		return
	w.set_frozen(true)
	victim.set_frozen(true)
	await w.event_move(victim.route, victim.dist)
	if not is_instance_valid(victim):
		w.set_frozen(false)
		return
	victim.visible = false
	hub.chatter.emote(w, "happy")
	# Жуёт: покачивается.
	var chew := w.create_tween().set_loops(int(ceil(float(ev.get("hold", 2.5)) / 0.36)))
	chew.tween_property(w.body, "scale", w.body.scale * Vector2(1.12, 0.9), 0.18)
	chew.tween_property(w.body, "scale", w.body.scale, 0.18)
	await get_tree().create_timer(float(ev.get("hold", 2.5))).timeout
	chew.kill()
	if not is_instance_valid(victim):
		w.set_frozen(false)
		return
	victim.visible = true
	victim.position = w.position + Vector2(0, -40)
	victim.set_frozen(false)
	var dir := 1.0 if randf() < 0.5 else -1.0
	victim.throw(Vector2(dir * 480.0, -620.0))
	w.set_frozen(false)
	w.hop()
	await _await_landing(victim)
	var reactions: Dictionary = ev.get("reactions", {})
	await _lie(victim, float(ev.get("lie", 2.0)), String(reactions.get(victim.unit_id, "")))

func _h_leave(ev: Dictionary, w: HomeWalker) -> void:
	var door := spot("Door")
	if door == null:
		return
	w.set_frozen(true)
	var n: Array = hub.nearest_spot(door.global_position)
	if n[0] != null:
		await w.event_move(n[0], float(n[1]))
	if not is_instance_valid(w):
		return
	hub.chatter.emote(w, "dots")
	await get_tree().create_timer(0.6).timeout
	# Заходит в проём (точка Spots/DoorIn) и растворяется; нет точки — просто тает на месте.
	var inside := spot("DoorIn")
	if inside != null and is_instance_valid(w):
		await w.walk_door(inside.global_position, float(ev.get("exit_time", 1.4)))
	elif is_instance_valid(w):
		await w.fade(0.0, 0.6)
	if is_instance_valid(w):
		hub.send_away(w, _range(ev, "away", Vector2(90, 180)))

# --- Сам пойти к месту ----------------------------------------------------------------

## Персонаж решает, куда идти: если есть событие с ним, место — на его линии, и выпал шанс "seek" —
## точка этого места (расстояние вдоль линии), иначе -1.
func seek_dist(w: HomeWalker) -> float:
	if running or w.route == null:
		return -1.0
	for ev in _events:
		if not (ev is Dictionary) or float(ev.get("seek", 0.0)) <= 0.0:
			continue
		if float(_cooldown.get(String(ev.get("id", "")), 0.0)) > 0.0 or not _conditions_ok(ev):
			continue
		if bool(ev.get("daily", false)) and _done_today(String(ev.get("id", ""))):
			continue
		var who = ev.get("who", [])
		var ids: Array = who if who is Array else [who]
		if not ids.has(w.unit_id) or randf() >= float(ev.get("seek", 0.0)):
			continue
		var s := spot(String(ev.get("spot", "")))
		if s == null:
			continue
		var n := w.route.nearest(s.global_position)
		if float(n["dist"]) <= float(ev.get("radius", 150.0)):
			return float(n["d"])
	return -1.0

# --- Ход события ----------------------------------------------------------------------

func _run(ev: Dictionary, ws: Array) -> void:
	running = true
	for w in ws:
		(w as HomeWalker).set_frozen(true)
	var walkers: Dictionary = hub.get("walkers")
	for step in ev.get("steps", []):
		if not is_inside_tree():
			return
		if not (step is Dictionary):
			continue
		var st: Dictionary = step
		var w: HomeWalker = null
		for key in ["who", "hop", "go", "face"]:
			if st.has(key) and walkers.has(String(st[key])):
				w = walkers[String(st[key])]
		if st.has("wait"):
			await get_tree().create_timer(float(st["wait"])).timeout
		elif st.has("magic"):
			hub.set("magic_forced", bool(st["magic"]))
		elif st.has("brew") and walkers.has(String(st["brew"])):
			await _step_brew(st, walkers[String(st["brew"])])
		elif st.has("give") and w != null:
			await _step_give(st, w)
		elif st.has("emote") and w != null:
			hub.chatter.emote(w, String(st["emote"]))
		elif st.has("say") and w != null:
			hub.chatter.say(w, String(st["say"]))
		elif st.has("hop") and w != null:
			await w.event_hop()
		elif st.has("go") and w != null:
			var s := spot(String(st.get("to", "")))
			if s != null:
				var n: Array = hub.nearest_spot(s.global_position)
				if n[0] != null:
					await w.event_move(n[0], float(n[1]))
		elif st.has("face") and w != null:
			var s2 := spot(String(st.get("to", "")))
			if s2 != null:
				w.face_toward(s2.global_position.x)
		elif st.has("turn_on") or st.has("turn_off"):
			var on := st.has("turn_on")
			var t = hub.get(String(st.get("turn_on" if on else "turn_off", "")))
			if t is HubToggle and (t as HubToggle).is_on != on:
				(t as HubToggle).toggle()
	hub.set("magic_forced", false)
	for w in ws:
		if is_instance_valid(w):
			(w as HomeWalker).set_frozen(false)
	_cooldown[String(ev.get("id", ""))] = float(ev.get("cooldown", 30.0))
	running = false

## Где положить: у точки "drop" (по умолчанию — CauldronDrop) в пределах "spread" px по сторонам;
## из нескольких случайных мест — самое далёкое от уже лежащих кучек, чтобы не слипались.
func _drop_pos(st: Dictionary) -> Vector2:
	var s := spot(String(st.get("drop", "CauldronDrop")))
	var base := s.global_position if s != null else Vector2(960, 1040)
	var spread := float(st.get("spread", 120.0))
	var taken: Array = HubPile.all().map(func(d) -> Vector2: return d["pos"])
	var best := base
	var best_gap := -1.0
	for i in 8:
		var c := base + Vector2(randf_range(-spread, spread), randf_range(-6.0, 6.0))
		var gap := 9999.0
		for t in taken:
			gap = minf(gap, c.distance_to(t))
		if gap > best_gap:
			best_gap = gap
			best = c
	return best

## Ведьмочка колдует у котла: зелье или шлак. Шанс — по уровню котла (AlchemyDB.cauldron_level).
func _step_brew(st: Dictionary, w: HomeWalker) -> void:
	var chances: Array = st.get("chance", [0.3])
	var lvl := clampi(AlchemyDB.cauldron_level(), 0, chances.size() - 1)
	var potions: Array = st.get("potions", ["slime_potion"])
	var good := randf() < float(chances[lvl]) and not potions.is_empty()
	var item := String(potions[randi() % potions.size()]) if good else String(st.get("fail", "alchemy_slag"))
	hub.call("drop_pile", item, 1, w.unit_id, _drop_pos(st))
	hub.chatter.emote(w, String(st.get("good" if good else "bad", "happy" if good else "sweat")))
	var line := String(st.get("good_say" if good else "bad_say", ""))
	if line != "":
		await get_tree().create_timer(0.6).timeout
		hub.chatter.say(w, line)

## Положить на пол одно случайное из списка (еда воина).
func _step_give(st: Dictionary, w: HomeWalker) -> void:
	var list: Array = st.get("give", [])
	if list.is_empty():
		return
	hub.call("drop_pile", String(list[randi() % list.size()]), int(st.get("count", 1)), w.unit_id, _drop_pos(st))
	if st.has("emote"):
		hub.chatter.emote(w, String(st["emote"]))
	var line := String(st.get("say_after", ""))
	if line != "":
		await get_tree().create_timer(0.6).timeout
		hub.chatter.say(w, line)

## Сам идёт к месту и делает там шаги события (Луиса тушит камин).
func _h_visit(ev: Dictionary, w: HomeWalker) -> void:
	var s := spot(String(ev.get("spot", "")))
	if s == null:
		return
	w.set_frozen(true)
	var n: Array = hub.nearest_spot(s.global_position)
	if n[0] != null:
		await w.event_move(n[0], float(n[1]))
	if not is_instance_valid(w) or w.state != HomeWalker.State.FROZEN or not _conditions_ok(ev):
		if is_instance_valid(w):
			w.set_frozen(false)
		return
	await _run(ev, [w])

## Девочка рядом с воином (не он сам): та же линия, ближе "radius".
func _flirt_partner(ev: Dictionary, w: HomeWalker) -> HomeWalker:
	if w.route == null:
		return null
	var best: HomeWalker = null
	var best_d := float(ev.get("radius", 600.0))
	var walkers: Dictionary = hub.get("walkers")
	for o in walkers.values():
		if o == w or not is_instance_valid(o) or not _free(o):
			continue
		var ow := o as HomeWalker
		if ow.route != w.route or ow.on_bed() or ow.is_lying():
			continue
		var d := absf(ow.dist - w.dist)
		if d < best_d:
			best_d = d
			best = ow
	return best

## Воин подкатывает: подходит, фраза-пикап, ответ и смайлик девочки, его реакция.
func _h_flirt(ev: Dictionary, w: HomeWalker) -> void:
	var o := _flirt_partner(ev, w)
	if o == null:
		return
	w.set_frozen(true)
	o.set_frozen(true)
	var side := signf(w.dist - o.dist)
	if side == 0.0:
		side = 1.0
	var stand := clampf(o.dist + side * float(ev.get("distance", 170.0)), 0.0, o.route.length())
	await w.event_move(o.route, stand)
	if not _still_frozen([w, o]):
		_unfreeze([w, o])
		return
	w.face_toward(o.position.x)
	await get_tree().create_timer(0.3).timeout
	o.face_toward(w.position.x)
	var lines: Array = ev.get("lines", [])
	if not lines.is_empty():
		hub.chatter.say(w, String(lines[randi() % lines.size()]))
	await get_tree().create_timer(float(ev.get("line_time", 2.6))).timeout
	if not _still_frozen([w, o]):
		_unfreeze([w, o])
		return
	var lucky := randf() < float(ev.get("success", 0.1))
	var reactions: Dictionary = ev.get("reactions", {})
	var emo: Array = reactions.get(o.unit_id, reactions.get("*", ["dots"]))
	hub.chatter.emote(o, "heart" if lucky else (String(emo[randi() % emo.size()]) if not emo.is_empty() else "dots"))
	var replies: Dictionary = ev.get("lucky_replies" if lucky else "replies", {})
	var rl: Array = replies.get(o.unit_id, replies.get("*", []))
	if not rl.is_empty():
		await get_tree().create_timer(0.5).timeout
		hub.chatter.say(o, String(rl[randi() % rl.size()]))
	await get_tree().create_timer(float(ev.get("reply_time", 2.0))).timeout
	if _still_frozen([w, o]):
		if lucky:
			hub.chatter.emote(w, "exclaim")
			await w.event_hop()
		else:
			var after: Array = ev.get("after", ["sweat", "sad"])
			hub.chatter.emote(w, String(after[randi() % after.size()]) if not after.is_empty() else "sweat")
		await get_tree().create_timer(1.2).timeout
	_unfreeze([w, o])

## Слизнедевочка оставляет лужицу слизи у себя под ногами и идёт дальше.
func _h_slime(ev: Dictionary, w: HomeWalker) -> void:
	var r: Array = ev.get("count", [2, 4])
	var n := randi_range(int(r[0]), int(r[r.size() - 1]))
	hub.call("drop_pile", String(ev.get("item", "slime_goop")), n, w.unit_id, w.global_position + Vector2(0, 2))
	if ev.has("emote"):
		hub.chatter.emote(w, String(ev["emote"]))
