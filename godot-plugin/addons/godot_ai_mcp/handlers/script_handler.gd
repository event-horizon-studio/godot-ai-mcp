@tool
extends RefCounted
## Handles GDScript execution, script creation, and script reading.


func execute_gdscript(params: Dictionary) -> Variant:
	var code: String = params.get("code", "")
	if code.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: code"}}

	# Wrap user code in a runnable @tool class
	# The code can access EditorInterface, ClassDB, Engine, etc.
	var wrapped_code := """@tool
extends RefCounted

func _run() -> Variant:
%s
""" % _indent_code(code)

	var script := GDScript.new()
	script.source_code = wrapped_code

	var reload_err := script.reload()
	if reload_err != OK:
		return {
			"error": {
				"code": int(reload_err),
				"message": "GDScript compilation error (code %d). Check your syntax." % reload_err,
			}
		}

	var instance = script.new()
	if not instance:
		return {"error": {"code": -1, "message": "Failed to instantiate script"}}

	var result = instance._run()

	return {
		"success": true,
		"result": _safe_stringify(result),
	}


func create_script(params: Dictionary) -> Variant:
	var script_path: String = params.get("script_path", "")
	var content: String = params.get("content", "")
	var attach_to: String = params.get("attach_to", "")

	if script_path.is_empty() or content.is_empty():
		return {"error": {"code": -1, "message": "Missing required params: script_path, content"}}

	# Ensure the path starts with res://
	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	# Ensure it ends with .gd
	if not script_path.ends_with(".gd"):
		script_path += ".gd"

	# Create parent directories if needed
	var dir_path := script_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)

	# Write the file
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if not file:
		var err := FileAccess.get_open_error()
		return {"error": {"code": int(err), "message": "Failed to open file for writing: " + script_path}}

	file.store_string(content)
	file.close()

	# Trigger filesystem rescan so the editor picks up the new file
	EditorInterface.get_resource_filesystem().scan()

	var result := {
		"success": true,
		"script_path": script_path,
	}

	# Optionally attach the script to a node
	if not attach_to.is_empty():
		var attach_result := _attach_script_to_node(script_path, attach_to)
		result.merge(attach_result)

	return result


func read_script(params: Dictionary) -> Variant:
	var script_path: String = params.get("script_path", "")
	if script_path.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: script_path"}}

	if not script_path.begins_with("res://"):
		script_path = "res://" + script_path

	if not FileAccess.file_exists(script_path):
		return {"error": {"code": -1, "message": "Script not found: " + script_path}}

	var file := FileAccess.open(script_path, FileAccess.READ)
	if not file:
		return {"error": {"code": -1, "message": "Failed to open script: " + script_path}}

	var content := file.get_as_text()
	file.close()

	return {
		"script_path": script_path,
		"content": content,
		"line_count": content.get_slice_count("\n"),
	}


# ── Private helpers ──────────────────────────────────────────────────────────

func _indent_code(code: String) -> String:
	## Indents each line of the code by one tab (for wrapping inside a function body).
	var lines := code.split("\n")
	var indented := PackedStringArray()
	for line in lines:
		indented.append("\t" + line)
	return "\n".join(indented)


func _safe_stringify(value: Variant) -> Variant:
	## Converts the result to something JSON-safe.
	if value == null:
		return null
	elif value is bool or value is int or value is float or value is String:
		return value
	elif value is Array or value is Dictionary:
		# JSON.stringify handles these natively
		return value
	else:
		return str(value)


func _attach_script_to_node(script_path: String, node_path: String) -> Dictionary:
	## Attaches a script to a node by path, with undo/redo support.
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return {"attach_error": "No active scene"}

	var node: Node = null
	if node_path == "." or node_path == scene_root.name:
		node = scene_root
	elif scene_root.has_node(node_path):
		node = scene_root.get_node(node_path)

	if not node:
		return {"attach_error": "Node not found: " + node_path}

	var script := ResourceLoader.load(script_path) as Script
	if not script:
		return {"attach_error": "Failed to load script: " + script_path}

	var undo_redo := EditorInterface.get_editor_undo_redo()
	var old_script = node.get_script()

	undo_redo.create_action("MCP: Attach script to " + node.name)
	undo_redo.add_do_property(node, "script", script)
	undo_redo.add_undo_property(node, "script", old_script)
	undo_redo.commit_action()

	return {"attached_to": node_path}
