extends Node2D

@export var cell_size: int = 32
@export var time_limit_sec: float = 60.0
@export var win_threshold: float = 0.90

@onready var target: Node = $TargetArea
@onready var blocks_parent: Node = $Blocks
@onready var timer_label: Label = $UI/TimerLabel
@onready var result_label: Label = $UI/ResultLabel

var time_left: float
var finished := false

func _ready() -> void:
	time_left = time_limit_sec
	result_label.text = "Time:59"
	# upewnij się, że wszystkie bloczki mają cell_size zgodne
	for b in blocks_parent.get_children():
		b.cell_size = cell_size
		b.queue_redraw()

func _process(delta: float) -> void:
	if finished:
		return
	time_left -= delta
	timer_label.text = "Time: %02d" % int(ceil(time_left))
	if time_left <= 0.0:
		time_left = 0.0
		_finish()

func _finish() -> void:
	finished = true
	var ratio := _compute_fill_ratio()
	if ratio >= win_threshold:
		result_label.text = "WIN! %d%%" % int(ratio * 100.0)
	else:
		result_label.text = "LOSE! %d%%" % int(ratio * 100.0)

func _compute_fill_ratio() -> float:
	# 1) zbierz wszystkie komórki celu
	var target_cells: Dictionary = target.target_cells
	var total := target_cells.size()
	if total == 0:
		return 0.0

	# 2) zbierz zajęte komórki przez bloczki
	var occupied: Dictionary = {}
	for b in blocks_parent.get_children():
		for c in b.get_occupied_cells():
			occupied[c] = true

	# 3) policz ile komórek celu jest wypełnionych
	var filled := 0
	for c in target_cells.keys():
		if occupied.has(c):
			filled += 1

	return float(filled) / float(total)
