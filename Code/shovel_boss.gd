# Boss.gd - Fixed warnings
extends CharacterBody2D
class_name Boss

# Boss stats
@export var max_health: float = 500.0
@export var current_health: float
@export var move_speed: float = 150.0
@export var jump_force: float = -300.0
@export var attack_damage: float = 20.0
@export var detection_range: float = 400.0
@export var attack_range: float = 80.0

# Combat variables
var can_attack: bool = true
var is_attacking: bool = false
var attack_cooldown: float = 2.0
var is_on_ground: bool = false

# AI State
enum BossState { IDLE, CHASING, ATTACKING, STUNNED }
var current_state: BossState = BossState.IDLE
var player: Player = null

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = get_node_or_null("AttackArea")
@onready var attack_timer: Timer = get_node_or_null("AttackCooldownTimer")
@onready var detection_area: Area2D = get_node_or_null("DetectionArea")

# Signals
signal health_changed(new_health: float)
signal died
signal checkpoint_reached(checkpoint_health: float)

# Get gravity from the project settings to be synced with RigidBody nodes
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# Progression variables
var base_health: float = 500.0
var health_multiplier: float = 1.0

func _ready():
	# Set initial health
	current_health = max_health
	
	# Connect timer
	if attack_timer:
		attack_timer.wait_time = attack_cooldown
		attack_timer.timeout.connect(_on_attack_cooldown_finished)
	
	# Connect attack area
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
	
	# Connect detection area
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)
	
	# Find player directly if no detection area
	if not detection_area:
		player = get_tree().get_first_node_in_group("player")
		if player:
			print("Boss found player directly")
	
	# Set collision layers
	collision_layer = 4  # Boss layer
	collision_mask = 1   # World layer

func _physics_process(_delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * _delta
	else:
		is_on_ground = true
	
	# Handle AI and movement
	handle_ai()
	handle_movement(_delta)
	
	# Move the character
	move_and_slide()

# FIXED: Simplified AI that works without detection area
func handle_ai():
	# Find player if we don't have one
	if not player:
		player = get_tree().get_first_node_in_group("player")
		if not player:
			current_state = BossState.IDLE
			return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	match current_state:
		BossState.IDLE:
			if distance_to_player <= detection_range:
				current_state = BossState.CHASING
				print("Boss started chasing!")
		
		BossState.CHASING:
			if distance_to_player <= attack_range and can_attack:
				current_state = BossState.ATTACKING
				perform_attack()
			elif distance_to_player > detection_range * 1.2:  # Add some buffer
				current_state = BossState.IDLE
				print("Boss stopped chasing")
		
		BossState.ATTACKING:
			if not is_attacking:
				current_state = BossState.CHASING

func handle_movement(delta):
	if current_state == BossState.CHASING and player:
		var direction_to_player = sign(player.global_position.x - global_position.x)
		
		# Horizontal movement
		velocity.x = direction_to_player * move_speed
		
		# Jump if player is above and boss is on ground
		if player.global_position.y < global_position.y - 50 and is_on_ground and can_attack:
			velocity.y = jump_force
			is_on_ground = false
		
		# Update sprite direction
		if animated_sprite:
			animated_sprite.flip_h = direction_to_player < 0
			if not is_attacking:
				animated_sprite.play("walk")
	
	elif current_state == BossState.IDLE:
		# Gradually stop moving
		velocity.x = move_toward(velocity.x, 0, move_speed * delta)
		if animated_sprite and not is_attacking:
			animated_sprite.play("Idle")
	
	elif current_state == BossState.ATTACKING:
		# Continue moving during attack (reduced speed)
		if player:
			var direction_to_player = sign(player.global_position.x - global_position.x)
			velocity.x = direction_to_player * move_speed * 0.3  # 30% speed during attack

func perform_attack():
	if not can_attack or is_attacking:
		return
	
	is_attacking = true
	can_attack = false
	
	print("Boss attacking!")
	
	# Play attack animation
	if animated_sprite:
		animated_sprite.play("attack")
	
	# Wait a moment for attack animation to start, then deal damage
	await get_tree().create_timer(0.2).timeout
	
	# Deal damage to overlapping players (with or without attack area)
	if attack_area:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body is Player:
				body.take_damage(attack_damage)
				print("Boss hit player for ", attack_damage, " damage")
	else:
		# Fallback: damage player if close enough
		if player and global_position.distance_to(player.global_position) <= attack_range:
			player.take_damage(attack_damage)
			print("Boss hit player for ", attack_damage, " damage (direct hit)")
	
	# Start cooldown
	if attack_timer:
		attack_timer.start()
	else:
		# Fallback if no timer
		await get_tree().create_timer(attack_cooldown).timeout
		_on_attack_cooldown_finished()

func take_damage(damage: float):
	current_health -= damage
	current_health = max(0, current_health)
	
	# Emit signal
	health_changed.emit(current_health)
	
	# Visual feedback
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)
	
	# Check for checkpoints (every 20% of max health)
	var health_percentage = current_health / max_health
	if health_percentage <= 0.8 and health_percentage > 0.6:
		checkpoint_reached.emit(current_health)
	elif health_percentage <= 0.6 and health_percentage > 0.4:
		checkpoint_reached.emit(current_health)
	elif health_percentage <= 0.4 and health_percentage > 0.2:
		checkpoint_reached.emit(current_health)
	elif health_percentage <= 0.2 and health_percentage > 0:
		checkpoint_reached.emit(current_health)
	
	# Check if dead
	if current_health <= 0:
		die()

func die():
	print("Boss defeated!")
	died.emit()
	
	# Death animation
	if animated_sprite:
		animated_sprite.play("Death")
	
	# Disable collision and movement
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	
	# Optional: Remove after animation
	await get_tree().create_timer(2.0).timeout
	queue_free()

func make_stronger(death_count: int):
	# Increase health and damage based on how many times player died
	health_multiplier = 1.0 + (death_count * 0.3)  # 30% more health per death
	max_health = base_health * health_multiplier
	current_health = max_health
	attack_damage = 20.0 + (death_count * 5.0)     # +5 damage per death
	
	print("Boss got stronger! Health: ", max_health, " Damage: ", attack_damage)

# Signal connections
func _on_attack_cooldown_finished():
	can_attack = true
	is_attacking = false
	
	if animated_sprite and current_state != BossState.CHASING:
		animated_sprite.play("Idle")

func _on_attack_area_entered(body):
	if body is Player:
		print("Player in attack range!")

func _on_detection_area_entered(body):
	if body is Player:
		player = body
		current_state = BossState.CHASING
		print("Player detected!")

func _on_detection_area_exited(body):
	if body is Player:
		current_state = BossState.IDLE
		print("Player lost!")

# FIXED: Added underscore prefix since parameter isn't used
func _on_health_changed(_new_health: float):
	# This function exists for external signal connections
	# The actual health change logic is in take_damage()
	pass
