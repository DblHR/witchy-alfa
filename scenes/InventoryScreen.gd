extends Control

const _UiKit := preload("res://scripts/card/RunUiKit.gd")
const _CardLib := preload("res://scripts/card/CardLibrary.gd")
const ENTRY_BUTTON_SCENE := preload("res://scenes/ui/inventory/InventoryEntryButton.tscn")

enum Section {
	ITEMS,
	RECIPES,
	LORE,
	CHARACTERS,
	GALLERY,
}

const SECTION_TITLES := {
	Section.ITEMS: "Все предметы",
	Section.RECIPES: "Рецепты алхимии",
	Section.LORE: "Лорные записи ведьмочки",
	Section.CHARACTERS: "Открытые персонажи",
	Section.GALLERY: "Галерея",
}

@onready var gold_label: Label = %GoldLabel
@onready var xp_label: Label = %XpLabel
@onready var level_label: Label = %LevelLabel
@onready var section_title_label: Label = %SectionTitleLabel
@onready var entries_scroll: ScrollContainer = %EntriesScroll
@onready var grid_container: GridContainer = %EntryGrid
@onready var detail_title_label: Label = %DetailTitleLabel
@onready var detail_hint_label: Label = %DetailHintLabel
@onready var save_button: Button = %SaveButton
@onready var back_button: TextureButton = %BackButton
@onready var alchemy_button: TextureButton = %AlchemyButton
@onready var general_button: TextureButton = %GeneralButton
@onready var lore_button: TextureButton = %LoreButton
@onready var characters_button: TextureButton = %CharactersButton
@onready var gallery_button: TextureButton = %GalleryButton
@onready var item_detail: Control = %ItemDetail
@onready var item_icon: TextureRect = %ItemIcon
@onready var item_name: Label = %ItemName
@onready var item_kind: Label = %ItemKind
@onready var item_desc: RichTextLabel = %ItemDescription
@onready var character_detail: Control = %CharacterDetail
@onready var character_sprite: TextureRect = %CharacterSprite
@onready var character_name: Label = %CharacterName
@onready var character_stats: RichTextLabel = %CharacterStats
@onready var lore_detail: Control = %LoreDetail
@onready var lore_body: RichTextLabel = %LoreBody
@onready var placeholder_detail: Control = %PlaceholderDetail
@onready var placeholder_text_label: Label = %PlaceholderText
@onready var footer_label: Label = %FooterLabel
@onready var lore_database: LoreDatabase = %LoreDatabase

var current_section: int = Section.ITEMS
var selected_entry_by_section: Dictionary = {}

func _ready() -> void:
	UIThemeHelper.apply_pink_theme(self)
	get_tree().paused = false
	_save_default_selection_ids()
	_save_button_connections()
	_subscribe_state()
	_build_cards_ui()
	_build_gallery_ui()
	_build_admin_ui()
	_select_section(Section.ITEMS)

func _exit_tree() -> void:
	if DungRun != null and DungRun.changed.is_connected(_refresh_header):
		DungRun.changed.disconnect(_refresh_header)
	if Inventory_ != null and Inventory_.changed.is_connected(_refresh_current_section):
		Inventory_.changed.disconnect(_refresh_current_section)
	if UnitRoster_ != null and UnitRoster_.changed.is_connected(_refresh_current_section):
		UnitRoster_.changed.disconnect(_refresh_current_section)

func _save_default_selection_ids() -> void:
	for section in [Section.ITEMS, Section.RECIPES, Section.LORE, Section.CHARACTERS, Section.GALLERY]:
		selected_entry_by_section[section] = ""

func _save_button_connections() -> void:
	save_button.pressed.connect(_on_save_pressed)
	back_button.pressed.connect(func() -> void:
		SceneRouter_.go_to_hub()
	)
	general_button.pressed.connect(func() -> void: _select_section(Section.ITEMS))
	alchemy_button.pressed.connect(func() -> void: _select_section(Section.RECIPES))
	lore_button.pressed.connect(func() -> void: _select_section(Section.LORE))
	characters_button.pressed.connect(func() -> void: _select_section(Section.CHARACTERS))
	gallery_button.pressed.connect(func() -> void: _select_section(Section.GALLERY))
	gallery_button.tooltip_text = "Галерея"
	general_button.tooltip_text = "Все предметы на одной вкладке"
	alchemy_button.tooltip_text = "Список рецептов для алхимии"
	lore_button.tooltip_text = "Лорные записи"
	characters_button.tooltip_text = "Персонажи"
	back_button.tooltip_text = "Назад в хаб"

