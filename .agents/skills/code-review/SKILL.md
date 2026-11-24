---
name: code-review
description: Review actual Endless Dungeon changes for defects, regressions, security, scope, and missing validation. Use for a review request or a distinct review pass, not to silently edit files or authorize publication.
---

# Code Review

## Purpose and use

Evaluate the actual diff against approved requirements and project rules. Do not use a review-only request as permission to change files, approve gameplay, or publish work.

## Required context

Read `AGENTS.md`, `docs/AI_WORKFLOW.md`, the request and approved scope, relevant `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, and `docs/DECISIONS.md` sections, plus the complete diff and validation evidence. Use `project-context` if the comparison base or scope is unclear.

## Procedure

1. Confirm branch, comparison base, tracked and untracked changes, and which files are in scope.
2. Inspect actual code and documentation changes for correctness, regressions, security, maintainability, architectural consistency, and unapproved behavior.
3. Review available structured results from `tools/validation/Validate-Project.ps1` and any feature-specific checks. Identify failed, skipped, warning, missing, or insufficient validation and distinguish a verified defect from a potential risk or missing test.
4. Do not automatically repeat expensive checks when trustworthy results cover the current repository state. Revalidate when relevant files, environment prerequisites, or other evidence have changed since those results were produced.
5. Report findings by severity with file references and actionable explanations; then list residual risks and validation gaps. If no findings remain, state what was reviewed and its limits.

## Approval and failure boundaries

Do not silently modify files during a review-only task. Do not autonomously approve commits, pushes, merges, new gameplay rules, dependencies, or significant architecture changes. Escalate unexpected conflicts or credential exposure under `AGENTS.md`.

## Expected output

Severity-ordered findings with evidence and file references, followed by validation gaps and review limits.
