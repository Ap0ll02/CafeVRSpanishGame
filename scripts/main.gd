extends Node3D

const ORDER: Dictionary = {
	"id": "order_001",
	"drink_type": "café",
	"size": "mediano",
	"milk": true,
	"sugar": false,
	"spanish_text": "Quisiera un café mediano con leche, sin azúcar.",
}

@onready var cup: DrinkCup = $Cup
@onready var feedback_label: Label3D = $FeedbackLabel
@onready var delivery_area: Area3D = $DeliveryArea

var attempts: int = 0
var order_complete: bool = false


func _ready() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface != null and xr_interface.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		print("OpenXR is unavailable; the scene remains viewable in the editor.")

	$OrderLabel.text = ORDER["spanish_text"]
	$CoffeeArea.body_entered.connect(_on_coffee_entered)
	$MilkArea.body_entered.connect(_on_milk_entered)
	$SugarArea.body_entered.connect(_on_sugar_entered)
	$RinseArea.body_entered.connect(_on_rinse_entered)
	cup.dropped.connect(_on_cup_dropped)
	feedback_label.text = "Prepara el pedido y deja la taza en ENTREGA."


func _on_coffee_entered(body: Node3D) -> void:
	if body == cup and not order_complete:
		cup.add_coffee()


func _on_milk_entered(body: Node3D) -> void:
	if body == cup and not order_complete:
		cup.add_milk()


func _on_sugar_entered(body: Node3D) -> void:
	if body == cup and not order_complete:
		cup.add_sugar()


func _on_rinse_entered(body: Node3D) -> void:
	if body == cup and not order_complete:
		cup.rinse()


func _on_cup_dropped(_pickable: XRToolsPickable) -> void:
	if not order_complete and delivery_area.get_overlapping_bodies().has(cup):
		_evaluate_delivery()


func _evaluate_delivery() -> void:
	attempts += 1
	var submitted: Dictionary = cup.get_drink_state()
	var mismatches: Array[String] = []
	for attribute: String in ["drink_type", "size", "milk", "sugar"]:
		if submitted[attribute] != ORDER[attribute]:
			mismatches.append(attribute)

	if mismatches.is_empty():
		order_complete = true
		feedback_label.text = "¡Perfecto, muchas gracias!"
	elif attempts == 1:
		if mismatches.has("sugar") and cup.sugar:
			feedback_label.text = "Perdón, lo pedí sin azúcar."
		else:
			feedback_label.text = "Perdón, pedí un café mediano con leche."
	elif attempts == 2:
		feedback_label.text = "Un café mediano con leche, sin azúcar, por favor."
	else:
		feedback_label.text = "CAFÉ + LECHE, SIN AZÚCAR. Lava la taza y prepáralo otra vez."
