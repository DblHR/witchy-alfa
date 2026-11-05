extends Node
class_name DialogueManager

const OVERLAY_SCENE := preload("res://scenes/DialogueOverlay.tscn")
## Диалог живёт в своём слое: выше любого игрового интерфейса (в т.ч. CanvasLayer карточного боя),
## но ниже меню паузы (слой 100). Иначе экран на CanvasLayer перекрывает диалог и забирает клики.
const OVERLAY_LAYER := 50

var _overlay: DialogueOverlay = null
var _overlay_layer: CanvasLayer = null
var _overlay_scene_id: int = 0

func _ready() -> void:
	var tree := get_tree()
	if tree == null:
		return
	if tree.has_signal("scene_changed"):
		var cb := Callable(self, "_on_current_scene_changed")
		if not tree.is_connected("scene_changed", cb):
			tree.connect("scene_changed", cb)

func _on_current_scene_changed() -> void:
	var current_scene := get_tree().current_scene
	var current_scene_id := current_scene.get_instance_id() if current_scene != null else 0
	if _overlay != null and is_instance_valid(_overlay) and _overlay_scene_id != 0 and _overlay_scene_id != current_scene_id:
		hide_overlay()

func _create_overlay() -> DialogueOverlay:
	hide_overlay()
	var root := get_tree().root
	if root == null:
		return null
	var overlay := OVERLAY_SCENE.instantiate() as DialogueOverlay
	var layer := CanvasLayer.new()
	layer.layer = OVERLAY_LAYER
	root.add_child(layer)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.tree_exited.connect(layer.queue_free)
	_overlay_layer = layer
	_overlay = overlay
	var current_scene := get_tree().current_scene
	_overlay_scene_id = current_scene.get_instance_id() if current_scene != null else 0
	_overlay.sequence_finished.connect(_on_overlay_finished, CONNECT_ONE_SHOT)
	return overlay

func _on_overlay_finished() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.call_deferred("queue_free")
	_overlay = null
	_overlay_scene_id = 0

func show_sequence(lines: Array, on_finished: Callable = Callable()) -> void:
	var overlay := _create_overlay()
	if overlay == null:
		return
	overlay.show_sequence(lines, on_finished)

func show_sequence_resource(seq: DialogueSequence, on_finished: Callable = Callable()) -> void:
	var overlay := _create_overlay()
	if overlay == null:
		return
	overlay.show_sequence_resource(seq, on_finished)

func hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_overlay_scene_id = 0

func is_showing() -> bool:
	return _overlay != null and is_instance_valid(_overlay) and _overlay.visible
