"""Godot MCP Server — bridges Claude Code to Godot editor and running game."""

import base64
import json
import socket

from mcp.server.fastmcp import FastMCP, Image

mcp = FastMCP("godot")

EDITOR_PORT = 9500
GAME_PORT = 9501
TIMEOUT = 5.0


def _send_command(port: int, cmd: dict, timeout: float = TIMEOUT) -> dict:
    """Send a JSON command over TCP and return the parsed response."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(timeout)
            sock.connect(("127.0.0.1", port))
            payload = json.dumps(cmd) + "\n"
            sock.sendall(payload.encode("utf-8"))

            # Read response (newline-terminated JSON)
            data = b""
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                data += chunk
                if b"\n" in data:
                    break

            if not data:
                return {"error": "Empty response from Godot"}

            return json.loads(data.decode("utf-8").strip())
    except ConnectionRefusedError:
        target = "editor" if port == EDITOR_PORT else "game"
        return {"error": f"Cannot connect to Godot {target} on port {port}. Is it running?"}
    except socket.timeout:
        return {"error": f"Timeout waiting for response on port {port}"}
    except Exception as e:
        return {"error": f"Connection error: {e}"}


def _send_to_editor(cmd: dict) -> dict:
    return _send_command(EDITOR_PORT, cmd)


def _send_to_game(cmd: dict, timeout: float = TIMEOUT) -> dict:
    return _send_command(GAME_PORT, cmd, timeout)


# ── Editor tools (via plugin on TCP:9500) ─────────────────────────────────────


@mcp.tool()
def get_scene_tree() -> str:
    """Get the scene tree from the Godot editor showing all nodes, their types, and hierarchy."""
    result = _send_to_editor({"cmd": "get_scene_tree"})
    return json.dumps(result, indent=2)


@mcp.tool()
def get_node_properties(node_path: str) -> str:
    """Get all properties of a specific node in the editor scene tree.

    Args:
        node_path: Path to the node (e.g. "Main/HBoxContainer/Column1")
    """
    result = _send_to_editor({"cmd": "get_node_properties", "node_path": node_path})
    return json.dumps(result, indent=2)


@mcp.tool()
def modify_node(node_path: str, properties: dict) -> str:
    """Modify properties on a node in the editor scene tree.

    Args:
        node_path: Path to the node (e.g. "Main/TitleLabel")
        properties: Dictionary of property names to new values (e.g. {"text": "New Title", "visible": false})
    """
    result = _send_to_editor({"cmd": "modify_node", "node_path": node_path, "properties": properties})
    return json.dumps(result, indent=2)


@mcp.tool()
def create_node(parent_path: str, type: str, name: str) -> str:
    """Create a new node in the editor scene tree.

    Args:
        parent_path: Path to the parent node (e.g. "." for scene root, "Main/HBoxContainer")
        type: Godot node type (e.g. "Label", "Button", "VBoxContainer")
        name: Name for the new node
    """
    result = _send_to_editor({"cmd": "create_node", "parent_path": parent_path, "type": type, "name": name})
    return json.dumps(result, indent=2)


@mcp.tool()
def delete_node(node_path: str) -> str:
    """Delete a node from the editor scene tree.

    Args:
        node_path: Path to the node to delete
    """
    result = _send_to_editor({"cmd": "delete_node", "node_path": node_path})
    return json.dumps(result, indent=2)


@mcp.tool()
def run_project() -> str:
    """Run the Godot project (play main scene). The game will start in a new window."""
    result = _send_to_editor({"cmd": "run_project"})
    return json.dumps(result, indent=2)


@mcp.tool()
def stop_project() -> str:
    """Stop the currently running Godot game."""
    result = _send_to_editor({"cmd": "stop_project"})
    return json.dumps(result, indent=2)


@mcp.tool()
def save_scene() -> str:
    """Save the currently edited scene in the Godot editor."""
    result = _send_to_editor({"cmd": "save_scene"})
    return json.dumps(result, indent=2)


@mcp.tool()
def get_editor_state() -> str:
    """Get the current state of the Godot editor (open scene, whether game is running, etc.)."""
    result = _send_to_editor({"cmd": "get_editor_state"})
    return json.dumps(result, indent=2)


@mcp.tool()
def open_scene(path: str) -> str:
    """Open a scene file in the Godot editor.

    Args:
        path: Resource path to the scene (e.g. "res://examples/cube/cube.tscn")
    """
    result = _send_to_editor({"cmd": "open_scene", "path": path})
    return json.dumps(result, indent=2)


@mcp.tool()
def run_scene(path: str) -> str:
    """Run a specific scene in Godot (instead of the main scene). The game will start in a new window.

    Args:
        path: Resource path to the scene (e.g. "res://examples/cube/cube.tscn")
    """
    result = _send_to_editor({"cmd": "run_scene", "path": path})
    return json.dumps(result, indent=2)


@mcp.tool()
def set_resource(node_path: str, property: str, resource_type: str, resource_properties: dict = {}) -> str:
    """Create a Resource and assign it to a node property in the editor scene tree.
    Use this for properties that hold Resources (meshes, materials, environments, etc.).

    Args:
        node_path: Path to the node (e.g. "Cube")
        property: Property name to set (e.g. "mesh", "surface_material_override/0", "environment")
        resource_type: Godot Resource class (e.g. "BoxMesh", "StandardMaterial3D", "Environment")
        resource_properties: Optional dict of properties to set on the new resource (e.g. {"size": {"x": 2, "y": 2, "z": 2}})
    """
    result = _send_to_editor({
        "cmd": "set_resource",
        "node_path": node_path,
        "property": property,
        "resource_type": resource_type,
        "resource_properties": resource_properties,
    })
    return json.dumps(result, indent=2)


@mcp.tool()
def attach_script(node_path: str, source: str) -> str:
    """Create and attach an inline GDScript to a node in the editor scene tree.

    Args:
        node_path: Path to the node (e.g. "Cube")
        source: GDScript source code (e.g. "extends MeshInstance3D\\n\\nfunc _process(delta):\\n\\trotate_y(delta)")
    """
    result = _send_to_editor({"cmd": "attach_script", "node_path": node_path, "source": source})
    return json.dumps(result, indent=2)


@mcp.tool()
def set_script(node_path: str, path: str) -> str:
    """Assign an existing .gd script file to a node in the editor scene tree.

    Args:
        node_path: Path to the node (e.g. "Player")
        path: Resource path to the script (e.g. "res://player.gd")
    """
    result = _send_to_editor({"cmd": "set_script", "node_path": node_path, "path": path})
    return json.dumps(result, indent=2)


@mcp.tool()
def get_signals(node_path: str) -> str:
    """List all signals on a node and their connections.

    Args:
        node_path: Path to the node (e.g. "Button")
    """
    result = _send_to_editor({"cmd": "get_signals", "node_path": node_path})
    return json.dumps(result, indent=2)


@mcp.tool()
def connect_signal(source_path: str, signal_name: str, target_path: str, method: str) -> str:
    """Connect a signal from one node to a method on another node.

    Args:
        source_path: Path to the node emitting the signal (e.g. "Button")
        signal_name: Name of the signal (e.g. "pressed")
        target_path: Path to the node receiving the signal (e.g. ".")
        method: Method name on the target node (e.g. "_on_button_pressed")
    """
    result = _send_to_editor({
        "cmd": "connect_signal",
        "source_path": source_path,
        "signal_name": signal_name,
        "target_path": target_path,
        "method": method,
    })
    return json.dumps(result, indent=2)


@mcp.tool()
def list_resources(directory: str = "res://", extensions: list[str] = []) -> str:
    """List all resource files in the Godot project (.tscn, .gd, .tres, etc.).

    Args:
        directory: Starting directory (default "res://")
        extensions: File extensions to include (default: tscn, scn, gd, tres, res, gdshader)
    """
    result = _send_to_editor({
        "cmd": "list_resources",
        "directory": directory,
        "extensions": extensions,
    })
    return json.dumps(result, indent=2)


@mcp.tool()
def instantiate_scene(parent_path: str, scene_path: str, name: str = "") -> str:
    """Instantiate an existing .tscn scene as a child of a node in the editor.

    Args:
        parent_path: Path to the parent node (e.g. "." for scene root)
        scene_path: Resource path to the scene file (e.g. "res://examples/kanban/kanban_card.tscn")
        name: Optional name for the new instance
    """
    result = _send_to_editor({
        "cmd": "instantiate_scene",
        "parent_path": parent_path,
        "scene_path": scene_path,
        "name": name,
    })
    return json.dumps(result, indent=2)


@mcp.tool()
def get_output() -> str:
    """Read recent output from the Godot editor log (prints, errors, warnings)."""
    result = _send_to_editor({"cmd": "get_output"})
    return json.dumps(result, indent=2)


@mcp.tool()
def undo() -> str:
    """Undo the last action in the Godot editor."""
    result = _send_to_editor({"cmd": "undo"})
    return json.dumps(result, indent=2)


@mcp.tool()
def redo() -> str:
    """Redo the last undone action in the Godot editor."""
    result = _send_to_editor({"cmd": "redo"})
    return json.dumps(result, indent=2)


# ── Game tools (via autoload on TCP:9501) ─────────────────────────────────────


@mcp.tool()
def screenshot() -> Image:
    """Take a screenshot of the running Godot game. The game must be running first (use run_project)."""
    result = _send_to_game({"cmd": "screenshot"}, timeout=10.0)

    if "error" in result:
        raise ValueError(result["error"])

    image_b64 = result.get("image_base64")
    if not image_b64:
        raise ValueError("No image data in response")

    return Image(data=base64.b64decode(image_b64), format="png")


@mcp.tool()
def click(x: float, y: float) -> str:
    """Simulate a mouse click at viewport coordinates in the running Godot game.

    Args:
        x: X coordinate in pixels from the left edge
        y: Y coordinate in pixels from the top edge
    """
    result = _send_to_game({"cmd": "click", "x": x, "y": y})
    return json.dumps(result, indent=2)


@mcp.tool()
def get_runtime_tree() -> str:
    """Get the live scene tree from the running Godot game. The game must be running first."""
    result = _send_to_game({"cmd": "get_runtime_tree"})
    return json.dumps(result, indent=2)


if __name__ == "__main__":
    mcp.run(transport="stdio")
