@tool
extends RefCounted
## Handles scene tree inspection and node manipulation with undo/redo support.

const MAX_TREE_DEPTH := 50  # Safety limit for recursive traversal


func get_scene_tree(params: Dictionary) -> Variant:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return {"error": {"code": -1, "message": "No active scene open in the editor"}}

	var max_depth: int = params.get("max_depth", -1)
	if max_depth < 0:
		max_depth = MAX_TREE_DEPTH

	return {"tree": _serialize_node_tree(scene_root, 0, max_depth)}


func get_node_info(params: Dictionary) -> Variant:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: node_path"}}

	var node := _get_node_by_path(node_path)
	if not node:
		return {"error": {"code": -1, "message": "Node not found: " + node_path}}

	return _serialize_node_detail(node)


func create_node(params: Dictionary) -> Variant:
	var parent_path: String = params.get("parent_path", "")
	var node_type: String = params.get("node_type", "")
	var node_name: String = params.get("node_name", "")

	if node_type.is_empty() or node_name.is_empty():
		return {"error": {"code": -1, "message": "Missing required params: node_type, node_name"}}

	# Validate the class exists and is a Node subclass
	if not ClassDB.class_exists(node_type):
		return {"error": {"code": -1, "message": "Unknown class: " + node_type}}
	if not ClassDB.is_parent_class(node_type, "Node"):
		return {"error": {"code": -1, "message": node_type + " is not a Node subclass"}}

	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return {"error": {"code": -1, "message": "No active scene open"}}

	# Resolve parent
	var parent: Node = scene_root
	if not parent_path.is_empty() and parent_path != ".":
		parent = _get_node_by_path(parent_path)
		if not parent:
			return {"error": {"code": -1, "message": "Parent node not found: " + parent_path}}

	# Create the node
	var new_node: Node = ClassDB.instantiate(node_type)
	new_node.name = node_name

	# Use undo/redo for reversible operations
	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Create " + node_name)
	undo_redo.add_do_method(parent, "add_child", new_node, true)
	undo_redo.add_do_method(new_node, "set_owner", scene_root)
	undo_redo.add_do_reference(new_node)
	undo_redo.add_undo_method(parent, "remove_child", new_node)
	undo_redo.commit_action()

	# Set initial properties if provided
	var properties: Dictionary = params.get("properties", {})
	for prop_name in properties:
		if new_node.has_method("set"):
			var value = _convert_value(properties[prop_name])
			new_node.set(prop_name, value)

	return {
		"success": true,
		"node_path": str(scene_root.get_path_to(new_node)),
		"node_type": node_type,
		"node_name": new_node.name,
	}


func modify_node_property(params: Dictionary) -> Variant:
	var node_path: String = params.get("node_path", "")
	var property: String = params.get("property", "")
	var value = params.get("value")

	if node_path.is_empty() or property.is_empty():
		return {"error": {"code": -1, "message": "Missing required params: node_path, property"}}

	var node := _get_node_by_path(node_path)
	if not node:
		return {"error": {"code": -1, "message": "Node not found: " + node_path}}

	# Get old value for undo
	var old_value = node.get(property)
	var new_value = _convert_value(value)

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Set %s.%s" % [node.name, property])
	undo_redo.add_do_property(node, property, new_value)
	undo_redo.add_undo_property(node, property, old_value)
	undo_redo.commit_action()

	return {
		"success": true,
		"node_path": node_path,
		"property": property,
		"old_value": _variant_to_json(old_value),
		"new_value": _variant_to_json(new_value),
	}