func _subscribe_state() -> void:
	if DungRun != null and not DungRun.changed.is_connected(_refresh_header):
		DungRun.changed.connect(_refresh_header)
	if Inventory_ != null and not Inventory_.changed.is_connected(_refresh_current_section):
		Inventory_.changed.connect(_refresh_current_section)
	if UnitRoster_ != null and not UnitRoster_.changed.is_connected(_refresh_current_section):
		UnitRoster_.changed.connect(_refresh_current_section)
	_refresh_header()

func _on_save_pressed() -> void:
	SaveManager_.save_game()
	footer_label.text = "Сохранение записано."

func _refresh_header() -> void:
	gold_label.text = "%d" % int(DungRun.gold)
	xp_label.text = "Опыт: %d / %d" % [int(DungRun.xp), int(DungRun.xp_to_next_level())]
	level_label.text = "Уровень группы: %d" % int(DungRun.party_level)

func _refresh_current_section() -> void:
	_select_section(current_section, false)

func _select_section(section: int, reset_status: bool = true) -> void:
	current_section = section
	section_title_label.text = SECTION_TITLES.get(section, "Инвентарь")
	general_button.button_pressed = section == Section.ITEMS
	alchemy_button.button_pressed = section == Section.RECIPES
	lore_button.button_pressed = section == Section.LORE
	characters_button.button_pressed = section == Section.CHARACTERS
	gallery_button.button_pressed = section == Section.GALLERY
	_gallery_group_box.visible = section == Section.GALLERY
	if section != Section.GALLERY:
		_gallery_panel.visible = false
	if reset_status:
		footer_label.text = ""
	_rebuild_entry_grid()

func _rebuild_entry_grid() -> void:
	for child in grid_container.get_children():
		child.queue_free()
	var entries := _build_entries_for_section(current_section)
	grid_container.columns = _get_columns_for_section(current_section)
	entries_scroll.scroll_vertical = 0
	if entries.is_empty():
		_show_empty_detail_for_section()
		return
	var selected_id := String(selected_entry_by_section.get(current_section, ""))
	if selected_id == "" or not _entries_have_id(entries, selected_id):
		selected_id = String(entries[0].get("id", ""))
		selected_entry_by_section[current_section] = selected_id
	for entry in entries:
		var button: InventoryEntryButton = ENTRY_BUTTON_SCENE.instantiate()
		entry["selected"] = String(entry.get("id", "")) == selected_id
		grid_container.add_child(button)
		button.setup(entry)
		button.entry_pressed.connect(_on_entry_pressed)
	_show_entry_detail(selected_id)

func _entries_have_id(entries: Array[Dictionary], entry_id: String) -> bool:
	for entry in entries:
		if String(entry.get("id", "")) == entry_id:
			return true
	return false

func _on_entry_pressed(entry_id: String) -> void:
	selected_entry_by_section[current_section] = entry_id
	_rebuild_entry_grid()

func _build_entries_for_section(section: int) -> Array[Dictionary]:
	match section:
		Section.ITEMS:
			return _build_item_entries()
		Section.RECIPES:
			return _build_recipe_entries()
		Section.LORE:
			return _build_lore_entries()
		Section.CHARACTERS:
			return _build_character_entries()
		Section.GALLERY:
			return _build_gallery_entries()
	return []

func _build_item_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if Inventory_ == null:
		return out
	for entry in Inventory_.get_sorted_item_entries():
		out.append({
			"id": String(entry.get("id", "")),
			"title": String(entry.get("name", "")),
			"subtitle": RunItems.get_item_kind_label(String(entry.get("id", ""))),
			"count": int(entry.get("count", 0)),
			"icon": entry.get("icon", null),
			"compact": true,
		})
	return out

func _build_recipe_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for recipe_id in AlchemyDB.get_recipe_ids():
		var result_item_id := AlchemyDB.get_result_item_id(recipe_id)
		out.append({
			"id": recipe_id,
			"title": AlchemyDB.get_recipe_name(recipe_id),
			"subtitle": RunItems.get_item_name(result_item_id),
			"count": -1,
			"icon": Inventory_.get_item_icon(result_item_id) if Inventory_ != null else null,
			"compact": true,
		})
	return out

func _build_lore_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if lore_database == null:
		return out
	for entry: LoreEntryData in lore_database.get_entries():
		if entry == null:
			continue
		out.append({
			"id": entry.id,
			"title": entry.title,
			"subtitle": _excerpt(entry.body),
			"icon": entry.icon,
			"count": -1,
			"compact": false,
		})
	return out

func _build_character_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if UnitRoster_ == null or CharDB == null:
		return out
	for unit_id in UnitRoster_.get_unlocked_unit_ids():
		var data: CharacterData = CharDB.get_by_id(unit_id)
		if data == null:
			continue
		out.append({
			"id": unit_id,
			"title": data.display_name,
			"subtitle": "",
			"icon": _get_character_avatar(data),
			"count": -1,
			"compact": true,
		})
	return out

