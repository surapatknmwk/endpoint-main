---
name: test-writing
description: Write unit or integration tests for existing code, including filling in missing edge-case coverage, in any language or test framework. Stack-agnostic. Use this skill whenever the user asks to write tests, add test coverage, test a specific function/module, or improve/expand an existing test suite — even if they just say something like "this doesn't have any tests" or "make sure this edge case is covered."
---

# Test Writing

Writes tests that verify actual intended behavior, not tests that just restate what the implementation currently does. A test suite's value comes from catching real breakage — a test that passes regardless of whether the logic is correct isn't providing coverage, it's providing false confidence.

## Workflow

### Step 1: Match existing conventions

Before writing anything, look at how the project already tests things: framework, file naming/location convention, assertion style, how mocking/fixtures are typically done. New tests should look like they belong in the existing suite, not like a different author wrote them.

### Step 2: Decide what actually needs coverage

Prioritize in this order:

1. **Edge cases and boundaries** — empty input, zero, negative numbers, max/min values, off-by-one boundaries.
2. **Error conditions** — invalid input, failure of a dependency, what happens when things go wrong.
3. **Non-obvious business rules** — anything with a specific reason behind it that isn't self-evident from the code.
4. **The happy path** — usually already partially covered; a couple of clear cases is enough, don't pad with redundant variations.

Edge cases and error handling are usually the actual gap in existing suites — the happy path is rarely the part that's under-tested.

### Step 3: One behavior per test

Each test should verify one thing and have a name that describes the scenario and expected outcome (e.g. `returns_empty_list_when_no_matches_found`, not `test1` or `test_function`). This makes failures immediately informative — you shouldn't have to read the test body to know what broke.

### Step 4: Test behavior, not implementation

Prefer asserting on the public interface / observable output over internal implementation details (private state, internal call order, specific intermediate values). Implementation-detail tests break the moment someone refactors, even when nothing about correctness changed — which trains people to ignore failing tests.

### Step 5: Mock sparingly

Use real inputs and fixtures wherever practical. Reserve mocking for things that are genuinely external or non-deterministic — network calls, databases, the current time, randomness. Over-mocking tends to produce tests that pass even when the real integration would fail.

### Step 6: Run and sanity-check the tests

Run the new tests to confirm they pass. Where feasible, also sanity-check that they're not vacuous — briefly verify a test would actually fail if the underlying logic were broken (e.g. temporarily break the logic, confirm the test catches it, then revert).

## Guardrails

- Don't write a test that simply mirrors whatever the code currently does — that only locks in existing behavior, correct or not. Test against the intended/spec'd behavior.
- If the intended behavior for an edge case is genuinely ambiguous or undocumented, ask or flag it — don't silently pick an interpretation and assert on it as if it were confirmed.
- Don't inflate coverage numbers with low-value tests (e.g. testing getters/setters with no logic) at the expense of the edge cases that actually matter.
