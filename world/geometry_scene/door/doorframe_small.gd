
@tool
extends Node3D

@export var open: bool = false:
	set(value):
		open = value
		if is_node_ready():
			update_door()

@export var animation_speed: float = 1.0

var door_tween: Tween

func _ready() -> void:
	update_door(true)


func update_door(instant: bool = false) -> void:
	if open:
		open_door(instant)
	else:
		close_door(instant)


func open_door(instant: bool = false) -> void:
	animate_door(-135.0, 135.0, instant)


func close_door(instant: bool = false) -> void:
	animate_door(0.0, 0.0, instant)


func animate_door(left_angle: float, right_angle: float, instant: bool) -> void:
	if not is_node_ready():
		return

	if door_tween and door_tween.is_running():
		door_tween.kill()

	if instant:
		%Door_small.rotation_degrees.y = left_angle
		%Door_small_R.rotation_degrees.y = right_angle
		return

	door_tween = create_tween()
	door_tween.set_parallel(true)

	door_tween.tween_property(
		%Door_small,
		"rotation_degrees:y",
		left_angle,
		animation_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	door_tween.tween_property(
		%Door_small_R,
		"rotation_degrees:y",
		right_angle,
		animation_speed
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
