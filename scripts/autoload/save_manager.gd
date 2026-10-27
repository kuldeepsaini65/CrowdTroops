extends Node
## Persists progress to user://save.json (CLAUDE.md §3.6).
## Writes are atomic: the JSON goes to a temp file which is then renamed over
## the real save, so a crash mid-write never leaves a corrupt save.

const SAVE_PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"
const SAVE_VERSION := 1

const UPGRADE_FIRE_RATE := "fire_rate"
const UPGRADE_CHAMPION := "champion"
const UPGRADE_WALL := "wall"

var level: int = 1
var coins: int = 0
var upgrades: Dictionary = {
	UPGRADE_FIRE_RATE: 0,
	UPGRADE_CHAMPION: 0,
	UPGRADE_WALL: 0,
}
var settings: Dictionary = {
	"sound": true,
	"music": true,
	"vibration": true,
}


func _ready() -> void:
	load_game()


func get_upgrade(key: String) -> int:
	return int(upgrades.get(key, 0))


func add_coins(amount: int) -> void:
	coins = maxi(0, coins + amount)
	GameEvents.coins_changed.emit(coins)


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is unreadable, starting fresh.")
		return
	var data: Dictionary = parsed
	level = maxi(1, int(data.get("level", 1)))
	coins = maxi(0, int(data.get("coins", 0)))
	var saved_upgrades: Variant = data.get("upgrades", {})
	if saved_upgrades is Dictionary:
		for key: String in upgrades.keys():
			upgrades[key] = clampi(int(saved_upgrades.get(key, 0)), 0, Tuning.MAX_UPGRADE_LEVEL)
	var saved_settings: Variant = data.get("settings", {})
	if saved_settings is Dictionary:
		for key: String in settings.keys():
			settings[key] = bool(saved_settings.get(key, settings[key]))


func save_game() -> bool:
	var data := {
		"version": SAVE_VERSION,
		"level": level,
		"coins": coins,
		"upgrades": upgrades,
		"settings": settings,
	}
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write temp save (%s)." % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		push_error("SaveManager: cannot open user:// directory.")
		return false
	var err := dir.rename(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveManager: rename failed (%s)." % error_string(err))
		return false
	return true


func reset_progress() -> void:
	level = 1
	coins = 0
	for key: String in upgrades.keys():
		upgrades[key] = 0
	save_game()
