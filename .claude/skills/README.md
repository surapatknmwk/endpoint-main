# Skills

Skills available to AI coding agents working in this repo. Each is a directory under `.claude/skills/`
containing a `SKILL.md` with the skill's trigger conditions and instructions.

| Skill | Purpose |
|---|---|
| [`codebase-onboarding`](codebase-onboarding/SKILL.md) | Orients in an unfamiliar codebase — architecture, entry points, major components, how to run/test locally. Stack-agnostic. |
| [`debugging`](debugging/SKILL.md) | Systematic root-cause investigation for a bug, error, stack trace, or unexpected behavior. Stack-agnostic. |
| [`refactoring`](refactoring/SKILL.md) | Restructures existing code without changing external behavior — extracting functions, removing duplication, splitting oversized files/classes, simplifying conditionals. |
| [`propose-refactor`](propose-refactor/SKILL.md) | Produces a refactor plan (risk/effort/impact) for review and feedback before any code is changed. |
| [`spec-review`](spec-review/SKILL.md) | Reviews a design/technical spec for gaps, inaccuracies, and inconsistencies before implementation starts. |
| [`task-breakdown`](task-breakdown/SKILL.md) | Breaks a feature request or requirement into concrete, independently implementable engineering tasks with dependencies and risk called out. |
| [`test-writing`](test-writing/SKILL.md) | Writes unit/integration tests for existing code, including missing edge-case coverage. |
| [`technical-docs-writer`](technical-docs-writer/SKILL.md) | Generates technical documentation (API endpoints, architecture/data flow, business logic) for a feature or service as a Markdown file. |
| [`spring-boot3-review`](spring-boot3-review/SKILL.md) | Checklist of Spring Boot 3 / Java 21 framework-level anti-patterns (DI, `@Transactional`, JPA N+1, exception handling, bean scope, config, Spring Security 6) — complements the data-access checklist in `AGENTS.md`. Supports diff-scoped review (git diff / PR only). |
| [`react-review`](react-review/SKILL.md) | Checklist of React 18 / TypeScript pitfalls tailored to this webapp's stack (hooks, Context API, react-hook-form + yup, antd/react-bootstrap). Supports diff-scoped review. |
