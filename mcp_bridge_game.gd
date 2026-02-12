extends Node

const DEFAULT_PORT := 9501

var port := DEFAULT_PORT
var tcp_server: TCPServer
var clients: Array[StreamPeerTCP] = []
var pending_screenshot_client: StreamPeerTCP = null
var _deferred_release: Vector2 = Vector2.ZERO


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("res://mcp_ports.cfg") == OK:
		port = config.get_value("mcp", "game_port", DEFAULT_PORT)
	tcp_server = TCPServer.new()
	var err := tcp_server.listen(port, "127.0.0.1")
	if err != OK:
		push_error("MCP Bridge Game: Failed to listen on port %d (error %d)" % [port, err])
	else:
		print("MCP Bridge Game: Listening on 127.0.0.1:%d" % port)
	RenderingServer.frame_post_draw.connect(_on_frame_post_draw)


func _exit_tree() -> void:
	for client in clients:
		client.disconnect_from_host()
	clients.clear()
	if tcp_server:
		tcp_server.stop()


func _process(_delta: float) -> void:
	if not tcp_server or not tcp_server.is_listening():
		return

	# Accept new connections
	while tcp_server.is_connection_available():
		var peer := tcp_server.take_connection()
		if peer:
			clients.append(peer)

	# Process existing clients
	var to_remove: Array[int] = []
	for i in range(clients.size()):
		var client := clients[i]
		client.poll()
		var status := client.get_status()

		if status == StreamPeerTCP.STATUS_ERROR or status == StreamPeerTCP.STATUS_NONE:
			to_remove.append(i)
			continue

		if status != StreamPeerTCP.STATUS_CONNECTED:
			continue

		if client.get_available_bytes() > 0:
			var data := client.get_utf8_string(client.get_available_bytes())
			if data.length() > 0:
				_handle_request(client, data)

	# Remove disconnected clients (reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		clients.remove_at(to_remove[i])


func _handle_request(client: StreamPeerTCP, data: String) -> void:
	var json := JSON.new()
	var err := json.parse(data)
	if err != OK:
		_send_response(client, {"error": "Invalid JSON: %s" % json.get_error_message()})
		return

	var request: Dictionary = json.data
	var cmd: String = request.get("cmd", "")

	match cmd:
		"screenshot":
			# Defer to frame_post_draw for correct viewport capture
			pending_screenshot_client = client
			# Force a frame draw in case low_processor_mode is active
			RenderingServer.force_draw()
		"get_runtime_tree":
			_send_response(client, _cmd_get_runtime_tree())
		"click":
			var x: float = request.get("x", 0.0)
			var y: float = request.get("y", 0.0)
			_send_response(client, _cmd_click(x, y))
		_:
			_send_response(client, {"error": "Unknown command: %s" % cmd})


func _on_frame_post_draw() -> void:
	if pending_screenshot_client == null:
		return

	var client := pending_screenshot_client
	pending_screenshot_client = null

	var image := get_viewport().get_texture().get_image()
	if not image:
		_send_response(client, {"error": "Failed to capture viewport"})
		return

	var png_bytes := image.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)
	_send_response(client, {"ok": true, "image_base64": b64})


func _cmd_click(x: float, y: float) -> Dictionary:
	# Simulate mouse press
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(x, y)
	press.global_position = Vector2(x, y)
	press.pressed = true
	get_viewport().push_input(press)
	# Defer the release to next frame so the UI processes the press first
	_deferred_release = Vector2(x, y)
	call_deferred("_send_mouse_release")
	return {"ok": true, "x": x, "y": y}


func _send_mouse_release() -> void:
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = _deferred_release
	release.global_position = _deferred_release
	release.pressed = false
	get_viewport().push_input(release)


func _cmd_get_runtime_tree() -> Dictionary:
	return {"ok": true, "tree": _serialize_node(get_tree().root)}


func _serialize_node(node: Node) -> Dictionary:
	var result := {
		"name": node.name,
		"type": node.get_class(),
	}
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_serialize_node(child))
	if children.size() > 0:
		result["children"] = children
	return result


func _send_response(client: StreamPeerTCP, response: Dictionary) -> void:
	var json_str := JSON.stringify(response)
	client.put_data((json_str + "\n").to_utf8_buffer())
