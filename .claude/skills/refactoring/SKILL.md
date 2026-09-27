---
name: refactoring
description: Restructure existing code without changing its external behavior — extracting functions, removing duplication, splitting overgrown files/classes, simplifying conditionals, renaming for clarity, or general "clean up this code" requests. Stack-agnostic — applies to any language or framework. Use this skill whenever the user asks to refactor, clean up, simplify, de-duplicate, or improve the structure of existing code, even if they don't use the word "refactor" explicitly (e.g. "this function is a mess," "can we split this up," "this file is getting huge").
---

# Refactoring

Restructures code while preserving behavior. The defining constraint of a refactor is that nothing observable changes — same inputs produce same outputs, same interfaces, same side effects. If behavior needs to change too, that's a feature or a bug fix bundled with a refactor, and the two should be called out separately so the user can review them independently.

## Workflow

### Step 1: Check for a safety net before touching anything

A refactor is only as safe as the tests that would catch a regression. Before changing code:

- Look for existing tests covering the code being touched.
- If coverage is missing or thin, say so up front. Offer to write a handful of characterization tests first (tests that pin down current behavior, not tests of "correct" behavior) — this gives both of you a way to verify nothing broke.
- If the user wants to proceed without tests anyway, that's their call — just make the risk explicit rather than proceeding silently.

### Step 2: Pin down the actual goal

"Refactor this" can mean very different things: reduce duplication, extract a reusable function, split a god-function/class, simplify nested conditionals, rename things for clarity, remove dead code. Figure out which one applies (ask if genuinely ambiguous) and stay scoped to it. Resist the urge to also fix unrelated things you notice along the way — flag them separately instead of folding them in, since an unscoped refactor is harder to review and riskier to land.

### Step 3: Work in small, independently verifiable steps

Large one-shot rewrites are hard to verify and hard to review. Prefer a sequence of small changes where each one keeps the code in a working state. Where possible, verify (run tests, or ask the user to) after each step rather than batching verification to the end — this makes it much easier to pinpoint what broke if something does.

### Step 4: Match the existing style, don't introduce new patterns

Consistency with the surrounding codebase matters more than using your preferred pattern. If the codebase doesn't use a particular abstraction (e.g. a specific design pattern, a new dependency, a different error-handling style), don't introduce it as part of a refactor unless asked. A refactor should look like it was written by the same team that wrote the rest of the file.

### Step 5: Summarize what changed and why

When done, give a short summary of what was restructured and the reasoning — not just "refactored X" but what shape it had before, what shape it has now, and why that's better (easier to test, removes duplication, clarifies intent, etc). This is what lets the user review a structural change quickly instead of re-deriving your reasoning from the diff.

## Guardrails

- Never mix a behavior change into a refactor without explicitly flagging it — if a "cleanup" would also fix a bug, name that separately so it can be reviewed as its own decision.
- Don't refactor code you weren't asked to touch, even if it's tempting — scope creep turns a reviewable change into an unreviewable one.
- If you can't verify behavior is preserved (no tests, no way to run the code), say so plainly rather than asserting the refactor is safe.
