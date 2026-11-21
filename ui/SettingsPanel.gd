extends Panel
class_name SettingsPanel

## Окно «Настройки» в меню паузы:
##  - главный герой для диалогов и катсцен (StoryState_.main_hero, хранится в сохранении);
##    воин выбирается, только когда он уже есть в ростере;
##  - частота реплик в бою и между комнатами (GameSettings, общая для всех сохранений).

signal back_requested

const PANEL_SIZE := Vector2(560, 520)
const SELECTED_COLOR := Color(1.0, 0.62, 0.86)
const HERO_LABELS := {"witch": "Ведьмочка", "warrior": "Воин"}

var _hero_buttons: Dictionary = {}
var _hint: Label
var _back_btn: Button
var _banter_slider: HSlider
var _banter_caption: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	position = (Vector2(1920, 1080) - PANEL_SIZE) * 0.5
	GameUi.style_panel(self)
	_build()
	refresh()

func _build() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(40, 24)
	box.size = PANEL_SIZE - Vector2(80, 48)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = "Настройки"
	title.custom_minimum_size = Vector2(0, 70)
	GameUi.style_title(title, 52)
	box.add_child(title)

	var caption := Label.new()
	caption.text = "Главный герой в диалогах и катсценах"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUi.style_text(caption, 24)
	box.add_child(caption)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var group := ButtonGroup.new()
	for hero_id in HERO_LABELS.keys():
		var b := Button.new()
		b.text = String(HERO_LABELS[hero_id])
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(200, 56)
		GameUi.style_toggle(b, 26)
		b.pressed.connect(_on_hero_pressed.bind(String(hero_id)))
		row.add_child(b)
		_hero_buttons[hero_id] = b

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	GameUi.style_text(_hint, 19, 0.7)
	_hint.custom_minimum_size = Vector2(PANEL_SIZE.x - 80, 56)
	box.add_child(_hint)

	box.add_child(GameUi.separator())
	_banter_caption = Label.new()
	_banter_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	GameUi.style_text(_banter_caption, 24)
	box.add_child(_banter_caption)
	_banter_slider = HSlider.new()
	_banter_slider.min_value = GameSettings.BANTER_MIN
	_banter_slider.max_value = GameSettings.BANTER_MAX
	_banter_slider.step = GameSettings.BANTER_STEP
	_banter_slider.custom_minimum_size = Vector2(PANEL_SIZE.x - 80, 32)
	GameUi.style_slider(_banter_slider)
	_banter_slider.value_changed.connect(func(v: float) -> void:
		GameSettings.set_banter_percent(int(v))
		_refresh_banter_caption()
	)
	box.add_child(_banter_slider)

	_back_btn = Button.new()
	_back_btn.text = "Назад"
	_back_btn.custom_minimum_size = Vector2(0, 60)
	GameUi.style_button(_back_btn, 28)
	_back_btn.pressed.connect(func(): back_requested.emit())
	box.add_child(_back_btn)

## Подтягивает текущий выбор героя из StoryState (вызывать при каждом открытии).
func refresh() -> void:
	var has_warrior := UnitRoster_ != null and UnitRoster_.has_unit("warrior")
	var current := "witch"
	if StoryState_ != null:
		current = String(StoryState_.get_main_hero())
	for hero_id in _hero_buttons.keys():
		var b: Button = _hero_buttons[hero_id]
		var selected: bool = hero_id == current
		b.set_pressed_no_signal(selected)
		b.disabled = hero_id == "warrior" and not has_warrior
		# Выбранный герой — с галочкой и розовой кнопкой (GameUi.style_toggle).
		b.text = ("✓ " if selected else "") + String(HERO_LABELS[hero_id])
	if has_warrior:
		_hint.text = "Влияет на то, чьё имя и портрет будут в диалогах отношений и с НПС."
	else:
		_hint.text = "Выбор откроется, когда к вам присоединится Воин."
	_banter_slider.set_value_no_signal(GameSettings.banter_percent())
	_refresh_banter_caption()

func _refresh_banter_caption() -> void:
	var p := GameSettings.banter_percent()
	var word := "молчат" if p == 0 else ("редко" if p < 100 else ("обычно" if p == 100 else "часто"))
	_banter_caption.text = "Реплики героев в бою: %d%% (%s)" % [p, word]

func focus_default() -> void:
	if _back_btn != null:
		_back_btn.grab_focus()

func _on_hero_pressed(hero_id: String) -> void:
	if StoryState_ != null:
		StoryState_.set_main_hero(hero_id)
	refresh()
