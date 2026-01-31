extends Node

## Applies a smooth figure-8 (infinity symbol) motion to the parent node

@export var motion_speed: float = 0.5  ## Speed of the figure-8 motion
@export var horizontal_range: float = 10.0  ## Horizontal movement range in pixels
@export var vertical_range: float = 5.0  ## Vertical movement range in pixels
@export var enabled: bool = true  ## Toggle motion on/off

var original_position: Vector2
var time: float = 0.0

func _ready():
	# Store the original position from the scene
	var parent = get_parent()
	if parent is Node2D:
		original_position = parent.position
	elif parent is Control:
		original_position = Vector2(parent.offset_left, parent.offset_top)

func _process(delta):
	if not enabled:
		return

	time += delta * motion_speed

	# Figure-8 pattern using Lissajous curve
	# x uses sin(time * 2) for horizontal figure-8
	# y uses sin(time) for vertical motion
	var offset_x = sin(time * 2.0) * horizontal_range
	var offset_y = sin(time) * vertical_range

	var parent = get_parent()
	if parent is Node2D:
		parent.position = original_position + Vector2(offset_x, offset_y)
	elif parent is Control:
		parent.offset_left = original_position.x + offset_x
		parent.offset_top = original_position.y + offset_y
