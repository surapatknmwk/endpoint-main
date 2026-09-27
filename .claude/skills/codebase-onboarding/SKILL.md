---
name: codebase-onboarding
description: Quickly orient in an unfamiliar codebase or repository — summarize its architecture, entry points, major components, key dependencies, and how to run/test it locally. Stack-agnostic, works for any language or project layout. Use this skill whenever the user opens an unfamiliar repo and asks things like "help me understand this codebase," "where do I even start," "explain how this project is organized," or shares a repo and asks what it does — even without using the word "onboarding."
---

# Codebase Onboarding

Builds a working mental model of an unfamiliar codebase efficiently, without reading every file. The goal is the same one a new engineer needs on day one: know what this thing does, how it's organized, where to start reading, and how to run it — well enough to make a safe first change.

## Workflow

### Step 1: Read the map before the territory

Before opening individual source files, check what the project already tells you about itself:

- README, CONTRIBUTING, or any `docs/` folder.
- Package manifest (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, etc.) — this reveals the language, framework, and major dependencies immediately.
- Top-level folder structure — often reveals the architectural style (e.g. `services/`, `apps/`, layered `controllers/models/views`, monorepo packages) before you've read a line of logic.
- Any existing `CLAUDE.md` or agent-instructions file, which may already document conventions.

### Step 2: Find the entry points

Identify how the system actually starts and runs: the main file, the server start command, the CLI entry point, or (for a library) the public API surface. Then trace, at a high level, how a request/job/input flows through the system — what receives it first, what it touches next. You're building a flow diagram in your head, not memorizing every function.

### Step 3: Map components, don't read everything

Identify the major modules/services and what each is responsible for. Sample a representative file or two per module rather than reading exhaustively — the goal at this stage is knowing where to look later, not full comprehension of every line.

### Step 4: Note key dependencies and integration points

Identify what the system depends on externally: databases, third-party APIs, message queues, other internal services. Note where configuration and secrets are wired in (env vars, config files) without inspecting actual secret values.

### Step 5: Summarize back in a structured way

Report back with:

- **What it does** — 2–3 sentences, plain language.
- **How it's organized** — the major components and their responsibilities.
- **Entry points** — how it runs, how a request flows through it.
- **How to run/test locally** — the actual commands, pulled from README/scripts/CI config, not guessed.
- **Open questions or gaps** — anything unclear from the code alone that's worth confirming with the team.

## Guardrails

- Don't present an inference as a fact. If something isn't clear from the code or docs, say so explicitly rather than filling the gap with a plausible-sounding guess.
- Match depth to the actual question — "how do I run this locally" doesn't need a full architecture summary, and "explain the whole system" shouldn't stop at entry points.
- Don't fabricate run/test commands — pull them from what the repo actually defines (README, `package.json` scripts, Makefile, CI config), or say they weren't found.
