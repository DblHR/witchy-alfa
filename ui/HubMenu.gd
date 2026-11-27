extends Control
class_name HubMenu
## Меню перехода между комнатами дома (сверху справа): большая кнопка «…» разворачивает /
## сворачивает ряд кнопок Лавка, Ферма, Алхимия, Дом. Меню одно и то же в доме, на ферме, в алхимии
## и в лавке (scenes/ui/HubMenu.tscn — двигайте кнопки там). Открыто/закрыто — запоминается при
## переходах между этими комнатами. Кнопка текущей комнаты чуть крупнее (CURRENT_SCALE), её подложка
## ярко-розовая (CURRENT_TINT, ui/panel_tint.gdshader), и она не нажимается.
## Кнопка = подложка (TextureButton, buttonPanel.png) + значок (дочерний TextureRect «Icon»).
##
## Новая кнопка: добавить TextureButton с подложкой и Icon в сцену и строку в TARGETS.

const SCENE := "res://scenes/ui/HubMenu.tscn"
## Имя кнопки -> куда ведёт (SceneRouter_).
const TARGETS := {
	"ShopButton": "go_to_shop",
	"FarmButton": "go_to_farm",
	"AlchemyButton": "go_to_alchemy",
	"HomeButton": "go_to_hub",
}
const SLIDE_TIME := 0.22
## Кнопка комнаты, где игрок сейчас: во столько раз крупнее остальных.
const CURRENT_SCALE := 1.18
const STAGGER := 0.035
## Подложка кнопки текущей комнаты.
const CURRENT_TINT := Color(0.94, 0.27, 0.55)
const PANEL_TINT_SHADER := preload("res://ui/panel_tint.gdshader")

## Развёрнуто ли меню (общее для всех комнат, пока игра запущена).
static var expanded := false

@onready var toggle: TextureButton = $ToggleButton
var _buttons: Array[TextureButton] = []
var _open_pos: Dictionary = {}     ## кнопка -> где она стоит в развёрнутом меню
var _current: TextureButton        ## кнопка текущей комнаты
var _tween: Tween

## Добавить меню в комнату (поверх всего, что в ней есть).
static func attach(parent: Node) -> HubMenu:
	var m := (load(SCENE) as PackedScene).instantiate() as HubMenu
	parent.add_child(m)
	return m

func _ready() -> void:
	z_index = 50
	for child in get_children():
		var b := child as TextureButton
		if b == null or b == toggle:
			continue
		_buttons.append(b)
		_open_pos[b] = b.position
		b.pivot_offset = b.size * 0.5
		if TARGETS.has(String(b.name)):
			var method := String(TARGETS[String(b.name)])
			b.pressed.connect(_go.bind(method))
			if _is_current(method):
				_current = b
				b.mouse_filter = Control.MOUSE_FILTER_IGNORE   ## тут и так — не нажимается, не подсвечивается
				var m := ShaderMaterial.new()
				m.shader = PANEL_TINT_SHADER
				m.set_shader_parameter("tint", CURRENT_TINT)
				b.material = m   ## значок (Icon) — своим материалом, не перекрашивается
	toggle.pressed.connect(_on_toggle)
	_refresh_locks()
	_apply(expanded, false)
	refresh_badges()
	if StoryState_ != null and StoryState_.has_signal("changed"):
		StoryState_.changed.connect(refresh_badges)
		StoryState_.changed.connect(_refresh_locks)

func _exit_tree() -> void:
	if StoryState_ != null and StoryState_.has_signal("changed") and StoryState_.changed.is_connected(refresh_badges):
		StoryState_.changed.disconnect(refresh_badges)
	if StoryState_ != null and StoryState_.has_signal("changed") and StoryState_.changed.is_connected(_refresh_locks):
		StoryState_.changed.disconnect(_refresh_locks)

