extends Node
class_name BossCinematic
## Кинематографичная смена фазы босса (пока Фуфу): камера наезжает на босса, сверху и снизу
## чёрные полосы, интерфейс гаснет, босс что-то делает (маска трескается, разворачивается,
## призывает, глотает героиню…), потом всё возвращается и бой идёт дальше.
## Запускается сразу, как HP босса прошло порог (EnemyFufu кладёт номер фазы в me.ai["cine"]):
## в ход игрока — после разыгранной карты (CardBattle._process), в ход врагов — после действия.
## Пока идёт сцена, игрок ничего не может (CardBattle._busy).
## Что и в каком порядке происходит — data/battle/boss_fufu.json (шаги steps).

const CONFIG := "res://data/battle/boss_fufu.json"
const SCREEN := Vector2(1920, 1080)
## Над всем интерфейсом боя (UI — 1, автобой — 3), под окном итогов (10) и VN-окном.
const BARS_LAYER := 5

var battle: CardBattle
var _cfg: Dictionary = {}
var _camera: Camera2D
var _bars: CanvasLayer
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _focused := false

func setup(b: CardBattle) -> void:
	battle = b
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else null
	_cfg = parsed if parsed is Dictionary else {}
	_camera = Camera2D.new()
	_camera.name = "CinemaCamera"
	_camera.position = SCREEN * 0.5
	_camera.enabled = false
	battle.add_child(_camera)
	_bars = CanvasLayer.new()
	_bars.name = "CinemaBars"
	_bars.layer = BARS_LAYER
	battle.add_child(_bars)
	_bar_top = _make_bar()
	_bar_bottom = _make_bar()
	_place_bars(0.0)

## Ход игрока: как только бой свободен (карта разыграна, ничего не тащат, нет окна диалога) —
## показать ждущую сцену. В ход врагов сцены показывает сам CardBattle (после каждого действия).
func _process(_delta: float) -> void:
	if battle == null or battle._cine_running or battle._busy or battle._ended or battle._dragging != null:
		return
	if DialogueManager_ != null and DialogueManager_.is_showing():
		return
	if has_pending():
		battle._run_boss_cinematics()

func _make_bar() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color.BLACK
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.size = Vector2(SCREEN.x, _cam("bars", 120.0))
	_bars.add_child(r)
	return r

## k — насколько выехали полосы (0 — спрятаны, 1 — на месте).
func _place_bars(k: float) -> void:
	var h := _cam("bars", 120.0)
	_bar_top.position = Vector2(0, -h + h * k)
	_bar_bottom.position = Vector2(0, SCREEN.y - h * k)
	_bars.visible = k > 0.001

func _cam(key: String, fallback: float) -> float:
	return float((_cfg.get("camera", {}) as Dictionary).get(key, fallback))

# --- Очередь -------------------------------------------------------------------------

## Есть босс, у которого ждёт сцена смены фазы?
func has_pending() -> bool:
	return not next_pending().is_empty()

## {"unit": Unit, "idx": номер фазы в EnemyFufu.PHASES} или {}.
func next_pending() -> Dictionary:
	for u in battle.right_team:
		if u == null or not CardCombat.is_alive(u):
			continue
		var q: Array = u.ai.get("cine", [])
		if not q.is_empty():
			return {"unit": u, "idx": int(q[0])}
	return {}

## Показать сцену фазы idx у босса me (await).
func play(me: Unit, idx: int) -> void:
	var q: Array = me.ai.get("cine", [])
	q.erase(idx)
	me.ai["cine"] = q
	var phases: Array = _cfg.get("phases", [])
	if idx < 0 or idx >= phases.size():
		return
	var ph: Dictionary = phases[idx]
	battle._enemy_drag_portrait.hide_portrait()
	for step in ph.get("steps", []):
		if not CardCombat.is_alive(me) or battle._ended:
			break
		await _step(String(step), me, idx, ph)
	if _focused:
		await _unfocus()

