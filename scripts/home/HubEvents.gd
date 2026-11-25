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
##       {"turn_on": "fireplace"} / {"turn_off": "pumpkin"} — включить / выключить камин, тыкву.
## Пока идёт событие, его участники не гуляют, а сам дом живёт как обычно.
##
## Случайные события ("type": "random") — не у места, а «иногда»: "chance_per_min" — шанс за минуту,
## "who" — id, список или "*" (любой); что делать — "handler" (код ниже, параметры — в самом событии):
##   "nap"         — лечь спать где стоит (картинка смерти), смайлики zzz; "duration": [от, до] сек;
##   "stairs_fall" — на лестнице спрыгнуть вбок и полежать "lie" сек ("throw": [x, y] — скорость);
##   "eat"         — съесть персонажа рядом ("radius"), через "hold" сек выплюнуть; тот лежит "lie" сек
##                   и показывает смайлик из "reactions" (id -> смайлик);
##   "leave"       — дойти до двери (точка Door) и уйти из дома на "away": [от, до] сек.

const FILE := "res://data/hub/events.json"
const CHECK_EVERY := 0.25

var hub: Node
var running := false
var _events: Array = []
var _cooldown: Dictionary = {}
var _inside: Dictionary = {}
var _check := 0.0

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
			_run(ev, ws)
			return

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
	var ids: Array = walkers.keys() if String(who) == "*" else (who if who is Array else [who])
	ids.shuffle()
	var p := float(ev.get("chance_per_min", 1.0)) * CHECK_EVERY / 60.0
	for id in ids:
		var w: HomeWalker = walkers.get(String(id))
		if w == null or not _free(w) or w.on_bed() or not _random_ok(ev, w):
			continue
		if randf() >= p:
			continue
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

func _run_random(ev: Dictionary, w: HomeWalker) -> void:
	running = true
	match String(ev.get("handler", "")):
		"nap":
			await _h_nap(ev, w)
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
	if not is_instance_valid(w):
		return
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
	await _lie(w, _range(ev, "duration", Vector2(10, 18)), "zzz", 3.0)

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
	for w in ws:
		if is_instance_valid(w):
			(w as HomeWalker).set_frozen(false)
	_cooldown[String(ev.get("id", ""))] = float(ev.get("cooldown", 30.0))
	running = false
