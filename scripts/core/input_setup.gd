class_name InputSetup
extends RefCounted
## Registers the desktop/test input actions in code (CLAUDE.md §3.2), so
## project.godot does not need hand-serialized InputEvent objects.


static func ensure_actions() -> void:
	_add_keys(&"move_left", [KEY_A, KEY_LEFT])
	_add_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_add_keys(&"fire", [KEY_SPACE])
	_add_keys(&"pause", [KEY_P, KEY_ESCAPE, KEY_BACK])


static func _add_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key as Key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
