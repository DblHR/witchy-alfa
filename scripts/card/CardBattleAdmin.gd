extends Control
class_name CardBattleAdmin
## Админ-панель боя (для тестов): кнопка «Админ» под «Выйти» раскрывает список действий.
## Сама ничего не решает — зовёт методы admin_* у CardBattle.

const POS := Vector2(1593, 142)
const WIDTH := 288.0

var _battle: CardBattle
var _toggle: Button
var _box: VBoxContainer
var _kill_button: Button
var _hint: Label

func _init() -> void:
	name = "BattleAdmin"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = POS
	z_index = 40

func setup(battle: CardBattle) -> void:
	_battle = battle
	_toggle = _make_button("Админ ▸", func() -> void: _set_open(not _box.visible))
	add_child(_toggle)
	_box = VBoxContainer.new()
	_box.position = Vector2(0, 52)
	_box.add_theme_constant_override("separation", 6)
	_box.visible = false
	add_child(_box)
	_box.add_child(_make_button("Вылечить союзников", func() -> void: _battle.admin_heal(true)))
	_box.add_child(_make_button("Вылечить противников", func() -> void: _battle.admin_heal(false)))
	_kill_button = _make_button("Убить цель…", func() -> void: _battle.admin_set_kill_mode(not _battle._admin_kill_mode))
	_box.add_child(_kill_button)
	_box.add_child(_make_button("Пройти комнату", func() -> void: _battle.admin_clear_room()))
	_box.add_child(_make_button("Проиграть", func() -> void: _battle.admin_lose()))
	_box.add_child(_make_button("Зарядить ульты", func() -> void: _battle.admin_charge_ults()))
	_hint = Label.new()
	_hint.text = "Кликните по любой цели\n(ПКМ — отмена)"
	_hint.visible = false
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.custom_minimum_size = Vector2(WIDTH, 0)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_hint.add_theme_constant_override("outline_size", 5)
	_box.add_child(_hint)

func _set_open(on: bool) -> void:
	_box.visible = on
	_toggle.text = "Админ ▾" if on else "Админ ▸"
	if not on and _battle._admin_kill_mode:
		_battle.admin_set_kill_mode(false)

func show_kill_mode(on: bool) -> void:
	_hint.visible = on
	_kill_button.text = "Отмена" if on else "Убить цель…"

func _make_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(WIDTH, 44)
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.11, 0.22, 0.92)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.15)
	var hover := sb.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.18, 0.36, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	return b
