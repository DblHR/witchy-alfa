extends EffHeal
class_name EffEstusHeal
## Лечение эстусом: сила берётся из прокачки (DungRun.estus_power), а не из характеристик.

func value(_caster: Unit) -> int:
	return DungRun.estus_power if DungRun != null else base
