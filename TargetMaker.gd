extends Node2D
class_name TargetMarker


func _ready() -> void:
	var visual := Polygon2D.new()
	var points := PackedVector2Array()
	var radius := 16.0
	var segments := 24
	
	for i in range(segments):
		var angle := i * (TAU / segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
		
	visual.polygon = points
	visual.color = Color(1.0, 0.45, 0.0) # Bright orange
	add_child(visual)
