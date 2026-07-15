# 05 — Session workflow: the daily loop and the two rituals

Everything in this system reduces to one loop and two rituals. If you keep
only one page of this kit, keep this one.

## The daily session loop

```
┌─────────────────────────────────────────────────────────────┐
│ 1. LOAD (≤ ~3K tokens, not a codebase scan)                 │
│    CONTEXT.md + MEMORY.md  → hard constraints + gotchas     │
│    ARCH.md (task's module) → where things live              │
│    DOMAIN.md (if business logic) → invariants               │
│    CHANGELOG.md (last entries) → recent trajectory          │
│                                                             │
│ 2. EXPLORE (narrow)                                         │
│    Read ONLY the files the task touches — ARCH.md routed    │
│    you there; no tree-wide sweeps                           │
│                                                             │
│ 3. PLAN → GO                                                │
│    Bullet-point logic flow; check DOMAIN invariants and     │
│    DECISIONS ADRs; list files to change and why.            │
│    Human approves (skip for trivial fixes / "just do it")   │
│                                                             │
│ 4. CODE + TEST                                              │
│    Atomic changes, one concern; tests alongside; gate green │
│                                                             │
│ 5. WRITE-BACK (Ritual #1 — mandatory)                       │
│    Append CHANGELOG entry · new gotchas → MEMORY.md ·       │
│    architectural choice → propose ADR                       │
└─────────────────────────────────────────────────────────────┘
```

With Claude Code, steps 1 and 5 are enforced by CLAUDE.md. With tools that
don't auto-load context, generate the injection explicitly:

```bash
bash ai-brain/scripts/compose-session.sh --module billing --task "add webhook retry"
# → paste ai-brain/SESSION_PROMPT.md as the system/first prompt
```

## Ritual #1 — session-end write-back (every session, ~2 minutes)

Tell the agent (or let CLAUDE.md make it automatic):

> "Append a CHANGELOG entry for today's work to ai-brain/CHANGELOG.md, and
> update MEMORY.md if you discovered any new gotchas."

Quality bar for the entry: WHAT / WHY / LEARNED / NEXT. The LEARNED line is
the valuable one — it's tomorrow's MEMORY bullet. Review the brain diff like
code before committing: the agent writing its own memory is powerful and
occasionally wrong.

**Why it's non-negotiable:** the write-back is the input to everything else.
No changelog → next session starts blind → agent re-explores → you're back to
paying the codebase-scan tax this system eliminates.

## Ritual #2 — sprint re-compression (every ~2 weeks, ~15 minutes)

```bash
bash ai-brain/scripts/recompress.sh
```

The script shows token sizes, archives CHANGELOG past 30 entries, backs up the
brain, and prints the re-compression prompt. You paste that prompt to the AI
with CONTEXT.md + the last 20 CHANGELOG entries + MEMORY.md, and it:

1. Absorbs completed work from CHANGELOG into CONTEXT.md as stable facts
2. Removes resolved constraints; updates PHASE
3. Promotes MEMORY items that became permanent rules into DOMAIN/CONTEXT
4. Deletes MEMORY items that are resolved
5. Keeps everything under budget

Then: replace both files, review, commit
(`git commit -m 'brain: sprint re-compression YYYY-MM-DD'`).

**Measure while you're at it:**

```bash
bash ai-brain/scripts/brain-metrics.sh
```

Health-score readings and their causes:

| Symptom | Meaning | Fix |
|---|---|---|
| File over hard limit | Compression debt | Run Ritual #2 now |
| CHANGELOG stale > 14d | Ritual #1 being skipped | Re-add ritual to CLAUDE.md / habit |
| MEMORY stale > 30d | Gotchas not captured | Ask "what did we learn?" at session end |
| ADR count flat for months | Decisions being lost | Propose ADRs at plan-approval time |

## Per-task-type routing

| Task | Extra step before coding |
|---|---|
| **Bug fix** | MEMORY.md first — it may already be a known gotcha; check the known-bugs registry if you keep one. After the fix: regression test + MEMORY entry |
| **Feature** | DOMAIN.md invariants + DECISIONS.md (has this been decided before?) + the SOURCE-OF-TRUTH plan doc |
| **Refactor** | DECISIONS.md — the current shape may be an explicit choice; reversing needs a new ADR, and human GO is mandatory |
| **Schema/data change** | DOMAIN.md data-integrity rules; update ARCH.md data notes in the same session |
| **New module** | Add its section to ARCH.md in the same session it's created |

## Failure modes and recoveries

- **Brain contradicts code** → the code is reality; fix the brain immediately
  and note the drift in CHANGELOG. A brain that's wrong is worse than none:
  the agent trusts it over what it reads.
- **Rituals skipped for weeks** → don't backfill session-by-session. Run one
  catch-up: diff `git log` since the last CHANGELOG entry, write a single
  consolidated entry, then re-compress.
- **Brain over budget everywhere** → you're documenting instead of
  compressing. Move narrative to docs/wiki; the brain keeps only what changes
  agent behavior.
- **Agent ignores a rule that's in the brain** → the rule is probably prose.
  Rewrite it as a `KEY: value` line or a state-machine row, and put it in the
  file the routing table actually loads for that task type.
