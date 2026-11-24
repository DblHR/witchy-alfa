extends RefCounted
class_name DayCycle
## День и ночь: хранит время суток и номер дня в сохранении (StoryState: счётчики "day_number" и
## "day_phase"), умеет переключать и подбирать картинки под время суток.
##
## Картинки — правило для всех комнат (дом, ферма, алхимия…):
##   <папка комнаты>/nighttime/x.png — ночная картинка;
##   <папка комнаты>/daytime/x.png   — дневная (то же имя файла);
##   <папка комнаты>/x.png           — не зависит от времени суток.
## В сценах можно ставить картинку из любой из папок nighttime / daytime: apply_textures(сцена)
## подменит её на картинку текущего времени суток. Если для этого времени картинки нет — берётся
## картинка из папки комнаты, а если и её нет — остаётся та, что стоит в сцене.
## Картинку, которой нет вообще ни в папке времени суток, ни в папке комнаты (например, звёзд на
## небе днём), texture() вернёт null — так узел понимает, что сейчас его показывать не нужно.
##
## Действия: ACTIONS — сколько действий доступно игроку за день и за ночь (пока ни на что не влияет,
## но считается: spend_action() / actions_left()). Подключим, когда решим, что тратит действия.
##
## Пока время суток меняется только вручную: клик по кровати в доме (для тестов) или кнопка в
## админ-панели (F9).

enum Phase { DAY, NIGHT }
const PHASE_NAMES := ["day", "night"]
const DEFAULT_PHASE := Phase.NIGHT
## Папки картинок для каждого времени суток.
const FOLDERS := {Phase.DAY: "daytime", Phase.NIGHT: "nighttime"}
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

## Папка комнаты и имя файла: ".../hub/nighttime/x.png" -> [".../hub/", "x.png"].
static func split_path(path: String) -> PackedStringArray:
	var dir := path.get_base_dir()
	var file := path.get_file()
	for f in FOLDERS.values():
		if dir.ends_with("/" + String(f)):
			dir = dir.get_base_dir()
			break
	return PackedStringArray([dir + "/", file])

## Есть ли в пути папка времени суток (nighttime / daytime).
static func is_phased(path: String) -> bool:
	for f in FOLDERS.values():
		if path.contains("/" + String(f) + "/"):
			return true
	return false

## Путь картинки для текущего времени суток. Ищет: папка текущего времени -> папка комнаты.
## "" — такой картинки сейчас нет.
static func find(room_dir: String, file: String) -> String:
	if not room_dir.ends_with("/"):
		room_dir += "/"
	if file.get_extension() == "":
		file += ".png"
	var p := room_dir + String(FOLDERS[phase()]) + "/" + file
	if ResourceLoader.exists(p):
		return p
	p = room_dir + file
	return p if ResourceLoader.exists(p) else ""

## Путь из сцены/кода -> путь для текущего времени суток. Не нашлось — тот же путь, что дали.
static func variant(path: String) -> String:
	if path == "":
		return path
	var parts := split_path(path)
	var p := find(parts[0], parts[1])
	return p if p != "" else path

## Картинка для текущего времени суток. null — сейчас такой картинки нет (ни в папке времени
## суток, ни в папке комнаты), даже если она есть для другого времени.
static func texture(path: String) -> Texture2D:
	var parts := split_path(path)
	var p := find(parts[0], parts[1])
	return load(p) as Texture2D if p != "" else null

## Картинка комнаты по имени файла (без .png можно): find + load. null — нет.
static func room_texture(room_dir: String, file: String) -> Texture2D:
	var p := find(room_dir, file)
	return load(p) as Texture2D if p != "" else null

## Заменить у всех узлов в root картинки из nighttime / daytime на картинки текущего времени суток.
## Смотрит все свойства-картинки узла (texture, texture_normal, свои @export картинки скриптов…).
static func apply_textures(root: Node) -> void:
	if root == null:
		return
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for n in nodes:
		for prop in n.get_property_list():
			if int(prop["type"]) != TYPE_OBJECT or not (int(prop["usage"]) & PROPERTY_USAGE_STORAGE):
				continue
			var t = n.get(prop["name"])
			if not (t is Texture2D):
				continue
			var path := (t as Texture2D).resource_path
			if path == "" or not is_phased(path):
				continue
			var p := variant(path)
			if p != path:
				n.set(prop["name"], load(p))
