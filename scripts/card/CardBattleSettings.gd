extends RefCounted
class_name CardBattleSettings
## Переключатель режима боя. Ставится в сцене Setup (чекбокс «Карточный бой»).
## Живёт только в рамках запущенной игры (в сейв пока не пишется).

static var enabled: bool = false
