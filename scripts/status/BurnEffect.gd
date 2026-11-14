extends StatusEffect
class_name BurnEffect

@export var damage_per_tick: int = 6
@export var ticks: int = 3
@export var interval: float = 1.0
@export var scale_mult: float = 1.0

var _ticks_left: int = 0
var _accum: float = 0.0

func _init() -> void:
	duration = 999999.0
	time_left = duration
	icon = load("res://assets/ui/status/fire_status.png")
	if ui_name == "":
		ui_name = "Burn"

func on_apply(_unit: Unit) -> void:
	_ticks_left = max(1, ticks)
	_accum = 0.0

	duration = 999999.0
	time_left = duration

	if _ticks_left <= 0:
		time_left = 0.0

func update(unit: Unit, delta: float) -> void:
	if _ticks_left <= 0:
		time_left = 0.0
		return

	if interval <= 0.0:
		while _ticks_left > 0:
			_apply_tick(unit)
		return

	_accum += delta

	while _accum >= interval and _ticks_left > 0:
		_accum -= interval
		_apply_tick(unit)

	if _ticks_left <= 0:
		time_left = 0.0

func _apply_tick(unit: Unit) -> void:
	if unit == null or unit.is_dead:
		_ticks_left = 0
		time_left = 0.0
		return

	var direct_damage = max(1, int(round(float(damage_per_tick) * scale_mult)))
	unit.take_damage(direct_damage)
	_ticks_left -= 1

	if _ticks_left <= 0:
		time_left = 0.0
