extends Node2D
class_name Dart

enum Team { BLUE, GREEN }
@export var team: Team = Team.BLUE
@export var custom_color: Color = Color(0.18, 0.82, 1.0)

# Tuned flight physics
@export var max_drag_distance: float = 240.0
@export var throw_multiplier: float = 4.8
@export var flight_duration: float = 0.62

var is_active: bool = false
var is_dragging: bool = false
var is_airborne: bool = false
var is_stuck: bool = false

var drag_start_pos: Vector2 = Vector2.ZERO
var current_drag_pos: Vector2 = Vector2.ZERO
var throw_vector: Vector2 = Vector2.ZERO

var flight_start_pos: Vector2 = Vector2.ZERO
var target_landing_pos: Vector2 = Vector2.ZERO
var flight_elapsed: float = 0.0

var visual_container: Node2D
var shadow_node: Polygon2D
var trail_line: Line2D

# Contact Spark Particle Tracking
var active_sparks: Array = []

signal dart_stopped(dart: Dart)


func _ready() -> void:
	create_suction_visual()


func create_suction_visual() -> void:
	for child in get_children():
		child.queue_free()

	visual_container = Node2D.new()
	add_child(visual_container)

	var sides := 24
	var dart_radius := 14.0

	# Shadow
	shadow_node = Polygon2D.new()
	shadow_node.color = Color(0.0, 0.0, 0.0, 0.35)
	var shadow_pts := PackedVector2Array()
	for i in range(sides):
		var angle := i * (TAU / sides)
		shadow_pts.append(Vector2(cos(angle), sin(angle)) * dart_radius)
	shadow_node.polygon = shadow_pts
	add_child(shadow_node)
	move_child(shadow_node, 0)

	# Silicone Cup
	var outer_cup := Polygon2D.new()
	outer_cup.color = custom_color
	var outer_pts := PackedVector2Array()
	for i in range(sides):
		var angle := i * (TAU / sides)
		outer_pts.append(Vector2(cos(angle), sin(angle)) * dart_radius)
	outer_cup.polygon = outer_pts
	visual_container.add_child(outer_cup)

	# Inner Silicone Shaft Tip
	var inner_shaft := Polygon2D.new()
	inner_shaft.color = Color(0.95, 0.96, 0.98)
	var shaft_pts := PackedVector2Array()
	for i in range(sides):
		var angle := i * (TAU / sides)
		shaft_pts.append(Vector2(cos(angle), sin(angle)) * 5.0)
	inner_shaft.polygon = shaft_pts
	visual_container.add_child(inner_shaft)

	# Motion Trail
	trail_line = Line2D.new()
	trail_line.width = 4.5
	trail_line.default_color = Color(custom_color.r, custom_color.g, custom_color.b, 0.45)
	trail_line.top_level = true
	add_child(trail_line)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active or is_airborne or is_stuck:
		return

	# Network check
	var main_node = get_parent()
	if is_instance_valid(main_node) and ("current_game_mode" in main_node):
		var mode = main_node.current_game_mode
		if mode == 2 and team != Team.BLUE:
			return
		elif mode == 3 and team != Team.GREEN:
			return

	var mouse_world_pos := get_global_mouse_position()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if global_position.distance_to(mouse_world_pos) < 95.0:
				is_dragging = true
				drag_start_pos = global_position
				current_drag_pos = mouse_world_pos
				queue_redraw()
		elif is_dragging:
			is_dragging = false
			current_drag_pos = mouse_world_pos
			launch()

	elif event is InputEventMouseMotion and is_dragging:
		current_drag_pos = mouse_world_pos
		queue_redraw()


func _draw() -> void:
	if is_dragging and is_active:
		var pull_vector := drag_start_pos - current_drag_pos
		var clamped_vector := pull_vector.limit_length(max_drag_distance)
		var pull_ratio := clamped_vector.length() / max_drag_distance

		# 1. Pull Cord (Elastic band under the finger)
		var pull_local := to_local(current_drag_pos)
		draw_line(Vector2.ZERO, pull_local, Color(1.0, 0.35, 0.35, 0.45), 2.5)
		draw_circle(pull_local, 5.5, Color(1.0, 0.4, 0.4, 0.85))

		# 2. Short Directional Guide (Fades out quickly — no landing reticle)
		var launch_dir := clamped_vector.normalized()
		var guide_length := lerpf(25.0, 75.0, pull_ratio)
		
		var num_pips := 4
		for i in range(1, num_pips + 1):
			var t := float(i) / float(num_pips)
			var pip_pos := launch_dir * (guide_length * t)
			var pip_alpha := (1.0 - t * 0.7) * 0.8
			var pip_radius := lerpf(4.0, 2.0, t)
			
			var c: Color = custom_color.lightened(0.3)
			c.a = pip_alpha
			draw_circle(pip_pos, pip_radius, c)

	for spark in active_sparks:
		var c: Color = custom_color.lightened(0.3)
		c.a = spark.alpha
		draw_circle(to_local(spark.pos), spark.size, c)


