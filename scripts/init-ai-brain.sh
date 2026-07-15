#!/usr/bin/env bash
# ============================================================
#  AI Brain Kit · init-ai-brain.sh
#  Bootstraps a compressed AI context system ("ai-brain/") into
#  ANY project — web, mobile, API, monorepo — adapted to the
#  stack it detects in the target directory.
#
#  What it creates:
#    ai-brain/
#      CONTEXT.md      signal layer — identity, stack, hard constraints
#      ARCH.md         module map + request/data flow
#      DOMAIN.md       business invariants + state machines
#      MEMORY.md       gotchas / attention anchors
#      DECISIONS.md    append-only ADR log
#      CHANGELOG.md    session drift-corrector
#      README.md       the workflow manual
#      FIRST_FILL_PROMPT.md   one-time prompt for your AI agent
#      scripts/
#        compose-session.sh   builds SESSION_PROMPT.md per session
#        recompress.sh        sprint re-compression ritual
#        brain-metrics.sh     token-savings + health calculator
#    CLAUDE.md         starter (only if the project has none)
#    .gitignore        entries for SESSION_PROMPT.md / .backups/
#
#  Usage:
#    bash init-ai-brain.sh [target_dir]           # interactive
#    bash init-ai-brain.sh [target_dir] --yes     # accept detected defaults
#    bash init-ai-brain.sh . --name my-app --yes
#    bash init-ai-brain.sh . --force              # overwrite existing ai-brain
#    bash init-ai-brain.sh . --no-claude-md
#
#  Compatible with macOS bash 3.2 and Linux bash.
# ============================================================

set -euo pipefail

# ---------- colors ----------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; CYAN=$'\033[36m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; RESET=""
fi

# ---------- args ----------
TARGET_DIR="."
ASSUME_YES=no
FORCE=no
WRITE_CLAUDE_MD=yes
NAME_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)       ASSUME_YES=yes; shift ;;
    --force)        FORCE=yes; shift ;;
    --no-claude-md) WRITE_CLAUDE_MD=no; shift ;;
    --name)         NAME_OVERRIDE="$2"; shift 2 ;;
    -h|--help)      grep '^#' "$0" | sed 's/^# \{0,2\}//' | head -34; exit 0 ;;
    -*)             echo "unknown flag: $1" >&2; exit 1 ;;
    *)              TARGET_DIR="$1"; shift ;;
  esac
done

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
BRAIN_DIR="${TARGET_DIR}/ai-brain"
TODAY="$(date +%Y-%m-%d)"

if [[ -d "$BRAIN_DIR" && "$FORCE" != "yes" ]]; then
  echo "${RED}✗ ${BRAIN_DIR} already exists. Use --force to overwrite.${RESET}" >&2
  exit 1
fi

echo ""
echo "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo "${BOLD}${CYAN}║   init-ai-brain — compressed AI context for any project   ║${RESET}"
echo "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "  ${DIM}target: ${TARGET_DIR}${RESET}"
echo ""

# ============================================================
#  STACK DETECTION
# ============================================================
STACK_LINES=""
TEST_LINES=""
DB_LINES=""

