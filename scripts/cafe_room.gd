class_name CafeRoom
extends RefCounted
## Builds the floor, walls, ceiling, doorways and wall decor around the counter.
## Everything is visual only; the original Floor collider in main.tscn still does the physics.

const WALL_COLOR := Color("ecdcc0")
const PANEL_COLOR := Color("6b4a32")
const CEILING_COLOR := Color("f4ead8")
const DOOR_COLOR := Color("2b1d14")
const HALF_WIDTH := 5.2
const FRONT_Z := 4.1
const BACK_Z := -2.9


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


static func _box(parent: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)


static func _poster(parent: Node3D, texture_path: String, size: Vector2, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mi.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(texture_path)
	mi.material_override = material
	mi.position = pos
	parent.add_child(mi)


## Checkerboard tile floor from a 2x2 texture repeated every metre.
static func _floor(parent: Node3D, depth: float, center_z: float) -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	for x in 2:
		for y in 2:
			image.set_pixel(x, y, Color("d9c3a0") if (x + y) % 2 == 0 else Color("a88761"))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(HALF_WIDTH * 2.0, depth, 1.0)
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(HALF_WIDTH * 2.0, depth)
	mi.mesh = plane
	mi.material_override = material
	mi.position = Vector3(0, 0, center_z)
	parent.add_child(mi)


static func build(root: Node3D, door_z: float) -> void:
	var depth := FRONT_Z - BACK_Z
	var center_z := (FRONT_Z + BACK_Z) / 2.0
	var wall := _material(WALL_COLOR)
	_floor(root, depth, center_z)
	_box(root, Vector3(HALF_WIDTH * 2.0, 3.2, 0.1), Vector3(0, 1.6, BACK_Z - 0.05), wall) # back
	_box(root, Vector3(HALF_WIDTH * 2.0, 3.2, 0.1), Vector3(0, 1.6, FRONT_Z + 0.05), wall) # behind player
	_box(root, Vector3(HALF_WIDTH * 2.0, 0.1, depth), Vector3(0, 3.25, center_z), _material(CEILING_COLOR))
	_box(root, Vector3(HALF_WIDTH * 2.0, 1.0, 0.04), Vector3(0, 0.5, BACK_Z + 0.02), _material(PANEL_COLOR))
	var door := _material(DOOR_COLOR)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(0.1, 3.2, depth), Vector3(side * (HALF_WIDTH + 0.05), 1.6, center_z), wall)
		_box(root, Vector3(0.04, 2.1, 1.1), Vector3(side * (HALF_WIDTH - 0.01), 1.05, door_z), door) # doorway

	_poster(root, "res://assets/cafe/Cafe Restaurant Menu-page-001.jpg", Vector2(0.9, 1.2), Vector3(-2.3, 1.75, BACK_Z + 0.03))
	CafeAssets.place(root, "Light string 1", 3.0, Vector3(0, 2.6, BACK_Z + 0.1), 0.0, false)
	CafeAssets.place(root, "Wall lamp 01", 0.3, Vector3(-3.4, 1.9, BACK_Z + 0.05))
	CafeAssets.place(root, "Wall lamp 01", 0.3, Vector3(3.4, 1.9, BACK_Z + 0.05))
