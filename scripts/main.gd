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
## English practice drinks shown before the Spanish customers arrive.
const TUTORIAL: Array = [
	{
		"drink_type": "café", "size": "mediano", "milk": true, "sugar": false,
		"english": "Make a MEDIUM coffee with milk and no sugar.",
	},
	{
		"drink_type": "café", "size": "pequeño", "milk": false, "sugar": true,
		"english": "Now make a SMALL black coffee with sugar.",
	},
]
const MUSIC: Array = [
	"res://assets/music/cafe_music_andriih.mp3",
	"res://assets/music/cafe_lofi_zephira.mp3",
]
const MUSIC_VOLUME_DB: float = -14.0
const OUTFITS: Array = ["Casual", "Formal", "Medieval", "Adventurer", "Worker", "Punk"]
const CUSTOMER_Z: float = -1.85
const ENTRY_X: float = 4.8 # doorways in the side walls
const EXIT_X: float = -4.8
const SLOT_X: Array = [0.0, 0.9, 1.8] # front of the line first
const PAY: float = 5.0 # halved for every mistake
const DRINK_COST: float = 1.0 # ingredients, charged for every drink made
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
var line: Array[Dictionary] = []
var next_index: int = 0
var money: float = 0.0
var money_label: Label3D
var music: AudioStreamPlayer
var music_index: int = 0
var _last_profit: float = 0.0
var tutorial_active: bool = false
var _hint_hold_until: int = 0
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
	money_label = Label3D.new()
	money_label.text = "Cash: $0.00"
	money_label.font_size = 96
	money_label.outline_size = 24
	money_label.pixel_size = 0.004
	money_label.modulate = Color("ffd54a")
	money_label.position = Vector3(-1.3, 1.9, -1.3)
	add_child(money_label)
	_start_music()
	_customer_loop()


## Background café music: the tracks play one after another, forever.
func _start_music() -> void:
	music = AudioStreamPlayer.new()
	music.volume_db = MUSIC_VOLUME_DB
	add_child(music)
	music.finished.connect(_play_next_track)
	_play_next_track()


func _play_next_track() -> void:
	music.stream = load(MUSIC[music_index % MUSIC.size()])
	music.play()
	music_index += 1


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


func _run_tutorial() -> void:
	tutorial_active = true
	order_label.text = "TUTORIAL"
	feedback_label.text = "Welcome, barista! Let's make two drinks. Look at the machines on the counter."
	await get_tree().create_timer(5.0).timeout
	for lesson: Dictionary in TUTORIAL:
		order = lesson
		order_complete = false
		customer_ready = true
		order_label.text = lesson["english"]
		var done_cup: DrinkCup = await order_done
		feedback_label.text = "Well done!"
		await done_cup.consume(Vector3(0, 1.3, CUSTOMER_Z))
		await get_tree().create_timer(1.0).timeout
		done_cup.respawn()
	customer_ready = false
	order_label.text = "Tutorial complete!"
	feedback_label.text = "Now real customers will order in Spanish. Listen carefully!"
	await get_tree().create_timer(5.0).timeout
	tutorial_active = false


func _process(_delta: float) -> void:
	if tutorial_active and customer_ready and not order_complete \
			and Time.get_ticks_msec() >= _hint_hold_until:
		feedback_label.text = _tutorial_hint()


## Tells the player the next step, based on the current state of the target cup.
func _tutorial_hint() -> String:
	var cup: DrinkCup = cups.filter(func(c: DrinkCup) -> bool: return c.size == order["size"])[0]
	if cup.drink_type == "" and not cup.is_picked_up():
		return "Step 1: grab the %s cup with the grip button." % str(order["size"]).to_upper()
	if cup.drink_type == "":
		return "Step 2: hold the cup inside CAFÉ to fill it with coffee."
	if order["milk"] and not cup.milk:
		return "Step 3: hold the cup inside LECHE to add milk."
	if order["sugar"] and not cup.sugar:
		return "Step 3: hold the cup inside AZÚCAR to add sugar."
	if cup.milk != order["milk"] or cup.sugar != order["sugar"]:
		return "Oops, that's not the order. Hold the cup inside LAVAR to empty it, then start over."
	return "Last step: let go of the cup inside ENTREGA."


func _enqueue() -> void:
	var who := CafeAssets.make_customer(OUTFITS[next_index % OUTFITS.size()], 1.7)
	var entry := {"order": ORDERS[next_index % ORDERS.size()], "node": who, "arrived": false}
	next_index += 1
	add_child(who)
	who.position = Vector3(ENTRY_X, 0, CUSTOMER_Z)
	line.append(entry)
	_go_to_slot(entry, SLOT_X[line.size() - 1])


## Walks a waiting customer (facing the direction of travel) to their place in line.
func _go_to_slot(entry: Dictionary, x: float) -> void:
	var who: Node3D = entry["node"]
	entry["arrived"] = false
	await _turn_to(who, -90.0)
	await _walk_to(who, x)
	await _turn_to(who, 0.0) # face the player
	CafeAssets.play(who, "Idle")
	entry["arrived"] = true


