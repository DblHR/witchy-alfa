extends DreamGame
## Сессилия прибирается: по полу разбросаны вещи — подобрать (подойти, руки должны быть пустые;
## нести можно только одну) и отнести в сундук. Каждая вещь в сундуке — очко.
## Ходить — стрелки / WASD. move_speed, items_on_floor.

const CHEST := "res://assets/ui/dreams/dream_chest.png"
const CHEST_OPEN := "res://assets/ui/dreams/dream_chest_open.png"
const CHEST_POS := Vector2(1690, 720)
const ITEMS := [
	"res://assets/items/potions/slime_potion.png", "res://assets/items/potions/energy_tonic.png",
	"res://assets/items/potions/rage_phial.png", "res://assets/items/ingredients/quartz.png",
	"res://assets/items/ingredients/fruit.png", "res://assets/items/ingredients/sweet.png",
	"res://assets/items/food/jelly.png", "res://assets/items/food/applepies.png",
	"res://assets/items/loot/slime_goop.png", "res://assets/items/staffs/heart_staff_common.png",
	"res://assets/items/quest/warm_headphones.png",
]
const PICK_DIST := 80.0
const CHEST_DIST := 140.0

var sess: Sprite2D
var chest: Sprite2D
var items: Array[Sprite2D] = []
var carried: Sprite2D
var _base_scale := Vector2.ONE

func build() -> void:
	chest = make_sprite(load(CHEST) as Texture2D, 170)
	chest.position = CHEST_POS
	chest.z_index = int(CHEST_POS.y)
	sess = make_sprite(char_texture("sessilia"), 300)
	sess.position = Vector2(500, 760)
	_base_scale = sess.scale
	for i in int(cf("items_on_floor", 6)):
		_spawn_item()

func _spawn_item() -> void:
	var it := make_icon(load(ITEMS[randi() % ITEMS.size()]) as Texture2D, 76)
	for tries in 12:
		it.position = Vector2(randf_range(FIELD.position.x + 60, FIELD.end.x - 260), randf_range(FIELD.position.y + 40, FIELD.end.y - 30))
		if it.position.distance_to(CHEST_POS) > 260.0 and it.position.distance_to(sess.position) > 150.0:
			break
	it.z_index = int(it.position.y)
	it.scale *= 0.2
	it.create_tween().tween_property(it, "scale", it.scale * 5.0, 0.25).set_trans(Tween.TRANS_BACK)
	items.append(it)

func play(delta: float) -> void:
	var d := held_dir()
	var p := sess.position + d * cf("move_speed", 520) * delta
	sess.position = Vector2(clampf(p.x, FIELD.position.x, FIELD.end.x), clampf(p.y, FIELD.position.y + 40, FIELD.end.y))
	if d.x != 0.0:
		sess.flip_h = d.x > 0.0
	# ближе к горизонту — чуть меньше
	var k := lerpf(0.82, 1.05, (sess.position.y - FIELD.position.y) / FIELD.size.y)
	sess.scale = _base_scale * k
	sess.z_index = int(sess.position.y)
	sess.offset.y = -float(sess.texture.get_height()) + sin(Time.get_ticks_msec() * 0.012) * (8.0 if d != Vector2.ZERO else 0.0)
	if carried != null:
		carried.position = sess.position + Vector2(0, -290.0 * k)
		carried.z_index = sess.z_index + 1
		if sess.position.distance_to(CHEST_POS + Vector2(-40, 0)) < CHEST_DIST:
			_deposit()
	else:
		for it in items:
			if it.position.distance_to(sess.position + Vector2(0, -10)) < PICK_DIST:
				carried = it
				items.erase(it)
				hop(sess, 16.0, 0.2)
				break

func _deposit() -> void:
	var it := carried
	carried = null
	add_points(1, CHEST_POS + Vector2(0, -200))
	var tw := it.create_tween().set_parallel(true)
	tw.tween_property(it, "position", CHEST_POS + Vector2(0, -60), 0.25)
	tw.tween_property(it, "scale", it.scale * 0.3, 0.25)
	tw.chain().tween_callback(it.queue_free)
	_set_chest(load(CHEST_OPEN) as Texture2D)
	hop(chest, 18.0, 0.25)
	get_tree().create_timer(0.4).timeout.connect(func() -> void:
		if is_instance_valid(chest):
			_set_chest(load(CHEST) as Texture2D))
	_spawn_item()

## Меняет картинку сундука, сохраняя масштаб и «ноги» на полу.
func _set_chest(tex: Texture2D) -> void:
	chest.texture = tex
	chest.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
