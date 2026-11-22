extends RefCounted
class_name EscClose
## Esc закрывает открытые «дополнительные» окна (меню колоды, просмотр карт, окно кормления…).
## Окно регистрируется: EscClose.register(окно, func(): закрыть) — Esc закроет самое верхнее
## из видимых. Окна, которые нельзя закрыть Esc'ом (ввод имени, «Получено»), — register_modal:
## пока такое открыто, Esc ничего не делает.
## Что делает Esc, если окон нет, решает PauseManagerLayer (пауза / домой).

const GROUP := &"esc_closable"
const MODAL_GROUP := &"esc_modal"

static func register(node: CanvasItem, closer: Callable) -> void:
	node.add_to_group(GROUP)
	node.set_meta("esc_closer", closer)

static func register_modal(node: CanvasItem) -> void:
	node.add_to_group(MODAL_GROUP)

static func _shown(n: Node) -> bool:
	if not is_instance_valid(n) or not (n is CanvasItem) or not (n as CanvasItem).is_visible_in_tree():
		return false
	if n.has_method("is_open") and not bool(n.call("is_open")):
		return false
	return true

static func modal_open(tree: SceneTree) -> bool:
	for n in tree.get_nodes_in_group(MODAL_GROUP):
		if _shown(n):
			return true
	return false

## Закрыть самое верхнее открытое окно. true — что-то закрыли.
static func close_top(tree: SceneTree) -> bool:
	var best: Node = null
	for n in tree.get_nodes_in_group(GROUP):
		if _shown(n) and (best == null or _above(n, best)):
			best = n
	if best == null:
		return false
	var c = best.get_meta("esc_closer") if best.has_meta("esc_closer") else null
	if c is Callable and (c as Callable).is_valid():
		(c as Callable).call()
	elif best.has_method("close"):
		best.call("close")
	else:
		(best as CanvasItem).visible = false
	return true

## a выше b на экране: больший z_index, а при равном — позже в дереве.
static func _above(a: Node, b: Node) -> bool:
	if b.is_ancestor_of(a):
		return true   ## окно внутри окна (вопрос внутри выбора слота) — выше
	if a.is_ancestor_of(b):
		return false
	var za := (a as CanvasItem).z_index
	var zb := (b as CanvasItem).z_index
	if za != zb:
		return za > zb
	return a.is_greater_than(b)
