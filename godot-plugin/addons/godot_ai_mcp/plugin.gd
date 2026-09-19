@tool
extends EditorPlugin
## Main entry point for the Godot AI MCP editor plugin.
## Manages the TCP server lifecycle and bottom-panel status UI.

const StatusPanel := preload("res://addons/godot_ai_mcp/ui/status_panel.gd")

var _mcp_server: Node = null
var _status_panel: Control = null


func _enter_tree() -> void:
	# Create and start the TCP server
	_mcp_server = preload("res://addons/godot_ai_mcp/mcp_server.gd").new()
	_mcp_server.name = "GodotAIMCPServer"
	add_child(_mcp_server)

	# Create bottom panel status indicator
	_status_panel = StatusPanel.new()
	_status_panel.name = "GodotAIMCPStatus"
	add_control_to_bottom_panel(_status_panel, "MCP")

	# Wire server connection events to the status panel
	_mcp_server.client_connected.connect(_status_panel.on_client_connected)
	_mcp_server.client_disconnected.connect(_status_panel.on_client_disconnected)
	_mcp_server.request_handled.connect(_status_panel.on_request_handled)

	print("[Godot AI MCP] Plugin enabled — listening on port %d" % _mcp_server.PORT)


func _exit_tree() -> void:
	if _status_panel:
		remove_control_from_bottom_panel(_status_panel)
		_status_panel.queue_free()
		_status_panel = null

	if _mcp_server:
		_mcp_server.shutdown()
		_mcp_server.queue_free()
		_mcp_server = null

	print("[Godot AI MCP] Plugin disabled.")
