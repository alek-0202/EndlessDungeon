---
name: game-design
description: Evaluate proposed Endless Dungeon gameplay rules against established design and open questions. Use for design analysis or an authorized design-document update, not to implement unapproved mechanics.
---

# Game Design

## Purpose and use

Assess a proposed mechanic or rule and help the owner make an informed decision. Do not use for routine code edits that require no new gameplay decision or for treating examples as approved rules.

## Required context

Read the proposal, `AGENTS.md`, relevant sections of `docs/GAME_DESIGN.md`, and related entries in `docs/DECISIONS.md`. Consult `docs/ARCHITECTURE.md` and `docs/ROADMAP.md` only where the proposal affects technical boundaries or priorities. Use `docs/AI_WORKFLOW.md` for approval rules.

## Procedure

1. State the proposed behavior and distinguish it from established rules, tentative values, and unresolved questions.
2. Check for contradictions, dependencies, tradeoffs, edge cases, and effects on existing systems.
3. Present meaningful alternatives and their consequences when a choice is needed. Mark recommendations as proposals.
4. Obtain owner approval before establishing any new gameplay rule. Update `docs/GAME_DESIGN.md` and, when a traceable decision warrants it, `docs/DECISIONS.md` only within an authorized documentation scope.
5. Hand an approved, concrete requirement to `feature-development` when implementation is requested; do not implement an unapproved mechanic.

## Approval and failure boundaries

Owner approval is required for new or changed gameplay rules. If sources disagree or a required detail is missing, leave it open and stop dependent implementation. Follow `AGENTS.md` for Git, security, and scope restrictions.

## Expected output

A sourced assessment, proposed options where useful, exact decisions awaiting approval, and any authorized documentation changes.
