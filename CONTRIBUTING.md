# Contributing to Godot MCP

Thanks for your interest in contributing! Here's how to get started.

## Prerequisites

- [Godot 4.6](https://godotengine.org/download/) (standard or mono)
- [Python 3.10+](https://www.python.org/downloads/)
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

## Development Setup

1. Clone the repo and open `project.godot` in Godot 4.6
2. The MCP Bridge editor plugin activates automatically
3. Install Python dependencies:
   ```bash
   cd mcp && uv sync
   ```
4. Register the MCP server with Claude Code:
   ```bash
   claude mcp add godot-mcp -- uv run --directory /absolute/path/to/mcp python godot_mcp_server.py
   ```

## Testing

With the Godot editor open:

1. Start a Claude Code session
2. Run through the core tools: `get_scene_tree`, `run_project`, `screenshot`, `stop_project`
3. Test scene editing: `create_node`, `modify_node`, `delete_node`, `save_scene`
4. Verify the sample Kanban app still works (F5 in Godot)

There's no automated test suite yet — manual verification against the sample app is the current process.

## Project Structure

- `mcp/` — Python MCP server (the bridge between Claude and Godot)
- `addons/mcp_bridge/` — Godot editor plugin (TCP server on port 9500)
- `mcp_bridge_game.gd` — Game autoload (TCP server on port 9501)
- `examples/kanban/` — Sample Kanban board app for testing

## Pull Requests

- Keep PRs focused on a single change
- Test against the sample app before submitting
- Follow GDScript conventions: tabs for indentation, `snake_case` for variables/functions, `PascalCase` for classes
- Update `CHANGELOG.md` under an `## [Unreleased]` section if your change is user-facing
