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
## Смена времени суток:
##   - кровать в доме (только ночью): ночь -> утро следующего дня (sleep());
##   - запуск забега на подготовке: день -> ночь (on_run_launched()); забег ночью — усталость:
##     первый раз — героиня предлагает поспать (можно отказаться: в забеге максимум энергии 1),
##     дальше — максимум энергии 0 (fatigue_for_next_run()). Сон снимает усталость;
##   - в самом начале игры ночь, а в подземелье ещё не ходили — «Я слишком устала» (Hub);
##   - кнопка в админ-панели (F9).
## Ночью: лавка Рикки закрыта, сексуальные взаимодействия доступны. Днём: лавка открыта,
## на экран отношений не пускают («Лучше приходи ко мне ночью~»). Несексуальные — всегда.

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
## Сколько забегов начато после последнего сна (0 — ещё не ходили; 1 — сходили днём; 2+ — ночью).
const COUNTER_RUNS := "runs_since_sleep"
## Тексты (реплики героя) — data/dialogues/story/day_night.json.
const DLG_TOO_TIRED := "day_night_too_tired"
const DLG_SHOP_CLOSED := "day_night_shop_closed"
const DLG_RUN_TIRED := "day_night_run_tired"
const DLG_RUN_MUMBLE := "day_night_run_mumble"
## Флаг: в «Сил совсем нет…» выбрали «Нет, не время для сна!».
const FLAG_PUSH_ON := "fatigue_push_on"
## Флаг: подсветить кровать (после «Я слишком устала»), снимается сном.
const FLAG_BED_HINT := "bed_hint"

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

## Ночью лавка Рикки закрыта: герой говорит об этом (VN). true — закрыто (никуда не идём).
static func shop_closed_say() -> bool:
	if not is_night():
		return false
	if DialogueManager_ != null and not DialogueManager_.is_showing() and StoryDialogueDB_ != null:
		var d: Dictionary = StoryDialogueDB_.get_dialogue(DLG_SHOP_CLOSED)
		if not d.is_empty():
			DialogueManager_.show_sequence(StoryDialogueDB_.resolve_lines(d))
	return true

# --- Сон и забеги -------------------------------------------------------------------

static func runs_since_sleep() -> int:
	return StoryState_.get_counter(COUNTER_RUNS) if StoryState_ != null else 0

## Ночь, а в подземелье ещё не ходили (начало игры): идти нельзя — надо выспаться.
static func too_tired_to_start() -> bool:
	return is_night() and runs_since_sleep() == 0

## Кровать: ночь -> утро следующего дня, усталость снята. false — сейчас не ночь.
static func sleep() -> bool:
	if not is_night() or StoryState_ == null:
		return false
	advance()
	StoryState_.add_counter(COUNTER_RUNS, -runs_since_sleep())
	StoryState_.set_flag(FLAG_BED_HINT, false)
	return true

## Усталость для забега, который сейчас запускают: 0 — нет; 1 — уже ходили сегодня
## (героиня предложит поспать; отказ — максимум энергии 1); 2 — ещё раз (максимум энергии 0).
static func fatigue_for_next_run() -> int:
	if not is_night():
		return 0
	return clampi(runs_since_sleep(), 0, 2)

## Забег запущен: днём наступает ночь; счётчик забегов после сна +1.
static func on_run_launched() -> void:
	if StoryState_ == null:
		return
	if not is_night():
		set_phase(Phase.NIGHT)
	StoryState_.add_counter(COUNTER_RUNS, 1)

## Максимум энергии в бою при усталости (fatigue 1 -> 1, 2 -> 0; 0 — без ограничения: -1).
static func fatigue_energy_cap(fatigue: int) -> int:
	match fatigue:
		1:
			return 1
		2:
			return 0
	return -1

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

## Заменить у всех узлов в root картинки на картинки текущего времени суток: и те, что из nighttime /
## daytime, и те, что лежат прямо в папке комнаты, если для этого времени суток рядом есть своя
## (например, alchemy/cauldron.png днём -> alchemy/daytime/cauldron.png, ночью — обратно).
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
			if path == "" or path.begins_with("res://assets/characters/"):
				continue   ## картинки героинь не зависят от времени суток
			var p := variant(path)
			if p != path:
				n.set(prop["name"], load(p))