## Котла нет — кнопка «Алхимия» потускневшая и не нажимается.
func _refresh_locks() -> void:
	var alch := button("AlchemyButton")
	if alch == null:
		return
	var ok := AlchemyDB.has_cauldron()
	alch.disabled = not ok
	var tint := Color.WHITE if ok else Color(0.45, 0.42, 0.48, 0.85)
	alch.set_meta("rest_tint", tint)   ## подсветка (ButtonGlow) не «отбеливает» потускневшую кнопку
	alch.self_modulate = tint
	var icon := alch.get_node_or_null("Icon") as CanvasItem
	if icon != null:
		icon.modulate = tint   ## значок тускнеет вместе с подложкой
	alch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ok else Control.CURSOR_ARROW

func button(btn_name: String) -> TextureButton:
	return get_node_or_null(btn_name) as TextureButton

func _is_current(method: String) -> bool:
	var cur := get_tree().current_scene if is_inside_tree() else null
	return cur != null and cur.scene_file_path == _scene_path(method)

func _open_scale(b: TextureButton) -> Vector2:
	return Vector2.ONE * (CURRENT_SCALE if b == _current else 1.0)

func _go(method: String) -> void:
	var cur := get_tree().current_scene
	var path := cur.scene_file_path if cur != null else ""
	if SceneRouter_ == null or path == _scene_path(method):
		return   ## уже здесь — никуда не идём
	if method == "go_to_shop" and DayCycle.shop_closed_say():
		return   ## ночью лавка закрыта
	SceneRouter_.call(method)

static func _scene_path(method: String) -> String:
	match method:
		"go_to_shop": return SceneRouter.SHOP_SCENE
		"go_to_farm": return SceneRouter.FARM
		"go_to_alchemy": return SceneRouter.ALCHEMY
		"go_to_hub": return SceneRouter.HUB
	return ""

func _on_toggle() -> void:
	expanded = not expanded
	_apply(expanded, true)

func _apply(open: bool, animated: bool) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var home := toggle.position
	if not animated:
		for b in _buttons:
			b.position = _open_pos[b] if open else home
			b.modulate.a = 1.0 if open else 0.0
			b.scale = _open_scale(b) if open else Vector2(0.4, 0.4)
			b.visible = open
		toggle.rotation = PI * 0.5 if open else 0.0
		refresh_badges()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(toggle, "rotation", PI * 0.5 if open else 0.0, SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Ближняя к «…» кнопка выезжает первой (и прячется последней).
	var order := _buttons.duplicate()
	order.sort_custom(func(a: TextureButton, b: TextureButton) -> bool:
		return (_open_pos[a] as Vector2).distance_to(home) < (_open_pos[b] as Vector2).distance_to(home))
	if not open:
		order.reverse()
	var i := 0
	for b: TextureButton in order:
		var delay := STAGGER * i
		i += 1
		if open:
			b.visible = true
			_tween.tween_property(b, "position", _open_pos[b], SLIDE_TIME).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tween.tween_property(b, "modulate:a", 1.0, SLIDE_TIME * 0.7).set_delay(delay)
			_tween.tween_property(b, "scale", _open_scale(b), SLIDE_TIME).set_delay(delay)
		else:
			_tween.tween_property(b, "position", home, SLIDE_TIME * 0.8).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_tween.tween_property(b, "modulate:a", 0.0, SLIDE_TIME * 0.8).set_delay(delay)
			_tween.tween_property(b, "scale", Vector2(0.4, 0.4), SLIDE_TIME * 0.8).set_delay(delay)
	_tween.chain().tween_callback(func() -> void:
		for b in _buttons:
			b.visible = open
		refresh_badges())
	refresh_badges()

## «!» на лавке (Рикка: квест, цветок). Меню свёрнуто — «!» на «…».
func refresh_badges() -> void:
	if not is_inside_tree():
		return
	var shop_news := StoryDialogueDB_ != null and (StoryDialogueDB_.npc_has_news("rikka") \
		or StoryDialogueDB_.npc_has_news(RikkaFlower.NPC_ID))
	NotifyBadge.attach(button("ShopButton"), shop_news)
	NotifyBadge.attach(toggle, shop_news and not expanded)