func _get_columns_for_section(section: int) -> int:
	match section:
		Section.LORE:
			return 1
		Section.CHARACTERS:
			return 4
		Section.GALLERY:
			return 2
		_:
			return 4

func _show_entry_detail(entry_id: String) -> void:
	_match_detail_visibility(false, false, false, false)
	match current_section:
		Section.ITEMS:
			_show_item_detail(entry_id)
		Section.RECIPES:
			_show_recipe_detail(entry_id)
		Section.LORE:
			_show_lore_detail(entry_id)
		Section.CHARACTERS:
			_show_character_detail(entry_id)
		Section.GALLERY:
			_show_gallery_category(entry_id)

func _show_empty_detail_for_section() -> void:
	_match_detail_visibility(false, false, false, true)
	detail_title_label.text = SECTION_TITLES.get(current_section, "Инвентарь")
	detail_hint_label.text = ""
	var placeholder_text := "Пока здесь пусто."
	if current_section == Section.GALLERY:
		placeholder_text = "Здесь пока нет картинок."
	elif current_section == Section.CHARACTERS:
		placeholder_text = "Персонажи ещё не открыты."
	placeholder_text_label.text = placeholder_text

func _show_item_detail(item_id: String) -> void:
	_match_detail_visibility(true, false, false, false)
	detail_title_label.text = "Карточка предмета"
	detail_hint_label.text = "На этой вкладке лежат все типы предметов: посохи, еда, зелья, ингредиенты и семена."
	item_icon.texture = Inventory_.get_item_icon(item_id)
	item_name.text = RunItems.get_item_name(item_id)
	var rarity := RunItems.get_item_rarity_label(item_id)
	item_kind.text = RunItems.get_item_kind_label(item_id) if rarity == "" else "%s • %s" % [RunItems.get_item_kind_label(item_id), rarity]
	item_desc.text = "%s\n\nКоличество: %d" % [RunItems.get_item_desc(item_id), Inventory_.get_item_count(item_id)]

func _show_recipe_detail(recipe_id: String) -> void:
	_match_detail_visibility(true, false, false, false)
	detail_title_label.text = "Карточка рецепта"
	detail_hint_label.text = "Вкладка рецептов показывает требования и позволяет быстро сверить наличие ингредиентов."
	var result_item_id := AlchemyDB.get_result_item_id(recipe_id)
	item_icon.texture = Inventory_.get_item_icon(result_item_id)
	item_name.text = AlchemyDB.get_recipe_name(recipe_id)
	item_kind.text = "Рецепт → %s" % RunItems.get_item_name(result_item_id)
	var ingredient_lines: Array[String] = []
	for ingredient_id in AlchemyDB.get_ingredients(recipe_id).keys():
		var need := int(AlchemyDB.get_ingredients(recipe_id)[ingredient_id])
		var have := Inventory_.get_item_count(String(ingredient_id)) if Inventory_ != null else 0
		ingredient_lines.append("• %s: %d / %d" % [RunItems.get_item_name(String(ingredient_id)), have, need])
	ingredient_lines.sort()
	item_desc.text = "%s\n\nИнгредиенты:\n%s\n\nМожно создать сейчас: %s" % [
		RunItems.get_item_desc(result_item_id),
		"\n".join(ingredient_lines),
		("да" if AlchemyDB.can_craft(recipe_id) else "нет"),
	]

func _show_lore_detail(entry_id: String) -> void:
	if lore_database == null:
		return
	_match_detail_visibility(false, false, true, false)
	detail_title_label.text = "Лорные записи ведьмочки"
	detail_hint_label.text = "Позже сюда можно добавить выделения, картинки и пометки."
	for entry: LoreEntryData in lore_database.get_entries():
		if entry != null and entry.id == entry_id:
			lore_body.text = "[center][b]%s[/b][/center]\n\n%s" % [entry.title, entry.body]
			return
	lore_body.text = "пока здесь пусто"

