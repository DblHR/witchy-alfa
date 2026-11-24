class_name NpcTrust
extends RefCounted
## Доверие НПС (Рикка, Ноктрис, Сессилия): 5 уровней.
## Очки копятся за:
##   - деньги, потраченные в комнате НПС: GOLD_PER_POINT золота = 1 очко (лавка Рикки и её
##     «Обновить», товары Сессилии, услуги Ноктрис);
##   - выполненные квесты НПС (кто дал квест — по диалогу со start_quest): QUEST_POINTS;
##   - несексуальные действия (сердечко рядом с НПС в его комнате; Interactions).
## На максимальном уровне НПС отдаёт свою карту (NPC_CARDS): она навсегда в колоде каждого забега.
## Хранится в StoryState (счётчики npc_trust:<id>, npc_gold:<id>, флаг npc_card:<id>).

const NPC_IDS := ["rikka", "noctris", "sessilia"]
## Старые id НПС в диалогах.
const LEGACY := {"rabbit_shop": "rikka", "nurse": "noctris", "lamia": "sessilia"}
const MAX_LEVEL := 5
## Очки на каждый уровень (сколько набрать от прошлого уровня до следующего).
const STEPS: Array[int] = [100, 200, 300, 400, 500]
const GOLD_PER_POINT := 10
const QUEST_POINTS := 50
## Карта НПС за максимальное доверие (id карты из resources/cards/npc/).
const NPC_CARDS := {"rikka": "rikka_gold", "noctris": "noctris_call", "sessilia": "sessilia_potion"}
const CARD_DIR := "res://resources/cards/npc/"

const POINTS_COUNTER := "npc_trust:%s"
const GOLD_COUNTER := "npc_gold:%s"
const CARD_FLAG := "npc_card:%s"

static func is_npc(id: String) -> bool:
	return NPC_IDS.has(normalize(id))

static func normalize(id: String) -> String:
	return String(LEGACY.get(id, id))

## Очки доверия НПС (действия и квесты + потраченное золото / GOLD_PER_POINT).
static func points(id: String) -> int:
	if StoryState_ == null:
		return 0
	id = normalize(id)
	return StoryState_.get_counter(POINTS_COUNTER % id) + floori(float(StoryState_.get_counter(GOLD_COUNTER % id)) / GOLD_PER_POINT)

static func points_for_level(lvl: int) -> int:
	var total := 0
	for i in range(clampi(lvl, 0, STEPS.size())):
		total += STEPS[i]
	return total

static func level(id: String) -> int:
	var pts := points(id)
	var lvl := 0
	while lvl < MAX_LEVEL and pts >= points_for_level(lvl + 1):
		lvl += 1
	return lvl

## {level, into_level, need} — для подписи «ещё N до следующего уровня».
static func progress(id: String) -> Dictionary:
	var lvl := level(id)
	var into := points(id) - points_for_level(lvl)
	var need := 0 if lvl >= MAX_LEVEL else STEPS[lvl]
	return {"level": lvl, "into_level": into, "need": need}

static func add(id: String, amount: int) -> void:
	id = normalize(id)
	if StoryState_ == null or amount <= 0 or not is_npc(id):
		return
	StoryState_.add_counter(POINTS_COUNTER % id, amount)
	_check_card(id)

## Потратили золото в комнате НПС.
static func add_gold(id: String, gold: int) -> void:
	id = normalize(id)
	if StoryState_ == null or gold <= 0 or not is_npc(id):
		return
	StoryState_.add_counter(GOLD_COUNTER % id, gold)
	_check_card(id)

## Выполнен квест: очки тому НПС, кто его дал.
static func on_quest_completed(quest_id: String) -> void:
	var giver := quest_giver(quest_id)
	if giver != "":
		add(giver, QUEST_POINTS)

## Кто дал квест: НПС диалога, в котором есть "start_quest": quest_id. «» — не НПС.
static func quest_giver(quest_id: String) -> String:
	if StoryDialogueDB_ == null or quest_id == "":
		return ""
	for d in StoryDialogueDB_.dialogues_by_id.values():
		if d is Dictionary and _mentions_start(d, quest_id):
			var npc := normalize(String((d as Dictionary).get("npc", "")))
			if is_npc(npc):
				return npc
	return ""

static func _mentions_start(node, quest_id: String) -> bool:
	if node is Dictionary:
		var d: Dictionary = node
		if String(d.get("start_quest", "")) == quest_id:
			return true
		for v in d.values():
			if (v is Dictionary or v is Array) and _mentions_start(v, quest_id):
				return true
	elif node is Array:
		for v in node:
			if _mentions_start(v, quest_id):
				return true
	return false

# --- Карта НПС -----------------------------------------------------------------------

static func has_card(id: String) -> bool:
	return StoryState_ != null and StoryState_.has_flag(CARD_FLAG % normalize(id))

## Карты НПС, которые уже есть у игрока (id карт).
static func owned_cards() -> Array[String]:
	var out: Array[String] = []
	for id in NPC_IDS:
		if has_card(id):
			out.append(String(NPC_CARDS[id]))
	return out

## Дошли до максимального уровня — НПС отдаёт карту (один раз), с окошком «Новая карта».
static func _check_card(id: String) -> void:
	if has_card(id) or level(id) < MAX_LEVEL or not NPC_CARDS.has(id):
		return
	StoryState_.set_flag(CARD_FLAG % id, true)
	var def := load(CARD_DIR + String(NPC_CARDS[id]) + ".tres") as CardDef
	var who := StoryDialogueDB_.get_character_name(id) if StoryDialogueDB_ != null else id
	var text := "%s отдаёт вам свою карту%s." % [who, (" «%s»" % def.title) if def != null else ""]
	announce("Максимальное доверие!", text)

## Окошко по центру экрана (поверх всего), закрывается кликом.
static func announce(title: String, text: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 80
	tree.current_scene.add_child(layer)
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(host)
	ItemNotice.show_notice(host, title, text, null, layer.queue_free)
