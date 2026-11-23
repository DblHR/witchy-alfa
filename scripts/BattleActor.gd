extends Node2D
class_name BattleActor

@onready var sprite: Sprite2D = $Sprite

@onready var hp_label: Label = $HPLabel
@onready var hp_bar: ProgressBar = $HPBar

@onready var en_label: Label = $ENLabel
@onready var en_bar: ProgressBar = $ENBar

@onready var aps_label: Label = $APSLabel

@onready var effects_row: HBoxContainer = $EffectsRow
@onready var marker: TextureRect = $ENBar/EnergyThresholdMarker

@export var is_boss: bool = false
## Полоска HP: ширина у обычных и у босса (босс ещё и сам крупнее, × 1.35).
const HP_WIDTH := 150.0
const BOSS_HP_WIDTH := 210.0
## Щит — как в League of Legends: светлая полоска нарастает справа от текущего HP. Общая длина
## полоски не меняется: если HP + щит больше макс. HP, вся полоска делится между HP и щитом.
## Число щита — на значке щита слева от полоски.
const SHIELD_FILL := Color(0.90, 0.93, 1.0, 0.95)
const SHIELD_ICON := "res://assets/ui/battle/intent_apply_shield.png"
const SHIELD_ICON_SIZE := 58.0
const SHIELD_FONT := 22
var shield := 0
var _shield_icon: TextureRect
var _shield_num: Label
var _shield_fill: ColorRect
var unit: Unit
var is_left := true
var show_hp_overhead := true
var _flash_tween: Tween
var _cast_tween: Tween
var _attack_tween: Tween
var _base_position: Vector2 = Vector2.ZERO
var _base_actor_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_base_position = position
	_apply_visual_profile()

func _apply_visual_profile() -> void:
	# базовый вид
	_base_actor_scale = Vector2.ONE
	scale = _base_actor_scale

	# HPBar может быть разным типом (ProgressBar / TextureProgressBar).
	# Поэтому правим через size/scale осторожно.
	if is_boss:
		# 1) увеличить актёра
		_base_actor_scale = Vector2(1.35, 1.35)
		scale = _base_actor_scale

		# 2) полоска HP босса шире (по центру над ним)
		_set_hp_width(BOSS_HP_WIDTH)
	else:
		_set_hp_width(HP_WIDTH)

## Ширина полоски HP (и подписи на ней), по центру актёра.
func _set_hp_width(w: float) -> void:
	for c in [hp_bar, hp_label]:
		if c is Control:
			(c as Control).offset_left = -w * 0.5
			(c as Control).offset_right = w * 0.5
	_place_shield_icon()

func flash_red() -> void:
	if unit != null and unit.is_dead:
		return
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()

	sprite.modulate = Color(1, 0.35, 0.35, 1)

	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color(1, 1, 1, 1), 0.4)

func bind(u: Unit, _is_left: bool) -> void:
	unit = u
	is_left = _is_left
	_apply_visual_profile()
	update_visual()
	

func play_cast_bounce() -> void:
	if not is_inside_tree():
		return
	if _cast_tween != null and _cast_tween.is_running():
		return
	position = _base_position
	_cast_tween = create_tween()
	_cast_tween.set_trans(Tween.TRANS_SINE)
	_cast_tween.set_ease(Tween.EASE_OUT)
	_cast_tween.tween_property(self, "position", _base_position + Vector2(0, -18), 0.10)
	_cast_tween.set_ease(Tween.EASE_IN)
	_cast_tween.tween_property(self, "position", _base_position, 0.12)
	_cast_tween.finished.connect(func():
		position = _base_position
	)

func set_boss_mode(v: bool) -> void:
	is_boss = v
	_apply_visual_profile()

func _set_progress_fill_color(bar: ProgressBar, color: Color) -> void:
	if bar == null:
		return
	var fill = bar.get("theme_override_styles/fill")
	if fill is StyleBoxFlat:
		var sb: StyleBoxFlat = (fill as StyleBoxFlat).duplicate()
		sb.bg_color = color
		bar.add_theme_stylebox_override("fill", sb)

