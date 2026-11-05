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

		# 2) увеличить HP bar
		# Если HPBar = Control (ProgressBar), у него есть size.
		if hp_bar is Control:
			var bar := hp_bar as Control
			bar.custom_minimum_size = Vector2(220, 18)  # можно подогнать
		else:
			# если вдруг не Control — просто чуть увеличим scale
			hp_bar.scale = Vector2(1.4, 1.4)

		# 3) опционально: увеличить шрифт/лейбл
		if hp_label is Label:
			# в Godot лучше менять theme/шрифт, но на старте можно scale
			hp_label.scale = Vector2(1.1, 1.1)

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
	sprite.texture = unit.data.battle_texture
	sprite.scale = Vector2(unit.data.battle_scale, unit.data.battle_scale)
	sprite.offset.y = unit.data.battle_offset_y
	sprite.flip_h = is_left

	# если юнит умер — фиксируем серый цвет и глушим любые "красные" твины
	if unit.is_dead:
		if _flash_tween and _flash_tween.is_running():
			_flash_tween.kill()
		sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
	else:
		# если сейчас идёт флэш — НЕ трогаем modulate, иначе он мгновенно станет белым
		if not (_flash_tween and _flash_tween.is_running()):
			sprite.modulate = Color(1, 1, 1, 1)

	# текст и полоска
	hp_label.text = "%d/%d" % [unit.hp, unit.max_hp]
	hp_bar.max_value = unit.max_hp
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
