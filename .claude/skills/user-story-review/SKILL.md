---
name: user-story-review
description: Review a user story (from ClickUp, a pasted description, or a file) for clarity, completeness, INVEST quality, and 3-layer acceptance criteria coverage, then produce an HTML review report. Use when asked to "review this user story", "check this ticket's ACs", or "verify this story is ready for dev".
---

Review a user story for clarity, completeness, and alignment with best practices, then write findings to an HTML report.

## Input

The user story may come from:
- A ClickUp task ID/URL — fetch it with the ClickUp MCP tools.
- Pasted text in the chat.
- A file in the repo.

If none of these is provided or the reference is ambiguous, ask the user which one to review before proceeding.

## Review dimensions

1. **Format** — follows `As a [type of user], I want [an action] so that [a benefit/a value].`
2. **Granularity** — story is small enough for one sprint; flag if it should be split (see `verify-user-story` skill).
3. **Clarity** — no ambiguous terms, undefined actors, or vague outcomes.
4. **Completeness** — background/context present, page info (name/title/URL) present when it's a UI story, no missing edge cases.
5. **Acceptance Criteria coverage** — ACs must be Given/When/Then tables and must cover all 3 layers below. Missing a layer is a gap to call out explicitly, not something to silently add.

| Layer | Covers | Example focus |
|-------|--------|----------------|
| Functional | What the user does and sees in the UI | Button states, validation messages, page navigation |
| Backend | API/service behavior triggered by the action | Request/response shape, error codes, business rule enforcement |
| Database Query | Data read/written as a result | Which table/columns are affected, expected row state before/after |

For each layer that exists, check it against ZOMBIES (Zero, One, Many, Boundary, Interface, Exception, Scenario) to see if edge cases are missing.

## Hidden acceptance criteria

Read every part of the story outside the AC tables — title, background, description prose, comments, attached notes/screenshots. Look for statements that describe a rule, behavior, constraint, or expected outcome (e.g. "only active users can...", "this should not apply to cancelled bookings", "response must return within X"). If such a statement is not already represented as a Given/When/Then row, flag it as a **hidden AC**: quote the source line, state which layer it belongs to (Functional/Backend/DB), and propose the row to add. Do not silently add rows to the story yourself — report them as findings.

## Output

Identify ambiguities, missing information, or potential improvements. For each finding, state:
- **What's missing/wrong**
- **Why it matters** (e.g. dev will guess, QA can't test, DBA can't verify)
- **Suggested fix** (concrete rewording or an added AC row)

Write the findings as an HTML report and save it to:
`docs/delivery/review-user-story/[domain/topic/module]/[proper-name].html`

### HTML report requirements

- **Introduction** — brief the user's prompt/task that generated this report (including file path context), plus a short explanation of the report's purpose and contents.
- **Diagrams** — use ASCII diagrams in `<pre><code class="language-none">` blocks (no external image files); pair each diagram with a companion table explaining its components.
- **Sidebar navigation** — include a sidebar nav for quick access to sections, with a consistent color scheme and font matching the report design.
- **Traceability** — reference file paths throughout; include a "How to reproduce" section (commands/scripts used) and a "How to verify" section (expected outputs/checks). Include a "Next steps / follow-up questions" section.

#### Required `<head>` addition

```html
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/themes/prism-tomorrow.min.css" />
```

#### Required CSS overrides (inside `<style>`)

```css
/* Default font family and body background */
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: #f8f9fa;
  color: #333;
}

/* Sidebar (nav) background */
nav {
  background: #1e293b;
  color: #e2e8f0;
}

nav a:hover {
  background: #334155;
  color: #fff;
}

/* Keep page layout/sizing when Prism adds its own pre styles */
pre[class*="language-"] {
  background: #1e293b !important;   /* match page dark bg */
  border-radius: 8px;
  padding: 16px;
  font-family: 'Fira Code', monospace;
  font-size: 13px;
  line-height: 1.5;
  margin: 12px 0 20px;
  overflow-x: auto;
}
/* Prevent Prism from restyling inline prose code */
:not(pre) > code[class*="language-"] {
  background: #f1f5f9 !important;
  color: #333 !important;
  padding: 2px 6px !important;
  border-radius: 4px;
  font-family: 'Fira Code', monospace;
  font-size: 13px;
}
```

