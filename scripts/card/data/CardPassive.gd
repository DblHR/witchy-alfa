extends Resource
class_name CardPassive
## Пассивка героя в карточном бою. Подключается к персонажу через CharacterData.card_passive.
## В начале боя вызывается attach(): пассивка подписывается на сигналы CardCombat
## (damage_dealt, card_played…) и реагирует на них. Ресурс общий для всех боёв,
## поэтому состояние хранится не в полях ресурса, а в замыкании attach().

## Короткое описание для экрана персонажа.
@export_multiline var description: String = ""

func attach(_combat: CardCombat, _owner: Unit) -> void:
	pass
