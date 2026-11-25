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
