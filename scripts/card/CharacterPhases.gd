class_name CharacterPhases
extends RefCounted
## Фазы героини по здоровью: на 60% HP и ниже — фаза 2, на 25% и ниже — фаза 3.
## Картинки фаз лежат рядом с обычными и называются так же + «_phase<N>»:
##   witch_battle.png -> witch_battle_phase2.png, witch_battle_phase3.png (чиби на поле)
##   witch_drag.png   -> witch_drag_phase2.png,   witch_drag_phase3.png   (портрет при перетаскивании)
## Нет картинки нужной фазы — берётся предыдущая фаза, а если и её нет — обычная картинка.
## Лечение выше порога возвращает прежнюю картинку.
## Смерть: <id>_dead.png рядом с <id>_battle.png (dead_texture) — вместо серого цвета.

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

## Картинка смерти рядом с обычной: aki_battle.png -> aki_dead.png (или <имя>_dead.png). Нет — null.
static func dead_texture(base: Texture2D) -> Texture2D:
	if base == null or base.resource_path == "":
		return null
	var key := base.resource_path + "#dead"
	if _cache.has(key):
		return _cache[key]
	var p := base.resource_path
	var stem := p.get_basename()
	var out: Texture2D = null
	for cand in ["%s_dead.%s" % [stem.trim_suffix("_battle"), p.get_extension()], "%s_dead.%s" % [stem, p.get_extension()]]:
		if ResourceLoader.exists(cand):
			out = load(cand) as Texture2D
			break
	_cache[key] = out
	return out

## «Лежит»: картинка смерти, а если её нет — пока фаза 3 (у ведьмочки), чтобы не заваливать
## обычную картинку набок. Нет и фазы 3 — null (тогда завалится набок, как раньше).
static func lying_texture(base: Texture2D) -> Texture2D:
	var t := dead_texture(base)
	if t != null:
		return t
	t = texture(base, 3)
	return t if t != base else null

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
