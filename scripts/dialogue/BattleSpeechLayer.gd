extends Control
class_name BattleSpeechLayer

const BUBBLE_SCENE := preload("res://scenes/ui/BattleSpeechBubble.tscn")

@export var bubble_offset: Vector2 = Vector2(0, -360)

var _active_bubble: Control = null
var _pending_request: Dictionary = {}

func show_line_for_actor(actor: Node, text: String) -> bool:
	if actor == null:
		return false

	text = text.strip_edges()
	if text == "":
		return false

	if _has_blocking_bubble():
		if _pending_request.is_empty():
			_pending_request = {
				"actor": actor,
				"text": text,
			}
			return true
		return false

	_spawn_bubble(actor, text)
	return true

func clear_lines() -> void:
	_pending_request.clear()
	_clear_active_bubble()

func _has_blocking_bubble() -> bool:
	if not is_instance_valid(_active_bubble):
		return false
	if _active_bubble.has_method("can_accept_next_line"):
		return not _active_bubble.can_accept_next_line()
	return true

func _spawn_bubble(actor: Node, text: String) -> void:
	if actor == null or text == "":
		return

	if not is_instance_valid(_active_bubble):
		_active_bubble = null

	var bubble := BUBBLE_SCENE.instantiate() as Control
	if bubble == null:
		return

	add_child(bubble)
	_active_bubble = bubble
	bubble.z_index = 200
	bubble.top_level = false
	bubble.set("follow_target", actor)
	bubble.set("world_offset", bubble_offset)

	if bubble.has_signal("fade_started"):
		bubble.fade_started.connect(_on_active_bubble_fade_started.bind(bubble))
	if bubble.has_signal("bubble_finished"):
		bubble.bubble_finished.connect(_on_active_bubble_finished.bind(bubble))

	if bubble.has_method("popup_text"):
		bubble.popup_text(text)
	else:
		bubble.show_text(text)

	_track_active_bubble(bubble)

func _on_active_bubble_fade_started(source_bubble: Control) -> void:
	if _active_bubble != source_bubble:
		return
	if _pending_request.is_empty():
		return

	var actor: Node = _pending_request.get("actor", null)
	var text: String = String(_pending_request.get("text", "")).strip_edges()
	_pending_request.clear()

	if actor == null or text == "":
		return

	_spawn_bubble(actor, text)

func _on_active_bubble_finished(source_bubble: Control) -> void:
	if _active_bubble == source_bubble:
		_active_bubble = null

func _track_active_bubble(bubble: Control) -> void:
	await bubble.tree_exited
	if _active_bubble == bubble:
		_active_bubble = null

func _clear_active_bubble() -> void:
	if is_instance_valid(_active_bubble):
		_active_bubble.queue_free()
	_active_bubble = null
