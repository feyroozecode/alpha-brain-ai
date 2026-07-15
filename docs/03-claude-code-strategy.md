# 03 — Claude Code strategy: the layer around the brain

The brain stores the knowledge; the AI-tool configuration decides *when it
gets loaded and how the agent behaves*. This is how GMaintain wires Claude
Code around its brain. Everything here has a portable equivalent (see
[06-adoption-playbook.md](06-adoption-playbook.md) for Cursor/Copilot/Codex
mappings).

## The stack, bottom to top

```
ai-brain/                 ← knowledge (this kit)
CLAUDE.md                 ← always-loaded contract: role, routing, rituals
.claude/commands/         ← repeatable workflows (/epct)
.claude/skills/           ← domain playbooks + a router skill
plans/                    ← dated plan docs, one living source-of-truth per effort
auto-memory (per-user)    ← cross-session facts the repo shouldn't hold
```

## CLAUDE.md — the contract, not the encyclopedia

CLAUDE.md is loaded into every session, so every token in it is paid every
session. Keep it a **contract with pointers**, never a knowledge dump. The
knowledge lives in the brain; CLAUDE.md holds four things:

**1. The routing table** — when to read which brain file:

| Trigger | File | Why |
|---|---|---|
| Every session start | CONTEXT.md + MEMORY.md | Brain + gotchas before any code |
| Working on a module | ARCH.md | Purpose, key files, dependencies |
| Business logic | DOMAIN.md | Non-negotiable invariants |
| "Why was this done?" | DECISIONS.md | Never reverse without a new ADR |
| Bug fix | MEMORY.md | Check known gotchas first |
| Recent changes | CHANGELOG.md | Session continuity |

**2. Role framing.** GMaintain's is: *"You are a Senior Pair Programmer. The
user is the System Architect."* Plus behavioral rules: never write code
neither party understands; challenge requests that contradict the
architecture; no black-box one-liners. Role framing changes agent behavior
more per token than almost anything else you can write.

**3. The workflow with a GO gate.** Explore → Plan → **Wait for GO** → Code →
Test → Explain. The explicit "do not implement until the plan is approved
(skip only for trivial fixes or 'just do it')" is what keeps the human the
architect instead of a spectator. This matters most on AI-heavy projects:
review happens at the *plan* stage, where it's cheap.

**4. The mandatory session-end ritual.** Append CHANGELOG entry; add new
gotchas to MEMORY.md; propose an ADR if an architectural decision was made.
Putting the ritual in CLAUDE.md is what makes the brain self-maintaining —
the agent does the write-back, the human just reviews the diff.

Beyond those four: a short "project specifics" block (the 5–10 conventions
agents get wrong most — error shape, ID format, pagination, currency, i18n
language) and a "common pitfalls" list that mirrors the top of MEMORY.md.

## Commands: /epct

One command file (`.claude/commands/epct.md`) encoding the default task
scaffold: **Explore → Plan → Code → Test**. The value of making it a command
rather than prose: it's invocable, so "run this through /epct" is a complete
instruction, and plans it produces land in `plans/` with a date prefix
(`DD-MM-YY-TITLE.md`) instead of scattering.

## Skills: wrappers + a router

GMaintain's pattern for skills that stays maintainable:

- **Vendor base skills, wrap them locally.** Generic Anthropic skills
  (frontend design, webapp testing, MCP building, skill creation) are vendored
  under `anthropic-*`, and thin project wrappers (`gmaintain-frontend-design`,
  `gmaintain-webapp-testing`, …) inject project constraints — French UI,
  tenant safety, design tokens — on top. Upgrading the base never loses the
  project layer.
- **One router skill** (`gmaintain-skill-router`) is the first stop when a
  task spans areas: it brainstorms which lane (frontend / testing /
  integration / skill-authoring) the task belongs to before any code is
  touched.
- **One context skill** (`gmaintain-context`) holds the deep reference
  material — module map, API patterns, a known-bugs registry — loaded only
  when its trigger words fire, not every session. That's the tiering: brain
  (always) → CLAUDE.md (always, small) → skills (on-demand, deep).

## Plans discipline

Plan/analysis markdown goes in `plans/` with a date prefix. Two hard rules
learned the expensive way:

1. **One living source-of-truth per effort.** CONTEXT.md's `SOURCE-OF-TRUTH:`
   points at it; MEMORY.md carries the rule *"NEVER create new dated
   stability docs; update these two in place."* Without this, agents generate
   a fresh roadmap every session and nobody knows which is real.
2. **Plans are superseded explicitly**, with a MEMORY note saying which doc
   replaced which — otherwise stale plans get executed.

## Auto-memory vs repo brain

Claude Code's per-user auto-memory and the repo brain hold different things:

| | Repo brain (`ai-brain/`) | Auto-memory (per-user) |
|---|---|---|
| Travels with | the repository (git) | the person/tool |
| Content | project facts, invariants, decisions | user preferences, cross-project habits, meta-facts about the workflow |
| Example | "money is FCFA integer" | "this user strips Co-Authored-By trailers" |

Rule of thumb: if a new teammate (human or agent) cloning the repo needs it,
it belongs in the brain. If it's about *how this user likes to work*, it
belongs in tool memory.

## Guardrails worth copying verbatim

From GMaintain's CLAUDE.md, stack-agnostic:

- One task = one change; no unrelated fixes mixed into feature work.
- Never create new files when editing an existing one achieves the goal.
- Do not add comments/types/error-handling to code you didn't change.
- Never interpolate strings into raw SQL/shell.
- Validate at system boundaries; trust internal framework guarantees.
- Do not skip or bypass existing guards, throttlers, or validation.
