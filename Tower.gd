extends Node2D
class_name Tower


func _ready() -> void:
	# Draw the black elevated tournament tower top
	var base := Polygon2D.new()
	var points := PackedVector2Array()
	var radius := 16.0
	for i in range(24):
		var angle := i * (TAU / 24)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	base.polygon = points
	base.color = Color(0.12, 0.12, 0.14) # Matte Black
	add_child(base)

	# Inner ring highlight
	var ring := Line2D.new()
	ring.width = 2.0
	ring.default_color = Color(0.35, 0.35, 0.4)
	for i in range(25):
		var angle := i * (TAU / 24)
		ring.add_point(Vector2(cos(angle), sin(angle)) * 14.0)
	add_child(ring)
