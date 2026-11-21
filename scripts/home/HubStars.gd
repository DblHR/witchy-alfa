@tool
extends Node2D
class_name HubStars
## Звёздочки на ниточках в доме (Hub.tscn → Stars, внутри — HubStar). Физика: тяжесть, ниточка
## (чуть тянется, если оттянуть), столкновения звёзд друг с другом. Мышью звезду можно схватить,
## оттянуть и раскачать; если тянуть её дольше TOUCH_TO_SPARKLE — сыплются блёстки и она чуть светится.
## Мышь передаёт Hub.gd (star_at / grab / drag_to / release).

const GRAVITY := 1500.0
## Жёсткость ниточки, когда звезду тянут дальше длины ниточки (больше — меньше тянется).
const ROPE_K := 900.0
## Гашение колебаний вдоль ниточки (чтобы не прыгала как на резинке).
const ROPE_DAMP := 10.0
## Сопротивление воздуха (больше — быстрее успокаивается).
const AIR_DAMP := 0.9
## Как сильно звезда тянется за курсором.
const DRAG_K := 260.0
const DRAG_DAMP := 16.0
const SUBSTEPS := 4
const RESTITUTION := 0.45
## Сколько секунд тянуть, чтобы посыпались блёстки; сколько они сыплются после того, как отпустили.
const TOUCH_TO_SPARKLE := 0.5
const SPARKLE_AFTER := 1.2
const GLOW_SPEED := 3.0
## Наклон звезды следует за ниточкой с запаздыванием (покачивается).
const TILT_K := 60.0
const TILT_DAMP := 9.0

## Если две звезды «зацепились» и висят, упираясь друг в друга, дольше STUCK_TIME — на время
## перестают сталкиваться (ниточки проходят одна за другой), пока не разойдутся.
const STUCK_TIME := 1.0
const STUCK_SPEED := 40.0
var _contact: Dictionary = {}   ## "i:j" -> сколько секунд в покоящемся контакте
var _ghost: Dictionary = {}     ## "i:j" -> true, пока не разойдутся

var _grab: HubStar
var _grab_offset := Vector2.ZERO
var _grab_target := Vector2.ZERO

func stars() -> Array[HubStar]:
	var out: Array[HubStar] = []
	for c in get_children():
		if c is HubStar and (c as HubStar).texture != null:
			out.append(c as HubStar)
	return out

func star_at(p: Vector2) -> HubStar:
	if Engine.is_editor_hint() or not is_visible_in_tree():
		return null
	var best: HubStar = null
	var best_d := INF
	for s in stars():
		var d := s.pos.distance_to(p)
		if d < s.hit_radius() * 1.15 and d < best_d:
			best = s
			best_d = d
	return best

func is_grabbing() -> bool:
	return _grab != null

func grab(s: HubStar, p: Vector2) -> void:
	_grab = s
	_grab_offset = s.pos - p
	_grab_target = s.pos

func drag_to(p: Vector2) -> void:
	_grab_target = p + _grab_offset

func release() -> void:
	if _grab != null:
		_grab.touch_time = 0.0
	_grab = null

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var list := stars()
	var dt := minf(delta, 1.0 / 30.0) / float(SUBSTEPS)
	for _i in range(SUBSTEPS):
		for s in list:
			var a := Vector2(0, GRAVITY) - s.vel * AIR_DAMP
			var anchor := s.global_position
			var d := s.pos - anchor
			var dist := d.length()
			var L := s.rest_length()
			if dist > L and dist > 0.001:
				var dir := d / dist
				a -= dir * ROPE_K * (dist - L)
				var out_v := s.vel.dot(dir)
				if out_v > 0.0:
					a -= dir * out_v * ROPE_DAMP
			if s == _grab:
				a += (_grab_target - s.pos) * DRAG_K - s.vel * DRAG_DAMP
			s.vel += a * dt
			s.pos += s.vel * dt
		_collide(list, dt)
	for s in list:
		_update_look(s, delta)

func _collide(list: Array[HubStar], dt: float) -> void:
	for i in range(list.size()):
		for j in range(i + 1, list.size()):
			var a := list[i]
			var b := list[j]
			var key := "%d:%d" % [i, j]
			var d := b.pos - a.pos
			var dist := d.length()
			var min_d := a.hit_radius() + b.hit_radius()
			if dist >= min_d or dist < 0.001:
				_contact.erase(key)
				_ghost.erase(key)
				continue
			if _ghost.has(key):
				continue
			var resting := a.vel.length() < STUCK_SPEED and b.vel.length() < STUCK_SPEED and a != _grab and b != _grab
			_contact[key] = float(_contact.get(key, 0.0)) + dt if resting else 0.0
			if float(_contact[key]) > STUCK_TIME:
				_ghost[key] = true
				continue
			var n := d / dist
			var push := (min_d - dist) * 0.5
			a.pos -= n * push
			b.pos += n * push
			var rel := (b.vel - a.vel).dot(n)
			if rel < 0.0:
				var imp := -(1.0 + RESTITUTION) * rel * 0.5
				a.vel -= n * imp
				b.vel += n * imp

func _update_look(s: HubStar, delta: float) -> void:
	# Наклон: макушка смотрит на точку крепления, с запаздыванием.
	var to_anchor := s.global_position - s.pos
	var target := atan2(to_anchor.x, -to_anchor.y)
	var diff := wrapf(target - s.rot, -PI, PI)
	s.rot_vel += (diff * TILT_K - s.rot_vel * TILT_DAMP) * delta
	s.rot += s.rot_vel * delta
	# Блёстки и свечение — если звезду тянут дольше TOUCH_TO_SPARKLE.
	if s == _grab:
		s.touch_time += delta
		if s.touch_time >= TOUCH_TO_SPARKLE:
			s.sparkle_left = SPARKLE_AFTER
	else:
		s.sparkle_left = maxf(0.0, s.sparkle_left - delta)
	var on := s.sparkle_left > 0.0
	s.glow = move_toward(s.glow, 1.0 if on else 0.0, GLOW_SPEED * delta)
	if s.particles != null:
		s.particles.position = s.to_local(s.pos)
		if s.particles.emitting != on:
			s.particles.emitting = on
	s.queue_redraw()
