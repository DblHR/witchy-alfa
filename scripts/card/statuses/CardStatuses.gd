extends RefCounted
class_name CardStatuses
## Реестр статусов карточного боя: id -> CardStatus.
## Чтобы добавить статус: напишите подкласс CardStatus (или используйте базовый с параметрами,
## если поведения нет) и зарегистрируйте его в _register_all().

const WEAK := "weak"
const VULN := "vuln"
const BURN := "burn"
const STUN := "stun"
const CHARM := "charm"
const NAZHIM := "nazhim"
const STICKY_SLIME := "sticky_slime"   ## липкая слизь — на врагах
const WRAP_SLIME := "wrap_slime"       ## обволакивающая слизь — на союзниках
const EMPOWER := "empower"
const EXPOSED := "exposed"             ## «Подставлена»: урон по HP → обволакивающая слизь
const HEAT_BODY := "heat_body"         ## «Жар тела»: ударивший по щиту получает Горение
const SWALLOWED := "swallowed"         ## героиня в животе у Фуфу: не действует, враги её не бьют

static var _all: Dictionary = {}

static func get_status(id: String) -> CardStatus:
	if _all.is_empty():
		_register_all()
	return _all.get(id)

static func all_ids() -> Array:
	if _all.is_empty():
		_register_all()
	return _all.keys()

static func _add(s: CardStatus) -> void:
	_all[s.id] = s

## Значки и подсказки статусов. Новый значок — строка сюда (картинка ui/status_icons/*.png).
const ICONS := {
	WEAK: "res://ui/status_icons/weakness_status.png",
	VULN: "res://ui/status_icons/vulnerability_status.png",
	BURN: "res://ui/status_icons/fire_status.png",
	STUN: "res://ui/status_icons/stun_status.png",
	CHARM: "res://ui/status_icons/charm_status.png",
	NAZHIM: "res://ui/status_icons/pressure_status.png",
	STICKY_SLIME: "res://ui/status_icons/sticky_slime_status.png",
	WRAP_SLIME: "res://ui/status_icons/enshroud_slime_status.png",
}
const INFO := {
	WEAK: "Наносит на 25% меньше урона.",
	VULN: "Получает на 50% больше урона.",
	BURN: "В начале хода врагов получает урон за каждый стак.",
	STUN: "Пропускает ход.",
	CHARM: "Очарована: бьёт своих.",
	NAZHIM: "Копится от ударов воина. Карты воина бьют сильнее за каждый стак, а некоторые снимают его целиком.",
	STICKY_SLIME: "Каждые 5 новых стаков — оглушение. Некоторые карты тратят её для урона.",
	WRAP_SLIME: "Карты Аки и Фуфу превращают её в лечение, щит или усиление.",
	EMPOWER: "Каждый удар сильнее на число стаков. Спадает в конце хода.",
	EXPOSED: "Каждые 25 урона по здоровью дают +1 обволакивающую слизь.",
	HEAT_BODY: "Враг, ударивший по её щиту, загорается.",
	SWALLOWED: "Внутри босса: не действует, враги её не бьют.",
}

static func _decorate() -> void:
	for id in _all.keys():
		var s: CardStatus = _all[id]
		s.icon_path = String(ICONS.get(id, ""))
		s.info = String(INFO.get(id, ""))

static func _register_all() -> void:
	_add(WeakStatus.new())
	_add(VulnStatus.new())
	_add(BurnStatus.new())
	var stun := CardStatus.new(STUN, "Оглушение", CardStatus.Kind.DURATION)
	stun.skips_turn = true
	_add(stun)
	var charm := CardStatus.new(CHARM, "Очарование", CardStatus.Kind.DURATION, Color(1.0, 0.55, 0.85))
	charm.charms = true
	_add(charm)
	_add(SwallowedStatus.new())
	_add(HeatBodyStatus.new())
	var nazhim := CardStatus.new(NAZHIM, "Нажим", CardStatus.Kind.STACKS)
	nazhim.max_stacks = 10
	_add(nazhim)
	_add(StickySlimeStatus.new())
	_add(CardStatus.new(WRAP_SLIME, "Обволакивающая слизь", CardStatus.Kind.STACKS, Color(0.45, 0.9, 1.0)))
	_add(EmpowerStatus.new())
	_add(ExposedStatus.new())
	_decorate()
