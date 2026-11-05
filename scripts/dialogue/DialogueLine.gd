extends Resource
class_name DialogueLine

@export var speaker_name: String = ""
@export_multiline var text: String = ""
@export var left_portrait: Texture2D
@export var center_portrait: Texture2D
@export var right_portrait: Texture2D
@export_enum("none", "left", "center", "right") var active_slot: String = "none"
