extends Node3D

signal order_done(cup: DrinkCup)

const ORDERS: Array = [
	{
		"id": "order_001", "drink_type": "café", "size": "mediano", "milk": true, "sugar": false,
		"spanish_text": "Quisiera un café mediano con leche, sin azúcar.",
	},
	{
		"id": "order_002", "drink_type": "café", "size": "pequeño", "milk": false, "sugar": true,
		"spanish_text": "Un café pequeño, solo, con azúcar, por favor.",
	},
	{
		"id": "order_003", "drink_type": "café", "size": "grande", "milk": true, "sugar": true,
		"spanish_text": "Quiero un café grande con leche y con azúcar.",
	},
]
const OUTFITS: Array = ["Casual", "Formal", "Medieval", "Adventurer", "Worker", "Punk"]
const CUSTOMER_Z: float = -1.85
const ENTRY_X: float = 3.4
const EXIT_X: float = -3.4
const WALK_SPEED: float = 1.1
const CUP_SIZES: Array = ["pequeño", "mediano", "grande"]
const CUP_X: Dictionary = {"pequeño": -1.15, "mediano": -0.95, "grande": -0.72}

@onready var feedback_label: Label3D = $FeedbackLabel
@onready var order_label: Label3D = $OrderLabel
@onready var delivery_area: Area3D = $DeliveryArea

var order: Dictionary = ORDERS[0]
var attempts: int = 0
var order_complete: bool = false
var customer_ready: bool = false
var customer: Node3D
var cups: Array[DrinkCup] = []


func _ready() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface != null and xr_interface.is_initialized():
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		get_viewport().use_xr = true
	else:
		print("OpenXR is unavailable; the scene remains viewable in the editor.")

	_dress_scene()
	_spawn_cups()
	$CoffeeArea.body_entered.connect(_on_coffee_entered)
	$MilkArea.body_entered.connect(_on_milk_entered)
	$SugarArea.body_entered.connect(_on_sugar_entered)
	$RinseArea.body_entered.connect(_on_rinse_entered)
	order_label.text = ""
	feedback_label.text = ""
	_customer_loop()


## The scene's original Cup becomes the mediano cup; the other sizes are copies.
func _spawn_cups() -> void:
	var template: DrinkCup = $Cup
	template.size = "mediano"
	cups.append(template)
	for cup_size: String in ["pequeño", "grande"]:
		var cup: DrinkCup = template.duplicate()
		cup.name = "Cup_" + cup_size
		cup.size = cup_size
		cup.position = Vector3(CUP_X[cup_size], template.position.y, template.position.z)
		add_child(cup)
		cups.append(cup)
	for cup in cups:
		cup.dropped.connect(_on_cup_dropped)


func _customer_loop() -> void:
	var index := 0
	while is_inside_tree():
		order = ORDERS[index % ORDERS.size()]
		attempts = 0
		order_complete = false
		customer_ready = false

		var who := CafeAssets.make_customer(OUTFITS[index % OUTFITS.size()], 1.7)
		customer = who
		add_child(who)
		who.position = Vector3(ENTRY_X, 0, CUSTOMER_Z)
		who.rotation_degrees.y = -90.0 # facing the direction of travel (-x)
		await _walk_to(who, 0.0)
		await _turn_to(who, 0.0) # face the player
		CafeAssets.play(who, "Idle")

		order_label.text = order["spanish_text"]
		feedback_label.text = "Prepara el pedido y deja la taza en ENTREGA."
		customer_ready = true

		var done_cup: DrinkCup = await order_done
		await done_cup.consume(who.global_position + Vector3(0, 1.1, 0.15))
		CafeAssets.play(who, "Wave")
		await get_tree().create_timer(2.5).timeout

		order_label.text = ""
		feedback_label.text = ""
		await _turn_to(who, -90.0)
		await _walk_to(who, EXIT_X)
		who.queue_free()
		done_cup.respawn()
		index += 1


func _walk_to(who: Node3D, x: float) -> void:
	CafeAssets.play(who, "Walk")
	var tween := create_tween()
	tween.tween_property(who, "position:x", x, absf(who.position.x - x) / WALK_SPEED)
	await tween.finished


func _turn_to(who: Node3D, yaw_degrees: float) -> void:
	var tween := create_tween()
	tween.tween_property(who, "rotation_degrees:y", yaw_degrees, 0.4)
	await tween.finished


