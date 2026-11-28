extends Node
class_name ElitePrelude
## Вход в комнату элиты: героиня чем-то занята — бой начинается, когда игрок кликнет по ней.
##   Луиса спит (картинка смерти + «zzz» над головой);
##   Аки прыгает между «телами» (Луиса, сплющенные слизни) и приговаривает пузырями.
## Клик по ней — она «просыпается», CardBattle показывает фразу встречи (VN в первый раз,
## потом — короткая фраза пузырём) и начинает бой.
## Настройки — data/battle/elite_intros.json (ключ — id врага).

signal woken

const CONFIG := "res://data/battle/elite_intros.json"
## Высота «тела»-слизня на полу (px) и насколько сплющен.
const SLIME_BODY_HEIGHT := 170.0
const SLIME_BODY_SQUASH := Vector2(1.25, 0.55)
const BODY_TINT := Color(0.62, 0.6, 0.68)

var battle: CardBattle
var _cfg: Dictionary = {}
var _entry: Dictionary = {}
var _girl: Unit
var _actor: BattleActor
var _home := Vector2.ZERO
var _decor: Array[Node2D] = []
var _emote: Sprite2D
var _waiting := false
var _bark_left := 0.0
var _hop_left := 0.0
var _hop_i := 0
var _hopping := false

func setup(b: CardBattle) -> void:
	battle = b
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else null
	_cfg = parsed if parsed is Dictionary else {}

func is_waiting() -> bool:
	return _waiting

## Героиня этой комнаты занята своим делом; вернётся, когда по ней кликнут (wake).
func play(room: Dictionary) -> void:
	_girl = null
	for e in room.get("enemies", []):
		if _cfg.has(String(e)):
			for u in battle.right_team:
				if u != null and u.enemy_def != null and u.enemy_def.id == String(e):
					_girl = u
					_entry = _cfg[String(e)]
	if _girl == null:
		return
	_actor = battle._find_actor(_girl)
	if _actor == null:
		return
	_home = _actor.global_position
	match String(_entry.get("pose", "")):
		"sleep":
			_pose_sleep()
		"hop":
			_pose_hop()
	_waiting = true
	await woken
	await _restore()

## Короткая фраза при пробуждении (если VN-встреча уже была). true — сказала.
func say_wake_line() -> bool:
	if _actor == null:
		return false
	var line := _pick(_entry.get("wake_line", []))
	if line == "":
		return false
	return _say(line)

func wake() -> void:
	if not _waiting:
		return
	_waiting = false
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	woken.emit()

# --- Позы ------------------------------------------------------------------------

func _pose_sleep() -> void:
	CardActorFx.stop_idle(_actor)
	var dead := CharacterPhases.dead_texture(_girl.data.battle_texture)
	if dead != null:
		_actor.sprite.texture = dead
	var path := String(_entry.get("emote", ""))
	if path != "" and ResourceLoader.exists(path):
		_emote = Sprite2D.new()
		_emote.texture = load(path) as Texture2D
		_emote.scale = Vector2.ONE * (96.0 / float(maxi(1, _emote.texture.get_height())))
		_emote.z_index = 40
		battle.add_child(_emote)
		var top := _actor.sprite.global_position + Vector2(-60, -_actor.sprite.texture.get_height() * _actor.sprite.global_scale.y * 0.18)
		_emote.global_position = top
		var tw := _emote.create_tween().set_loops()
		tw.tween_property(_emote, "position:y", top.y - 22, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_emote, "position:y", top.y, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _pose_hop() -> void:
	CardActorFx.stop_idle(_actor)
	for b in _entry.get("bodies", []):
		if b is Dictionary:
			_add_body(b)
	_bark_left = 0.6
	_hop_left = 0.3
	_hop_i = 0

func _add_body(b: Dictionary) -> void:
	var id := String(b.get("id", ""))
	var s := Sprite2D.new()
	s.z_index = 0
	if bool(b.get("slime", false)):
		var def := EnemyDefs.get_def(id)
		var tex: Texture2D = def.char_data().battle_texture if def != null and def.char_data() != null else null
		if tex == null:
			return
		s.texture = tex
		var k := SLIME_BODY_HEIGHT / float(maxi(1, tex.get_height()))
		s.scale = Vector2(k, k) * SLIME_BODY_SQUASH
		s.modulate = BODY_TINT
		s.offset = Vector2(0, -tex.get_height() * 0.5)
	else:
		var cd := CharDB.get_by_id(id) if CharDB != null else null
		var base: Texture2D = cd.battle_texture if cd != null else null
		var tex := CharacterPhases.dead_texture(base) if base != null else null
		if tex == null:
			return
		s.texture = tex
		s.scale = _actor.sprite.global_scale
		s.offset = Vector2(0, -tex.get_height() * 0.5 + 60)
	battle.add_child(s)
	s.global_position = Vector2(float(b.get("x", 1400)), float(b.get("y", 760)))
	_decor.append(s)

func _process(delta: float) -> void:
	if not _waiting or _actor == null:
		return
	var over := battle._unit_at(battle.right_actors, battle.get_viewport().get_mouse_position()) == _girl
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over else Input.CURSOR_ARROW)
	if String(_entry.get("pose", "")) != "hop":
		return
	_bark_left -= delta
	if _bark_left <= 0.0:
		_bark_left = float(_entry.get("bark_every", 2.6))
		_say(_pick(_entry.get("bark", [])))
	_hop_left -= delta
	if _hop_left <= 0.0 and not _hopping and not _decor.is_empty():
		_hop_left = float(_entry.get("hop_every", 0.9))
		var to := _decor[_hop_i % _decor.size()].global_position + Vector2(-90, 0)
		_hop_i += 1
		_hop_to(to)

func _hop_to(to: Vector2) -> void:
	_hopping = true
	var from := _actor.global_position
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if is_instance_valid(_actor):
			_actor.global_position = from.lerp(to, k) + Vector2(0, -sin(k * PI) * 90.0), 0.0, 1.0, 0.45)
	tw.tween_callback(func() -> void: _hopping = false)

func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if battle._unit_at(battle.right_actors, (event as InputEventMouseButton).position) == _girl:
			get_viewport().set_input_as_handled()
			wake()

# --- Возврат к бою -----------------------------------------------------------------

func _restore() -> void:
	if _emote != null:
		_emote.queue_free()
		_emote = null
	for d in _decor:
		var tw := d.create_tween()
		tw.tween_property(d, "modulate:a", 0.0, 0.4)
		tw.tween_callback(d.queue_free)
	_decor.clear()
	if _actor == null or not is_instance_valid(_actor):
		return
	while _hopping:
		await get_tree().process_frame
	if _actor.global_position.distance_to(_home) > 2.0:
		var tw := create_tween()
		tw.tween_property(_actor, "global_position", _home, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	_actor.update_visual()
	CardActorFx.start_idle(_actor)
	CardActorFx.hop(_actor)
	await get_tree().create_timer(0.3).timeout

func _say(text: String) -> bool:
	var speech = battle.get_node_or_null("%BattleSpeechLayer")
	if speech == null or text == "":
		return false
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.party_size_override = battle._combat.alive_heroes().size()
		text = StoryDialogueDB_.hero_forms(text)
		StoryDialogueDB_.party_size_override = -1
	return speech.show_line_for_actor(_actor, text)

static func _pick(v) -> String:
	if v is Array:
		return String(v[randi() % v.size()]) if not (v as Array).is_empty() else ""
	return String(v)