func _show_character_detail(unit_id: String) -> void:
	_match_detail_visibility(false, true, false, false)
	detail_title_label.text = "Карточка персонажа"
	detail_hint_label.text = "Слева — открытые персонажи, справа — подробности по выбранному."
	var data: CharacterData = CharDB.get_by_id(unit_id)
	if data == null:
		_show_empty_detail_for_section()
		return
	var stats := data.stats_for_level(max(1, int(DungRun.party_level)))
	character_sprite.texture = data.battle_texture if data.battle_texture != null else _get_character_avatar(data)
	character_name.text = data.display_name
	var desc := data.codex_description.strip_edges()
	if desc == "":
		desc = _build_default_character_description(data)
	var notes := data.codex_notes.strip_edges()
	if notes == "":
		notes = "Позже здесь можно добавить личное описание персонажа, реплики и интересные факты."
	_current_char_id = unit_id
	_rank_label.text = "Ранг %s • карт до %d" % [data.rank, data.card_cap()]
	var owned := _CardLib.owned_defs(data).size()
	_cards_button.text = "Все карты (%d/%d)" % [owned, data.card_pool.size() + data.unlock_cards.size()]
	_cards_button.disabled = owned == 0 and data.unlock_cards.is_empty() and data.ult_card == null
	var passive_text := ""
	if data.card_passive != null and data.card_passive.description.strip_edges() != "":
		passive_text = "\n[b]Пассивка:[/b] %s\n" % data.card_passive.description.strip_edges()
	passive_text = _relationship_text(data) + passive_text
	character_stats.text = "[b]Класс:[/b] %s\n[b]HP:[/b] %d\n[b]Атака:[/b] %d\n[b]Магия:[/b] %d\n[b]Энергия ульты:[/b] %d\n%s\n[b]Описание:[/b]\n%s\n\n[b]Заметки:[/b]\n%s" % [
		data.unit_class,
		int(stats.get("max_hp", data.base_hp)),
		int(stats.get("attack", data.attack)),
		int(stats.get("magic", data.magic)),
		data.max_energy,
		passive_text,
		desc,
		notes,
	]

func _match_detail_visibility(show_item: bool, show_character: bool, show_lore: bool, show_placeholder: bool) -> void:
	item_detail.visible = show_item
	character_detail.visible = show_character
	lore_detail.visible = show_lore
	placeholder_detail.visible = show_placeholder
	if _gallery_panel != null:
		_gallery_panel.visible = false

func _excerpt(text: String, max_len: int = 80) -> String:
	var clean := text.replace("\n", " ").strip_edges()
	if clean.length() <= max_len:
		return clean
	return clean.substr(0, max_len - 1) + "…"

func _get_character_avatar(data: CharacterData) -> Texture2D:
	if data.card_portrait != null:
		return data.card_portrait
	if data.icon != null:
		return data.icon
	return data.battle_texture

func _build_default_character_description(data: CharacterData) -> String:
	return "%s — %s. Базовое описание пока не заполнено, но раздел уже готов для ручной доработки через ресурсы персонажей." % [data.display_name, data.unit_class]

func _get_ability_name(ability: Ability, fallback_name: String) -> String:
	if ability != null and ability.name.strip_edges() != "":
		return ability.name
	return fallback_name


# --- Все карты персонажа ------------------------------------------------------

var _current_char_id: String = ""
var _rank_label: Label = null
var _cards_button: Button = null
var _cards_overlay: Control = null
var _cards_grid: GridContainer = null
var _locked_title: Label = null
var _locked_grid: GridContainer = null

var _cards_title: Label = null
var _ult_title: Label = null
var _ult_row: HBoxContainer = null

## Строка отношений для досье.
func _relationship_text(data: CharacterData) -> String:
	if UnitRoster_ == null:
		return ""
	var prog := UnitRoster_.trust_progress(data.id)
	var rel := int(prog["level"])
	var mx := UnitRoster.RELATIONSHIP_MAX
	var bar := "[color=#ff7fc8]%s[/color][color=#6a5a70]%s[/color]" % ["■".repeat(rel), "■".repeat(mx - rel)]
	var text := "[b]Отношения:[/b] %s %d/%d" % [bar, rel, mx]
	if rel < mx:
		text += "\n[b]Доверие:[/b] %d/%d до следующего уровня (+1 за забег в отряде)" % [int(prog["into_level"]), int(prog["need"])]
	if not data.unlock_cards.is_empty():
		var levels := PackedStringArray()
		for i in range(data.unlock_cards.size()):
			levels.append(str(_CardLib.unlock_level(data, i)))
		text += "\n[b]Карты за отношения:[/b] на уровнях %s" % ", ".join(levels)
	return text + "\n"

