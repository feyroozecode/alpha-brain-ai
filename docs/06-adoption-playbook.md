# 06 — Adoption playbook: any codebase, any AI tool

## The seven steps

**1. Bootstrap.**
```bash
bash ai-brain-kit/scripts/init-ai-brain.sh /path/to/project        # interactive
bash ai-brain-kit/scripts/init-ai-brain.sh /path/to/project --yes  # detected defaults
```
Detects the stack (root + `backend/ frontend/ server/ client/ api/ app/ web/
mobile/ admin/ worker/` + `apps/* packages/* services/*` for monorepos), test
frameworks, database, and CI; generates the six brain files pre-filled with
what it found, the three scripts, `.gitignore` entries, and a starter
CLAUDE.md (or `ai-brain/CLAUDE-SNIPPET.md` to merge if you already have one).

**2. One-time fill.** Open your AI agent in the repo and paste
`ai-brain/FIRST_FILL_PROMPT.md`. The agent does a *structural* scan (tree +
manifests + schema + routers — not every file) and fills ARCH.md, the
CONTEXT.md TODOs, and DOMAIN.md within their budgets. This is the last broad
scan the project should ever need.

**3. Review the fill.** Fix wrong facts now — the agent will trust this file
over the code later. Especially verify: the request-flow diagram, invariants
it inferred, anything it marked `<!-- VERIFY -->`.

**4. Seed what only humans know.** Add to DOMAIN.md the business rules that
aren't in code yet (pricing rules, legal constraints, "refunds require
approval"). Add your first real ADRs for the big standing choices (why this
framework, why this tenancy model). 15 minutes, huge payoff.

**5. Wire the gate.** One command that must always be green (typecheck +
tests + build). Put it in CLAUDE.md and CI. Record the current suite/test
count in MEMORY.md.

**6. Run one session end-to-end** including the write-back ritual, and commit
the brain.

**7. Calendar the sprint ritual.** Every ~2 weeks: `recompress.sh` +
`brain-metrics.sh`. The health score is your early warning.

## Per-stack notes

**Web backend (NestJS/Express/Django/Rails/Laravel/Go/...)**
The reference case. ARCH.md's request flow = middleware → guards/policies →
controller → service → ORM → DB. DOMAIN.md carries state machines, money
rules, tenancy fences. Test gate = unit (mocked data layer) + integration on
a real test DB for isolation/transactions.

**Web frontend (React/Vue/Svelte/...)**
CONTEXT constraints: state library, form/validation stack, i18n language
policy, bundle budget (e.g. "main shell ≤ 200 KB gzip — investigate before
merging past it"), routing/lazy-loading rules ("all routes lazy — never
static-import a page"). MEMORY earns its keep on frontend gotchas: build
commands that don't type-check, ambient type declarations, mock-`t` i18n
traps in tests.

**Mobile (Flutter / React Native / native)**
Same six files. ARCH.md maps feature folders and navigation flow instead of
HTTP; DOMAIN.md adds offline/sync rules ("counter uploads are
last-write-wins", "queue mutations when offline"), platform-permission
policies, and store-release constraints. CONTEXT: min OS versions, state
management choice, API client. State machines matter *more* on mobile
(screens are state machines).

**API/library/CLI (no UI)**
CONTEXT gains: public-surface stability policy (semver, breaking-change
rules), supported-versions matrix. DOMAIN: input/output contracts and
compatibility invariants. DECISIONS carries the API-design choices.

**Monorepo**
One brain at the root; ARCH.md sections per package plus a "cross-package
rules" block (who may import whom). Only split into per-package brains when
packages have genuinely separate teams/agents — two half-maintained brains
are worse than one good one.

**Existing large codebase**
Don't fill everything. Brain the modules you actively touch (ARCH sections
for those, `## Legacy` one-liner for the rest), and let coverage grow
on-demand: each time work enters an unmapped module, the session's write-back
adds its ARCH section. The brain earns trust incrementally.

## Per-tool wiring

| Tool | Always-loaded contract | Session injection | Write-back |
|---|---|---|---|
| **Claude Code** | CLAUDE.md (generated starter) | automatic via routing table | agent does it (CLAUDE.md ritual) |
| **Cursor** | `.cursorrules` / `.cursor/rules/*.mdc` — paste the CLAUDE.md content, add `alwaysApply` for the routing table | rules can `@`-reference brain files | ask at session end, or add to rules |
| **Copilot** | `.github/copilot-instructions.md` | limited — keep CONTEXT+MEMORY inline there (they fit: <1K tokens) | manual |
| **Codex / plain chat / any LLM** | none | `compose-session.sh` → paste SESSION_PROMPT.md | paste the ritual sentence at session end |
| **Aider** | `CONVENTIONS.md` (point it at the brain) | `/read ai-brain/CONTEXT.md ai-brain/MEMORY.md` | manual |

The brain itself is tool-agnostic markdown — switching tools costs you one
wiring file, never the knowledge.

## Anti-patterns

- **Filling the brain by hand for a week before using it.** Bootstrap + fill +
  go, same day. The brain improves through rituals, not upfront authorship.
- **Copying GMaintain's facts.** The *structure* replicates; `CURRENCY: FCFA
  integer` does not. Every line must be true of *your* project.
- **Treating budgets as aspirational.** Over-budget files are the system
  failing. Recompress.
- **A brain nobody commits.** It's source code for your agents — review the
  diffs, commit it, let it travel with the repo.
- **Skipping the GO gate because the agent seems right.** Plan review is
  where a human catches invariant violations for cents instead of hours.
- **Putting secrets or credentials in the brain.** It's committed plaintext.
  Constraints yes ("payments live mode requires webhook secret"), values never.
