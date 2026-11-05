extends Control
class_name FarmPot
## Один горшок фермы. Всё положение считается из FarmLayout, ручных смещений в сцене нет.
## Слои (снизу вверх): тень, свечение, РАСТЕНИЕ, горшок, мешочек с семенами, кнопка.
## Растение лежит позади горшка: горшки нарисованы снизу, и стебель должен расти из-за ободка.

signal pressed(slot_index: int)

@export var slot_index: int = 0

const _Layout := preload("res://scenes/FarmLayout.gd")   # preload: не зависит от кэша class_name

const SPROUT_MULT := 1.5          ## росток на арте мелкий — подтягиваем размер
const BAG_WIDTH_FRACTION := 0.30  ## ширина мешочка относительно ширины горшка
const SHADOW_COLOR := Color(0.12, 0.06, 0.10, 0.34)

static var _base_cache: Dictionary = {}

@onready var pot_sprite: TextureRect = $PotSprite
@onready var plant_anchor: Control = $PlantAnchor
@onready var plant_sprite: TextureRect = $PlantAnchor/PlantSprite
@onready var seed_bag_sprite: TextureRect = $SeedBagSprite
@onready var click_button: Button = $ClickButton

var _shadow: TextureRect
var _hover_glow: TextureRect
var _water_glow: TextureRect
var _hovered := false
var _water_tween: Tween
var _seed_base_modulate := Color(1, 1, 1, 1)
var _plant_base_modulate := Color(1, 1, 1, 1)
var _laid_out_for := -1
var _pot_scale := 1.0

func _ready() -> void:
	custom_minimum_size = Vector2.ZERO
	_build_effect_layers()
	click_button.pressed.connect(_on_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)
	refresh()

func _build_effect_layers() -> void:
	_shadow = _make_gradient_rect()
	_hover_glow = _make_gradient_rect()
	_water_glow = _make_gradient_rect()
	_shadow.modulate = Color(1, 1, 1, 1)
	_hover_glow.modulate.a = 0.0
	_water_glow.modulate.a = 0.0
	_set_gradient(_shadow, SHADOW_COLOR)
	_set_gradient(_hover_glow, Color(1.0, 0.95, 0.75, 0.55))
	_set_gradient(_water_glow, Color(0.5, 0.82, 1.0, 0.75))
	# Порядок: тень, свечение, вода — под растением и горшком.
	add_child(_shadow)
	add_child(_hover_glow)
	add_child(_water_glow)
	move_child(_shadow, 0)
	move_child(_hover_glow, 1)
	move_child(_water_glow, 2)
	# Растение — позади горшка.
	move_child(plant_anchor, 3)
	move_child(pot_sprite, 4)

func _make_gradient_rect() -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	return r

func _set_gradient(r: TextureRect, color: Color) -> void:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	r.texture = t

# ---------------------------------------------------------------------------
# Раскладка
# ---------------------------------------------------------------------------

