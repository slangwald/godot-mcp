# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Kanban board application built with Godot 4.6. Not a game — a simple desktop utility with three columns (To Do, In Progress, Done), drag-and-drop cards between columns, and persistent storage.

## Engine & Configuration

- **Engine**: Godot 4.6
- **Rendering**: GL Compatibility (desktop and mobile)
- **Window**: 900x600, low processor mode (UI app)
- **Audio**: Dummy driver (no audio needed)
- **3D Physics**: Jolt Physics (default, unused)
- **Windows Rendering**: Direct3D 12

## Architecture

### Data Layer (Resource-based persistence)

- **`card_data.gd`** (`CardData`) — Custom Resource for a single card (`text`)
- **`column_data.gd`** (`ColumnData`) — Custom Resource for a column (`title`, `cards: Array[CardData]`)
- **`board_data.gd`** (`BoardData`) — Top-level Resource (`columns: Array[ColumnData]`)
- **`board_manager.gd`** (`BoardManager`) — Autoload singleton; loads/saves `BoardData` via `ResourceSaver`/`ResourceLoader` at `user://board.tres`

### UI Layer

- **`main.tscn` / `main.gd`** — Main scene: title, three KanbanColumn instances in an HBoxContainer
- **`kanban_column.tscn` / `kanban_column.gd`** — Column: title label, scrollable card list (drop target), input row for adding cards
- **`kanban_card.tscn` / `kanban_card.gd`** — Draggable card: label + delete button, implements `_get_drag_data()`

### Drag and Drop

- Cards implement `_get_drag_data()` to initiate drag with a preview label
- Columns use `set_drag_forwarding()` on the CardList VBoxContainer to receive drops
- Drop index is calculated by comparing `at_position.y` against child midpoints
- Same-column reordering adjusts the target index after removal

### Persistence

Data is stored at `user://board.tres` using Godot's native Resource serialization. No manual JSON parsing — `@export` properties on custom Resources are auto-serialized.

## Development

This project uses the Godot Editor as its primary development environment. There is no Makefile or CLI build system.

- **Open project**: Open `project.godot` in Godot 4.6 editor
- **Run project**: F5 in editor
- **Run current scene**: F6 in editor

### GDScript conventions

- Files use `.gd` extension
- Indentation: tabs (Godot default)
- Class names use PascalCase, variables/functions use snake_case
- Signals use past tense snake_case (e.g., `card_deleted`)

## Project Structure

Godot projects organize resources under `res://`. Scenes (`.tscn`/`.tres`) define node trees; scripts attach to nodes. The `project.godot` file is the root configuration.

The `.godot/` directory is editor cache (ignored by git) and should never be manually edited.
