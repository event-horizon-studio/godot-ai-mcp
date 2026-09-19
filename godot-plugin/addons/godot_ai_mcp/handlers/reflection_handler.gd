@tool
extends RefCounted
## Handles ClassDB reflection queries and project file listing.
## Enables AI agents to discover available classes, methods, properties, signals, and enums.


func api_lookup(params: Dictionary) -> Variant:
	var target_class: String = params.get("class_name", "")
	if target_class.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: class_name"}}

	if not ClassDB.class_exists(target_class):
		# Try fuzzy match — suggest similar class names
		var suggestions := _find_similar_classes(target_class)
		return {
			"error": {
				"code": -1,
				"message": "Class not found: " + target_class,
				"suggestions": suggestions,
			}
		}

	var include_inherited: bool = params.get("include_inherited", false)

	var result := {
		"class_name": target_class,
		"parent_class": ClassDB.get_parent_class(target_class),
		"is_instantiable": ClassDB.can_instantiate(target_class),
		"class_hierarchy": _get_hierarchy(target_class),
	}

	# Properties
	var properties := []
	var prop_list := ClassDB.class_get_property_list(target_class, !include_inherited)
	for prop in prop_list:
		if prop.usage & PROPERTY_USAGE_EDITOR:
			properties.append({
				"name": prop.name,
				"type": type_string(prop.type),
				"hint": prop.get("hint", 0),
				"hint_string": prop.get("hint_string", ""),
			})
	result["properties"] = properties

	# Methods
	var methods := []
	var method_list := ClassDB.class_get_method_list(target_class, !include_inherited)
	for method in method_list:
		var method_name: String = method.name
		# Skip internal/private methods
		if method_name.begins_with("_"):
			continue
		var args := []
		for arg in method.get("args", []):
			args.append({
				"name": arg.name,
				"type": type_string(arg.type),
			})
		methods.append({
			"name": method_name,
			"args": args,
			"return_type": type_string(method.get("return", {}).get("type", TYPE_NIL)),
		})
	result["methods"] = methods

	# Signals
	var signals := []
	var signal_list := ClassDB.class_get_signal_list(target_class, !include_inherited)
	for sig in signal_list:
		var sig_args := []
		for arg in sig.get("args", []):
			sig_args.append({
				"name": arg.name,
				"type": type_string(arg.type),
			})
		signals.append({
			"name": sig.name,
			"args": sig_args,
		})
	result["signals"] = signals

	# Enums
	var enum_list := ClassDB.class_get_enum_list(target_class, !include_inherited)
	var enums := {}
	for enum_name in enum_list:
		var constants := ClassDB.class_get_enum_constants(target_class, enum_name, !include_inherited)
		var enum_values := {}
		for constant_name in constants:
			enum_values[constant_name] = ClassDB.class_get_integer_constant(target_class, constant_name)
		enums[enum_name] = enum_values
	result["enums"] = enums

	# Integer constants (not part of named enums)
	var constant_list := ClassDB.class_get_integer_constant_list(target_class, !include_inherited)
	var constants := {}
	for c_name in constant_list:
		# Skip ones already covered by enums
		var in_enum := false
		for enum_name in enum_list:
			if c_name in ClassDB.class_get_enum_constants(target_class, enum_name, !include_inherited):
				in_enum = true
				break
		if not in_enum:
			constants[c_name] = ClassDB.class_get_integer_constant(target_class, c_name)
	if not constants.is_empty():
		result["constants"] = constants

	return result


func list_project_files(params: Dictionary) -> Variant:
	var directory: String = params.get("directory", "res://")
	var extensions: Array = params.get("extensions", [])
	var recursive: bool = params.get("recursive", true)
	var max_files: int = params.get("max_files", 500)

	if not DirAccess.dir_exists_absolute(directory):
		return {"error": {"code": -1, "message": "Directory not found: " + directory}}

	var files := []
	_scan_directory(directory, extensions, recursive, files, max_files)

	return {
		"directory": directory,
		"file_count": files.size(),
		"files": files,
	}


# ── Private helpers ──────────────────────────────────────────────────────────

func _get_hierarchy(cls_name: String) -> Array:
	var hierarchy := []
	var current := cls_name
	while not current.is_empty():
		hierarchy.append(current)
		current = ClassDB.get_parent_class(current)
	return hierarchy


func _find_similar_classes(query: String) -> Array:
	## Returns up to 5 class names similar to the query for suggestions.
	var all_classes := ClassDB.get_class_list()
	var query_lower := query.to_lower()
	var matches := []

	for cls in all_classes:
		if cls.to_lower().contains(query_lower) or query_lower.contains(cls.to_lower()):
			matches.append(cls)
			if matches.size() >= 5:
				break

	return matches


func _scan_directory(path: String, extensions: Array, recursive: bool, results: Array, max_files: int) -> void:
	if results.size() >= max_files:
		return

	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty() and results.size() < max_files:
		# Skip hidden files and .godot cache
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := path.path_join(file_name)

		if dir.current_is_dir():
			if recursive:
				_scan_directory(full_path, extensions, recursive, results, max_files)
		else:
			# Filter by extension if specified
			if extensions.is_empty() or _matches_extension(file_name, extensions):
				results.append({
					"path": full_path,
					"name": file_name,
					"extension": file_name.get_extension(),
				})

		file_name = dir.get_next()

	dir.list_dir_end()


func _matches_extension(file_name: String, extensions: Array) -> bool:
	var ext := "." + file_name.get_extension()
	for e in extensions:
		var check: String = e if e.begins_with(".") else "." + e
		if ext == check:
			return true
	return false
