---
name: commit-message-generator
description: Generate a Conventional Commits-style branch name, commit subject, and commit description from staged/unstaged code changes (git diff). Use this skill whenever the user has made code changes and asks for a commit message, a branch name, or wants to know "what to commit" — even if they just say "gen commit msg", "ตั้งชื่อ branch ให้หน่อย", or paste a diff. This skill only GENERATES text for the user to copy into their own `git checkout -b` / `git commit -m` — it never runs git commands itself.
---

# Commit Message & Branch Name Generator

Generates three things from a code change, for the user to copy-paste themselves:

1. **Branch name** — `type/short-kebab-description`
2. **Subject** — Conventional Commits header: `type(scope): summary`
3. **Description** — a short body explaining what changed and why

**This skill never executes git commands** (no `checkout`, `commit`, `add`, etc.). It only produces text. If the user wants those commands run, tell them this skill just generates the message/branch name — they run the commands themselves.

## Step 1: Get the diff

If the user pasted a diff or described the change, use that directly.

Otherwise, if you have shell/tool access to the user's repo, get the diff yourself rather than asking them to paste it:
- Prefer staged changes: `git diff --staged`
- If nothing is staged, fall back to: `git diff`
- If neither shows anything, ask the user what changed (they may have already committed, or the change is untracked-only — check `git status` too, and `git diff --staged -- <path>` for new files may need `git diff --staged --stat` first).

If you have no shell access and the user hasn't shared a diff, ask them to paste `git diff` or `git diff --staged` output.

## Step 2: Analyze the change

Read the diff and determine:
-- **type**: one of `feature`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `perf`, `build`, `ci`
  - `issue` — bug fix (alternative to `fix`)
  - `refactor` — code restructuring, no behavior change
  - `docs` — documentation only
  - `test` — tests only
  - `hotfix` — Issue Production hotfix (alternative to `fix`)
- **scope** (optional): the module/service/component affected (e.g. `auth`, `user-service`, `api`) — infer from file paths. Given this user's stack (NestJS backend services + React frontend), a good scope is often the service/module name from the path, e.g. `src/modules/auth/...` → scope `auth`.
- **what changed**: the concrete change (functions/files touched, behavior added/removed/fixed)
- **why** (if inferable from context, comments, or the user's own explanation): the motivation — don't invent a reason that isn't supported by the diff or what the user told you.

If the diff mixes clearly unrelated changes (e.g. a feature plus an unrelated formatting pass across the whole repo), flag this to the user and suggest splitting into separate commits, but still generate a message for the diff as given.

## Step 3: Output format

Always output in this structure, in a fenced block so it's easy to copy:

```
Branch:  <type>/<short-kebab-description>
Subject: <type>(<scope>): <summary, imperative mood, no period, ≤72 chars>

Description:
<2-5 bullet points or short sentences explaining what changed and why>
```

Rules for each part:
- **Branch name**: lowercase, kebab-case, no spaces, ≤ ~50 chars, same `type` as the commit. Omit scope from the branch name unless it meaningfully disambiguates (e.g. `fix/auth-token-refresh` not `fix/auth/token-refresh`).
- **Subject**: imperative mood ("add", "fix", "remove" — not "added"/"fixes"), lowercase after the colon, no trailing period, ≤72 characters. Scope in parentheses is optional — omit it if the change spans multiple modules or scope isn't clear.
- **Description**: focused on *what* and *why*, not a line-by-line narration of the diff. Use bullet points for multiple distinct changes; one or two sentences is fine for a small change. Do not restate the subject line.

Then remind the user, briefly, that these are for them to use with their own `git checkout -b <branch>` and `git commit -m "<subject>" -m "<description>"` — don't offer to run these commands.

## Example

Given a diff that adds JWT refresh-token logic to a NestJS auth module and adds a new endpoint:

```
Branch:  feat/jwt-refresh-token

Subject: feat(auth): add refresh token endpoint

Description:
- Add POST /auth/refresh endpoint to issue new access tokens
- Add RefreshTokenService to validate and rotate refresh tokens
- Store refresh token hash in the users table
```

## Edge cases

- **Multiple unrelated changes in one diff**: generate the message for the dominant/largest change, note the mixed diff, and suggest the user split it if they haven't already staged selectively.
- **Very small change** (e.g. one-line fix, typo, config tweak): keep the description to one line or omit it if the subject is fully self-explanatory — don't pad with filler bullets.
- **No clear "why"**: don't guess at motivation. State what changed and leave it at that, or ask the user for the reason if it materially changes the message (e.g. a `fix` where the root cause matters).