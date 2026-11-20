extends Node2D
class_name RikkaTour
## Экскурсия Рикки при первом заходе в лавку (после VN rikka_first_visit).
## Реплики — data/dialogues/npc/rikka.json → диалог "rikka_tour": у каждой реплики "anim" — какую
## анимацию этой сцены играть. Анимации — в AnimationPlayer этой сцены (RikkaTour.tscn), их можно
## править в редакторе: Body — Рикка (точка Body — у её ног, вокруг неё качается и падает),
## Body/Sprite:texture — какой спрайт, Hand — рука FE5 снизу, BubbleAt — где низ пузыря с репликой.
## Дорожка вызовов (method):
##   highlight([2, 5]) — подсветить ячейки лавки (0..5: верхний ряд слева направо, потом нижний);
##   show_line()       — показать пузырь с репликой (если в анимации нет — после её конца).
## Пока идёт экскурсия, лавка закрыта (Shop.gd): ни купить, ни уйти.

signal highlight_requested(slots: Array)
signal line_requested(text: String, at: Vector2)
signal finished

## Сколько пузырь висит после появления: 1 сек + на каждую букву, но в пределах.
const READ_BASE := 1.0
const READ_PER_CHAR := 0.05
const READ_MIN := 1.8
const READ_MAX := 3.2

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var bubble_at: Marker2D = $BubbleAt

var _text := ""
var _line_shown := false
var _skip := false

func _ready() -> void:
	if anim.has_animation("RESET"):
		anim.play("RESET")
		anim.advance(0.0)

## Проиграть экскурсию по репликам [{text, anim}].
func play(lines: Array) -> void:
	for l in lines:
		if not (l is Dictionary) or not is_inside_tree():
			continue
		_text = String(l.get("text", "")).strip_edges()
		_line_shown = false
		line_requested.emit("", bubble_at.global_position)   ## убрать прошлый пузырь
		var a := String(l.get("anim", ""))
		if a != "" and anim.has_animation(a):
			anim.play(a)
			await anim.animation_finished
		show_line()
		await _wait_reading()
	line_requested.emit("", bubble_at.global_position)
	finished.emit()

## Вызывается из анимации: показать пузырь с текущей репликой.
func show_line() -> void:
	if _line_shown:
		return
	_line_shown = true
	if _text != "":
		line_requested.emit(_text, bubble_at.global_position)

## Вызывается из анимации: какие ячейки лавки подсветить ([] — никакие).
func highlight(slots: Array) -> void:
	highlight_requested.emit(slots)

## Клик игрока: дочитал — дальше (анимацию не перебивает).
func skip_reading() -> void:
	_skip = true

func _wait_reading() -> void:
	_skip = false
	var left := clampf(READ_BASE + READ_PER_CHAR * _text.length(), READ_MIN, READ_MAX)
	while left > 0.0 and not _skip and is_inside_tree():
		await get_tree().process_frame
		left -= get_process_delta_time()