func _customer_loop() -> void:
	await _run_tutorial()
	for i in SLOT_X.size():
		_enqueue()
		await get_tree().create_timer(1.5).timeout
	while is_inside_tree():
		var entry: Dictionary = line[0]
		while not entry["arrived"]:
			await get_tree().process_frame
		var who: Node3D = entry["node"]
		customer = who
		order = entry["order"]
		attempts = 0
		order_complete = false
		order_label.text = order["spanish_text"]
		feedback_label.text = "Prepara el pedido y deja la taza en ENTREGA."
		customer_ready = true

		var done_cup: DrinkCup = await order_done
		await done_cup.consume(who.global_position + Vector3(0, 1.1, 0.15))
		_celebrate(who)
		CafeAssets.play(who, "Wave")
		await get_tree().create_timer(2.5).timeout

		order_label.text = ""
		feedback_label.text = ""
		customer_ready = false
		line.pop_front()
		for i in line.size():
			_go_to_slot(line[i], SLOT_X[i]) # everyone steps up
		_enqueue()
		await _turn_to(who, -90.0)
		await _walk_to(who, EXIT_X)
		who.queue_free()
		done_cup.respawn()


## Confetti, a floating profit popup and a happy hop over the customer.
func _celebrate(who: Node3D) -> void:
	var head := who.global_position + Vector3(0, 1.9, 0)
	var popup := Label3D.new()
	popup.text = "%s$%.2f" % ["+" if _last_profit >= 0.0 else "-", absf(_last_profit)]
	popup.font_size = 96
	popup.outline_size = 24
	popup.pixel_size = 0.004
	popup.modulate = Color("5fe36a") if _last_profit >= 0.0 else Color("ff6b5b")
	popup.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	popup.no_depth_test = true
	add_child(popup)
	popup.global_position = head
	var float_up := create_tween().set_parallel(true)
	float_up.tween_property(popup, "position:y", popup.position.y + 0.8, 1.6)
	float_up.tween_property(popup, "modulate:a", 0.0, 0.8).set_delay(0.8)
	float_up.chain().tween_callback(popup.queue_free)

	var bit := SphereMesh.new()
	bit.radius = 0.02
	bit.height = 0.04
	var bit_material := StandardMaterial3D.new()
	bit_material.vertex_color_use_as_albedo = true
	bit_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bit.material = bit_material
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color.GOLD, Color.HOT_PINK, Color.DEEP_SKY_BLUE])
	colors.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var burst := CPUParticles3D.new()
	burst.mesh = bit
	burst.color_initial_ramp = colors
	burst.amount = 60
	burst.lifetime = 1.4
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.direction = Vector3.UP
	burst.spread = 60.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3(0, -6, 0)
	add_child(burst)
	burst.global_position = head - Vector3(0, 0.3, 0)
	burst.emitting = true
	get_tree().create_timer(2.5).timeout.connect(burst.queue_free)

	var hop := create_tween().set_loops(2)
	hop.tween_property(who, "position:y", 0.15, 0.15).set_ease(Tween.EASE_OUT)
	hop.tween_property(who, "position:y", 0.0, 0.15).set_ease(Tween.EASE_IN)


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
		if tutorial_active:
			_evaluate_tutorial(cup)
		else:
			_evaluate_delivery(cup)


func _describe(o: Dictionary) -> String:
	return "un café %s %s, %s" % [
		o["size"],
		"con leche" if o["milk"] else "solo",
		"con azúcar" if o["sugar"] else "sin azúcar",
	]


func _mismatches(cup: DrinkCup) -> Array[String]:
	var submitted: Dictionary = cup.get_drink_state()
	var result: Array[String] = []
	for attribute: String in ["drink_type", "size", "milk", "sugar"]:
		if submitted[attribute] != order[attribute]:
			result.append(attribute)
	return result


func _evaluate_tutorial(cup: DrinkCup) -> void:
	if _mismatches(cup).is_empty():
		order_complete = true
		order_done.emit(cup)
	else:
		feedback_label.text = "Not quite: wrong cup size or recipe. Empty it in LAVAR and try again."
		_hint_hold_until = Time.get_ticks_msec() + 3500


func _evaluate_delivery(cup: DrinkCup) -> void:
	attempts += 1
	var mismatches := _mismatches(cup)

	if mismatches.is_empty():
		order_complete = true
		var revenue := PAY * pow(0.5, attempts - 1)
		var cost := DRINK_COST * attempts
		_last_profit = revenue - cost
		money += _last_profit
		money_label.text = "Cash: $%.2f" % money
		feedback_label.text = "¡Perfecto, muchas gracias!\nSale $%.2f - ingredients $%.2f" % [revenue, cost]
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
	CafeAssets.place(self, "Chalkboard menu wall sign 1", 0.9, Vector3(1.3, 1.2, -2.85))
	CafeAssets.place(self, "Plant tropical heart shaped", 1.0, Vector3(-1.6, 0, -2.5))
	CafeAssets.place(self, "Plant long leaves", 0.9, Vector3(1.7, 0, -2.5))
	CafeAssets.place(self, "Ceiling Light A", 0.35, Vector3(0, 2.6, -1.0))
	CafeAssets.place(self, "Round table beige", 0.75, Vector3(-1.4, 0, 0.8))
	CafeAssets.place(self, "Round chair 1 beige", 0.5, Vector3(-1.4, 0, 1.3))

	$CustomerPlaceholder.visible = false
	$Floor/Mesh.visible = false
	CafeRoom.build(self, CUSTOMER_Z)
