extends CustomEvent

var statue = load("res://src/structure/data/statue_of_grace.tres")

func _init():
	super._init("Sacred Glade", "This description is blank for now, sorry!")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func get_options():
	var nodes: Array[Node] = []
	var struct_display = ShopDisplay.instantiate()
	struct_display.set_data(statue)
	nodes.append(struct_display)
	
	var option1 = CustomEvent.Option.new("Bring the statue back to your farm",\
	nodes_preview("Gain Structure: Statue of Grace", nodes), func():
		user_interface._on_shop_on_structure_place(statue, func(): pass)
		user_interface.CancelStructure.visible = false
	)
	var option2 = CustomEvent.Option.new("Clean the statue and leave a gift basket", text_preview("Gain a Blessing"), func():
		user_interface.pick_blessing("Pick a blessing to gain", [])
	)
	return [option1, option2]

func check_prerequisites():
	return turn_manager.blight_damage == 0 and turn_manager.year > 2
