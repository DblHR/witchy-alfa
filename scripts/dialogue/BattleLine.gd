extends Resource
class_name BattleLine

@export var line_id: String = ""
@export var speaker_id: String = ""
@export_enum("battle_start", "ability_cast", "basic_attack", "kill_enemy", "ally_low_hp", "victory", "between_rooms") var trigger: String = "battle_start"
@export_enum("battle", "joke", "taunt", "reaction", "support", "warning") var line_type: String = "battle"
@export_multiline var text: String = ""

@export_range(0.0, 1.0, 0.01) var chance: float = 0.35
@export var enabled: bool = true
@export var once_per_battle: bool = false
@export_range(0.0, 30.0, 0.1) var cooldown_sec: float = 0.0

@export var response_group: String = ""
@export var target_speaker_id: String = ""
@export var required_tags: Array[String] = []
@export var forbidden_tags: Array[String] = []
