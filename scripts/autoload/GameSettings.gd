extends RefCounted
class_name GameSettings
## Настройки игры, общие для всех сохранений: user://settings.cfg.
## Сейчас: частота реплик в бою и между комнатами (множитель шансов из data/banter/settings.json),
## режим экрана (окно / полный экран) и размер окна.

const FILE := "user://settings.cfg"
const SECTION := "game"
## Шаги ползунка «Частота реплик», %: 0 — молчат, 100 — как задано в json, 200 — вдвое чаще.
const BANTER_MIN := 0
const BANTER_MAX := 200
const BANTER_STEP := 25

## Размеры окна на выбор (в настройках остаются только те, что помещаются на экран).
## Игра рисуется в 1920×1080 и растягивается под окно с сохранением пропорций (полосы по краям).
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160)]
const WINDOW_MIN_SIZE := Vector2i(960, 540)

static var _cfg: ConfigFile
static var _banter := 100

static func _ensure() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_cfg.load(FILE)   ## нет файла — остаются значения по умолчанию
	_banter = clampi(int(_cfg.get_value(SECTION, "banter_percent", 100)), BANTER_MIN, BANTER_MAX)

static func _save() -> void:
	_cfg.save(FILE)

static func banter_percent() -> int:
	_ensure()
	return _banter

## Множитель шансов реплик: 0.0 .. 2.0.
static func banter_mult() -> float:
	return float(banter_percent()) / 100.0

static func set_banter_percent(value: int) -> void:
	_ensure()
	_banter = clampi(value, BANTER_MIN, BANTER_MAX)
	_cfg.set_value(SECTION, "banter_percent", _banter)
	_save()

# --- Экран ---------------------------------------------------------------------

## Есть настоящее окно (в headless-тестах — нет).
static func _has_window() -> bool:
	return DisplayServer.get_name() != "headless"

static func is_fullscreen() -> bool:
	_ensure()
	return bool(_cfg.get_value(SECTION, "fullscreen", false))

## Выбранный размер окна (0,0 — ещё не выбирали: как в настройках проекта).
static func window_size() -> Vector2i:
	_ensure()
	return _cfg.get_value(SECTION, "window_size", Vector2i.ZERO)

static func set_fullscreen(on: bool) -> void:
	_ensure()
	_cfg.set_value(SECTION, "fullscreen", on)
	_save()
	apply_display()

static func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())

static func set_window_size(sz: Vector2i) -> void:
	_ensure()
	_cfg.set_value(SECTION, "window_size", sz)
	_save()
	apply_display()

## Размеры окна, которые помещаются на текущий монитор.
static func available_window_sizes() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var screen := Vector2i(100000, 100000)
	if _has_window():
		screen = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for sz in WINDOW_SIZES:
		if sz.x <= screen.x and sz.y <= screen.y:
			out.append(sz)
	if out.is_empty():
		out.append(WINDOW_SIZES[0])
	return out

## Текущий размер окна (для подписи в настройках).
static func current_window_size() -> Vector2i:
	var sz := window_size()
	if sz == Vector2i.ZERO and _has_window():
		sz = DisplayServer.window_get_size()
	return sz

## Применить режим экрана и размер окна (при запуске игры и при смене в настройках).
static func apply_display() -> void:
	if not _has_window():
		return
	DisplayServer.window_set_min_size(WINDOW_MIN_SIZE)
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var sz := window_size()
	if sz == Vector2i.ZERO:
		return
	var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	sz = Vector2i(mini(sz.x, screen.size.x), mini(sz.y, screen.size.y))
	DisplayServer.window_set_size(sz)
	DisplayServer.window_set_position(screen.position + (screen.size - sz) / 2)
