extends Control
class_name SaveSlotMenu
## Выбор слота сохранения (главное меню): «Новая игра» — в какой слот начать (если там уже есть
## сохранение — переспрашивает), «Загрузить» — какое сохранение открыть (пустые слоты не нажать).
## Вид — как у паузы (GameUi). Esc: сначала закрывает вопрос, потом само окно.

signal slot_chosen(slot: int, new_game: bool)

const PANEL_SIZE := Vector2(720, 620)
const SLOT_SIZE := Vector2(620, 120)

var _new_game := false
var _title: Label
var _slots: Array[Button] = []
var _confirm: Control
var _confirm_text: Label
var _confirm_slot := 0

func _init() -> void:
	name = "SaveSlotMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	z_index = 20
	var dim := ColorRect.new()
	dim.color = GameUi.DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var panel := Panel.new()
	panel.size = PANEL_SIZE
	panel.position = (Vector2(1920, 1080) - PANEL_SIZE) * 0.5
	GameUi.style_panel(panel)
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(50, 24)
	box.size = PANEL_SIZE - Vector2(100, 48)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_title = Label.new()
	_title.custom_minimum_size = Vector2(0, 76)
	GameUi.style_title(_title, 50)
	box.add_child(_title)
	for i in range(1, SaveManager.SLOT_COUNT + 1):
		var b := Button.new()
		b.custom_minimum_size = SLOT_SIZE
		GameUi.style_button(b, 26)
		b.pressed.connect(_on_slot.bind(i))
		box.add_child(b)
		_slots.append(b)
	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(0, 60)
	GameUi.style_button(back, 28)
	back.pressed.connect(close)
	box.add_child(back)
	_build_confirm()
	EscClose.register(self, close)

func _build_confirm() -> void:
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.visible = false
	_confirm.z_index = 5
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = GameUi.DIM_COLOR
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var csize := Vector2(640, 330)
	var panel := Panel.new()
	panel.size = csize
	panel.position = (Vector2(1920, 1080) - csize) * 0.5
	GameUi.style_panel(panel)
	_confirm.add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(44, 28)
	box.size = csize - Vector2(88, 56)
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var t := Label.new()
	t.text = "Начать заново?"
	GameUi.style_title(t, 44)
	box.add_child(t)
	_confirm_text = Label.new()
	_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_text.custom_minimum_size = Vector2(csize.x - 88, 70)
	GameUi.style_text(_confirm_text, 24)
	box.add_child(_confirm_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var yes := Button.new()
	yes.text = "Да, начать"
	yes.custom_minimum_size = Vector2(240, 60)
	GameUi.style_button(yes, 26)
	yes.pressed.connect(func() -> void:
		_confirm.visible = false
		_choose(_confirm_slot))
	row.add_child(yes)
	var no := Button.new()
	no.text = "Отмена"
	no.custom_minimum_size = Vector2(240, 60)
	GameUi.style_button(no, 26)
	no.pressed.connect(func() -> void: _confirm.visible = false)
	row.add_child(no)
	EscClose.register(_confirm, func() -> void: _confirm.visible = false)

## Открыть: new_game — для новой игры, иначе — загрузка.
func open(new_game: bool) -> void:
	_new_game = new_game
	_title.text = "Новая игра" if new_game else "Загрузить игру"
	refresh()
	_confirm.visible = false
	visible = true

func close() -> void:
	visible = false

func refresh() -> void:
	for i in range(_slots.size()):
		var slot := i + 1
		var b := _slots[i]
		var info := SaveManager_.slot_info(slot) if SaveManager_ != null else {}
		if bool(info.get("exists", false)):
			var when := ""
			var t := int(info.get("saved_at", 0))
			if t > 0:
				var d := Time.get_datetime_dict_from_unix_time(t + _tz_bias())
				when = "  ·  %02d.%02d.%d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]
			var secs := int(info.get("play_time", -1))
			var played := "  ·  в игре %s" % SaveManager.format_play_time(secs) if secs >= 0 else ""
			b.text = "Слот %d%s\nУровень отряда %d  ·  %d зол.%s" % [slot, played, int(info.get("party_level", 1)), int(info.get("gold", 0)), when]
			b.disabled = false
		else:
			b.text = "Слот %d\nпусто" % slot
			b.disabled = not _new_game

static func _tz_bias() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60

func _on_slot(slot: int) -> void:
	if _new_game and SaveManager_ != null and SaveManager_.has_save(slot):
		_confirm_slot = slot
		_confirm_text.text = "В слоте %d уже есть сохранение — оно пропадёт." % slot
		_confirm.visible = true
		return
	_choose(slot)

func _choose(slot: int) -> void:
	visible = false
	slot_chosen.emit(slot, _new_game)