func _build_cards_ui() -> void:
	_rank_label = Label.new()
	_rank_label.position = Vector2(300, 100)
	_rank_label.size = Vector2(260, 30)
	_rank_label.add_theme_font_size_override("font_size", 20)
	_rank_label.add_theme_color_override("font_color", Color(0.3, 0.14, 0.36))
	character_detail.add_child(_rank_label)
	_cards_button = Button.new()
	_cards_button.name = "AllCardsButton"
	_cards_button.position = Vector2(300, 140)
	_cards_button.size = Vector2(260, 52)
	_cards_button.text = "Все карты"
	_cards_button.pressed.connect(_open_cards_overlay)
	character_detail.add_child(_cards_button)

	_cards_overlay = Control.new()
	_cards_overlay.name = "CardsOverlay"
	_cards_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_overlay.visible = false
	_cards_overlay.z_index = 50
	add_child(_cards_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 640)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.09, 0.2, 0.97)
	sb.set_corner_radius_all(18)
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	_cards_title = Label.new()
	_cards_title.add_theme_font_size_override("font_size", 28)
	_cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_cards_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 12)
	scroll.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)
	var cards_head := Label.new()
	cards_head.text = "Карты колоды"
	cards_head.add_theme_font_size_override("font_size", 20)
	content.add_child(cards_head)
	_cards_grid = GridContainer.new()
	_cards_grid.columns = 5
	_cards_grid.add_theme_constant_override("h_separation", 14)
	_cards_grid.add_theme_constant_override("v_separation", 14)
	content.add_child(_cards_grid)
	_locked_title = Label.new()
	_locked_title.text = "Можно получить — за отношения"
	_locked_title.add_theme_font_size_override("font_size", 20)
	_locked_title.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
	content.add_child(_locked_title)
	_locked_grid = GridContainer.new()
	_locked_grid.columns = 5
	_locked_grid.add_theme_constant_override("h_separation", 14)
	_locked_grid.add_theme_constant_override("v_separation", 14)
	content.add_child(_locked_grid)
	_ult_title = Label.new()
	_ult_title.text = "Ульта — не карта: копит заряд в бою и жмётся кнопкой"
	_ult_title.add_theme_font_size_override("font_size", 20)
	_ult_title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	content.add_child(_ult_title)
	_ult_row = HBoxContainer.new()
	content.add_child(_ult_row)
	var close := Button.new()
	close.text = "Закрыть"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(func() -> void: _cards_overlay.visible = false)
	box.add_child(close)

func _open_cards_overlay() -> void:
	var data: CharacterData = CharDB.get_by_id(_current_char_id)
	if data == null:
		return
	for grid in [_cards_grid, _locked_grid, _ult_row]:
		for c in grid.get_children():
			c.queue_free()
	# Числа на картах — для текущего уровня отряда.
	var preview_unit := Unit.new(data, maxi(1, int(DungRun.party_level)))
	var cards := _CardLib.hero_pool(preview_unit)
	var owned := 0
	for card in cards:
		if card.locked:
			_locked_grid.add_child(_UiKit.card_preview(card, 1.0))
		else:
			_cards_grid.add_child(_UiKit.card_preview(card, 1.0))
			owned += 1
	_locked_title.visible = owned < cards.size()
	_locked_grid.visible = _locked_title.visible
	var ult := _CardLib.ult_for(preview_unit)
	_ult_title.visible = ult != null
	if ult != null:
		_ult_row.add_child(_UiKit.card_preview(ult, 1.0))
	_cards_title.text = "%s — ранг %s, получено карт: %d из %d, в бой берёт до %d" % [data.display_name, data.rank, owned, cards.size(), data.card_cap()]
	_cards_overlay.visible = true


# --- Админ: выдать любой предмет ---------------------------------------------

var _admin_panel: PanelContainer
var _admin_item: OptionButton
var _admin_amount: SpinBox
var _admin_result: Label
var _admin_hero: OptionButton
var _admin_trust: SpinBox
var _admin_level: SpinBox

