extends Node2D

@export var dart_scene: PackedScene = preload("res://dart.tscn")

enum ScreenState { MENU, GAMEPLAY, PUZZLES }
enum GameMode { VS_AI, TWO_PLAYER, ONLINE_HOST, ONLINE_CLIENT, PUZZLE_MODE }

var current_screen: ScreenState = ScreenState.MENU
var current_game_mode: GameMode = GameMode.VS_AI

const DARTS_PER_ROUND: int = 6
const TABLE_RECT: Rect2 = Rect2(170, 140, 380, 710)
const FOUL_LINE_Y: float = 850.0

const ORANGE_MARKER_POS: Vector2 = Vector2(360, 490)
const TOWER_POS: Vector2 = Vector2(515, 185)

# Gameplay Podium Mats
const P1_MAT_RECT: Rect2 = Rect2(165, 980, 185, 170)
const P2_MAT_RECT: Rect2 = Rect2(370, 980, 185, 170)

const P1_SPAWN_POS: Vector2 = Vector2(257, 1065)
const P2_SPAWN_POS: Vector2 = Vector2(462, 1065)

# Modals
const MODAL_RECT: Rect2 = Rect2(130, 360, 460, 430)
const REMATCH_BTN_RECT: Rect2 = Rect2(170, 620, 380, 58)
const MAIN_MENU_BTN_RECT: Rect2 = Rect2(170, 695, 380, 48)

# Auth Modal Dimensions
const AUTH_MODAL_RECT: Rect2 = Rect2(110, 210, 500, 510)

# Theme Colors
const CHESS_BG_DARK: Color = Color(0.12, 0.11, 0.10)
const CHESS_CARD_BG: Color = Color(0.16, 0.15, 0.14)
const CHESS_CARD_BORDER: Color = Color(0.24, 0.23, 0.21)
const CHESS_GREEN_CTA: Color = Color(0.50, 0.71, 0.30)
const CHESS_GREEN_BEVEL: Color = Color(0.33, 0.44, 0.20)
const CHESS_CYAN_BRILLIANT: Color = Color(0.16, 0.77, 0.81)

const PALETTE: Array[Color] = [
	Color(0.18, 0.82, 1.0),
	Color(1.0, 0.28, 0.35),
	Color(0.75, 0.35, 1.0),
	Color(0.28, 1.0, 0.45),
	Color(1.0, 0.82, 0.15),
	Color(1.0, 0.35, 0.75)
]

var p1_color_idx: int = 0
var p2_color_idx: int = 3

# Match State
var current_team: Dart.Team = Dart.Team.BLUE
var darts_thrown_count: int = 0
var active_dart: Dart = null
var thrown_darts: Array = []
var suction_ring_decals: Array[Vector2] = []

var blue_total_score: int = 0
var green_total_score: int = 0
var displayed_blue_score: float = 0.0
var displayed_green_score: float = 0.0

var p2_name_display: String = "BOT MARTIN"
var p2_elo: int = 1420

var tower_claimed_by: Dart = null
var show_measurement_line: bool = false
var measure_start: Vector2 = Vector2.ZERO
var measure_end: Vector2 = Vector2.ZERO

var shockwaves: Array = []
var pulse_timer: float = 0.0

# Camera Shake & Micro-Zoom
var main_camera: Camera2D = null
var shake_intensity: float = 0.0

# Table Watermarks, Audio & Network UI
var top_table_watermark: Label = null
var bottom_table_watermark: Label = null
var victory_overlay: Node2D = null
var is_game_over: bool = false
var winner_name: String = ""
var winner_color: Color = Color.WHITE
var victory_rating_text: String = ""
var confetti_particles: Array = []
var network_status_text: String = ""

# 6-Digit Matchmaking Code
var room_code_box: LineEdit = null
var host_room_code: String = ""
var is_audio_muted: bool = false

# Registration Form Controls
var show_auth_modal: bool = false
var auth_email_box: LineEdit = null
var auth_name_box: LineEdit = null
var auth_error_msg: String = ""

# Move Badges & Live Demo
var active_move_badges: Array[Node2D] = []
var demo_timer: float = 0.0
var demo_darts: Array = []
var demo_badges: Array = []

# Instagram Live Floating Balloon Reactions
const EMOJIS: Array[String] = ["🔥", "🎯", "😱", "👏", "😎"]
const EMOJI_BAR_START_Y: float = 880.0
var active_reaction_balloons: Array = []

# Trickshot / Puzzle Mode State
var current_puzzle_level: int = 1
var puzzle_obstacles: Array[Rect2] = []
var puzzle_target_pos: Vector2 = ORANGE_MARKER_POS
var puzzle_stars_earned: Dictionary = {}
var puzzle_attempts_left: int = 3

# UI References
@onready var hud: CanvasLayer = $HUD
@onready var table_surface: ColorRect = $TableSurface
@onready var target_marker: Node2D = $TargetMaker
@onready var tower: Node2D = $Tower
@onready var score_label: Label = $HUD/UIRoot/ScoreLabel
@onready var turn_label: Label = $HUD/UIRoot/TurnLabel
@onready var round_result_label: Label = $HUD/UIRoot/RoundResultLabel


func _ready() -> void:
	if is_instance_valid(hud):
		for child in hud.find_children("*", "Control", true):
			if child is Control and not (child is LineEdit):
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	main_camera = Camera2D.new()
	main_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	main_camera.position = Vector2.ZERO
	add_child(main_camera)

	if is_instance_valid(table_surface):
		table_surface.position = TABLE_RECT.position
		table_surface.size = TABLE_RECT.size
		table_surface.color = Color(0.291, 0.308, 0.341, 0.851)
		table_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var popdarts_font := SystemFont.new()
	popdarts_font.font_names = PackedStringArray(["Impact", "Eurostile", "Microgramma", "Arial Black", "Sans-Serif"])
	popdarts_font.font_weight = 900
	popdarts_font.font_stretch = 125
	popdarts_font.font_italic = true

	top_table_watermark = Label.new()
	top_table_watermark.text = "POPDARTS"
	top_table_watermark.position = Vector2(TABLE_RECT.position.x, TABLE_RECT.position.y + 20.0)
	top_table_watermark.size = Vector2(TABLE_RECT.size.x, 50.0)
	top_table_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_table_watermark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_table_watermark.add_theme_font_override("font", popdarts_font)
	top_table_watermark.add_theme_font_size_override("font_size", 55)
	top_table_watermark.add_theme_color_override("font_color", Color(0.12, 0.16, 0.22, 0.18))
	top_table_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_table_watermark)

	bottom_table_watermark = Label.new()
	bottom_table_watermark.text = "POPDARTS"
	bottom_table_watermark.size = Vector2(TABLE_RECT.size.x, 50.0)
	bottom_table_watermark.pivot_offset = Vector2(TABLE_RECT.size.x / 2.0, 25.0)
	bottom_table_watermark.position = Vector2(TABLE_RECT.position.x, TABLE_RECT.position.y + 660.0)
	bottom_table_watermark.rotation_degrees = 180.0
	bottom_table_watermark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_table_watermark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom_table_watermark.add_theme_font_override("font", popdarts_font)
	bottom_table_watermark.add_theme_font_size_override("font_size", 55)
	bottom_table_watermark.add_theme_color_override("font_color", Color(0.12, 0.16, 0.22, 0.18))
	bottom_table_watermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_table_watermark)

	auth_email_box = LineEdit.new()
	auth_email_box.placeholder_text = "name@gmail.com"
	auth_email_box.position = Vector2(160, 375)
	auth_email_box.size = Vector2(400, 44)
	auth_email_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	auth_email_box.add_theme_font_size_override("font_size", 14)
	auth_email_box.visible = false
	add_child(auth_email_box)

	auth_name_box = LineEdit.new()
	auth_name_box.placeholder_text = "Display Name (Optional)"
	auth_name_box.position = Vector2(160, 460)
	auth_name_box.size = Vector2(400, 44)
	auth_name_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	auth_name_box.add_theme_font_size_override("font_size", 14)
	auth_name_box.visible = false
	add_child(auth_name_box)

	room_code_box = LineEdit.new()
	room_code_box.placeholder_text = "6-Digit Code"
	room_code_box.max_length = 6
	room_code_box.position = Vector2(140, 715)
	room_code_box.size = Vector2(240, 44)
	room_code_box.alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_code_box.add_theme_font_size_override("font_size", 16)
	add_child(room_code_box)

	victory_overlay = Node2D.new()
	victory_overlay.z_index = 100
	victory_overlay.draw.connect(_on_victory_overlay_draw)
	add_child(victory_overlay)

	if is_instance_valid(target_marker): target_marker.position = ORANGE_MARKER_POS
	if is_instance_valid(tower): tower.position = TOWER_POS

	format_hud_layout()
	set_screen_visibility(ScreenState.MENU)


