extends Node2D

@export var cell_size: int = 32
@export var size_cells: Vector2i = Vector2i(10, 10) # kwadrat 10x10
@export var origin: Vector2 = Vector2(-160, -160)   # środek sceny (dla 10x10 przy 32)

var target_cells: Dictionary = {} # klucz: Vector2i, wartość: true

func _ready() -> void:
	_build_square()

func _build_square() -> void:
	target_cells.clear()
	for y in range(size_cells.y):
		for x in range(size_cells.x):
			target_cells[Vector2i(x, y)] = true
	queue_redraw()

func world_to_cell(p: Vector2) -> Vector2i:
	var local := p - origin
	return Vector2i(floor(local.x / cell_size), floor(local.y / cell_size))

func cell_to_world(c: Vector2i) -> Vector2:
	return origin + Vector2(c.x * cell_size, c.y * cell_size)

func _draw() -> void:
	# rysuj obrys kwadratu celu
	var w := size_cells.x * cell_size
	var h := size_cells.y * cell_size
	draw_rect(Rect2(origin, Vector2(w, h)), Color(0.2,0.2,0.2,1.0), true) # wypełnienie
	draw_rect(Rect2(origin, Vector2(w, h)), Color.WHITE, false, 2.0)      # ramka
