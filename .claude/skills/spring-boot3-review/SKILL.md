---
name: spring-boot3-review
description: Review or write Spring Boot 3 service-layer code (Java 21) against a checklist of common framework-level anti-patterns — dependency injection, @Transactional boundaries, JPA/Hibernate N+1 and lazy loading, exception handling, bean scope/lifecycle, configuration properties, validation, and Spring Security 6. Complements the query/SQL-focused checklist in AGENTS.md — this one is Spring-framework-specific, not data-access-specific. Use whenever writing new @Service/@Component/@Repository/@Controller code, reviewing a PR that touches Spring Boot wiring or lifecycle, or when the user wants to learn/avoid common Spring Boot mistakes ("what am I doing wrong with Spring here", "review this service class", "teach me Spring Boot pitfalls"). Also use in diff-scoped mode when the user asks to review only the changed/diffed code — "review my diff", "review just what I changed", "check my uncommitted changes", "review this PR" — instead of the whole file.
---

# Spring Boot 3 Service Review

A passive checklist for catching Spring-framework-level mistakes in Spring Boot 3 / Java 21 code —
things that compile fine, pass a quick manual test, and then break under load, in a different
profile, or six months later when someone touches the class again. This does not replace the
data-access checklist already in `AGENTS.md` (presence-check vs value-check, LIKE escaping,
Testcontainers for native queries, etc.) — apply both together when a change touches a service that
also does DB access.

## How to use this

Apply it in two situations:

1. **Writing new code** — before finishing a `@Service`, `@Component`, `@Controller`, or config
   class, scan the relevant section(s) below and check each item against what you just wrote.
2. **Reviewing existing code** — walk section by section, flag violations with the concrete
   consequence ("this will double-query under load because...", not just "this looks off"), and
   propose the fix inline. Don't just point out anti-patterns — explain *why* each one is wrong so
   it sticks as a learning point, not just a lint result.

Group findings by category (matching sections below) and order by real impact: correctness/data bugs
first, then performance, then style/maintainability. Don't flag something as wrong without being able
to say what breaks and under what condition.

## Diff-Scoped Mode

Use this mode instead of a whole-file review when the user asks to review "the diff," "what I
changed," "my uncommitted changes," or a PR — anywhere the intent is clearly "just the delta," not
the whole file.

1. **Get the diff.** Prefer `git diff --staged`; if nothing is staged, fall back to `git diff`. If
   the user names a PR/branch, use `git diff <base>...<branch>`. If none of that is available and
   the user hasn't pasted a diff, ask for one rather than guessing what changed.
2. **Read enough context around each hunk to judge it correctly — don't review the diff text in
   isolation.** Several checklist items are only detectable with context that may not appear in the
   diff itself:
   - A new instance field added to a `@Service` class needs the whole class read to confirm the
     bean is singleton-scoped and whether the field is genuinely stateless.
   - A new line inside a loop needs the loop's start read to tell whether it's the N+1 pattern.
   - A new call to a method needs that method's signature/annotations read to tell whether it's
     `@Transactional`, `@Async`, private, etc.
   Pull the full method or class via `Read`/`git show` when a changed line's correctness depends on
   something outside the visible diff hunk.
3. **Only flag issues the diff introduces or makes worse.** If a hunk sits next to a pre-existing
   problem the diff doesn't touch or worsen, don't fold it into the main findings — note it
   separately as "pre-existing, not introduced by this change" so the user can tell what's actually
   their responsibility in this change vs. what was already there.
4. **Cite file + line number from the diff** for every finding, same as a normal review, so it's
   easy to jump to.
5. Everything else — categorization, impact-first ordering, explaining *why* — works the same as
   whole-file mode (see sections below).

## 1. Dependency Injection & Bean Wiring

- **Field injection (`@Autowired` on a field) instead of constructor injection.** Field injection
  hides required dependencies, makes the class impossible to instantiate without Spring (breaks
  plain-`new` unit tests), and allows circular dependencies to compile when they shouldn't. Use
  constructor injection; with Lombok, `@RequiredArgsConstructor` on `final` fields is the standard
  pattern in this codebase.
- **`@Autowired` on a single constructor.** Redundant since Spring 4.3 — if there's exactly one
  constructor, Spring uses it automatically. Leave it off; only needed when there are multiple
  constructors and you must disambiguate.
- **Injecting a concrete class instead of an interface** when the class has (or should have) an
  interface — makes mocking and swapping implementations harder for no benefit.
- **`@Lazy` used to paper over a circular dependency.** A circular dependency between beans is a
  design smell (usually two services that should be merged, or a piece of logic that belongs in a
  third class). `@Lazy` hides the symptom without fixing the cycle.
- **New `RestTemplate`/`WebClient`/`ObjectMapper` instantiated inline inside a method** instead of
  injected as a configured bean. Loses connection pooling, timeouts, and shared Jackson config;
  every call site reinvents (or forgets) configuration.

## 2. `@Transactional` Boundaries

- **`@Transactional` on a `private` method, or called from within the same class
  (self-invocation).** Spring's proxy-based AOP can't intercept private methods or internal calls —
  the annotation is silently a no-op. Move the transactional method to a separate bean, or call it
  through the injected proxy/self-reference.
