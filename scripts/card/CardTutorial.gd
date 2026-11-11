class_name CardTutorial
extends Control
## Обучение (один раз, после пролога «Новой игры»): бой ведьмочки с обычным слизнем.
## Подсказки по очереди подсвечивают части экрана, потом игрок сам разыгрывает карты
## и завершает ход — слизень побеждает ведьмочку, дальше в хабе диалог с Риккой.
##
## Тексты подсказок — в STEPS ниже. Реплики (вступление и Рикка после боя) — data/dialogues/story/tutorial.json.

## Выставляет пролог перед переходом в бой; бой проверяет и сбрасывает.
static var requested := false

const INTRO_DIALOGUE := "tutorial_intro"
const SLIME_PORTRAIT := "res://assets/pics/actorSprite/slime_green.png"
const ENEMY_ID := "shlep"
const ENEMY_HP := 260
## Флаг для хаба: после обучения показать диалог Рикки.
const RIKKA_FLAG := "pending_tutorial_rikka"
const RIKKA_DIALOGUE := "tutorial_rikka_after"

## target — что подсвечивать (см. _target_rects), panel — центр окна подсказки (экран 1920×1080).
const STEPS := [
	{"target": "hand", "panel": Vector2(960, 560),
		"text": "Это твоя рука. Здесь карты, которые можно разыграть в этот ход."},
	{"target": "hand_enemy", "panel": Vector2(700, 330),
		"text": "Карты атаки перетаскивают на противника. Карты защиты и поддержки — на своих."},
	{"target": "card", "panel": Vector2(960, 560),
		"text": "Каждая карта стоит энергию — число в её углу."},
	{"target": "energy", "panel": Vector2(960, 600),
		"text": "Энергия ограничена: каждый ход её столько, сколько показано здесь. Не хватает — карту не разыграть."},
	{"target": "discard", "panel": Vector2(1460, 640),
		"text": "В конце хода все неразыгранные карты уходят в стопку сброса."},
	{"target": "deck", "panel": Vector2(470, 700),
		"text": "Это стопка добора. Когда в ней заканчиваются карты, стопка сброса перемешивается и становится новой стопкой добора."},
	{"target": "card_kinds", "panel": Vector2(960, 560),
		"text": "Колода состоит из общих карт-филлеров и карт-умений персонажей."},
	{"target": "ult", "panel": Vector2(560, 520),
		"text": "Каждая разыгранная карта персонажа копит заряд его ульты. Полную ульту можно разыграть бесплатно, но она потратит все заряды."},
	{"target": "play", "panel": Vector2(960, 330), "free": true,
		"text": "Теперь самостоятельно: разыграй карты по слизню и заверши ход."},
]

const DIM := Color(0.02, 0.0, 0.05, 0.62)
const HOLE_PAD := 14.0
const MAX_HOLES := 4

const HOLES_SHADER := "shader_type canvas_item;
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 0.6);
uniform vec2 frame_size = vec2(1920.0, 1080.0);
uniform int hole_count = 0;
uniform vec4 holes[4];
uniform float radius = 18.0;
uniform float pulse = 0.0;

float box(vec2 p, vec4 r) {
	vec2 c = r.xy + r.zw * 0.5;
	vec2 q = abs(p - c) - r.zw * 0.5 + vec2(radius);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 p = UV * frame_size;
	float d = 1e6;
	for (int i = 0; i < 4; i++) {
		if (i < hole_count) {
			d = min(d, box(p, holes[i]));
		}
	}
	float outside = smoothstep(-1.5, 1.5, d);
	vec4 col = vec4(dim_color.rgb, dim_color.a * outside);
	float ring = (1.0 - smoothstep(0.0, 3.0, abs(d - 2.0))) * (0.55 + 0.45 * pulse);
	col = mix(col, vec4(1.0, 0.86, 0.45, 1.0), ring);
	COLOR = col;
}
"

signal finished

var battle: CardBattle
var _step := -1
var _dim: ColorRect
var _mat: ShaderMaterial
var _panel: PanelContainer
var _label: Label
var _next: Button
var _pulse_tween: Tween
var _done := false
var _free_play := false

func setup(p_battle: CardBattle) -> void:
	battle = p_battle
	name = "CardTutorial"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = Vector2(1920, 1080)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_dim = ColorRect.new()
	_dim.position = Vector2.ZERO
	_dim.size = size
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = HOLES_SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("dim_color", DIM)
	_mat.set_shader_parameter("frame_size", size)
	_dim.material = _mat
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.04, 0.12, 0.95)
	sb.border_color = RunUiKit.GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 22
	sb.content_margin_bottom = 22
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_label = Label.new()
	_label.custom_minimum_size = Vector2(620, 0)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_color_override("font_color", Color(1, 0.97, 1))
	box.add_child(_label)
	_next = RunUiKit.make_button("Далее  ▸", Vector2(200, 54), 26)
	_next.size_flags_horizontal = Control.SIZE_SHRINK_END
	_next.pressed.connect(_advance)
	box.add_child(_next)

	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	visible = false

## Вступление (ведьмочка замечает слизня), затем подсказки.
func begin() -> void:
	var lines := _intro_lines()
	if not lines.is_empty() and DialogueManager_ != null:
		DialogueManager_.show_sequence(lines)
		await get_tree().process_frame
		while DialogueManager_.is_showing():
			await get_tree().create_timer(0.1).timeout
	if _done:
		return
	visible = true
	_advance()

