#!/bin/bash
# Workflow Orchestrator - Run Gate Checks
# Executes configurable validation checks between workflow steps
#
# Usage: run-gate-checks.sh <state_file> <gate_type>
#
# Gate Types:
#   - typecheck-lint     : Run pnpm typecheck && pnpm lint
#   - typecheck          : Run pnpm typecheck only
#   - lint               : Run pnpm lint only
#   - full-suite         : Run typecheck, lint, and tests
#   - custom             : Run commands from config
#
# Returns:
#   0 - All checks passed
#   1 - One or more checks failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source parsing utilities
source "${SCRIPT_DIR}/parse-config.sh"

# Arguments
STATE_FILE="${1:-}"
GATE_TYPE="${2:-typecheck-lint}"
STEP_ID="${3:-}"

if [[ -z "$STATE_FILE" ]]; then
  echo "Usage: run-gate-checks.sh <state_file> [gate_type] [step_id]" >&2
  exit 1
fi

# Parse state
WORKFLOW_CONFIG=$(parse_state_field "$STATE_FILE" "workflow_config")
OUTPUT_DIR=$(parse_state_field "$STATE_FILE" "output_dir")

# Default check commands
TYPECHECK_CMD="pnpm typecheck"
LINT_CMD="pnpm lint"
TEST_CMD="timeout 30s pnpm test"

# Get custom commands from config if specified
if [[ -n "$STEP_ID" ]] && [[ -f "$WORKFLOW_CONFIG" ]]; then
  CUSTOM_GATE=$(yq ".phases[].steps[] | select(.id == \"$STEP_ID\") | .gate_checks // null" "$WORKFLOW_CONFIG" 2>/dev/null || echo "null")

  if [[ "$CUSTOM_GATE" != "null" ]]; then
    # Override with custom commands
    TYPECHECK_CMD=$(echo "$CUSTOM_GATE" | yq '.typecheck // "pnpm typecheck"')
    LINT_CMD=$(echo "$CUSTOM_GATE" | yq '.lint // "pnpm lint"')
    TEST_CMD=$(echo "$CUSTOM_GATE" | yq '.test // "timeout 30s pnpm test"')
  fi
fi

# Track results
PASSED=0
FAILED=0
RESULTS=""

# Helper function to run a check
run_check() {
  local name="$1"
  local cmd="$2"

  echo "🔍 Running $name..."

  if eval "$cmd" > /tmp/gate-check-output.txt 2>&1; then
    echo "✅ $name: PASSED"
    RESULTS+="✅ $name: PASSED\n"
    ((PASSED++)) || true
    return 0
  else
    echo "❌ $name: FAILED"
    echo "   Output:"
    head -20 /tmp/gate-check-output.txt | sed 's/^/   /'
    RESULTS+="❌ $name: FAILED\n"
    ((FAILED++)) || true
    return 1
  fi
}

# Run checks based on gate type
case "$GATE_TYPE" in
  typecheck-lint)
    echo "🚦 Gate Check: typecheck-lint"
    echo "================================"
    run_check "TypeScript" "$TYPECHECK_CMD" || true
    run_check "Biome Lint" "$LINT_CMD" || true
    ;;

  typecheck)
    echo "🚦 Gate Check: typecheck"
    echo "========================"
    run_check "TypeScript" "$TYPECHECK_CMD" || true
    ;;

  lint)
    echo "🚦 Gate Check: lint"
    echo "==================="
    run_check "Biome Lint" "$LINT_CMD" || true
    ;;

  full-suite)
    echo "🚦 Gate Check: full-suite"
    echo "========================="
    run_check "TypeScript" "$TYPECHECK_CMD" || true
    run_check "Biome Lint" "$LINT_CMD" || true
    run_check "Tests" "$TEST_CMD" || true
    ;;

  e2e-smoke)
    echo "🚦 Gate Check: e2e-smoke"
    echo "========================"
    run_check "TypeScript" "$TYPECHECK_CMD" || true
    run_check "Biome Lint" "$LINT_CMD" || true
    run_check "Smoke Tests" "pnpm test:e2e:smoke" || true
    ;;

  custom)
    echo "🚦 Gate Check: custom"
    echo "===================="
    if [[ -n "$STEP_ID" ]] && [[ "$CUSTOM_GATE" != "null" ]]; then
      CUSTOM_CMDS=$(echo "$CUSTOM_GATE" | yq '.commands[]' 2>/dev/null || echo "")
      for cmd in $CUSTOM_CMDS; do
        run_check "Custom ($cmd)" "$cmd" || true
      done
    else
      echo "No custom commands configured for step: $STEP_ID"
    fi
    ;;

  none|skip)
    echo "🚦 Gate Check: skipped"
    echo "======================"
    echo "No gate checks configured for this step."
    exit 0
    ;;

  *)
    echo "Unknown gate type: $GATE_TYPE" >&2
    echo "Available types: typecheck-lint, typecheck, lint, full-suite, e2e-smoke, custom, none" >&2
    exit 1
    ;;
esac

# Summary
echo ""
echo "================================"
echo "🚦 Gate Check Summary"
echo "================================"
echo -e "$RESULTS"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

# Return exit code based on results
if [[ $FAILED -gt 0 ]]; then
  echo ""
  echo "⚠️  Gate check failed. Fix issues before proceeding."
  exit 1
else
  echo ""
  echo "✅ All gate checks passed!"
  exit 0
fi
