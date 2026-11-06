class_name MeshBuilder
## Helpers for building flat-shaded block meshes with SurfaceTool.
## Godot draws clockwise triangles as front faces, so each face is wound
## clockwise as seen from outside.


static func add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var cross := (b - a).cross(c - a)
	if cross.dot(outward) > 0.0:
		var swap := b
		b = c
		c = swap
		cross = -cross
	var normal := -cross.normalized()
	for point in [a, b, c]:
		st.set_normal(normal)
		st.add_vertex(point)


static func add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	add_triangle(st, a, b, c, outward)
	add_triangle(st, a, c, d, outward)


static func add_box(st: SurfaceTool, size: Vector3, xform: Transform3D) -> void:
	var h := size / 2.0
	var corners := []
	for i in 8:
		var local := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		corners.append(xform * local)
	var faces := [
		[1, 3, 7, 5, Vector3.RIGHT], [0, 4, 6, 2, Vector3.LEFT],
		[2, 6, 7, 3, Vector3.UP], [0, 1, 5, 4, Vector3.DOWN],
		[4, 5, 7, 6, Vector3.BACK], [0, 2, 3, 1, Vector3.FORWARD],
	]
	for face in faces:
		add_quad(st, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], xform.basis * face[4])


# A prism around the vertical axis, or a frustum when the two radii differ.
# Radii are to the corners. With 8 sides and a 22.5 degree offset, flat sides face the X and Z axes.
static func add_prism(st: SurfaceTool, sides: int, bottom_radius: float, top_radius: float, bottom_y: float, top_y: float, angle_offset: float) -> void:
	var bottom := []
	var top := []
	for i in sides:
		var angle := angle_offset + i * TAU / sides
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		bottom.append(direction * bottom_radius + Vector3(0, bottom_y, 0))
		top.append(direction * top_radius + Vector3(0, top_y, 0))
	for i in sides:
		var j := (i + 1) % sides
		var outward: Vector3 = (bottom[i] + bottom[j]) / 2.0
		outward.y = 0.0
		add_quad(st, bottom[i], bottom[j], top[j], top[i], outward)
	var bottom_center := Vector3(0, bottom_y, 0)
	var top_center := Vector3(0, top_y, 0)
	for i in sides:
		var j := (i + 1) % sides
		add_triangle(st, top_center, top[i], top[j], Vector3.UP)
		add_triangle(st, bottom_center, bottom[j], bottom[i], Vector3.DOWN)


static func make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	material.metallic = 0.2
	return material
