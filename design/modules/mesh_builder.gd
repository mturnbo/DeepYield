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


# A thin square box from one point to another.
static func add_strut(st: SurfaceTool, from: Vector3, to: Vector3, thickness: float) -> void:
	var along := to - from
	var x_axis := along.normalized()
	var helper := Vector3.UP if absf(x_axis.dot(Vector3.UP)) < 0.9 else Vector3.BACK
	var z_axis := x_axis.cross(helper).normalized()
	var y_axis := z_axis.cross(x_axis)
	var strut_basis := Basis(x_axis, y_axis, z_axis)
	add_box(st, Vector3(along.length(), thickness, thickness), Transform3D(strut_basis, (from + to) / 2.0))


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


# A lumpy, flat-shaded rock about 1 m in radius.
static func make_rock_mesh(rng: RandomNumberGenerator, lumpiness: float) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.9
	var stretch := Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.3))

	var points := _icosphere_points()
	for i in points.size():
		var p := points[i]
		points[i] = p * (1.0 + noise.get_noise_3dv(p * 1.7) * lumpiness * 2.0) * stretch

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in _icosphere_faces():
		var a := points[face[0]]
		var b := points[face[1]]
		var c := points[face[2]]
		var normal := (b - a).cross(c - a).normalized()
		if normal.dot(a + b + c) < 0.0:
			normal = -normal
		surface.set_normal(normal)
		surface.add_vertex(a)
		surface.set_normal(normal)
		surface.add_vertex(b)
		surface.set_normal(normal)
		surface.add_vertex(c)
	return surface.commit()


# An icosahedron subdivided once: 42 points and 80 faces.
static var _ico_points: PackedVector3Array = []
static var _ico_faces: Array[PackedInt32Array] = []


static func _icosphere_points() -> PackedVector3Array:
	if _ico_points.is_empty():
		_build_icosphere()
	return _ico_points.duplicate()


static func _icosphere_faces() -> Array[PackedInt32Array]:
	if _ico_faces.is_empty():
		_build_icosphere()
	return _ico_faces


static func _build_icosphere() -> void:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var corners := [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	]
	var faces := [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	_ico_points = PackedVector3Array()
	for corner in corners:
		_ico_points.append(corner.normalized())

	var midpoints := {}
	for face in faces:
		var ab := _midpoint(face[0], face[1], midpoints)
		var bc := _midpoint(face[1], face[2], midpoints)
		var ca := _midpoint(face[2], face[0], midpoints)
		_ico_faces.append(PackedInt32Array([face[0], ab, ca]))
		_ico_faces.append(PackedInt32Array([face[1], bc, ab]))
		_ico_faces.append(PackedInt32Array([face[2], ca, bc]))
		_ico_faces.append(PackedInt32Array([ab, bc, ca]))


static func _midpoint(a: int, b: int, cache: Dictionary) -> int:
	var key := Vector2i(mini(a, b), maxi(a, b))
	if cache.has(key):
		return cache[key]
	_ico_points.append(((_ico_points[a] + _ico_points[b]) / 2.0).normalized())
	cache[key] = _ico_points.size() - 1
	return cache[key]
