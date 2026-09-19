@tool
extends Node
## TCP server that accepts connections from the godot-ai-mcp TypeScript process.
## Routes incoming JSON requests to the appropriate handler and returns JSON responses.

signal client_connected()
signal client_disconnected()
signal request_handled(method: String)

const PORT := 6505
const BIND_HOST := "127.0.0.1"
const MAX_REQUEST_SIZE := 1_048_576  # 1 MB safety limit

var _server := TCPServer.new()
var _clients: Array[StreamPeerTCP] = []
var _client_buffers: Dictionary = {}  # StreamPeerTCP -> String (partial message buffer)

# Handlers — lazy-loaded on first request
var _editor_handler: RefCounted = null
var _scene_handler: RefCounted = null
var _script_handler: RefCounted = null
var _viewport_handler: RefCounted = null
var _reflection_handler: RefCounted = null
var _input_handler: RefCounted = null
var _resource_handler: RefCounted = null


func _ready() -> void:
	var err := _server.listen(PORT, BIND_HOST)
	if err != OK:
		push_error("[Godot AI MCP] Failed to listen on %s:%d — error %d. Is another instance running?" % [BIND_HOST, PORT, err])
		return
	_init_handlers()


func _init_handlers() -> void:
	_editor_handler = preload("res://addons/godot_ai_mcp/handlers/editor_handler.gd").new()
	_scene_handler = preload("res://addons/godot_ai_mcp/handlers/scene_handler.gd").new()
	_script_handler = preload("res://addons/godot_ai_mcp/handlers/script_handler.gd").new()
	_viewport_handler = preload("res://addons/godot_ai_mcp/handlers/viewport_handler.gd").new()
	_reflection_handler = preload("res://addons/godot_ai_mcp/handlers/reflection_handler.gd").new()
	_input_handler = preload("res://addons/godot_ai_mcp/handlers/input_handler.gd").new()
	_resource_handler = preload("res://addons/godot_ai_mcp/handlers/resource_handler.gd").new()



func _process(_delta: float) -> void:
	if not _server.is_listening():
		return

	# Accept new connections
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if peer:
			_clients.append(peer)
			_client_buffers[peer] = ""
			client_connected.emit()
			print("[Godot AI MCP] Client connected (%d active)" % _clients.size())

	# Process all connected clients
	var i := _clients.size() - 1
	while i >= 0:
		var peer := _clients[i]
		peer.poll()

		var status := peer.get_status()
		if status != StreamPeerTCP.STATUS_CONNECTED:
			_remove_client(i)
			i -= 1
			continue

		# Read available data
		var available := peer.get_available_bytes()
		if available > 0:
			var data := peer.get_data(available)
			if data[0] == OK:  # data is [error_code, PackedByteArray]
				var raw_bytes: PackedByteArray = data[1]
				var text: String = raw_bytes.get_string_from_utf8()
				_client_buffers[peer] += text
				_process_buffer(peer)

		i -= 1


func _process_buffer(peer: StreamPeerTCP) -> void:
	## Extracts complete JSON lines from the buffer and processes them.
	var buffer: String = _client_buffers[peer]

	while true:
		var newline_pos := buffer.find("\n")
		if newline_pos == -1:
			# No complete message yet — check safety limit
			if buffer.length() > MAX_REQUEST_SIZE:
				push_warning("[Godot AI MCP] Buffer exceeded max size, clearing")
				buffer = ""
			break

		var line := buffer.substr(0, newline_pos).strip_edges()
		buffer = buffer.substr(newline_pos + 1)

		if line.is_empty():
			continue

		var response := _handle_request(line)
		if not response.is_empty():
			var response_bytes := (response + "\n").to_utf8_buffer()
			peer.put_data(response_bytes)

	_client_buffers[peer] = buffer


func _handle_request(json_line: String) -> String:
	## Parses a JSON request, dispatches to the correct handler, returns JSON response.
	var json := JSON.new()
	var parse_err := json.parse(json_line)
	if parse_err != OK:
		return JSON.stringify({
			"id": null,
			"error": {"code": -32700, "message": "Parse error: " + json.get_error_message()}
		})

	var request: Dictionary = json.data
	var req_id = request.get("id", null)
	var method: String = request.get("method", "")
	var params: Dictionary = request.get("params", {})

	if method.is_empty():
		return JSON.stringify({
			"id": req_id,
			"error": {"code": -32600, "message": "Missing 'method' field"}
		})

	var result = _dispatch(method, params)

	request_handled.emit(method)

	if result is Dictionary and result.has("error"):
		return JSON.stringify({"id": req_id, "error": result["error"]})
	else:
		return JSON.stringify({"id": req_id, "result": result})


func _dispatch(method: String, params: Dictionary) -> Variant:
	## Routes a method call to the correct handler.
	match method:
		# Editor tools
		"get_editor_status":
			return _editor_handler.get_editor_status(params)
		"open_scene":
			return _editor_handler.open_scene(params)
		"save_scene":
			return _editor_handler.save_scene(params)
		"run_project":
			return _editor_handler.run_project(params)
		"stop_project":
			return _editor_handler.stop_project(params)
		"get_editor_logs":
			return _editor_handler.get_editor_logs(params)

		# Scene tools
		"get_scene_tree":
			return _scene_handler.get_scene_tree(params)
		"get_node_info":
			return _scene_handler.get_node_info(params)
		"create_node":
			return _scene_handler.create_node(params)
		"modify_node_property":
			return _scene_handler.modify_node_property(params)
		"delete_node":
			return _scene_handler.delete_node(params)
		"reparent_node":
			return _scene_handler.reparent_node(params)
		"connect_signal":
			return _scene_handler.connect_signal(params)
		"get_node_connections":
			return _scene_handler.get_node_connections(params)
		"create_primitive_mesh":
			return _scene_handler.create_primitive_mesh(params)
		"create_collision_shape":
			return _scene_handler.create_collision_shape(params)

		# Script tools
		"execute_gdscript":
			return _script_handler.execute_gdscript(params)
		"create_script":
			return _script_handler.create_script(params)
		"read_script":
			return _script_handler.read_script(params)

		# Input & Project Settings tools
		"get_input_actions":
			return _input_handler.get_input_actions(params)
		"add_input_action":
			return _input_handler.add_input_action(params)
		"set_project_setting":
			return _input_handler.set_project_setting(params)

		# Resource tools
		"create_material":
			return _resource_handler.create_material(params)

		# Viewport tools
		"get_viewport_screenshot":
			return _viewport_handler.get_viewport_screenshot(params)

		# Reflection tools
		"api_lookup":
			return _reflection_handler.api_lookup(params)
		"list_project_files":
			return _reflection_handler.list_project_files(params)

		_:
			return {"error": {"code": -32601, "message": "Unknown method: " + method}}


func _remove_client(index: int) -> void:
	var peer := _clients[index]
	_client_buffers.erase(peer)
	peer.disconnect_from_host()
	_clients.remove_at(index)
	client_disconnected.emit()
	print("[Godot AI MCP] Client disconnected (%d active)" % _clients.size())


func shutdown() -> void:
	## Cleanly shuts down the server and all connections.
	for peer in _clients:
		peer.disconnect_from_host()
	_clients.clear()
	_client_buffers.clear()

	if _server.is_listening():
		_server.stop()

	print("[Godot AI MCP] Server stopped.")


func get_client_count() -> int:
	return _clients.size()
