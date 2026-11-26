extends Control
class_name HubChatter
## Фразы и смайлики над чибиками в доме (Hub).
##   say(walker, "текст")  — пузырь с фразой над головой (BattleSpeechLayer: по одному за раз);
##   emote(walker, "heart") — смайлик как в Arknights: assets/ui/emotes/<имя>.png (можно заменить
##                            своими картинками с теми же именами или добавить новые).
## Сами по себе персонажи время от времени говорят фразу или показывают смайлик — из файла
## assets/characters/<id>/hub/chatter.json:
##   "every": [от, до]  — раз во сколько секунд (случайно в этих пределах);
##   "emote_chance": 0.5 — доля смайликов (остальное — фразы);
##   "phrases": [...], "emotes": [...].
## События на местах и встречи — HubEvents.

const EMOTE_DIR := "res://assets/ui/emotes/"
const CHATTER_FILE := "res://assets/characters/%s/hub/chatter.json"
const EMOTE_SIZE := Vector2(96, 96)
const EMOTE_HOLD := 1.6
## Насколько пузырь фразы ниже точки над макушкой (плюс — ниже; смайлики не двигает).
const BUBBLE_DROP := 45.0
## Первая фраза — не раньше, чем через столько секунд после входа в дом.
const FIRST_DELAY := Vector2(6.0, 14.0)

var hub: Node
var _bubbles: BattleSpeechLayer
var _data: Dictionary = {}       ## id -> chatter.json
var _next: Dictionary = {}       ## id -> через сколько секунд следующая фраза
var _emotes: Dictionary = {}     ## walker -> текущий смайлик (Control)

func setup(p_hub: Node) -> void:
	hub = p_hub
	name = "HubChatter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubbles = BattleSpeechLayer.new()
	_bubbles.name = "Bubbles"
	_bubbles.bubble_offset = Vector2(0, BUBBLE_DROP)
	_bubbles.bubble_min_width = 220.0
	_bubbles.bubble_max_width = 420.0
	_bubbles.bubble_font_px = 26
	_bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubbles)

func bubble_layer() -> BattleSpeechLayer:
	return _bubbles

# --- Фраза и смайлик ------------------------------------------------------------------

## Фраза над головой. false — сейчас нельзя (идёт диалог / персонажа нет).
func say(w: HomeWalker, text: String) -> bool:
	if w == null or not is_instance_valid(w) or text == "" or _dialogue_open():
		return false
	return _bubbles.show_line_for_actor(w.head_anchor(), text)

## Смайлик над головой: всплывает, чуть покачивается и тает. Прошлый смайлик этого персонажа убирается.
func emote(w: HomeWalker, emote_name: String, hold: float = EMOTE_HOLD) -> bool:
	if w == null or not is_instance_valid(w) or _dialogue_open():
		return false
	var path := EMOTE_DIR + emote_name + ".png"
	if not ResourceLoader.exists(path):
		push_warning("HubChatter: нет смайлика " + path)
		return false
	if _emotes.has(w) and is_instance_valid(_emotes[w]):
		(_emotes[w] as Node).queue_free()
	var e := EmoteIcon.new()
	e.texture = load(path) as Texture2D
	e.target = w.head_anchor()
	e.size = EMOTE_SIZE
	e.hold = hold
	add_child(e)
	_emotes[w] = e
	return true

func _dialogue_open() -> bool:
	return DialogueManager_ != null and DialogueManager_.is_showing()

# --- Сами по себе ---------------------------------------------------------------------

func _chatter(id: String) -> Dictionary:
	if not _data.has(id):
		var d: Dictionary = {}
		var p := CHATTER_FILE % id
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				d = parsed
		_data[id] = d
	return _data[id]

func _process(delta: float) -> void:
	if hub == null or _dialogue_open():
		return
	var walkers: Dictionary = hub.get("walkers")
	for id in walkers:
		var w: HomeWalker = walkers[id]
		if not is_instance_valid(w):
			continue
		var c := _chatter(String(id))
		if c.is_empty():
			continue
		if not _next.has(id):
			_next[id] = randf_range(FIRST_DELAY.x, FIRST_DELAY.y)
		_next[id] = float(_next[id]) - delta
		if float(_next[id]) > 0.0:
			continue
		var every: Array = c.get("every", [25, 60])
		_next[id] = randf_range(float(every[0]), float(every[1]))
		if w.state in [HomeWalker.State.DRAG, HomeWalker.State.FLY, HomeWalker.State.FROZEN, HomeWalker.State.FALL]:
			continue
		if hub.has_method("event_running") and bool(hub.call("event_running")):
			continue
		var phrases: Array = c.get("phrases", [])
		var emotes: Array = c.get("emotes", [])
		var use_emote := not emotes.is_empty() and (phrases.is_empty() or randf() < float(c.get("emote_chance", 0.5)))
		if use_emote:
			emote(w, String(emotes[randi() % emotes.size()]))
		elif not phrases.is_empty():
			say(w, String(phrases[randi() % phrases.size()]))


## Смайлик: едет за головой персонажа.
class EmoteIcon extends TextureRect:
	var target: Node2D
	var hold := 1.6
	var _t := 0.0

	func _ready() -> void:
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		pivot_offset = Vector2(size.x * 0.35, size.y)   ## хвостик пузыря — снизу слева
		scale = Vector2(0.2, 0.2)
		modulate.a = 0.0
		_follow()
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(self, "scale", Vector2(1.12, 1.12), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "modulate:a", 1.0, 0.1)
		t.chain().tween_property(self, "scale", Vector2.ONE, 0.1)
		t.chain().tween_interval(hold)
		t.chain().tween_property(self, "modulate:a", 0.0, 0.3)
		t.chain().tween_callback(queue_free)

	func _process(delta: float) -> void:
		_t += delta
		if not is_instance_valid(target):
			queue_free()
			return
		_follow()

	func _follow() -> void:
		if not is_instance_valid(target):
			return
		var p := target.global_position
		position = p + Vector2(-size.x * 0.2, -size.y - 6.0 + sin(_t * 5.0) * 3.0)
