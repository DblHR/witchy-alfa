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

static func _register_all() -> void:
	_add(WeakStatus.new())
	_add(VulnStatus.new())
	_add(BurnStatus.new())
	var stun := CardStatus.new(STUN, "Оглушение", CardStatus.Kind.DURATION)
	stun.skips_turn = true
	_add(stun)
	var charm := CardStatus.new(CHARM, "Очарование", CardStatus.Kind.DURATION, Color(0.45, 1.0, 0.55))
	charm.charms = true
	_add(charm)
	var nazhim := CardStatus.new(NAZHIM, "Нажим", CardStatus.Kind.STACKS)
	nazhim.max_stacks = 10
	_add(nazhim)
	_add(StickySlimeStatus.new())
	_add(CardStatus.new(WRAP_SLIME, "Обволакивающая слизь", CardStatus.Kind.STACKS, Color(0.45, 0.9, 1.0)))
	_add(EmpowerStatus.new())
	_add(ExposedStatus.new())
