class_name HeartText
extends RefCounted
## «♥» в текстах доверия -> картинка сердечка (assets/ui/buttons/love/heartSymbol.png).
## В строках (interactions / gifts / тосты) остаётся «♥» — картинку подставляет показ:
##   button(b, text) — кнопка: текст без «♥», сердечко — иконкой справа;
##   rich(text, size) — надпись (RichTextLabel), «♥» заменено картинкой нужного размера.

const ICON := "res://assets/ui/buttons/love/heartSymbol.png"
const MARK := "♥"

static func icon() -> Texture2D:
	return load(ICON) as Texture2D if ResourceLoader.exists(ICON) else null

static func has_heart(text: String) -> bool:
	return text.contains(MARK)

## Текст без «♥» (и без пробела перед ним).
static func strip(text: String) -> String:
	return text.replace(" " + MARK, "").replace(MARK, "").strip_edges(false, true)

## Кнопка: есть «♥» — сердечко иконкой у правого края (размер — icon_px).
static func button(b: Button, text: String, icon_px: int = 34) -> void:
	if not has_heart(text) or icon() == null:
		b.text = text
		return
	b.text = strip(text)
	b.icon = icon()
	b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.expand_icon = false
	b.add_theme_constant_override("icon_max_width", icon_px)

## Надпись с картинкой сердечка вместо «♥» (bbcode). Цвета/обводку задаёт вызывающий.
static func rich(text: String, font_size: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.scroll_active = false
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("normal_font_size", font_size)
	var px := int(font_size * 0.95)
	var img := "[img=%dx%d]%s[/img]" % [px, px, ICON] if ResourceLoader.exists(ICON) else MARK
	l.text = text.replace(MARK, img)
	return l
