# Boss.gd - Complete fixed script
extends CharacterBody2D
class_name Boss

# Signals
signal died
signal health_changed(new_health: float)
signal checkpoint_reached(checkpoint_health: float)

enum BossState {
	IDLE,
	CHASING,
	ATTACKING,
	DEAD
}

# Movement variables
@export var speed: float = 120.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Combat variables
@export var max_health: float = 200.0
@export var current_health: float
@export var attack_damage: float = 25.0
@export var attack_range: float = 50.0  # Much smaller melee range
@export var collision_damage: float = 15.0  # Reduced collision damage
@export var attack_cooldown: float = 3.0   # Longer cooldown between attacks
@export var attack_delay: float = 1.0      # Time before dealing damage (for animation)

# AI variables
@export var chase_range: float = 300.0
@export var detection_range: float = 400.0

# State variables
var current_state: BossState = BossState.IDLE
var is_alive: bool = true
var player_reference: CharacterBody2D

# Timers
var attack_timer: float = 0.0
var state_timer: float = 0.0
var immunity_timer: float = 0.0
var immunity_duration: float = 0.5

# Health checkpoints (for boss scaling)
var health_checkpoints: Array[float] = [0.8, 0.6, 0.4, 0.2]
var triggered_checkpoints: Array[bool] = [false, false, false, false]

# Scaling variables
var strength_multiplier: float = 1.0
var deaths_count: int = 0

# Components
@onready var animated_sprite = $AnimatedSprite2D

func _ready():
	# Set initial health
	current_health = max_health
	
	# Add to boss group for easy reference
	add_to_group("boss")
	
	# Set up collision layers properly
	collision_layer = 2     # Boss is on layer 2
	collision_mask = 7      # Collide with player (1) + boss (2) + environment (3) = 7
	
	# Find player reference
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player_reference = players[0]
	
	# Emit initial health signal
	health_changed.emit(current_health)
	
	print("Boss initialized with health: ", current_health)

func _physics_process(delta):
	if not is_alive:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Handle timers
	if attack_timer > 0:
		attack_timer -= delta
	
	if state_timer > 0:
		state_timer -= delta
	
	if immunity_timer > 0:
		immunity_timer -= delta
	
	# Handle AI state machine
	handle_ai_state(delta)
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Move and check collisions
	move_and_slide()
	check_player_collision()

func handle_ai_state(_delta):
	match current_state:
		BossState.IDLE:
			handle_idle_state(_delta)
		BossState.CHASING:
			handle_chasing_state(_delta)
		BossState.ATTACKING:
			handle_attacking_state(_delta)

func handle_idle_state(_delta):
	velocity.x = 0
	
	if not player_reference:
		# Try to find player again
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player_reference = players[0]
		return
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	
	# Start chasing if player is in detection range
	if distance_to_player <= detection_range:
		current_state = BossState.CHASING
		print("Boss detected player, switching to CHASING")

func handle_chasing_state(_delta):
	if not player_reference:
		current_state = BossState.IDLE
		return
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	
	# Check if close enough to attack
	if distance_to_player <= attack_range and attack_timer <= 0:
		current_state = BossState.ATTACKING
		attack_timer = attack_delay  # Start attack delay
		velocity.x = 0  # Stop moving
		print("Boss starting attack sequence")
		return
	
	# Stop chasing if player is too far away
	if distance_to_player > chase_range:
		current_state = BossState.IDLE
		velocity.x = 0
		return
	
	# Move towards player
	var direction = sign(player_reference.global_position.x - global_position.x)
	velocity.x = direction * speed * strength_multiplier
	
	# Flip sprite
	if animated_sprite:
		animated_sprite.flip_h = direction < 0

func handle_attacking_state(_delta):
	# Stay still during attack
	velocity.x = 0
	
	# Check if attack delay is over (let animation play)
	if attack_timer <= 0 and player_reference:
		# Deal damage if player is still in melee range
		var distance_to_player = global_position.distance_to(player_reference.global_position)
		if distance_to_player <= attack_range:
			if player_reference.has_method("take_damage"):
				print("Boss deals attack damage: ", attack_damage * strength_multiplier)
				player_reference.take_damage(attack_damage * strength_multiplier)
		
		# Set cooldown and return to chasing
		attack_timer = attack_cooldown
		current_state = BossState.CHASING
		print("Boss attack completed, cooldown started")

func check_player_collision():
	# Only deal collision damage if not currently attacking (to avoid double damage)
	if current_state == BossState.ATTACKING:
		return
	
	# Check collision results from move_and_slide()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		if collider and collider.is_in_group("player"):
			# Boss collided with player - deal collision damage
			if collider.has_method("take_damage"):
				print("Boss collision damage: ", collision_damage * strength_multiplier)
				collider.take_damage(collision_damage * strength_multiplier)
				break

func take_damage(damage: float):
	if not is_alive:
		return
	
	# Check immunity
	if immunity_timer > 0:
		print("Boss is immune to damage!")
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	
	print("Boss took ", damage, " damage! Health: ", current_health, "/", max_health)
	
	# Set immunity timer
	immunity_timer = immunity_duration
	
	# Emit health changed signal
	health_changed.emit(current_health)
	
	# Check health checkpoints
	check_health_checkpoints()
	
	# Check if dead
	if current_health <= 0:
		die()

func check_health_checkpoints():
	var health_percentage = current_health / max_health
	
	for i in range(health_checkpoints.size()):
		if not triggered_checkpoints[i] and health_percentage <= health_checkpoints[i]:
			triggered_checkpoints[i] = true
			var checkpoint_health = health_checkpoints[i] * max_health
			checkpoint_reached.emit(checkpoint_health)
			print("Boss reached health checkpoint: ", health_percentage * 100, "%")

func die():
	if not is_alive:
		return
	
	print("Boss died!")
	is_alive = false
	current_state = BossState.DEAD
	
	# Stop all movement
	velocity = Vector2.ZERO
	
	# Disable collision with player
	set_collision_mask_value(1, false)
	
	# Emit death signal
	died.emit()

func make_stronger(player_deaths: int = 0):
	# Use the passed death count or increment our own
	if player_deaths > 0:
		deaths_count = player_deaths
	else:
		deaths_count += 1
	
	strength_multiplier = 1.0 + (deaths_count * 0.2)  # 20% stronger per death
	max_health = 200.0 * (1.0 + deaths_count * 0.1)  # 10% more health per death
	current_health = max_health
	
	print("Boss got stronger! Deaths: ", deaths_count, " Multiplier: ", strength_multiplier, " Health: ", max_health)
	
	# Reset for respawn
	is_alive = true
	current_state = BossState.IDLE
	
	# Reset checkpoints
	triggered_checkpoints = [false, false, false, false]
	
	# Re-enable collision
	set_collision_mask_value(1, true)
	
	# Emit health signal
	health_changed.emit(current_health)

func handle_animations():
	if not animated_sprite:
		return
	
	match current_state:
		BossState.DEAD:
			animated_sprite.play("Death")
		BossState.ATTACKING:
			animated_sprite.play("Attack")
		BossState.CHASING:
			if abs(velocity.x) > 0:
				animated_sprite.play("Run")
			else:
				animated_sprite.play("Idle")
		BossState.IDLE:
			animated_sprite.play("Idle")
