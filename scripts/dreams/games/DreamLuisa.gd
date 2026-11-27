extends DreamGame
## Луисе несут подношения: Луиса лежит справа, к ней очередь (слизни, героини, НПС), у каждого
## что-то в руках. Еда — ↑ / W (взять), не еда — ↓ / S (отказать). Верно — очко.
## food_chance — сколько из подношений еда.

const FOOD := [
	"res://assets/items/food/applepies.png", "res://assets/items/food/jelly.png",
	"res://assets/items/food/kebab.png", "res://assets/items/food/steak.png",
	"res://assets/items/ingredients/fruit.png", "res://assets/items/ingredients/sweet.png",
	"res://assets/items/ingredients/meat.png", "res://assets/items/ingredients/vegetable.png",
]
const NOT_FOOD := [
	"res://assets/items/potions/slime_potion.png", "res://assets/items/potions/energy_tonic.png",
	"res://assets/items/ingredients/quartz.png", "res://assets/items/ingredients/alchemy_slag.png",
	"res://assets/items/staffs/stick_staff_common.png", "res://assets/items/quest/return_stone.png",
	"res://assets/items/quest/warm_headphones.png", "res://assets/items/loot/coin.png",
]
const BEARERS := ["slime", "slime", "witch", "warrior", "aki", "fufu", "rikka", "sessilia"]
const LUISA_LYING := "res://assets/characters/luisa/luisa_dead.png"
const LUISA_POS := Vector2(1580, 800)
const GROUND := 780.0
const FRONT_X := 1200.0
const STEP_X := 210.0
const QUEUE := 6

var luisa: Sprite2D
var queue: Array[Node2D] = []
var _busy := false

func build() -> void:
	## лежит в позе смерти (luisa_dead.png), головой к очереди
	luisa = make_sprite(load(LUISA_LYING) as Texture2D, 640)
	luisa.position = LUISA_POS
	for i in QUEUE:
		_add_bearer(FRONT_X - STEP_X * i)

func _add_bearer(x: float) -> void:
	var holder := Node2D.new()
	add_child(holder)
	holder.position = Vector2(x, GROUND)
	var kind: String = BEARERS[randi() % BEARERS.size()]
	var tex := slime_texture() if kind == "slime" else char_texture(kind)
	var body := make_sprite(tex, 140.0 if kind == "slime" else (260.0 if kind in ["rikka", "sessilia"] else 230.0), holder)
	body.flip_h = true
	var food := randf() < cf("food_chance", 0.5)
	var list: Array = FOOD if food else NOT_FOOD
	var item := make_icon(load(String(list[randi() % list.size()])) as Texture2D, 72, holder)
	item.position = Vector2(0, -float(body.texture.get_height()) * body.scale.y - 50.0)
	holder.set_meta("food", food)
	holder.set_meta("item", item)
	queue.append(holder)

func play(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.003
	for i in queue.size():
		var h := queue[i]
		var it: Sprite2D = h.get_meta("item")
		it.position.x = sin(t + i) * 4.0

func key(dir: Vector2i) -> void:
	if _busy or queue.is_empty() or (dir != Vector2i.UP and dir != Vector2i.DOWN):
		return
	_busy = true
	var h: Node2D = queue.pop_front()
	var food := bool(h.get_meta("food"))
	var accept := dir == Vector2i.UP
	var right := accept == food
	var item: Sprite2D = h.get_meta("item")
	if right:
		add_points(1, h.position + Vector2(0, -330))
	else:
		float_text("Не то!", h.position + Vector2(0, -330), Color(1, 0.5, 0.5))
	if accept:
		# Подношение улетает Луисе.
		var tw := item.create_tween().set_parallel(true)
		tw.tween_property(item, "global_position", luisa.position + Vector2(-170, -90), 0.25)
		tw.tween_property(item, "modulate:a", 0.0, 0.25).set_delay(0.15)
		hop(luisa, 18.0 if food else 6.0, 0.25)
		hop(h, 30.0, 0.3)
	else:
		item.create_tween().tween_property(item, "modulate:a", 0.4, 0.2)
	# Уходит вверх-назад, очередь подходит.
	var leave := h.create_tween()
	leave.tween_interval(0.25)
	leave.tween_property(h, "position", h.position + Vector2(-60, -120), 0.35)
	leave.parallel().tween_property(h, "modulate:a", 0.0, 0.35)
	leave.tween_callback(h.queue_free)
	for i in queue.size():
		queue[i].create_tween().tween_property(queue[i], "position:x", FRONT_X - STEP_X * i, 0.22).set_trans(Tween.TRANS_SINE)
	_add_bearer(FRONT_X - STEP_X * (queue.size()) - STEP_X)
	var last: Node2D = queue[queue.size() - 1]
	last.create_tween().tween_property(last, "position:x", FRONT_X - STEP_X * (queue.size() - 1), 0.3)
	await get_tree().create_timer(0.18).timeout
	_busy = false
