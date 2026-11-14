extends CanvasLayer
class_name MainHeroChoicePopup

## Разовое окно «Кого вы хотите выбрать для диалогов и катсцен?» — показывается в хабе после
## того, как воин присоединился и отыграл свой диалог. Выбор пишется в StoryState_.main_hero
## и потом меняется в «Настройках» меню паузы.

signal chosen(hero_id: String)

const QUESTION := "Кого вы хотите выбрать для диалогов и катсцен?"
const FOOTNOTE := "*Это всегда можно изменить в настройках"
const OPTIONS := [["witch", "Ведьмочка"], ["warrior", "Воин"]]

## Показать окно, если воин уже есть, а выбор ещё не делали. Возвращает true, если показали.
static func show_if_needed(host: Node) -> bool:
	if StoryState_ == null or UnitRoster_ == null:
		return false
	if not UnitRoster_.has_unit("warrior"):
		return false
	if StoryState_.has_flag(StoryState_.MAIN_HERO_CHOSEN_FLAG):
		return false
	for child in host.get_children():
		if child is MainHeroChoicePopup:
			return true
	var popup := MainHeroChoicePopup.new()
	host.add_child(popup)
	return true

func _ready() -> void:
	layer = 60
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	margin.add_child(box)

	var q := Label.new()
	q.text = QUESTION
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.add_theme_font_size_override("font_size", 26)
	box.add_child(q)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	for opt in OPTIONS:
		var b := Button.new()
		b.text = String(opt[1])
		b.custom_minimum_size = Vector2(220, 60)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_on_pick.bind(String(opt[0])))
		row.add_child(b)

	var note := Label.new()
	note.text = FOOTNOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.modulate = Color(1, 1, 1, 0.65)
	note.add_theme_font_size_override("font_size", 16)
	box.add_child(note)

func _on_pick(hero_id: String) -> void:
	if StoryState_ != null:
		StoryState_.set_main_hero(hero_id)
	chosen.emit(hero_id)
	queue_free()
