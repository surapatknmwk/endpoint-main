---
name: task-breakdown
description: Break a feature request, project, or vague requirement into concrete, independently implementable engineering tasks or tickets, with dependencies and risk called out. Stack-agnostic — works for planning any kind of software work. Use this skill whenever the user wants to plan out a feature, asks "how should I break this down," "help me plan this out," "turn this into tickets/tasks," or describes a feature/requirement and needs it structured into actionable work before building it.
---

# Task Breakdown

Turns a feature request or requirement into a set of concrete, sequenced tasks that can actually be picked up and implemented — as opposed to a vague list of "things to do" that still requires another round of thinking before anyone can start.

## Workflow

### Step 1: Clarify the actual goal and constraints

Before breaking anything down, make sure the target outcome is clear: what does "done" look like, is this exploratory or well-specified, is there a deadline or scope constraint that should shape the plan. Ask rather than assume — inventing scope or requirements that weren't stated leads to a plan that solves the wrong problem.

### Step 2: Identify dependencies and natural sequencing

Work out what has to happen before what — e.g. a schema/data-model change typically precedes the API change that depends on it, which typically precedes the UI that consumes it. Getting the order right up front avoids a plan where task 3 silently blocks on task 7.

### Step 3: Break into tasks that are independently implementable and verifiable

Each task should:

- Have a clear, checkable "done" state.
- Be small enough to reason about and review on its own, but not so small that it loses meaning (e.g. "add a field to the schema" is fine; "write one line of code" is not a task).
- Ideally be shippable or reviewable independently, rather than only making sense once every other task is also done.

### Step 4: Call out risk and unknowns explicitly

If part of the work has unclear requirements or real technical uncertainty (unfamiliar API, unproven approach, unclear edge-case behavior), flag it rather than folding it into a normal task with false confidence. Consider proposing a small spike/investigation task first when the uncertainty is high enough to affect the rest of the plan.

### Step 5: Size only if useful

If the user wants rough sizing (small/medium/large, or a time estimate), provide it — but don't force precision that wasn't asked for, and don't let estimation become the focus over getting the sequencing and scope right.

## Output format

Present each task with: a short title, what "done" looks like, and anything it depends on. Group by sequence/phase where there's a clear order, and call out flagged risks separately so they don't get buried in the list.

## Guardrails

- Don't invent product requirements or scope that weren't stated — ask instead of assuming, especially for ambiguous UX or business-rule decisions.
- Don't over-decompose into tasks so small they carry no real "done" criteria — every task should represent an actual, testable unit of progress.
- Surface risk and unknowns as their own category rather than hiding them inside a normal-looking task.