func _build_admin_ui() -> void:
	var toggle := Button.new()
	toggle.text = "Админ ▸"
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.position = Vector2(30, 990)
	toggle.size = Vector2(200, 56)
	toggle.add_theme_font_size_override("font_size", 22)
	add_child(toggle)

	_admin_panel = PanelContainer.new()
	_admin_panel.visible = false
	_admin_panel.position = Vector2(30, 770)
	_admin_panel.custom_minimum_size = Vector2(460, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.10, 0.20, 0.96)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.15)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_admin_panel.add_theme_stylebox_override("panel", sb)
	add_child(_admin_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_admin_panel.add_child(box)
	var title := Label.new()
	title.text = "Выдать предмет"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)
	_admin_item = OptionButton.new()
	_admin_item.custom_minimum_size = Vector2(428, 44)
	_admin_item.add_theme_font_size_override("font_size", 18)
	var ids := RunItems.all_item_ids()
	ids.sort_custom(func(a: String, b: String) -> bool: return RunItems.get_item_name(a) < RunItems.get_item_name(b))
	for id in ids:
		_admin_item.add_item("%s  (%s)" % [RunItems.get_item_name(id), id])
		_admin_item.set_item_metadata(_admin_item.item_count - 1, id)
		var icon := Inventory_.get_item_icon(id) if Inventory_ != null else null
		if icon != null:
			_admin_item.set_item_icon(_admin_item.item_count - 1, icon)
			_admin_item.get_popup().set_item_icon_max_width(_admin_item.item_count - 1, 32)
	_admin_item.add_theme_constant_override("icon_max_width", 32)
	_admin_item.get_popup().max_size = Vector2i(600, 600)
	box.add_child(_admin_item)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_admin_amount = SpinBox.new()
	_admin_amount.min_value = 1
	_admin_amount.max_value = 999
	_admin_amount.value = 1
	_admin_amount.custom_minimum_size = Vector2(140, 44)
	row.add_child(_admin_amount)
	var give := Button.new()
	give.text = "Выдать"
	give.focus_mode = Control.FOCUS_NONE
	give.custom_minimum_size = Vector2(160, 44)
	give.add_theme_font_size_override("font_size", 20)
	give.pressed.connect(_on_admin_give)
	row.add_child(give)
	_admin_result = Label.new()
	_admin_result.add_theme_font_size_override("font_size", 16)
	box.add_child(_admin_result)

	# --- Доверие героини и уровень отряда (тесты прокачки) ---
	var trust_title := Label.new()
	trust_title.text = "Доверие (уровень отношений 0-10)"
	trust_title.add_theme_font_size_override("font_size", 20)
	box.add_child(trust_title)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	box.add_child(trow)
	_admin_hero = OptionButton.new()
	_admin_hero.custom_minimum_size = Vector2(200, 44)
	_admin_hero.add_theme_font_size_override("font_size", 18)
	for c in CharDB.characters:
		var cd := c as CharacterData
		if cd == null or cd.unit_class == "рядовой враг" or cd.card_pool.is_empty():
			continue
		_admin_hero.add_item(cd.display_name)
		_admin_hero.set_item_metadata(_admin_hero.item_count - 1, cd.id)
	_admin_hero.item_selected.connect(func(_i: int) -> void: _sync_admin_trust())
	trow.add_child(_admin_hero)
	_admin_trust = SpinBox.new()
	_admin_trust.min_value = 0
	_admin_trust.max_value = UnitRoster.RELATIONSHIP_MAX
	_admin_trust.custom_minimum_size = Vector2(100, 44)
	trow.add_child(_admin_trust)
	var set_trust := Button.new()
	set_trust.text = "Задать"
	set_trust.focus_mode = Control.FOCUS_NONE
	set_trust.custom_minimum_size = Vector2(110, 44)
	set_trust.add_theme_font_size_override("font_size", 20)
	set_trust.pressed.connect(_on_admin_set_trust)
	trow.add_child(set_trust)
	_sync_admin_trust()

	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	box.add_child(lrow)
	var lvl_title := Label.new()
	lvl_title.text = "Уровень отряда"
	lvl_title.custom_minimum_size = Vector2(200, 44)
	lvl_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_title.add_theme_font_size_override("font_size", 18)
	lrow.add_child(lvl_title)
	_admin_level = SpinBox.new()
	_admin_level.min_value = 1
	_admin_level.max_value = CardBalance.MAX_LEVEL
	_admin_level.value = maxi(1, int(DungRun.party_level))
	_admin_level.custom_minimum_size = Vector2(100, 44)
	lrow.add_child(_admin_level)
	var set_lvl := Button.new()
	set_lvl.text = "Задать"
	set_lvl.focus_mode = Control.FOCUS_NONE
	set_lvl.custom_minimum_size = Vector2(110, 44)
	set_lvl.add_theme_font_size_override("font_size", 20)
	set_lvl.pressed.connect(func() -> void:
		DungRun.party_level = int(_admin_level.value)
		DungRun.xp = 0
		DungRun.emit_changed()
		_refresh_header()
		_refresh_current_section()
		_admin_result.text = "Уровень отряда: %d" % DungRun.party_level
	)
	lrow.add_child(set_lvl)

	toggle.pressed.connect(func() -> void:
		_admin_panel.visible = not _admin_panel.visible
		if _admin_panel.visible:
			_sync_admin_trust()
			_admin_level.value = maxi(1, int(DungRun.party_level))
			# Панель растёт вверх от кнопки «Админ».
			_admin_panel.reset_size()
			_admin_panel.position.y = 980.0 - _admin_panel.get_combined_minimum_size().y
		toggle.text = "Админ ▾" if _admin_panel.visible else "Админ ▸"
	)

func _on_admin_give() -> void:
	if _admin_item.selected < 0:
		return
	var id := String(_admin_item.get_item_metadata(_admin_item.selected))
	var n := int(_admin_amount.value)
	var ok := Inventory_.add_item(id, n)
	_admin_result.text = ("Выдано: %s ×%d" % [RunItems.get_item_name(id), n]) if ok else "Не удалось выдать %s" % id

