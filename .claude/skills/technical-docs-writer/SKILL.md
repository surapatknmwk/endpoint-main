---
name: technical-docs-writer
description: Generate technical documentation for a software feature or service as a Markdown file, saved in that service's repo. Covers API endpoints/contracts, architecture & data flow, and business logic — works regardless of language or stack. Use this skill whenever the user asks to "document a feature", "write docs for this service", "explain how X works for the team", wants a docs update after building something, or needs to create/maintain technical documentation for any backend service or frontend. Also trigger when the user shares or references source code and asks for documentation, or verbally describes a feature and wants it turned into proper docs. Push to use this skill even if the user just says "help me document this" without more detail.
---

# Technical Docs Writer

Generates onboarding-quality technical documentation for a feature or service, stack-agnostic. The target reader is a new engineer on the team who needs to understand and safely modify this feature without asking around.

## Workflow

### Step 1: Establish the source of truth

- **If source code is available** (uploaded, in a repo, or pasted in chat): read it directly. Code is the primary source of truth for endpoint paths, field names, types, and logic — never guess these.
- **If the user describes the feature verbally**: ask targeted clarifying questions for anything needed to fill the template below. Do not infer or invent endpoint names, request/response shapes, or business rules that weren't stated or found in code.
- **If both are available**: use the code to verify what was said verbally. If they disagree, flag the mismatch to the user instead of silently picking one.

### Step 2: Check existing conventions first

Before writing, look for an existing `docs/` folder, README, or prior docs in the same repo/project. Match their heading structure, tone, and depth. Consistency across services matters more than any single doc looking polished — a team documenting 10+ services needs them to feel like one system, not ten different authors.

### Step 3: Structure the document

Use `assets/template.md` as the default structure:

1. **Overview** — what the feature does and why it exists. 2–4 sentences, no fluff.
2. **Architecture & Data Flow** — how it fits into the broader system: what calls it, what it calls, which data stores/queues/other services it touches. Note upstream/downstream dependencies explicitly by name.
3. **API Endpoints / Contract** — method, path, auth requirement, request/response shape, key error/status codes. Use a table for the endpoint list.
4. **Business Logic** — validation rules, edge cases, and the *why* behind non-obvious decisions, not just the *what*.

Skip a section entirely rather than padding it if it doesn't apply (e.g. a background worker with no HTTP endpoints has no "API Endpoints" section).

### Step 4: Writing style

- Engineer-to-engineer tone. No marketing language, no unnecessary adjectives, no restating obvious framework boilerplate (don't explain what a REST API is).
- Use tables for endpoint lists and field definitions.
- Use code blocks with real request/response examples pulled from actual code or actual user-provided examples — never invented placeholder values dressed up as real ones.
- Each section should be as short as possible while staying complete.

### Step 5: Save

Save as a Markdown file inside the service's repo:
- In `docs/` if that folder already exists.
- Otherwise, alongside the README, matching whatever file naming convention the repo already uses.

## Guardrails

- Never fabricate endpoint paths, field names, status codes, or business rules. If something is missing, either ask the user or mark it explicitly as `<!-- TODO: confirm with team -->` in the output — don't fill the gap with a plausible-sounding guess.
- If the code and the user's verbal description conflict, surface the conflict rather than resolving it silently.
- Optimize for a future engineer's ability to safely change this code, not for making the doc look impressive.