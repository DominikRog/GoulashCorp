extends Node

# Global game state manager

signal act_completed
signal puzzle_completed
signal game_won
signal game_lost

# Current game state
var current_act: int = 1
var current_character: String = "demon"
var puzzle_shapes_completed: int = 0
var total_shapes_in_act: int = 0
var is_puzzle_phase: bool = true

# Track completed shapes for clue display
var completed_shapes: Array[String] = []

func _ready():
	pass

func start_new_game():
	"""Reset game state for a new game"""
	current_act = 1
	current_character = "demon"
	reset_act_progress()

func reset_act_progress():
	"""Reset progress within the current act"""
	puzzle_shapes_completed = 0
	completed_shapes.clear()
	is_puzzle_phase = true

func complete_shape(shape_name: String):
	"""Called when a shape puzzle is completed"""
	puzzle_shapes_completed += 1
	completed_shapes.append(shape_name)

	if puzzle_shapes_completed >= total_shapes_in_act:
		puzzle_completed.emit()
		is_puzzle_phase = false

func advance_to_next_act(next_character: String):
	"""Move to the next act after successful mind puzzle"""
	current_act += 1
	current_character = next_character
	reset_act_progress()

	if current_act > 6:
		game_won.emit()
	else:
		act_completed.emit()

func restart_current_act():
	"""Restart the current act after wrong answer"""
	reset_act_progress()
	game_lost.emit()

func get_current_act_data() -> Dictionary:
	"""Get the configuration for the current act from ShapeData"""
	if has_node("/root/ShapeData"):
		var shape_data = get_node("/root/ShapeData")
		if shape_data.has_method("get_act"):
			return shape_data.get_act(current_act)
	return {}
