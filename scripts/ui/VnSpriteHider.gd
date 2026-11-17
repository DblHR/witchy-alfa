extends Node
class_name VnSpriteHider
## Пока открыто окно диалога (VN), плавно прячет указанные картинки на фоне (продавца, медсестру,
## гуляющих по дому героинь), чтобы на экране был только портрет из самого диалога.
##
##   VnSpriteHider.attach(self, [npc_sprite])

const FADE_TIME := 0.2

var _items: Array = []
var _tween: Tween
var _hidden := false

static func attach(host: Node, items: Array) -> VnSpriteHider:
	var h := VnSpriteHider.new()
	h.name = "VnSpriteHider"
	h._items = items.duplicate()
	host.add_child(h)
	return h

func add_item(item: CanvasItem) -> void:
	if item != null and not _items.has(item):
		_items.append(item)
		if _hidden:
			item.modulate.a = 0.0

func _ready() -> void:
	if DialogueManager_ != null and not DialogueManager_.showing_changed.is_connected(_on_showing_changed):
		DialogueManager_.showing_changed.connect(_on_showing_changed)
	_sync.call_deferred()

func _exit_tree() -> void:
	if DialogueManager_ != null and DialogueManager_.showing_changed.is_connected(_on_showing_changed):
		DialogueManager_.showing_changed.disconnect(_on_showing_changed)

func _on_showing_changed(_on: bool) -> void:
	## Отложенно: два диалога подряд (закрылся — сразу открылся следующий) не мигают спрайтом.
	_sync.call_deferred()

func _sync() -> void:
	if not is_inside_tree():
		return
	var hide := DialogueManager_ != null and DialogueManager_.is_showing()
	if hide == _hidden:
		return
	_hidden = hide
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_items = _items.filter(func(it) -> bool: return is_instance_valid(it))
	if _items.is_empty():
		return
	_tween = create_tween().set_parallel(true)
	for it in _items:
		_tween.tween_property(it, "modulate:a", 0.0 if hide else 1.0, FADE_TIME)

func is_hidden() -> bool:
	return _hidden