func _step(step: String, me: Unit, idx: int, ph: Dictionary) -> void:
	var actor: BattleActor = battle._find_actor(me)
	match step:
		"focus":
			await _focus(actor)
		"unfocus":
			await _unfocus()
		"wait":
			await _wait(float(ph.get("wait", _cfg.get("wait", 0.5))))
		"lines":
			await _lines(ph)
		"phase":
			EnemyFufu.set_phase(me, idx + 2)
			_flash(actor)
			battle._refresh_actor(actor)
			await _wait(0.3)
		"crack_mask":
			EnemyFufu.set_phase(me, idx + 2)
			battle._refresh_actor(actor)
			_shake(actor)
			_fly_mask_part(actor, _cfg.get("mask_part", {}))
			await _wait(float((_cfg.get("mask_part", {}) as Dictionary).get("time", 1.0)) * 0.6)
		"unmask":
			# Остаток маски (белый кусок) отлетает с картинки фазы 2, потом — лицо без маски.
			_fly_mask_part(actor, _cfg.get("mask_part_white", {}))
			EnemyFufu.unmask(me)
			EnemyFufu.set_phase(me, idx + 2)
			_flash(actor)
			_shake(actor)
			battle._refresh_actor(actor)
			await _wait(0.7)
		"turn_away":
			await _turn(actor, true)
		"turn_back":
			await _turn(actor, false)
		"summon_minis", "summon_girls":
			if me.enemy_def != null and me.enemy_def.has_method("phase_action"):
				me.enemy_def.call("phase_action", battle._api, me, step)
			battle._refresh_all_actors()
			await _wait(0.7)
		"swallow":
			await _swallow(me, actor)
		_:
			push_warning("BossCinematic: нет шага «%s» (data/battle/boss_fufu.json)" % step)

# --- Камера, полосы, интерфейс ---------------------------------------------------------

func _ui_nodes() -> Array:
	var out: Array = []
	for p in ["UI/UIRoot", "UI/BottomPanel", "UI/Hud", "AutoLayer/AutoBattleButton"]:
		var n := battle.get_node_or_null(p) as CanvasItem
		if n != null:
			out.append(n)
	return out

func _focus(actor: BattleActor) -> void:
	await _focus_on(actor, _cam("zoom", 1.45))

## Камера на персонажа (полосы и приглушённый интерфейс — если ещё не было).
func _focus_on(actor: BattleActor, zoom: float) -> void:
	var t := _cam("time", 0.6)
	var target := _clamp_center((actor.global_position if actor != null else SCREEN * 0.5) - Vector2(0, _cam("lift", 150.0)), zoom)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not _focused:
		_camera.position = SCREEN * 0.5
		_camera.zoom = Vector2.ONE
		_camera.enabled = true
		_camera.make_current()
		tw.tween_method(_place_bars, 0.0, 1.0, t * 0.8)
		for n in _ui_nodes():
			tw.tween_property(n, "modulate:a", _cam("ui_alpha", 0.12), t * 0.6)
	_focused = true
	tw.tween_property(_camera, "position", target, t)
	tw.tween_property(_camera, "zoom", Vector2(zoom, zoom), t)
	await tw.finished

func _unfocus() -> void:
	_focused = false
	var t := _cam("time", 0.6)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_camera, "position", SCREEN * 0.5, t)
	tw.tween_property(_camera, "zoom", Vector2.ONE, t)
	tw.tween_method(_place_bars, 1.0, 0.0, t * 0.8)
	for n in _ui_nodes():
		tw.tween_property(n, "modulate:a", 1.0, t * 0.8)
	await tw.finished
	_camera.position = SCREEN * 0.5
	_camera.zoom = Vector2.ONE
	_camera.enabled = false

## Камера не выезжает за край фона.
func _clamp_center(p: Vector2, zoom: float) -> Vector2:
	var half := SCREEN * 0.5 / zoom
	return Vector2(clampf(p.x, half.x, SCREEN.x - half.x), clampf(p.y, half.y, SCREEN.y - half.y))

# --- Анимации -----------------------------------------------------------------------

func _wait(sec: float) -> void:
	await get_tree().create_timer(maxf(0.01, sec)).timeout