func set_screen_visibility(new_screen: ScreenState) -> void:
	current_screen = new_screen
	is_game_over = false
	show_auth_modal = false
	confetti_particles.clear()
	active_reaction_balloons.clear()
	clear_active_move_badges()
	
	var is_gameplay: bool = (current_screen == ScreenState.GAMEPLAY)
	var is_puzzles: bool = (current_screen == ScreenState.PUZZLES)

	if is_instance_valid(table_surface): table_surface.visible = (is_gameplay or is_puzzles)
	if is_instance_valid(top_table_watermark): top_table_watermark.visible = (is_gameplay or is_puzzles)
	if is_instance_valid(bottom_table_watermark): bottom_table_watermark.visible = (is_gameplay or is_puzzles)
	if is_instance_valid(target_marker): target_marker.visible = (is_gameplay or is_puzzles)
	if is_instance_valid(tower): tower.visible = is_gameplay
	if is_instance_valid(round_result_label): round_result_label.visible = is_gameplay
	
	if is_instance_valid(room_code_box): room_code_box.visible = (current_screen == ScreenState.MENU)
	if is_instance_valid(auth_email_box): auth_email_box.visible = false
	if is_instance_valid(auth_name_box): auth_name_box.visible = false

	if is_instance_valid(score_label): score_label.visible = false
	if is_instance_valid(turn_label): turn_label.visible = false

	if is_gameplay:
		if has_node("/root/ProfileManager"):
			ProfileManager.reset_match_analytics()
		blue_total_score = 0
		green_total_score = 0
		displayed_blue_score = 0.0
		displayed_green_score = 0.0
		darts_thrown_count = 0
		current_team = Dart.Team.BLUE
		reset_for_new_round()
	elif is_puzzles:
		setup_puzzle_level(current_puzzle_level)
	else:
		clear_all_darts()
		demo_darts.clear()
		demo_badges.clear()
		demo_timer = 0.0

	queue_redraw()
	if is_instance_valid(victory_overlay):
		victory_overlay.queue_redraw()


func format_hud_layout() -> void:
	if is_instance_valid(round_result_label):
		round_result_label.position = Vector2(170, 290)
		round_result_label.size = Vector2(380, 80)
		round_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		round_result_label.add_theme_font_size_override("font_size", 20)
		round_result_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		round_result_label.add_theme_constant_override("shadow_outline_size", 4)
		round_result_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func toggle_audio_mute() -> void:
	is_audio_muted = not is_audio_muted
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		AudioServer.set_bus_mute(master_idx, is_audio_muted)
	queue_redraw()


func generate_room_code() -> String:
	return "%06d" % [randi() % 1000000]


func resolve_room_code_to_ip(code: String) -> String:
	if code.length() == 6:
		return "127.0.0.1"
	return code


# Instagram Live Flying Balloon Emitter
func trigger_emoji_reaction(is_player_1: bool, emoji: String, spawn_origin: Vector2 = Vector2.ZERO) -> void:
	var start_pos: Vector2 = spawn_origin
	if start_pos == Vector2.ZERO:
		if is_player_1:
			start_pos = Vector2(670, EMOJI_BAR_START_Y + 120)
		else:
			start_pos = Vector2(50, EMOJI_BAR_START_Y + 120)

	active_reaction_balloons.append({
		"pos": start_pos + Vector2(randf_range(-14, 14), randf_range(-8, 8)),
		"emoji": emoji,
		"up_speed": randf_range(280.0, 380.0),
		"wobble_freq": randf_range(4.5, 7.0),
		"wobble_amp": randf_range(24.0, 48.0),
		"wobble_seed": randf_range(0.0, TAU),
		"scale": randf_range(0.85, 1.25),
		"alpha": 1.0,
		"elapsed": 0.0
	})
	
	if has_node("/root/SoundManager") and not is_audio_muted:
		SoundManager.play_chime()
	
	if current_game_mode == GameMode.ONLINE_HOST or current_game_mode == GameMode.ONLINE_CLIENT:
		if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			rpc("sync_remote_emoji", is_player_1, emoji)


@rpc("any_peer", "call_remote", "reliable")
func sync_remote_emoji(is_p1: bool, emoji: String) -> void:
	trigger_emoji_reaction(is_p1, emoji)


func setup_puzzle_level(level_idx: int) -> void:
	clear_all_darts()
	clear_active_move_badges()
	current_puzzle_level = level_idx
	current_game_mode = GameMode.PUZZLE_MODE
	puzzle_attempts_left = 3
	puzzle_obstacles.clear()

	match level_idx:
		1:
			puzzle_target_pos = Vector2(360, 360)
			puzzle_obstacles.append(Rect2(220, 520, 280, 24))
		2:
			puzzle_target_pos = Vector2(250, 300)
			puzzle_obstacles.append(Rect2(290, 380, 140, 180))
		3:
			puzzle_target_pos = Vector2(360, 380)
			puzzle_obstacles.append(Rect2(190, 480, 120, 24))
			puzzle_obstacles.append(Rect2(410, 480, 120, 24))

	if is_instance_valid(target_marker):
		target_marker.position = puzzle_target_pos
	
	spawn_next_puzzle_dart()


func spawn_next_puzzle_dart() -> void:
	if current_screen != ScreenState.PUZZLES or puzzle_attempts_left <= 0:
		return

	var dart_instance: Dart = dart_scene.instantiate() as Dart
	active_dart = dart_instance
	active_dart.team = Dart.Team.BLUE
	active_dart.custom_color = PALETTE[p1_color_idx]
	active_dart.global_position = P1_SPAWN_POS
	active_dart.is_active = true
	active_dart.dart_stopped.connect(_on_puzzle_dart_stopped)
	add_child(active_dart)
	active_dart.create_suction_visual()
	queue_redraw()


