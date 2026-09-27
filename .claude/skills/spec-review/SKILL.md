---
name: spec-review
description: Review a design/technical spec (from a System Analyst, PM, or architect) for gaps, inaccuracies, and inconsistencies before implementation starts — breaks the spec into sections and flags what's missing, wrong, or over-specified in each one, ordered by how much it would block implementation. Stack-agnostic, works on specs in any format (doc, markdown, ticket, Figma notes, etc.) describing any kind of software. Use this skill whenever the user shares a spec/design doc and asks to review it, wants to check whether a spec is "ready" or "complete" before starting to build, complains a spec is vague/incomplete/contradictory, or says something like "review this spec," "is this spec complete," or "why do I keep getting stuck implementing this."
---

# Spec Review

Reviews a design or technical spec the way an implementer reading it for the first time would — surfacing exactly where it would leave them stuck, guessing, or building the wrong thing. The goal isn't to critique writing quality; it's to catch the gaps and contradictions that turn into mid-implementation blockers, back-and-forth with the spec's author, or rework after the fact.

## Workflow

### Step 1: Break the spec into sections

Split into logical sections following the spec's own structure where it has one (by feature, by endpoint, by user flow, by data model). If the spec has no clear sectioning, impose one based on distinct concerns — data model, business rules, API contract, UI states, edge cases, error handling — so findings can be attributed precisely instead of delivered as one undifferentiated wall of feedback.

### Step 2: Check each section for three problem types

- **Missing** — something an implementer needs but the spec doesn't specify: validation rules, error/failure states, edge cases (empty input, concurrent access, permission boundaries), field types or constraints, who or what triggers this flow.
- **Incorrect / inconsistent** — something specified that contradicts another part of the spec, contradicts how the referenced system actually behaves (check against code or existing docs when available), or is internally inconsistent (e.g. two names for the same field, mismatched types between sections).
- **Excessive / out of scope** — detail that doesn't belong here: implementation prescriptions that overstep what a spec should dictate, speculative future requirements not needed for this piece of work, or detail duplicated from elsewhere that risks drifting out of sync with the source.

### Step 3: Tie each finding to concrete implementation impact

For every issue, state what would actually go wrong during implementation if it's left unresolved — not "this is unclear" but "without knowing X, Y can't be built because Z." A finding that doesn't trace to a real implementation consequence isn't worth flagging; it's what separates useful review from nitpicking.

### Step 4: Prioritize by how much it blocks work, not by where it appears in the document

- **Blocking** — implementation cannot start or proceed until this is resolved.
- **Risky** — implementation can proceed, but this gap or inconsistency creates a real chance of rework later.
- **Minor** — worth fixing, but doesn't block progress or risk rework.

### Step 5: Report using `assets/template.md`

Present findings section by section, blocking issues first within each section, and close with a single priority-ordered punch list across the whole spec — this is what lets the user work through issues in order instead of re-deriving the priority themselves. Keep each finding specific and quotable (reference the actual section or line) so it can be brought back to the spec's author verbatim.

## Guardrails

- Don't invent requirements or quietly fill in gaps with your own assumptions about what the spec should say — the job is to surface what's missing, not resolve it on the author's behalf.
- If code or a running system is available to check the spec against, treat it as the source of truth over the spec's claims — specs go stale, running systems don't lie — and flag the mismatch explicitly rather than silently trusting one over the other.
- Don't flag prose or formatting issues that carry no implementation impact — every finding should trace back to something a real implementer would get stuck on.
- If the spec references something outside what was provided (another doc, a system you can't see), say so explicitly rather than reviewing around the gap silently.
