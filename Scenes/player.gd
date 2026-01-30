extends Node2D

@export var width := 26.0
@export var height := 40.0

func _draw() -> void:
	# rysuje białą fasolkę / kapsułę
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
	_draw_capsule(Vector2.ZERO, width, height, Color.WHITE)

func _draw_capsule(center: Vector2, w: float, h: float, col: Color) -> void:
	var r := w * 0.5
	var body_h: float = max(0.0, h - 2.0 * r)

	# prostokąt "tułowia"
	if body_h > 0.0:
		var rect := Rect2(center.x - r, center.y - body_h * 0.5, w, body_h)
		draw_rect(rect, col)

	# kółka góra/dół
	draw_circle(Vector2(center.x, center.y - body_h * 0.5), r, col)
	draw_circle(Vector2(center.x, center.y + body_h * 0.5), r, col)

func _ready() -> void:
	queue_redraw()