func _on_puzzle_dart_stopped(dart: Dart) -> void:
	thrown_darts.append(dart)
	puzzle_attempts_left -= 1
	var landing_pos: Vector2 = dart.global_position
	var dist_to_target: float = landing_pos.distance_to(puzzle_target_pos)

	if dist_to_target < 28.0:
		spawn_move_badge(landing_pos, "★", "3-STAR SOLVED!", Color(1.0, 0.85, 0.2), 0)
		puzzle_stars_earned[current_puzzle_level] = 3
		if has_node("/root/SoundManager") and not is_audio_muted:
			SoundManager.play_chime()
	elif dist_to_target < 65.0:
		spawn_move_badge(landing_pos, "✓", "2-STAR CLEAR", CHESS_CYAN_BRILLIANT, 0)
		puzzle_stars_earned[current_puzzle_level] = maxi(int(puzzle_stars_earned.get(current_puzzle_level, 0)), 2)
	else:
		spawn_move_badge(landing_pos, "❌", "MISSED", Color(0.9, 0.3, 0.3), 0)

	queue_redraw()
	if puzzle_attempts_left > 0 and dist_to_target >= 28.0:
		await get_tree().create_timer(0.8).timeout
		spawn_next_puzzle_dart()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos: Vector2 = event.position
		
		# Auth Modal
		if show_auth_modal:
			if Rect2(160, 545, 400, 52).has_point(pos):
				var entered_email := auth_email_box.text.strip_edges()
				var entered_name := auth_name_box.text.strip_edges()
				if entered_email.is_empty() or not ("@" in entered_email):
					auth_error_msg = "Please enter a valid Gmail / Email!"
					queue_redraw()
					return
				if has_node("/root/ProfileManager"):
					ProfileManager.register_with_email(entered_email, entered_name)
				show_auth_modal = false
				auth_email_box.visible = false
				auth_name_box.visible = false
				auth_error_msg = ""
				queue_redraw()
				return

			if Rect2(160, 610, 400, 40).has_point(pos) or not AUTH_MODAL_RECT.has_point(pos):
				show_auth_modal = false
				auth_email_box.visible = false
				auth_name_box.visible = false
				auth_error_msg = ""
				queue_redraw()
				return
			return

		# Audio Toggle
		if Rect2(620, 16, 52, 44).has_point(pos):
			toggle_audio_mute()
			return

		# Main Menu
		if current_screen == ScreenState.MENU:
			if Rect2(140, 480, 440, 54).has_point(pos):
				show_auth_modal = true
				if has_node("/root/ProfileManager"):
					auth_email_box.text = ProfileManager.email
					auth_name_box.text = ProfileManager.username
				auth_email_box.visible = true
				auth_name_box.visible = true
				auth_email_box.grab_focus()
				auth_error_msg = ""
				queue_redraw()
				return

			if Rect2(140, 580, 440, 58).has_point(pos):
				current_game_mode = GameMode.ONLINE_HOST
				_on_host_pressed()
				queue_redraw()
				return

			if Rect2(140, 646, 140, 52).has_point(pos):
				current_game_mode = GameMode.VS_AI
				p2_name_display = "BOT MARTIN"
				p2_elo = 1420
				network_status_text = ""
				set_screen_visibility(ScreenState.GAMEPLAY)
				return

			if Rect2(290, 646, 140, 52).has_point(pos):
				current_game_mode = GameMode.TWO_PLAYER
				p2_name_display = "PLAYER 2"
				p2_elo = 1200
				network_status_text = ""
				set_screen_visibility(ScreenState.GAMEPLAY)
				return

			if Rect2(440, 646, 140, 52).has_point(pos):
				set_screen_visibility(ScreenState.PUZZLES)
				return

			if Rect2(390, 715, 190, 44).has_point(pos):
				current_game_mode = GameMode.ONLINE_CLIENT
				var entered_code: String = room_code_box.text.strip_edges()
				if entered_code.is_empty(): entered_code = "749201"
				_on_join_pressed(resolve_room_code_to_ip(entered_code))
				queue_redraw()
				return

			for i in range(6):
				var sw_pos := Vector2(175 + (i % 3) * 55, 825 + int(i / 3) * 45)
				if pos.distance_to(sw_pos) < 24.0:
					p1_color_idx = i
					queue_redraw()
					return

			for i in range(6):
				var sw_pos := Vector2(400 + (i % 3) * 55, 825 + int(i / 3) * 45)
				if pos.distance_to(sw_pos) < 24.0:
					p2_color_idx = i
					queue_redraw()
					return

		# Gameplay Screen
		elif current_screen == ScreenState.GAMEPLAY:
			# Live Flying Balloon Reaction Clicks
			for i in range(EMOJIS.size()):
				var btn_rect := Rect2(645, EMOJI_BAR_START_Y + i * 52, 50, 46)
				if btn_rect.has_point(pos):
					trigger_emoji_reaction(true, EMOJIS[i], btn_rect.get_center())
					return

			if is_game_over:
				if REMATCH_BTN_RECT.has_point(pos):
					set_screen_visibility(ScreenState.GAMEPLAY)
					return
				if MAIN_MENU_BTN_RECT.has_point(pos):
					set_screen_visibility(ScreenState.MENU)
					return
				return

			if Rect2(20, 16, 100, 44).has_point(pos):
				set_screen_visibility(ScreenState.MENU)
				return

		# Puzzles Screen
		elif current_screen == ScreenState.PUZZLES:
			for lvl in range(1, 4):
				var lvl_rect := Rect2(170 + (lvl - 1) * 130, 80, 115, 44)
				if lvl_rect.has_point(pos):
					setup_puzzle_level(lvl)
					return
			
			if Rect2(20, 16, 100, 44).has_point(pos):
				set_screen_visibility(ScreenState.MENU)
				return


func _on_host_pressed() -> void:
	if has_node("/root/NetworkManager"):
		var err = NetworkManager.create_host()
		if err == OK:
			host_room_code = generate_room_code()
			network_status_text = "ROOM CODE: %s (Waiting...)" % host_room_code
			NetworkManager.player_connected.connect(func(_id):
				var my_name := ProfileManager.username if has_node("/root/ProfileManager") and not ProfileManager.username.is_empty() else "PLAYER 1"
				var my_elo := ProfileManager.elo_rating if has_node("/root/ProfileManager") else 1200
				rpc("exchange_profile_data", my_name, my_elo)
				set_screen_visibility(ScreenState.GAMEPLAY)
			)
		else:
			network_status_text = "HOST ERROR: Port in use."


func _on_join_pressed(ip_address: String) -> void:
	if has_node("/root/NetworkManager"):
		var err = NetworkManager.join_game(ip_address)
		if err == OK:
			network_status_text = "JOINING ROOM..."
			var my_name := ProfileManager.username if has_node("/root/ProfileManager") and not ProfileManager.username.is_empty() else "PLAYER 2"
			var my_elo := ProfileManager.elo_rating if has_node("/root/ProfileManager") else 1200
			rpc("exchange_profile_data", my_name, my_elo)
			set_screen_visibility(ScreenState.GAMEPLAY)
		else:
			network_status_text = "INVALID ROOM CODE."


@rpc("any_peer", "call_remote", "reliable")
func exchange_profile_data(remote_name: String, remote_elo: int) -> void:
	p2_name_display = remote_name
	p2_elo = remote_elo
	queue_redraw()