func launch() -> void:
	var pull_vector := drag_start_pos - current_drag_pos
	var clamped_vector := pull_vector.limit_length(max_drag_distance)

	if clamped_vector.length() > 16.0:
		var main_node = get_parent()
		if is_instance_valid(main_node) and main_node.has_method("send_network_throw"):
			main_node.send_network_throw(clamped_vector)
		
		execute_launch(clamped_vector)
	else:
		queue_redraw()


func execute_launch(clamped_vector: Vector2) -> void:
	is_airborne = true
	is_active = false
	is_dragging = false
	throw_vector = clamped_vector * throw_multiplier
	flight_start_pos = global_position
	target_landing_pos = flight_start_pos + throw_vector
	flight_elapsed = 0.0

	var main_node = get_parent()
	if is_instance_valid(main_node) and main_node.has_method("trigger_camera_zoom"):
		main_node.trigger_camera_zoom(target_landing_pos)

	if has_node("/root/SoundManager"):
		SoundManager.play_swoosh()
	
	queue_redraw()


func _process(delta: float) -> void:
	if not active_sparks.is_empty():
		for spark in active_sparks:
			spark.pos += spark.velocity * delta
			spark.velocity = spark.velocity.move_toward(Vector2.ZERO, delta * 300.0)
			spark.alpha = maxf(0.0, spark.alpha - delta * 3.5)
			spark.size = maxf(0.5, spark.size - delta * 4.0)
		active_sparks = active_sparks.filter(func(s): return s.alpha > 0.02)
		queue_redraw()

	if is_airborne:
		flight_elapsed += delta
		var t: float = clampf(flight_elapsed / flight_duration, 0.0, 1.0)

		visual_container.rotation = sin(flight_elapsed * 28.0) * 0.18
		global_position = flight_start_pos.lerp(target_landing_pos, t)

		var height_factor: float = sin(t * PI)
		var throw_dist: float = flight_start_pos.distance_to(target_landing_pos)
		var peak_height: float = clampf(throw_dist * 0.16, 70.0, 150.0)

		visual_container.position.y = -height_factor * peak_height
		visual_container.scale = Vector2.ONE * (1.0 + height_factor * 0.7)

		shadow_node.position = Vector2(0, height_factor * 26.0)
		shadow_node.scale = Vector2.ONE * (1.0 - height_factor * 0.4)
		shadow_node.color.a = lerpf(0.35, 0.12, height_factor)

		trail_line.add_point(visual_container.global_position)
		if trail_line.get_point_count() > 16:
			trail_line.remove_point(0)

		if t >= 1.0:
			land_and_stick()


func spawn_landing_sparks() -> void:
	active_sparks.clear()
	for i in range(7):
		var angle := randf_range(0.0, TAU)
		var speed := randf_range(90.0, 180.0)
		active_sparks.append({
			"pos": global_position,
			"velocity": Vector2(cos(angle), sin(angle)) * speed,
			"alpha": 1.0,
			"size": randf_range(3.0, 5.0)
		})
	queue_redraw()


func land_and_stick() -> void:
	is_airborne = false
	is_stuck = true
	is_active = false
	global_position = target_landing_pos
	visual_container.position = Vector2.ZERO
	visual_container.rotation = 0.0
	visual_container.scale = Vector2.ONE
	shadow_node.position = Vector2.ZERO
	shadow_node.scale = Vector2.ONE
	shadow_node.color.a = 0.35

	spawn_landing_sparks()

	var main_node = get_parent()
	if is_instance_valid(main_node) and main_node.has_method("trigger_screen_shake"):
		main_node.trigger_screen_shake(10.0)

	if is_instance_valid(trail_line):
		var fade_tween := create_tween()
		fade_tween.tween_property(trail_line, "modulate:a", 0.0, 0.35)

	if has_node("/root/SoundManager"):
		SoundManager.play_pop(randf_range(0.95, 1.05))

	var tween := create_tween()
	tween.tween_property(visual_container, "scale", Vector2(1.38, 1.38), 0.06)
	tween.tween_property(visual_container, "scale", Vector2.ONE, 0.08)

	dart_stopped.emit(self)