func _apply_layout() -> void:
	var tex: Texture2D = AssetCatalog_.get_farm_pot_texture(slot_index) if AssetCatalog_ != null else null
	if tex == null:
		return
	_laid_out_for = slot_index
	var cfg := _Layout.slot(slot_index)
	var s: float = float(cfg["scale"])
	_pot_scale = s
	var anchor_local: Vector2 = _Layout.anchor(slot_index) * s
	var bbox: Rect2 = _Layout.bbox(slot_index)
	var tex_size := tex.get_size() * s

	# Сам контрол = текстура горшка; его позиция выбрана так, чтобы точка роста легла в anchor.
	position = (cfg["anchor"] as Vector2) - anchor_local
	size = tex_size
	pot_sprite.position = Vector2.ZERO
	pot_sprite.size = tex_size
	pot_sprite.texture = tex
	pot_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	plant_anchor.position = anchor_local
	plant_anchor.size = Vector2.ZERO

	# Мешочек с семенами — на лицевой стороне горшка, посередине между ободком и дном.
	var bbox_px := Rect2(bbox.position * s, bbox.size * s)
	var bag_center := Vector2(bbox_px.position.x + bbox_px.size.x * 0.5, lerpf(anchor_local.y, bbox_px.end.y, float(cfg.get("bag_t", 0.55))))
	seed_bag_sprite.set_meta("center", bag_center)
	seed_bag_sprite.set_meta("width", clampf(bbox_px.size.x * BAG_WIDTH_FRACTION, 34.0, 90.0))

	# Тень на полу.
	_shadow.visible = bool(cfg["shadow"])
	var sh_w := bbox_px.size.x * 1.05
	var sh_h := sh_w * 0.16
	_shadow.size = Vector2(sh_w, sh_h)
	_shadow.position = Vector2(bbox_px.position.x + bbox_px.size.x * 0.5 - sh_w * 0.5, bbox_px.end.y - sh_h * 0.55)

	# Свечения.
	var hg := Vector2(bbox_px.size.x * 1.5, bbox_px.size.y * 1.5)
	_hover_glow.size = hg
	_hover_glow.position = Vector2(bbox_px.position.x + bbox_px.size.x * 0.5, bbox_px.position.y + bbox_px.size.y * 0.5) - hg * 0.5
	var wg := Vector2(bbox_px.size.x * 1.1, bbox_px.size.x * 0.7)
	_water_glow.size = wg
	_water_glow.position = anchor_local - wg * 0.5

	# Кнопка клика: от верха растения до дна горшка.
	var plant_h := 280.0 * s * float(cfg["plant_mult"])
	var top := minf(anchor_local.y - plant_h, bbox_px.position.y)
	click_button.position = Vector2(bbox_px.position.x, top)
	click_button.size = Vector2(bbox_px.size.x, bbox_px.end.y - top)

## Нижняя точка стебля в пикселях текстуры (центр непрозрачных пикселей нижних строк).
static func _stem_base(tex: Texture2D) -> Vector2:
	var key := tex.resource_path
	if _base_cache.has(key):
		return _base_cache[key]
	var base := Vector2(tex.get_width() * 0.5, tex.get_height())
	var img := tex.get_image()
	if img != null:
		var w := img.get_width()
		var h := img.get_height()
		var y_bottom := -1
		for y in range(h - 1, -1, -1):
			for x in range(w):
				if img.get_pixel(x, y).a > 0.25:
					y_bottom = y
					break
			if y_bottom >= 0:
				break
		if y_bottom >= 0:
			var sum_x := 0.0
			var n := 0
			for y in range(maxi(0, y_bottom - 8), y_bottom + 1):
				for x in range(w):
					if img.get_pixel(x, y).a > 0.25:
						sum_x += x
						n += 1
			if n > 0:
				base = Vector2(sum_x / float(n), float(y_bottom))
	_base_cache[key] = base
	return base

func _place_plant(tex: Texture2D, mult: float) -> void:
	var cfg := _Layout.slot(slot_index)
	var ps := _pot_scale * float(cfg["plant_mult"]) * mult
	var base := _stem_base(tex)
	plant_sprite.texture = tex
	plant_sprite.stretch_mode = TextureRect.STRETCH_SCALE
	plant_sprite.size = tex.get_size() * ps
	plant_sprite.position = -base * ps

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------

