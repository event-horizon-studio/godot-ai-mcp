@tool
extends RefCounted
## Handles editor lifecycle requests: status, scene management, project run/stop.


func get_editor_status(_params: Dictionary) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	var version_info := Engine.get_version_info()

	return {
		"godot_version": "%s.%s.%s-%s" % [
			version_info.get("major", "?"),
			version_info.get("minor", "?"),
			version_info.get("patch", "?"),
			version_info.get("status", "stable"),
		],
		"plugin_version": "1.0.0",
		"project_name": ProjectSettings.get_setting("application/config/name", "Untitled"),
		"active_scene_path": scene_root.scene_file_path if scene_root else "",
		"active_scene_root": scene_root.name if scene_root else "",
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"),
		"is_playing": EditorInterface.is_playing_scene(),
	}


func open_scene(params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("scene_path", "")
	if scene_path.is_empty():
		return {"error": {"code": -1, "message": "Missing required param: scene_path"}}

	if not ResourceLoader.exists(scene_path):
		return {"error": {"code": -1, "message": "Scene not found: " + scene_path}}

	EditorInterface.open_scene_from_path(scene_path)
	return {"success": true, "scene_path": scene_path}


func save_scene(_params: Dictionary) -> Dictionary:
	var scene_root := EditorInterface.get_edited_scene_root()
	if not scene_root:
		return {"error": {"code": -1, "message": "No active scene to save"}}

	var err := EditorInterface.save_scene()
	if err != OK:
		return {"error": {"code": int(err), "message": "Failed to save scene, error code: %d" % err}}

	return {"success": true, "scene_path": scene_root.scene_file_path}


func run_project(params: Dictionary) -> Dictionary:
	var scene_path: String = params.get("scene_path", "")

	if scene_path.is_empty():
		EditorInterface.play_main_scene()
	else:
		if not ResourceLoader.exists(scene_path):
			return {"error": {"code": -1, "message": "Scene not found: " + scene_path}}
		EditorInterface.play_custom_scene(scene_path)

	return {"success": true, "playing": scene_path if not scene_path.is_empty() else "main_scene"}


func stop_project(_params: Dictionary) -> Dictionary:
	if not EditorInterface.is_playing_scene():
		return {"error": {"code": -1, "message": "No scene is currently playing"}}

	EditorInterface.stop_playing_scene()
	return {"success": true}


func get_editor_logs(params: Dictionary) -> Dictionary:
	var line_count: int = params.get("line_count", 50)
	var log_path: String = ProjectSettings.get_setting("debug/settings/stdout/log_path", "user://logs/godot.log")
	
	if not FileAccess.file_exists(log_path):
		# Fallback to standard godot log path
		log_path = "user://logs/godot.log"
		if not FileAccess.file_exists(log_path):
			return {
				"logs": [],
				"message": "No log file found at user://logs/godot.log"
			}

	var file := FileAccess.open(log_path, FileAccess.READ)
	if not file:
		return {"error": {"code": -1, "message": "Failed to open log file at: " + log_path}}

	var all_text := file.get_as_text()
	file.close()

	var lines := all_text.split("\n")
	var start_idx := max(0, lines.size() - line_count)
	var recent_lines: Array[String] = []
	for i in range(start_idx, lines.size()):
		var l := lines[i].strip_edges()
		if not l.is_empty():
			recent_lines.append(l)

	return {
		"total_lines": lines.size(),
		"returned_lines": recent_lines.size(),
		"logs": recent_lines
	}

