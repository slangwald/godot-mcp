# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## Roadmap

- Automated plugin installation (search, find, and install Godot plugins via MCP)

## [0.1.0] - 2025-06-07

### Added

- Python MCP server bridging Claude Code to Godot 4.6 over localhost TCP
- Godot editor plugin (port 9500) with tools:
  - `get_scene_tree` — inspect the full node hierarchy
  - `get_node_properties` — read any property on any node
  - `modify_node` — change node properties
  - `create_node` — add new nodes to the scene
  - `delete_node` — remove nodes from the scene
  - `run_project` / `stop_project` — launch and stop the game
  - `save_scene` — persist the current scene
  - `get_editor_state` — check editor status
- Game autoload (port 9501) with tools:
  - `screenshot` — capture the game viewport as PNG
  - `get_runtime_tree` — inspect the live scene tree while running
- Cross-platform support (macOS, Windows, Linux)
- Sample Kanban board app for testing (`examples/kanban/`)