func _sync_admin_trust() -> void:
	if _admin_hero == null or _admin_hero.selected < 0:
		return
	_admin_trust.value = UnitRoster_.get_relationship(String(_admin_hero.get_item_metadata(_admin_hero.selected)))

func _on_admin_set_trust() -> void:
	if _admin_hero.selected < 0:
		return
	var id := String(_admin_hero.get_item_metadata(_admin_hero.selected))
	UnitRoster_.set_relationship(id, int(_admin_trust.value))
	_admin_result.text = "%s: отношения %d" % [_admin_hero.get_item_text(_admin_hero.selected), UnitRoster_.get_relationship(id)]


# --- Галерея ------------------------------------------------------------------
## Слева — персонажи / события (переключатель над списком), справа — картинки выбранного,
## по клику картинка открывается на весь экран. Данные: data/gallery/gallery.json (GalleryData).

const GALLERY_PANEL_RECT := Rect2(972, 170, 735, 690)
const GALLERY_THUMB := Vector2(226, 226)
const GALLERY_GROUPS := ["characters", "events"]

var _gallery_group := "characters"
var _gallery_group_box: HBoxContainer
var _gallery_group_buttons: Dictionary = {}
var _gallery_panel: ScrollContainer
var _gallery_grid: GridContainer
var _gallery_categories: Dictionary = {}     ## id -> категория из GalleryData
var _gallery_images: Array[String] = []      ## картинки открытой категории
var _gallery_pending: Dictionary = {}        ## путь -> [TextureRect] (ждут фоновой загрузки)
var _viewer: Control
var _viewer_image: TextureRect
var _viewer_counter: Label
var _viewer_index := 0

func _build_gallery_ui() -> void:
	_gallery_group_box = HBoxContainer.new()
	_gallery_group_box.position = Vector2(560, 64)
	_gallery_group_box.add_theme_constant_override("separation", 8)
	_gallery_group_box.visible = false
	add_child(_gallery_group_box)
	var group := ButtonGroup.new()
	for g in GALLERY_GROUPS:
		var b := Button.new()
		b.text = "Персонажи" if g == "characters" else "События"
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = g == _gallery_group
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 44)
		b.add_theme_font_size_override("font_size", 20)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var group_id := String(g)
		b.pressed.connect(func() -> void:
			if _gallery_group == group_id:
				return
			_gallery_group = group_id
			selected_entry_by_section[Section.GALLERY] = ""
			_rebuild_entry_grid()
		)
		_gallery_group_box.add_child(b)
		_gallery_group_buttons[group_id] = b

	_gallery_panel = ScrollContainer.new()
	_gallery_panel.position = GALLERY_PANEL_RECT.position
	_gallery_panel.size = GALLERY_PANEL_RECT.size
	_gallery_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_gallery_panel.visible = false
	add_child(_gallery_panel)
	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 3
	_gallery_grid.add_theme_constant_override("h_separation", 14)
	_gallery_grid.add_theme_constant_override("v_separation", 14)
	_gallery_panel.add_child(_gallery_grid)

	# Просмотр картинки на весь экран.
	_viewer = Control.new()
	_viewer.name = "GalleryViewer"
	_viewer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	_viewer.z_index = 60
	_viewer.visible = false
	add_child(_viewer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.0, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(dim)
	_viewer_image = TextureRect.new()
	_viewer_image.position = Vector2(120, 50)
	_viewer_image.size = Vector2(1680, 950)
	_viewer_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewer_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_viewer_image.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_viewer_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewer.add_child(_viewer_image)
	_viewer_counter = Label.new()
	_viewer_counter.position = Vector2(760, 1012)
	_viewer_counter.size = Vector2(400, 50)
	_viewer_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_viewer_counter.add_theme_font_size_override("font_size", 26)
	_viewer_counter.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	_viewer.add_child(_viewer_counter)
	for side in [-1, 1]:
		var arrow := Button.new()
		arrow.text = "‹" if side < 0 else "›"
		arrow.flat = true
		arrow.focus_mode = Control.FOCUS_NONE
		arrow.add_theme_font_size_override("font_size", 96)
		arrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
		arrow.add_theme_color_override("font_hover_color", Color(1, 0.86, 0.45))
		arrow.position = Vector2(14 if side < 0 else 1806, 470)
		arrow.size = Vector2(100, 140)
		arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var step := int(side)
		arrow.pressed.connect(func() -> void: _viewer_step(step))
		_viewer.add_child(arrow)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 44)
	close.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	close.add_theme_color_override("font_hover_color", Color(1, 0.86, 0.45))
	close.position = Vector2(1830, 14)
	close.size = Vector2(76, 70)
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.pressed.connect(_close_viewer)
	_viewer.add_child(close)
	_viewer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_close_viewer()
			_viewer.accept_event()
	)

