extends RefCounted
class_name RoomParams

enum RoomType { BATTLE, BOSS, EVENT }
enum EventType { NONE, SHOP, NURSE, CHEST, STATUE, QUEST }
enum StatueVariant { NONE, WHITE, BLACK }

var index: int
var room_type: int = RoomType.BATTLE
var enemy_count: int = 1
var hp_bonus: int = 0
var damage_bonus: int = 0
var strong_chance: float = 0.0
var is_boss: bool = false
var boss_id: String = ""
var event_type: int = EventType.NONE
var statue_variant: int = StatueVariant.NONE
var shop_item_ids: Array[String] = []
var shop_refreshed: bool = false
var used: bool = false
var quest_id: String = ""
var event_npc_id: String = ""

func _init(
		_index: int = 0,
		_enemy_count: int = 1,
		_hp_bonus: int = 0,
		_strong_chance: float = 0.0,
		_room_type: int = RoomType.BATTLE,
		_event_type: int = EventType.NONE,
		_boss_id: String = ""
	) -> void:
	index = _index
	room_type = _room_type
	event_type = _event_type
	enemy_count = _enemy_count
	hp_bonus = _hp_bonus
	strong_chance = _strong_chance
	is_boss = (room_type == RoomType.BOSS)
	boss_id = _boss_id if is_boss else ""
