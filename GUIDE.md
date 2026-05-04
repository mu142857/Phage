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
Aseprite Assets/        ← original .aseprite source files (not loaded by Godot)
docs/                   ← design docs in markdown

## Working Style

- Prefer small, reviewable changes. The author reviews every diff.
- Don't refactor unrelated code when fixing a bug.
- When unsure about Godot 4 API specifics, say so rather than guessing.
- Bilingual project (English + 简体中文) — keep user-facing strings in a translation table, not hardcoded.