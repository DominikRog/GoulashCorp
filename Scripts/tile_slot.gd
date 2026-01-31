extends Node2D

var tile_index: int = 0
var is_filled: bool = false
var visual: ColorRect

func _ready():
	visual = ColorRect.new()
	visual.size = Vector2(16, 16)
	visual.position = Vector2(-8, -8)  # Center
	visual.color = Color(1, 1, 1, 0.25)  # Semi-transparent
	add_child(visual)

func setup(index: int, pos: Vector2):
	tile_index = index
	global_position = pos

func set_filled(filled: bool):
	is_filled = filled
	visual.color = Color(0.3, 1, 0.3, 0.3) if filled else Color(1, 1, 1, 0.25)
