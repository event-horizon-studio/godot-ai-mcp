@tool
extends RefCounted
## Handles Resource creation and management (Materials, Shaders, etc.)


func create_material(params: Dictionary) -> Variant:
	var save_path: String = params.get("save_path", "")
	var albedo_color = params.get("albedo_color") # e.g. {"r": 1, "g": 0, "b": 0} or "#ff0000"
	var roughness = params.get("roughness", 0.5)
	var metallic = params.get("metallic", 0.0)
	var emission_color = params.get("emission_color")
	var emission_energy_multiplier = params.get("emission_energy_multiplier", 1.0)

	var mat := StandardMaterial3D.new()
	mat.roughness = float(roughness)
	mat.metallic = float(metallic)

	if albedo_color != null:
		mat.albedo_color = _parse_color(albedo_color)

	if emission_color != null:
		mat.emission_enabled = true
		mat.emission = _parse_color(emission_color)
		mat.emission_energy_multiplier = float(emission_energy_multiplier)

	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			save_path = "res://" + save_path
		if not save_path.ends_with(".tres"):
			save_path += ".tres"

		var dir := save_path.get_base_dir()
		if not DirAccess.dir_exists_absolute(dir):
			DirAccess.make_dir_recursive_absolute(dir)

		var err := ResourceSaver.save(mat, save_path)
		if err != OK:
			return {"error": {"code": int(err), "message": "Failed to save material to: " + save_path}}
		EditorInterface.get_resource_filesystem().scan()
		return {
			"success": true,
			"saved_path": save_path,
			"albedo": mat.albedo_color.to_html(),
			"roughness": mat.roughness,
			"metallic": mat.metallic
		}

	return {
		"success": true,
		"albedo": mat.albedo_color.to_html(),
		"roughness": mat.roughness,
		"metallic": mat.metallic
	}


func _parse_color(val: Variant) -> Color:
	if val is Dictionary:
		var d: Dictionary = val
		return Color(float(d.get("r", 1.0)), float(d.get("g", 1.0)), float(d.get("b", 1.0)), float(d.get("a", 1.0)))
	elif val is String:
		return Color.from_string(val, Color.WHITE)
	return Color.WHITE
