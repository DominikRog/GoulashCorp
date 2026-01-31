extends Node

## Applies a subtle breathing effect (scale pulsing) to the parent node

@export var breathe_speed: float = 0.8  ## Speed of breathing
@export var breathe_intensity: float = 0.05  ## How much to scale (0.05 = 5% larger/smaller)

var original_scale: Vector2
var time: float = 0.0

func _ready():
	# Store the original scale from the scene
	var parent = get_parent()
	if parent is Node2D:
		original_scale = parent.scale
	elif parent is Control:
		original_scale = parent.scale
		# Set pivot to center for uniform scaling and adjust position
		var center = parent.size / 2.0
		parent.offset_left += center.x
		parent.offset_top += center.y
		parent.pivot_offset = center

func _process(delta):
	time += delta * breathe_speed

	# Breathing effect using sine wave
	var pulse = sin(time) * breathe_intensity
	var scale_multiplier = 1.0 + pulse

	var parent = get_parent()
	if parent is Node2D or parent is Control:
		parent.scale = original_scale * scale_multiplier
