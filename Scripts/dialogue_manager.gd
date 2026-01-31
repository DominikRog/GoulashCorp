extends Control

# Dialogue system for opening dialogue and mind puzzles

enum DialogueType {
	OPENING,      # "Get to the king" -> "Yes my Lord"
	MIND_PUZZLE,  # Question with multiple choice
	ACT_INTRO,    # Between acts
	VICTORY,      # Win ending
	DEFEAT        # Lose ending
}

var current_type: DialogueType = DialogueType.OPENING
var current_question_data: Dictionary = {}

@onready var dialogue_text: Label = $DialogueText
@onready var choices_container: VBoxContainer = $ChoicesContainer

signal dialogue_completed
signal answer_selected(correct: bool)

func _ready() -> void:
	MusicManager.resume_if_not_playing()
	# Determine what dialogue to show based on game state
	if GameManager.current_act == 1 and GameManager.is_puzzle_phase:
		# Opening dialogue
		show_opening_dialogue()
	elif not GameManager.is_puzzle_phase:
		# Mind puzzle after shapes completed
		show_mind_puzzle()

func show_opening_dialogue():
	"""Display the opening 'Get to the king' dialogue"""
	current_type = DialogueType.OPENING

	dialogue_text.text = "\"Get to the king.\""

	# Clear existing choices
	clear_choices()

	# Add single choice
	add_choice_button("Yes my Lord.", true)

func show_mind_puzzle():
	"""Display mind puzzle with multiple choice"""
	current_type = DialogueType.MIND_PUZZLE

	# Get question data for current act
	var act_data = GameManager.get_current_act_data()
	if act_data.is_empty():
		push_error("No act data for mind puzzle!")
		return

	# Show completed shapes as hint
	var shapes_text = "You have assembled: " + ", ".join(GameManager.completed_shapes) + "\n\n"

	dialogue_text.text = shapes_text + act_data.get("question", "")

	# Clear existing choices
	clear_choices()

	# Add answer choices
	var answers = act_data.get("answers", [])
	for answer in answers:
		add_choice_button(answer["text"], answer["correct"])

func show_act_intro(act_number: int):
	"""Show dialogue when starting an act"""
	current_type = DialogueType.ACT_INTRO

	var act_data = ShapeData.get_act(act_number)
	dialogue_text.text = act_data.get("dialogue_before", "")

	clear_choices()
	add_choice_button("Continue", true)

func show_victory():
	"""Display victory ending"""
	current_type = DialogueType.VICTORY

	dialogue_text.text = "\"Well done, my servant. You have claimed the throne.\n\nThe Queen's power is yours. The kingdom is mine.\n\nYour reward is existence... for now.\""

	clear_choices()
	add_choice_button("Return to Main Menu", true)

func show_defeat():
	"""Display defeat ending"""
	current_type = DialogueType.DEFEAT

	dialogue_text.text = "\"You have failed me.\n\nA demon who cannot possess the right vessel is useless.\n\nBe unmade.\""

	clear_choices()
	add_choice_button("Retry Act", true)

func clear_choices():
	"""Remove all choice buttons"""
	for child in choices_container.get_children():
		child.queue_free()

func add_choice_button(text: String, is_correct: bool):
	"""Add a choice button"""
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(400, 50)

	# Style the button
	button.theme_type_variation = "Button"

	# Connect signal
	button.pressed.connect(_on_choice_selected.bind(is_correct, text))

	choices_container.add_child(button)

func _on_choice_selected(is_correct: bool, choice_text: String):
	"""Handle choice selection"""
	match current_type:
		DialogueType.OPENING:
			# Start first act puzzle
			get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

		DialogueType.MIND_PUZZLE:
			if is_correct:
				# Correct answer - advance to next act
				var act_data = GameManager.get_current_act_data()
				var next_character = act_data.get("next_character", "")

				GameManager.advance_to_next_act(next_character)

				# Check if game is won
				if GameManager.current_act > 6:
					show_victory()
				else:
					# Next act puzzle
					get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
			else:
				# Wrong answer - show defeat and restart act
				show_defeat()

		DialogueType.VICTORY:
			# Return to main menu
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

		DialogueType.DEFEAT:
			# Restart current act
			GameManager.restart_current_act()
			get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")

		DialogueType.ACT_INTRO:
			# Continue to puzzle
			get_tree().change_scene_to_file("res://Scenes/PuzzleGame.tscn")
