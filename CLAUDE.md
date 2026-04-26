# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Auracole is a **Godot 4.6** game project (3D Chinese-themed world with industrial/machine-building gameplay). It uses **GDScript** for most gameplay logic and **C# (.NET 8.0)** for the deterministic offline production simulation. The addons `dialogic` (dialogue system) and `godot_mcp` (Claude integration) are in `addons/`.

See `AGENTS.md` for detailed guidelines on build commands, coding style, naming conventions, gameplay system notes, testing, and commit conventions.

## Godot MCP Tools (Scene Editing)

**Always use MCP tools to edit `.tscn` files** — never hand-edit them as text. The MCP plugin (`addons/godot_mcp/`) is running in the Godot editor and provides tools for creating/modifying scenes, scripts, and assets.

The current permissions in `.claude/settings.local.json` only allow read operations. When you need to modify scenes or scripts, ask the user for the necessary MCP tool permissions.

MCP tools follow the pattern `mcp__godot-mcp__<action>`. Key tools include:
- Scene editing: `create_scene`, `add_node`, `remove_node`, `modify_node_property`, `set_node_properties`
- Script editing: `create_script`, `edit_script`, `validate_script`
- Runtime: `run_scene`, `stop_scene`, `send_input`, `take_screenshot`
- Query: `classdb_query`, `read_file`, `read_scene`, `list_dir`, `search_project`

## Architecture Notes

**Dual-language split**: GDScript for real-time gameplay (player, UI, placement, inventory). C# for the offline production simulation where deterministic computation matters. C# code lives under `scripts/industry_map/` with a three-layer architecture: `data/` (models), `engine/` (simulation), `runtime/` (Godot node wrappers).

**Scene flow**: `scenes/start_game.tscn` (title) → Dialogic timeline (`story/begin.dtl`) → `scenes/jing_chuan.tscn` (3D world). UI overlays (map/inventory/recipe browser/placement) are toggled from the 3D world.

**Placement systems**: Two distinct systems exist — a 2D grid-based placement system (`scripts/placement_logic/`) and a 3D GridMap-based placement system (`scripts/industry_system/spawn_equipment.gd`). Do not confuse the two.

**Inventory**: Custom Resource-based system using `class_name` types (`InventoryDate`, `SlotData`, `ItemData`) with signal-based change propagation.

**Persistence**: Uses `user://` paths (Godot's user data directory). Key files: `user://production_snapshot.json`, `user://blueprints.save`.

## C# Build Validation

Always run `dotnet build Auracole.sln` after modifying C# files under `scripts/industry_map/`. Use Godot `--headless --check-only` for GDScript syntax validation.
