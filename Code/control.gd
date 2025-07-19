# SettingsMenu.gd
extends Control

# Called when the node enters the scene tree
func _ready():
	# Connect button signals
	$VBoxContainer/BackButton.pressed.connect(_on_back_button_pressed)
	
	# Connect slider signals for volume controls
	$VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value_changed.connect(_on_master_volume_changed)
	$VBoxContainer/SFXVolumeContainer/SFXVolumeSlider.value_changed.connect(_on_sfx_volume_changed)
	$VBoxContainer/MusicVolumeContainer/MusicVolumeSlider.value_changed.connect(_on_music_volume_changed)
	
	# Connect fullscreen checkbox
	$VBoxContainer/FullscreenContainer/FullscreenCheckbox.toggled.connect(_on_fullscreen_toggled)
	
	# Load saved settings
	_load_settings()
	
	# Focus the back button for keyboard navigation
	$VBoxContainer/BackButton.grab_focus()

# Go back to main menu
func _on_back_button_pressed():
	print("Returning to main menu...")
	get_tree().change_scene_to_file("res://scenes/StartMenu.tscn")

# Handle master volume change
func _on_master_volume_changed(value):
	print("Master volume changed to: ", value)
	# Convert slider value (0-100) to decibels (-80 to 0)
	var db_value = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), db_value)
	
	# Save setting
	_save_settings()

# Handle SFX volume change
func _on_sfx_volume_changed(value):
	print("SFX volume changed to: ", value)
	# You'll need to create an "SFX" audio bus in the Audio settings
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus != -1:
		var db_value = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(sfx_bus, db_value)
	
	_save_settings()

# Handle Music volume change
func _on_music_volume_changed(value):
	print("Music volume changed to: ", value)
	# You'll need to create a "Music" audio bus in the Audio settings
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus != -1:
		var db_value = linear_to_db(value / 100.0)
		AudioServer.set_bus_volume_db(music_bus, db_value)
	
	_save_settings()

# Handle fullscreen toggle - FIXED VERSION
func _on_fullscreen_toggled(pressed):
	print("Fullscreen toggled: ", pressed)
	
	# Add a small delay to ensure the toggle state is properly set
	await get_tree().process_frame
	
	if pressed:
		# Try different fullscreen modes if one doesn't work
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		# Alternative: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		print("Setting to fullscreen mode")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Setting to windowed mode")
	
	# Save after a brief delay to ensure the mode change is complete
	await get_tree().create_timer(0.1).timeout
	_save_settings()

# Save settings to file
func _save_settings():
	var config = ConfigFile.new()
	
	# Save volume settings
	config.set_value("audio", "master_volume", $VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value)
	config.set_value("audio", "sfx_volume", $VBoxContainer/SFXVolumeContainer/SFXVolumeSlider.value)
	config.set_value("audio", "music_volume", $VBoxContainer/MusicVolumeContainer/MusicVolumeSlider.value)
	
	# Save display settings - get current window mode instead of checkbox state
	var is_fullscreen = DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	config.set_value("display", "fullscreen", is_fullscreen)
	
	# Save to file
	config.save("user://settings.cfg")
	print("Settings saved - fullscreen: ", is_fullscreen)

# Load settings from file - IMPROVED VERSION
func _load_settings():
	var config = ConfigFile.new()
	
	# Load the config file
	if config.load("user://settings.cfg") != OK:
		print("No settings file found, using defaults")
		_set_default_display_settings()
		return
	
	# Load volume settings
	var master_vol = config.get_value("audio", "master_volume", 100)
	var sfx_vol = config.get_value("audio", "sfx_volume", 100)
	var music_vol = config.get_value("audio", "music_volume", 100)
	
	# Apply volume settings
	$VBoxContainer/MasterVolumeContainer/MasterVolumeSlider.value = master_vol
	$VBoxContainer/SFXVolumeContainer/SFXVolumeSlider.value = sfx_vol
	$VBoxContainer/MusicVolumeContainer/MusicVolumeSlider.value = music_vol
	
	# Load and apply display settings
	var fullscreen = config.get_value("display", "fullscreen", false)
	print("Loading fullscreen setting: ", fullscreen)
	
	# Set checkbox state WITHOUT triggering the signal
	$VBoxContainer/FullscreenContainer/FullscreenCheckbox.set_pressed_no_signal(fullscreen)
	
	# Apply display settings
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		print("Applied fullscreen mode from settings")
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		print("Applied windowed mode from settings")

# Set default display settings
func _set_default_display_settings():
	var current_mode = DisplayServer.window_get_mode()
	var is_fullscreen = current_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	$VBoxContainer/FullscreenContainer/FullscreenCheckbox.set_pressed_no_signal(is_fullscreen)

# Handle ESC key to go back
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()

# Alternative fullscreen toggle function if the above doesn't work
func _alternative_fullscreen_toggle(pressed):
	print("Alternative fullscreen toggle: ", pressed)
	
	if pressed:
		# Set to fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		
		# If that doesn't work, try regular fullscreen
		await get_tree().process_frame
		if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		# Return to windowed mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
		# Optionally restore previous window size
		# DisplayServer.window_set_size(Vector2i(1024, 600))  # Set your preferred default size
	
	_save_settings()
