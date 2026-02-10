@tool
extends EditorPlugin

const PORT := 9500
const BUFFER_SIZE := 65536

var tcp_server: TCPServer
var clients: Array[StreamPeerTCP] = []


func _enter_tree() -> void:
	tcp_server = TCPServer.new()
	var err := tcp_server.listen(PORT, "127.0.0.1")
	if err != OK:
		push_error("MCP Bridge: Failed to listen on port %d (error %d)" % [PORT, err])
	else:
		print("MCP Bridge: Listening on 127.0.0.1:%d" % PORT)


func _exit_tree() -> void:
	for client in clients:
		client.disconnect_from_host()
	clients.clear()
	if tcp_server:
		tcp_server.stop()
	print("MCP Bridge: Stopped")


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

	var response: Dictionary
	match cmd:
		"get_scene_tree":
			response = _cmd_get_scene_tree()
		"get_node_properties":
			response = _cmd_get_node_properties(request.get("node_path", ""))
		"modify_node":
			response = _cmd_modify_node(request.get("node_path", ""), request.get("properties", {}))
		"create_node":
			response = _cmd_create_node(request.get("parent_path", ""), request.get("type", ""), request.get("name", ""))
		"delete_node":
			response = _cmd_delete_node(request.get("node_path", ""))
		"run_project":
			response = _cmd_run_project()
		"stop_project":
			response = _cmd_stop_project()
		"save_scene":
			response = _cmd_save_scene()
		"get_editor_state":
			response = _cmd_get_editor_state()
		_:
			response = {"error": "Unknown command: %s" % cmd}

	_send_response(client, response)


func _send_response(client: StreamPeerTCP, response: Dictionary) -> void:
	var json_str := JSON.stringify(response)
	client.put_data((json_str + "\n").to_utf8_buffer())


# ── Commands ──────────────────────────────────────────────────────────────────

func _cmd_get_scene_tree() -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open in the editor"}
	return {"ok": true, "tree": _serialize_node(root, root)}


func _serialize_node(node: Node, scene_root: Node) -> Dictionary:
	var rel_path: String
	if node == scene_root:
		rel_path = "."
	else:
		rel_path = str(scene_root.get_path_to(node))
	var result := {
		"name": node.name,
		"type": node.get_class(),
		"path": rel_path,
	}
	var children: Array[Dictionary] = []
	for child in node.get_children():
		children.append(_serialize_node(child, scene_root))
	if children.size() > 0:
		result["children"] = children
	return result


func _cmd_get_node_properties(node_path: String) -> Dictionary:
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open in the editor"}

	var node := root.get_node_or_null(NodePath(node_path)) if not node_path.begins_with("/root") else root.get_node_or_null(_strip_root_prefix(node_path, root))
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var props := {}
	for prop_info in node.get_property_list():
		var prop_name: String = prop_info["name"]
		# Skip internal/private properties
		if prop_name.begins_with("_") or prop_info["usage"] & PROPERTY_USAGE_CATEGORY or prop_info["usage"] & PROPERTY_USAGE_GROUP:
			continue
		var value = node.get(prop_name)
		# Only include serializable types
		if value == null or value is Object:
			continue
		props[prop_name] = _value_to_string(value)

	var rel_path := "." if node == root else str(root.get_path_to(node))
	return {"ok": true, "path": rel_path, "type": node.get_class(), "properties": props}


func _cmd_modify_node(node_path: String, properties: Dictionary) -> Dictionary:
	if node_path.is_empty():
		return {"error": "node_path is required"}
	if properties.is_empty():
		return {"error": "properties dict is required"}

	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open in the editor"}

	var node := root.get_node_or_null(NodePath(node_path)) if not node_path.begins_with("/root") else root.get_node_or_null(_strip_root_prefix(node_path, root))
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var modified: Array[String] = []
	var errors: Array[String] = []
	for prop_name in properties:
		var value = properties[prop_name]
		if prop_name in node:
			var current = node.get(prop_name)
			var converted = _convert_value(value, typeof(current))
			node.set(prop_name, converted)
			modified.append(prop_name)
		else:
			errors.append("Property not found: %s" % prop_name)

	var result := {"ok": true, "modified": modified}
	if errors.size() > 0:
		result["errors"] = errors
	return result


