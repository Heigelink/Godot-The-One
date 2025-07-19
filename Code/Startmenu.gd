# StartMenu.gd
extends Control

# Called when the node enters the scene tree for the first time
func _ready():
	# Only start menu music if it's not already playing
	if not MusicManager.is_music_playing():
		MusicManager.play_menu_music()
	else:
		# Ensure the music continues properly after scene change
		MusicManager.restore_music_state()
	
	# Find buttons by name (more flexible)
	var start_btn = find_child("Start")
	var settings_btn = find_child("Options") 
	var quit_btn = find_child("Quit")
	
	# Connect signals if buttons exist
	if start_btn:
		start_btn.pressed.connect(_on_start_button_pressed)
		start_btn.grab_focus()
	
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_button_pressed)
	
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_button_pressed)
	
	print("StartMenu ready! Found buttons: ", start_btn != null, settings_btn != null, quit_btn != null)

# Start the game
func _on_start_button_pressed():
	print("Starting game...")
	# Stop the music before going to game scene
	MusicManager.stop_all_music()
	# Replace "res://GameScene.tscn" with your actual game scene path
	get_tree().change_scene_to_file("res://scenes/game.tscn")

# Open settings menu
func _on_settings_button_pressed():
	print("Opening settings...")
	# Keep music playing when going to settings - don't stop it
	# Replace "res://SettingsMenu.tscn" with your settings scene path
	get_tree().change_scene_to_file("res://scenes/Settings.tscn")

# Quit the game
func _on_quit_button_pressed():
	print("Quitting game...")
	# Stop the music before quitting
	MusicManager.stop_all_music()
	get_tree().quit()

# Handle ESC key to quit (optional)
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		MusicManager.stop_all_music()
		get_tree().quit()