## Реплики вступления из tutorial.json; у слизня нет карточки персонажа — берём его спрайт.
func _intro_lines() -> Array:
	if StoryDialogueDB_ == null:
		return []
	var d := StoryDialogueDB_.get_dialogue(INTRO_DIALOGUE)
	if d.is_empty():
		return []
	var lines := StoryDialogueDB_.resolve_lines(d)
	var slime_tex := load(SLIME_PORTRAIT) as Texture2D
	for line in lines:
		for c in line.get("characters", []):
			if c is Dictionary and String(c.get("id", "")) == "slime":
				c["portrait"] = slime_tex
				c["name"] = "Слизень"
	return lines

func _gui_input(event: InputEvent) -> void:
	# Клик по затемнению тоже листает подсказки (но не в свободной игре).
	if not _free_play and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()

func _advance() -> void:
	_step += 1
	if _step >= STEPS.size():
		return
	var s: Dictionary = STEPS[_step]
	_free_play = bool(s.get("free", false))
	# В свободной игре затемнения нет и клики проходят в бой; подсвечены рука и «Завершить ход».
	mouse_filter = Control.MOUSE_FILTER_IGNORE if _free_play else Control.MOUSE_FILTER_STOP
	_mat.set_shader_parameter("dim_color", Color(DIM, 0.0) if _free_play else DIM)
	_next.visible = not _free_play
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if _free_play else Control.MOUSE_FILTER_STOP
	_label.text = String(s.get("text", ""))
	_set_holes(_target_rects(String(s.get("target", ""))))
	_place_panel(s.get("panel", Vector2(960, 540)))
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.2)

func _place_panel(center: Vector2) -> void:
	_panel.reset_size()
	var sz := _panel.get_combined_minimum_size()
	_panel.size = sz
	_panel.position = (center - sz * 0.5).clamp(Vector2(16, 16), size - sz - Vector2(16, 16))

## Прямоугольники подсветки (координаты экрана 1920×1080).
func _target_rects(target: String) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var hand := _hand_rect()
	match target:
		"hand":
			out.append(hand)
		"hand_enemy":
			out.append(hand)
			out.append_array(_enemy_rects())
		"card":
			var v := _first_card(false)
			if v != null:
				out.append(v.get_global_rect())
		"energy":
			out.append(battle.energy_label.get_global_rect())
		"discard":
			out.append(battle.discard_button.get_global_rect())
		"deck":
			out.append(battle.deck_button.get_global_rect())
		"card_kinds":
			for owned in [false, true]:
				var v2 := _first_card(true, owned)
				if v2 != null:
					out.append(v2.get_global_rect())
		"ult":
			out.append_array(battle.tutorial_ult_rects())
		"play":
			out.append(hand)
			out.append(battle.end_turn_button.get_global_rect())
	return out

func _hand_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for v in battle.tutorial_hand_views():
		var vr := v.get_global_rect()
		r = vr if first else r.merge(vr)
		first = false
	return r

func _enemy_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for a in battle.right_actors:
		if a != null and is_instance_valid(a):
			out.append(battle.tutorial_actor_rect(a))
	return out

## Первая карта руки; by_kind — искать карту персонажа (owned) или общую (не owned).
func _first_card(by_kind: bool, owned: bool = false) -> CardView:
	for v in battle.tutorial_hand_views():
		if not by_kind or (v.card.owner_id != "") == owned:
			return v
	return null

func _set_holes(rects: Array[Rect2]) -> void:
	var arr := PackedVector4Array()
	for r in rects:
		if arr.size() >= MAX_HOLES or r.size == Vector2.ZERO:
			continue
		var g := r.grow(HOLE_PAD)
		var lp := g.position - global_position
		arr.append(Vector4(lp.x, lp.y, g.size.x, g.size.y))
	var count := arr.size()
	while arr.size() < MAX_HOLES:
		arr.append(Vector4.ZERO)
	_mat.set_shader_parameter("holes", arr)
	_mat.set_shader_parameter("hole_count", count)

func _set_pulse(v: float) -> void:
	_mat.set_shader_parameter("pulse", v)

## Ход завершён: подсказки больше не нужны.
func on_turn_ended() -> void:
	_free_play = false
	create_tween().tween_property(_panel, "modulate:a", 0.0, 0.2)
	_set_holes([])

## Слизень победил (или игрок пропустил обучение): в хаб, там Рикка.
func finish(fade: bool = true) -> void:
	if _done:
		return
	_done = true
	if DialogueManager_ != null and DialogueManager_.is_showing():
		DialogueManager_.hide_overlay()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_set_holes([])
	if fade:
		await get_tree().create_timer(0.8).timeout
		var tw := create_tween()
		tw.tween_method(func(a: float) -> void: _mat.set_shader_parameter("dim_color", Color(0, 0, 0, a)), 0.0, 1.0, 0.7)
		await tw.finished
	mark_done()
	finished.emit()
	SceneRouter_.go_to_hub()

static func mark_done() -> void:
	if StoryState_ != null:
		StoryState_.tutorial_battle_pending = false
		StoryState_.tutorial_battle_completed = true
		StoryState_.set_flag(RIKKA_FLAG, true)
		StoryState_.changed.emit()
	if SaveManager_ != null:
		SaveManager_.save_game()
