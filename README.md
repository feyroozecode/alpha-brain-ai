# ALPHA AI Brain Kit

**A replicable system for AI-assisted development inspired by Andrej Karpathy second brain with Obsidian that keeps full project context
without re-analyzing the codebase every session.**

Extracted from Web SaaS — a multi-tenant Management System (37 backend modules,
~2M tokens of source, 95 test suites / 1,534 tests) built primarily with AI
agents by a single engineer. On that project the compressed brain replaces
~500K tokens of cold-start codebase scanning with ~3–30K tokens of curated
facts per session (**93–94% context savings**, matching independently observed
session telemetry).

Works with any stack — web, mobile, API, monorepo — and any AI coding tool
(Claude Code, Cursor, Copilot, Codex, Aider).

## The idea in one paragraph

An AI agent doesn't need your codebase at session start — it needs the ~3,000
tokens of *decisions, invariants, gotchas, and recent changes* that the code
alone cannot tell it. So you maintain a small, layered, token-budgeted "brain"
(`ai-brain/`) that the agent loads instead of scanning, and you enforce two
rituals that keep it truthful: a **write-back** at every session end (changelog
entry + new gotchas) and a **re-compression** every sprint (absorb what
stabilized, archive what aged out). Everything else in this kit — the scripts,
the CLAUDE.md contract, the test-gate discipline — exists to make those two
rituals cheap and automatic.

## Quick start (any project)

```bash
# 1. Bootstrap — detects your stack (Node/React/NestJS, Flutter, Python, Go,
#    Rust, Laravel, Rails, Android, iOS, monorepos...) and generates an
#    adapted ai-brain/ + starter CLAUDE.md + .gitignore entries
bash ai-brain-kit/scripts/init-ai-brain.sh /path/to/your/project

# 2. One-time fill — paste ai-brain/FIRST_FILL_PROMPT.md to your AI agent.
#    This is the LAST broad codebase scan the project should ever need.

# 3. Work. At every session end, the agent appends a CHANGELOG entry and
#    records new gotchas in MEMORY.md (the CLAUDE.md starter enforces this).

# 4. Measure and maintain
bash ai-brain/scripts/brain-metrics.sh    # health score + token savings
bash ai-brain/scripts/recompress.sh       # sprint ritual (~every 2 weeks)
```

## What's in the kit

```
ai-brain-kit/
├── README.md                        ← you are here
├── docs/
│   ├── 01-philosophy.md             Why compressed context beats codebase re-analysis
│   ├── 02-brain-architecture.md     The 6-file layered brain: spec, budgets, formats
│   ├── 03-claude-code-strategy.md   CLAUDE.md contract, skills, commands, EPCT, memory
│   ├── 04-test-strategy.md          Test-driven discipline: gates, patterns, hard-won rules
│   ├── 05-session-workflow.md       The daily loop and the two rituals, step by step
│   ├── 06-adoption-playbook.md      Adopting on web / mobile / API / any codebase + any AI tool
│   └── 07-case-study-gmaintain.md   Real numbers and lessons from the source project
└── scripts/
    ├── init-ai-brain.sh             Stack-detecting bootstrap (self-contained, portable)
    └── brain-metrics.sh             Brain health + token-savings calculator (standalone)
```

`init-ai-brain.sh` embeds copies of `compose-session.sh`, `recompress.sh`, and
`brain-metrics.sh`, so the single file is enough to bootstrap a project on any
machine. If you edit the standalone `brain-metrics.sh`, keep the embedded copy
in `init-ai-brain.sh` in sync (the init script prefers a sibling
`brain-metrics.sh` when present, so keeping the two files together also works).

## What the generated brain looks like

```
Signal layer (what IS true)          Correction layer (what CHANGED / went wrong)
──────────────────────────           ─────────────────────────────────────────
CONTEXT.md  ← system brain           CHANGELOG.md ← drift corrector (per session)
ARCH.md     ← module map             MEMORY.md    ← gotchas / attention anchors
DOMAIN.md   ← invariants             DECISIONS.md ← append-only ADR log
                     ↓
             SESSION_PROMPT.md  (composed per session — gitignored)
```

Each file has a hard token budget (CONTEXT < 600, ARCH < 1000, DOMAIN < 800,
MEMORY < 500). Budgets are what force compression — without them every context
file grows into the unbounded blob this system exists to replace.

## Reading order

| You want to… | Read |
|---|---|
| Understand why this works | [docs/01-philosophy.md](docs/01-philosophy.md) |
| Know exactly what goes in each brain file | [docs/02-brain-architecture.md](docs/02-brain-architecture.md) |
| Set up Claude Code (or another tool) around the brain | [docs/03-claude-code-strategy.md](docs/03-claude-code-strategy.md) |
| Keep an AI-built codebase stable with tests | [docs/04-test-strategy.md](docs/04-test-strategy.md) |
| Run the day-to-day loop | [docs/05-session-workflow.md](docs/05-session-workflow.md) |
| Adopt this on a new/existing project | [docs/06-adoption-playbook.md](docs/06-adoption-playbook.md) |
| See proof it works | [docs/07-case-study-gmaintain.md](docs/07-case-study-gmaintain.md) |