##### ⚠️ Known pitfall: inline-code CSS bleeding into ASCII diagrams

Reports commonly add one more rule for plain inline prose code (file paths, symbol
names) that has **no** language class, e.g. `` `pk_customer_code` ``. If that
selector is not scoped away from `<pre>`, it also matches the plain `<code>`
inside ASCII-diagram blocks (`<pre class="ascii"><code>...</code></pre>`), which
also have no language class. The diagram's `<pre>` sets a dark background/light
text, but the wrongly-matched rule then paints the `<code>` background light —
while the text color still inherits light-on-dark — producing **light text on a
light background that is unreadable**. This exact bug shipped in a prior report.

Always scope inline-code rules to exclude `<pre>` descendants, and add a
belt-and-suspenders reset so anything inside `<pre>` (ascii or language-tagged)
never picks up the inline-code styling:

```css
/* Inline prose code ONLY — the ":not(pre) >" guard is required, otherwise this
   rule also matches the plain <code> inside ASCII-diagram <pre> blocks. */
:not(pre) > code:not([class*="language-"]) {
  background: #f1f5f9;
  color: #333;
  padding: 2px 6px;
  border-radius: 4px;
  font-family: 'Fira Code', monospace;
  font-size: 12.5px;
}

/* Defensive reset: any <code> inside a <pre> always inherits from its parent —
   never gets the inline-code background/color above. */
pre code {
  background: transparent;
  padding: 0;
}
```

After adding this CSS, open the rendered HTML and visually confirm every ASCII
diagram is legible before delivering the report — do not just trust the CSS by inspection.

#### Required scripts (before `</body>`)

Load only the language components actually used in the report:

```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/prism.min.js"></script>
<!-- Add only the languages present in the report -->
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-sql.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-java.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-typescript.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.29.0/components/prism-json.min.js"></script>
```

#### How to mark up code blocks

Always set the language class on **both** `<pre>` and `<code>`:

```html
<!-- SQL / PL/SQL -->
<pre class="language-sql"><code class="language-sql">SELECT * FROM IJS_AGREEMENT_HEADER WHERE CONTRACT_NO = :id;</code></pre>

<!-- Java -->
<pre class="language-java"><code class="language-java">public List&lt;ContractDTO&gt; findContracts(String contractNo) {
    return jdbcTemplate.query(SQL, new BeanPropertyRowMapper&lt;&gt;(ContractDTO.class), contractNo);
}</code></pre>

<!-- TypeScript -->
<pre class="language-typescript"><code class="language-typescript">getData(params: SearchParams): Observable&lt;ContractList&gt; {
    return this.http.get&lt;ContractList&gt;('/api/contracts', { params });
}</code></pre>

<!-- JSON -->
<pre class="language-json"><code class="language-json">{
  "contractNo": "ABC-001",
  "status": "A"
}</code></pre>
```

#### Language reference

| Language | Class | CDN component |
|----------|-------|---------------|
| SQL / PL/SQL | `language-sql` | `prism-sql.min.js` |
| Java | `language-java` | `prism-java.min.js` |
| TypeScript | `language-typescript` | `prism-typescript.min.js` |
| JavaScript | `language-javascript` | *(included in core)* |
| JSON | `language-json` | `prism-json.min.js` |
| XML / HTML | `language-markup` | *(included in core)* |
| Shell / Bash | `language-bash` | `prism-bash.min.js` |

> ASCII diagrams and plain-text flow charts must use plain `<pre><code>` **without** a language class so Prism ignores them.

After writing the report, summarize the top 3 findings in chat and link the report file — do not just say "report created".