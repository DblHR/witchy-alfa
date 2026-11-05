extends Node
class_name EventPresentationDB

# Старые ивент-реплики вынесены в res://data/dialogues/.
# Этот autoload оставлен как совместимый fallback для старого кода.

func get_intro_lines(_room: RoomParams) -> Array[String]:
	return []
