# GameManager.gd - Fixed ternary operator warnings
extends Node

# Game state
var player_points: int = 0
var deaths: int = 0
var boss_defeated: bool = false

# References
var player: Player
var boss: Boss

# Boss checkpoint tracking
var checkpoints_reached: Array[bool] = [false, false, false, false]  # 80%, 60%, 40%, 20%

# UI References
@onready var points_label: Label = $UI/PointsLabel
@onready var death_counter: Label = $UI/DeathCounter
@onready var upgrade_panel: Control = $UI/UpgradePanel

func _ready():
	# Find player and boss
	await get_tree().process_frame  # Wait one frame for nodes to be ready
	
	player = get_tree().get_first_node_in_group("player")
	boss = get_tree().get_first_node_in_group("boss")
	
	if player:
		player.died.connect(_on_player_died)
		player.health_changed.connect(_on_player_health_changed)
		print("Player connected to GameManager")
	else:
		print("WARNING: Player not found!")
	
	if boss:
		boss.died.connect(_on_boss_died)
		boss.health_changed.connect(_on_boss_health_changed)
		boss.checkpoint_reached.connect(_on_boss_checkpoint_reached)
		print("Boss connected to GameManager")
	else:
		print("WARNING: Boss not found!")
	
	update_ui()

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Enter key
		if boss_defeated:
			restart_game()

func award_points(amount: int):
	player_points += amount
	print("Points awarded: ", amount, " Total: ", player_points)
	update_ui()

func _on_player_died():
	deaths += 1
	print("Player died! Deaths: ", deaths)
	
	# Reset boss checkpoints
	checkpoints_reached = [false, false, false, false]
	
	# Make boss stronger
	if boss:
		boss.make_stronger(deaths)
	
	# Show upgrade options
	show_upgrade_options()
	
	# Respawn player after a delay
	await get_tree().create_timer(2.0).timeout
	respawn_player()

func _on_boss_died():
	boss_defeated = true
	award_points(10)  # Big bonus for defeating boss
	print("Boss defeated! You win!")
	
	# Show victory message
	if points_label:
		points_label.text = "VICTORY! Points: " + str(player_points) + "\nPress Enter to restart"

func _on_player_health_changed(new_health: float):
	print("Player health: ", new_health)

func _on_boss_health_changed(new_health: float):
	print("Boss health: ", new_health)
	
	# Check for health checkpoints (80%, 60%, 40%, 20%)
	if boss:
		var health_percentage = new_health / boss.max_health
		
		if not checkpoints_reached[0] and health_percentage <= 0.8:
			checkpoints_reached[0] = true
			award_points(1)
		elif not checkpoints_reached[1] and health_percentage <= 0.6:
			checkpoints_reached[1] = true
			award_points(1)
		elif not checkpoints_reached[2] and health_percentage <= 0.4:
			checkpoints_reached[2] = true
			award_points(2)
		elif not checkpoints_reached[3] and health_percentage <= 0.2:
			checkpoints_reached[3] = true
			award_points(2)

func _on_boss_checkpoint_reached(checkpoint_health: float):
	print("Boss checkpoint reached at health: ", checkpoint_health)
	award_points(1)

func respawn_player():
	if player:
		# Reset player to spawn position
		player.global_position = Vector2(100, 400)  # Adjust as needed
		player.current_health = player.max_health
		player.health_changed.emit(player.current_health)
		
		# Re-enable player
		player.collision_shape.disabled = false
		player.set_physics_process(true)
		player.modulate = Color.WHITE
		
		print("Player respawned")
	
	update_ui()

func show_upgrade_options():
	print("=== UPGRADE SHOP ===")
	print("Points available: ", player_points)
	print("Choose upgrades (auto-applied for now):")
	
	# Auto-apply upgrades for testing
	apply_auto_upgrades()

func apply_auto_upgrades():
	if not player:
		return
	
	# Spend points on upgrades
	var points_to_spend = min(player_points, 5)  # Spend up to 5 points
	
	if points_to_spend > 0:
		# FIXED: Ensure both sides of ternary return same type (float)
		player.max_health += float(points_to_spend * 10.0)  # +10 health per point
		player.attack_damage += float(points_to_spend * 2.0)  # +2 damage per point
		
		player.current_health = player.max_health  # Full heal
		player_points -= points_to_spend
		
		print("Upgrades applied! Health: ", player.max_health, " Damage: ", player.attack_damage)

func restart_game():
	# Reset game state
	player_points = 0
	deaths = 0
	boss_defeated = false
	checkpoints_reached = [false, false, false, false]
	
	# Reload the scene
	get_tree().reload_current_scene()

func update_ui():
	if points_label:
		# FIXED: Ensure consistent string types
		points_label.text = "Points: " + str(player_points)
	
	if death_counter:
		death_counter.text = "Deaths: " + str(deaths)
