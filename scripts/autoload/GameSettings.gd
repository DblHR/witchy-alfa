extends RefCounted
class_name GameSettings
## Настройки игры, общие для всех сохранений: user://settings.cfg.
## Сейчас: частота реплик в бою и между комнатами (множитель шансов из data/banter/settings.json).

const FILE := "user://settings.cfg"
const SECTION := "game"
## Шаги ползунка «Частота реплик», %: 0 — молчат, 100 — как задано в json, 200 — вдвое чаще.
const BANTER_MIN := 0
const BANTER_MAX := 200
const BANTER_STEP := 25

static var _cfg: ConfigFile
static var _banter := 100

static func _ensure() -> void:
	if _cfg != null:
		return
	_cfg = ConfigFile.new()
	_cfg.load(FILE)   ## нет файла — остаются значения по умолчанию
	_banter = clampi(int(_cfg.get_value(SECTION, "banter_percent", 100)), BANTER_MIN, BANTER_MAX)

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
	_cfg.save(FILE)
