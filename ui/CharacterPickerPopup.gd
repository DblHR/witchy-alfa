extends PopupPanel
class_name CharacterPickerPopup

signal character_chosen(character_id: String)

@onready var grid: GridContainer = $Root/Scroll/Grid
@onready var title_label: Label = $Root/Title

var _current_party_ids: Array[String] = []
var _slot_index: int = -1

func open_for(slot_index: int, current_party_ids: Array[String], allowed_ids: Array[String]) -> void:
	_slot_index = slot_index
	_current_party_ids = current_party_ids.duplicate()
	set_meta("slot_index", slot_index)
	title_label.text = "Выбор персонажа (слот %d)" % (slot_index + 1)
	_rebuild_buttons(allowed_ids)
	popup_centered(Vector2i(520, 360))

func _rebuild_buttons(allowed_ids: Array[String]) -> void:
	for c in grid.get_children():
		c.queue_free()

	# Важно: повторяться нельзя. Текущий слот — исключение (его выбор разрешён).
	var taken: Dictionary = {}
	for i in range(_current_party_ids.size()):
		if i == _slot_index:
			continue
		taken[_current_party_ids[i]] = true

	for id in allowed_ids:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 56)
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true

		if id == "":
			btn.text = "(пусто)"
		else:
			var data: CharacterData = CharDB.get_by_id(id)
			btn.text = data.display_name if data != null else id
			if data != null:
				var tex := data.card_portrait
				if tex == null:
					tex = data.icon
				if tex == null:
					tex = data.battle_texture
				btn.icon = tex
				btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
				btn.expand_icon = true
				btn.custom_minimum_size.y = 64

		var is_taken := taken.has(id) and id != ""
		if is_taken:
			btn.disabled = true
			btn.modulate = Color(0.6, 0.6, 0.6, 1)
			btn.tooltip_text = "Уже выбран в другом слоте"

		btn.pressed.connect(func():
			emit_signal("character_chosen", id)
			hide()
		)

		grid.add_child(btn)
