extends CardStatus
class_name StickySlimeStatus
## Липкая слизь (на врагах; враги-слизнедевочки вешают её и на героев). Оглушение — за каждые STUN_EVERY НОВЫХ стаков: считаются только
## наложенные стаки, снятие счётчик не уменьшает (снял один, наложил один — это 1 новый, а не стан).
## Счётчик «до стана» живёт в данных статуса (ключ "gained") и переживает снятие всех стаков.

const STUN_EVERY := 5

func _init() -> void:
	super("sticky_slime", "Липкая слизь", Kind.STACKS, Color(0.55, 1.0, 0.45))

## Статус остаётся на враге, пока есть стаки или копится счётчик до стана.
func is_active(s: Dictionary) -> bool:
	return int(s["stacks"]) > 0 or int(s.get("gained", 0)) > 0

func label(s: Dictionary) -> String:
	var left := STUN_EVERY - int(s.get("gained", 0))
	return "%s %d (стан через %d)" % [title, int(s["stacks"]), left]

func on_added(combat: CardCombat, unit: Unit, old_stacks: int, s: Dictionary) -> void:
	var added := int(s["stacks"]) - old_stacks
	if added <= 0 or STUN_EVERY <= 0:
		return
	var gained := int(s.get("gained", 0)) + added
	var stuns := gained / STUN_EVERY
	s["gained"] = gained % STUN_EVERY
	if stuns > 0:
		combat.stun(unit)
