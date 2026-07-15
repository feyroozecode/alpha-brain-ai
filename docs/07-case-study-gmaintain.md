# 07 — Case study: GMaintain SaaS

The project this kit was extracted from: a multi-tenant GMAO/CMMS platform
(maintenance, interventions, equipment, stock, approvals, billing) for
Francophone Africa. NestJS 11 + Prisma 7 + PostgreSQL 16 backend, React 19 +
Vite 6 frontend, Flutter mobile MVP. Built and stabilized by **one engineer**
working primarily through AI agents (Claude Code, Codex).

## Scale at the time of writing (July 2026)

| Dimension | Value |
|---|---|
| Backend feature modules | 37 |
| Source files / est. tokens | 2,293 files / ~2.06M tokens (511 test files) |
| Test gate | 95 suites / 1,534 tests — kept green as a hard invariant |
| Brain age | ~3.5 months (created 2026-03-31) |
| CHANGELOG entries | 98 sessions logged |
| ADRs | 24 |
| MEMORY gotchas | ~60 live items |

## Measured context economics

From `brain-metrics.sh` on the live repo (defaults: 25% cold-start scan
fraction, 20 sessions/month):

```
Cold-start session scan (25% of codebase):  ~515,000 tokens
Brain-loaded session:                       ~33,700 tokens (full brain incl. changelog)
Saved per session:                          ~481,000 tokens  (93.5%)
Saved per month:                            ~9.6M tokens
Brain = 1.63% of the codebase
```

The 93.5% model estimate matches reality: the project's session-observation
tooling (claude-mem) independently reports **94% context savings** across its
recorded sessions. And the typical session loads far less than the full brain
— CONTEXT + MEMORY + one ARCH section is ~3–4K tokens.

## What the health score caught

The same metrics run graded the brain **70/100 (C)**: MEMORY.md at ~2,710
tokens (hard limit 500), DOMAIN.md at ~1,206 (limit 800), 98 unarchived
CHANGELOG entries. That's the system working — three months of intense
stabilization work accumulated compression debt, and the calculator turns it
into a specific instruction: run the re-compression ritual, promote the
stabilized MEMORY rules into DOMAIN/CONTEXT, archive the changelog. A context
system without budgets would have just kept growing silently.

## What the brain demonstrably prevented

Concrete gotchas that became MEMORY entries + regression tests, and therefore
never shipped twice:

- **Spec drift**: a French error-message pass broke 10 specs asserting English
  strings → permanent rule "assert on exception type, never message" — every
  later error-path spec followed it.
- **Coverage illusion**: Jest config in a subfolder instrumented **zero files**
  while CI stayed green → rootDir rule in MEMORY; thresholds now attached to
  commands that actually measure them.
- **Type-safety illusion**: `vite build` never type-checks; 98 silent TS errors
  accumulated across 37 files before the explicit `tsc --noEmit` gate rule.
- **Repeated-plan sprawl**: agents kept generating new dated roadmaps → the
  `SOURCE-OF-TRUTH:` pointer + "never create new dated stability docs" rule.
- **Decision protection**: ADR-005 (no repository pattern) and ADR-001
  (CLS-based tenant scoping) end re-litigation whenever an agent "suggests"
  reversing them; ADR reversal requires a new ADR.

## Timeline of the system itself

- **2026-03-31** — brain generated (ADR-007 records the choice: "single large
  CLAUDE.md rejected — grows unbounded, no layered compression").
- **April** — production-readiness push: brain absorbed security fixes as
  drift corrections; false alarms recorded as explicitly *stale* findings so
  agents stopped re-reporting them.
- **June** — ADR-018: AI-driven 5-stage TDD verify gate with a real-Postgres
  integration harness; terminology layer (French UI over English domain code)
  captured as a MEMORY trap.
- **July** — 1-month stability roadmap as single source of truth; test gate
  reached 95 suites / 1,534 tests; the coverage/mock/flake rules in
  [04-test-strategy.md](04-test-strategy.md) were all earned this month.

## Lessons that shaped the kit

1. **The correction layer does the heavy lifting.** CONTEXT/ARCH/DOMAIN
   changed slowly; MEMORY and CHANGELOG absorbed 98 sessions of change cheaply.
   Systems with only a static context file rot in weeks.
2. **Budgets fail silently without a meter.** The C-grade above went unnoticed
   until measured — hence `brain-metrics.sh` is part of the kit, not an
   afterthought.
3. **Gotchas need teeth.** A MEMORY bullet paired with a regression test held;
   bullets alone eventually got violated by an agent that never loaded that
   file for that task type.
4. **Facts beat prose.** The most-respected brain lines are the tersest:
   `CURRENCY: FCFA integer only, never float` has survived every session;
   paragraph-form guidance got paraphrased away.
5. **The human stays architect at the plan gate.** Nearly every prevented
   architecture mistake was caught at "Wait for GO" — reviewing a 10-bullet
   plan, not a 40-file diff.