func refresh() -> void:
	if not is_node_ready():
		return
	if _laid_out_for != slot_index:
		_apply_layout()
	var slot := FarmState_.get_slot(slot_index)
	var stage := int(slot.get("stage", FarmState.PlantStage.EMPTY))
	var needs_water := FarmState_.can_water_slot(slot_index)
	var seed_item_id := String(slot.get("seed_item_id", ""))
	var plant_item_id := String(slot.get("plant_item_id", ""))

	# Мешочек
	seed_bag_sprite.visible = stage != FarmState.PlantStage.EMPTY
	var bag_tex: Texture2D = null
	if seed_item_id != "":
		bag_tex = AssetCatalog_.get_farm_texture(FarmState_.get_seed_texture_key(slot)) if AssetCatalog_ != null else null
		if bag_tex == null and Inventory_ != null:
			bag_tex = Inventory_.get_item_icon(seed_item_id)
	seed_bag_sprite.texture = bag_tex
	if bag_tex != null and seed_bag_sprite.has_meta("center"):
		var w := float(seed_bag_sprite.get_meta("width"))
		var aspect := float(bag_tex.get_height()) / maxf(float(bag_tex.get_width()), 1.0)
		seed_bag_sprite.stretch_mode = TextureRect.STRETCH_SCALE
		seed_bag_sprite.size = Vector2(w, w * aspect)
		seed_bag_sprite.position = (seed_bag_sprite.get_meta("center") as Vector2) - seed_bag_sprite.size * 0.5

	# Растение
	plant_sprite.visible = false
	match stage:
		FarmState.PlantStage.SPROUT:
			var sprout: Texture2D = AssetCatalog_.get_farm_texture("sprout") if AssetCatalog_ != null else null
			if sprout != null:
				_place_plant(sprout, SPROUT_MULT)
				plant_sprite.visible = true
		FarmState.PlantStage.FLOWER:
			var flower: Texture2D = null
			if plant_item_id != "":
				flower = AssetCatalog_.get_farm_texture(FarmState_.get_plant_texture_key(slot)) if AssetCatalog_ != null else null
				if flower == null and Inventory_ != null:
					flower = Inventory_.get_item_icon(plant_item_id)
			if flower != null:
				_place_plant(flower, 1.0)
				plant_sprite.visible = true

	_seed_base_modulate = Color(0.62, 0.62, 0.62, 1.0) if stage == FarmState.PlantStage.SEED and needs_water else Color(1, 1, 1, 1)
	_plant_base_modulate = Color(0.62, 0.62, 0.62, 1.0) if stage == FarmState.PlantStage.SPROUT and needs_water else Color(1, 1, 1, 1)

	var can_interact := FarmState_.can_interact(slot_index)
	click_button.disabled = not can_interact
	click_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_interact else Control.CURSOR_ARROW
	click_button.tooltip_text = _build_tooltip(slot)
	_apply_hover_visual()

func _build_tooltip(slot: Dictionary) -> String:
	var stage := int(slot.get("stage", FarmState.PlantStage.EMPTY))
	if stage == FarmState.PlantStage.EMPTY:
		var available := FarmState_.get_available_seed_ids()
		if available.is_empty():
			return "Нет доступных семян."
		var names: Array[String] = []
		for seed_id in available:
			names.append(RunItems.get_item_name(seed_id))
		return "Выберите мешочек с семенами: %s" % ", ".join(names)
	if stage == FarmState.PlantStage.SEED:
		return "Посажено: %s\nНужно полить." % FarmState_.get_stage_label(slot)
	if stage == FarmState.PlantStage.SPROUT:
		return "Росток: %s\nНужно полить ещё раз." % FarmState_.get_stage_label(slot)
	if stage == FarmState.PlantStage.FLOWER:
		return "Созрел урожай: %s" % FarmState_.get_stage_label(slot)
	return ""

func play_water_flash() -> void:
	if _water_tween != null and _water_tween.is_valid():
		_water_tween.kill()
	_water_glow.modulate.a = 0.0
	_water_tween = create_tween()
	_water_tween.tween_property(_water_glow, "modulate:a", 1.0, 0.10)
	_water_tween.tween_interval(0.12)
	_water_tween.tween_property(_water_glow, "modulate:a", 0.0, 0.30)
	await _water_tween.finished
	_water_glow.modulate.a = 0.0
	_apply_hover_visual()

func _on_pressed() -> void:
	pressed.emit(slot_index)

func _on_mouse_entered() -> void:
	_hovered = true
	_apply_hover_visual()

func _on_mouse_exited() -> void:
	_hovered = false
	_apply_hover_visual()

func _apply_hover_visual() -> void:
	var highlight := _hovered and FarmState_.can_interact(slot_index)
	_hover_glow.modulate.a = 1.0 if highlight else 0.0
	var tint := Color(1.12, 1.07, 0.96, 1.0) if highlight else Color(1, 1, 1, 1)
	pot_sprite.modulate = tint
	seed_bag_sprite.modulate = Color(
		_seed_base_modulate.r * tint.r, _seed_base_modulate.g * tint.g,
		_seed_base_modulate.b * tint.b, _seed_base_modulate.a)
	plant_sprite.modulate = Color(
		_plant_base_modulate.r * tint.r, _plant_base_modulate.g * tint.g,
		_plant_base_modulate.b * tint.b, _plant_base_modulate.a)
