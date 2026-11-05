extends Control
class_name StirringMinigame

signal finished(success: bool, score: float)

@export_range(0.5, 6.0, 0.1) var required_turns: float = 2.0
@export var clockwise: bool = true
@export_range(0.20, 0.60, 0.01) var ring_radius_norm: float = 0.34
@export_range(0.02, 0.28, 0.01) var ring_half_width_norm: float = 0.18
@export_range(0.05, 1.00, 0.01) var stability_loss_multiplier: float = 0.42
@export var ring_color: Color = Color(0.97, 0.92, 0.78, 0.30)
@export var progress_color: Color = Color(0.89, 0.60, 0.25, 0.96)
@export var spoon_color: Color = Color(0.74, 0.52, 0.92, 1.0)

var _active: bool = false
var _tracking: bool = false
var _progress_turns: float = 0.0
var _stability: float = 1.0
var _last_angle: float = 0.0
var _last_pointer: Vector2 = Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	queue_redraw()

func begin(turns_needed: float = 2.0, use_clockwise: bool = true, stability_loss: float = 0.42) -> void:
	required_turns = maxf(turns_needed, 0.35)
	clockwise = use_clockwise
	stability_loss_multiplier = clampf(stability_loss, 0.02, 0.45)
	_progress_turns = 0.0
	_stability = 1.0
	_tracking = false
	_active = true
	_last_angle = 0.0
	_last_pointer = _spoon_tip_position()
	queue_redraw()

func cancel() -> void:
	_active = false
	_tracking = false
	queue_redraw()

func is_active() -> bool:
	return _active

func get_progress_ratio() -> float:
	if required_turns <= 0.0:
		return 0.0
	return clampf(_progress_turns / required_turns, 0.0, 1.0)

func get_stability_ratio() -> float:
	return clampf(_stability, 0.0, 1.0)

func _gui_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		var mouse_button: InputEventMouseButton = event
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			if mouse_button.pressed:
				_tracking = true
				_last_pointer = mouse_button.position
				_last_angle = _angle_for_point(mouse_button.position)
				accept_event()
			else:
				_tracking = false
				accept_event()
	elif event is InputEventMouseMotion and _tracking:
		var mouse_motion: InputEventMouseMotion = event
		_process_stir_motion(mouse_motion.position)
		accept_event()

func _process_stir_motion(local_position: Vector2) -> void:
	var current_angle: float = _angle_for_point(local_position)
	var delta_angle: float = wrapf(current_angle - _last_angle, -PI, PI)
	_last_angle = current_angle
	_last_pointer = local_position

	if absf(delta_angle) > 1.2:
		queue_redraw()
		return

	var center: Vector2 = size * 0.5
	var radius: float = local_position.distance_to(center)
	var target_radius: float = minf(size.x, size.y) * ring_radius_norm
	var ring_half_width: float = minf(size.x, size.y) * ring_half_width_norm
	var radius_offset: float = absf(radius - target_radius)
	var direction_sign: float = 1.0 if clockwise else -1.0

	var direction_progress: float = maxf(direction_sign * delta_angle, 0.0)
	var radius_bonus: float = 1.0 - clampf(radius_offset / maxf(target_radius + ring_half_width, 1.0), 0.0, 0.45)
	if direction_progress > 0.0:
		_progress_turns += ((direction_progress / TAU) * radius_bonus)
		_stability = minf(1.0, _stability + absf(delta_angle) * 0.02)
	else:
		_stability -= maxf(absf(delta_angle), 0.02) * stability_loss_multiplier * 0.18

	if radius_offset > ring_half_width * 1.8:
		_stability -= minf(radius_offset / maxf(target_radius, 1.0), 0.25) * stability_loss_multiplier * 0.1

	if _progress_turns >= required_turns:
		_finish(true)
		return
	if _stability <= 0.0:
		_finish(false)
		return
	queue_redraw()

func _finish(success: bool) -> void:
	_active = false
	_tracking = false
	var score: float = clampf((get_progress_ratio() * 0.8) + (get_stability_ratio() * 0.2), 0.0, 1.0)
	finished.emit(success, score)
	queue_redraw()

func _angle_for_point(point: Vector2) -> float:
	var delta: Vector2 = point - (size * 0.5)
	return atan2(delta.y, delta.x)

func _spoon_tip_position() -> Vector2:
	var angle: float = _last_angle
	var radius: float = minf(size.x, size.y) * ring_radius_norm
	return (size * 0.5) + Vector2(cos(angle), sin(angle)) * radius

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * ring_radius_norm
	var ring_width: float = maxf(minf(size.x, size.y) * 0.06, 10.0)
	var progress_arc: float = TAU * get_progress_ratio()
	var start_angle: float = -PI * 0.5

	draw_arc(center, radius, 0.0, TAU, 72, ring_color, ring_width, true)
	if progress_arc > 0.01:
		draw_arc(center, radius, start_angle, start_angle + progress_arc, 72, progress_color, ring_width, true)

	var spoon_tip: Vector2 = _spoon_tip_position()
	draw_line(center, spoon_tip, spoon_color, maxf(ring_width * 0.4, 6.0), true)
	draw_circle(spoon_tip, maxf(ring_width * 0.3, 8.0), spoon_color)
	draw_circle(center, maxf(ring_width * 0.42, 10.0), Color(0.09, 0.07, 0.12, 0.85))
