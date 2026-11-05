extends CardEffect
class_name EffConsumeStatus
## Потратить стаки статуса и получить что-то за каждый стак.
## Источник стаков — цели эффекта (target_mode). Получатель — сам источник или владелец карты.
## Пример: Аки снимает обволакивающую слизь с союзника и даёт ему щит за каждый стак.

enum Gain { NOTHING, HEAL, SHIELD, EMPOWER }
enum Receiver { SOURCE, CASTER }

@export var status: String = ""
## Сколько стаков тратить максимум (0 — все).
@export var max_stacks: int = 0
## Меньше стольких стаков — эффект не срабатывает.
@export var min_stacks: int = 1
@export var gain: Gain = Gain.HEAL
@export var receiver: Receiver = Receiver.SOURCE
## Сколько дать за один стак (скейлится).
@export var base: int = 0
@export var atk_ratio: float = 0.0
@export var mag_ratio: float = 0.0
## Если стаки потрачены — наложить на источник ещё и этот статус (например, Уязвимость).
@export var then_status: String = ""
@export var then_stacks: int = 0
@export var then_turns: int = 0

func value(caster: Unit) -> int:
	return scaled(base, atk_ratio, mag_ratio, caster)

func bonus_value(_caster: Unit) -> int:
	return max_stacks

func _apply_one(ctx: CardContext, source: Unit) -> void:
	var have := ctx.combat.stacks(source, status)
	if have < maxi(1, min_stacks):
		return
	var spent := ctx.combat.remove_stacks(source, status, max_stacks)
	if spent <= 0:
		return
	var rcv: Unit = ctx.caster if receiver == Receiver.CASTER else source
	var amount := value(ctx.caster) * spent
	if rcv != null and amount > 0:
		match gain:
			Gain.HEAL:
				ctx.combat.heal(rcv, amount)
			Gain.SHIELD:
				ctx.combat.add_shield(rcv, amount)
			Gain.EMPOWER:
				ctx.combat.add_status(rcv, CardStatuses.EMPOWER, amount, 0)
	if then_status != "":
		ctx.combat.add_status(source, then_status, then_stacks, then_turns)

func describe(caster: Unit, card_target: CardInstance.Target) -> String:
	var how_many := "все" if max_stacks <= 0 else "до %d" % max_stacks
	var text := "Тратит %s стаки [e]%s[/e] (%s)" % [how_many, status_title(status), target_phrase(card_target)]
	match gain:
		Gain.HEAL:
			text += ": [h]%d[/h] лечения за стак" % value(caster)
		Gain.SHIELD:
			text += ": [s]%d[/s] щита за стак" % value(caster)
		Gain.EMPOWER:
			text += ": [e]Усиление %d[/e] за стак" % value(caster)
	if then_status != "":
		text += ", затем [e]%s[/e]" % status_title(then_status)
	return text + "."
