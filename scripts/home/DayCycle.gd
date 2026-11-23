extends RefCounted
class_name DayCycle
## День и ночь. Пока заготовка: хранит время суток и номер дня в сохранении (StoryState: счётчики
## "day_number" и "day_phase"), умеет переключать и подбирать картинки под время суток.
##
## Картинки: ночные лежат в assets/hub/night_hub/, дневные будут в assets/hub/day_hub/ с теми же
## именами файлов. apply_textures(сцена) заменяет у всех узлов сцены картинки из night_hub на
## картинки из папки текущего времени суток (если такой файл есть — иначе остаётся ночная).
##
## Действия: ACTIONS — сколько действий доступно игроку за день и за ночь (пока ни на что не влияет,
## но считается: spend_action() / actions_left()). Подключим, когда решим, что тратит действия.
##
## Сейчас время суток не меняется само: только advance() (или кнопка в админ-панели).
## По умолчанию — ночь (других картинок пока нет).

enum Phase { DAY, NIGHT }
const PHASE_NAMES := ["day", "night"]
const DEFAULT_PHASE := Phase.NIGHT
## Папка картинок для каждого времени суток (ночь — исходная, в сценах стоят ночные картинки).
const FOLDERS := {Phase.DAY: "/day_hub/", Phase.NIGHT: "/night_hub/"}
const SOURCE_FOLDER := "/night_hub/"
## Сколько действий даёт день и ночь (заготовка).
const ACTIONS := {Phase.DAY: 3, Phase.NIGHT: 2}

const COUNTER_PHASE := "day_phase"            ## 0 — ещё не начинали (= DEFAULT_PHASE), 1 — день, 2 — ночь
const COUNTER_DAY := "day_number"
const COUNTER_SPENT := "day_actions_spent"

static func phase() -> Phase:
	if StoryState_ == null:
		return DEFAULT_PHASE
	var v := StoryState_.get_counter(COUNTER_PHASE)
	if v <= 0:
		return DEFAULT_PHASE
	return Phase.DAY if v == 1 else Phase.NIGHT

static func is_night() -> bool:
	return phase() == Phase.NIGHT

static func phase_name() -> String:
	return PHASE_NAMES[phase()]

## Номер дня (с 1).
static func day_number() -> int:
	return 1 + (StoryState_.get_counter(COUNTER_DAY) if StoryState_ != null else 0)

static func set_phase(p: Phase) -> void:
	if StoryState_ == null:
		return
	var want := 1 if p == Phase.DAY else 2
	StoryState_.add_counter(COUNTER_PHASE, want - StoryState_.get_counter(COUNTER_PHASE))
	StoryState_.add_counter(COUNTER_SPENT, -StoryState_.get_counter(COUNTER_SPENT))

## День -> ночь -> следующий день.
static func advance() -> void:
	if phase() == Phase.DAY:
		set_phase(Phase.NIGHT)
	else:
		if StoryState_ != null:
			StoryState_.add_counter(COUNTER_DAY, 1)
		set_phase(Phase.DAY)

# --- Действия (заготовка) -----------------------------------------------------------

static func actions_left() -> int:
	var spent := StoryState_.get_counter(COUNTER_SPENT) if StoryState_ != null else 0
	return maxi(0, int(ACTIONS[phase()]) - spent)

## Потратить действие. false — действий не осталось.
static func spend_action() -> bool:
	if actions_left() <= 0 or StoryState_ == null:
		return false
	StoryState_.add_counter(COUNTER_SPENT, 1)
	return true

# --- Картинки -------------------------------------------------------------------------

## Путь картинки для текущего времени суток: ".../night_hub/x.png" -> ".../day_hub/x.png", если есть.
static func variant(path: String) -> String:
	if not path.contains(SOURCE_FOLDER):
		return path
	var folder := String(FOLDERS[phase()])
	if folder == SOURCE_FOLDER:
		return path
	var p := path.replace(SOURCE_FOLDER, folder)
	return p if ResourceLoader.exists(p) else path

static func texture(path: String) -> Texture2D:
	var p := variant(path)
	return load(p) as Texture2D if ResourceLoader.exists(p) else null

## Заменить у всех узлов в root картинки night_hub на картинки текущего времени суток.
static func apply_textures(root: Node) -> void:
	if root == null:
		return
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for n in nodes:
		if not ("texture" in n):
			continue
		var t = n.get("texture")
		if t is Texture2D and (t as Texture2D).resource_path.contains(SOURCE_FOLDER):
			var p := variant((t as Texture2D).resource_path)
			if p != (t as Texture2D).resource_path:
				n.set("texture", load(p))
