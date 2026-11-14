class_name CharacterPhases
extends RefCounted
## Фазы героини по здоровью: на 60% HP и ниже — фаза 2, на 25% и ниже — фаза 3.
## Картинки фаз лежат рядом с обычными и называются так же + «_phase<N>»:
##   witch_battle.png -> witch_battle_phase2.png, witch_battle_phase3.png (чиби на поле)
##   witch_drag.png   -> witch_drag_phase2.png,   witch_drag_phase3.png   (портрет при перетаскивании)
## Нет картинки нужной фазы — берётся предыдущая фаза, а если и её нет — обычная картинка.
## Лечение выше порога возвращает прежнюю картинку.

## [доля HP (включительно), фаза] — от меньшей доли к большей.
const THRESHOLDS := [[0.25, 3], [0.60, 2]]

static var _cache: Dictionary = {}

static func phase_of(unit: Unit) -> int:
	if unit == null or unit.max_hp <= 0:
		return 1
	var r := float(unit.hp) / float(unit.max_hp)
	for t in THRESHOLDS:
		if r <= float(t[0]):
			return int(t[1])
	return 1

static func texture(base: Texture2D, phase: int) -> Texture2D:
	if base == null or phase <= 1 or base.resource_path == "":
		return base
	var key := "%s#%d" % [base.resource_path, phase]
	if _cache.has(key):
		return _cache[key]
	var out: Texture2D = base
	var p := base.resource_path
	for n in range(phase, 1, -1):
		var cand := "%s_phase%d.%s" % [p.get_basename(), n, p.get_extension()]
		if ResourceLoader.exists(cand):
			out = load(cand) as Texture2D
			break
	_cache[key] = out
	return out
