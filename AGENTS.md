# AGENTS.md

## Purpose
This repository contains a personal WezTerm setup for macOS.
Keep the configuration modular, readable, and easy to tweak without digging through large files.

## Repository Structure
- `wezterm.lua`: Main entry point. Loads modules and defines global UI, colors, tabs, and event hooks.
- `background.lua`: Background slideshow and readability overlay logic.
- `keybinds.lua`: Key tables and custom key bindings.
- `background-img/`: User-managed image folder for slideshow assets.

## Configuration Principles
1. Keep user-tunable values near the top of each module.
2. Prefer paths based on `wezterm.config_dir` over hard-coded absolute paths.
3. Minimize side effects in `wezterm.lua`; place feature logic in dedicated modules.
4. Preserve existing keybinding behavior unless a change is explicitly requested.

## Background Slideshow Contract
1. Image sources must come from `background-img/`.
2. Supported formats must include `.png`, `.jpg`, and `.jpeg`.
3. Slideshow interval must be configurable from one obvious setting.
4. A readability layer must exist under the image layer (gradient preferred).
5. If no valid image exists, configuration must still load safely (fallback image or gradient-only mode).

## Validation Checklist
1. Reload WezTerm config and confirm no Lua errors.
2. Confirm slideshow rotates over time.
3. Confirm text remains readable over bright and dark areas of the image.
4. Confirm startup and tab rendering are unaffected.

## Shared Rules

Use English commit message prefixes: `feat:`, `fix:`, `ref:`, `docs:`, `chore:`.

After each implementation/editing prompt is completed, confirm whether there are unfinished points in the current phase, or if the phase is complete, whether there are tasks in the next phase. If there are remaining tasks, ask the user in selection mode where to continue next. Repeat this after every implementation step until all phases are complete and the project is release-ready.

After that question, generate a commit command with a message format appropriate to the implementation and ask the user in selection mode whether to execute it.

Do not ask for commit command generation for every tiny change within the same phase. However, if a change inside the same phase is large, this rule can be treated as an exception.

Even if the user chooses not to run the commit command, continue implementation if there is still work in the current phase or next phases, and keep iterating with question -> implementation -> question until completion.

The "question" here refers to selection-style planning questions, not plain text questions.

Commit command format:
`git commit -m "message" -m "message" -m "message"`

Use VS Code terminal commands directly for git operations. Do not use MCP for git operations.

Git add:
`git add .`

Git commit:
Use the format above with implementation-appropriate messages.

Git push:
`git push origin main`

If a reset command such as `git reset --soft HEAD^` is performed and the user informs you, force push is required:
`git push -f -u origin main`

After implementation/editing for the prompt is complete, before running build, read all files in the background (`.java`, `.ts`, `.json`, `.yml`, etc.), investigate all errors and warnings, and fix them.

Because a single fix may not resolve everything, run diagnostics again after each fix and continue until both errors and warnings are zero.

If there are multiple updates/additions, split work into numbered stages (`1`, `2`, `3`, ...).

All numbered tasks given in one prompt must be fully implemented within that same prompt.

Report progress to the user for each stage while implementing.
