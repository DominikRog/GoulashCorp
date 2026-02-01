extends TextureRect


@export var radius := 6       # promień kółka (px)
@export var speed := 1.5         # prędkość obrotu

var time := 0.0
var start_pos: Vector2

func _ready():
	start_pos = position

func _process(delta):
	time += delta * speed
	
	var offset = Vector2(
		cos(time),
		sin(time)
	) * radius
	
	position = start_pos + offset
