extends Node

const SAVE_PATH: String = "user://player_profile.json"

var player_id: String = ""
var email: String = ""
var username: String = ""
var elo_rating: int = 1200
var matches_won: int = 0
var matches_played: int = 0

# Match Performance Analytics
var round_bullseyes: int = 0
var round_brilliants: int = 0
var round_deflections: int = 0
var round_misses: int = 0
var round_total_throws: int = 0


func _ready() -> void:
	load_profile()


func generate_unique_id() -> String:
	return "PD-%04d" % [randi() % 10000]


func reset_match_analytics() -> void:
	round_bullseyes = 0
	round_brilliants = 0
	round_deflections = 0
	round_misses = 0
	round_total_throws = 0


func record_throw_performance(quality_badge: String) -> void:
	round_total_throws += 1
	match quality_badge:
		"BRILLIANT":
			round_brilliants += 1
		"BULLSEYE":
			round_bullseyes += 1
		"DEFLECT":
			round_deflections += 1
		"MISS":
			round_misses += 1


func calculate_match_elo_change(my_score: int, opponent_score: int, opponent_elo: int, won_match: bool) -> int:
	matches_played += 1
	if won_match:
		matches_won += 1

	# Expected probability (Standard Elo equation)
	var expected_score: float = 1.0 / (1.0 + pow(10.0, float(opponent_elo - elo_rating) / 400.0))
	var actual_score: float = 1.0 if won_match else 0.0
	
	var k_factor: float = 32.0
	if matches_played < 10:
		k_factor = 48.0

	var base_elo_delta: float = k_factor * (actual_score - expected_score)

	# Tactical accuracy bonus/penalty
	var tactical_points: float = (round_bullseyes * 3.0) + (round_brilliants * 5.0) + (round_deflections * 2.0) - (round_misses * 3.0)
	var tactical_modifier: float = clampf(tactical_points * 0.8, -12.0, 15.0)

	# Score margin modifier
	var score_margin: int = my_score - opponent_score
	var margin_modifier: float = clampf(float(score_margin) * 0.6, -8.0, 8.0)

	var final_delta: int = int(round(base_elo_delta + tactical_modifier + margin_modifier))

	if won_match and final_delta <= 0:
		final_delta = 2
	elif not won_match and final_delta >= 0:
		final_delta = -2

	elo_rating = clampi(elo_rating + final_delta, 100, 3000)
	save_profile()
	
	return final_delta


func register_with_email(new_email: String, custom_name: String = "") -> void:
	email = new_email.strip_edges().to_lower()
	if custom_name.strip_edges().is_empty():
		var prefix := email.split("@")[0]
		username = prefix.capitalize().replace(" ", "_")
	else:
		username = custom_name.strip_edges()
	
	if player_id.is_empty():
		player_id = generate_unique_id()
		
	save_profile()


func save_profile() -> void:
	var data := {
		"player_id": player_id,
		"email": email,
		"username": username,
		"elo_rating": elo_rating,
		"matches_won": matches_won,
		"matches_played": matches_played
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json_text := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			player_id = parsed.get("player_id", "")
			email = parsed.get("email", "")
			username = parsed.get("username", "")
			elo_rating = parsed.get("elo_rating", 1200)
			matches_won = parsed.get("matches_won", 0)
			matches_played = parsed.get("matches_played", 0)
