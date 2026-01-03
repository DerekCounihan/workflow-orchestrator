#!/bin/bash
# Workflow Orchestrator - Advance Step
# Advances workflow to the next step or phase
#
# Usage: advance-step.sh <state_file> [--force]
#
# Returns:
# - Next step ID
# - "CHECKPOINT_<step_id>" if next step is a checkpoint
# - "PHASE_END" if no more steps in phase
# - "WORKFLOW_END" if no more phases

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source parsing utilities
source "${SCRIPT_DIR}/parse-config.sh"

# Arguments
STATE_FILE="${1:-}"
FORCE="${2:-}"

if [[ -z "$STATE_FILE" ]]; then
  echo "Usage: advance-step.sh <state_file> [--force]" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: State file not found: $STATE_FILE" >&2
  exit 1
fi

# Parse current state
CURRENT_PHASE=$(parse_state_field "$STATE_FILE" "current_phase")
CURRENT_STEP=$(parse_state_field "$STATE_FILE" "current_step")
WORKFLOW_CONFIG=$(parse_state_field "$STATE_FILE" "workflow_config")

if [[ ! -f "$WORKFLOW_CONFIG" ]]; then
  echo "Error: Config file not found: $WORKFLOW_CONFIG" >&2
  exit 1
fi

# Get next step in current phase
NEXT_STEP=$(get_next_step "$WORKFLOW_CONFIG" "$CURRENT_STEP")

# If phase end, advance to next phase
if [[ "$NEXT_STEP" == "PHASE_END" ]]; then
  NEXT_PHASE=$(get_next_phase "$WORKFLOW_CONFIG" "$CURRENT_PHASE")

  if [[ "$NEXT_PHASE" == "WORKFLOW_END" ]]; then
    echo "WORKFLOW_END"
    exit 0
  fi

  # Check phase dependencies
  DEPS=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .depends_on[]" "$WORKFLOW_CONFIG" 2>/dev/null || echo "")

  for dep in $DEPS; do
    if [[ -n "$dep" ]] && [[ "$dep" != "null" ]]; then
      # Verify dependent phase is complete
      # Note: In production, we'd check state file for phase completion
      :
    fi
  done

  # Check if phase has manual trigger
  PHASE_TRIGGER=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .trigger // \"auto\"" "$WORKFLOW_CONFIG")
  if [[ "$PHASE_TRIGGER" == "manual" ]] && [[ "$FORCE" != "--force" ]]; then
    echo "MANUAL_TRIGGER_${NEXT_PHASE}"
    exit 0
  fi

  # Get first step of next phase
  NEXT_STEP=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .steps[0].id" "$WORKFLOW_CONFIG")

  if [[ -z "$NEXT_STEP" ]] || [[ "$NEXT_STEP" == "null" ]]; then
    echo "Error: No steps in phase $NEXT_PHASE" >&2
    exit 1
  fi

  # Update state to new phase
  update_state_field "$STATE_FILE" "current_phase" "$NEXT_PHASE"
fi

# Check if next step is a checkpoint
if is_checkpoint "$WORKFLOW_CONFIG" "$NEXT_STEP"; then
  echo "CHECKPOINT_${NEXT_STEP}"
else
  echo "$NEXT_STEP"
fi

# Update state
update_state_field "$STATE_FILE" "current_step" "$NEXT_STEP"
update_state_numeric "$STATE_FILE" "current_iteration" "1"

# Update timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
update_state_field "$STATE_FILE" "last_updated" "$TIMESTAMP"

exit 0
