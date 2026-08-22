extends Node

var pop_player: AudioStreamPlayer
var swoosh_player: AudioStreamPlayer
var chime_player: AudioStreamPlayer


func _ready() -> void:
	pop_player = AudioStreamPlayer.new()
	swoosh_player = AudioStreamPlayer.new()
	chime_player = AudioStreamPlayer.new()
	
	add_child(pop_player)
	add_child(swoosh_player)
	add_child(chime_player)


# Modeled precisely after #1 Bubble/Cork Pop sound
func play_pop(pitch_scale: float = 1.0) -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.12
	pop_player.stream = gen
	pop_player.pitch_scale = pitch_scale
	pop_player.play()
	
	var playback: AudioStreamGeneratorPlayback = pop_player.get_stream_playback()
	if playback:
		var duration: float = 0.055 # Short 55ms crisp pop
		var sample_count: int = int(44100 * duration)
		var phase: float = 0.0
		
		for i in range(sample_count):
			var t: float = float(i) / float(sample_count)
			
			# Fast upward cork-pop pitch bend (320Hz -> 860Hz -> 540Hz)
			var freq: float = 320.0 + sin(t * PI) * 540.0
			phase += (freq * TAU) / 44100.0
			
			# Pure resonant sine wave with subtle second harmonic
			var tone: float = sin(phase) + sin(phase * 2.0) * 0.18
			
			# Smooth bell-curve attack with fast exponential decay
			var envelope: float = sin(pow(t, 0.4) * PI) * exp(-t * 7.5)
			
			var final_sample: float = clampf(tone * envelope * 0.95, -1.0, 1.0)
			playback.push_frame(Vector2(final_sample, final_sample))


func play_swoosh() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.18
	swoosh_player.stream = gen
	swoosh_player.play()
	
	var playback: AudioStreamGeneratorPlayback = swoosh_player.get_stream_playback()
	if playback:
		var duration: float = 0.14
		var sample_count: int = int(44100 * duration)
		for i in range(sample_count):
			var t: float = float(i) / float(sample_count)
			var noise: float = randf_range(-1.0, 1.0)
			var envelope: float = sin(t * PI) * 0.35
			var sample: float = noise * envelope
			playback.push_frame(Vector2(sample, sample))


func play_chime() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.4
	chime_player.stream = gen
	chime_player.play()
	
	var playback: AudioStreamGeneratorPlayback = chime_player.get_stream_playback()
	if playback:
		var sample_count: int = int(44100 * 0.35)
		for i in range(sample_count):
			var t: float = float(i) / 44100.0
			var decay: float = exp(-t * 9.0)
			var sample: float = (sin(t * TAU * 1174.6) + sin(t * TAU * 1479.9) * 0.6) * decay * 0.65
			playback.push_frame(Vector2(sample, sample))
