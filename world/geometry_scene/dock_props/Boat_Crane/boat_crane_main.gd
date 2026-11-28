@tool
extends Node3D

@export_range(-180.0, 180.0, 0.1) var custom_rotation_y: float = 0.0:
	set(value):
		custom_rotation_y = value
		%Boat_Crane_Hook.rotation_degrees.y = custom_rotation_y
		
@export_range(-180.0, 180.0, 0.1) var custom_rotation_x: float = 0.0:
	set(value):
		custom_rotation_x = value
		%Boat_Crane_Hook.rotation_degrees.x = custom_rotation_x
		
@export_range(-180.0, 180.0, 0.1) var custom_rotation_z: float = 0.0:
	set(value):
		custom_rotation_z = value
		%Boat_Crane_Hook.rotation_degrees.z = custom_rotation_z	
