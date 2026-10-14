extends Node3D

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")

var players: Dictionary = {}
var player_chars: Dictionary = {}

func _ready() -> void:
	Networking.host_created.connect(on_host_created)
	Networking.client_connected.connect(on_client_connected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(remove_player)
	$UI/HostButton.pressed.connect(_on_host_pressed)
	$UI/QuitButton.pressed.connect(_on_quit_pressed)

func on_host_created() -> void:
	$UI/StatusLabel.text = "Hosting - ID: %d" % multiplayer.get_unique_id()
	player_chars[multiplayer.get_unique_id()] = GameSession.selected_character
	spawn_player_local(multiplayer.get_unique_id())

func on_client_connected() -> void:
	$UI/StatusLabel.text = "Connected - ID: %d" % multiplayer.get_unique_id()
	register_player.rpc_id(1, GameSession.selected_character)

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Peer connected: ", peer_id)

@rpc("any_peer", "reliable")
func register_player(char_path: String) -> void:
	if not multiplayer.is_server():
		return
	var caller_id := multiplayer.get_remote_sender_id()
	if caller_id in players:
		return
	print("Client %d registered: %s" % [caller_id, char_path])
	var existing := players.keys()
	player_chars[caller_id] = char_path
	spawn_player_rpc.rpc(caller_id, char_path)
	for id in existing:
		spawn_player_rpc.rpc_id(caller_id, id, player_chars.get(id, ""))
	spawn_player_rpc.rpc_id(caller_id, caller_id, char_path)

@rpc("authority", "call_local", "reliable")
func spawn_player_rpc(peer_id: int, char_path: String) -> void:
	if peer_id in players:
		return
	print("Spawning player: ", peer_id)
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.character_path = char_path
	player.position = spawn_position(peer_id)
	add_child(player)
	players[peer_id] = player

func spawn_player_local(peer_id: int) -> void:
	if peer_id in players:
		return
	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.character_path = GameSession.selected_character
	player.position = spawn_position(peer_id)
	add_child(player)
	players[peer_id] = player

func spawn_position(peer_id: int) -> Vector3:
	return Vector3((peer_id % 4) * 2.0 - 2.0, 0.1, (peer_id / 4) * 2.0)

func remove_player(peer_id: int) -> void:
	if peer_id in players:
		players[peer_id].queue_free()
		players.erase(peer_id)
		player_chars.erase(peer_id)
		print("Removed player: ", peer_id)

func _on_host_pressed() -> void:
	Networking.host_lobby()

func _on_quit_pressed() -> void:
	get_tree().quit()
