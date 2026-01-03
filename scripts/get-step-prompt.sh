#!/bin/bash
# Workflow Orchestrator - Get Step Prompt
# Retrieves and processes the prompt for a workflow step
#
# Usage: get-step-prompt.sh <state_file> <step_id>
#
# Outputs the prompt with variables substituted

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source parsing utilities
source "${SCRIPT_DIR}/parse-config.sh"

# Arguments
STATE_FILE="${1:-}"
STEP_ID="${2:-}"

if [[ -z "$STATE_FILE" ]] || [[ -z "$STEP_ID" ]]; then
  echo "Usage: get-step-prompt.sh <state_file> <step_id>" >&2
  exit 1
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: State file not found: $STATE_FILE" >&2
  exit 1
fi

# Get config path
WORKFLOW_CONFIG=$(parse_state_field "$STATE_FILE" "workflow_config")

if [[ ! -f "$WORKFLOW_CONFIG" ]]; then
  echo "Error: Config file not found: $WORKFLOW_CONFIG" >&2
  exit 1
fi

# Get step prompt
PROMPT=$(get_step_prompt "$WORKFLOW_CONFIG" "$STEP_ID")

if [[ -z "$PROMPT" ]] || [[ "$PROMPT" == "null" ]]; then
  # No prompt defined - use step name as default
  STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$STEP_ID" "name")
  STEP_TYPE=$(get_step_field "$WORKFLOW_CONFIG" "$STEP_ID" "type")

  PROMPT="Execute step: $STEP_NAME (type: $STEP_TYPE)"

  # Add completion reminder
  PROMPT+=$'\n\nWhen this step is complete, output: <promise>STEP_COMPLETE</promise>'
fi

# Get variables from state
FEATURE_DESC=$(parse_state_field "$STATE_FILE" "feature_description")
CHANGE_ID=$(parse_state_field "$STATE_FILE" "change_id")
OUTPUT_DIR=$(parse_state_field "$STATE_FILE" "output_dir")
QUESTION_COUNT=$(parse_state_field "$STATE_FILE" "question_count")

# Substitute variables
PROMPT="${PROMPT//\{feature_description\}/$FEATURE_DESC}"
PROMPT="${PROMPT//\{change_id\}/$CHANGE_ID}"
PROMPT="${PROMPT//\{output_dir\}/$OUTPUT_DIR}"
PROMPT="${PROMPT//\{question_count\}/$QUESTION_COUNT}"

# Get step-specific metadata
STEP_NAME=$(get_step_field "$WORKFLOW_CONFIG" "$STEP_ID" "name")
STEP_TYPE=$(get_step_field "$WORKFLOW_CONFIG" "$STEP_ID" "type")
MAX_ITERATIONS=$(get_max_iterations "$WORKFLOW_CONFIG" "$STEP_ID" "10")

# Get current iteration
CURRENT_ITERATION=$(parse_state_field "$STATE_FILE" "current_iteration")

# Add context header
HEADER="## Step: ${STEP_ID} - ${STEP_NAME}
**Type**: ${STEP_TYPE}
**Iteration**: ${CURRENT_ITERATION}/${MAX_ITERATIONS}

---

"

# Combine header and prompt
echo "${HEADER}${PROMPT}"

exit 0
