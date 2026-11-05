extends Control
class_name PathPopup
## Выбор пути: 1-3 «двери» следующей комнаты и полоса прогресса забега.
## Сигнал chosen(index) — номер выбранного варианта.

signal chosen(choice_index: int)

const PANEL_POS := Vector2(800, 150)
const PANEL_SIZE := Vector2(1060, 560)

func setup(run: CardRun) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := RunUiKit.make_panel(PANEL_POS, PANEL_SIZE)
	add_child(panel)

	var title := RunUiKit.make_label("Выберите путь", 44, RunUiKit.GOLD)
	title.position = Vector2(0, 18)
	title.size = Vector2(PANEL_SIZE.x, 56)
	panel.add_child(title)

	panel.add_child(_make_progress(run))

	var row := HBoxContainer.new()
	row.position = Vector2(30, 190)
	row.size = Vector2(PANEL_SIZE.x - 60, 330)
	row.add_theme_constant_override("separation", 22)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	for i in range(run.pending_choices.size()):
		row.add_child(_make_door(run.pending_choices[i], i))

func _make_progress(run: CardRun) -> Control:
	var bar := RunProgress.new()
	bar.position = Vector2(0, 100)
	bar.size = Vector2(PANEL_SIZE.x, 40)
	bar.setup(run.total_rooms(), run.index + 1)
	return bar

func _make_door(room: Dictionary, i: int) -> Button:
	var kind := String(room.get("kind", ""))
	var color := Color(1.0, 0.55, 0.5)
	if kind == "event":
		color = Color(0.6, 0.95, 0.75)
	elif kind == "boss":
		color = Color(1.0, 0.35, 0.35)
	var title := RunUiKit.make_label(CardRun.room_title(room), 38, color)
	var hint := RunUiKit.make_label(CardRun.room_hint(room), 24, RunUiKit.TEXT_DIM, true, true)
	hint.custom_minimum_size.y = 120
	var b := RunUiKit.make_option_button(Vector2(310, 300), [title, hint])
	b.pressed.connect(func() -> void:
		chosen.emit(i)
		queue_free()
	)
	return b
