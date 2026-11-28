
@tool
extends Node3D

@export var open: bool = false:
	set(value):
		open = value
		if is_node_ready():
			update_door()

@export var animation_speed: float = 2.5

var door_tween: Tween

func _ready() -> void:
	update_door(true)


func update_door(instant: bool = false) -> void:
	if open:
		open_door(instant)
	else:
		close_door(instant)


func open_door(instant: bool = false) -> void:
	animate_door(8.712, -0.793, instant)


func close_door(instant: bool = false) -> void:
	animate_door(6.842, 1.14, instant)


func animate_door(left_pos: float, right_pos: float, instant: bool) -> void:
	if not is_node_ready():
		return

	if door_tween and door_tween.is_running():
		door_tween.kill()

	if instant:
		%door_large2.position.x = left_pos
		%door_large.position.x = right_pos
		return

	door_tween = create_tween()
	door_tween.set_parallel(true)

	door_tween.tween_property(
		%door_large2,
		"position:x",
		left_pos,
		animation_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	door_tween.tween_property(
		%door_large,
		"position:x",
		right_pos,
		animation_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
