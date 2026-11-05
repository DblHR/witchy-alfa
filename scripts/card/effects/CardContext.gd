extends RefCounted
class_name CardContext
## Всё, что нужно эффекту при розыгрыше: бой, кто играет, по кому и какой картой.

var combat: CardCombat
var caster: Unit          ## владелец карты; null для общих карт и эстуса
var targets: Array[Unit]  ## цели, выбранные при розыгрыше
var card: CardInstance

func _init(p_combat: CardCombat, p_caster: Unit, p_targets: Array[Unit], p_card: CardInstance) -> void:
	combat = p_combat
	caster = p_caster
	targets = p_targets
	card = p_card