func _cmd_create_node(parent_path: String, type_name: String, node_name: String) -> Dictionary:
	if parent_path.is_empty() or type_name.is_empty() or node_name.is_empty():
		return {"error": "parent_path, type, and name are all required"}

	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open in the editor"}

	var parent: Node
	if parent_path == "." or parent_path == root.name:
		parent = root
	else:
		parent = root.get_node_or_null(NodePath(parent_path)) if not parent_path.begins_with("/root") else root.get_node_or_null(_strip_root_prefix(parent_path, root))
	if not parent:
		return {"error": "Parent node not found: %s" % parent_path}

	var new_node: Node = ClassDB.instantiate(type_name)
	if not new_node:
		return {"error": "Unknown node type: %s" % type_name}

	new_node.name = node_name
	parent.add_child(new_node)
	new_node.owner = root
	var rel_path := str(root.get_path_to(new_node))
	return {"ok": true, "path": rel_path}


func _cmd_delete_node(node_path: String) -> Dictionary:
	if node_path.is_empty():
		return {"error": "node_path is required"}

	var root := EditorInterface.get_edited_scene_root()
	if not root:
		return {"error": "No scene is currently open in the editor"}

	if node_path == "." or node_path == root.name or node_path == str(root.get_path()):
		return {"error": "Cannot delete the root node"}

	var node := root.get_node_or_null(NodePath(node_path)) if not node_path.begins_with("/root") else root.get_node_or_null(_strip_root_prefix(node_path, root))
	if not node:
		return {"error": "Node not found: %s" % node_path}

	var rel_path := str(root.get_path_to(node))
	node.get_parent().remove_child(node)
	node.queue_free()
	return {"ok": true, "deleted": rel_path}


func _cmd_run_project() -> Dictionary:
	EditorInterface.play_main_scene()
	return {"ok": true, "action": "play_main_scene"}


func _cmd_stop_project() -> Dictionary:
	EditorInterface.stop_playing_scene()
	return {"ok": true, "action": "stop_playing_scene"}


func _cmd_save_scene() -> Dictionary:
	EditorInterface.save_scene()
	return {"ok": true, "action": "save_scene"}


func _cmd_get_editor_state() -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	return {
		"ok": true,
		"has_scene": root != null,
		"scene_name": root.name if root else "",
		"scene_path": root.scene_file_path if root else "",
		"is_playing": EditorInterface.is_playing_scene(),
	}


# ── Helpers ───────────────────────────────────────────────────────────────────

func _strip_root_prefix(path: String, root: Node) -> NodePath:
	# Convert absolute "/root/Main/Foo" paths to relative paths from scene root
	var prefix := "/root/%s" % root.name
	if path == prefix:
		return NodePath(".")
	if path.begins_with(prefix + "/"):
		return NodePath(path.substr(prefix.length() + 1))
	return NodePath(path)


func _value_to_string(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2:
			return {"x": value.x, "y": value.y}
		TYPE_VECTOR3:
			return {"x": value.x, "y": value.y, "z": value.z}
		TYPE_RECT2:
			return {"x": value.position.x, "y": value.position.y, "w": value.size.x, "h": value.size.y}
		TYPE_COLOR:
			return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
		TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL:
			return value
		_:
			return str(value)


func _convert_value(value: Variant, target_type: int) -> Variant:
	match target_type:
		TYPE_VECTOR2:
			if value is Dictionary:
				return Vector2(value.get("x", 0), value.get("y", 0))
		TYPE_VECTOR3:
			if value is Dictionary:
				return Vector3(value.get("x", 0), value.get("y", 0), value.get("z", 0))
		TYPE_COLOR:
			if value is Dictionary:
				return Color(value.get("r", 0), value.get("g", 0), value.get("b", 0), value.get("a", 1))
			if value is String:
				return Color(value)
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return float(value)
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			return str(value)
	return value