add_stack() { STACK_LINES="${STACK_LINES}$1
"; }
add_test()  { TEST_LINES="${TEST_LINES}$1
"; }
add_db()    { DB_LINES="${DB_LINES}$1
"; }

has_dep() {  # has_dep <package.json> <dep-name>
  grep -q "\"$2\"" "$1" 2>/dev/null
}

detect_node_dir() {  # detect_node_dir <dir> <label>
  local d="$1" label="$2" pkg="$1/package.json" fw="" extras="" tests=""
  [[ -f "$pkg" ]] || return 0

  has_dep "$pkg" "@nestjs/core"   && fw="NestJS (Node/TypeScript)"
  has_dep "$pkg" "next"           && fw="${fw:-Next.js (React)}"
  has_dep "$pkg" "nuxt"           && fw="${fw:-Nuxt (Vue)}"
  has_dep "$pkg" "@angular/core"  && fw="${fw:-Angular}"
  has_dep "$pkg" "svelte"         && fw="${fw:-Svelte/SvelteKit}"
  has_dep "$pkg" "expo"           && fw="${fw:-Expo (React Native)}"
  if [[ -z "$fw" ]] && has_dep "$pkg" "react-native"; then fw="React Native"; fi
  if [[ -z "$fw" ]] && has_dep "$pkg" "react"; then fw="React"; fi
  if [[ -z "$fw" ]] && has_dep "$pkg" "vue"; then fw="Vue"; fi
  has_dep "$pkg" "express"        && fw="${fw:-Express (Node)}"
  has_dep "$pkg" "fastify"        && fw="${fw:-Fastify (Node)}"
  has_dep "$pkg" "hono"           && fw="${fw:-Hono (Node/edge)}"
  [[ -z "$fw" ]] && fw="Node.js"

  has_dep "$pkg" "vite"        && extras="${extras}, Vite"
  has_dep "$pkg" "tailwindcss" && extras="${extras}, Tailwind"
  has_dep "$pkg" "typescript"  && extras="${extras}, TypeScript"
  has_dep "$pkg" "prisma"      && { extras="${extras}, Prisma"; detect_prisma_db "$d"; }
  has_dep "$pkg" "typeorm"     && extras="${extras}, TypeORM"
  has_dep "$pkg" "drizzle-orm" && extras="${extras}, Drizzle"
  has_dep "$pkg" "mongoose"    && { extras="${extras}, Mongoose"; add_db "DB: MongoDB (mongoose) — ${label}"; }
  has_dep "$pkg" "zustand"     && extras="${extras}, Zustand"
  has_dep "$pkg" "zod"         && extras="${extras}, Zod"

  has_dep "$pkg" "jest"        && tests="Jest"
  has_dep "$pkg" "vitest"      && tests="${tests:+${tests}, }Vitest"
  has_dep "$pkg" "mocha"       && tests="${tests:+${tests}, }Mocha"
  has_dep "$pkg" "playwright"  && tests="${tests:+${tests}, }Playwright"
  has_dep "$pkg" "@playwright/test" && { case "$tests" in *Playwright*) ;; *) tests="${tests:+${tests}, }Playwright" ;; esac; }
  has_dep "$pkg" "cypress"     && tests="${tests:+${tests}, }Cypress"

  add_stack "${label}: ${fw}${extras}"
  [[ -n "$tests" ]] && add_test "${label}: ${tests}"
  return 0
}

detect_prisma_db() {  # parse provider from prisma schema
  local d="$1" schema=""
  for schema in "$d/prisma/schema.prisma" "$d/schema.prisma"; do
    if [[ -f "$schema" ]]; then
      local prov
      prov=$(grep -E '^\s*provider\s*=' "$schema" | grep -v 'prisma-client' | head -1 | sed 's/.*=\s*"\{0,1\}\([a-z]*\)"\{0,1\}.*/\1/' || true)
      [[ -n "$prov" ]] && add_db "DB: ${prov} (Prisma) — schema at ${schema#$TARGET_DIR/}"
      return 0
    fi
  done
  return 0
}

detect_dir() {  # detect_dir <dir> <label>
  local d="$1" label="$2"
  [[ -d "$d" ]] || return 0

  detect_node_dir "$d" "$label"

  if [[ -f "$d/pubspec.yaml" ]]; then
    if grep -q "flutter:" "$d/pubspec.yaml" 2>/dev/null; then
      add_stack "${label}: Flutter (Dart)"
      add_test "${label}: flutter_test (built-in)"
    else
      add_stack "${label}: Dart"
    fi
  fi
  if [[ -f "$d/pyproject.toml" || -f "$d/requirements.txt" ]]; then
    local pyfw="Python"
    grep -qs "django"  "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null && pyfw="Python (Django)"
    grep -qs "fastapi" "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null && pyfw="Python (FastAPI)"
    grep -qs "flask"   "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null && pyfw="Python (Flask)"
    add_stack "${label}: ${pyfw}"
    grep -qs "pytest" "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null && add_test "${label}: pytest"
  fi
  [[ -f "$d/go.mod" ]]        && { add_stack "${label}: Go"; add_test "${label}: go test (built-in)"; }
  [[ -f "$d/Cargo.toml" ]]    && { add_stack "${label}: Rust"; add_test "${label}: cargo test (built-in)"; }
  if [[ -f "$d/composer.json" ]]; then
    if has_dep "$d/composer.json" "laravel/framework"; then
      add_stack "${label}: PHP (Laravel)"; add_test "${label}: PHPUnit/Pest"
    else
      add_stack "${label}: PHP"
    fi
  fi
  if [[ -f "$d/Gemfile" ]]; then
    if grep -q "rails" "$d/Gemfile" 2>/dev/null; then
      add_stack "${label}: Ruby on Rails"; add_test "${label}: RSpec/Minitest"
    else
      add_stack "${label}: Ruby"
    fi
  fi
  if [[ -f "$d/build.gradle" || -f "$d/build.gradle.kts" || -f "$d/pom.xml" ]]; then
    if grep -qs "com.android" "$d/build.gradle" "$d/build.gradle.kts" 2>/dev/null; then
      add_stack "${label}: Android (Kotlin/Java)"
    else
      add_stack "${label}: JVM (Java/Kotlin)"
    fi
    add_test "${label}: JUnit"
  fi
  if ls "$d"/*.xcodeproj >/dev/null 2>&1 || [[ -f "$d/Package.swift" ]]; then
    add_stack "${label}: iOS/Swift"
    add_test "${label}: XCTest"
  fi
  [[ -f "$d/mix.exs" ]] && { add_stack "${label}: Elixir (Phoenix?)"; add_test "${label}: ExUnit"; }
  return 0
}

echo "${BOLD}${BLUE}── Detecting stack ──${RESET}"

detect_dir "$TARGET_DIR" "root"
for sub in backend frontend server client api app web mobile admin worker; do
  detect_dir "${TARGET_DIR}/${sub}" "${sub}/"
done
for parent in apps packages services; do
  if [[ -d "${TARGET_DIR}/${parent}" ]]; then
    for sub in "${TARGET_DIR}/${parent}"/*/; do
      [[ -d "$sub" ]] || continue
      detect_dir "${sub%/}" "${parent}/$(basename "$sub")/"
    done
  fi
done

# docker-compose DB detection
for dc in "$TARGET_DIR/docker-compose.yml" "$TARGET_DIR/docker-compose.yaml" "$TARGET_DIR/compose.yml" "$TARGET_DIR/compose.yaml"; do
  if [[ -f "$dc" ]]; then
    grep -q "postgres" "$dc" 2>/dev/null && add_db "DB: PostgreSQL (docker-compose)"
    grep -q "mysql"    "$dc" 2>/dev/null && add_db "DB: MySQL (docker-compose)"
    grep -q "mongo"    "$dc" 2>/dev/null && add_db "DB: MongoDB (docker-compose)"
    grep -q "redis"    "$dc" 2>/dev/null && add_db "CACHE: Redis (docker-compose)"
    break
  fi
done

# CI detection
CI_DETECTED="none detected"
[[ -d "$TARGET_DIR/.github/workflows" ]]      && CI_DETECTED="GitHub Actions"
[[ -f "$TARGET_DIR/.gitlab-ci.yml" ]]         && CI_DETECTED="GitLab CI"
[[ -f "$TARGET_DIR/bitbucket-pipelines.yml" ]] && CI_DETECTED="Bitbucket Pipelines"
[[ -f "$TARGET_DIR/Jenkinsfile" ]]            && CI_DETECTED="Jenkins"
[[ -d "$TARGET_DIR/.circleci" ]]              && CI_DETECTED="CircleCI"

# project name
PROJECT_NAME="$(basename "$TARGET_DIR")"
if [[ -f "$TARGET_DIR/package.json" ]]; then
  n=$(grep -m1 '"name"' "$TARGET_DIR/package.json" | sed 's/.*"name"[^"]*"\([^"]*\)".*/\1/' || true)
  [[ -n "$n" ]] && PROJECT_NAME="$n"
fi
if [[ -f "$TARGET_DIR/pubspec.yaml" ]]; then
  n=$(grep -m1 '^name:' "$TARGET_DIR/pubspec.yaml" | sed 's/name:[[:space:]]*//' || true)
  [[ -n "$n" ]] && PROJECT_NAME="$n"
fi
[[ -n "$NAME_OVERRIDE" ]] && PROJECT_NAME="$NAME_OVERRIDE"

[[ -z "$STACK_LINES" ]] && STACK_LINES="root: (stack not auto-detected — fill in manually)
"

echo "${DIM}$(printf '%s' "$STACK_LINES" | sed 's/^/  /')${RESET}"
[[ -n "$DB_LINES" ]] && echo "${DIM}$(printf '%s' "$DB_LINES" | sed 's/^/  /')${RESET}"
echo "${DIM}  CI: ${CI_DETECTED}${RESET}"
echo ""

# ============================================================
#  INTERVIEW
# ============================================================
ask() {  # ask "question" "default" -> ANSWER
  local q="$1" default="${2:-}" ans=""
  if [[ "$ASSUME_YES" == "yes" ]]; then
    echo "$default"
    return
  fi
  if [[ -n "$default" ]]; then
    printf "%s? %s%s %s[%s]%s " "$BOLD" "$q" "$RESET" "$DIM" "$default" "$RESET" >&2
  else
    printf "%s? %s%s " "$BOLD" "$q" "$RESET" >&2
  fi
  read -r ans || true
  echo "${ans:-$default}"
}

echo "${BOLD}${BLUE}── Project interview ──${RESET} ${DIM}(Enter accepts default; --yes skips)${RESET}"
PROJECT_NAME=$(ask "Project name" "$PROJECT_NAME")
PROJECT_DESC=$(ask "One-line description" "TODO: describe what this product does")
PROJECT_USERS=$(ask "Primary users" "TODO: who uses this")
PROJECT_PHASE=$(ask "Phase (MVP / early users / scaling / mature)" "MVP")
TEAM_SIZE=$(ask "Team size" "1 engineer")
AI_TOOL=$(ask "Primary AI tool" "Claude Code")
IS_MULTITENANT=$(ask "Multi-tenant SaaS? (yes/no)" "no")

echo ""
echo "${BOLD}${BLUE}── Writing ai-brain/ ──${RESET}"
mkdir -p "$BRAIN_DIR/scripts"

# ============================================================
#  CONTEXT.md
# ============================================================
TENANCY_CONTEXT=""
if [[ "$IS_MULTITENANT" == "yes" ]]; then
  TENANCY_CONTEXT="TENANCY: multi-tenant — every data query MUST be scoped to the authenticated tenant; tenant ID never comes from request body"
fi

{
cat <<EOF
<!-- AI Brain · signal layer -->
<!-- AI: read this file at the START of every session. Treat every line as a hard constraint. -->
<!-- Token budget: keep under 600 tokens. Re-compress after each sprint. -->

# CONTEXT — ${PROJECT_NAME}

## Identity
PROJECT: ${PROJECT_NAME}
DESCRIPTION: ${PROJECT_DESC}
USERS: ${PROJECT_USERS}
PHASE: ${PROJECT_PHASE}
TEAM: ${TEAM_SIZE}
AI-TOOL: ${AI_TOOL}

## Stack
$(printf '%s%sCI: %s' "$STACK_LINES" "$DB_LINES" "$CI_DETECTED")

## Critical constraints
EOF
[[ -n "$TENANCY_CONTEXT" ]] && echo "$TENANCY_CONTEXT"
cat <<'EOF'
<!-- TODO: replace the examples with YOUR real invariants. Keep the KEY: value format — facts, not prose. -->
<!-- CURRENCY: integer minor units only, never float -->
<!-- IDS: UUID / CUID -->
<!-- PAGINATION: { data, meta: { total, page, limit, totalPages } } -->
<!-- ERRORS: { code, message, details } -->
<!-- LANGUAGES: primary UI language, i18n framework -->

## Architecture
PATTERN: <!-- TODO: e.g. layered modular monolith / clean architecture / feature-first -->
SOURCE-OF-TRUTH: <!-- TODO: path to the current plan/roadmap doc, if any -->

## Session rules
- Never introduce a new dependency or architecture pattern without need
- Never hardcode secrets or deployment values
- Re-read MEMORY.md before touching code
- Keep ai-brain aligned with the live repo when facts change
- Append materially relevant changes to CHANGELOG.md at session end

EOF
echo "<!-- Last updated: ${TODAY} -->"
} > "$BRAIN_DIR/CONTEXT.md"
echo "  ${GREEN}✓ CONTEXT.md${RESET}"

# ============================================================
#  ARCH.md
# ============================================================
{
cat <<EOF
<!-- AI Brain · module-map layer -->
<!-- AI: read the relevant section(s) for your current task. -->
<!-- Update this file when module structure or request flow changes materially. -->
<!-- Token budget: keep under 1000 tokens. -->

# ARCH — ${PROJECT_NAME}

## Pattern
<!-- TODO: one line, e.g. "Layered modular monolith in a monorepo: backend/ + frontend/" -->

## Request / data flow
EOF
cat <<'EOF'
```txt
<!-- TODO: the ONE diagram every session needs. Example:
UI -> service layer -> REST API
  -> middleware (auth, tenant)
  -> guards
  -> Controller -> Service -> ORM -> Database
-->
```

## Modules
<!-- TODO: one "## <module>" section per area with: purpose, key files, dependencies.
     TIP: don't write this by hand — run the one-time fill prompt in
     ai-brain/FIRST_FILL_PROMPT.md and let your AI agent generate it. -->

## Data notes
<!-- TODO: ID format, key uniqueness rules, tenancy columns, soft-delete policy -->

EOF
echo "<!-- Last updated: ${TODAY} -->"
} > "$BRAIN_DIR/ARCH.md"
echo "  ${GREEN}✓ ARCH.md${RESET}"

# ============================================================
#  DOMAIN.md
# ============================================================
TENANCY_DOMAIN=""
if [[ "$IS_MULTITENANT" == "yes" ]]; then
  TENANCY_DOMAIN="## Tenancy rules

- Every data query MUST be scoped to the authenticated tenant
- Cross-tenant data access is ALWAYS forbidden — even for admins
- Tenant ID comes from the authenticated context — never from request body or params
- Regression test: tenant A must never read/write tenant B rows
"
fi

{
cat <<EOF
<!-- AI Brain · invariant layer -->
<!-- AI: these rules are NEVER negotiable. If code would violate any rule below, stop and ask. -->
<!-- Update when new business rules are discovered or validated with stakeholders. -->
<!-- Token budget: keep under 800 tokens. -->

# DOMAIN — ${PROJECT_NAME}

## Business rules (core invariants)

<!-- TODO: numbered list of rules that must NEVER be violated. Examples:
1. Every order total is the sum of its line items — never stored independently
2. A published article cannot return to draft without an audit entry
-->

## Data integrity rules

<!-- TODO: e.g. money as integer minor units, ID formats, timestamp conventions,
     empty-string-to-undefined sanitization before ORM calls -->

## Security rules

<!-- TODO: token lifetimes, lockout policy, rate limits, raw-SQL bans,
     upload isolation, guard ordering -->

${TENANCY_DOMAIN}## Lifecycle state machines

<!-- TODO: one block per entity with states. Keep the exact format — AI agents parse it:

### Order lifecycle
DRAFT -> SUBMITTED (requires: at least 1 item)
SUBMITTED -> PAID (requires: successful payment)
Any state -> CANCELLED (requires: reason + authorized role)
Forbidden: PAID -> DRAFT
-->

EOF
echo "<!-- Last updated: ${TODAY} -->"
} > "$BRAIN_DIR/DOMAIN.md"
echo "  ${GREEN}✓ DOMAIN.md${RESET}"

# ============================================================
#  MEMORY.md
# ============================================================
{
cat <<EOF
<!-- AI Brain · attention-anchor layer -->
<!-- AI: read this BEFORE writing any code in a session. -->
<!-- Keep this file under 500 tokens. Promote permanent rules to CONTEXT.md or DOMAIN.md. -->

# MEMORY — ${PROJECT_NAME}

## Live gotchas

<!-- Every hard-won lesson goes here as one bullet, dated, with the fix. Example:
- **Coverage gate trap (2026-07-11)**: unit-only and full-suite coverage measure
  different things — match the threshold to the command that runs it.
-->

- **($(date +%Y-%m-%d))**: ai-brain initialized. First gotcha goes here.

## Known naming or behavior traps

<!-- e.g. dual field names pending migration, legacy cookie names, enum-vs-string filters -->

## Still-open quality gaps

<!-- e.g. modules with weak test coverage, unpolished UX areas -->

EOF
echo "<!-- Last updated: ${TODAY} -->"
} > "$BRAIN_DIR/MEMORY.md"
echo "  ${GREEN}✓ MEMORY.md${RESET}"

# ============================================================
#  DECISIONS.md
# ============================================================
{
cat <<EOF
<!-- AI Brain · Architecture Decision Record log -->
<!-- AI: read this when you wonder why something is done a certain way. -->
<!-- NEVER reverse a decision without adding a new ADR explaining the reversal. -->
<!-- This file only grows — never delete entries. -->

# DECISIONS (ADR) — ${PROJECT_NAME}
EOF
cat <<'EOF'

## How to add a decision
```
## ADR-NNN: [short decision title]
WHY:          (the reasoning — why this was the right call)
ALTERNATIVES: (what else was considered and rejected)
TRADEOFFS:    (what you give up with this choice)
DATE:         YYYY-MM-DD
STATUS:       accepted | superseded-by-ADR-NNN | deprecated
```

---

## ADR-001: Adopt AI Brain compressed-context system
WHY:          AI-assisted development needs compressed, structured context to stay consistent across sessions without re-analyzing the codebase each time.
ALTERNATIVES: Single large CLAUDE.md (rejected — grows unbounded, no layered compression); no context system (rejected — drift and repeated mistakes).
TRADEOFFS:    Extra files to maintain. Requires session-end write-back and sprint re-compression rituals.
EOF
echo "DATE:         ${TODAY}"
echo "STATUS:       accepted"
} > "$BRAIN_DIR/DECISIONS.md"
echo "  ${GREEN}✓ DECISIONS.md${RESET}"

# ============================================================
#  CHANGELOG.md
# ============================================================
{
cat <<EOF
<!-- AI Brain · drift-corrector layer -->
<!-- AI: append ONE entry at session end. Newest entries at the BOTTOM. -->
<!-- Entries are archived past 30 by scripts/recompress.sh — never edit old entries. -->

# CHANGELOG — ${PROJECT_NAME}
EOF
cat <<'EOF'

## Entry template
```
## [YYYY-MM-DD] <short title>
- WHAT: files/modules touched and what changed
- WHY: the intent behind the change
- LEARNED: gotchas discovered (also add to MEMORY.md)
- NEXT: known follow-ups
```

---
EOF
cat <<EOF

## [${TODAY}] ai-brain initialized
- WHAT: ai-brain/ created by init-ai-brain.sh (CONTEXT, ARCH, DOMAIN, MEMORY, DECISIONS, CHANGELOG + scripts)
- WHY: adopt compressed AI context system instead of per-session codebase re-analysis
- NEXT: run FIRST_FILL_PROMPT.md with the AI agent to fill ARCH.md and CONTEXT.md TODOs
EOF
} > "$BRAIN_DIR/CHANGELOG.md"
echo "  ${GREEN}✓ CHANGELOG.md${RESET}"

# ============================================================
#  README.md (brain workflow manual)
# ============================================================
{
cat <<EOF
# AI Brain — ${PROJECT_NAME}

Generated by **init-ai-brain.sh** (AI Brain Kit) on ${TODAY}.
Compressed context system for AI-assisted development: ~3K tokens of curated
facts replace six-figure-token codebase re-analysis at every session start.
EOF
cat <<'EOF'

## Layers

```
Signal layer (what IS true)          Correction layer (what CHANGED / went wrong)
──────────────────────────           ─────────────────────────────────────────
CONTEXT.md  ← system brain           CHANGELOG.md ← drift corrector
ARCH.md     ← module map             MEMORY.md    ← attention anchor / gotchas
DOMAIN.md   ← invariants             DECISIONS.md ← ADR log
                     ↓
             SESSION_PROMPT.md  (composed per session — do not edit by hand)
```

## Daily workflow

**Start a session** — either let your AI tool load the brain via CLAUDE.md,
or compose an explicit prompt:
```bash
bash ai-brain/scripts/compose-session.sh --module <area> --task "<what you're doing>"
```

**End a session** — tell the AI:
> "Append a CHANGELOG entry for today's work to ai-brain/CHANGELOG.md,
> and update MEMORY.md if you discovered any new gotchas."

**Every sprint (~2 weeks):**
```bash
bash ai-brain/scripts/recompress.sh    # archive changelog, re-compress CONTEXT/MEMORY
bash ai-brain/scripts/brain-metrics.sh # check budgets, health score, token savings
```

## File responsibilities

| File | Who writes it | When |
|---|---|---|
| CONTEXT.md | You + AI re-compress | Sprint start |
| ARCH.md | You/AI when structure changes | On module add |
| DOMAIN.md | You when rules clarify | As domain grows |
| CHANGELOG.md | AI at session end | Every session |
| MEMORY.md | AI during session | On new gotcha |
| DECISIONS.md | AI proposes, you confirm | On arch decision |
| SESSION_PROMPT.md | compose-session.sh | Session start |

## Token budgets

| File | Target | Hard limit |
|---|---|---|
| CONTEXT.md | < 400 | 600 |
| ARCH.md | < 600 | 1000 |
| DOMAIN.md | < 500 | 800 |
| MEMORY.md | < 300 | 500 |
| SESSION_PROMPT.md | < 2000 | 3000 |

Over budget = time to recompress: absorb stable facts upward (MEMORY → DOMAIN/CONTEXT),
archive history (CHANGELOG → archive), delete resolved gotchas.

## Git

Commit every brain file EXCEPT the generated/backup ones (already in .gitignore):
```
ai-brain/SESSION_PROMPT.md
ai-brain/.backups/
```
EOF
} > "$BRAIN_DIR/README.md"
echo "  ${GREEN}✓ README.md${RESET}"

# ============================================================
#  FIRST_FILL_PROMPT.md
# ============================================================
{
cat <<EOF
# One-time brain fill prompt

Paste this to your AI agent (${AI_TOOL}) ONCE, right after initialization.
This is the only time the agent should do a broad codebase scan — afterwards,
the brain replaces it.

---

You are filling the AI brain for **${PROJECT_NAME}**. Do a structural scan of
this repository (directory tree 2 levels deep, package manifests, schema files,
router/entry files — NOT every source file) and then:

1. **ai-brain/ARCH.md** — fill in: the architecture pattern (one line), the
   request/data flow diagram, one short section per module/feature area
   (purpose, key files, dependencies), and data notes (ID format, key
   uniqueness rules). Keep it under 1000 tokens.
2. **ai-brain/CONTEXT.md** — resolve every TODO comment: critical constraints
   you can infer from code (ID formats, pagination shape, error shape, currency
   handling, i18n), the architecture PATTERN line. Keep it under 600 tokens.
3. **ai-brain/DOMAIN.md** — extract invariants from the schema, validation
   code, and state/enum definitions: business rules, data integrity rules,
   security rules, and lifecycle state machines in the documented format.
   Keep it under 800 tokens.
4. Do NOT touch MEMORY.md, DECISIONS.md, or CHANGELOG.md beyond appending one
   CHANGELOG entry describing this fill.

Rules: facts only, no prose. KEY: value lines and terse bullets. If something
is ambiguous, mark it \`<!-- VERIFY: ... -->\` instead of guessing.
EOF
} > "$BRAIN_DIR/FIRST_FILL_PROMPT.md"
echo "  ${GREEN}✓ FIRST_FILL_PROMPT.md${RESET}"

# ============================================================
#  scripts/compose-session.sh
# ============================================================
cat > "$BRAIN_DIR/scripts/compose-session.sh" <<'COMPOSE_EOF'
#!/usr/bin/env bash
# AI Brain · compose-session.sh
# Generates SESSION_PROMPT.md — the composed context injection for one AI session.
# Usage:
#   bash ai-brain/scripts/compose-session.sh
#   bash ai-brain/scripts/compose-session.sh --module auth --task "implement refresh"
set -euo pipefail

BOLD="\033[1m"; CYAN="\033[0;36m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RESET="\033[0m"
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="${BRAIN_DIR}/SESSION_PROMPT.md"
TODAY=$(date +%Y-%m-%d)
MODULE=""; TASK=""; EXTRA_CONTEXT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --module) MODULE="$2"; shift 2 ;;
    --task)   TASK="$2";   shift 2 ;;
    --extra)  EXTRA_CONTEXT="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$MODULE" ]]; then
  printf "  ${BOLD}Module / area of work today${RESET} ${CYAN}→ ${RESET}"; read -r MODULE
fi
if [[ -z "$TASK" ]]; then
  printf "  ${BOLD}Task description${RESET} ${CYAN}→ ${RESET}"; read -r TASK
fi

extract_section() {
  local file="$1" pattern="$2"
  [[ -f "$file" ]] || return 0
  awk "
    /^## .*${pattern}/ { found=1 }
    found && /^## / && !/^## .*${pattern}/ { found=0 }
    found { print }
  " "$file" 2>/dev/null | head -40 || true
}

last_n_changelog() {
  local n="${1:-7}" file="${BRAIN_DIR}/CHANGELOG.md"
  [[ -f "$file" ]] || return 0
  local total skip start_line
  total=$(grep -c "^## \[" "$file" 2>/dev/null || echo 0)
  (( total == 0 )) && return 0
  skip=$(( total > n ? total - n : 0 ))
  start_line=$(grep -n "^## \[" "$file" | sed -n "$((skip + 1))p" | cut -d: -f1)
  [[ -n "$start_line" ]] && tail -n +"$start_line" "$file"
}

AI_TOOL_NAME="Claude Code"
if [[ -f "${BRAIN_DIR}/CONTEXT.md" ]]; then
  found=$(grep "^AI-TOOL:" "${BRAIN_DIR}/CONTEXT.md" 2>/dev/null | cut -d: -f2 | xargs || true)
  [[ -n "$found" ]] && AI_TOOL_NAME="$found"
fi

{
  echo "<!-- AI Brain SESSION_PROMPT — generated ${TODAY} at $(date +%H:%M) -->"
  echo "<!-- Module: ${MODULE} | Task: ${TASK} -->"
  echo "<!-- Do not edit by hand. Regenerate: bash ai-brain/scripts/compose-session.sh -->"
  echo ""
  echo "# AI SESSION CONTEXT"
  echo "**Date:** ${TODAY}  |  **Module:** ${MODULE}  |  **AI tool:** ${AI_TOOL_NAME}"
  echo ""
  echo "---"
  echo ""
  echo "## SYSTEM BRAIN (read first)"
  echo ""
  [[ -f "${BRAIN_DIR}/CONTEXT.md" ]] && grep -v "^<!--" "${BRAIN_DIR}/CONTEXT.md" | grep -v "^[[:space:]]*$" | head -80
  echo ""
  echo "---"
  echo ""
  echo "## ARCHITECTURE (${MODULE} focus)"
  echo ""
  if [[ -f "${BRAIN_DIR}/ARCH.md" ]]; then
    grep -v "^<!--" "${BRAIN_DIR}/ARCH.md" | head -30
    echo ""
    echo "### Relevant module section:"
    section_content="$(extract_section "${BRAIN_DIR}/ARCH.md" "${MODULE}")"
    if [[ -n "$section_content" ]]; then
      echo "$section_content"
    else
      echo "(no dedicated section for '${MODULE}' yet — add one in ARCH.md)"
    fi
  fi
  echo ""
  echo "---"
  echo ""
  echo "## DOMAIN RULES (always enforced)"
  echo ""
  [[ -f "${BRAIN_DIR}/DOMAIN.md" ]] && grep -v "^<!--" "${BRAIN_DIR}/DOMAIN.md" | grep -v "^[[:space:]]*$" | head -60
  echo ""
  echo "---"
  echo ""
  echo "## RECENT CHANGES (last 7 sessions)"
  echo ""
  last_n_changelog 7
  echo ""
  echo "---"
  echo ""
  echo "## MEMORY AND REMINDERS"
  echo ""
  [[ -f "${BRAIN_DIR}/MEMORY.md" ]] && grep -v "^<!--" "${BRAIN_DIR}/MEMORY.md" | grep -v "^[[:space:]]*$" | head -50
  echo ""
  echo "---"
  echo ""
  echo "## THIS SESSION"
  echo ""
  echo "**Task:** ${TASK}"
  echo ""
  if [[ -n "$EXTRA_CONTEXT" ]]; then
    echo "**Extra context:** ${EXTRA_CONTEXT}"
    echo ""
  fi
  echo "### Constraints for this session"
  echo "- Stay within the module: **${MODULE}**"
  echo "- Do not modify other modules unless explicitly asked"
  echo "- Follow all rules in MEMORY.md and DOMAIN.md"
  echo "- At session end: append a CHANGELOG entry with today's work"
  echo "- If you discover a new gotcha or rule: add it to MEMORY.md"
  echo ""
  echo "### Definition of done"
  echo "- [ ] Task completed as described"
  echo "- [ ] Tests written for new business logic"
  echo "- [ ] No type errors or lint errors"
  echo "- [ ] CHANGELOG.md entry appended"
  echo "- [ ] MEMORY.md updated if needed"
  echo ""
  echo "---"
  echo "<!-- END SESSION PROMPT -->"
} > "$OUTPUT"

TOKEN_ESTIMATE=$(wc -w < "$OUTPUT" | xargs)
TOKEN_COUNT=$(( TOKEN_ESTIMATE * 4 / 3 ))
echo -e "  ${GREEN}✓  SESSION_PROMPT.md generated (~${TOKEN_COUNT} tokens)${RESET}"
if (( TOKEN_COUNT > 3000 )); then
  echo -e "  ${YELLOW}⚠  Over 3000 tokens — consider: bash ai-brain/scripts/recompress.sh${RESET}"
fi
COMPOSE_EOF
chmod +x "$BRAIN_DIR/scripts/compose-session.sh"
echo "  ${GREEN}✓ scripts/compose-session.sh${RESET}"

# ============================================================
#  scripts/recompress.sh
# ============================================================
cat > "$BRAIN_DIR/scripts/recompress.sh" <<'RECOMPRESS_EOF'
#!/usr/bin/env bash
# AI Brain · recompress.sh — periodic context re-compression ritual.
# Run after every sprint or when a brain file exceeds its hard limit.
#  1. Shows token estimates for all brain files
#  2. Archives old CHANGELOG entries (keeps last 30)
#  3. Backs up the current brain
#  4. Prints the re-compression prompt to send to your AI
set -euo pipefail

BOLD="\033[1m"; CYAN="\033[0;36m"; GREEN="\033[0;32m"; YELLOW="\033[0;33m"
PURPLE="\033[0;35m"; DIM="\033[2m"; RESET="\033[0m"
BRAIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TODAY=$(date +%Y-%m-%d)

echo ""
echo -e "${PURPLE}${BOLD}━━━  AI Brain Re-Compression  ━━━${RESET}"
echo ""

echo -e "${BOLD}  Brain file sizes (estimated tokens):${RESET}"
total_words=0
for f in CONTEXT.md ARCH.md DOMAIN.md MEMORY.md CHANGELOG.md DECISIONS.md; do
  fpath="${BRAIN_DIR}/${f}"
  if [[ -f "$fpath" ]]; then
    words=$(wc -w < "$fpath" | xargs)
    tokens=$(( words * 4 / 3 ))
    total_words=$(( total_words + words ))
    if (( tokens > 800 )); then
      echo -e "  ${YELLOW}  ${f}: ~${tokens} tokens  ⚠ over target${RESET}"
    else
      echo -e "  ${GREEN}  ${f}: ~${tokens} tokens  ✓${RESET}"
    fi
  fi
done
total_tokens=$(( total_words * 4 / 3 ))
echo ""
echo -e "  ${BOLD}  Total brain: ~${total_tokens} tokens${RESET}"
echo ""

CLOG="${BRAIN_DIR}/CHANGELOG.md"
if [[ -f "$CLOG" ]]; then
  entry_count=$(grep -c "^## \[" "$CLOG" 2>/dev/null || echo 0)
  if (( entry_count > 30 )); then
    echo -e "  ${YELLOW}  CHANGELOG has ${entry_count} entries (> 30). Archiving old ones...${RESET}"
    ARCHIVE="${BRAIN_DIR}/CHANGELOG.archive.md"
    skip=$(( entry_count - 30 ))
    first_keep_line=$(grep -n "^## \[" "$CLOG" | sed -n "$((skip + 1))p" | cut -d: -f1)
    if [[ -z "$first_keep_line" ]]; then
      echo -e "  ${YELLOW}  Could not locate archive split point — skipping${RESET}" >&2
    else
      head -n $(( first_keep_line - 1 )) "$CLOG" >> "$ARCHIVE"
      echo "<!-- archived on ${TODAY} -->" >> "$ARCHIVE"
      header=$(head -8 "$CLOG")
      tmp_recent=$(mktemp "${TMPDIR:-/tmp}/brain-clog.XXXXXX")
      trap 'rm -f "${tmp_recent:-}"' EXIT
      tail -n +"$first_keep_line" "$CLOG" > "$tmp_recent"
      printf '%s\n\n' "$header" > "$CLOG"
      cat "$tmp_recent" >> "$CLOG"
      rm -f "$tmp_recent"; trap - EXIT
      echo -e "  ${GREEN}  Archived to CHANGELOG.archive.md, kept last 30 entries${RESET}"
    fi
  else
    echo -e "  ${GREEN}  CHANGELOG: ${entry_count} entries — no archiving needed${RESET}"
  fi
fi
echo ""

BACKUP_DIR="${BRAIN_DIR}/.backups"
mkdir -p "$BACKUP_DIR"
STAMP=$(date +%Y%m%d_%H%M)
# NOTE: --exclude flags must come BEFORE the directory operand (BSD tar requirement)
tar --exclude "*/.backups" --exclude "*/.backups/*" --exclude "*/SESSION_PROMPT.md" \
  -czf "${BACKUP_DIR}/brain_${STAMP}.tar.gz" \
  -C "$(dirname "$BRAIN_DIR")" "$(basename "$BRAIN_DIR")"
echo -e "  ${GREEN}  Brain backed up → ai-brain/.backups/brain_${STAMP}.tar.gz${RESET}"
echo ""

PROJECT="this project"
if [[ -f "${BRAIN_DIR}/CONTEXT.md" ]]; then
  found=$(grep "^PROJECT:" "${BRAIN_DIR}/CONTEXT.md" 2>/dev/null | cut -d: -f2 | xargs || true)
  [[ -n "$found" ]] && PROJECT="$found"
fi

echo -e "${BOLD}  Re-compression prompt — send to your AI with CONTEXT.md + last 20 CHANGELOG entries + MEMORY.md:${RESET}"
echo ""
echo -e "${CYAN}  ┌──────────────────────────────────────────────────────────────────"
echo "  │ You are re-compressing the AI brain for ${PROJECT}."
echo "  │"
echo "  │ CONTEXT.md must stay under 600 tokens. Read the current CONTEXT.md"
echo "  │ and the last 20 CHANGELOG entries."
echo "  │"
echo "  │ Your task:"
echo "  │ 1. Absorb completed decisions from CHANGELOG into CONTEXT.md as facts"
echo "  │ 2. Remove constraints that were resolved or are no longer relevant"
echo "  │ 3. Update the PHASE field if the project has progressed"
echo "  │ 4. Add new stack components or critical constraints discovered"
echo "  │ 5. Keep the exact format — no prose, only structured key: value lines"
echo "  │ 6. Target: under 600 tokens total"
echo "  │"
echo "  │ Also review MEMORY.md:"
echo "  │ 7. Promote items that are now permanent rules into DOMAIN.md or CONTEXT.md"
echo "  │ 8. Remove items that are no longer relevant (resolved gotchas)"
echo "  │"
echo "  │ Output: new CONTEXT.md content, then new MEMORY.md content. Nothing else."
echo -e "  └──────────────────────────────────────────────────────────────────${RESET}"
echo ""
echo -e "  ${DIM}After the AI responds: replace both files, then commit:${RESET}"
echo -e "  ${DIM}  git add ai-brain/ && git commit -m 'brain: sprint re-compression ${TODAY}'${RESET}"
echo ""
echo -e "  ${GREEN}✓  Re-compression ritual complete${RESET}"
RECOMPRESS_EOF
chmod +x "$BRAIN_DIR/scripts/recompress.sh"
echo "  ${GREEN}✓ scripts/recompress.sh${RESET}"

# ============================================================
#  scripts/brain-metrics.sh
#  (copied from sibling if the kit is intact, else embedded copy)
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/brain-metrics.sh" ]]; then
  cp "${SCRIPT_DIR}/brain-metrics.sh" "$BRAIN_DIR/scripts/brain-metrics.sh"
else
  cat > "$BRAIN_DIR/scripts/brain-metrics.sh" <<'METRICS_EOF'
#!/usr/bin/env bash
# AI Brain · brain-metrics.sh — brain health + token-savings calculator.
# (Embedded copy — canonical version lives in the AI Brain Kit.)
# Usage: bash brain-metrics.sh [--brain DIR] [--sessions N] [--scan-fraction PCT] [--json]
set -euo pipefail

if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; CYAN=$'\033[36m'; PURPLE=$'\033[35m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; PURPLE=""; RESET=""
fi

BRAIN_DIR=""
SESSIONS_PER_MONTH=20
SCAN_FRACTION=25
JSON_MODE=no

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brain)         BRAIN_DIR="$2"; shift 2 ;;
    --sessions)      SESSIONS_PER_MONTH="$2"; shift 2 ;;
    --scan-fraction) SCAN_FRACTION="$2"; shift 2 ;;
    --json)          JSON_MODE=yes; shift ;;
    -h|--help)       grep '^#' "$0" | sed 's/^# \{0,2\}//' | head -6; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$BRAIN_DIR" ]]; then
  if [[ -f "${SCRIPT_DIR}/../CONTEXT.md" ]]; then
    BRAIN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
  elif [[ -f "./ai-brain/CONTEXT.md" ]]; then
    BRAIN_DIR="$(cd ./ai-brain && pwd)"
  else
    echo "${RED}Could not locate an ai-brain/ folder. Use --brain <dir>.${RESET}" >&2
    exit 1
  fi
else
  BRAIN_DIR="$(cd "$BRAIN_DIR" && pwd)"
fi
PROJECT_ROOT="$(dirname "$BRAIN_DIR")"

tokens_of() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local w; w=$(wc -w < "$f" | tr -d ' ')
    echo $(( w * 4 / 3 ))
  else
    echo 0
  fi
}
mtime_of() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0; }
days_since() {
  local f="$1" now m
  now=$(date +%s); m=$(mtime_of "$f")
  if [[ "$m" == "0" ]]; then echo "-"; else echo $(( (now - m) / 86400 )); fi
}
fmt_num() {
  echo "$1" | awk '{ s=$1; r=""; while (length(s) > 3) { r="," substr(s, length(s)-2) r; s=substr(s, 1, length(s)-3) } print s r }'
}

BUDGETS="CONTEXT.md:400:600
ARCH.md:600:1000
DOMAIN.md:500:800
MEMORY.md:300:500
DECISIONS.md:-:-
CHANGELOG.md:-:-"

BRAIN_TOTAL=0; OVER_TARGET=0; OVER_HARD=0; MISSING_CORE=0
FILE_REPORT=""; JSON_FILES=""

while IFS=: read -r fname target hard; do
  fpath="${BRAIN_DIR}/${fname}"
  t=$(tokens_of "$fpath")
  BRAIN_TOTAL=$(( BRAIN_TOTAL + t ))
  age=$(days_since "$fpath")
  status="ok"
  if [[ ! -f "$fpath" ]]; then
    status="missing"; MISSING_CORE=$(( MISSING_CORE + 1 ))
  elif [[ "$hard" != "-" ]] && (( t > hard )); then
    status="over-hard"; OVER_HARD=$(( OVER_HARD + 1 ))
  elif [[ "$target" != "-" ]] && (( t > target )); then
    status="over-target"; OVER_TARGET=$(( OVER_TARGET + 1 ))
  fi
  FILE_REPORT="${FILE_REPORT}${fname}|${t}|${target}|${hard}|${age}|${status}
"
  [[ -n "$JSON_FILES" ]] && JSON_FILES="${JSON_FILES},"
  JSON_FILES="${JSON_FILES}
    {\"file\":\"${fname}\",\"tokens\":${t},\"target\":\"${target}\",\"hard_limit\":\"${hard}\",\"days_since_update\":\"${age}\",\"status\":\"${status}\"}"
done <<EOF
$BUDGETS
EOF

LIST_FILE="$(mktemp "${TMPDIR:-/tmp}/brain-metrics.XXXXXX")"
trap 'rm -f "$LIST_FILE"' EXIT

find "$PROJECT_ROOT" \
  \( -type d \( \
       -name node_modules -o -name .git -o -name dist -o -name build -o -name out \
    -o -name coverage -o -name vendor -o -name .next -o -name .nuxt -o -name .dart_tool \
    -o -name .gradle -o -name Pods -o -name DerivedData -o -name target \
    -o -name __pycache__ -o -name .venv -o -name venv -o -name .turbo -o -name .cache \
    -o -name .backups -o -name generated -o -name .expo -o -name ai-brain \
    -o -name ai-brain-kit \
  \) -prune \) -o \
  -type f \( \
       -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' -o -name '*.mjs' \
    -o -name '*.cjs' -o -name '*.vue' -o -name '*.svelte' -o -name '*.py' -o -name '*.go' \
    -o -name '*.rs' -o -name '*.rb' -o -name '*.php' -o -name '*.java' -o -name '*.kt' \
    -o -name '*.kts' -o -name '*.swift' -o -name '*.dart' -o -name '*.ex' -o -name '*.exs' \
    -o -name '*.cs' -o -name '*.scala' -o -name '*.sql' -o -name '*.prisma' \
    -o -name '*.graphql' -o -name '*.proto' \
  \) -print > "$LIST_FILE" 2>/dev/null || true

SRC_FILES=$(wc -l < "$LIST_FILE" | tr -d ' ')
TEST_FILES=$(grep -Ec '(\.spec\.|\.test\.|_test\.|/tests?/|/__tests__/)' "$LIST_FILE" || true)
TEST_FILES=${TEST_FILES:-0}

CODE_WORDS=0
if (( SRC_FILES > 0 )); then
  CODE_WORDS=$(tr '\n' '\0' < "$LIST_FILE" | xargs -0 wc -w 2>/dev/null \
    | awk '$2 != "total" {s+=$1} END {print s+0}')
fi
CODE_TOKENS=$(( CODE_WORDS * 4 / 3 ))

SCAN_TOKENS=$(( CODE_TOKENS * SCAN_FRACTION / 100 ))
SAVED_PER_SESSION=$(( SCAN_TOKENS - BRAIN_TOTAL ))
(( SAVED_PER_SESSION < 0 )) && SAVED_PER_SESSION=0
SAVED_PER_MONTH=$(( SAVED_PER_SESSION * SESSIONS_PER_MONTH ))
if (( SCAN_TOKENS > 0 )); then
  SAVINGS_PCT=$(awk -v b="$BRAIN_TOTAL" -v s="$SCAN_TOKENS" 'BEGIN { printf "%.1f", (1 - b/s) * 100 }')
else
  SAVINGS_PCT="0.0"
fi
if (( CODE_TOKENS > 0 )); then
  COMPRESSION=$(awk -v b="$BRAIN_TOTAL" -v c="$CODE_TOKENS" 'BEGIN { printf "%.2f", (b/c) * 100 }')
else
  COMPRESSION="0.00"
fi

CLOG="${BRAIN_DIR}/CHANGELOG.md"
CHANGELOG_ENTRIES=0
[[ -f "$CLOG" ]] && CHANGELOG_ENTRIES=$(grep -c '^## \[' "$CLOG" 2>/dev/null || echo 0)
CHANGELOG_AGE=$(days_since "$CLOG")
ADR_COUNT=0
[[ -f "${BRAIN_DIR}/DECISIONS.md" ]] && ADR_COUNT=$(grep -c '^## ADR-' "${BRAIN_DIR}/DECISIONS.md" 2>/dev/null || echo 0)
MEMORY_ITEMS=0
[[ -f "${BRAIN_DIR}/MEMORY.md" ]] && MEMORY_ITEMS=$(grep -c '^- ' "${BRAIN_DIR}/MEMORY.md" 2>/dev/null || echo 0)
MEMORY_AGE=$(days_since "${BRAIN_DIR}/MEMORY.md")

SCORE=100
NOTES=""
add_note() { NOTES="${NOTES}  - $1
"; }
(( MISSING_CORE > 0 )) && { SCORE=$(( SCORE - 15 * MISSING_CORE )); add_note "${MISSING_CORE} core brain file(s) missing (-15 each)"; }
(( OVER_HARD > 0 ))    && { SCORE=$(( SCORE - 10 * OVER_HARD ));    add_note "${OVER_HARD} file(s) over hard token limit (-10 each) -> run recompress"; }
(( OVER_TARGET > 0 ))  && { SCORE=$(( SCORE - 5 * OVER_TARGET ));   add_note "${OVER_TARGET} file(s) over token target (-5 each)"; }
if [[ "$CHANGELOG_AGE" != "-" ]] && (( CHANGELOG_AGE > 14 )); then
  SCORE=$(( SCORE - 10 )); add_note "CHANGELOG stale (${CHANGELOG_AGE}d since update, -10) -> session-end ritual is being skipped"
fi
if [[ "$MEMORY_AGE" != "-" ]] && (( MEMORY_AGE > 30 )); then
  SCORE=$(( SCORE - 10 )); add_note "MEMORY stale (${MEMORY_AGE}d since update, -10) -> gotchas are not being captured"
fi
if (( ADR_COUNT < 1 )); then
  SCORE=$(( SCORE - 5 )); add_note "No ADRs recorded (-5) -> decisions are being lost"
fi
if (( CHANGELOG_ENTRIES > 30 )); then
  SCORE=$(( SCORE - 5 )); add_note "CHANGELOG has ${CHANGELOG_ENTRIES} entries (>30, -5) -> run recompress to archive"
fi
(( SCORE < 0 )) && SCORE=0

GRADE="A"
(( SCORE < 90 )) && GRADE="B"
(( SCORE < 75 )) && GRADE="C"
(( SCORE < 60 )) && GRADE="D"
(( SCORE < 40 )) && GRADE="F"

if [[ "$JSON_MODE" == "yes" ]]; then
  cat <<EOF
{
  "brain_dir": "${BRAIN_DIR}",
  "project_root": "${PROJECT_ROOT}",
  "files": [${JSON_FILES}
  ],
  "brain_tokens": ${BRAIN_TOTAL},
  "codebase": {
    "source_files": ${SRC_FILES},
    "test_files": ${TEST_FILES},
    "tokens": ${CODE_TOKENS}
  },
  "savings": {
    "scan_fraction_pct": ${SCAN_FRACTION},
    "cold_start_scan_tokens": ${SCAN_TOKENS},
    "saved_per_session": ${SAVED_PER_SESSION},
    "sessions_per_month": ${SESSIONS_PER_MONTH},
    "saved_per_month": ${SAVED_PER_MONTH},
    "savings_pct_vs_cold_start": ${SAVINGS_PCT},
    "brain_to_codebase_pct": ${COMPRESSION}
  },
  "counts": {
    "changelog_entries": ${CHANGELOG_ENTRIES},
    "changelog_age_days": "${CHANGELOG_AGE}",
    "adr_count": ${ADR_COUNT},
    "memory_items": ${MEMORY_ITEMS},
    "memory_age_days": "${MEMORY_AGE}"
  },
  "health": { "score": ${SCORE}, "grade": "${GRADE}" }
}
EOF
  exit 0
fi

echo ""
echo "${PURPLE}${BOLD}━━━  AI Brain Metrics  ━━━${RESET}"
echo "${DIM}  brain: ${BRAIN_DIR}${RESET}"
echo ""
echo "${BOLD}  Brain files (tokens vs budget):${RESET}"
printf "  %-14s %10s %10s %10s %8s  %s\n" "file" "tokens" "target" "hard" "age(d)" "status"
printf "  %-14s %10s %10s %10s %8s  %s\n" "--------------" "------" "------" "------" "------" "------"
echo "$FILE_REPORT" | while IFS='|' read -r f t target hard age status; do
  [[ -z "$f" ]] && continue
  case "$status" in
    ok)          c="$GREEN"; icon="✓" ;;
    over-target) c="$YELLOW"; icon="⚠" ;;
    over-hard)   c="$RED"; icon="✗" ;;
    missing)     c="$RED"; icon="∅" ;;
  esac
  printf "  ${c}%-14s %10s %10s %10s %8s  %s %s${RESET}\n" "$f" "$t" "$target" "$hard" "$age" "$icon" "$status"
done
echo ""
echo "  ${BOLD}Total brain: ~$(fmt_num "$BRAIN_TOTAL") tokens${RESET}"
echo ""
echo "${BOLD}  Codebase:${RESET}"
echo "    Source files:   $(fmt_num "$SRC_FILES")  ${DIM}(${TEST_FILES} test files)${RESET}"
echo "    Est. tokens:    $(fmt_num "$CODE_TOKENS")"
echo "    Brain = ${BOLD}${COMPRESSION}%${RESET} of the codebase"
echo ""
echo "${BOLD}  Token savings estimate:${RESET}"
echo "    Cold-start session scan (${SCAN_FRACTION}% of codebase):  ~$(fmt_num "$SCAN_TOKENS") tokens"
echo "    Brain-loaded session:                     ~$(fmt_num "$BRAIN_TOTAL") tokens"
echo "    ${GREEN}Saved per session:   ~$(fmt_num "$SAVED_PER_SESSION") tokens (${SAVINGS_PCT}%)${RESET}"
echo "    ${GREEN}Saved per month:     ~$(fmt_num "$SAVED_PER_MONTH") tokens (${SESSIONS_PER_MONTH} sessions)${RESET}"
echo ""
echo "${BOLD}  Rituals:${RESET}"
echo "    CHANGELOG entries: ${CHANGELOG_ENTRIES}  ${DIM}(last update ${CHANGELOG_AGE}d ago)${RESET}"
echo "    ADRs recorded:     ${ADR_COUNT}"
echo "    MEMORY items:      ${MEMORY_ITEMS}  ${DIM}(last update ${MEMORY_AGE}d ago)${RESET}"
echo ""
case "$GRADE" in
  A) gc="$GREEN" ;; B) gc="$GREEN" ;; C) gc="$YELLOW" ;; *) gc="$RED" ;;
esac
echo "${BOLD}  Brain health: ${gc}${SCORE}/100 (grade ${GRADE})${RESET}"
if [[ -n "$NOTES" ]]; then
  echo ""
  echo "${BOLD}  Improve:${RESET}"
  printf "%s" "$NOTES"
fi
echo ""
METRICS_EOF
fi
chmod +x "$BRAIN_DIR/scripts/brain-metrics.sh"
echo "  ${GREEN}✓ scripts/brain-metrics.sh${RESET}"

# ============================================================
#  .gitignore
# ============================================================
GITIGNORE="${TARGET_DIR}/.gitignore"
touch "$GITIGNORE"
if ! grep -q "ai-brain/SESSION_PROMPT.md" "$GITIGNORE" 2>/dev/null; then
  {
    echo ""
    echo "# AI Brain (generated / backups — commit everything else in ai-brain/)"
    echo "ai-brain/SESSION_PROMPT.md"
    echo "ai-brain/.backups/"
  } >> "$GITIGNORE"
  echo "  ${GREEN}✓ .gitignore entries added${RESET}"
else
  echo "  ${DIM}○ .gitignore already has ai-brain entries${RESET}"
fi

# ============================================================
#  CLAUDE.md starter (only if the project has none)
# ============================================================
write_claude_md() {
  local dest="$1"
  {
cat <<EOF
# ${PROJECT_NAME} — AI Engineering Protocol

## 0. AI Brain (context compression system)

This project uses a layered compressed-context system in \`ai-brain/\`.
Do NOT re-analyze the codebase at session start — load the brain instead.

| Trigger | File to read | Why |
|---|---|---|
| **Every session start** | \`ai-brain/CONTEXT.md\` + \`ai-brain/MEMORY.md\` | System brain + gotchas before writing any code |
| **Working on a module** | \`ai-brain/ARCH.md\` | Module purpose, key files, dependencies |
| **Business logic / validation** | \`ai-brain/DOMAIN.md\` | Non-negotiable invariants and state machines |
| **Wondering "why was this done?"** | \`ai-brain/DECISIONS.md\` | ADR log — never reverse without a new ADR |
| **Bug fix** | \`ai-brain/MEMORY.md\` | Check known gotchas before fixing |
| **Checking recent changes** | \`ai-brain/CHANGELOG.md\` | Recent session summaries |

### Session-end ritual (MANDATORY)
After completing a non-trivial task:
1. Append a CHANGELOG entry to \`ai-brain/CHANGELOG.md\`
2. New gotcha or hard-won rule discovered → add to \`ai-brain/MEMORY.md\`
3. Architectural decision made → propose an ADR in \`ai-brain/DECISIONS.md\`

### Sprint ritual (every ~2 weeks)
Run \`bash ai-brain/scripts/recompress.sh\` and \`bash ai-brain/scripts/brain-metrics.sh\`.

## 1. Role & Philosophy
- **You are a Senior Pair Programmer. The user is the System Architect.**
- Never write code neither party understands. If asked "Why?", explain fundamentally.
- Do not refactor large blocks or change architectural patterns without explicit approval.
- Challenge requests that contradict existing architecture before implementing.

## 2. Logic-First Workflow (Explore → Plan → Code → Test)
1. **Analyze** — read \`ai-brain/CONTEXT.md\` + \`MEMORY.md\`, then the relevant module files.
2. **Plan** — propose a bullet-point logic flow; check DOMAIN.md invariants and DECISIONS.md.
3. **Wait for GO** on large changes — do not implement until the plan is approved.
4. **Implement** — atomic, focused changes. One task = one concern.
5. **Test** — write or update tests alongside the implementation, then run the suite.

> Skip steps 2-3 only for trivial 1-line fixes or when told "just do it."

## 3. Development standards
- One task = one change. No unrelated fixes mixed into feature work.
- Never create new files when editing an existing one achieves the goal.
- Validate at system boundaries (user input, external APIs).
- Never interpolate strings into raw SQL / shell.
- Tests: mock at the boundary, set mock implementations per-test (not at describe level).
- Error-path tests assert on exception TYPE, not message strings.

## 4. Project specifics
<!-- TODO: add the 5-10 conventions unique to this project (error shapes, ID formats,
     pagination, i18n language, currency handling). Keep in sync with ai-brain/CONTEXT.md. -->
EOF
  } > "$dest"
}

if [[ "$WRITE_CLAUDE_MD" == "yes" ]]; then
  if [[ -f "${TARGET_DIR}/CLAUDE.md" || -f "${TARGET_DIR}/.claude/CLAUDE.md" ]]; then
    write_claude_md "${BRAIN_DIR}/CLAUDE-SNIPPET.md"
    echo "  ${YELLOW}○ CLAUDE.md already exists — wrote ai-brain/CLAUDE-SNIPPET.md; merge the brain-routing section into your CLAUDE.md${RESET}"
  else
    write_claude_md "${TARGET_DIR}/CLAUDE.md"
    echo "  ${GREEN}✓ CLAUDE.md starter created${RESET}"
  fi
fi

# ============================================================
#  DONE
# ============================================================
echo ""
echo "${GREEN}${BOLD}✓ AI Brain initialized for ${PROJECT_NAME}${RESET}"
echo ""
echo "${BOLD}Next steps:${RESET}"
echo "  1. ${BOLD}One-time fill:${RESET} open your AI agent in this repo and paste"
echo "     ${CYAN}ai-brain/FIRST_FILL_PROMPT.md${RESET} — it fills ARCH.md/CONTEXT.md/DOMAIN.md"
echo "     from a structural scan (the LAST broad scan this repo should need)."
echo "  2. Review the generated facts — fix anything the agent got wrong."
echo "  3. Commit: ${CYAN}git add ai-brain/ CLAUDE.md .gitignore && git commit -m 'chore: init ai-brain'${RESET}"
echo "  4. Check health anytime: ${CYAN}bash ai-brain/scripts/brain-metrics.sh${RESET}"
echo "  5. Every session end: append CHANGELOG entry + MEMORY gotchas."
echo "  6. Every sprint: ${CYAN}bash ai-brain/scripts/recompress.sh${RESET}"
echo ""
