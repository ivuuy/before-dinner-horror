extends RefCounted
## Small, reusable modelling primitives. All project geometry is original.

static func material(color: Color, rough := 0.8, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = mat
	parent.add_child(node)
	node.position = pos
	return node

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(parent, shape, pos, mat)

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape := SphereMesh.new()
	shape.radial_segments = 20
	shape.rings = 12
	var node := mesh(parent, shape, pos, mat)
	node.scale = size
	return node

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top := -1.0) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius if top < 0.0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 24
	return mesh(parent, shape, pos, mat)

static func torus(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material) -> MeshInstance3D:
	var shape := TorusMesh.new()
	shape.inner_radius = inner
	shape.outer_radius = outer
	shape.rings = 24
	shape.ring_segments = 12
	return mesh(parent, shape, pos, mat)

static func limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, top := -1.0) -> MeshInstance3D:
	var node := cylinder(parent, (a+b)*0.5, radius, a.distance_to(b), mat, top)
	node.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return node

static func body(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, id := "", prompt := "") -> StaticBody3D:
	var node := StaticBody3D.new()
	parent.add_child(node)
	node.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	node.add_child(collision)
	if mat:
		box(node, Vector3.ZERO, size, mat)
	if not id.is_empty():
		node.set_meta("interact_id", id)
		node.set_meta("prompt", prompt)
	return node

static func bowl(parent: Node3D, pos: Vector3, mat: Material) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	cylinder(root, Vector3(0,0.025,0), 0.10, 0.05, mat, 0.15)
	torus(root, Vector3(0,0.07,0), 0.13, 0.157, mat)
	var inside := material(Color("c5c9b6"),0.23)
	cylinder(root,Vector3(0,0.057,0),0.13,0.008,inside)
	return root
