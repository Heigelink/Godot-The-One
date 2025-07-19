# MusicManager.gd
# Add this as an autoload in Project Settings → Autoload
extends Node

var music_player: AudioStreamPlayer
var current_music: AudioStream
var current_music_path: String = ""
var music_position: float = 0.0
var should_be_playing: bool = false

func _ready():
	# Create an AudioStreamPlayer for music
	music_player = AudioStreamPlayer.new()
	
	# Check if Music bus exists, create it if it doesn't
	var music_bus_index = AudioServer.get_bus_index("Music")
	if music_bus_index == -1:
		print("Warning: 'Music' audio bus not found! Please create it in the Audio dock.")
		print("Using Master bus as fallback.")
		music_player.bus = "Master"
	else:
		music_player.bus = "Music"  # Assign to Music audio bus
		print("Music player assigned to 'Music' audio bus")
	
	# Make sure the music player persists across scenes
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)
	
	# Connect to the finished signal to handle looping
	music_player.finished.connect(_on_music_finished)
	
	# Connect to tree changes to save music position
	get_tree().node_removed.connect(_on_node_removed)
	
	# Start playing your default music
	play_music("res://path/to/your/music.ogg")  # Replace with your music file path

# Save position when nodes are removed (scene changes)
func _on_node_removed(node):
	# Save music state when scenes change
	if music_player and music_player.playing:
		save_music_state()

func _on_music_finished():
	# Auto-restart the music if it should be playing
	if should_be_playing and current_music:
		music_player.play()

# Enhanced play_music with persistence
func play_music(music_path: String, fade_in: bool = false):
	var music_stream = load(music_path)
	if music_stream:
		if fade_in and music_player.playing:
			# Fade out current music first
			var tween = create_tween()
			tween.tween_property(music_player, "volume_db", -80.0, 0.5)
			await tween.finished
		
		current_music_path = music_path
		current_music = music_stream
		music_player.stream = music_stream
		music_player.play()
		should_be_playing = true
		
		if fade_in:
			music_player.volume_db = -80.0
			var tween = create_tween()
			tween.tween_property(music_player, "volume_db", 0.0, 0.5)
		
		print("Now playing: ", music_path)

# Function to ensure music continues playing
func ensure_music_playing():
	if should_be_playing and current_music and not music_player.playing:
		print("Restarting music: ", current_music_path)
		music_player.stream = current_music
		music_player.play()
		if music_position > 0:
			music_player.seek(music_position)

# Save music position before scene changes
func save_music_state():
	if music_player.playing:
		music_position = music_player.get_playback_position()

# Restore music after scene changes
func restore_music_state():
	ensure_music_playing()

# Check if music is actually playing
func is_music_playing() -> bool:
	return music_player.playing

# Play menu music specifically
func play_menu_music():
	play_music("res://Music/twilight-game-menu-short-pixabay-356042.mp3")  # Replace with your menu music path

# Play game music
func play_game_music():
	play_music("res://path/to/your/game_music.ogg")  # Replace with your game music path

# Play music with fade transition
func play_music_with_fade(music_path: String):
	play_music(music_path, true)

# Switch between different music tracks
func switch_to_menu():
	play_menu_music()

func switch_to_game():
	play_game_music()

func switch_to_boss_music():
	play_music("res://path/to/your/boss_music.ogg")  # Replace with boss music path

func stop_music(fade_out: bool = false):
	if fade_out:
		var tween = create_tween()
		tween.tween_property(music_player, "volume_db", -80.0, 0.5)
		await tween.finished
		music_player.stop()
		music_player.volume_db = 0.0
	else:
		music_player.stop()

# Alternative name for stop_music (for compatibility)
func stop_all_music(fade_out: bool = false):
	stop_music(fade_out)

# Stop music immediately
func stop_music_immediately():
	music_player.stop()

# Stop music with fade
func stop_music_with_fade():
	stop_music(true)

func pause_music():
	music_player.stream_paused = true

func resume_music():
	music_player.stream_paused = false
	
func is_menu_music_playing() -> bool:
	return music_player.playing and current_music_path == "res://Music/twilight-game-menu-short-pixabay-356042.mp3"
