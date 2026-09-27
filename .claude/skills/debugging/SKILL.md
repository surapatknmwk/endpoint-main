---
name: debugging
description: Systematically root-cause a bug or unexpected behavior in any codebase or language — an error message, a stack trace, a test failure, or "this isn't working / behaves weird" report. Stack-agnostic. Use this skill whenever the user reports something broken, pastes an error or stack trace, describes unexpected behavior, or asks "why is this happening" / "why doesn't this work," even if they haven't asked for a formal debugging process — jump straight into systematic investigation rather than guessing at a fix.
---

# Debugging

Finds the root cause of a bug through a systematic, evidence-driven process, instead of guessing at fixes and seeing what sticks. The core discipline: don't change code until you have a specific hypothesis for what's wrong, and don't call it fixed until you've verified the hypothesis was correct.

## Workflow

### Step 1: Reproduce before investigating

Don't start reading code or theorizing until the bug can be reliably triggered. Gather:

- The exact error message or stack trace, verbatim (not paraphrased).
- Steps to reproduce, and how consistently it reproduces (always, intermittently, only in some environment).
- Expected behavior vs. actual behavior.
- What changed recently, if anything — a bug that just appeared is usually connected to a recent change, and that's the fastest lead to chase first.

If reproduction isn't possible with what's available, say so explicitly rather than proceeding on assumptions about what's happening.

### Step 2: Isolate

Narrow down where the bug lives before trying to fix it:

- Bisect: if it worked before and doesn't now, find the change that broke it (recent commits, recent dependency bumps, recent config changes).
- Narrow the surface area: add logging/prints or use a debugger at suspected boundaries to see where actual behavior diverges from expected.
- Find the smallest input or scenario that still reproduces the issue — a minimal repro is usually most of the way to the root cause.

### Step 3: Form a hypothesis before touching code

State explicitly what you think is wrong and why ("I think X happens because Y") before writing a fix. This is the step that's easiest to skip under time pressure, and skipping it is what turns debugging into random trial-and-error.

### Step 4: Verify the hypothesis

Confirm the hypothesis with the smallest possible check — a targeted log line, a quick script, a temporary assertion — before committing to a fix. If the hypothesis turns out wrong, that's useful: go back to Step 2 with the new information rather than patching around the symptom.

### Step 5: Fix at the root cause

Once verified, fix the actual cause, not the closest symptom. A fix that suppresses the visible error without addressing why it happened often just moves the bug somewhere less visible.

### Step 6: Verify and prevent recurrence

- Confirm the original repro no longer triggers the bug.
- Run the existing test suite to make sure the fix didn't break anything else.
- Add a regression test that would have caught this bug — this is what stops it from coming back silently.

## Guardrails

- Don't change code speculatively hoping it helps — every change should be testing a specific hypothesis from Step 3.
- Don't declare something fixed without verifying it against the original reproduction steps.
- If the root cause is still unclear after isolating, say so and propose the next diagnostic step rather than shipping a guess.
