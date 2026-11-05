extends Node
class_name LoreDatabase

@export var entries: Array[LoreEntryData] = []

func get_entries() -> Array[LoreEntryData]:
	return entries
