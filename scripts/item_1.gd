extends Node3D

@export var item_name: String = "gas"



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func can_interact(player) -> bool:
	return true

func get_prompt(player) -> String:
	return "Hold E to pick up " + item_name

func interaction(player: Node):
	player.pick_up_item(item_name)
	player.hide_label()
	queue_free()
