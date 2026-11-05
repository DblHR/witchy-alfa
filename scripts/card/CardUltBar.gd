extends Control
class_name CardUltBar
## Колонка ульт слева: по кнопке на героя и шкала заряда.
## Шкала заполняется картами героя; её размер = энергия ульты героя (CharacterData.max_energy).

signal ult_pressed(button: UltButton)

const CHARGE_PER_CARD := 1
const CHARGE_FROM_ANY_CARD := false   ## true: любая сыгранная карта заряжает ульты ВСЕХ героев
const START_CHARGE := 0
const COLUMN_X := 10.0                ## левый край колонки
const COLUMN_CENTER_Y := 520.0        ## вертикальный центр колонки
const STEP_Y := 122.0                 ## шаг между кнопками

var _charge: Dictionary = {}     ## id героя -> заряд
var _cards: Dictionary = {}      ## id героя -> CardInstance ульты
var _buttons: Array[UltButton] = []

func _init() -> void:
	name = "UltColumn"
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func build(heroes: Array[Unit]) -> void:
	for b in _buttons:
		b.queue_free()
	_buttons.clear()
	_cards.clear()
	_charge.clear()

	var with_ult: Array[Unit] = []
	for u in heroes:
		if u == null:
			continue
		var ult := CardLibrary.ult_for(u)
		if ult != null:
			_cards[u.data.id] = ult
			with_ult.append(u)
	var total := float(with_ult.size())
	for i in range(with_ult.size()):
		var u := with_ult[i]
		var ult: CardInstance = _cards[u.data.id]
		_charge[u.data.id] = clampi(START_CHARGE, 0, maxi(1, ult.cost))
		var b := UltButton.new()
		b.name = "Ult_%s" % u.data.id
		b.setup(u, ult, _hero_texture(u))
		b.position = Vector2(COLUMN_X, COLUMN_CENTER_Y + (float(i) - (total - 1.0) * 0.5) * STEP_Y - UltButton.BUTTON_SIZE * 0.5)
		b.pressed.connect(func(btn: UltButton) -> void: ult_pressed.emit(btn))
		add_child(b)
		_buttons.append(b)
	refresh()

func refresh() -> void:
	for b in _buttons:
		b.set_state(int(_charge.get(b.unit.data.id, 0)), not b.unit.is_dead)

func ult_of(hero_id: String) -> CardInstance:
	return _cards.get(hero_id)

## Сыгранная карта героя заряжает его ульту.
func gain(owner_id: String) -> void:
	for b in _buttons:
		var id := b.unit.data.id
		if (not CHARGE_FROM_ANY_CARD and id != owner_id) or b.unit.is_dead:
			continue
		var ult: CardInstance = _cards[id]
		_charge[id] = mini(maxi(1, ult.cost), int(_charge.get(id, 0)) + CHARGE_PER_CARD)

func spend(hero_id: String) -> void:
	_charge[hero_id] = 0

static func _hero_texture(u: Unit) -> Texture2D:
	var d: CharacterData = u.data
	if d.card_portrait != null:
		return d.card_portrait
	if d.icon != null:
		return d.icon
	return d.battle_texture
