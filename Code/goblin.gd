# Player.gd - Complete fixed Goblin script
extends CharacterBody2D
class_name Player

# Signals
signal died
signal health_changed(new_health: float)

# Movement variables
@export var speed = 200.0
@export var jump_velocity = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Combat variables
@export var max_health: float = 100.0
@export var current_health: float
@export var attack_damage: float = 25.0
@export var attack_range: float = 80.0

# State flags
var is_alive: bool = true
var is_taking_damage: bool = false
var is_attacking: bool = false
var can_attack: bool = true

# Timers
var immunity_timer: float = 0.0
var immunity_duration: float = 1.5
var hit_timer: float = 0.0
var hit_duration: float = 0.5
var attack_timer: float = 0.0
var attack_duration: float = 0.6

# Components
@onready var animated_sprite = $AnimatedSprite2D
var player_reference: CharacterBody2D

func _ready():
	# Set initial health
	current_health = max_health
	
	# Add to player group for easy reference
	add_to_group("player")
	
	# Set up collision layers
	collision_layer = 1     # Player is on layer 1
	collision_mask = 6      # Collide with boss (2) + environment (3) = 4+2 = 6
	
	# Emit initial health signal
	health_changed.emit(current_health)
	
	print("Player initialized with health: ", current_health)

func _physics_process(delta):
	# Don't process physics if dead
	if not is_alive:
		velocity.y += gravity * delta  # Still apply gravity when dead
		move_and_slide()
		return
	
	# Handle timers
	if immunity_timer > 0:
		immunity_timer -= delta
	
	if hit_timer > 0:
		hit_timer -= delta
		if hit_timer <= 0:
			is_taking_damage = false
	
	if attack_timer > 0:
		attack_timer -= delta
		if attack_timer <= 0:
			is_attacking = false
			can_attack = true
	
	# Handle input and movement
	handle_input()
	handle_movement(delta)
	handle_animations()

func handle_input():
	# Don't allow input if taking damage or attacking
	if is_taking_damage or is_attacking:
		return
	
	# Attack input
	if Input.is_action_just_pressed("attack") and can_attack and is_on_floor():
		attack()

func handle_movement(delta):
	# Don't move if taking damage or attacking
	if is_taking_damage or is_attacking:
		velocity.x = 0
	else:
		# Horizontal movement
		var direction = Input.get_axis("move_left", "move_right")
		if direction != 0:
			velocity.x = direction * speed
			# Flip sprite based on direction
			if animated_sprite:
				animated_sprite.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
		
		# Jump
		if Input.is_action_just_pressed("move_up") and is_on_floor():
			velocity.y = jump_velocity
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Move and check for collisions
	move_and_slide()
	check_boss_collision()

func attack():
	if not can_attack or is_attacking or is_taking_damage:
		return
	
	print("Player attacking!")
	is_attacking = true
	can_attack = false
	attack_timer = attack_duration
	
	# Check for bosses in attack range
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + Vector2(attack_range * (1 if not animated_sprite.flip_h else -1), 0)
	)
	query.collision_mask = 2  # Only check boss layer
	
	var result = space_state.intersect_ray(query)
	if result:
		var target = result.collider
		if target.has_method("take_damage"):
			print("Player hit boss for ", attack_damage, " damage!")
			target.take_damage(attack_damage)
	
	# Also check for overlapping bodies
	var bodies = []
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("boss"):
			bodies.append(collider)
	
	# Attack any overlapping bosses
	for body in bodies:
		if body.has_method("take_damage") and global_position.distance_to(body.global_position) <= attack_range:
			print("Player melee hit boss for ", attack_damage, " damage!")
			body.take_damage(attack_damage)

func check_boss_collision():
	# Only deal collision damage if not attacking (to avoid double damage)
	if is_attacking:
		return
	
	# Check collision results from move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("boss"):
			# Boss touched player - player takes damage
			if immunity_timer <= 0:
				take_damage(15.0)  # Boss collision damage
				break

func take_damage(damage: float):
	# Don't take damage if dead
	if not is_alive:
		return
	
	# Check immunity - prevent stunlocking
	if immunity_timer > 0:
		print("Player is immune to damage!")
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	
	print("Player took ", damage, " damage! Health: ", current_health)
	
	# Emit health changed signal
	health_changed.emit(current_health)
	
	# Set hit state
	is_taking_damage = true
	hit_timer = hit_duration
	immunity_timer = immunity_duration
	
	# Check if dead
	if current_health <= 0:
		die()

func die():
	if not is_alive:
		return
		
	print("Player died!")
	is_alive = false
	is_taking_damage = false
	is_attacking = false
	
	# Disable collision
	set_collision_mask_value(1, false)  # Don't collide with player layer
	set_collision_mask_value(2, false)  # Don't collide with boss layer
	
	died.emit()

func respawn():
	print("Player respawning!")
	
	# Reset all states
	is_alive = true
	is_taking_damage = false
	is_attacking = false
	can_attack = true
	
	# Reset timers
	immunity_timer = 0.0
	hit_timer = 0.0
	attack_timer = 0.0
	
	# Reset health
	current_health = max_health
	health_changed.emit(current_health)
	
	# Reset velocity
	velocity = Vector2.ZERO
	
	# Re-enable collision
	set_collision_mask_value(1, true)   # Collide with player layer
	set_collision_mask_value(2, true)   # Collide with boss layer
	
	print("Player respawned with health: ", current_health)

func handle_animations():
	if not animated_sprite:
		return
	
	if not is_alive:
		animated_sprite.play("Death")
	elif is_taking_damage:
		animated_sprite.play("Hit")
	elif is_attacking:
		animated_sprite.play("Attack")
	elif not is_on_floor():
		if velocity.y < 0:
			animated_sprite.play("Jump")

	elif abs(velocity.x) > 0:
		animated_sprite.play("Run")
	else:
		animated_sprite.play("Idle")
d
