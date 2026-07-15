# 01 — Philosophy: compressed context beats codebase re-analysis

## The problem

Every AI coding session starts cold. Without a context system, the agent has
three bad options:

1. **Re-scan the codebase** — hundreds of thousands of tokens burned before the
   first line of useful work, every single session. On GMaintain (~2M source
   tokens) even a partial exploratory scan costs ~500K tokens.
2. **Guess from filenames and training priors** — produces generic code that
   violates project conventions (wrong error shape, wrong ID format, float
   money, cross-tenant queries).
3. **Rely on one giant CLAUDE.md** — grows unbounded, mixes stable facts with
   stale ones, and nobody can tell which line is still true. Context files
   without budgets become the very blob they were meant to replace.

Worse than token cost is **drift**: the agent repeats mistakes that were
already solved (last month's coverage-config trap, the mock-scope bug, the
dual-named field), because nothing carried that knowledge across sessions.

## The insight

The code itself is the *least* useful thing to give an agent at session start.
Code answers "what exists"; the agent can read the two or three files it
actually needs on demand. What the agent cannot recover from code is:

- **Decisions** — why there's no repository pattern, why roles are tenant-scoped
- **Invariants** — money is integer-only, tenant ID never comes from the request body
- **Gotchas** — `vite build` never type-checks; assert on exception *type*, not message
- **Recent trajectory** — what changed in the last 7 sessions and what's next

That knowledge is small — a few thousand tokens — and it's exactly what makes
the difference between an agent that fits the project and one that fights it.

## The model: signal + error correction

The brain borrows its shape from quantization systems (the original project
called it "TurboQuant", after Google Research's extreme-compression work):
a compressed **signal layer** that captures the stable truth, plus a
**correction layer** that captures how reality drifts from that compression.

| Layer | Files | Nature | Update rhythm |
|---|---|---|---|
| Signal | CONTEXT.md, ARCH.md, DOMAIN.md | Stable facts, invariants | Sprint (re-compression) |
| Correction | CHANGELOG.md, MEMORY.md, DECISIONS.md | Deltas, gotchas, decisions | Every session (write-back) |

The correction layer absorbs change cheaply (append a bullet), and the sprint
re-compression periodically folds stabilized corrections back into the signal
layer — the same way a codec re-keys frames. That is what keeps the signal
layer small AND true.

## Five principles

**1. Token budgets are hard limits, not suggestions.**
CONTEXT < 600, ARCH < 1000, DOMAIN < 800, MEMORY < 500 tokens. Budgets force
the discipline of deciding what still matters. A brain file over budget is a
bug with a defined fix: re-compress.

**2. Facts, not prose.**
`CURRENCY: FCFA integer only, never float` beats a paragraph about monetary
handling. Agents follow structured `KEY: value` constraints far more reliably
than narrative, and structure compresses better.

**3. Write-back is mandatory, or the brain dies.**
Every session ends by appending a CHANGELOG entry and capturing new gotchas in
MEMORY.md. Skip this for two weeks and the brain silently rots — the metrics
script flags stale files precisely because this is the most common failure mode.

**4. Decisions are append-only.**
An ADR is never edited or deleted; reversing one requires a *new* ADR that
explains the reversal. This is what stops an agent (or you, six months later)
from "helpfully" re-introducing the repository pattern that was explicitly
rejected.

**5. One broad scan, ever.**
The only time an agent should sweep the codebase is the one-time brain fill at
adoption. After that, the brain routes it: CONTEXT says what's true, ARCH says
where things live, and the agent reads only the files the task touches.

## What this is not

- **Not documentation.** Docs explain the system to humans at leisure; the
  brain is an operational context injection optimized for token cost and
  constraint-following. (GMaintain keeps both — plus a wiki — they serve
  different readers.)
- **Not a replacement for reading code.** The agent still opens the files it
  edits. The brain replaces the *exploration* phase, not the *work* phase.
- **Not tool-specific.** CLAUDE.md, `.cursorrules`, a pasted SESSION_PROMPT.md —
  they're all just delivery mechanisms for the same brain.
