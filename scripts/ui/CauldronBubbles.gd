extends RefCounted
class_name CauldronBubbles
## Пузырьки над котлом при наведении (дом, алхимия). Частицы поднимаются из прямоугольника
## center ± extents; включать / выключать — .emitting.

static func make(center: Vector2, extents: Vector2, amount: int = 14, size_k: float = 1.0) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.name = "CauldronBubbles"
	p.position = center
	p.emitting = false
	p.amount = amount
	p.lifetime = 1.1
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = extents
	p.direction = Vector2(0, -1)
	p.spread = 18.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0 * size_k
	p.initial_velocity_max = 90.0 * size_k
	p.scale_amount_min = 0.35 * size_k
	p.scale_amount_max = 0.8 * size_k
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.55, 1.0, 0.95))
	grad.set_color(1, Color(0.85, 0.3, 1.0, 0.0))
	p.color_ramp = grad
	var gt := GradientTexture2D.new()
	gt.width = 24
	gt.height = 24
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g2 := Gradient.new()
	g2.set_color(0, Color(1, 1, 1, 1))
	g2.add_point(0.6, Color(1, 1, 1, 0.9))
	g2.set_color(g2.get_point_count() - 1, Color(1, 1, 1, 0))
	gt.gradient = g2
	p.texture = gt
	return p