func _on_coffee_entered(body: Node3D) -> void:
	if body is DrinkCup and not order_complete:
		body.add_coffee()


func _on_milk_entered(body: Node3D) -> void:
	if body is DrinkCup and not order_complete:
		body.add_milk()


func _on_sugar_entered(body: Node3D) -> void:
	if body is DrinkCup and not order_complete:
		body.add_sugar()


func _on_rinse_entered(body: Node3D) -> void:
	if body is DrinkCup and not order_complete:
		body.rinse()


func _on_cup_dropped(pickable: XRToolsPickable) -> void:
	var cup := pickable as DrinkCup
	if cup != null and customer_ready and not order_complete \
			and delivery_area.get_overlapping_bodies().has(cup):
		_evaluate_delivery(cup)


func _describe(o: Dictionary) -> String:
	return "un café %s %s, %s" % [
		o["size"],
		"con leche" if o["milk"] else "solo",
		"con azúcar" if o["sugar"] else "sin azúcar",
	]


func _evaluate_delivery(cup: DrinkCup) -> void:
	attempts += 1
	var submitted: Dictionary = cup.get_drink_state()
	var mismatches: Array[String] = []
	for attribute: String in ["drink_type", "size", "milk", "sugar"]:
		if submitted[attribute] != order[attribute]:
			mismatches.append(attribute)

	if mismatches.is_empty():
		order_complete = true
		feedback_label.text = "¡Perfecto, muchas gracias!"
		order_done.emit(cup)
	elif attempts == 1:
		if mismatches.has("size"):
			feedback_label.text = "Perdón, pedí la taza %s." % order["size"]
		elif mismatches.has("sugar") and cup.sugar:
			feedback_label.text = "Perdón, lo pedí sin azúcar."
		else:
			feedback_label.text = "Perdón, pedí %s." % _describe(order)
	elif attempts == 2:
		feedback_label.text = "%s, por favor." % _describe(order).capitalize()
	else:
		feedback_label.text = "%s. Lava la taza y prepáralo otra vez." % _describe(order).to_upper()


## Swaps the grey-box placeholders for the café asset pack props. Colliders and
## trigger areas are untouched, so gameplay is unchanged.
func _dress_scene() -> void:
	# Counter top surface is at y = 0.9 (world); stations sit 0.18 below their areas.
	$Counter/Mesh.visible = false
	var counter_prop := CafeAssets.make_prop_boxed("Counter tall brown", Vector3(2.4, 0.9, 0.8))
	if counter_prop != null:
		$Counter.add_child(counter_prop)
		counter_prop.position = Vector3(0, -0.45, 0)

	var stations := {
		"RinseArea": ["Plate metal large", 0.22],
		"CoffeeArea": ["Coffee maker Medium", 0.35],
		"MilkArea": ["Milk jug", 0.2],
		"SugarArea": ["Pot sphere white", 0.14],
		"DeliveryArea": ["Cash register Type A black", 0.3],
	}
	for area_name: String in stations:
		var area: Node3D = get_node(area_name)
		area.get_node("Mesh").visible = false
		# Flat, wide items (plate) are sized by longest side; tall ones by height.
		var by_height: bool = area_name != "RinseArea"
		CafeAssets.place(area, stations[area_name][0], stations[area_name][1], Vector3(0, -0.18, 0), 0.0, by_height)

	# Backdrop, kept clear of the customers' walking lane along z = CUSTOMER_Z.
	CafeAssets.place(self, "Chalkboard menu wall sign 1", 0.9, Vector3(1.3, 1.2, -2.5))
	CafeAssets.place(self, "Plant tropical heart shaped", 1.0, Vector3(-1.6, 0, -2.5))
	CafeAssets.place(self, "Plant long leaves", 0.9, Vector3(1.7, 0, -2.5))
	CafeAssets.place(self, "Ceiling Light A", 0.35, Vector3(0, 2.6, -1.0))
	CafeAssets.place(self, "Round table beige", 0.75, Vector3(-1.4, 0, 0.8))
	CafeAssets.place(self, "Round chair 1 beige", 0.5, Vector3(-1.4, 0, 1.3))

	$CustomerPlaceholder.visible = false
