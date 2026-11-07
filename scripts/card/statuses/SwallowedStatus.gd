extends CardStatus
class_name SwallowedStatus
## «Проглочена»: героиня внутри босса. Её карты не разыгрываются (как при оглушении),
## враги её не выбирают целью. Снимается, когда босс выплёвывает (см. EnemyFufu).

func _init() -> void:
	super(CardStatuses.SWALLOWED, "Проглочена", Kind.STACKS, Color(0.55, 1.0, 0.75))
	skips_turn = true
	max_stacks = 1

func label(_s: Dictionary) -> String:
	return title

func float_text(_stacks: int, _turns: int) -> String:
	return "Проглочена!"