func delete_node(params: Dictionary) -> Variant:
	var node_path: String = params.get("node_path", "")
	if node_path.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: node_path"}}

	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return {"error": {"code": -1, "message": "No active scene"}}

	var node := _get_node_by_path(node_path)
	if not node:
		return {"error": {"code": -1, "message": "Node not found: " + node_path}}

	if node == scene_root:
		return {"error": {"code": -1, "message": "Cannot delete the scene root node"}}

	var parent := node.get_parent()
	var node_name := node.name

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Delete " + node_name)
	undo_redo.add_do_method(parent, "remove_child", node)
	undo_redo.add_undo_method(parent, "add_child", node, true)
	undo_redo.add_undo_method(node, "set_owner", scene_root)
	undo_redo.add_undo_reference(node)
	undo_redo.commit_action()

	return {"success": true, "deleted": node_name}


func reparent_node(params: Dictionary) -> Variant:
	var node_path: String = params.get("node_path", "")
	var new_parent_path: String = params.get("new_parent_path", "")

	if node_path.is_empty() or new_parent_path.is_empty():
		return {"error": {"code": -1, "message": "Missing required params: node_path, new_parent_path"}}

	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return {"error": {"code": -1, "message": "No active scene"}}

	var node := _get_node_by_path(node_path)
	if not node:
		return {"error": {"code": -1, "message": "Node not found: " + node_path}}

	var new_parent := _get_node_by_path(new_parent_path)
	if not new_parent:
		return {"error": {"code": -1, "message": "New parent not found: " + new_parent_path}}

	if node == scene_root:
		return {"error": {"code": -1, "message": "Cannot reparent the scene root"}}

	var old_parent := node.get_parent()
	var node_name := node.name

	var undo_redo := EditorInterface.get_editor_undo_redo()
	undo_redo.create_action("MCP: Reparent " + node_name)
	undo_redo.add_do_method(old_parent, "remove_child", node)
	undo_redo.add_do_method(new_parent, "add_child", node, true)
	undo_redo.add_do_method(node, "set_owner", scene_root)
	undo_redo.add_undo_method(new_parent, "remove_child", node)
	undo_redo.add_undo_method(old_parent, "add_child", node, true)
	undo_redo.add_undo_method(node, "set_owner", scene_root)
	undo_redo.commit_action()

	return {
		"success": true,
		"node": node_name,
		"old_parent": str(scene_root.get_path_to(old_parent)),
		"new_parent": new_parent_path,
	}


# ── Private helpers ──────────────────────────────────────────────────────────

func _get_node_by_path(path: String) -> Node:
	## Resolves a node path relative to the scene root.
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return null

	if path == "." or path == "" or path == scene_root.name:
		return scene_root

	# Try as-is first (relative to scene root)
	if scene_root.has_node(path):
		return scene_root.get_node(path)

	# Try without leading scene root name (e.g. "Main/Player" → "Player")
	if path.begins_with(scene_root.name + "/"):
		var relative := path.substr(scene_root.name.length() + 1)
		if scene_root.has_node(relative):
			return scene_root.get_node(relative)

	return null


func _serialize_node_tree(node: Node, depth: int, max_depth: int) -> Dictionary:
	var data := {
		"name": node.name,
		"type": node.get_class(),
	}

	# Include script info if attached
	var script := node.get_script() as Script
	if script:
		data["script"] = script.resource_path

	# Recurse into children
	if depth < max_depth:
		var children: Array[Dictionary] = []
		for child in node.get_children():
			# Skip internal editor nodes
			if child.is_class("EditorPlugin"):
				continue
			children.append(_serialize_node_tree(child, depth + 1, max_depth))
		if not children.is_empty():
			data["children"] = children

	return data


