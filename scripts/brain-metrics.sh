#!/usr/bin/env bash
# ============================================================
#  AI Brain Kit · brain-metrics.sh
#  Brain health + token-savings calculator.
#
#  Measures:
#    1. Token estimate per brain file vs its budget (target / hard limit)
#    2. Total brain size vs total codebase size -> compression ratio
#    3. Estimated tokens saved per session and per month
#    4. Freshness (days since each brain file was updated)
#    5. Counts: CHANGELOG entries, ADRs, MEMORY gotchas, source/test files
#    6. A 0-100 brain health score
#
#  Works standalone in any project that has an ai-brain/ folder.
#  Compatible with macOS bash 3.2 and Linux.
#
#  Usage:
#    bash brain-metrics.sh                          # auto-locate ai-brain/
#    bash brain-metrics.sh --brain path/to/ai-brain
#    bash brain-metrics.sh --sessions 20            # sessions/month (default 20)
#    bash brain-metrics.sh --scan-fraction 25       # % of codebase an agent would
#                                                   # otherwise re-read per session
#    bash brain-metrics.sh --json                   # machine-readable output
# ============================================================

set -euo pipefail

# ---------- colors ----------
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; CYAN=$'\033[36m'; PURPLE=$'\033[35m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; CYAN=""; PURPLE=""; RESET=""
fi

# ---------- args ----------
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
    -h|--help)       grep '^#' "$0" | sed 's/^# \{0,2\}//' | head -30; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ---------- locate brain ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "$BRAIN_DIR" ]]; then
  if [[ -f "${SCRIPT_DIR}/../CONTEXT.md" ]]; then
    BRAIN_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"          # installed at ai-brain/scripts/
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

# ---------- helpers ----------
tokens_of() {  # words * 4/3 heuristic (consistent with compose/recompress scripts)
  local f="$1"
  if [[ -f "$f" ]]; then
    local w; w=$(wc -w < "$f" | tr -d ' ')
    echo $(( w * 4 / 3 ))
  else
    echo 0
  fi
}

mtime_of() {  # epoch mtime, BSD or GNU stat
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

days_since() {
  local f="$1" now m
  now=$(date +%s); m=$(mtime_of "$f")
  if [[ "$m" == "0" ]]; then echo "-"; else echo $(( (now - m) / 86400 )); fi
}

fmt_num() {  # 1234567 -> 1,234,567
  echo "$1" | awk '{ s=$1; r=""; while (length(s) > 3) { r="," substr(s, length(s)-2) r; s=substr(s, 1, length(s)-3) } print s r }'
}

# ---------- 1. per-file budgets ----------
# file:target:hard  ("-" = no budget, growth handled by rotation/append-only rules)
BUDGETS="CONTEXT.md:400:600
ARCH.md:600:1000
DOMAIN.md:500:800
MEMORY.md:300:500
DECISIONS.md:-:-
CHANGELOG.md:-:-"

BRAIN_TOTAL=0
OVER_TARGET=0
OVER_HARD=0
MISSING_CORE=0
FILE_REPORT=""
JSON_FILES=""

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

# ---------- 2. codebase scan ----------
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

# ---------- 3. savings model ----------
# Without a brain, an agent cold-starting a session re-reads ~SCAN_FRACTION% of
# the codebase to rebuild context. With a brain it reads BRAIN_TOTAL tokens.
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

# ---------- 4. counts + freshness ----------
CLOG="${BRAIN_DIR}/CHANGELOG.md"
CHANGELOG_ENTRIES=0
[[ -f "$CLOG" ]] && CHANGELOG_ENTRIES=$(grep -c '^## \[' "$CLOG" 2>/dev/null || echo 0)
CHANGELOG_AGE=$(days_since "$CLOG")

ADR_COUNT=0
[[ -f "${BRAIN_DIR}/DECISIONS.md" ]] && ADR_COUNT=$(grep -c '^## ADR-' "${BRAIN_DIR}/DECISIONS.md" 2>/dev/null || echo 0)

MEMORY_ITEMS=0
[[ -f "${BRAIN_DIR}/MEMORY.md" ]] && MEMORY_ITEMS=$(grep -c '^- ' "${BRAIN_DIR}/MEMORY.md" 2>/dev/null || echo 0)
MEMORY_AGE=$(days_since "${BRAIN_DIR}/MEMORY.md")

# ---------- 5. health score ----------
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

# ---------- output ----------
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
