extends Node2D

@export var cell_size: int = 32
@export var anchor_cell: Vector2i = Vector2i(0, 0)
@export var shape_cells: Array[Vector2i] = [Vector2i(0,0)] # domyślnie 1 klocek

func get_occupied_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for off in shape_cells:
		out.append(anchor_cell + off)
	return out

func set_anchor_cell(c: Vector2i, origin: Vector2) -> void:
	anchor_cell = c
	position = origin + Vector2(c.x * cell_size, c.y * cell_size)

func _draw() -> void:
	# proste rysowanie klocków (na start bez sprite)
	for off in shape_cells:
		var r := Rect2(Vector2(off.x * cell_size, off.y * cell_size), Vector2(cell_size, cell_size))
		draw_rect(r, Color.WHITE, true)
		draw_rect(r, Color.BLACK, false, 2.0)
