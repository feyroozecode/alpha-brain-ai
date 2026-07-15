# 02 — Brain architecture: the six files

Complete specification of the `ai-brain/` folder. `init-ai-brain.sh` generates
all of this pre-adapted to the detected stack; this document is the reference
for maintaining it.

## Layout

```
ai-brain/
├── CONTEXT.md            signal   — identity, stack, hard constraints, session rules
├── ARCH.md               signal   — pattern, request/data flow, module map
├── DOMAIN.md             signal   — business invariants, state machines
├── MEMORY.md             correction — live gotchas, traps, open gaps
├── DECISIONS.md          correction — append-only ADR log
├── CHANGELOG.md          correction — one entry per session, newest last
├── README.md             the workflow manual for humans
├── FIRST_FILL_PROMPT.md  one-time fill prompt (delete after use)
├── SESSION_PROMPT.md     composed per session — GITIGNORED, never hand-edited
├── CHANGELOG.archive.md  created by recompress.sh when entries exceed 30
├── .backups/             tar snapshots from recompress.sh — GITIGNORED
└── scripts/
    ├── compose-session.sh   builds SESSION_PROMPT.md for one session
    ├── recompress.sh        sprint ritual: sizes, archive, backup, AI prompt
    └── brain-metrics.sh     health score + token-savings calculator
```

Everything is committed except `SESSION_PROMPT.md` and `.backups/`.

## Token budgets

| File | Target | Hard limit | Over the limit? |
|---|---|---|---|
| CONTEXT.md | < 400 | 600 | Re-compress: absorb CHANGELOG facts, drop resolved constraints |
| ARCH.md | < 600 | 1000 | Collapse module sections; details belong in code |
| DOMAIN.md | < 500 | 800 | Move narrative to docs; keep only rules + state machines |
| MEMORY.md | < 300 | 500 | Promote permanent rules to DOMAIN/CONTEXT; delete resolved gotchas |
| DECISIONS.md | — | — | Append-only by design; never trimmed |
| CHANGELOG.md | — (30 entries) | — | recompress.sh archives past 30 entries |
| SESSION_PROMPT.md | < 2000 | 3000 | compose-session.sh warns; recompress the sources |

`brain-metrics.sh` scores these automatically (−10 health per file over hard
limit, −5 over target).

## File-by-file specification

### CONTEXT.md — the system brain

Read at the **start of every session**. Every line is a hard constraint.

Sections: `Identity` (PROJECT / DESCRIPTION / USERS / PHASE / TEAM / AI-TOOL),
`Stack`, `Critical constraints`, `Architecture` (PATTERN + SOURCE-OF-TRUTH
pointer to the current roadmap doc), `Session rules`.

Format rule: **`KEY: value` lines only, no prose.** Real examples from GMaintain:

```
CURRENCY: FCFA integer only, never float
TENANCY: single DB multi-tenant; middleware/CLS resolve tenant before scoped queries
PAGINATION: { data, meta: { total, page, limit, totalPages } }
SOFT-DELETE: not a general rule; most entities use hard delete
```

The `SOURCE-OF-TRUTH:` line matters more than it looks: it points the agent at
the one living plan document, which prevents the classic failure of agents
creating a new dated plan file every session. Pair it with an explicit rule in
MEMORY.md ("NEVER create new dated stability docs; update these two in place").

### ARCH.md — the module map

Read **when working on a module**. Contains: the architecture pattern (one
line), the request/data flow diagram (the single most valuable block — every
session needs it), one short section per module/area (purpose, key files,
dependencies), and data notes (ID format, uniqueness rules).

`compose-session.sh --module X` extracts the matching `## X` section, so name
sections after the module names you'd type there.

### DOMAIN.md — the invariants

Read **before writing business logic**. Header contract: *"these rules are
NEVER negotiable. If code would violate any rule below, stop and ask."*

Sections: business rules (numbered), data integrity rules, security rules,
tenancy rules (if multi-tenant), localization rules, **lifecycle state
machines**. State machines use a strict parseable format:

```
### Order lifecycle
DRAFT -> SUBMITTED (requires: at least 1 item)
SUBMITTED -> PAID (requires: successful payment)
Any state -> CANCELLED (requires: reason + authorized role)
Forbidden: PAID -> DRAFT
```

This format is the highest-leverage content in the whole brain: agents
respect explicit transition tables far better than descriptions, and state
machine violations are the most expensive class of business-logic bug.

### MEMORY.md — the attention anchor

Read **before writing any code**, especially bug fixes. One dated bullet per
hard-won lesson, always with the *fix or rule*, not just the observation:

```
- **Spec drift rule (2026-07-11)**: after the FR error-string pass, always
  assert on exception TYPE (NotFoundException), NEVER on the message string.
```

Lifecycle: gotchas are born here → if they become permanent rules they get
*promoted* to DOMAIN/CONTEXT at re-compression → if resolved they get deleted.
MEMORY is the only brain file where deletion is routine.

### DECISIONS.md — the ADR log

Read **when wondering why something is done a certain way**. Append-only.
Fixed template:

```
## ADR-NNN: [short decision title]
WHY:          (the reasoning)
ALTERNATIVES: (what was considered and rejected)
TRADEOFFS:    (what you give up)
DATE:         YYYY-MM-DD
STATUS:       accepted | superseded-by-ADR-NNN | deprecated
```

The `ALTERNATIVES` line is what prevents re-litigating: when an agent proposes
the repository pattern, ADR-005's "rejected — too much boilerplate for solo
developer" ends the discussion. Reversal requires a new ADR, never an edit.

### CHANGELOG.md — the drift corrector

Appended **at every session end**, newest at the bottom. Entry template:

```
## [YYYY-MM-DD] <short title>
- WHAT: files/modules touched and what changed
- WHY: the intent
- LEARNED: gotchas discovered (also added to MEMORY.md)
- NEXT: known follow-ups
```

`compose-session.sh` injects the last 7 entries into each session prompt —
that's how a fresh agent knows the project's recent trajectory. Past 30
entries, `recompress.sh` moves the oldest to `CHANGELOG.archive.md`.

## The scripts

**compose-session.sh** — assembles SESSION_PROMPT.md from: CONTEXT (full) +
ARCH (head + the `--module` section) + DOMAIN (full) + last 7 CHANGELOG entries
+ MEMORY (full) + the task statement + a fixed definition-of-done checklist.
Use it when your AI tool doesn't auto-load context files (plain chat, Codex,
a fresh tool); with Claude Code the CLAUDE.md routing table plays this role.

**recompress.sh** — the sprint ritual: prints token sizes, archives CHANGELOG
past 30 entries, tars a backup into `.backups/`, and prints the re-compression
prompt you paste to the AI (absorb CHANGELOG facts into CONTEXT, promote/purge
MEMORY, stay under budget).

**brain-metrics.sh** — measures the system: per-file tokens vs budget, brain
vs codebase size, estimated tokens saved per session/month, ritual freshness
(days since CHANGELOG/MEMORY updates), ADR count, and a 0–100 health score
with specific fix suggestions. `--json` for CI/dashboards. Run it weekly; a
falling score means the rituals are being skipped.

## Information flow between files

```
   session work
        │ write-back (every session)
        ▼
  CHANGELOG.md ──── absorb stable facts ────► CONTEXT.md / ARCH.md
  MEMORY.md    ──── promote permanent rules ─► DOMAIN.md / CONTEXT.md
        │                    (sprint re-compression)
        └─ resolved gotchas → deleted
  DECISIONS.md ← new ADR whenever an architectural choice is made (append-only)
```
