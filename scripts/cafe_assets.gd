class_name CafeAssets
extends RefCounted
## Pulls individual props out of the café asset pack FBX by name and fits them
## to a target size, so scenes don't depend on the pack's internal layout or scale.

const PACK: PackedScene = preload("res://assets/cafe/Cafe asset pack 1.fbx")
const CUSTOMER: PackedScene = preload("res://assets/characters/all_together.fbx")

static var _pack_root: Node3D


static func _norm(s: String) -> String:
	var out := ""
	for c in s.to_lower():
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	return out


static func _find_named(root: Node, prop_name: String) -> Node3D:
	var want := _norm(prop_name)
	if root.name != &"" and _norm(str(root.name)) == want and root is Node3D:
		return root
	for child in root.get_children():
		var hit := _find_named(child, prop_name)
		if hit != null:
			return hit
	return null


## Returns a Node3D whose origin is the bottom-center of the prop, scaled so its
## height (or, if `fit_height` is 0, its longest side) equals `target`.
## Returns null (with a warning) if the prop isn't in the pack.
static func make_prop(prop_name: String, target: float, fit_height: bool = true) -> Node3D:
	if _pack_root == null:
		_pack_root = PACK.instantiate()
	var source := _find_named(_pack_root, prop_name)
	if source == null:
		push_warning("CafeAssets: prop '%s' not found in pack" % prop_name)
		return null

	var copy: Node3D = source.duplicate()
	var pivot := Node3D.new()
	pivot.name = prop_name.replace(" ", "_")
	var holder := Node3D.new()
	pivot.add_child(holder)
	holder.add_child(copy)
	# Keep the orientation/scale the importer baked into the node chain (Blender
	# Z-up -> Godot Y-up), but drop the prop's position in the pack's layout grid.
	var chain := Transform3D.IDENTITY
	var n: Node = source
	while n != null:
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	copy.transform = Transform3D(chain.basis, Vector3.ZERO)

	var box := measure(holder)
	if box.size == Vector3.ZERO:
		return pivot
	var dim := box.size.y if fit_height else maxf(box.size.x, maxf(box.size.y, box.size.z))
	var s := target / maxf(dim, 0.0001)
	holder.scale = Vector3.ONE * s
	var bottom_center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
	holder.position = -bottom_center * s
	return pivot


## Like make_prop, but stretches the prop to exactly fill `size` (x, y, z).
static func make_prop_boxed(prop_name: String, size: Vector3) -> Node3D:
	var pivot := make_prop(prop_name, 1.0)
	if pivot == null:
		return null
	var holder: Node3D = pivot.get_child(0)
	var box := measure(holder)
	# make_prop already scaled uniformly to height 1; re-fit each axis.
	var unit := box.size * holder.scale
	if unit.x > 0.0001 and unit.y > 0.0001 and unit.z > 0.0001:
		var k := Vector3(size.x / unit.x, size.y / unit.y, size.z / unit.z)
		holder.scale *= k
		holder.position *= k
	return pivot


static func measure(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or not mi.visible:
			continue
		var xform := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != root:
			xform = (n as Node3D).transform * xform
			n = n.get_parent()
		var box := xform * mi.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Places a fitted prop under `parent`. Returns the prop (or null if missing).
static func place(parent: Node3D, prop_name: String, target: float, pos: Vector3 = Vector3.ZERO,
		yaw_deg: float = 0.0, fit_height: bool = true) -> Node3D:
	var prop := make_prop(prop_name, target, fit_height)
	if prop == null:
		return null
	parent.add_child(prop)
	prop.position = pos
	prop.rotation_degrees.y = yaw_deg
	return prop


## Instances the customer character, showing only the `outfit` variant
## (e.g. "Casual") and starting the idle animation.
static func make_customer(outfit: String, height: float) -> Node3D:
	var root: Node3D = CUSTOMER.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var n := str(mi.name)
		var is_variant := n.contains("_Body") or n.contains("_Head") or n.contains("_Legs") \
				or n.contains("_Feet") or n.contains("_Head")
		if is_variant:
			mi.visible = n.begins_with(outfit + "_") or (outfit == "Formal" and n == "Formad_Head")
		elif n == "Sword" or n == "Pistol":
			mi.visible = false

	var pivot := Node3D.new()
	pivot.name = "Customer"
	pivot.add_child(root)
	# Fit to height using the visible meshes measured through their full node chain
	# (the importer stores unit scale on the armature/skeleton nodes).
	var box := measure(root)
	if box.size.y > 0.0001:
		var s := height / box.size.y
		root.scale = Vector3.ONE * s
		root.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)

	var player: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if player != null:
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			var short := str(anim_name).get_slice("|", 1) if "|" in str(anim_name) else str(anim_name)
			if short in ["Idle", "Idle_Neutral", "Walk"]:
				anim.loop_mode = Animation.LOOP_LINEAR
		play(pivot, "Idle")
	return pivot


## Plays an animation on the customer whose name ends with `anim` (e.g. "Wave").
## One-shot animations fall back to Idle when they finish.
static func play(customer: Node, anim: String) -> void:
	var player: AnimationPlayer = customer.find_child("AnimationPlayer", true, false)
	if player == null:
		return
	var idle := ""
	for anim_name in player.get_animation_list():
		if str(anim_name).ends_with("|Idle") or str(anim_name) == "Idle":
			idle = str(anim_name)
	for anim_name in player.get_animation_list():
		if str(anim_name).ends_with(anim):
			player.play(anim_name)
			if idle != "" and anim != "Idle" and player.get_animation(anim_name).loop_mode == Animation.LOOP_NONE:
				player.queue(idle)
			return
