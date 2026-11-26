extends DreamGame
## Рикка ловит монетки: сверху падают монетки, Рикка ходит ← → / A D. Поймала — очко.
## move_speed, spawn_every (сек), fall_speed [от, до].

const COIN := "res://assets/items/loot/coin.png"
const GROUND := 790.0
const CATCH_W := 110.0
const CATCH_TOP := 300.0   ## насколько выше ног ещё ловит

var rikka: Sprite2D
var coins: Array[Sprite2D] = []
var next_in := 0.3
var _coin_tex: Texture2D

func build() -> void:
	_coin_tex = load(COIN) as Texture2D
	rikka = make_sprite(char_texture("rikka"), 340)
	rikka.position = Vector2(960, GROUND)

func play(delta: float) -> void:
	var dx := held_dir().x
	rikka.position.x = clampf(rikka.position.x + dx * cf("move_speed", 900) * delta, 120.0, 1800.0)
	if dx != 0.0:
		rikka.flip_h = dx > 0.0
	next_in -= delta
	if next_in <= 0.0:
		next_in = cf("spawn_every", 0.45) * randf_range(0.7, 1.3)
		var c := make_icon(_coin_tex, 64)
		c.position = Vector2(randf_range(140.0, 1780.0), -40.0)
		c.set_meta("v", cf_range("fall_speed", Vector2(380, 620)))
		coins.append(c)
	for c: Sprite2D in coins.duplicate():
		c.position.y += float(c.get_meta("v")) * delta
		c.rotation += delta * 3.0
		var feet := rikka.position
		if absf(c.position.x - feet.x) < CATCH_W and c.position.y > feet.y - CATCH_TOP and c.position.y < feet.y - 60.0:
			coins.erase(c)
			add_points(1, c.position)
			poof(c, 0.15)
		elif c.position.y > GROUND + 40.0:
			coins.erase(c)
			poof(c, 0.3)