func _build_gallery_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_gallery_categories.clear()
	for cat in GalleryData.categories(_gallery_group):
		var id := String(cat["id"])
		_gallery_categories[id] = cat
		var n: int = cat["images"].size()
		out.append({
			"id": id,
			"title": String(cat["title"]),
			"title_font_size": 20 if String(cat["title"]).length() <= 13 else 16,
			"subtitle": "%d %s" % [n, _pictures_word(n)],
			"icon": load(String(cat["icon_path"])) as Texture2D,
			"count": -1,
			"compact": false,
		})
	return out

static func _pictures_word(n: int) -> String:
	var m10 := n % 10
	var m100 := n % 100
	if m10 == 1 and m100 != 11:
		return "картинка"
	if m10 >= 2 and m10 <= 4 and (m100 < 12 or m100 > 14):
		return "картинки"
	return "картинок"

func _show_gallery_category(cat_id: String) -> void:
	var cat: Dictionary = _gallery_categories.get(cat_id, {})
	if cat.is_empty():
		_show_empty_detail_for_section()
		return
	_match_detail_visibility(false, false, false, false)
	detail_title_label.text = String(cat["title"])
	detail_hint_label.text = "Нажмите на картинку, чтобы рассмотреть её."
	for c in _gallery_grid.get_children():
		c.queue_free()
	_gallery_pending.clear()
	_gallery_images.assign(cat["images"])
	for i in range(_gallery_images.size()):
		_gallery_grid.add_child(_make_gallery_thumb(i))
	_gallery_panel.scroll_vertical = 0
	_gallery_panel.visible = true
	set_process(not _gallery_pending.is_empty())

func _make_gallery_thumb(index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = GALLERY_THUMB
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.93, 0.87, 0.78) if state == "normal" else Color(0.98, 0.92, 0.82)
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(2 if state == "normal" else 4)
		sb.border_color = Color(0.62, 0.45, 0.52) if state == "normal" else Color(0.85, 0.35, 0.6)
		b.add_theme_stylebox_override(state, sb)
	var pic := TextureRect.new()
	pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pic.offset_left = 8
	pic.offset_top = 8
	pic.offset_right = -8
	pic.offset_bottom = -8
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(pic)
	_request_texture(_gallery_images[index], pic)
	b.pressed.connect(func() -> void: _open_viewer(index))
	return b

## Картинки грузятся в фоне, чтобы большие кадры (пролог) не подвешивали книжку.
func _request_texture(path: String, target: TextureRect) -> void:
	if ResourceLoader.has_cached(path):
		target.texture = load(path) as Texture2D
		return
	if not _gallery_pending.has(path):
		_gallery_pending[path] = []
		if ResourceLoader.load_threaded_request(path) != OK:
			_gallery_pending.erase(path)
			target.texture = load(path) as Texture2D
			return
	_gallery_pending[path].append(target)

func _process(_delta: float) -> void:
	if _gallery_pending.is_empty():
		set_process(false)
		return
	for path in _gallery_pending.keys():
		var st := ResourceLoader.load_threaded_get_status(path)
		if st == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		var tex: Texture2D = null
		if st == ResourceLoader.THREAD_LOAD_LOADED:
			tex = ResourceLoader.load_threaded_get(path) as Texture2D
		for t in _gallery_pending[path]:
			if is_instance_valid(t):
				t.texture = tex
		_gallery_pending.erase(path)

func _open_viewer(index: int) -> void:
	if _gallery_images.is_empty():
		return
	_viewer_index = posmod(index, _gallery_images.size())
	_viewer_image.texture = load(_gallery_images[_viewer_index]) as Texture2D
	_viewer_counter.text = "%d / %d" % [_viewer_index + 1, _gallery_images.size()]
	_viewer.visible = true
	_viewer.modulate.a = 0.0
	create_tween().tween_property(_viewer, "modulate:a", 1.0, 0.15)

func _viewer_step(step: int) -> void:
	_open_viewer(_viewer_index + step)

func _close_viewer() -> void:
	_viewer.visible = false
	_viewer_image.texture = null

func _unhandled_input(event: InputEvent) -> void:
	if _viewer == null or not _viewer.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_viewer()
	elif event.is_action_pressed("ui_left"):
		_viewer_step(-1)
	elif event.is_action_pressed("ui_right"):
		_viewer_step(1)
	else:
		return
	get_viewport().set_input_as_handled()
