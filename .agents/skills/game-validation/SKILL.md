---
name: game-validation
description: Select and run relevant checks for Endless Dungeon Godot changes, including executable resolution and headless import. Use when validating project changes, not as proof of gameplay behavior from import alone.
---

# Game Validation

## Purpose and use

Gather evidence that matches the changed scope. Do not run unrelated tests or claim gameplay works because project import succeeds.

## Required context

Read `AGENTS.md`, `docs/AI_WORKFLOW.md`, the task acceptance criteria, and relevant `docs/ARCHITECTURE.md` and `docs/GAME_DESIGN.md` sections. Inspect the diff and available tests before selecting checks. Use `feature-development` or `code-review` guidance when those tasks are in scope.

## Procedure

1. Choose checks for changed files: documentation and diff checks, Godot import, available automated tests, and runtime inspection when applicable.
2. Resolve Godot in order from process `GODOT_PATH`, Windows User `GODOT_PATH` when applicable, then an executable on `PATH`. Validate a resolved path with `Test-Path` where applicable and run `--version`. Set `GODOT_PATH` only for the current process if needed; never commit a machine path.
3. Run headless import against the actual project root when applicable. Run available automated tests relevant to the change. When Godot MCP is useful, discover only tools relevant to the required editor or runtime inspection and verify their results.
4. Inspect actual exit codes, MCP results, logs, and tracked and untracked changes caused by validation. Distinguish import, automated test, and gameplay validation in the report.

## Approval and failure boundaries

Never bypass a blocked mandatory validation or report an unrun check as passed. Stop dependent delivery on unexpected changes, security issues, or mandatory failures; preserve unrelated work. Follow `AGENTS.md` for publication approval.

## Expected output

Checks selected and executed, exact results and exit codes, coverage limits, unavailable tests, unexpected changes, and any blocker.
