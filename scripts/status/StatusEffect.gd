extends Resource
class_name StatusEffect

@export var icon: Texture2D
@export var ui_name: String = ""

@export var duration: float = 0.0
var time_left: float = 0.0

func _init(dur: float = 0.0) -> void:
	duration = dur
	time_left = dur

func on_apply(_unit: Unit) -> void:
	pass

func update(_unit: Unit, delta: float) -> void:
	time_left -= delta

func on_expire(_unit: Unit) -> void:
	pass

func is_finished() -> bool:
	return time_left <= 0.0

func blocks_attacks() -> bool:
	return false

func blocks_casting() -> bool:
	return false

func flips_faction_for_autoattacks() -> bool:
	return false

func ui_time_left() -> float:
	return time_left

func ui_stack_count() -> int:
	return 1

func ui_stack_group_key() -> String:
	var script_res = get_script()
	if script_res is Script and script_res.resource_path != "":
		return script_res.resource_path
	return get_class()
