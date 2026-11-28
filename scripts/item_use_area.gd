extends Node3D

@export var required_items: Array[String] = ["gas","oil","sparkPlug"]
var used_items: Array[String] = []
signal used_item(item_name: String)
signal all_items_used



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _next_usable_item(player) -> String:
	for item in required_items:
		if not used_items.has(item) and player.inventory.has(item):
			return item
	return ""


func can_interact(player) -> bool:
	return _next_usable_item(player) != ""
	

func get_prompt(player) -> String:
	if used_items.size() == required_items.size():
		return ""                                  # finished, no prompt
	var item = _next_usable_item(player)
	if item != "":
		return "Hold E to use " + item
	# list what's still missing
	var missing = required_items.filter(func(i): return not used_items.has(i))
	return "Requires " + ", ".join(missing)
	


func interaction(player) -> void:
	var item = _next_usable_item(player)
	if item == "":
		return
	player.remove_item(item)
	used_items.append(item)
	used_item.emit(item)
	if used_items.size() == required_items.size():
		all_items_used.emit()
