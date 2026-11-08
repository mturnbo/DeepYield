class_name Balance
extends RefCounted

const DEFAULT_PATH := "res://game/data/balance.json"


static func load_default() -> Dictionary:
	var text := FileAccess.get_file_as_string(DEFAULT_PATH)
	return JSON.parse_string(text)
