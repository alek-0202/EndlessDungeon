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

1. Use `tools/validation/Validate-Project.ps1` as the preferred baseline. Select `Quick` for local feedback when import evidence is unnecessary; select `Full` for Godot code, scenes, resources, project configuration, or delivery evidence that requires headless import.
2. Inspect every failed, skipped, and warning result and the native exit codes that are available. Never describe a skipped check as passed.
3. Use `tools/setup/Resolve-Godot.ps1`, `tools/validation/Validate-Environment.ps1`, or `tools/validation/Validate-Skills.ps1` individually only when troubleshooting their specific responsibility. Do not reconstruct their resolution or validation logic manually.
4. Run available automated or feature-specific tests relevant to the change. When Godot MCP is useful, discover only tools relevant to the required editor or runtime inspection and verify their results.
5. Inspect actual exit codes, MCP results, logs, and tracked and untracked changes caused by validation. Distinguish project import, runtime inspection, automated tests, and gameplay validation in the report.

## Approval and failure boundaries

Never bypass a blocked mandatory validation or report an unrun check as passed. Stop dependent delivery on unexpected changes, security issues, or mandatory failures; preserve unrelated work. Follow `AGENTS.md` for publication approval.

## Expected output

Checks selected and executed, exact results and exit codes, coverage limits, unavailable tests, unexpected changes, and any blocker.
