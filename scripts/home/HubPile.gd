extends Node2D
class_name HubPile
## Что-то лежит на полу в доме — кликнуть, чтобы забрать в сумку (+N предмета всплывает и тает).
## Появляется от дневных дел персонажей (HubEvents): зелье / шлак ведьмочки у котла, еда воина,
## лужица слизи от слизнедевочек. Лежит, пока не заберут (даже после выхода из игры).
##
## Хранится в StoryState: счётчик "hub_pile:<предмет>:<кто>:<x>:<y>" = сколько штук.
## Кучки рисуются в узле Hub.tscn → Piles (под гуляющими спереди).
## Слизь ("slime_goop") — лужица assets/ui/hub/slime_puddle.png цвета того, кто оставил (TINTS),
## остальное — значок предмета на полу.

const PREFIX := "hub_pile:"
const PUDDLE := "res://assets/ui/hub/slime_puddle.png"
const PUDDLE_ITEM := "slime_goop"
const ICON_SIZE := 72.0
const PUDDLE_WIDTH := 150.0
## Цвет лужицы по тому, кто оставил.
const TINTS := {
	"fufu": Color(0.62, 1.0, 0.42),
	"aki": Color(1.0, 0.62, 0.8),
	"luisa": Color(0.6, 0.82, 1.0),
}

var item_id := ""
var count := 1
var key := ""
var _sprite: Sprite2D
var _hover := false
var _taken := false

## Положить кучку (и запомнить в StoryState). Возвращает ключ.
static func drop(item: String, n: int, who: String, pos: Vector2) -> String:
	if StoryState_ == null or n <= 0:
		return ""
	var k := "%s%s:%s:%d:%d" % [PREFIX, item, who, roundi(pos.x), roundi(pos.y)]
	StoryState_.add_counter(k, n)
	return k

## Все лежащие кучки: [{key, item, who, pos, count}].
static func all() -> Array:
	var out: Array = []
	if StoryState_ == null:
		return out
	for k in StoryState_.counters.keys():
		var ks := String(k)
		if not ks.begins_with(PREFIX) or int(StoryState_.counters[k]) <= 0:
			continue
		var parts := ks.trim_prefix(PREFIX).split(":")
		if parts.size() < 4:
			continue
		out.append({"key": ks, "item": parts[0], "who": parts[1], "pos": Vector2(float(parts[2]), float(parts[3])), "count": int(StoryState_.counters[k])})
	return out

func setup(p_key: String, p_item: String, who: String, n: int) -> void:
	key = p_key
	item_id = p_item
	count = n
	name = "Pile_" + item_id
	_sprite = Sprite2D.new()
	add_child(_sprite)
	if item_id == PUDDLE_ITEM and ResourceLoader.exists(PUDDLE):
		_sprite.texture = load(PUDDLE) as Texture2D
		_sprite.self_modulate = TINTS.get(who, Color.WHITE)
		var k := PUDDLE_WIDTH / maxf(1.0, float(_sprite.texture.get_width()))
		_sprite.scale = Vector2(k, k)
		_sprite.position = Vector2(0, -float(_sprite.texture.get_height()) * k * 0.35)
	else:
		_sprite.texture = Inventory_.get_item_icon(item_id) if Inventory_ != null else null
		if _sprite.texture != null:
			var k2 := ICON_SIZE / maxf(1.0, float(maxi(_sprite.texture.get_width(), _sprite.texture.get_height())))
			_sprite.scale = Vector2(k2, k2)
		_sprite.position = Vector2(0, -ICON_SIZE * 0.5)
		# Чуть покачивается, чтобы было видно, что это можно взять.
		var tw := create_tween().set_loops()
		tw.tween_property(_sprite, "position:y", -ICON_SIZE * 0.5 - 6.0, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_sprite, "position:y", -ICON_SIZE * 0.5, 0.8).set_trans(Tween.TRANS_SINE)
	# Появление.
	scale = Vector2(0.2, 0.2)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hit(p: Vector2) -> bool:
	if _taken or _sprite == null or _sprite.texture == null:
		return false
	var sz := _sprite.texture.get_size() * _sprite.scale
	var r := Rect2(global_position + _sprite.position - sz * 0.5, sz).grow(8.0)
	return r.has_point(p)

func set_hover(on: bool) -> void:
	if on == _hover or _taken:
		return
	_hover = on
	modulate = Color(1.25, 1.25, 1.25) if on else Color.WHITE

## Забрать: в сумку, «+N предмет» всплывает, кучка тает.
func collect() -> void:
	if _taken:
		return
	_taken = true
	if Inventory_ != null:
		Inventory_.add_item(item_id, count)
	if StoryState_ != null:
		StoryState_.counters.erase(key)
	var lbl := Label.new()
	lbl.text = "+%d %s" % [count, RunItems.get_item_name(item_id)]
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	lbl.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0.25))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.position = Vector2(-120, -ICON_SIZE - 50)
	lbl.size = Vector2(240, 40)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "scale", _sprite.scale * 1.3, 0.25)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60.0, 1.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5).set_delay(0.6)
	tw.chain().tween_callback(queue_free)
