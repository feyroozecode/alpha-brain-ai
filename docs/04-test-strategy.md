# 04 — Test strategy: keeping an AI-built codebase honest

AI agents write code fast and break things quietly. Tests are the only
feedback channel that scales with that speed. GMaintain's discipline —
"test-aware, not strictly TDD" — got a solo engineer to **95 suites / 1,534
tests, kept green as a hard invariant**, on a codebase written mostly by
agents. This document is that discipline, generalized.

## The core stance

**Tests alongside implementation, always; test-first when the logic is
subtle.** Every feature plan includes its test plan (the /epct "Test" phase is
not optional). The agent writes the tests; the human reviews them like
production code — because for AI-generated code, the tests ARE the review.

## The gate is an invariant, not a metric

The project maintains one command that must always be green (GMaintain:
`verify` = typecheck + full test run + build) and treats "gate GREEN" as a
brain-level invariant recorded in MEMORY — with the suite/test count, so a
silently skipped suite is detectable. Rules:

- **Red gate blocks everything** — including pushes. Fix or revert; never
  "fix later".
- **Every incident becomes a regression test** plus a MEMORY.md entry. The
  test stops the recurrence; the memory stops the agent from re-introducing
  the pattern elsewhere.
- CI enforces the same gate (plus schema drift-check if you have migrations):
  what's green locally must be what's green in CI.

## Structure agents can work in

Predictability matters more than elegance — agents reproduce whatever
structure exists:

- Tests live in a dedicated tree (`tests/unit/...`, `tests/integration/...`)
  mirroring `src/`.
- **Controller/route tests**: mock the service; override auth/permission
  guards.
- **Service tests**: mock the data layer (`jest-mock-extended` or per-test
  `jest.fn()`s).
- **Integration tests**: real database, dedicated test DB; reserve them for
  what mocks can't prove (tenant isolation, transactions, cascades).
- **Mobile (Flutter/RN)**: same shape — widget/component tests mock services;
  service tests mock the API client; a handful of integration tests on real
  storage.

## Hard-won rules (each one cost a debugging session)

These generalize beyond the stack that produced them:

**Assert on exception TYPE, never on message strings.**
Error copy changes (i18n passes, rewording) broke 10 specs in one day. The
contract is *which* error class is thrown (`NotFoundException`), not its
wording. This applies to any codebase with localized or evolving messages.

**Match the coverage threshold to the command that computes it.**
A floor measured on the full suite (unit + integration) wired to a unit-only
CI command either passes with false confidence or fails every build. Decide
which command owns the floor, and document the honest number for each.

**Coverage tooling silently reports 0% when config paths are wrong.**
Jest resolves `collectCoverageFrom` globs relative to `rootDir` — a config
living in a subfolder instrumented zero files while staying green. Rule: if
the test config isn't at package root, set `rootDir` explicitly, and make an
empty coverage report *fail* (a threshold on a config with no report is a
no-op).

**Mock scope: fresh mocks per test.**
Module-level mock objects shared across `it()` blocks get polluted by
`clearAllMocks` and cross-test state (symptom: `$transaction` returning
`undefined` in one test only). Create mock objects inside `beforeEach`; set
mock *implementations* per-test, never at `describe` level; run with
`resetMocks: true`.

**A failing integration test must be re-run in isolation before you believe it.**
Shared test DB + worker contention creates order-dependent false failures
(a 403 that looks like a permission bug). Isolation pass = infrastructure
problem (fix test isolation), not a product bug.

**Your build command probably doesn't type-check.**
`vite build` (esbuild) transpiles without checking — types drifted red for
weeks while builds stayed green. Run `tsc --noEmit` (or your language's
equivalent) as an explicit gate; never trust "build passes" as type safety.

**Test invariants, not implementations, for domain rules.**
The highest-value specs assert DOMAIN.md content directly: state-machine
transition tables (every allowed transition succeeds, every forbidden one
throws), tenancy fences (tenant A can never read tenant B — a permanent
regression suite), sanitization contracts (empty-string FKs become
`undefined`). When DOMAIN.md and a spec disagree, one of them is a bug —
that mutual check is the point.

## The test ↔ brain loop

The test strategy and the brain reinforce each other:

```
bug found ──► fix + regression test ──► MEMORY.md gotcha (dated, with the rule)
                                              │ (sprint re-compression)
                            promoted to DOMAIN.md if it's a permanent invariant
                                              │
                            next agent session reads it BEFORE writing code
                                              ▼
                                   the same bug never ships twice
```

A gotcha without a test can silently regress; a test without a gotcha gets
"fixed" by an agent that doesn't understand why it exists (e.g. by asserting
the new message string). Always write both, and let the MEMORY entry cite the
spec file.

## What to skip

Stage-appropriate rigor, from the source project's own rules: MVP = high
confidence on money, auth, and data integrity; glue code can wait. Don't
chase a coverage number — chase *"every invariant in DOMAIN.md has a spec
that fails when it's violated."* Add mutation testing and property-based
invariant tests only once the basic gate has been green for a while.
