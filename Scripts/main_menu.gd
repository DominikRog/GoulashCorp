extends Control

@onready var play_button = $MarginContainer/VBoxContainer/PlayButton


func _ready():
	MusicManager.play_music()
	play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed():
	# Initialize game state
	GameManager.start_new_game()
	# Start with opening dialogue
	get_tree().change_scene_to_file("res://Scenes/Dialogue.tscn")
