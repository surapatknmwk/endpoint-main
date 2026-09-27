---
name: pr-review
description: Orchestrates a full PR review between two git branches — pulls latest refs, explores the diff/commits via the pr-explorer subagent, then writes a structured markdown report (summary, key changes, severity-tagged issues, improvement suggestions) to docs/delivery/pr/[epic]/. Use when the user gives two branch names and asks for a PR review, a branch comparison writeup, or "review branch A into branch B". Ported from the team's Copilot code-reviewer agent so the same workflow and report format work in Claude Code.
---

# PR Review

Orchestrates a PR review between two branches (Branch A = source merging in, Branch B = target) and produces a markdown report in `docs/delivery/pr/[epic]/`.

## Args

Expect `<branch-a> <branch-b>` (and optionally which submodule to operate in, since this is an umbrella repo — `ra-account-service` or `ra-account-webapp`). Ask if either is missing or ambiguous.

## Workflow

Track these steps with TodoWrite.

1. **Check current branch.** Run `git branch --show-current` (in the correct submodule directory) and note it — you must switch back to it when the workflow finishes.
2. **Initialize the report file.** Create `docs/delivery/pr/[epic]/<branch-a>-into-<branch-b>.md` (pick `[epic]` from the branch name if it encodes one, e.g. `feat-contract-search-refactor`, else use `misc`). Write the skeleton from the Output Format below so the file exists before delegating.
3. **Explore the PR.** Spawn the `pr-explorer` subagent (via Agent tool, `subagent_type: pr-explorer`) with Branch A, Branch B, and the submodule path. Run it in the foreground — you need its findings before writing the report. Do not duplicate its git digging yourself.
4. **Summary.** From the explorer's report, write a concise paragraph on the PR's purpose/scope, files-changed counts, and services touched. Add an ASCII architecture-flow diagram only if the explorer flagged new/changed inter-service or inter-module call paths.
5. **Key changes.** Turn the explorer's per-file findings into the table + code-snippet blocks described below, one block per service/module.
6. **Issue identification.** Independently judge the explorer's "risks/oddities" list plus your own read of the diff against this repo's mandatory review checklist (see `CLAUDE.md` — presence-check vs value-check, unconfirmed contracts, mock-only tests on join queries, unguarded controller inputs, untested failure paths, LIKE-escaping, missing branch coverage, duplicate-on-second-occurrence, unnamed literals). Tag each with 🔴 High / 🟠 Medium / 🟡 Low.
7. **Improvement suggestions.** For each High/Medium issue, write a Before/After snippet. Low issues get a single snippet.
8. **Write and finalize the report**, then switch back to the branch noted in step 1.

## Output Format

The report file must follow this structure exactly (section numbering starts at 2; section 1 is the internal exploration step and isn't rendered):

```markdown
# PR Review: `<branch-a>` → `<branch-b>`

**Date:** <YYYY-MM-DD>
**Branch A (Source):** `<branch-a>`
**Branch B (Target):** `<branch-b>`
**Commit:** `<short-sha>` — `<commit-message>`
**Author:** <Name> `<email>`

---

## Status: Complete

---

## 2. Summary

<One paragraph describing the overall purpose and scope of the PR.>

**Files changed:** <N> files (<X> added, <Y> modified)
**Services touched:** <list of services/modules affected>

### Architecture Flow

\```
<ASCII diagram showing the call/data flow introduced by this PR, if applicable>
\```

---

## 3. Key Changes

### <Service/Module A> (`<folder>`)

| Component | Change | File | Lines |
|-----------|--------|------|-------|
| `ClassName` | <What changed and why> | [ClassName.java](<relative/path/to/ClassName.java>) | L<start>–L<end> |

#### Code Snippet — `<ClassName>` (<brief label, e.g. "new method" or "modified logic">)

\```java
// [<relative/path/to/ClassName.java>:<line-number>]
<relevant code snippet — 5–15 lines centred on the change>
\```

_(Repeat a table + snippet block per service/module. Use the column set that fits — 4-column for modifications, 5-column for new additions with type. Always include at least one snippet per module that shows the most significant change.)_

---

## 4. Identified Issues

### 🔴 High

| # | Issue | File | Lines |
|---|-------|------|-------|
| N | **<Short title>** — <Description of the issue and its impact.> | [FileName](<relative/path>) | L<n> |

#### Issue N — `<Short title>`

\```java
// [<relative/path/to/FileName>:<line-number>]
<code snippet showing the problematic code>
\```

> **Why it matters:** <One-sentence explanation of the risk or impact.>

### 🟠 Medium

_(same structure as High)_

### 🟡 Low

_(same structure as High)_

_(Omit a severity section entirely if there are no issues at that level.)_

---

## 5. Improvement Suggestions

1. **<Title>** _(ref: Issue #N)_

   <Explanation of the suggested improvement.>

   **Location:** [FileName](<relative/path>) L<start>–L<end>

   **Before:**
   \```java
   // [<relative/path>:<line-number>]
   <current code>
   \```

   **After:**
   \```java
   <suggested replacement code>
   \```

_(Number each suggestion. Reference the issue number from Section 4 where applicable. Always include a Before/After snippet for High and Medium issues; a single snippet is sufficient for Low issues.)_
```

### Report Rules

- **File references must be clickable markdown links** using workspace-relative paths. Never use plain backtick filenames in the `File` column.
- **Every table must have a `File` column and a `Lines` column** — `File` is a clickable link; `Lines` is a 1-based range (`L42–L58`) or single line (`L42`). For issues spanning multiple files, separate links with ` / ` and list corresponding line ranges.
- **Every significant change and every issue must have a code snippet** placed directly below its table row, first line formatted as `// [path/to/File.java:42]`.
- **Improvement suggestions for High and Medium issues must include Before/After snippets.** Low-severity suggestions may use a single snippet.
- **Issue severity** uses 🔴 High, 🟠 Medium, 🟡 Low.
- **Architecture Flow** diagram only when the PR introduces or changes inter-service communication or a significant new call path.
- **Use the correct language fence** per file type — `java`, `ts`/`tsx`, `sql`, `xml`, etc.
