extends RefCounted
class_name NameRules
## Особые имена (data/names/name_rules.json): если персонажу / питомцу дали такое имя —
## другая картинка, диалог сразу после имени, другое имя в меню, доступ к админ-панелям.

const FILE := "res://data/names/name_rules.json"

static var _rules: Array = []
static var _loaded := false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(FILE):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if parsed is Dictionary and parsed.get("rules") is Array:
		_rules = parsed["rules"]
	else:
		push_warning("NameRules: не получилось прочитать %s" % FILE)

static func _norm(s: String) -> String:
	return s.strip_edges().to_lower()

## Правило для имени name у key ({} — обычное имя).
static func rule_for(key: String, name: String) -> Dictionary:
	_ensure()
	var n := _norm(name)
	if n == "":
		return {}
	for r in _rules:
		if not (r is Dictionary) or String(r.get("key", "")) != key:
			continue
		for v in r.get("names", []):
			if _norm(String(v)) == n:
				return r
	return {}

## Правило для текущего имени key.
static func current_rule(key: String) -> Dictionary:
	if StoryState_ == null:
		return {}
	return rule_for(key, StoryState_.get_custom_name(key, ""))

## Картинка для имени (или "" — обычная).
static func texture_for(key: String) -> String:
	var p := String(current_rule(key).get("texture", ""))
	return p if p != "" and (ResourceLoader.exists(p) or FileAccess.file_exists(p)) else ""

## Диалог, который играет сразу после того, как дали имя ("" — нет).
static func dialogue_for(key: String, name: String) -> String:
	return String(rule_for(key, name).get("dialogue", ""))

## Как показывать имя в меню (по таблице display; иначе как ввели).
static func display_name(key: String, name: String) -> String:
	var disp = rule_for(key, name).get("display", {})
	if disp is Dictionary:
		var n := _norm(name)
		for k in disp:
			if _norm(String(k)) == n:
				return String(disp[k])
	return name

## Открывает ли чьё-то нынешнее имя админ-панели.
static func grants_admin() -> bool:
	_ensure()
	if StoryState_ == null:
		return false
	for r in _rules:
		if r is Dictionary and bool(r.get("admin", false)):
			var key := String(r.get("key", ""))
			if not rule_for(key, StoryState_.get_custom_name(key, "")).is_empty():
				return true
	return false
