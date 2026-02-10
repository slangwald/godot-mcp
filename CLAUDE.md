# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A **Model Context Protocol (MCP) server** that bridges Claude Code to the Godot 4.6 game engine. It lets Claude run projects, inspect and modify scene trees, take screenshots of the running game, and iterate on Godot projects — all without leaving the terminal.

The repo includes a sample Kanban board app as a demo project to test against.

## Architecture

Three components communicate over localhost TCP:

```
Claude Code ←stdio→ Python MCP Server ←TCP:9500→ Godot Editor Plugin
													   ↓ (runs game)
												  Godot Game (autoload) ←TCP:9501→ Python MCP Server
```

### MCP Server (`mcp/godot_mcp_server.py`)

Python FastMCP server. Talks to Claude Code via stdio, forwards commands to Godot over TCP. Cross-platform (Mac, Windows, Linux).

**Editor tools** (port 9500): `get_scene_tree`, `get_node_properties`, `modify_node`, `create_node`, `delete_node`, `set_resource`, `attach_script`, `set_script`, `get_signals`, `connect_signal`, `instantiate_scene`, `list_resources`, `run_project`, `run_scene`, `stop_project`, `save_scene`, `get_editor_state`, `open_scene`, `get_output`, `undo`, `redo`

**Game tools** (port 9501): `screenshot` (returns PNG as base64 image), `get_runtime_tree`

### Editor Plugin (`addons/mcp_bridge/`)

`@tool` EditorPlugin running inside the Godot editor. TCP server on port 9500. Uses `EditorInterface` APIs to manipulate the scene tree, run/stop the project, and save scenes.

### Game Autoload (`mcp_bridge_game.gd`)

Autoload singleton injected into the running game. TCP server on port 9501. Captures viewport screenshots via `get_viewport().get_texture().get_image()` and sends PNG bytes as base64 over TCP. Uses `RenderingServer.force_draw()` to ensure frames render in low-processor mode.

## File Structure

```
├── mcp/
│   ├── pyproject.toml              # Python deps (mcp[cli])
│   └── godot_mcp_server.py         # MCP server (stdio transport)
├── addons/mcp_bridge/
│   ├── plugin.cfg                  # Editor plugin metadata
│   └── plugin.gd                   # Editor plugin (TCP:9500)
├── mcp_bridge_game.gd              # Game autoload (TCP:9501)
├── project.godot                   # Godot project config
└── examples/kanban/                # Sample app: Kanban board
	├── main.tscn / main.gd        #   Main scene & script
	├── kanban_column.tscn / .gd   #   Column component
	├── kanban_card.tscn / .gd     #   Card component
	├── board_data.gd / column_data.gd / card_data.gd  #   Data model
	└── board_manager.gd           #   Persistence (autoload)
```

## Setup

### Prerequisites

- **Godot 4.6** (standard or mono)
- **Python 3.10+** with **uv** (`pip install uv`)
- **Claude Code** CLI

### Installation

1. Open the project in Godot 4.6 — the MCP Bridge plugin auto-enables
2. Install and register the MCP server:
   ```bash
   claude mcp add godot-mcp -- uv run --directory /path/to/this/repo/mcp python godot_mcp_server.py
   ```
3. Start a new Claude Code session — MCP tools are now available

### Usage

With Godot editor open and a new Claude Code session:

1. `get_scene_tree` — inspect the editor's scene tree
2. `run_project` — launch the game
3. `screenshot` — see what the game looks like
4. `modify_node` / `create_node` / `delete_node` — edit the scene
5. `save_scene` — persist changes
6. `stop_project` — stop the game

## Development

### GDScript conventions

- Indentation: tabs
- Class names: PascalCase, variables/functions: snake_case
- Signals: past tense snake_case (e.g., `card_deleted`)

### TCP protocol

Both TCP servers (editor and game) use the same protocol:
- **Request**: JSON object with `"cmd"` key, newline-terminated
- **Response**: JSON object, newline-terminated
- **Connection**: short-lived (connect, send, receive, close)

### Cross-platform notes

- All networking uses localhost TCP (works identically on Mac/Windows/Linux)
- No filesystem paths in the TCP protocol — screenshots are base64-encoded in JSON
- The `rendering_device/driver.windows="d3d12"` setting in `project.godot` is scoped to Windows only and ignored on other platforms
- Python MCP server uses only stdlib `socket` + `json` plus `mcp[cli]`

### Ports

| Port | Component | Purpose |
|------|-----------|---------|
| 9500 | Editor plugin | Scene tree, node manipulation, run/stop |
| 9501 | Game autoload | Screenshots, runtime tree |
