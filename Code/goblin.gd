extends CharacterBody2D

@export var speed = 200.0
@export var jump_velocity = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	animated_sprite.play("Idle")

func _physics_process(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle jump - using multiple keys for reliability
	if (Input.is_action_just_pressed("ui_accept") or 
		Input.is_key_pressed(KEY_SPACE) or 
		Input.is_key_pressed(KEY_W)) and is_on_floor():
		velocity.y = jump_velocity
	
	# Handle horizontal movement - using direct key checks as backup
	var direction = 0
	
	# Check for left movement
	if (Input.is_action_pressed("ui_left") or 
		Input.is_key_pressed(KEY_LEFT) or 
		Input.is_key_pressed(KEY_A)):
		direction -= 1
	
	# Check for right movement  
	if (Input.is_action_pressed("ui_right") or 
		Input.is_key_pressed(KEY_RIGHT) or 
		Input.is_key_pressed(KEY_D)):
		direction += 1
	
	# Apply movement
	if direction != 0:
		velocity.x = direction * speed
		
		# Flip sprite for left/right movement
		if direction > 0:
			animated_sprite.flip_h = false  # Facing right
		elif direction < 0:
			animated_sprite.flip_h = true   # Facing left
		
		# Play walk animation only if on ground
		if is_on_floor() and animated_sprite.animation != "Walk":
			animated_sprite.play("Walk")
	else:
		# Stop horizontal movement
		velocity.x = move_toward(velocity.x, 0, speed)
	
	# Handle animation states
	if not is_on_floor():
		# In air - play jump animation
		if animated_sprite.animation != "jump":
			animated_sprite.play("jump")
	elif direction == 0:
		# On ground and not moving - play idle
		if animated_sprite.animation != "Idle":
			animated_sprite.play("Idle")
	
	move_and_slide()
	
	# Debug print to check if script is working
	if direction != 0:
		print("Moving direction: ", direction, " Velocity: ", velocity)