- **`@Transactional` at the controller layer.** Keeps the transaction open for the whole HTTP
  request including serialization, which can hold DB connections far longer than needed. Transaction
  boundaries belong in the service layer, scoped to the actual unit of work.
- **Catching a checked or runtime exception inside a `@Transactional` method and swallowing it**,
  expecting rollback to still happen. By default, Spring only rolls back on unchecked exceptions
  that *propagate out* of the method — a caught-and-logged exception commits whatever happened
  before it. If a checked exception should roll back, declare
  `@Transactional(rollbackFor = SomeCheckedException.class)` explicitly.
- **A `@Transactional` method that also makes an external HTTP call** (another service, the Oracle
  microservice, etc.) inside the transaction. Holds a DB connection/lock for the duration of a
  network call. Do the external call outside the transaction, or split into two steps.
- **Missing `readOnly = true` on read-only query methods.** Not just an optimization hint — for
  Hibernate it also disables dirty checking on loaded entities, avoiding accidental unintended
  writes from a service method that was only meant to read.
- **Long-running loops with DB writes inside a single `@Transactional` method** (e.g. batch-updating
  hundreds of rows one at a time in one transaction) — holds locks and grows the transaction log
  unnecessarily. Chunk into smaller transactions for bulk operations.

## 3. JPA / Hibernate

- **Default `FetchType.EAGER` on `@ManyToOne`/`@OneToOne`** (or forgetting that `@ManyToOne` is
  EAGER by default). Loads related entities even when the caller never touches them. Default to
  `LAZY` and fetch explicitly (join fetch, entity graph) only where needed.
- **The classic N+1: looping over a collection and accessing a lazy association inside the loop.**
  Each iteration fires a separate query. Look for this specifically in any method that returns a
  list and then maps/enriches it — use a `JOIN FETCH`, `@EntityGraph`, or a projection instead.
  This is the JPA-layer version of the "presence-check vs value-check" query bug already flagged in
  `AGENTS.md` — same root cause (not thinking about what SQL actually gets generated).
- **Accessing a lazy association after the persistence context/transaction has closed**
  (`LazyInitializationException` waiting to happen, or worse, silently open-session-in-view masking
  it). Fetch what's needed inside the transactional boundary, or map to a DTO before returning.
- **Using `@Entity` classes directly as REST response/request bodies.** Couples the API contract to
  the DB schema, risks leaking lazy-load exceptions or internal fields, and makes it easy to
  accidentally accept fields (mass assignment) the client shouldn't be able to set. Map to a
  DTO/record at the controller boundary.
- **`saveAll()` / repeated `save()` calls without batching configured**
  (`spring.jpa.properties.hibernate.jdbc.batch_size`), turning a bulk insert into N round trips.
- **Not overriding `equals()`/`hashCode()` on `@Entity` classes** (or using the JPA-generated ID in
  them incorrectly) — breaks correctness of entities used in Sets or compared before the ID is
  assigned (transient/detached state).

## 4. Exception Handling

- **A new local `try/catch` + custom error response inside a controller**, bypassing the shared
  `GlobalExceptionHandler`/`BusinessException` pattern already established in this codebase.
  Inconsistent error shapes make the API unpredictable for consumers. Throw `BusinessException` (or
  the appropriate typed exception) and let the global handler shape the response.
- **Catching `Exception` (or worse, `Throwable`) broadly** instead of the specific exception type
  that can actually be thrown — hides real bugs (NPEs, programming errors) behind the same generic
  handling as expected failure cases.
- **Catching an exception only to log it and continue**, leaving the caller with no way to know the
  operation partially failed. If a failure is recoverable, that should be a deliberate, documented
  decision — not a side effect of a `catch` block someone added to stop a stack trace from showing.
- **Losing the original exception** by not passing it as the cause (`throw new
  BusinessException(msg)` instead of `throw new BusinessException(msg, e)`) — destroys the original
  stack trace, making production incidents much harder to root-cause.

## 5. Configuration & Properties

- **`@Value("${some.property}")` scattered across multiple classes** for the same config value
  instead of a single `@ConfigurationProperties`-bound class. Harder to see all config in one place,
  no validation, easy to typo the property key in one of the many places it's used.
- **No default value and no validation on a required property** — a missing/misspelled key in
  `application-{profile}.yml` fails at first use (or silently injects `null`) instead of failing
  fast at startup. Use `@ConfigurationProperties` with `@Validated` + Bean Validation annotations so
  Spring refuses to start with bad config.
- **Environment-specific values (URLs, credentials, feature flags) hardcoded in `@Value` defaults**
  instead of living only in the profile YAML — makes it easy to accidentally ship a dev value to
  prod.
- **Profile-specific beans without `@Profile`**, relying on property overrides alone to change
  behavior across environments where a different bean implementation would be clearer and safer.

## 6. Bean Scope & Lifecycle

- **Mutable instance state on a singleton-scoped `@Service`/`@Component`** (the default scope).
  Since Spring beans are singletons by default, any non-final, non-thread-local instance field is
  shared and mutated across every concurrent request — a correctness and thread-safety bug, not
  just a style issue. Keep services stateless; pass state through method parameters.
