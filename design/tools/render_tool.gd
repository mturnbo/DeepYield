extends Node
# Renders each job from a JSON list onto a transparent background and saves it
# cropped to what was drawn. Run with: godot --path . res://design/tools/render_tool.tscn -- <jobs.json>

func _ready() -> void:
	var jobs: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	for job in jobs:
		await _render(job)
	get_tree().quit()


func _render(job: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(job["res"][0], job["res"][1])
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.55)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.85, 2.6, 0)
	sun.light_color = Color(1, 0.95, 0.88)
	sun.light_energy = 1.3
	vp.add_child(sun)

	var target: Node3D = load(job["script"]).new()
	for key in job.get("props", {}):
		target.set(key, job["props"][key])
	vp.add_child(target)

	var center := Vector3(job["center"][0], job["center"][1], job["center"][2])
	var yaw := deg_to_rad(job["yaw"])
	var pitch := deg_to_rad(job["pitch"])
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = job["size"]
	camera.near = 1.0
	camera.far = 6000.0
	vp.add_child(camera)
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 2000.0
	camera.position = center + offset
	var up := Vector3.UP if absf(job["pitch"]) < 89.0 else Vector3.FORWARD
	if job.has("up"):
		up = Vector3(job["up"][0], job["up"][1], job["up"][2])
	camera.look_at(center, up)
	camera.current = true

	for i in 12:
		await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var used := image.get_used_rect().grow(12).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(used).save_png(job["out"])
	vp.queue_free()
	await get_tree().process_frame
