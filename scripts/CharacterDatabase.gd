extends Node
class_name CharacterDatabase

var by_id: Dictionary = {}

@export var characters: Array = []

func _ready() -> void:
	# на всякий случай: иногда autoload'ы и ресурсы "догружаются" прямо перед ready,
	# поэтому сделаем rebuild и сразу, и deferred.
	_rebuild()
	call_deferred("_rebuild")

func _rebuild() -> void:
	by_id.clear()

	for item in characters:
		if item == null:
			continue
		if not (item is CharacterData):
			push_error("CharDB contains non-CharacterData item: %s" % [item])
			continue

		var c: CharacterData = item
		var cid := c.id.strip_edges()
		if cid == "":
			push_error("CharacterData has empty id: %s" % c)
			continue

		if by_id.has(cid):
			push_error("Duplicate character id: %s" % cid)

		by_id[cid] = c

func get_by_id(id: String) -> CharacterData:
	# страховка: если кто-то попросил раньше, чем база собралась
	if by_id.is_empty() and not characters.is_empty():
		_rebuild()
	return by_id.get(id, null)
