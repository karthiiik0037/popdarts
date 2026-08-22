extends Node

const DEFAULT_PORT: int = 8910
const MAX_CLIENTS: int = 2

var peer: ENetMultiplayerPeer = null
var is_host: bool = false
var opponent_id: int = 0

signal player_connected(peer_id: int)
signal server_disconnected


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func reset_connection() -> void:
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_host = false
	opponent_id = 0


func create_host(port: int = DEFAULT_PORT) -> Error:
	reset_connection()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, MAX_CLIENTS)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = true
	return error


func join_game(ip: String, port: int = DEFAULT_PORT) -> Error:
	reset_connection()
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(ip, port)
	if error == OK:
		multiplayer.multiplayer_peer = peer
		is_host = false
	return error


func _on_peer_connected(id: int) -> void:
	opponent_id = id
	player_connected.emit(id)


func _on_peer_disconnected(_id: int) -> void:
	opponent_id = 0
	server_disconnected.emit()


func _on_server_disconnected() -> void:
	reset_connection()
	server_disconnected.emit()
