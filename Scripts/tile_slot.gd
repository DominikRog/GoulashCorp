extends Node2D

var tile_index: int = 0
var is_filled: bool = false
var visual = null  # Can be ColorRect or Sprite2D depending on mode
var shape_outline: PackedVector2Array = PackedVector2Array()  # For Voronoi mode

func _ready():
	# Default visual (will be replaced if Voronoi mode)
	if visual == null:
		create_default_visual()

func create_default_visual():
	"""Create simple rectangle slot (grid mode)"""
	visual = ColorRect.new()
	visual.size = Vector2(16, 16)
	visual.position = Vector2(-8, -8)  # Center
	visual.color = Color(1, 1, 1, 0.25)  # Semi-transparent
	add_child(visual)

func setup(index: int, pos: Vector2):
	tile_index = index
	global_position = pos

func setup_voronoi(index: int, pos: Vector2, piece_texture: Image, piece_boundary: PackedVector2Array, sprite_offset: Vector2 = Vector2.ZERO):
	"""Setup slot for Voronoi piece with actual shape preview"""
	tile_index = index
	global_position = pos
	shape_outline = piece_boundary

	# Remove old visual if exists
	if visual:
		visual.queue_free()

	# Create sprite showing the piece shape with transparency
	if piece_texture:
		var texture = ImageTexture.create_from_image(piece_texture)
		visual = Sprite2D.new()
		visual.texture = texture
		visual.offset = sprite_offset  # Match tile sprite offset
		visual.modulate = Color(1, 1, 1, 0.3)  # Semi-transparent white overlay
		add_child(visual)
	else:
		# Fallback to drawing outline
		create_default_visual()

func set_filled(filled: bool):
	is_filled = filled

	if visual is ColorRect:
		visual.color = Color(0.3, 1, 0.3, 0.3) if filled else Color(1, 1, 1, 0.25)
	elif visual is Sprite2D:
		# Change tint when filled
		visual.modulate = Color(0.3, 1, 0.3, 0.5) if filled else Color(1, 1, 1, 0.3)

func _draw():
	"""Draw outline for Voronoi pieces (disabled - just showing texture)"""
	# Outline drawing removed - only showing semi-transparent texture preview
	pass