func _process(delta: float) -> void:
	pulse_timer += delta * 4.0

	# Instagram Live Balloon Physics & Sine Wave Drift
	for b in active_reaction_balloons:
		b.elapsed += delta
		b.pos.y -= b.up_speed * delta
		var wobble: float = sin(b.elapsed * b.wobble_freq + b.wobble_seed) * b.wobble_amp
		b.render_x = b.pos.x + wobble
		
		# Fade out gently as it reaches top of screen
		if b.elapsed > 0.8:
			b.alpha = maxf(0.0, b.alpha - delta * 1.8)
	active_reaction_balloons = active_reaction_balloons.filter(func(b): return b.alpha > 0.02)

	if shake_intensity > 0.0 and is_instance_valid(main_camera):
		shake_intensity = move_toward(shake_intensity, 0.0, delta * 35.0)
		main_camera.offset = Vector2(randf_range(-shake_intensity, shake_intensity), randf_range(-shake_intensity, shake_intensity))
	elif is_instance_valid(main_camera):
		main_camera.offset = Vector2.ZERO

	if current_screen == ScreenState.MENU:
		demo_timer += delta
		_update_demo_simulation(delta)
	elif current_screen == ScreenState.GAMEPLAY:
		displayed_blue_score = move_toward(displayed_blue_score, float(blue_total_score), delta * 18.0)
		displayed_green_score = move_toward(displayed_green_score, float(green_total_score), delta * 18.0)

		if not shockwaves.is_empty():
			for sw in shockwaves:
				sw.radius += delta * 150.0
				sw.alpha = maxf(0.0, sw.alpha - delta * 2.8)
			shockwaves = shockwaves.filter(func(sw): return sw.alpha > 0.01)

		if is_game_over and not confetti_particles.is_empty():
			for p in confetti_particles:
				p.pos += p.vel * delta
				p.vel.y += 380.0 * delta
				p.rot += p.rot_speed * delta
				if p.pos.y > 1280.0:
					p.pos.y = randf_range(-40.0, 0.0)
					p.pos.x = randf_range(50.0, 670.0)
					p.vel = Vector2(randf_range(-80.0, 80.0), randf_range(120.0, 320.0))
			if is_instance_valid(victory_overlay):
				victory_overlay.queue_redraw()
	
	queue_redraw()


