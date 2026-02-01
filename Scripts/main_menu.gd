extends Control

@onready var play_button = $MarginContainer/VBoxContainer/PlayButton
@onready var quote_label = $MarginContainer/VBoxContainer/Quote

# Typewriter effect variables
var full_text: String = ""
var current_char_index: float = 0.0
var typewriter_speed: float = 0.05  # Seconds per character
var is_typing: bool = false

func _ready():
	MusicManager.enter_menu_or_dialogue()
	play_button.pressed.connect(_on_play_pressed)

	# Make button focusable
	play_button.focus_mode = Control.FOCUS_ALL

	# Start typewriter effect for quote
	full_text = quote_label.text
	quote_label.text = ""
	is_typing = true
	current_char_index = 0.0

func _process(delta: float) -> void:
	# Typewriter effect
	if is_typing:
		current_char_index += delta / typewriter_speed
		var chars_to_show = int(current_char_index)
		if chars_to_show >= full_text.length():
			# Finished typing
			quote_label.text = full_text
			is_typing = false
			# Give focus to play button after typing finishes
			play_button.grab_focus()
		else:
			quote_label.text = full_text.substr(0, chars_to_show)

func _input(event: InputEvent) -> void:
	# Number key shortcut - press 1 to play
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_on_play_pressed()
			get_viewport().set_input_as_handled()

func _on_play_pressed():
	# Initialize game state
	GameManager.start_new_game()
	# Start with opening dialogue
	get_tree().change_scene_to_file("res://Scenes/Dialogue.tscn")
