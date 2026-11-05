extends RigidBody2D
class_name IngredientBody
## Физический ингредиент: иконка предмета + круглая коллизия. Его можно хватать мышкой.

const RADIUS := 40.0
const ICON_SIZE := 88.0

var item_id: String = ""
var accepted := false   ## уже брошен в котёл и засчитан

func setup(id: String, tex: Texture2D) -> void:
	item_id = id
	add_to_group("ingredient")
	mass = 1.0
	gravity_scale = 2.2
	linear_damp = 0.25
	angular_damp = 0.8
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.25
	mat.friction = 0.7
	physics_material_override = mat
	collision_layer = 1
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = tex
	if tex != null:
		var biggest := maxf(tex.get_width(), tex.get_height())
		if biggest > 0.0:
			sprite.scale = Vector2.ONE * (ICON_SIZE / biggest)
	add_child(sprite)
