@tool
extends RefCounted
## Captures editor viewport screenshots and returns them as base64 PNG.


func get_viewport_screenshot(params: Dictionary) -> Variant:
	var viewport_type: String = params.get("viewport", "3d")

	var img: Image = null

	match viewport_type:
		"3d":
			img = _capture_3d_viewport()
		"2d":
			img = _capture_2d_viewport()
		_:
			return {"error": {"code": -1, "message": "Invalid viewport type: %s. Use '2d' or '3d'." % viewport_type}}

	if not img:
		return {"error": {"code": -1, "message": "Failed to capture %s viewport. Ensure a scene is open." % viewport_type}}

	var png_bytes := img.save_png_to_buffer()
	if png_bytes.is_empty():
		return {"error": {"code": -1, "message": "Failed to encode viewport to PNG"}}

	var base64_data := Marshalls.raw_to_base64(png_bytes)

	return {
		"image_base64": base64_data,
		"mime_type": "image/png",
		"width": img.get_width(),
		"height": img.get_height(),
		"viewport": viewport_type,
	}


# ── Private helpers ──────────────────────────────────────────────────────────

func _capture_3d_viewport() -> Image:
	## Captures the primary 3D editor viewport.
	# EditorInterface.get_editor_viewport_3d() returns the SubViewport
	var viewport := EditorInterface.get_editor_viewport_3d(0)
	if not viewport:
		return null

	var texture := viewport.get_texture()
	if not texture:
		return null

	return texture.get_image()


func _capture_2d_viewport() -> Image:
	## Captures the 2D editor viewport.
	var viewport := EditorInterface.get_editor_viewport_2d()
	if not viewport:
		return null

	var texture := viewport.get_texture()
	if not texture:
		return null

	return texture.get_image()
