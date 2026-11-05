extends StatusEffect
class_name WeakeningStacksEffect

const MAX_STACKS := 10

@export var stacks: int = 1

func _init(initial_stacks: int = 1) -> void:
	stacks = clamp(initial_stacks, 0, MAX_STACKS)
	duration = 999999.0
	time_left = duration
	icon = load("res://ui/status_icons/bleed_stack.png")
	ui_name = "Ослабление x%d" % stacks

func on_apply(_unit: Unit) -> void:
	time_left = duration
	_update_name()

func add_stacks(amount: int) -> void:
	stacks = clamp(stacks + amount, 0, MAX_STACKS)
	_update_name()
	time_left = duration

func remove_all_stacks() -> int:
	var removed := stacks
	stacks = 0
	_update_name()
	time_left = 0.0
	return removed

func is_finished() -> bool:
	return stacks <= 0 or time_left <= 0.0

func _update_name() -> void:
	ui_name = "Ослабление x%d" % max(0, stacks)

func ui_stack_count() -> int:
	return max(0, stacks)

func ui_stack_group_key() -> String:
	return "weakening_stacks"