func _serialize_node_detail(node: Node) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	var data := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(scene_root.get_path_to(node)) if scene_root else str(node.name),
		"class_hierarchy": _get_class_hierarchy(node.get_class()),
	}

	# Transform info for spatial nodes
	if node is Node3D:
		var n3d := node as Node3D
		data["transform"] = {
			"position": _vec3_to_dict(n3d.position),
			"rotation_degrees": _vec3_to_dict(n3d.rotation_degrees),
			"scale": _vec3_to_dict(n3d.scale),
			"global_position": _vec3_to_dict(n3d.global_position),
		}
	elif node is Node2D:
		var n2d := node as Node2D
		data["transform"] = {
			"position": _vec2_to_dict(n2d.position),
			"rotation_degrees": n2d.rotation_degrees,
			"scale": _vec2_to_dict(n2d.scale),
			"global_position": _vec2_to_dict(n2d.global_position),
		}
	elif node is Control:
		var ctrl := node as Control
		data["rect"] = {
			"position": _vec2_to_dict(ctrl.position),
			"size": _vec2_to_dict(ctrl.size),
			"global_position": _vec2_to_dict(ctrl.global_position),
		}

	# Script info
	var script := node.get_script() as Script
	if script:
		data["script"] = script.resource_path

	# Key exported/user-facing properties
	var properties := []
	for prop in node.get_property_list():
		# Only include user-relevant properties (PROPERTY_USAGE_EDITOR)
		if prop.usage & PROPERTY_USAGE_EDITOR:
			var prop_name: String = prop.name
			# Skip internal/redundant props
			if prop_name.begins_with("_") or prop_name in ["script"]:
				continue
			properties.append({
				"name": prop_name,
				"type": type_string(prop.type),
				"value": _variant_to_json(node.get(prop_name)),
			})
	data["properties"] = properties

	# Children summary
	var children := []
	for child in node.get_children():
		children.append({"name": child.name, "type": child.get_class()})
	data["children"] = children

	# Signal list
	var signals := []
	for sig in node.get_signal_list():
		signals.append(sig.name)
	data["signals"] = signals

	# Groups
	data["groups"] = node.get_groups()

	return data


func _get_class_hierarchy(class_name: String) -> Array:
	var hierarchy := []
	var current := class_name
	while not current.is_empty():
		hierarchy.append(current)
		current = ClassDB.get_parent_class(current)
	return hierarchy


func _vec3_to_dict(v: Vector3) -> Dictionary:
	return {"x": snapped(v.x, 0.0001), "y": snapped(v.y, 0.0001), "z": snapped(v.z, 0.0001)}


func _vec2_to_dict(v: Vector2) -> Dictionary:
	return {"x": snapped(v.x, 0.0001), "y": snapped(v.y, 0.0001)}


func _variant_to_json(value: Variant) -> Variant:
	## Converts Godot Variants to JSON-safe types.
	if value == null:
		return null
	elif value is bool or value is int or value is float or value is String:
		return value
	elif value is Vector2:
		return _vec2_to_dict(value)
	elif value is Vector3:
		return _vec3_to_dict(value)
	elif value is Color:
		var c := value as Color
		return {"r": c.r, "g": c.g, "b": c.b, "a": c.a, "hex": c.to_html()}
	elif value is NodePath:
		return str(value)
	elif value is StringName:
		return str(value)
	elif value is Resource:
		var res := value as Resource
		return res.resource_path if not res.resource_path.is_empty() else str(res)
	elif value is Array:
		var arr := []
		for item in value:
			arr.append(_variant_to_json(item))
		return arr
	elif value is Dictionary:
		var dict := {}
		for key in value:
			dict[str(key)] = _variant_to_json(value[key])
		return dict
	else:
		return str(value)


func _convert_value(json_value: Variant) -> Variant:
	## Attempts to convert JSON values back to Godot types.
	## Handles common patterns: {"x":0,"y":0,"z":0} → Vector3, etc.
	if json_value is Dictionary:
		var d: Dictionary = json_value
		# Vector3 detection
		if d.has("x") and d.has("y") and d.has("z"):
			return Vector3(float(d.x), float(d.y), float(d.z))
		# Vector2 detection
		if d.has("x") and d.has("y") and not d.has("z"):
			return Vector2(float(d.x), float(d.y))
		# Color detection
		if d.has("r") and d.has("g") and d.has("b"):
			return Color(float(d.r), float(d.g), float(d.b), float(d.get("a", 1.0)))
		return d
	return json_value
