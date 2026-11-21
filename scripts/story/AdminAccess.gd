extends RefCounted
class_name AdminAccess
## Доступ к админ-панелям (инвентарь, подготовка к бою, бой, F9). Пока закрыт — панелей не видно
## и не нажать. Открывается:
##   — особым именем (data/names/name_rules.json, "admin": true) — пока это имя стоит;
##   — или навсегда, если проиграть LOSSES_TO_UNLOCK забега, не набрав в них опыта.

const LOSS_COUNTER := "zero_xp_losses"
const LOSSES_TO_UNLOCK := 2

static func unlocked() -> bool:
	if StoryState_ == null:
		return false
	if StoryState_.get_counter(LOSS_COUNTER) >= LOSSES_TO_UNLOCK:
		return true
	return NameRules.grants_admin()

## Забег проигран; xp_gained — сколько опыта в нём набрали.
static func note_loss(xp_gained: int) -> void:
	if StoryState_ != null and xp_gained <= 0:
		StoryState_.add_counter(LOSS_COUNTER, 1)
