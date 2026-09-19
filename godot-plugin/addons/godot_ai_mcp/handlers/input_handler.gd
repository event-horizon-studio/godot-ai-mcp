@tool
extends RefCounted
## Handles InputMap and ProjectSettings configuration.


func get_input_actions(_params: Dictionary) -> Variant:
	var actions: Array[Dictionary] = []
	
	# Load actions directly from ProjectSettings to see configured defaults
	var property_list := ProjectSettings.get_property_list()
	for prop in property_list:
		var prop_name: String = prop.name
		if prop_name.begins_with("input/"):
			var action_name := prop_name.substr(6)
			var action_data: Dictionary = ProjectSettings.get_setting(prop_name, {})
			var events_summary: Array[String] = []
			
			var events: Array = action_data.get("events", [])
			for ev in events:
				if ev is InputEventKey:
					events_summary.append("Key: " + OS.get_keycode_string(ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode))
				elif ev is InputEventMouseButton:
					events_summary.append("Mouse Button: %d" % ev.button_index)
				elif ev is InputEventJoypadButton:
					events_summary.append("Joypad Button: %d" % ev.button_index)
				elif ev is InputEvent:
					events_summary.append(ev.as_text())
					
			actions.append({
				"action": action_name,
				"deadzone": action_data.get("deadzone", 0.5),
				"events": events_summary
			})
			
	return {"actions": actions}


func add_input_action(params: Dictionary) -> Variant:
	var action_name: String = params.get("action", "")
	var deadzone: float = params.get("deadzone", 0.5)
	var keys: Array = params.get("keys", [])  # e.g. ["W", "Up", "Space"]
	var mouse_buttons: Array = params.get("mouse_buttons", []) # e.g. [1] (Left Click)

	if action_name.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: action"}}

	var setting_key := "input/" + action_name
	var events: Array = []

	# Build key events
	for k in keys:
		var key_str := str(k).strip_edges().to_upper()
		var keycode := OS.find_keycode_from_string(key_str)
		if keycode != KEY_NONE:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			events.append(event)
		else:
			push_warning("[Godot AI MCP] Unknown key string: " + key_str)

	# Build mouse button events
	for mb in mouse_buttons:
		var event := InputEventMouseButton.new()
		event.button_index = int(mb)
		events.append(event)

	var action_dict := {
		"deadzone": deadzone,
		"events": events
	}

	ProjectSettings.set_setting(setting_key, action_dict)
	var err := ProjectSettings.save()
	if err != OK:
		return {"error": {"code": int(err), "message": "Failed to save ProjectSettings: %d" % err}}

	return {
		"success": true,
		"action": action_name,
		"events_count": events.size()
	}


func set_project_setting(params: Dictionary) -> Variant:
	var setting: String = params.get("setting", "")
	var value = params.get("value")

	if setting.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: setting"}}

	ProjectSettings.set_setting(setting, value)
	var err := ProjectSettings.save()
	if err != OK:
		return {"error": {"code": int(err), "message": "Failed to save ProjectSettings: %d" % err}}

	return {
		"success": true,
		"setting": setting,
		"value": value
	}
