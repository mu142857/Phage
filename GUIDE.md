# AI Collaboration Guide

This file gives AI assistants (Claude, Copilot, etc.) the context they need to help on this project.

## Project Overview

2D side-scrolling action game. Player is a 4×8 pixel nanobot. Enemies are pathogens (bacteria, viruses, etc.). Combat is the core loop — fast, hard, satisfying. No grinding, no filler.

## Tech Stack

- Godot Godot 4.6.2.stable with GDScript 2 (NOT GDScript 1 — do not suggest legacy syntax)
- Use `TileMapLayer`, NOT the deprecated `TileMap` node
- Renderer: Compatibility (2D project)

## Code Conventions

- Filenames: `snake_case` (e.g., `player_controller.gd`)
- Class names in code: `PascalCase`
- Variables/functions: `snake_case`
- Signals: past tense (`health_changed`, `enemy_died`)
- Global state lives in `systems/globals.gd` (AutoLoad singleton)

## Project Structure

Feature-based organization. Each entity has its own folder containing scene, script, and entity-specific sprites:

entities/player/        ← player.tscn, player.gd, player.png
entities/enemies/       ← one subfolder per enemy type
levels/                 ← .tscn level files
systems/                ← cross-cutting systems (globals, audio manager, save)
assets/                 ← shared resources (audio, fonts, UI)
Aseprite Assets/        ← original .aseprite source files at the workspace root, outside phage-0.0/ (not loaded by Godot)
docs/                   ← design docs in markdown

## Working Style

- Prefer small, reviewable changes. The author reviews every diff.
- Don't refactor unrelated code when fixing a bug.
- When unsure about Godot 4 API specifics, say so rather than guessing.
- Bilingual project (English + 简体中文) — keep user-facing strings in a translation table, not hardcoded.

## Code Conventions

### Naming
- Filenames: `snake_case` (e.g., `state_manager.gd`, `player.gd`)
- Folder names: `snake_case` (no spaces, no PascalCase)
- `class_name` declarations: `PascalCase` (e.g., `StateManager`, `BasicState`)
- Variables and functions: `snake_case` (e.g., `current_state`, `change_state()`)
- Constants: `SCREAMING_SNAKE_CASE` (e.g., `MAX_HEALTH`)
- Signals: past tense, `snake_case` (e.g., `health_changed`, `enemy_died`)

### File Headers
Every `.gd` file begins with a comment on line 1 stating its full `res://` path. Example:

    # res://entities/player/player.gd
    extends CharacterBody2D

When renaming or moving a file, update this comment to match. AI assistants must include this header when creating new scripts.

### State Machine Conventions
- All states extend `BasicState` and live as child nodes of a `StateManager` node.
- States expose three lifecycle methods: `enter()`, `process()`, `exit()`.
- State transitions use `change_state(id)`. The `id` parameter must be a string or enum identifier — never a raw integer index.
- The state machine code in `systems/state_machine/` is reused across all entities (player, enemies, bosses).

### Project Structure
Feature-based, not type-based. Each entity owns its scene, script, and entity-specific assets:

    entities/player/        ← player.tscn, player.gd, player.png
    entities/enemies/<name>/ ← one folder per enemy type
    levels/                 ← .tscn level files
    systems/                ← cross-cutting code (state_machine, globals, audio)
    assets/                 ← shared resources (audio, fonts, ui)
    Aseprite Assets/        ← original .aseprite source files at the workspace root, outside phage-0.0/
    docs/                   ← design docs
