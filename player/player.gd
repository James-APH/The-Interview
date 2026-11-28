extends CharacterBody3D
# This is still heavily work in progress, I need to adjust a couple things
# and add one more function
# feel free to mess with constants, they are pretty self explanatory


const SPEED = 6.5               # max walking speed
const SHIFT_SPEED = 3.0         # max sneak walking speed(hold shift)
const JUMP = 4.25                # jump velocity (impulse)
const ACCELERATION = 60.0       # ground acceleration
const FRICTION = 8.0            # ground friction applied after grace period ends
								# determines how quickly you slow down
const SENSITIVITY = 0.1         # mouse sensitivity - probably shouldn't be a const tbh
const FRICTION_FLOOR = 1.5      # when below this speed, friction acts as if
								# you're at this speed, helps the player stop smoothly
								# fixes slidy movement
const JUMP_BUFFER_CONST = 0.1   # buffer for jump input before actually landing
								# allows for player to press jump before landing
								# and still jump upon landing- helps Bunny hopping
const FRICTION_GRACE = 0.04     # Grace period where friction is not applied after landing
								# after a successful bunnyhop you keep your speed
const AIR_SPEED_CAP = 1.2       # NOT MAXIMUM AIR SPEED - this is the maximum speed
								# you can gain in a single direction while air strafing
								# (holding A or D and moving mouse left/right respectively)
const AIR_ACCELERATION = 80     # how fast you reach air speed cap

var ground_time = 0.0           # how long you've spent on the ground
var jump_buffer_calc = 0.0		# time left on a buffered jump press: 0 = no jump
var speed_cap = 0.0				# used to set ground speed, walk or sneak
var target = null

# captures the mouse for aim movement
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	$Label.hide()


func _unhandled_input(event):
	if event is InputEventMouseMotion:
		#horizontal mouse movement
		self.rotation_degrees.y -= event.relative.x * SENSITIVITY
		#vertical mouse movement, clamped to 60 degrees up and down
		$Camera3D.rotation_degrees.x -= event.relative.y * SENSITIVITY
		$Camera3D.rotation_degrees.x = clamp($Camera3D.rotation_degrees.x,-60.0,60.0)
	# release mouse when pressing escape
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta) :
	#Read input keys as 2d vector, turn into 3d vector and rotate to match player direction
		var input_direction_2D = Input.get_vector("left","right","forward","backward")
		var input_dirtection_3D = Vector3(input_direction_2D.x,0.0,input_direction_2D.y)
		var direction = (transform.basis * input_dirtection_3D).normalized()

	# when jump is pressed, set buffer time
	# when jump is not pressed, count down the buffer time down to 0
		if Input.is_action_just_pressed("jump"):
			jump_buffer_calc = JUMP_BUFFER_CONST
		else:
			jump_buffer_calc = max(jump_buffer_calc - delta , 0.0)


		if is_on_floor():
			# counting the time spent on the ground
			ground_time += delta
			# if jump has been queued, jump when touching the ground
			if jump_buffer_calc > 0.0:
				velocity.y = JUMP
				jump_buffer_calc = 0.0
			else:
				# if grace period has ended, apply friction
				if ground_time > FRICTION_GRACE:
					# 20% speed penalty for failing a bunny hop
					# This is done to slow you down quicker when you have lots of speed
					# and add a downside to unsuccessful movement
					# I'm open to removing this, but I believe it feels better this way
					if ground_time- delta <= FRICTION_GRACE:
						velocity.x *= 0.8
						velocity.z *= 0.8
					_apply_friction(delta)
				#choosing between sneak speed and walk speed
				if Input.is_action_pressed("shift"):
					speed_cap = SHIFT_SPEED
				else:
					speed_cap = SPEED
				# ground acceleration applied
				_apply_acceleratation(direction,speed_cap,ACCELERATION,delta)

		#when not on floor ( I.E in air)
		else:
			# reset ground time and apply air acceleration, no friction is applied
			ground_time = 0.0
			_apply_acceleratation(direction,AIR_SPEED_CAP,AIR_ACCELERATION,delta)
		velocity += get_gravity() * delta
		move_and_slide()
		_handle_interact(delta)

		if $%RayCast3D.is_colliding():
			var target = ray.get_collider()
			if is_instance_valid(target):
				if (target.has_method("interaction") or target.get_parent().has_method("interaction")):
					$Label.show()
				else:
					hide_label()
		else: hide_label()

# increases speed in a direction up to a cap
# because you are sped up in one direction but others are unaffected
# your overall speed which is the length of the velocity
# in each direction can climb past the speed cap when turning in the air
# this is how air strafing works.  hold only one input key and turn the mouse into that direction
func _apply_acceleratation(direction: Vector3, speed_cap: float, accel: float, delta: float):
	# current speed in the specific direction you're pressing
	var current_speed := velocity.dot(direction)
	# how much more speed you are allowed to gain in that direction
	var add_speed := speed_cap - current_speed
	if add_speed <= 0.0:
		return
	# accelerate in the direction, limited to how much you're allowed to gain
	velocity += direction *  min(accel * delta, add_speed)

# slowing down X and Z ( horizontal ) movement
func _apply_friction(delta: float) -> void:
	var current_speed := Vector2(velocity.x, velocity.z).length()
	# when moving at 0.01 or less, stop completely
	if current_speed < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	# taking the highest of actual speed vs the friction floor( GO see CONST section)
	var control: float = max(current_speed, FRICTION_FLOOR )
	# calculate speed bleed off and apply it to both x and z axis to maintain
	# player movement direction
	var new_speed: float = max(current_speed - control * FRICTION * delta, 0.0)
	var speed_scaling := new_speed / current_speed
	velocity.x *= speed_scaling
	velocity.z *= speed_scaling





var inventory: Array[String] = []
@onready var ray: RayCast3D = %RayCast3D
const HOLD_TIME = 5.0
var hold_progress = 0.0
var hold_target = null
var hold_locked = false

func _get_item() -> Node:
	if not ray.is_colliding():
		return null
	var target = ray.get_collider()
	if not is_instance_valid(target):
		return null
	if target.has_method("interaction"):
		return target
	if target.get_parent().has_method("interaction"):
		return target.get_parent()
	return null


func _handle_interact(delta: float) -> void:
	var target = _get_item()
	if target == null or target.get_prompt(self) == "":
		$Label.hide()
		hold_progress = 0.0
		hold_target = null
		return

	$Label.show()
	$Label.text = target.get_prompt(self)

	#missing item, already used or E not held, reset
	if not target.can_interact(self) or not Input.is_action_pressed("interact"):
		hold_progress = 0.0
		if not Input.is_action_pressed("interact"):
			hold_locked = false
		return
	if hold_locked:
		return

	if target != hold_target:
		hold_progress = 0.0
		hold_target = target

	hold_progress += delta
	$Label.text += "  %.1f" % max(HOLD_TIME - hold_progress, 0.0)

	if hold_progress >= HOLD_TIME:
		target.interaction(self)
		hold_progress = 0.0
		hold_target = null
		hold_locked = true


func hide_label():
	$Label.hide()


func pick_up_item(item_name: String):
	inventory.append(item_name)
	print("Inventory: ", inventory)