## Развернуться спиной / обратно: картинка сплющивается до полоски и раскрывается отражённой.
func _turn(actor: BattleActor, away: bool) -> void:
	if actor == null or actor.sprite == null:
		return
	var spr := actor.sprite
	var sx := spr.scale.x
	var tw := create_tween()
	tw.tween_property(spr, "scale:x", sx * 0.05, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	actor.face_away = away
	actor.update_visual()
	sx = spr.scale.x
	spr.scale.x = sx * 0.05
	tw = create_tween()
	tw.tween_property(spr, "scale:x", sx, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await _wait(0.15)

func _flash(actor: BattleActor) -> void:
	if actor == null or actor.sprite == null:
		return
	var spr := actor.sprite
	spr.modulate = Color(2.2, 2.2, 2.2, 1.0)
	create_tween().tween_property(spr, "modulate", Color.WHITE, 0.45)

func _shake(actor: BattleActor) -> void:
	if actor == null:
		return
	var base := actor.position
	var tw := create_tween()
	for i in 6:
		tw.tween_property(actor, "position", base + Vector2(randf_range(-10, 10), randf_range(-4, 4)), 0.04)
	tw.tween_property(actor, "position", base, 0.05)

## Осколок маски отлетает с того места на картинке, где он был (mask_part.at — пиксели картинки).
func _fly_mask_part(actor: BattleActor, mp: Dictionary) -> void:
	var path := String(mp.get("texture", ""))
	if actor == null or actor.sprite == null or path == "" or not ResourceLoader.exists(path):
		return
	var spr := actor.sprite
	var tex := spr.texture
	var at: Array = mp.get("at", [0, 0])
	var local := Vector2(float(at[0]) - tex.get_width() * 0.5, float(at[1]) - tex.get_height() * 0.5 + spr.offset.y)
	if spr.flip_h:
		local.x = -local.x
	var part := Sprite2D.new()
	part.name = "MaskPart"
	part.texture = load(path) as Texture2D
	part.flip_h = spr.flip_h
	part.scale = spr.global_scale
	part.z_index = 60
	battle.add_child(part)
	part.global_position = spr.get_global_transform() * local
	var fly: Array = mp.get("fly", [300, -250])
	var t := float(mp.get("time", 1.1))
	var dx := float(fly[0]) * (-1.0 if spr.flip_h else 1.0)
	var start := part.position
	var top := start + Vector2(dx * 0.45, float(fly[1]))
	var end := start + Vector2(dx, float(fly[1]) + float(mp.get("fall", 500)))
	var tw := part.create_tween().set_parallel(true)
	tw.tween_property(part, "position", top, t * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(part, "position", end, t * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN).set_delay(t * 0.4)
	tw.tween_property(part, "rotation", float(mp.get("spin", 5.0)) * signf(dx), t)
	tw.tween_property(part, "modulate:a", 0.0, t * 0.35).set_delay(t * 0.65)
	tw.chain().tween_callback(part.queue_free)

## Подойти к переднему персонажу, проглотить (EnemyFufu.swallow) и вернуться на место.
func _swallow(me: Unit, actor: BattleActor) -> void:
	var hero: Unit = battle._api.front_hero()
	var hero_actor: BattleActor = battle._find_actor(hero) if hero != null else null
	if actor == null or hero_actor == null:
		return
	CardActorFx.stop_idle(actor)
	var home := actor.global_position
	var to := hero_actor.global_position + Vector2(_cam("swallow_reach", 120.0), 0)
	# Камера отъезжает, чтобы видно было и Фуфу, и героиню, — потом Фуфу идёт.
	if _focused:
		var z := _cam("swallow_zoom", 1.2)
		var mid := _clamp_center((home + hero_actor.global_position) * 0.5 - Vector2(0, _cam("lift", 150.0)), z)
		var cz := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cz.tween_property(_camera, "position", mid, 0.5)
		cz.tween_property(_camera, "zoom", Vector2(z, z), 0.5)
		await cz.finished
	var tw := create_tween()
	tw.tween_property(actor, "global_position", to, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	# «Ам!» — героиня сжимается к Фуфу и пропадает.
	var hs := hero_actor.sprite
	var hscale := hs.scale
	tw = create_tween().set_parallel(true)
	tw.tween_property(actor, "global_position", to + Vector2(-90, 0), 0.12)
	tw.tween_property(hs, "scale", hscale * 0.2, 0.22).set_delay(0.05)
	tw.tween_property(hs, "modulate:a", 0.0, 0.22).set_delay(0.05)
	await tw.finished
	me.enemy_def.call("phase_action", battle._api, me, "swallow")
	hs.modulate.a = 1.0
	hero_actor.update_visual()
	hs.visible = false
	CardActorFx.hop(actor)
	await _wait(0.6)
	tw = create_tween()
	tw.tween_property(actor, "global_position", home, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	CardActorFx.start_idle(actor)
	battle._refresh_all_actors()

## Реплики отряда по очереди: камера на того, кто говорит, он подпрыгивает, над ним — пузырь.
## lines: {"<id героини>": [варианты], "any": [для всех остальных]} — у кого фраз нет, молчит.
## Говорят до speakers_max живых (видимых) героинь.
func _lines(ph: Dictionary) -> void:
	var speech = battle.get_node_or_null("%BattleSpeechLayer")
	var lines = ph.get("lines", {})
	if speech == null:
		return
	if lines is Array:
		lines = {"any": lines}
	var used: Array = []
	var said := 0
	for h in battle._combat.alive_heroes():
		if said >= int(ph.get("speakers_max", 2)):
			break
		var a: BattleActor = battle._find_actor(h)
		if a == null or a.sprite == null or not a.sprite.visible:
			continue
		var pool: Array = ((lines as Dictionary).get(h.data.id, (lines as Dictionary).get("any", [])) as Array).duplicate()
		for u in used:
			pool.erase(u)
		if pool.is_empty():
			continue
		var text := String(pool[randi() % pool.size()])
		used.append(text)
		await _focus_on(a, _cam("speaker_zoom", 1.35))
		CardActorFx.hop(a)
		speech.show_line_for_actor(a, text)
		said += 1
		await _wait(float(ph.get("line_time", 1.6)))
	if said > 0 and speech.has_method("clear_lines"):
		speech.clear_lines()
