# Player.gd - Complete Goblin script with Hit animation
extends CharacterBody2D
class_name Player

# Movement variables
@export var speed = 200.0
@export var jump_velocity = -400.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Combat variables
@export var max_health: float = 100.0
@export var current_health: float
@export var attack_damage: float = 25.0
var can_attack: bool = true
var is_attacking: bool = false
var is_taking_damage: bool = false  # New variable to track hit animation
var damage_immunity_time: float = 1.0  # Immunity duration after taking damage
var immunity_timer: float = 0.0  # Current immunity timer

# Node references
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackCooldownTimer
@onready var hit_timer: Timer = $HitTimer  # Timer for hit animation duration

# Signals
signal health_changed(new_health: float)
signal died
signal attack_performed

func _ready():
	current_health = max_health
	
	# Setup animated sprite
	if animated_sprite:
		animated_sprite.play("Idle")
	
	# Setup attack area
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
	
	# Setup attack timer
	if attack_timer:
		attack_timer.wait_time = 0.5  # Attack cooldown
		attack_timer.timeout.connect(_on_attack_cooldown_finished)
	
	# Setup hit timer (create if doesn't exist)
	if not hit_timer:
		hit_timer = Timer.new()
		add_child(hit_timer)
		hit_timer.wait_time = 0.5  # Hit animation duration
		hit_timer.one_shot = true
		hit_timer.timeout.connect(_on_hit_animation_finished)
	
	# Set collision layers
	collision_layer = 2  # Player layer
	collision_mask = 1   # World layer

func _physics_process(delta):
	# Update immunity timer
	if immunity_timer > 0:
		immunity_timer -= delta
		# Flash effect during immunity
		modulate.a = 0.5 + sin(immunity_timer * 20) * 0.3
		if immunity_timer <= 0:
			modulate = Color.WHITE
	
	# Don't process movement during hit animation (but allow reduced movement)
	if is_taking_damage:
		# Apply gravity and basic physics even during hit
		if not is_on_floor():
			velocity.y += gravity * delta
		velocity.x = move_toward(velocity.x, 0, speed * delta * 2)  # Slow down
		move_and_slide()
		return
	
	# Handle input and movement
	handle_input()
	handle_movement(delta)
	handle_animation()
	
	# Move the character
	move_and_slide()

func handle_input():
	# Attack input (allow attacking unless in hit animation)
	if Input.is_action_just_pressed("attack") and can_attack and not is_attacking and not is_taking_damage:
		perform_attack()

func handle_movement(delta):
	# Add gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity
	
	# Handle horizontal movement
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0:
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

func handle_animation():
	if not animated_sprite:
		return
	
	# Don't change animation during attack or hit
	if is_attacking or is_taking_damage:
		return
	
	# Flip sprite based on movement direction
	if velocity.x > 0:
		animated_sprite.flip_h = false
	elif velocity.x < 0:
		animated_sprite.flip_h = true
	
	# Play appropriate animation
	if is_on_floor():
		if abs(velocity.x) > 0.1:
			animated_sprite.play("Walk")
		else:
			animated_sprite.play("Idle")
	else:
		animated_sprite.play("Jump")

func perform_attack():
	if not can_attack or is_attacking or is_taking_damage:
		return
	
	is_attacking = true
	can_attack = false
	
	# Play attack animation
	if animated_sprite:
		animated_sprite.play("Attack")
	
	# Emit signal
	attack_performed.emit()
	
	# Wait a moment then check for hits
	await get_tree().create_timer(0.2).timeout
	
	# Deal damage to overlapping enemies
	if attack_area:
		var bodies = attack_area.get_overlapping_bodies()
		for body in bodies:
			if body is Boss:
				body.take_damage(attack_damage)
				print("Player hit boss for ", attack_damage, " damage")
	
	# Start cooldown
	if attack_timer:
		attack_timer.start()
	else:
		# Fallback cooldown
		await get_tree().create_timer(0.5).timeout
		_on_attack_cooldown_finished()

func take_damage(damage: float):
	# Check immunity - prevent stunlocking
	if immunity_timer > 0:
		print("Player is immune to damage!")
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	
	# Start immunity period
	immunity_timer = damage_immunity_time
	
	# Start hit animation sequence
	is_taking_damage = true
	
	# Play hit animation
	if animated_sprite:
		animated_sprite.play("Hit")
	
	# Visual feedback - red flash (will be overridden by immunity flashing)
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	# Emit signal
	health_changed.emit(current_health)
	
	# Start hit timer
	if hit_timer:
		hit_timer.start()
	else:
		# Fallback
		await get_tree().create_timer(0.5).timeout
		_on_hit_animation_finished()
	
	print("Player took ", damage, " damage. Health: ", current_health)
	
	# Check if dead
	if current_health <= 0:
		die()

func die():
	print("Player died!")
	died.emit()
	
	# Play death animation or hit animation
	if animated_sprite:
		animated_sprite.play("Hit")  # Use hit animation if no death animation
	
	# Disable collision and movement
	collision_shape.set_deferred("disabled", true)
	set_physics_process(false)
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 1.0)

# Signal callbacks
func _on_attack_cooldown_finished():
	can_attack = true
	is_attacking = false

func _on_hit_animation_finished():
	is_taking_damage = false
	# Don't override immunity flashing with normal animation changes
	if immunity_timer <= 0:
		# Return to appropriate idle/movement animation
		if animated_sprite and not is_attacking:
			if is_on_floor():
				if abs(velocity.x) > 0.1:
					animated_sprite.play("Walk")
				else:
					animated_sprite.play("Idle")
			else:
				animated_sprite.play("Jump")

func _on_attack_area_entered(body):
	if body is Boss:
		print("Boss in attack range!")
