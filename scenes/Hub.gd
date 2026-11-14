extends Control

@onready var start_run: TextureButton = %StartRunButton
@onready var farm: TextureButton = %FarmButton
@onready var alchemy: TextureButton = %AlchemyButton
@onready var shop: TextureButton = %ShopButton
@onready var inv: TextureButton = %InventoryButton

func _ready() -> void:
	get_tree().paused = false

	start_run.pressed.connect(_on_start_run)
	farm.pressed.connect(func(): SceneRouter_.go_to_farm())
	alchemy.pressed.connect(func(): SceneRouter_.go_to_alchemy())
	shop.pressed.connect(func(): SceneRouter_.go_to_shop())
	inv.pressed.connect(func(): SceneRouter_.go_to_inventory())
	_start_wanderers()
	_refresh_badges()
	if StoryState_ != null and StoryState_.has_signal("changed") and not StoryState_.changed.is_connected(_refresh_badges):
		StoryState_.changed.connect(_refresh_badges)
	call_deferred("_play_pending_story_dialogue")

## «!» на кнопке лавки, когда Рикка может выдать квест.
func _refresh_badges() -> void:
	if not is_inside_tree():
		return
	NotifyBadge.attach(shop, StoryDialogueDB_ != null and StoryDialogueDB_.npc_has_quest_offer("rabbit_shop"))

## Ведьмочка бродит по дому. Границы — левый край её картинки (координаты 1920×1080),
## чтобы не заходить под кнопки инвентаря и портала.
const WITCH_MIN_X := 90.0
const WITCH_MAX_X := 1150.0

## Кто ещё гуляет по дому, когда есть в ростере: id героини -> её спрайт. Чтобы добавить
## новую — строка сюда (картинка того же формата, что witch.png: 1000×1240, смотрит влево).
const HUB_GUESTS := {
	"fufu": "res://assets/characters/fufu/fufu_battle.png",
}

func _start_wanderers() -> void:
	var witch := get_node_or_null("TextureRect") as TextureRect
	if witch == null:
		return
	var w := HubWanderer.new()
	w.name = "WitchWanderer"
	w.setup(witch, WITCH_MIN_X, WITCH_MAX_X)
	add_child(w)
	# Гости: такая же картинка, как у ведьмочки (размер, слой), со своим маршрутом.
	var k := 0
	for id in HUB_GUESTS:
		if UnitRoster_ == null or not UnitRoster_.has_unit(String(id)):
			continue
		var tex := load(String(HUB_GUESTS[id])) as Texture2D
		if tex == null:
			continue
		var guest := TextureRect.new()
		guest.name = "Guest_" + String(id)
		guest.texture = tex
		guest.expand_mode = witch.expand_mode
		guest.stretch_mode = witch.stretch_mode
		guest.flip_h = k % 2 == 0
		guest.size = witch.size
		guest.position = Vector2(lerpf(WITCH_MAX_X, WITCH_MIN_X, 0.25 + 0.3 * float(k)), witch.position.y)
		add_child(guest)
		move_child(guest, witch.get_index())   ## за ведьмочкой, перед фоном
		var gw := HubWanderer.new()
		gw.name = "Wanderer_" + String(id)
		gw.setup(guest, WITCH_MIN_X, WITCH_MAX_X)
		add_child(gw)
		_guests[String(id)] = gw
		k += 1

# --- Разговоры в доме -----------------------------------------------------------
## Гостью можно позвать: при наведении она подсвечивается, по клику — диалог.
## Диалог выбирается как у NPC: npc = id героини, type = "hub_talk" (data/dialogues/hub/*.json),
## поэтому потом легко добавить разговоры по уровню отношений (conditions + priority).
const HUB_TALK_TYPE := "hub_talk"
var _guests: Dictionary = {}          ## id -> HubWanderer
var _hovered_guest := ""
var _talking := ""

func _process(_delta: float) -> void:
	var over := ""
	if _talking == "" and not DialogueManager_.is_showing() and not _over_button():
		var m := get_viewport().get_mouse_position()
		# Сверху та, что нарисована последней.
		var ids := _guests.keys()
		ids.reverse()
		for id in ids:
			var w: HubWanderer = _guests[id]
			if is_instance_valid(w) and w.is_over(m) and _can_talk(String(id)):
				over = String(id)
				break
	if over == _hovered_guest:
		return
	if _hovered_guest != "" and _guests.has(_hovered_guest):
		(_guests[_hovered_guest] as HubWanderer).set_glow(false)
	_hovered_guest = over
	if over != "":
		(_guests[over] as HubWanderer).set_glow(true)
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over != "" else Input.CURSOR_ARROW)

## Кнопки дома (магазин, ферма, выход...) важнее гостьи под ними.
func _over_button() -> bool:
	var hc := get_viewport().gui_get_hovered_control()
	while hc != null:
		if hc is BaseButton:
			return true
		hc = hc.get_parent() as Control
	return false

func _can_talk(id: String) -> bool:
	return StoryDialogueDB_ != null and not StoryDialogueDB_.pick_npc_dialogue(id, HUB_TALK_TYPE).is_empty()

func _input(event: InputEvent) -> void:
	if _hovered_guest == "" or _talking != "" or DialogueManager_.is_showing():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		talk_to(_hovered_guest)

func talk_to(id: String) -> void:
	var d := StoryDialogueDB_.pick_npc_dialogue(id, HUB_TALK_TYPE)
	if d.is_empty():
		return
	var lines := StoryDialogueDB_.resolve_lines(d)
	if lines.is_empty():
		return
	_talking = id
	var w: HubWanderer = _guests.get(id, null)
	if w != null:
		w.set_glow(false)
		w.set_frozen(true)   ## стоит на месте, пока говорим
	_hovered_guest = ""
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	DialogueManager_.show_sequence(lines, Callable(self, "_on_talk_finished").bind(d))

func _on_talk_finished(dialogue: Dictionary) -> void:
	var w: HubWanderer = _guests.get(_talking, null)
	if w != null and is_instance_valid(w):
		w.set_frozen(false)
	_talking = ""
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen(String(dialogue.get("id", "")))
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.apply_effects(dialogue.get("on_finish", {}))

func _on_start_run() -> void:
	# Тут логично начинать новый забег (seed, сброс золота и т.д.)
	# Но если Вы хотите сохранить "старт run" строго в Setup — можно перенести туда.
	SceneRouter_.go_to_setup()

## Отложенные сюжетные диалоги: флаг StoryState -> id диалога (первый поднятый флаг играется при входе в хаб).
const PENDING_DIALOGUES := [
	["pending_tutorial_rikka", "tutorial_rikka_after"],
	["pending_find_warrior_after_battle", "find_warrior_after_battle"],
]

func _play_pending_story_dialogue() -> void:
	if StoryState_ == null or StoryDialogueDB_ == null:
		return
	for pair in PENDING_DIALOGUES:
		var flag := String(pair[0])
		if not StoryState_.has_flag(flag):
			continue
		StoryState_.set_flag(flag, false)
		var d := StoryDialogueDB_.get_dialogue(String(pair[1]))
		if d.is_empty():
			continue
		var lines := StoryDialogueDB_.resolve_lines(d)
		if lines.is_empty():
			StoryDialogueDB_.apply_effects(d.get("on_finish", {}))
			continue
		DialogueManager_.show_sequence(lines, Callable(self, "_on_pending_story_dialogue_finished").bind(d))
		return

func _on_pending_story_dialogue_finished(dialogue: Dictionary) -> void:
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen(String(dialogue.get("id", "")))
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.apply_effects(dialogue.get("on_finish", {}))