- **`SimpleDateFormat` or other non-thread-safe utility held as an instance field** on a singleton
  bean — corrupts state under concurrent access. Use thread-safe alternatives (`DateTimeFormatter`)
  or a fresh instance per call.
- **Heavy work in a bean's constructor instead of `@PostConstruct`** (or vice versa when
  dependencies aren't ready yet) — constructor runs before dependency injection completes for
  field-injected dependencies, so anything touching an injected field there can NPE.

## 7. REST Controller Layer

- **Business logic living in the controller** (branching, calculation, orchestration across
  multiple repositories) instead of the service layer — controllers should parse/validate the
  request, delegate, and shape the response.
- **Returning raw entities, raw exceptions, or a bare `ResponseEntity<String>` with an ad hoc error
  message** instead of the shared `ResponseModal` wrapper already used in this codebase.
- **Missing `@Valid`/`@Validated` on a request body**, relying on manual null checks scattered
  through the service layer instead of declarative validation at the boundary. Per the existing
  `AGENTS.md` guardrail: confirm the test harness in use can actually exercise the validation
  mechanism you pick (`MockMvcBuilders.standaloneSetup` won't trigger class-level `@Validated`
  AOP).
- **Using the wrong HTTP method/status semantics** — e.g. a `@GetMapping` that has side effects, or
  always returning `200 OK` with an error payload instead of the matching 4xx/5xx status.

## 8. Validation

- **Doing validation only in the service layer for input that already arrived as a `@RequestBody`**
  — by the time it's deserialized into a DTO, structural validation (required fields, format,
  ranges) should already have happened via Bean Validation annotations at the boundary. Reserve
  service-layer checks for business-rule validation that needs DB/context (e.g. "does this contract
  party already have an active booking party").
- **Custom regex/manual checks reimplementing what a standard annotation already does**
  (`@NotBlank`, `@Email`, `@Pattern`, `@Size`) — more code to maintain, easier to get subtly wrong.

## 9. Async & Threading

- **`@Async` method called from within the same class** — same self-invocation problem as
  `@Transactional` (Section 2); the proxy never intercepts the call, so it runs synchronously with
  no warning.
- **`@Async` without a dedicated `Executor` bean** — falls back to `SimpleAsyncTaskExecutor`, which
  creates a new unbounded thread per call instead of reusing a pool. Fine for a toy example, a
  liability under real load.
- **Manually managing threads (`new Thread(...)`, raw `ExecutorService`) instead of Spring's task
  abstractions** when running on Java 21 + Spring Boot 3.2+, where virtual threads
  (`spring.threads.virtual.enabled=true`) are the supported way to get high-concurrency I/O-bound
  execution without hand-rolled thread pools. If virtual threads are enabled, also check for
  **`synchronized` blocks around blocking I/O**, which pin the carrier thread and defeat the point
  of virtual threads — prefer `ReentrantLock` in that case.

## 10. Spring Security 6 (`SecurityFilterChain`, not `WebSecurityConfigurerAdapter`)

- **Any reference to `WebSecurityConfigurerAdapter`** — removed in Spring Security 6. Security
  config must be a `SecurityFilterChain` `@Bean`.
- **`csrf().disable()` or permissive CORS applied globally** without a documented reason — should
  be scoped as narrowly as possible, not a blanket default, especially for a service handling
  session-token auth (`rcl-token` / `BKG_SESSION`, per this service's auth model).
- **Authorization logic duplicated in both the `SecurityFilterChain` and manually in each
  controller** instead of expressed once, consistently.

## 11. Testing (Spring-specific)

- **`@SpringBootTest` used for a test that doesn't need the full context** (a pure service-logic
  test, a mapper test) — slow, and a proxy for "I didn't want to figure out the real dependencies."
  Use plain unit tests with mocked collaborators for logic, `@WebMvcTest`/`@DataJpaTest`/slice tests
  for the layer actually under test, and reserve `@SpringBootTest` for true integration tests.
- **Testing `@Transactional` rollback behavior without actually verifying a rollback occurred** —
  asserting the exception was thrown isn't the same as confirming the DB state didn't change.
- **Autowiring real beans into a unit test "for convenience"** instead of constructing the class
  under test directly with mocked dependencies — turns a unit test into a slow, brittle integration
  test without the coverage benefits of a real one.

## Guardrails

- Don't flag a pattern as wrong without stating the concrete failure mode — "field injection is bad
  practice" is a weaker finding than "field injection means this class can't be unit-tested without
  a Spring context, and won't fail fast if the bean is missing."
- Don't duplicate findings already covered by the data-access checklist in `AGENTS.md` (presence vs
  value check, LIKE escaping, named constants for status literals) — this skill is for
  framework/lifecycle issues, that one is for query correctness. Apply both, but attribute each
  finding to the right category.
- If a "violation" is actually a deliberate, documented tradeoff (e.g. `@Transactional` at the
  controller layer for a specific legacy reason), say so rather than flagging it blind — check for
  a comment or ask before assuming it's a mistake.
