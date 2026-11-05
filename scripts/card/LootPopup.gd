extends Control
class_name LootPopup
## Окно добычи после боя: что выпало с врагов в этой комнате (золото, опыт, слизь, кварц).
## Награда уже выдана в момент убийства — окно только показывает итог. Сигнал closed — «Дальше».

signal closed

const PANEL_POS := Vector2(800, 120)
const PANEL_SIZE := Vector2(1060, 700)
const ROW_H := 84

## loot: {gold: int, xp: int, items: {item_id: count}}
func setup(loot: Dictionary, title_text: String = "Добыча") -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := RunUiKit.make_panel(PANEL_POS, PANEL_SIZE)
	add_child(panel)

	var title := RunUiKit.make_label(title_text, 44, RunUiKit.GOLD)
	title.position = Vector2(0, 18)
	title.size = Vector2(PANEL_SIZE.x, 56)
	panel.add_child(title)
	var sub := RunUiKit.make_label("С врагов выпало", 24, RunUiKit.TEXT_DIM)
	sub.position = Vector2(0, 76)
	sub.size = Vector2(PANEL_SIZE.x, 32)
	panel.add_child(sub)

	var col := VBoxContainer.new()
	col.position = Vector2(120, 130)
	col.size = Vector2(PANEL_SIZE.x - 240, 440)
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	col.add_child(_row(null, "Золото", "+%d" % int(loot.get("gold", 0)), Color(1.0, 0.88, 0.4)))
	col.add_child(_row(null, "Опыт", "+%d" % int(loot.get("xp", 0)), Color(0.6, 0.85, 1.0)))
	var items: Dictionary = loot.get("items", {})
	for id in items.keys():
		var icon: Texture2D = null
		if Inventory_ != null:
			icon = Inventory_.get_item_icon(String(id))
		col.add_child(_row(icon, RunItems.get_item_name(String(id)), "×%d" % int(items[id]), Color.WHITE))

	var go := RunUiKit.make_button("Дальше", Vector2(260, 56), 26)
	go.position = Vector2((PANEL_SIZE.x - 260.0) * 0.5, PANEL_SIZE.y - 84.0)
	go.pressed.connect(func() -> void:
		closed.emit()
		queue_free()
	)
	panel.add_child(go)

func _row(icon: Texture2D, name_text: String, amount_text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_constant_override("separation", 18)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ROW_H, ROW_H)
	if icon != null:
		var tr := TextureRect.new()
		tr.texture = icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		holder.add_child(tr)
	row.add_child(holder)
	var n := RunUiKit.make_label(name_text, 34, Color.WHITE, false)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(n)
	var a := RunUiKit.make_label(amount_text, 40, color, false)
	a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(a)
	return row
