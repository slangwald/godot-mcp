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
def get_runtime_tree() -> str:
    """Get the live scene tree from the running Godot game. The game must be running first."""
    result = _send_to_game({"cmd": "get_runtime_tree"})
    return json.dumps(result, indent=2)


if __name__ == "__main__":
    mcp.run(transport="stdio")
