@tool
extends Control
## Bottom panel widget showing MCP connection status, client count, and last request info.

var _indicator: ColorRect
var _label: Label
var _client_count: int = 0
var _last_method: String = ""
var _last_time: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(0, 30)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)

	# Connection indicator dot
	_indicator = ColorRect.new()
	_indicator.custom_minimum_size = Vector2(12, 12)
	_indicator.color = Color(0.8, 0.2, 0.2)  # Red — no clients
	hbox.add_child(_indicator)

	# Status label
	_label = Label.new()
	_label.text = "MCP: No clients connected"
	hbox.add_child(_label)

	# Center vertically
	hbox.anchors_preset = Control.PRESET_CENTER_LEFT
	hbox.offset_left = 8.0


func on_client_connected() -> void:
	_client_count += 1
	_update_display()


func on_client_disconnected() -> void:
	_client_count = max(0, _client_count - 1)
	_update_display()


func on_request_handled(method: String) -> void:
	_last_method = method
	_last_time = Time.get_time_string_from_system()
	_update_display()


func _update_display() -> void:
	if _client_count > 0:
		_indicator.color = Color(0.2, 0.8, 0.3)  # Green — connected
		var status := "MCP: %d client%s" % [_client_count, "s" if _client_count > 1 else ""]
		if not _last_method.is_empty():
			status += "  |  Last: %s @ %s" % [_last_method, _last_time]
		_label.text = status
	else:
		_indicator.color = Color(0.8, 0.2, 0.2)  # Red — disconnected
		_label.text = "MCP: No clients connected"