func update_visual() -> void:
	if unit == null:
		visible = false
		return

	# --- Debug marker: порог энергии для скилла ---
	# ВАЖНО: у многих врагов max_energy = 0. Деление приведёт к ошибке.
	# Также скилл может иметь cost=0 (или вообще ability=null) — тогда маркер не нужен.
	var cost := 0
	if unit.data != null and unit.data.skill_ability != null:
		cost = unit.data.skill_cost
		if unit.data.skill_ability.cost > 0:
			cost = unit.data.skill_ability.cost

	if marker != null and unit.max_energy > 0 and cost > 0:
		marker.visible = true
		var ratio := clampf(float(cost) / float(unit.max_energy), 0.0, 1.0)
		# Marker сидит внутри ENBar (Control). Используем local position.
		var x := en_bar.size.x * ratio
		marker.position = Vector2(x - marker.size.x * 0.5, marker.position.y)
	else:
		if marker != null:
			marker.visible = false

	visible = true

	# базовый спрайт
	sprite.texture = CharacterPhases.texture(unit.data.battle_texture, CharacterPhases.phase_of(unit))   ## фаза по HP
	var k := unit.data.battle_scale * unit.visual_scale
	sprite.scale = Vector2(k, k)
	sprite.offset.y = unit.data.battle_offset_y
	sprite.flip_h = is_left

	# если юнит умер — картинка смерти (<id>_dead.png), а если её нет — серый цвет; глушим «красные» твины
	if unit.is_dead:
		if _flash_tween and _flash_tween.is_running():
			_flash_tween.kill()
		var dead_tex := CharacterPhases.dead_texture(unit.data.battle_texture)
		if dead_tex != null:
			sprite.texture = dead_tex
			sprite.modulate = Color(1, 1, 1, 1)
		else:
			sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		# если сейчас идёт флэш — НЕ трогаем modulate, иначе он мгновенно станет белым
		if not (_flash_tween and _flash_tween.is_running()):
			sprite.modulate = Color(1, 1, 1, 1)

	# текст и полоска
	hp_label.text = "%d/%d" % [unit.hp, unit.max_hp]
	hp_bar.max_value = maxi(unit.max_hp, unit.hp + shield)
	hp_bar.value = unit.hp
	_apply_hp_bar_state()
	
	en_label.text = "%d/%d" % [unit.energy, unit.max_energy]
	en_bar.max_value = unit.max_energy
	en_bar.value = unit.energy

	var real_aps := unit.aps * unit.aps_mult
	var interval := 0.0
	if real_aps > 0.0:
		interval = 1.0 / real_aps
	aps_label.text = "APS: %.2f (%.2fs)" % [real_aps, interval]

	# показываем HP над головой только если включено и юнит жив
	var should_show := show_hp_overhead and not unit.is_dead
	hp_label.visible = should_show
	hp_bar.visible = should_show
	_place_shield_icon()

	# Иконки эффектов (для отладки читаемости)
	sync_effect_icons(unit)

func _apply_hp_bar_state() -> void:
	if unit == null or hp_bar == null:
		return
	var ratio := 0.0 if unit.max_hp <= 0 else float(unit.hp) / float(unit.max_hp)
	if unit.is_dead:
		_set_progress_fill_color(hp_bar, Color(0.45, 0.45, 0.45, 0.95))
		hp_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	elif ratio <= 0.30:
		_set_progress_fill_color(hp_bar, Color(0.92, 0.18, 0.18, 0.95))
		hp_label.modulate = Color(1.0, 0.85, 0.85, 1.0)
	else:
		_set_progress_fill_color(hp_bar, Color(0.18, 0.82, 0.32, 0.95))
		hp_label.modulate = Color(1, 1, 1, 1)

## Щит на юните (CardBattle обновляет при каждом изменении).
func set_shield(amount: int) -> void:
	shield = maxi(0, amount)
	if unit != null:
		update_visual()

## Значок щита с числом у левого края полоски HP и светлая полоска щита (видны, пока есть щит).
func _place_shield_icon() -> void:
	if hp_bar == null:
		return
	_place_shield_fill()
	if _shield_icon == null:
		if shield <= 0 or not ResourceLoader.exists(SHIELD_ICON):
			return
		_shield_icon = TextureRect.new()
		_shield_icon.name = "ShieldIcon"
		_shield_icon.texture = load(SHIELD_ICON) as Texture2D
		_shield_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_shield_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_shield_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shield_icon.size = Vector2(SHIELD_ICON_SIZE, SHIELD_ICON_SIZE)
		add_child(_shield_icon)
		_shield_num = Label.new()
		_shield_num.name = "Amount"
		_shield_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_shield_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_shield_num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shield_num.add_theme_font_size_override("font_size", SHIELD_FONT)
		_shield_num.add_theme_color_override("font_color", Color.WHITE)
		_shield_num.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.25, 1))
		_shield_num.add_theme_constant_override("outline_size", 6)
		_shield_num.position = Vector2(-10, 0)
		_shield_num.size = Vector2(SHIELD_ICON_SIZE + 20, SHIELD_ICON_SIZE)
		_shield_icon.add_child(_shield_num)
	var bar_h := hp_bar.offset_bottom - hp_bar.offset_top
	_shield_icon.position = Vector2(hp_bar.offset_left - SHIELD_ICON_SIZE * 0.7, hp_bar.offset_top + (bar_h - SHIELD_ICON_SIZE) * 0.5)
	_shield_icon.visible = shield > 0 and hp_bar.visible
	_shield_num.text = str(shield)

