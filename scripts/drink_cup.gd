extends XRToolsPickable
class_name DrinkCup

@export var size: String = "mediano"

var drink_type: String = ""
var milk: bool = false
var sugar: bool = false

@onready var liquid: MeshInstance3D = $Liquid
@onready var contents_label: Label3D = $ContentsLabel


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


func _refresh_visual() -> void:
	liquid.visible = drink_type != ""
	if liquid.visible:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("ad8970") if milk else Color("503326")
		liquid.material_override = material
	contents_label.text = "%s%s%s" % [
		drink_type if drink_type != "" else "vacía",
		" + leche" if milk else "",
		" + azúcar" if sugar else "",
	]
