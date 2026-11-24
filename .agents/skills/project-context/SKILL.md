---
name: project-context
description: Discover the relevant Endless Dungeon repository state, documentation, and approved decisions before planning a project task. Use for initial task triage, not for implementation or design approval.
---

# Project Context

## Purpose and use

Build a small, reliable context map for a specific project task. Use at the start of work or when a task changes scope. Do not use this skill to implement changes, approve rules, or load every document without a reason.

## Required context

Read `AGENTS.md` and the task request. Check the current branch, working tree, and relevant repository files. Read only the sections needed from `docs/AI_WORKFLOW.md`, `docs/DECISIONS.md`, `docs/GAME_DESIGN.md`, `docs/ARCHITECTURE.md`, and `docs/ROADMAP.md`; consult future `docs/ART_DIRECTION.md` only when it exists and the task concerns visuals.

## Procedure

1. Confirm branch, remote relationship when relevant, and tracked and untracked changes before any edit.
2. Classify the task and identify affected systems and documents.
3. Separate established decisions from tentative examples, proposals, and open questions; cite the source of each relevant claim.
4. Identify missing decisions, constraints, and the Skills that may help with the actual task, such as `game-design`, `feature-development`, `asset-generation`, `game-validation`, or `code-review`. Treat composition as a manual choice; automatic orchestration is unverified.
5. Return a concise context map and the next safe action. Do not modify project files solely for discovery.

## Approval and failure boundaries

Discovery grants no approval for gameplay, assets, dependencies, Git publication, or destructive actions. Stop dependent work when branch state, sources, or approved scope conflict; report the specific uncertainty without resolving it by inference.

## Expected output

Relevant branch and changes, authoritative references, approved scope, open questions, applicable Skills, and any blocker.
