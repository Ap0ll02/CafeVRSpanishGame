extends XRToolsPickable
class_name DrinkCup

## Per-size cup models and dimensions. Tune `liquid_r` (liquid surface radius) and
## `target` (fitted model size) here if a cup looks off in the headset.
const SIZE_SPECS: Dictionary = {
	"pequeño": {"prop": "Cup espresso blue", "target": 0.09, "by_height": false, "radius": 0.06, "liquid_r": 0.022},
	"mediano": {"prop": "Cup Cappuchino blue", "target": 0.14, "by_height": false, "radius": 0.08, "liquid_r": 0.038},
	"grande": {"prop": "Cup tall blue", "target": 0.17, "by_height": true, "radius": 0.095, "liquid_r": 0.035},
}
const LIQUID_FILL: float = 0.7 # fraction of the cup's height

@export var size: String = "mediano"

var drink_type: String = ""
var milk: bool = false
var sugar: bool = false

var _spawn_transform: Transform3D
var _consumed: bool = false

@onready var liquid: MeshInstance3D = $Liquid
@onready var contents_label: Label3D = $ContentsLabel


func _ready() -> void:
	super._ready()
	_build_visual()
	_spawn_transform = global_transform
	_refresh_visual()


func _physics_process(_delta: float) -> void:
	if _consumed or is_picked_up() or global_position.y >= 0.5:
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn_transform


func _build_visual() -> void:
	var spec: Dictionary = SIZE_SPECS[size]
	var radius: float = spec["radius"]

	# Duplicated cups carry the template's visual; replace it rather than stacking.
	var old := get_node_or_null("Visual")
	if old != null:
		remove_child(old)
		old.free()
	$Mesh.visible = false
	$Handle.visible = false

	var shape := SphereShape3D.new()
	shape.radius = radius
	$Collision.shape = shape

	var cup_height := 0.1
	var visual := CafeAssets.make_prop(spec["prop"], spec["target"], spec["by_height"])
	if visual != null:
		visual.name = "Visual"
		add_child(visual)
		visual.position = Vector3(0, -radius, 0) # model bottom rests on the sphere bottom
		cup_height = CafeAssets.measure(visual).size.y

	var liquid_mesh := CylinderMesh.new()
	liquid_mesh.top_radius = spec["liquid_r"]
	liquid_mesh.bottom_radius = spec["liquid_r"]
	liquid_mesh.height = 0.01
	liquid.mesh = liquid_mesh
	liquid.position = Vector3(0, -radius + cup_height * LIQUID_FILL, 0)
	contents_label.position = Vector3(0, -radius + cup_height + 0.08, 0)


func add_coffee() -> void:
	drink_type = "café"
	_refresh_visual()


func add_milk() -> void:
	milk = true
	_refresh_visual()


func add_sugar() -> void:
	sugar = true
	_refresh_visual()


func rinse() -> void:
	drink_type = ""
	milk = false
	sugar = false
	_refresh_visual()


func get_drink_state() -> Dictionary:
	return {
		"drink_type": drink_type,
		"size": size,
		"milk": milk,
		"sugar": sugar,
	}


## Flies the cup to `target` (the customer), then hides it. Awaitable.
func consume(target: Vector3) -> void:
	_consumed = true
	freeze = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", target, 0.7)
	await tween.finished
	visible = false
	$Collision.set_deferred("disabled", true)


## Puts a fresh, empty cup back at its starting spot.
func respawn() -> void:
	rinse()
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_transform = _spawn_transform
	freeze = false
	visible = true
	$Collision.set_deferred("disabled", false)
	_consumed = false


func _refresh_visual() -> void:
	liquid.visible = drink_type != ""
	if liquid.visible:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ad8970") if milk else Color("503326")
		liquid.material_override = material
	contents_label.text = "%s: %s%s%s" % [
		size,
		drink_type if drink_type != "" else "vacía",
		" + leche" if milk else "",
		" + azúcar" if sugar else "",
	]
