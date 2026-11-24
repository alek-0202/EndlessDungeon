---
name: feature-development
description: Implement an approved Endless Dungeon feature within existing Godot architecture and project scope. Use when concrete requirements are ready for code changes, not to decide new gameplay rules.
---

# Feature Development

## Purpose and use

Turn approved requirements into a small, maintainable implementation. Do not use this skill to expand gameplay scope, choose a major architecture, or add a dependency without the required approval.

## Required context

Read `AGENTS.md`, the request, relevant rules in `docs/GAME_DESIGN.md`, boundaries in `docs/ARCHITECTURE.md`, priorities in `docs/ROADMAP.md`, applicable entries in `docs/DECISIONS.md`, and workflow rules in `docs/AI_WORKFLOW.md`. Inspect affected code and local changes. Use `project-context` when the task context is unclear.

## Procedure

1. Confirm the authorized branch, working tree, acceptance criteria, and any gameplay detail the implementation depends on.
2. Plan the smallest change that fits existing Godot and GDScript conventions; identify validation and review needs.
3. Implement only the approved behavior, preserving unrelated work and separating reusable content, mutable run state, logic, and presentation as required by the architecture.
4. When Godot MCP materially helps, discover only the tools relevant to the intended operation, then use supported inspection or editor operations and check each result. Do not assume a tool is available or successful.
5. Run `tools/validation/Validate-Project.ps1` with `game-validation` guidance and add feature-specific checks when appropriate. Use `Full` when changes affect Godot code, scenes, resources, or project configuration. Treat successful import as loading evidence, not proof of runtime or gameplay behavior.
6. Inspect the diff with `code-review` guidance when useful, correct implementation defects, and update affected documentation.

## Approval and failure boundaries

Pause dependent implementation for unapproved gameplay decisions, new dependencies, or significant architectural changes. Do not commit, push, or merge without explicit authorization. Stop on unexpected conflicts or security issues under `AGENTS.md` and `docs/AI_WORKFLOW.md`.

## Expected output

Implemented scope, changed files, validation results, remaining questions, and risks for owner review.
