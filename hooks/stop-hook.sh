#!/bin/bash
# Workflow Orchestrator Stop Hook
# Manages per-step looping with phase/step advancement
#
# This hook:
# 1. Checks for active workflow state file
# 2. Parses current phase/step/iteration
# 3. Checks for completion signals (STEP_COMPLETE, WORKFLOW_COMPLETE)
# 4. Handles checkpoints (require human response)
# 5. Advances to next step/phase when complete
# 6. Re-injects step prompt to continue loop

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source parsing utilities
source "${PLUGIN_ROOT}/scripts/parse-config.sh"

# Source terminal UI helpers
source "${PLUGIN_ROOT}/scripts/terminal-ui.sh"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# State file location
STATE_DIR=".claude/workflows"
ACTIVE_STATE_FILE=""

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Find active workflow state file
find_active_workflow() {
  for file in "$STATE_DIR"/*.state.md; do
    if [[ -f "$file" ]]; then
      local status
      status=$(parse_state_field "$file" "status")
      if [[ "$status" == "running" ]]; then
        ACTIVE_STATE_FILE="$file"
        return 0
      fi
    fi
  done
  return 1
}

# Update state file timestamp
update_timestamp() {
  local file="$1"
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  update_state_field "$file" "last_updated" "$timestamp"
}

# Get variables from state file for substitution
get_state_variables() {
  local file="$1"
  local vars=""

  # Extract key variables
  vars+="feature_description=$(parse_state_field "$file" "feature_description") "
  vars+="change_id=$(parse_state_field "$file" "change_id") "
  vars+="output_dir=$(parse_state_field "$file" "output_dir") "

  echo "$vars"
}

# ============================================================================
# MAIN LOGIC
# ============================================================================

# Check if no active workflow
if ! find_active_workflow; then
  # No active workflow - allow normal exit
  exit 0
fi

# Parse current state
CURRENT_PHASE=$(parse_state_field "$ACTIVE_STATE_FILE" "current_phase")
CURRENT_STEP=$(parse_state_field "$ACTIVE_STATE_FILE" "current_step")
CURRENT_ITERATION=$(parse_state_field "$ACTIVE_STATE_FILE" "current_iteration")
WORKFLOW_CONFIG=$(parse_state_field "$ACTIVE_STATE_FILE" "workflow_config")
WORKFLOW_NAME=$(parse_state_field "$ACTIVE_STATE_FILE" "workflow_name")
TOTAL_ITERATIONS=$(parse_state_field "$ACTIVE_STATE_FILE" "total_iterations")
MAX_GLOBAL_ITERATIONS=$(parse_state_field "$ACTIVE_STATE_FILE" "max_global_iterations")
DEFAULT_MAX_STEP_ITERATIONS=$(parse_state_field "$ACTIVE_STATE_FILE" "default_max_step_iterations")

# Validate numeric fields
if [[ ! "$CURRENT_ITERATION" =~ ^[0-9]+$ ]]; then
  echo "State file corrupted: iteration is not a number" >&2
  update_state_field "$ACTIVE_STATE_FILE" "status" "failed"
  exit 0
fi

# Check global iteration limit
if [[ "$MAX_GLOBAL_ITERATIONS" =~ ^[0-9]+$ ]] && [[ $MAX_GLOBAL_ITERATIONS -gt 0 ]]; then
  if [[ $TOTAL_ITERATIONS -ge $MAX_GLOBAL_ITERATIONS ]]; then
    echo "Max global iterations ($MAX_GLOBAL_ITERATIONS) reached."
    update_state_field "$ACTIVE_STATE_FILE" "status" "completed"
    exit 0
  fi
fi

# Get step configuration
STEP_MAX_ITERATIONS=$(get_max_iterations "$WORKFLOW_CONFIG" "$CURRENT_STEP" "$DEFAULT_MAX_STEP_ITERATIONS")
STEP_TYPE=$(get_step_field "$WORKFLOW_CONFIG" "$CURRENT_STEP" "type")
IS_STOP_GATE=$(get_step_field "$WORKFLOW_CONFIG" "$CURRENT_STEP" "stop_gate")

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "Transcript file not found: $TRANSCRIPT_PATH" >&2
  exit 0
fi

# Read last assistant message from transcript
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "No assistant messages found in transcript" >&2
  exit 0
fi

LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null || echo "")

if [[ -z "$LAST_OUTPUT" ]]; then
  echo "Assistant message contained no text content" >&2
  exit 0
fi

# ============================================================================
# CHECK FOR COMPLETION SIGNALS
# ============================================================================

# Check for WORKFLOW_COMPLETE signal
WORKFLOW_COMPLETE=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(WORKFLOW_COMPLETE)<\/promise>.*/$1/s' 2>/dev/null || echo "")

if [[ "$WORKFLOW_COMPLETE" == "WORKFLOW_COMPLETE" ]]; then
  # Count completed phases
  PHASES_COUNT=$(yq '.phases | length' "$WORKFLOW_CONFIG" 2>/dev/null || echo "?")

  # Print workflow complete banner
  print_workflow_complete "$WORKFLOW_NAME" "$TOTAL_ITERATIONS" "$PHASES_COUNT"

  update_state_field "$ACTIVE_STATE_FILE" "status" "completed"
  update_timestamp "$ACTIVE_STATE_FILE"
  exit 0
fi

# Check for STEP_COMPLETE signal
STEP_COMPLETE=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(STEP_COMPLETE)<\/promise>.*/$1/s' 2>/dev/null || echo "")

if [[ "$STEP_COMPLETE" == "STEP_COMPLETE" ]]; then
  # Get step name for display
  CURRENT_STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$CURRENT_STEP" "name")

  # Print step complete banner
  print_step_complete "$CURRENT_STEP" "$CURRENT_STEP_NAME" "$CURRENT_ITERATION"

  # Get gate configuration for this step
  GATE_TYPE=$(get_step_field "$WORKFLOW_CONFIG" "$CURRENT_STEP" "gate_checks.type")

  # Default to workflow-level gate setting if step doesn't specify
  if [[ -z "$GATE_TYPE" ]] || [[ "$GATE_TYPE" == "null" ]]; then
    GATE_TYPE=$(yq '.settings.default_gate_checks // "none"' "$WORKFLOW_CONFIG" 2>/dev/null || echo "none")
  fi

  # Run gate checks if configured
  if [[ "$GATE_TYPE" != "none" ]] && [[ "$GATE_TYPE" != "skip" ]] && [[ -n "$GATE_TYPE" ]]; then
    print_gate_check_start "$GATE_TYPE"

    if ! "${PLUGIN_ROOT}/scripts/run-gate-checks.sh" "$ACTIVE_STATE_FILE" "$GATE_TYPE" "$CURRENT_STEP"; then
      # Gate check failed - block advancement and request fixes
      print_gate_check_fail

      GATE_FAILURE_MSG="Gate checks failed for step $CURRENT_STEP. Please fix the issues before proceeding.

The following checks failed:
- Run \`pnpm typecheck\` and \`pnpm lint\` to see the errors
- Fix the issues and then output <promise>STEP_COMPLETE</promise> to retry

Once all gate checks pass, the workflow will advance to the next step."

      jq -n \
        --arg prompt "$GATE_FAILURE_MSG" \
        --arg msg "Gate Check FAILED for step: $CURRENT_STEP - Fix issues to proceed" \
        '{
          "decision": "block",
          "reason": $prompt,
          "systemMessage": $msg
        }'
      exit 0
    fi

    print_gate_check_pass
  fi

  # Get next step
  NEXT_STEP=$(get_next_step "$WORKFLOW_CONFIG" "$CURRENT_STEP")

  if [[ "$NEXT_STEP" == "PHASE_END" ]]; then
    # Phase complete - get phase info for display
    CURRENT_PHASE_NAME=$(yq ".phases[] | select(.id == \"$CURRENT_PHASE\") | .name" "$WORKFLOW_CONFIG" 2>/dev/null || echo "$CURRENT_PHASE")
    STEPS_IN_PHASE=$(yq ".phases[] | select(.id == \"$CURRENT_PHASE\") | .steps | length" "$WORKFLOW_CONFIG" 2>/dev/null || echo "?")

    # Print phase complete banner
    print_phase_complete "$CURRENT_PHASE" "$CURRENT_PHASE_NAME" "$STEPS_IN_PHASE"

    # Advance to next phase
    NEXT_PHASE=$(get_next_phase "$WORKFLOW_CONFIG" "$CURRENT_PHASE")

    if [[ "$NEXT_PHASE" == "WORKFLOW_END" ]]; then
      PHASES_COUNT=$(yq '.phases | length' "$WORKFLOW_CONFIG" 2>/dev/null || echo "?")
      print_workflow_complete "$WORKFLOW_NAME" "$TOTAL_ITERATIONS" "$PHASES_COUNT"
      update_state_field "$ACTIVE_STATE_FILE" "status" "completed"
      update_timestamp "$ACTIVE_STATE_FILE"
      exit 0
    fi

    # Get next phase info
    NEXT_PHASE_NAME=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .name" "$WORKFLOW_CONFIG" 2>/dev/null || echo "$NEXT_PHASE")

    # Check if next phase has manual trigger
    PHASE_TRIGGER=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .trigger // \"auto\"" "$WORKFLOW_CONFIG")
    if [[ "$PHASE_TRIGGER" == "manual" ]]; then
      print_warning "Phase $NEXT_PHASE ($NEXT_PHASE_NAME) requires manual trigger. Pausing workflow."
      print_info "Use '/workflow resume' to continue."
      update_state_field "$ACTIVE_STATE_FILE" "status" "paused"
      update_timestamp "$ACTIVE_STATE_FILE"
      exit 0
    fi

    # Print phase transition
    print_phase_advancing "$CURRENT_PHASE" "$NEXT_PHASE" "$NEXT_PHASE_NAME"

    # Move to first step of next phase
    NEXT_STEP=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .steps[0].id" "$WORKFLOW_CONFIG")
    update_state_field "$ACTIVE_STATE_FILE" "current_phase" "$NEXT_PHASE"
  fi

  # Update state to new step
  update_state_field "$ACTIVE_STATE_FILE" "current_step" "$NEXT_STEP"
  update_state_numeric "$ACTIVE_STATE_FILE" "current_iteration" "1"
  update_timestamp "$ACTIVE_STATE_FILE"

  # Check if next step is a checkpoint
  if is_checkpoint "$WORKFLOW_CONFIG" "$NEXT_STEP"; then
    NEXT_STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$NEXT_STEP" "name")

    # Print checkpoint banner
    print_checkpoint "$NEXT_STEP" "$NEXT_STEP_NAME"

    CHECKPOINT_PROMPT=$(get_step_prompt "$WORKFLOW_CONFIG" "$NEXT_STEP")

    # Substitute variables
    VARS=$(get_state_variables "$ACTIVE_STATE_FILE")
    # shellcheck disable=SC2086
    CHECKPOINT_PROMPT=$(substitute_vars "$CHECKPOINT_PROMPT" $VARS)

    # Output checkpoint prompt and pause
    jq -n \
      --arg prompt "$CHECKPOINT_PROMPT" \
      --arg msg "Checkpoint: $NEXT_STEP - $NEXT_STEP_NAME - Awaiting response" \
      '{
        "decision": "block",
        "reason": $prompt,
        "systemMessage": $msg
      }'
    exit 0
  fi

  # Get next step's prompt
  NEXT_PROMPT=$(get_step_prompt "$WORKFLOW_CONFIG" "$NEXT_STEP")
  VARS=$(get_state_variables "$ACTIVE_STATE_FILE")
  # shellcheck disable=SC2086
  NEXT_PROMPT=$(substitute_vars "$NEXT_PROMPT" $VARS)

  # Get step metadata for system message
  NEXT_STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$NEXT_STEP" "name")
  STEP_MAX=$(get_max_iterations "$WORKFLOW_CONFIG" "$NEXT_STEP" "$DEFAULT_MAX_STEP_ITERATIONS")

  # Print advancing message
  print_advancing "$CURRENT_STEP" "$NEXT_STEP" "$NEXT_STEP_NAME"

  # Get current phase for status display
  DISPLAY_PHASE=$(parse_state_field "$ACTIVE_STATE_FILE" "current_phase")

  # Print workflow status banner
  print_workflow_status "$WORKFLOW_NAME" "$DISPLAY_PHASE" "$NEXT_STEP" "$NEXT_STEP_NAME" "1" "$STEP_MAX" "$TOTAL_ITERATIONS"

  jq -n \
    --arg prompt "$NEXT_PROMPT" \
    --arg msg "Step: $NEXT_STEP - $NEXT_STEP_NAME (iteration 1/$STEP_MAX)" \
    '{
      "decision": "block",
      "reason": $prompt,
      "systemMessage": $msg
    }'
  exit 0
fi

# ============================================================================
# STEP NOT COMPLETE - CHECK LIMITS
# ============================================================================

# Check step iteration limit
if [[ $CURRENT_ITERATION -ge $STEP_MAX_ITERATIONS ]]; then
  CURRENT_STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$CURRENT_STEP" "name")

  if [[ "$IS_STOP_GATE" == "true" ]]; then
    print_warning "Stop gate at step $CURRENT_STEP ($CURRENT_STEP_NAME)"
    print_warning "Max iterations ($STEP_MAX_ITERATIONS) reached - Human intervention required"
    print_info "Use '/workflow resume' to continue after addressing issues."

    update_state_field "$ACTIVE_STATE_FILE" "status" "paused"
    update_timestamp "$ACTIVE_STATE_FILE"

    exit 0
  else
    # Force advance to next step
    print_warning "Max iterations ($STEP_MAX_ITERATIONS) reached for step $CURRENT_STEP"
    print_info "Force advancing to next step..."

    NEXT_STEP=$(get_next_step "$WORKFLOW_CONFIG" "$CURRENT_STEP")

    if [[ "$NEXT_STEP" == "PHASE_END" ]]; then
      NEXT_PHASE=$(get_next_phase "$WORKFLOW_CONFIG" "$CURRENT_PHASE")

      if [[ "$NEXT_PHASE" == "WORKFLOW_END" ]]; then
        PHASES_COUNT=$(yq '.phases | length' "$WORKFLOW_CONFIG" 2>/dev/null || echo "?")
        print_workflow_complete "$WORKFLOW_NAME" "$TOTAL_ITERATIONS" "$PHASES_COUNT"
        update_state_field "$ACTIVE_STATE_FILE" "status" "completed"
        update_timestamp "$ACTIVE_STATE_FILE"
        exit 0
      fi

      NEXT_STEP=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .steps[0].id" "$WORKFLOW_CONFIG")
      NEXT_PHASE_NAME=$(yq ".phases[] | select(.id == \"$NEXT_PHASE\") | .name" "$WORKFLOW_CONFIG" 2>/dev/null || echo "$NEXT_PHASE")
      print_phase_advancing "$CURRENT_PHASE" "$NEXT_PHASE" "$NEXT_PHASE_NAME"
      update_state_field "$ACTIVE_STATE_FILE" "current_phase" "$NEXT_PHASE"
    fi

    update_state_field "$ACTIVE_STATE_FILE" "current_step" "$NEXT_STEP"
    update_state_numeric "$ACTIVE_STATE_FILE" "current_iteration" "1"
    update_timestamp "$ACTIVE_STATE_FILE"

    # Get next step prompt
    NEXT_PROMPT=$(get_step_prompt "$WORKFLOW_CONFIG" "$NEXT_STEP")
    VARS=$(get_state_variables "$ACTIVE_STATE_FILE")
    # shellcheck disable=SC2086
    NEXT_PROMPT=$(substitute_vars "$NEXT_PROMPT" $VARS)

    NEXT_STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$NEXT_STEP" "name")
    STEP_MAX=$(get_max_iterations "$WORKFLOW_CONFIG" "$NEXT_STEP" "$DEFAULT_MAX_STEP_ITERATIONS")

    # Print advancing message
    print_advancing "$CURRENT_STEP" "$NEXT_STEP" "$NEXT_STEP_NAME"

    # Print workflow status
    DISPLAY_PHASE=$(parse_state_field "$ACTIVE_STATE_FILE" "current_phase")
    print_workflow_status "$WORKFLOW_NAME" "$DISPLAY_PHASE" "$NEXT_STEP" "$NEXT_STEP_NAME" "1" "$STEP_MAX" "$TOTAL_ITERATIONS"

    jq -n \
      --arg prompt "$NEXT_PROMPT" \
      --arg msg "Step: $NEXT_STEP - $NEXT_STEP_NAME (iteration 1/$STEP_MAX) [Force advanced from $CURRENT_STEP]" \
      '{
        "decision": "block",
        "reason": $prompt,
        "systemMessage": $msg
      }'
    exit 0
  fi
fi

# ============================================================================
# CONTINUE SAME STEP WITH NEXT ITERATION
# ============================================================================

NEXT_ITERATION=$((CURRENT_ITERATION + 1))
NEW_TOTAL=$((TOTAL_ITERATIONS + 1))

update_state_numeric "$ACTIVE_STATE_FILE" "current_iteration" "$NEXT_ITERATION"
update_state_numeric "$ACTIVE_STATE_FILE" "total_iterations" "$NEW_TOTAL"
update_timestamp "$ACTIVE_STATE_FILE"

# Get step prompt
STEP_PROMPT=$(get_step_prompt "$WORKFLOW_CONFIG" "$CURRENT_STEP")
VARS=$(get_state_variables "$ACTIVE_STATE_FILE")
# shellcheck disable=SC2086
STEP_PROMPT=$(substitute_vars "$STEP_PROMPT" $VARS)

# Build system message
STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$CURRENT_STEP" "name")
SYSTEM_MSG="Step: $CURRENT_STEP - $STEP_NAME (iteration $NEXT_ITERATION/$STEP_MAX_ITERATIONS)"

# Print iteration status
print_iteration "$CURRENT_STEP" "$NEXT_ITERATION" "$STEP_MAX_ITERATIONS" "$NEW_TOTAL"

# Print workflow status banner for visibility
print_workflow_status "$WORKFLOW_NAME" "$CURRENT_PHASE" "$CURRENT_STEP" "$STEP_NAME" "$NEXT_ITERATION" "$STEP_MAX_ITERATIONS" "$NEW_TOTAL"

# Output JSON to block exit and continue step
jq -n \
  --arg prompt "$STEP_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