## Полоска щита внутри полоски HP: от конца HP на длину щита (в общих единицах max(макс. HP, HP + щит)).
func _place_shield_fill() -> void:
	if _shield_fill == null:
		if shield <= 0:
			return
		_shield_fill = ColorRect.new()
		_shield_fill.name = "ShieldFill"
		_shield_fill.color = SHIELD_FILL
		_shield_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hp_bar.add_child(_shield_fill)
	_shield_fill.visible = shield > 0 and unit != null and not unit.is_dead
	if not _shield_fill.visible:
		return
	var fill := hp_bar.get_theme_stylebox("fill")
	var m_t := fill.content_margin_top if fill != null else 0.0
	var m_b := fill.content_margin_bottom if fill != null else 0.0
	var w := hp_bar.size.x
	var total := maxf(1.0, float(hp_bar.max_value))
	var x0 := w * float(unit.hp) / total
	var x1 := minf(w, w * float(unit.hp + shield) / total)
	_shield_fill.position = Vector2(x0, maxf(0.0, m_t))
	_shield_fill.size = Vector2(maxf(2.0, x1 - x0), maxf(2.0, hp_bar.size.y - maxf(0.0, m_t) - maxf(0.0, m_b)))

func sync_effect_icons(unit: Unit) -> void:
	for c in effects_row.get_children():
		c.queue_free()

	var grouped: Dictionary = {}
	var group_order: Array[String] = []
	for e in unit.effects:
		if e == null or e.icon == null:
			continue
		var key := e.ui_stack_group_key()
		if key == "":
			key = str(e.icon)
		if not grouped.has(key):
			grouped[key] = {
				"effect": e,
				"count": 0,
				"time_left": e.ui_time_left(),
			}
			group_order.append(key)
		var entry: Dictionary = grouped[key]
		entry["count"] = int(entry.get("count", 0)) + max(1, e.ui_stack_count())
		entry["time_left"] = maxf(float(entry.get("time_left", 0.0)), e.ui_time_left())
		grouped[key] = entry

	for key in group_order:
		var entry: Dictionary = grouped[key]
		var e: StatusEffect = entry.get("effect", null)
		if e == null or e.icon == null:
			continue

		var holder := Control.new()
		holder.custom_minimum_size = Vector2(12, 12)
		holder.size = Vector2(12, 12)
		holder.clip_contents = false
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var tr := TextureRect.new()
		tr.texture = e.icon
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 0.0
		tr.offset_top = 0.0
		tr.offset_right = 0.0
		tr.offset_bottom = 0.0
		tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)

		var count := int(entry.get("count", 1))
		if count > 1:
			var count_bg := Panel.new()
			count_bg.position = Vector2(6, -2)
			count_bg.size = Vector2(9, 9)
			count_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.08, 0.02, 0.02, 0.88)
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			sb.corner_radius_bottom_left = 6
			sb.corner_radius_bottom_right = 6
			sb.border_color = Color(1, 0.92, 0.92, 0.9)
			sb.border_width_left = 1
			sb.border_width_top = 1
			sb.border_width_right = 1
			sb.border_width_bottom = 1
			count_bg.add_theme_stylebox_override("panel", sb)
			holder.add_child(count_bg)

			var count_label := Label.new()
			count_label.text = str(count)
			count_label.position = Vector2(6, -3)
			count_label.size = Vector2(9, 10)
			count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			count_label.add_theme_font_size_override("font_size", 7)
			count_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			count_label.add_theme_color_override("font_outline_color", Color(0.12, 0.0, 0.0, 1.0))
			count_label.add_theme_constant_override("outline_size", 2)
			count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(count_label)

		holder.tooltip_text = e.ui_name
		effects_row.add_child(holder)

func play_attack_bounce(direction: int) -> void:
	if _attack_tween != null and _attack_tween.is_running():
		return
	position = Vector2(_base_position.x, position.y)
	scale = _base_actor_scale
	_attack_tween = create_tween()
	_attack_tween.set_parallel(true)
	_attack_tween.tween_property(self, "position:x", _base_position.x + 6 * direction, 0.06)
	_attack_tween.tween_property(self, "position:x", _base_position.x, 0.08).set_delay(0.06)
	_attack_tween.tween_property(self, "scale:y", _base_actor_scale.y * 0.92, 0.06)
	_attack_tween.tween_property(self, "scale:y", _base_actor_scale.y, 0.08).set_delay(0.06)
	_attack_tween.finished.connect(func():
		position.x = _base_position.x
		scale = _base_actor_scale
	)

func show_battle_line(text: String) -> void:
	if text.strip_edges() == "":
		return
	var speech_layer := _find_battle_speech_layer()
	if speech_layer != null:
		speech_layer.show_line_for_actor(self, text)

func _find_battle_speech_layer() -> BattleSpeechLayer:
	var tree := get_tree()
	if tree == null:
		return null
	var current_scene := tree.current_scene
	if current_scene == null:
		return null
	return current_scene.get_node_or_null("%BattleSpeechLayer") as BattleSpeechLayer