func trigger_camera_zoom(_landing_pos: Vector2) -> void:
	if not is_instance_valid(main_camera) or current_screen != ScreenState.GAMEPLAY:
		return
	var tween := create_tween().set_parallel(true)
	tween.tween_property(main_camera, "zoom", Vector2(1.05, 1.05), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(main_camera, "zoom", Vector2.ONE, 0.25).set_delay(0.2)


func trigger_screen_shake(amount: float = 8.0) -> void:
	shake_intensity = amount


func _update_demo_simulation(delta: float) -> void:
	var demo_target := Vector2(360, 205)

	for dart in demo_darts:
		if dart.is_flying:
			dart.t += delta * 1.6
			var t_clamped := clampf(dart.t, 0.0, 1.0)
			dart.current_pos = dart.start_pos.lerp(dart.end_pos, t_clamped)
			var h := sin(t_clamped * PI) * 55.0
			dart.render_pos = dart.current_pos - Vector2(0, h)
			dart.scale = 1.0 + sin(t_clamped * PI) * 0.6
			
			if t_clamped >= 1.0:
				dart.is_flying = false
				dart.render_pos = dart.end_pos
				dart.scale = 1.0
				demo_badges.append({
					"pos": dart.end_pos,
					"text": dart.badge_text,
					"color": dart.badge_col,
					"alpha": 1.0,
					"offset_y": 0.0
				})
				if has_node("/root/SoundManager") and not is_audio_muted:
					SoundManager.play_pop(1.0)

	for b in demo_badges:
		b.offset_y += delta * 35.0
		b.alpha = maxf(0.0, b.alpha - delta * 0.8)
	demo_badges = demo_badges.filter(func(b): return b.alpha > 0.02)

	if demo_timer > 1.8:
		demo_timer = 0.0
		if demo_darts.size() >= 4:
			demo_darts.clear()

		var is_p1 := (demo_darts.size() % 2 == 0)
		var dart_col: Color = PALETTE[p1_color_idx] if is_p1 else PALETTE[p2_color_idx]
		var spawn_x := 220.0 if is_p1 else 500.0
		
		var offset_angle := randf_range(0, TAU)
		var offset_dist := randf_range(8.0, 52.0)
		var landing := demo_target + Vector2(cos(offset_angle), sin(offset_angle)) * offset_dist
		
		var badge_str := "+3 CLOSEST"
		var badge_color := Color(1.0, 0.85, 0.2)
		if offset_dist < 18.0:
			badge_str = "!! BULLSEYE"
			badge_color = CHESS_CYAN_BRILLIANT
		elif offset_dist < 32.0:
			badge_str = "+1 STICK"
			badge_color = CHESS_GREEN_CTA

		demo_darts.append({
			"start_pos": Vector2(spawn_x, 340),
			"end_pos": landing,
			"current_pos": Vector2(spawn_x, 340),
			"render_pos": Vector2(spawn_x, 340),
			"color": dart_col,
			"t": 0.0,
			"is_flying": true,
			"scale": 1.0,
			"badge_text": badge_str,
			"badge_col": badge_color
		})


func clear_active_move_badges() -> void:
	for b in active_move_badges:
		if is_instance_valid(b):
			var tw := create_tween()
			tw.tween_property(b, "modulate:a", 0.0, 0.15)
			tw.tween_callback(b.queue_free)
	active_move_badges.clear()


func spawn_move_badge(pos: Vector2, icon_text: String, label_text: String, badge_color: Color, offset_tier: int = 0) -> void:
	for b in active_move_badges:
		if is_instance_valid(b) and b.position.distance_to(pos) < 60.0:
			var fade := create_tween()
			fade.tween_property(b, "modulate:a", 0.0, 0.1)
			fade.tween_callback(b.queue_free)

	var badge := Node2D.new()
	badge.position = pos + Vector2(0, -38.0 - (offset_tier * 42.0))
	badge.z_index = 85 + offset_tier
	add_child(badge)
	active_move_badges.append(badge)

	var bg_pill := Polygon2D.new()
	bg_pill.color = badge_color
	var pts := PackedVector2Array([
		Vector2(-65, -15), Vector2(65, -15),
		Vector2(75, 0), Vector2(65, 15),
		Vector2(-65, 15), Vector2(-75, 0)
	])
	bg_pill.polygon = pts
	badge.add_child(bg_pill)

	var lbl := Label.new()
	lbl.text = "%s %s" % [icon_text, label_text]
	lbl.position = Vector2(-75, -13)
	lbl.size = Vector2(150, 26)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08))
	badge.add_child(lbl)

	badge.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(badge, "scale", Vector2(1.12, 1.12), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(badge, "scale", Vector2.ONE, 0.08)
	tw.tween_property(badge, "position:y", badge.position.y - 35.0, 0.75)
	tw.tween_property(badge, "modulate:a", 0.0, 0.6).set_delay(0.4)
	tw.chain().tween_callback(func():
		active_move_badges.erase(badge)
		if is_instance_valid(badge):
			badge.queue_free()
	)


func draw_beveled_button(rect: Rect2, bg_col: Color, bevel_col: Color, text: String, font: Font, font_size: int = 18, is_active: bool = false, target_canvas: CanvasItem = null) -> void:
	var canvas: CanvasItem = target_canvas if target_canvas != null else self
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y + 4, rect.size.x, rect.size.y), bevel_col, true)
	canvas.draw_rect(rect, bg_col, true)
	if is_active:
		canvas.draw_rect(rect, Color(1, 1, 1, 0.85), false, 2.0)
	canvas.draw_string(font, Vector2(rect.position.x, rect.position.y + (rect.size.y / 2.0) + (font_size * 0.35)), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, font_size, Color.WHITE)


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 720, 1280), CHESS_BG_DARK, true)

	var sound_rect := Rect2(620, 16, 52, 44)
	draw_rect(sound_rect, CHESS_CARD_BG, true)
	draw_rect(sound_rect, CHESS_CARD_BORDER, false, 1.5)

	var icon_center := Vector2(646, 38)
	var icon_col := Color(0.9, 0.3, 0.35) if is_audio_muted else CHESS_GREEN_CTA
	var speaker_pts := PackedVector2Array([
		icon_center + Vector2(-12, -4),
		icon_center + Vector2(-7, -4),
		icon_center + Vector2(-1, -10),
		icon_center + Vector2(-1, 10),
		icon_center + Vector2(-7, 4),
		icon_center + Vector2(-12, 4)
	])
	draw_colored_polygon(speaker_pts, icon_col)

	if not is_audio_muted:
		draw_arc(icon_center + Vector2(-3, 0), 8.0, -PI/3.2, PI/3.2, 12, icon_col, 2.0)
		draw_arc(icon_center + Vector2(-3, 0), 13.0, -PI/3.5, PI/3.5, 12, icon_col, 2.0)
	else:
		draw_line(icon_center + Vector2(4, -8), icon_center + Vector2(14, 8), Color(1.0, 0.25, 0.25), 2.5)
		draw_line(icon_center + Vector2(14, -8), icon_center + Vector2(4, 8), Color(1.0, 0.25, 0.25), 2.5)

	# Screen 1: Homepage
	if current_screen == ScreenState.MENU:
		var hero_table_rect := Rect2(160, 75, 400, 260)
		draw_rect(hero_table_rect, Color(0.95, 0.96, 0.98), true)
		draw_rect(hero_table_rect, Color(0.24, 0.28, 0.34), false, 4.0)
		draw_string(font, Vector2(160, 130), "POPDARTS", HORIZONTAL_ALIGNMENT_CENTER, 400, 26, Color(0.12, 0.16, 0.22, 0.20))

		var hero_marker := Vector2(360, 205)
		var wave_pulse := (sin(pulse_timer * 1.5) + 1.0) * 0.5
		draw_arc(hero_marker, 42.0, 0, TAU, 32, Color(1.0, 0.5, 0.0, 0.35), 2.0)
		draw_arc(hero_marker, 78.0 + wave_pulse * 8.0, 0, TAU, 32, Color(1.0, 0.5, 0.0, 0.2), 1.5)
		draw_circle(hero_marker, 16.0, Color(1.0, 0.5, 0.0))

		for dart in demo_darts:
			if dart.is_flying:
				draw_circle(dart.current_pos + Vector2(0, 8), 10.0 * (2.0 - dart.scale), Color(0, 0, 0, 0.25))
			draw_circle(dart.render_pos, 13.0 * dart.scale, dart.color)
			draw_circle(dart.render_pos, 4.5 * dart.scale, Color.WHITE)

		for b in demo_badges:
			var c: Color = b.color
			c.a = b.alpha
			draw_rect(Rect2(b.pos.x - 55, b.pos.y - 32 - b.offset_y, 110, 24), Color(0.1, 0.1, 0.1, b.alpha * 0.85), true)
			draw_rect(Rect2(b.pos.x - 55, b.pos.y - 32 - b.offset_y, 110, 24), c, false, 1.5)
			draw_string(font, Vector2(b.pos.x - 55, b.pos.y - 16 - b.offset_y), b.text, HORIZONTAL_ALIGNMENT_CENTER, 110, 11, c)

		draw_string(font, Vector2(40, 380), "Play PopDarts Online", HORIZONTAL_ALIGNMENT_CENTER, 640, 32, Color.WHITE)
		draw_string(font, Vector2(40, 415), "on the #1 Target Arena!", HORIZONTAL_ALIGNMENT_CENTER, 640, 28, Color(0.85, 0.75, 0.3))
		draw_string(font, Vector2(40, 452), "Join 250M+ throws in the world's largest silicone dart community", HORIZONTAL_ALIGNMENT_CENTER, 640, 13, Color(0.68, 0.72, 0.76))

		var my_email := ProfileManager.email if has_node("/root/ProfileManager") else ""
		var my_id := ProfileManager.player_id if has_node("/root/ProfileManager") else ""
		var my_name := ProfileManager.username if has_node("/root/ProfileManager") else ""
		var my_elo := ProfileManager.elo_rating if has_node("/root/ProfileManager") else 1200
		
		var id_card := Rect2(140, 480, 440, 54)
		var cta_pulse := (sin(pulse_timer * 2.0) + 1.0) * 0.5
		draw_rect(id_card, Color(0.16, 0.18, 0.22), true)
		draw_rect(id_card, Color(0.3, 0.75, 1.0, lerpf(0.6, 1.0, cta_pulse)), false, 2.0)
		draw_circle(Vector2(168, 507), 14.0, PALETTE[p1_color_idx])

		if my_email.is_empty():
			draw_string(font, Vector2(192, 513), "✉ Enter Gmail to Create Account ▶", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.9, 0.3))
			draw_string(font, Vector2(480, 513), "FREE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 1.0, 0.5))
		else:
			draw_string(font, Vector2(192, 513), "%s  (%s)" % [my_name, my_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			draw_string(font, Vector2(460, 513), "★ %d ELO ✎" % my_elo, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.3, 1.0, 0.5))

		if network_status_text != "":
			draw_string(font, Vector2(140, 555), network_status_text, HORIZONTAL_ALIGNMENT_CENTER, 440, 13, Color(1.0, 0.85, 0.2))

		var pulse := (sin(pulse_timer) + 1.0) * 0.5
		draw_beveled_button(Rect2(140, 580, 440, 58), CHESS_GREEN_CTA.lightened(pulse * 0.08), CHESS_GREEN_BEVEL, "🌐 CREATE ROOM CODE ▶", font, 20)

		draw_beveled_button(Rect2(140, 646, 140, 52), Color(0.22, 0.21, 0.20), Color(0.14, 0.13, 0.12), "🤖 VS BOT", font, 14)
		draw_beveled_button(Rect2(290, 646, 140, 52), Color(0.22, 0.21, 0.20), Color(0.14, 0.13, 0.12), "👥 2-PLAYER", font, 14)
		draw_beveled_button(Rect2(440, 646, 140, 52), Color(0.28, 0.22, 0.35), Color(0.18, 0.14, 0.24), "🧩 PUZZLES", font, 14)

		draw_beveled_button(Rect2(390, 715, 190, 44), Color(0.28, 0.45, 0.65), Color(0.18, 0.30, 0.45), "ENTER CODE ▶", font, 14)

		draw_string(font, Vector2(140, 795), "PLAYER 1 COLOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PALETTE[p1_color_idx])
		for i in range(6):
			var sw_pos := Vector2(175 + (i % 3) * 55, 825 + int(i / 3) * 45)
			draw_circle(sw_pos, 16.0, PALETTE[i])
			if p1_color_idx == i: draw_arc(sw_pos, 20.0, 0, TAU, 24, Color.WHITE, 2.5)

		draw_string(font, Vector2(365, 795), "PLAYER 2 COLOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PALETTE[p2_color_idx])
		for i in range(6):
			var sw_pos := Vector2(400 + (i % 3) * 55, 825 + int(i / 3) * 45)
			draw_circle(sw_pos, 16.0, PALETTE[i])
			if p2_color_idx == i: draw_arc(sw_pos, 20.0, 0, TAU, 24, Color.WHITE, 2.5)

		if show_auth_modal:
			draw_rect(Rect2(0, 0, 720, 1280), Color(0.05, 0.05, 0.05, 0.85), true)
			draw_rect(AUTH_MODAL_RECT, CHESS_CARD_BG, true)
			draw_rect(AUTH_MODAL_RECT, CHESS_GREEN_CTA, false, 3.0)
			draw_string(font, Vector2(110, 255), "✉ POPDARTS ACCOUNT", HORIZONTAL_ALIGNMENT_CENTER, 500, 24, Color.WHITE)
			draw_string(font, Vector2(110, 290), "Enter your Gmail to save stats & play online", HORIZONTAL_ALIGNMENT_CENTER, 500, 13, Color(0.65, 0.7, 0.75))
			draw_string(font, Vector2(160, 355), "GMAIL / EMAIL ADDRESS *", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.75, 0.3))
			draw_string(font, Vector2(160, 442), "DISPLAY USERNAME (OPTIONAL)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.75, 0.3))
			if auth_error_msg != "": draw_string(font, Vector2(110, 525), auth_error_msg, HORIZONTAL_ALIGNMENT_CENTER, 500, 12, Color(1.0, 0.35, 0.35))
			draw_beveled_button(Rect2(160, 545, 400, 52), CHESS_GREEN_CTA, CHESS_GREEN_BEVEL, "CREATE & LINK ACCOUNT ✓", font, 16)
			draw_beveled_button(Rect2(160, 610, 400, 40), Color(0.24, 0.23, 0.21), Color(0.14, 0.13, 0.12), "CANCEL", font, 13)
		return

	var menu_btn := Rect2(20, 16, 100, 44)
	draw_rect(menu_btn, CHESS_CARD_BG, true)
	draw_rect(menu_btn, CHESS_CARD_BORDER, false, 1.5)
	draw_string(font, Vector2(20, 44), "◀ MENU", HORIZONTAL_ALIGNMENT_CENTER, 100, 14, Color(0.8, 0.85, 0.9))

	# Screen 2: Gameplay Arena
	if current_screen == ScreenState.GAMEPLAY:
		var active_name := ProfileManager.username if has_node("/root/ProfileManager") and not ProfileManager.username.is_empty() else "PLAYER 1"
		var active_elo := ProfileManager.elo_rating if has_node("/root/ProfileManager") else 1200

		var p1_active := (current_team == Dart.Team.BLUE and darts_thrown_count < DARTS_PER_ROUND and not is_game_over)
		var p1_card := Rect2(130, 12, 220, 56)
		draw_rect(p1_card, CHESS_CARD_BG, true)
		draw_rect(p1_card, PALETTE[p1_color_idx] if p1_active else CHESS_CARD_BORDER, false, 2.5 if p1_active else 1.0)
		draw_circle(Vector2(160, 40), 16.0, PALETTE[p1_color_idx])
		draw_string(font, Vector2(185, 34), active_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(font, Vector2(185, 52), "(%d) 🏆 %d" % [active_elo, int(round(displayed_blue_score))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.75, 0.8))

		var p2_active := (current_team == Dart.Team.GREEN and darts_thrown_count < DARTS_PER_ROUND and not is_game_over)
		var p2_card := Rect2(370, 12, 220, 56)
		draw_rect(p2_card, CHESS_CARD_BG, true)
		draw_rect(p2_card, PALETTE[p2_color_idx] if p2_active else CHESS_CARD_BORDER, false, 2.5 if p2_active else 1.0)
		draw_circle(Vector2(400, 40), 16.0, PALETTE[p2_color_idx])
		draw_string(font, Vector2(425, 34), p2_name_display, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		draw_string(font, Vector2(425, 52), "(%d) 🏆 %d" % [p2_elo, int(round(displayed_green_score))], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.7, 0.75, 0.8))

		# Bottom-Right Mobile Quick Emoji Bar
		for i in range(EMOJIS.size()):
			var e_rect := Rect2(645, EMOJI_BAR_START_Y + i * 52, 50, 46)
			draw_rect(e_rect, CHESS_CARD_BG, true)
			draw_rect(e_rect, CHESS_CARD_BORDER, false, 1.5)
			draw_string(font, Vector2(645, EMOJI_BAR_START_Y + 30 + i * 52), EMOJIS[i], HORIZONTAL_ALIGNMENT_CENTER, 50, 22, Color.WHITE)

	# Screen 3: Trickshot Puzzles Map
	elif current_screen == ScreenState.PUZZLES:
		for lvl in range(1, 4):
			var is_selected: bool = (lvl == current_puzzle_level)
			var stars: int = int(puzzle_stars_earned.get(lvl, 0))
			var star_str: String = "★★★" if stars == 3 else ("★★☆" if stars == 2 else ("★☆☆" if stars == 1 else "☆☆☆"))
			var l_rect: Rect2 = Rect2(170 + (lvl - 1) * 130, 80, 115, 44)
			draw_beveled_button(l_rect, CHESS_GREEN_CTA if is_selected else Color(0.2, 0.19, 0.18), CHESS_GREEN_BEVEL if is_selected else Color(0.14, 0.13, 0.12), "LVL %d %s" % [lvl, star_str], font, 11, is_selected)
		
		for obs in puzzle_obstacles:
			draw_rect(obs, Color(0.85, 0.3, 0.25), true)
			draw_rect(obs, Color(1.0, 0.5, 0.4), false, 2.0)

	# Instagram Live Flying Balloon Reaction Rendering
	for b in active_reaction_balloons:
		var c: Color = Color.WHITE
		c.a = b.alpha
		var rx: float = b.render_x if "render_x" in b else b.pos.x
		var ry: float = b.pos.y
		
		# Translucent bubble backing
		draw_circle(Vector2(rx, ry), 24.0 * b.scale, Color(0.18, 0.22, 0.28, b.alpha * 0.9))
		draw_arc(Vector2(rx, ry), 24.0 * b.scale, 0, TAU, 24, Color(1.0, 0.85, 0.2, b.alpha * 0.8), 2.0)
		draw_string(font, Vector2(rx - 24, ry + 8), b.emoji, HORIZONTAL_ALIGNMENT_CENTER, 48, int(20 * b.scale), c)

	draw_rect(TABLE_RECT, Color(0.25, 0.28, 0.32), false, 5.0)
	for ring_pos in suction_ring_decals:
		draw_arc(ring_pos, 14.0, 0, TAU, 24, Color(0.1, 0.15, 0.22, 0.14), 2.5)

	var marker_pos := puzzle_target_pos if current_screen == ScreenState.PUZZLES else ORANGE_MARKER_POS
	draw_arc(marker_pos, 75.0, 0, TAU, 32, Color(1.0, 0.5, 0.0, 0.35), 2.0)
	draw_arc(marker_pos, 140.0, 0, TAU, 32, Color(1.0, 0.5, 0.0, 0.2), 1.5)
	draw_line(Vector2(TABLE_RECT.position.x, FOUL_LINE_Y), Vector2(TABLE_RECT.position.x + TABLE_RECT.size.x, FOUL_LINE_Y), Color(0.85, 0.2, 0.2, 0.9), 3.5)

	var pulse_glow := (sin(pulse_timer) + 1.0) * 0.5
	var p1_col: Color = PALETTE[p1_color_idx]
	draw_rect(P1_MAT_RECT, CHESS_CARD_BG, true)
	draw_rect(P1_MAT_RECT, p1_col, false, 2.5)
	draw_string(font, Vector2(P1_MAT_RECT.position.x + 15, P1_MAT_RECT.position.y + 30), "P1 PODIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, p1_col)
	draw_arc(P1_SPAWN_POS, 26.0 + pulse_glow * 4.0, 0, TAU, 28, Color(p1_col.r, p1_col.g, p1_col.b, 0.45), 2.0)

	if current_screen == ScreenState.GAMEPLAY:
		var p2_col: Color = PALETTE[p2_color_idx]
		draw_rect(P2_MAT_RECT, CHESS_CARD_BG, true)
		draw_rect(P2_MAT_RECT, p2_col, false, 2.5)
		draw_string(font, Vector2(P2_MAT_RECT.position.x + 15, P2_MAT_RECT.position.y + 30), "P2 PODIUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, p2_col)
		draw_arc(P2_SPAWN_POS, 26.0 + pulse_glow * 4.0, 0, TAU, 28, Color(p2_col.r, p2_col.g, p2_col.b, 0.45), 2.0)

	for sw in shockwaves:
		var c: Color = sw.color
		c.a = sw.alpha
		draw_arc(sw.pos, sw.radius, 0, TAU, 28, c, 3.5)

	if show_measurement_line:
		draw_dashed_line(measure_start, measure_end, CHESS_CYAN_BRILLIANT, 3.5, 8.0)
		draw_circle(measure_start, 5.0, CHESS_CYAN_BRILLIANT)
		draw_circle(measure_end, 5.0, CHESS_CYAN_BRILLIANT)


func _on_victory_overlay_draw() -> void:
	if not is_game_over or current_screen != ScreenState.GAMEPLAY:
		return

	var font := ThemeDB.fallback_font
	victory_overlay.draw_rect(Rect2(0, 0, 720, 1280), Color(0.08, 0.07, 0.06, 0.85), true)

	for p in confetti_particles:
		var pts := PackedVector2Array([
			p.pos + Vector2(-p.size.x, -p.size.y).rotated(p.rot),
			p.pos + Vector2(p.size.x, -p.size.y).rotated(p.rot),
			p.pos + Vector2(p.size.x, p.size.y).rotated(p.rot),
			p.pos + Vector2(-p.size.x, p.size.y).rotated(p.rot)
		])
		victory_overlay.draw_colored_polygon(pts, p.color)

	victory_overlay.draw_rect(MODAL_RECT, CHESS_CARD_BG, true)
	victory_overlay.draw_rect(MODAL_RECT, winner_color, false, 3.5)

	victory_overlay.draw_string(font, Vector2(140, 425), "🏆 MATCH WINNER 🏆", HORIZONTAL_ALIGNMENT_CENTER, 440, 24, Color(1.0, 0.85, 0.2))
	victory_overlay.draw_string(font, Vector2(140, 480), winner_name, HORIZONTAL_ALIGNMENT_CENTER, 440, 36, winner_color)
	victory_overlay.draw_string(font, Vector2(140, 535), victory_rating_text, HORIZONTAL_ALIGNMENT_CENTER, 440, 16, Color(0.8, 0.85, 0.9))

	draw_beveled_button(REMATCH_BTN_RECT, CHESS_GREEN_CTA, CHESS_GREEN_BEVEL, "PLAY AGAIN ▶", font, 20, false, victory_overlay)
	draw_beveled_button(MAIN_MENU_BTN_RECT, Color(0.24, 0.23, 0.21), Color(0.15, 0.14, 0.13), "MAIN MENU", font, 16, false, victory_overlay)


func trigger_victory(winner_str: String, win_col: Color, rating_txt: String = "") -> void:
	is_game_over = true
	winner_name = winner_str
	winner_color = win_col
	victory_rating_text = rating_txt
	
	if is_instance_valid(active_dart): active_dart.queue_free()
	if is_instance_valid(round_result_label): round_result_label.text = ""

	confetti_particles.clear()
	for i in range(85):
		confetti_particles.append({
			"pos": Vector2(randf_range(80, 640), randf_range(-60, 480)),
			"vel": Vector2(randf_range(-140, 140), randf_range(120, 380)),
			"size": Vector2(randf_range(8, 14), randf_range(5, 9)),
			"rot": randf_range(0, TAU),
			"rot_speed": randf_range(-8.0, 8.0),
			"color": PALETTE[randi() % PALETTE.size()]
		})
	
	if has_node("/root/SoundManager"): SoundManager.play_chime()
	if is_instance_valid(victory_overlay): victory_overlay.queue_redraw()


func trigger_shockwave(pos: Vector2, color: Color) -> void:
	shockwaves.append({"pos": pos, "radius": 14.0, "alpha": 0.9, "color": color})


func spawn_next_dart() -> void:
	if current_screen != ScreenState.GAMEPLAY or is_game_over:
		return

	if darts_thrown_count >= DARTS_PER_ROUND:
		end_round_and_score()
		return

	var dart_instance: Dart = dart_scene.instantiate() as Dart
	active_dart = dart_instance
	active_dart.team = current_team
	active_dart.custom_color = PALETTE[p1_color_idx] if current_team == Dart.Team.BLUE else PALETTE[p2_color_idx]
	active_dart.global_position = P1_SPAWN_POS if current_team == Dart.Team.BLUE else P2_SPAWN_POS
	active_dart.is_active = true
	active_dart.dart_stopped.connect(_on_dart_stopped)
	
	add_child(active_dart)
	active_dart.create_suction_visual()
	queue_redraw()

	if current_game_mode == GameMode.VS_AI and current_team == Dart.Team.GREEN:
		perform_ai_throw()


func perform_ai_throw() -> void:
	await get_tree().create_timer(0.7).timeout
	if not is_instance_valid(active_dart) or not active_dart.is_active or is_game_over:
		return

	var aim_target: Vector2 = target_marker.global_position if is_instance_valid(target_marker) else ORANGE_MARKER_POS
	if tower_claimed_by == null and randf() < 0.18:
		aim_target = tower.global_position if is_instance_valid(tower) else TOWER_POS

	var inaccuracy: Vector2 = Vector2(randf_range(-38, 38), randf_range(-45, 45))
	var final_landing_target: Vector2 = aim_target + inaccuracy

	var desired_throw_vector: Vector2 = (final_landing_target - active_dart.global_position) / active_dart.throw_multiplier
	var simulated_pull: Vector2 = desired_throw_vector.limit_length(active_dart.max_drag_distance)

	active_dart.drag_start_pos = active_dart.global_position
	active_dart.current_drag_pos = active_dart.global_position - simulated_pull
	active_dart.launch()


func _resolve_dart_collisions(incoming_dart: Dart) -> int:
	var incoming_pos: Vector2 = incoming_dart.global_position
	var deflections_count: int = 0

	for other_dart in thrown_darts:
		if other_dart == incoming_dart or not is_instance_valid(other_dart):
			continue
		if not TABLE_RECT.has_point(other_dart.global_position):
			continue
		
		var dist: float = incoming_pos.distance_to(other_dart.global_position)
		if dist < 18.0:
			deflections_count += 1
			var push_dir: Vector2 = (other_dart.global_position - incoming_pos).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			
			var push_force: float = randf_range(30.0, 50.0)
			var new_dart_pos: Vector2 = other_dart.global_position + push_dir * push_force
			
			var dart_tween := create_tween().set_parallel(true)
			dart_tween.tween_property(other_dart, "global_position", new_dart_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if is_instance_valid(other_dart.visual_container):
				dart_tween.tween_property(other_dart.visual_container, "rotation", randf_range(-0.45, 0.45), 0.15)
				dart_tween.chain().tween_property(other_dart.visual_container, "rotation", 0.0, 0.1)
			
			spawn_move_badge(other_dart.global_position, "💥", "DEFLECT!", Color(0.95, 0.4, 0.3), deflections_count)

	return deflections_count


func _on_dart_stopped(dart: Dart) -> void:
	thrown_darts.append(dart)
	darts_thrown_count += 1
	
	var landing_pos: Vector2 = dart.global_position
	var is_on_table: bool = TABLE_RECT.has_point(landing_pos) and landing_pos.y <= FOUL_LINE_Y
	var team_color: Color = PALETTE[p1_color_idx] if dart.team == Dart.Team.BLUE else PALETTE[p2_color_idx]
	var target_pos: Vector2 = target_marker.global_position if is_instance_valid(target_marker) else ORANGE_MARKER_POS
	var tower_pos: Vector2 = tower.global_position if is_instance_valid(tower) else TOWER_POS

	if not is_on_table:
		dart.is_stuck = false
		spawn_move_badge(landing_pos, "❌", "MISS", Color(0.8, 0.3, 0.3), 0)
		if dart.team == Dart.Team.BLUE and has_node("/root/ProfileManager"):
			ProfileManager.record_throw_performance("MISS")
		if is_instance_valid(dart.visual_container):
			var tw := create_tween()
			tw.tween_property(dart.visual_container, "modulate:a", 0.35, 0.25)
	else:
		suction_ring_decals.append(landing_pos)
		var _deflections := _resolve_dart_collisions(dart)
		trigger_shockwave(landing_pos, team_color)

		if tower_claimed_by == null and landing_pos.distance_to(tower_pos) < 18.0:
			tower_claimed_by = dart
			dart.global_position = tower_pos
			spawn_move_badge(dart.global_position, "!!", "BRILLIANT", CHESS_CYAN_BRILLIANT, 0)
			if dart.team == Dart.Team.BLUE and has_node("/root/ProfileManager"):
				ProfileManager.record_throw_performance("BRILLIANT")
			if has_node("/root/SoundManager"):
				SoundManager.play_chime()
			
			if current_game_mode == GameMode.VS_AI:
				trigger_emoji_reaction(false, "😱")
				
		elif landing_pos.distance_to(target_pos) < 32.0:
			spawn_move_badge(landing_pos, "★", "BULLSEYE", Color(1.0, 0.85, 0.2), 0)
			if dart.team == Dart.Team.BLUE and has_node("/root/ProfileManager"):
				ProfileManager.record_throw_performance("BULLSEYE")
			if has_node("/root/SoundManager"):
				SoundManager.play_chime()
		else:
			spawn_move_badge(landing_pos, "✓", "GOOD", CHESS_GREEN_CTA, 0)
			if dart.team == Dart.Team.BLUE and has_node("/root/ProfileManager"):
				ProfileManager.record_throw_performance("STICK")

	current_team = Dart.Team.GREEN if current_team == Dart.Team.BLUE else Dart.Team.BLUE
	queue_redraw()

	await get_tree().create_timer(0.4).timeout
	spawn_next_dart()


func end_round_and_score() -> void:
	if thrown_darts.is_empty():
		return

	var target_pos: Vector2 = target_marker.global_position if is_instance_valid(target_marker) else ORANGE_MARKER_POS
	var closest_dart: Dart = null
	var min_distance: float = INF
	
	for dart in thrown_darts:
		if not is_instance_valid(dart) or not dart.is_stuck: continue
		if dart == tower_claimed_by: continue
		if not TABLE_RECT.has_point(dart.global_position) or dart.global_position.y > FOUL_LINE_Y: continue

		var dist: float = dart.global_position.distance_to(target_pos)
		if dist < min_distance:
			min_distance = dist
			closest_dart = dart

	if closest_dart != null:
		clear_active_move_badges()
		measure_start = target_pos
		measure_end = closest_dart.global_position
		show_measurement_line = true
		queue_redraw()
		spawn_move_badge(closest_dart.global_position, "★", "+3 CLOSEST", Color(1.0, 0.85, 0.2), 0)

	var blue_round_pts: int = 0
	var green_round_pts: int = 0

	for dart in thrown_darts:
		if is_instance_valid(dart) and dart.is_stuck:
			if not TABLE_RECT.has_point(dart.global_position) or dart.global_position.y > FOUL_LINE_Y:
				continue
				
			var pts: int = 0
			if dart == tower_claimed_by: pts += 10
			else:
				pts += 3 if dart == closest_dart else 1
				if dart.global_position.distance_to(target_pos) < 32.0: pts += 1
			
			if dart.team == Dart.Team.BLUE: blue_round_pts += pts
			else: green_round_pts += pts

	var round_summary: String = ""
	if blue_round_pts > green_round_pts:
		var diff: int = blue_round_pts - green_round_pts
		blue_total_score += diff
		var p1_title := ProfileManager.username if has_node("/root/ProfileManager") and not ProfileManager.username.is_empty() else "P1"
		round_summary = "%s wins round! (+%d pts)\n(%s: %d - P2: %d)" % [p1_title, diff, p1_title, blue_round_pts, green_round_pts]
		current_team = Dart.Team.BLUE
	elif green_round_pts > blue_round_pts:
		var diff: int = green_round_pts - blue_round_pts
		green_total_score += diff
		round_summary = "%s wins round! (+%d pts)\n(%s: %d - P1: %d)" % [p2_name_display, diff, p2_name_display, green_round_pts, blue_round_pts]
		current_team = Dart.Team.GREEN
	else:
		round_summary = "Round Tied! (0 pts awarded)\n(Both scored %d)" % blue_round_pts

	round_result_label.text = round_summary

	if blue_total_score >= 21 or green_total_score >= 21:
		var p1_won: bool = (blue_total_score >= 21)
		var p1_name := ProfileManager.username if has_node("/root/ProfileManager") and not ProfileManager.username.is_empty() else "PLAYER 1"
		var champ: String = p1_name if p1_won else p2_name_display
		var champ_color: Color = PALETTE[p1_color_idx] if p1_won else PALETTE[p2_color_idx]
		
		var elo_delta: int = 0
		if has_node("/root/ProfileManager"):
			elo_delta = ProfileManager.calculate_match_elo_change(blue_total_score, green_total_score, p2_elo, p1_won)

		var sign_str := "+" if elo_delta > 0 else ""
		var rating_summary := "RATING: %s%d Elo (Now %d)\nFINAL SCORE: P1: %d  |  P2: %d" % [
			sign_str,
			elo_delta,
			ProfileManager.elo_rating if has_node("/root/ProfileManager") else 1200,
			blue_total_score,
			green_total_score
		]

		await get_tree().create_timer(1.2).timeout
		trigger_victory(champ, champ_color, rating_summary)
		return

	await get_tree().create_timer(3.8).timeout
	reset_for_new_round()


func clear_all_darts() -> void:
	if is_instance_valid(active_dart): active_dart.queue_free()
	for dart in thrown_darts:
		if is_instance_valid(dart): dart.queue_free()
	thrown_darts.clear()
	suction_ring_decals.clear()
	clear_active_move_badges()


func reset_for_new_round() -> void:
	show_measurement_line = false
	suction_ring_decals.clear()
	clear_all_darts()
	
	tower_claimed_by = null
	darts_thrown_count = 0
	if is_instance_valid(round_result_label): round_result_label.text = ""
	spawn_next_dart()


func send_network_throw(clamped_vector: Vector2) -> void:
	if current_game_mode == GameMode.ONLINE_HOST or current_game_mode == GameMode.ONLINE_CLIENT:
		if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			rpc("sync_remote_launch", clamped_vector)


@rpc("any_peer", "call_remote", "reliable")
func sync_remote_launch(synced_vector: Vector2) -> void:
	if is_instance_valid(active_dart) and active_dart.is_active:
		active_dart.execute_launch(synced_vector)
