#!/bin/bash
# Workflow Orchestrator - Config Parser Utilities
# Provides functions for parsing workflow.yaml configurations

set -euo pipefail

# Check for yq dependency
check_yq() {
  if ! command -v yq &> /dev/null; then
    echo "Error: yq is required but not installed" >&2
    echo "Install with: brew install yq" >&2
    return 1
  fi
}

# Get phase by ID
# Usage: get_phase <config_path> <phase_id>
get_phase() {
  local config="$1"
  local phase_id="$2"
  yq ".phases[] | select(.id == \"$phase_id\")" "$config"
}

# Get step by ID
# Usage: get_step <config_path> <step_id>
get_step() {
  local config="$1"
  local step_id="$2"
  yq ".phases[].steps[] | select(.id == \"$step_id\")" "$config"
}

# Get step field
# Usage: get_step_field <config_path> <step_id> <field>
get_step_field() {
  local config="$1"
  local step_id="$2"
  local field="$3"
  yq ".phases[].steps[] | select(.id == \"$step_id\") | .$field" "$config"
}

# Get all steps in a phase
# Usage: get_phase_steps <config_path> <phase_id>
get_phase_steps() {
  local config="$1"
  local phase_id="$2"
  yq ".phases[] | select(.id == \"$phase_id\") | .steps[].id" "$config"
}

# Get next step in phase after given step
# Usage: get_next_step <config_path> <current_step_id>
# Returns: next step ID or "PHASE_END" if no more steps
get_next_step() {
  local config="$1"
  local current_step="$2"

  # Get phase containing this step
  local phase_id
  phase_id=$(yq ".phases[] | select(.steps[].id == \"$current_step\") | .id" "$config")

  # Get all steps in phase
  local steps
  steps=$(yq ".phases[] | select(.id == \"$phase_id\") | .steps[].id" "$config")

  # Find next step
  local found_current=false
  while IFS= read -r step; do
    if [[ "$found_current" == "true" ]]; then
      echo "$step"
      return 0
    fi
    if [[ "$step" == "$current_step" ]]; then
      found_current=true
    fi
  done <<< "$steps"

  echo "PHASE_END"
}

# Get next phase after given phase
# Usage: get_next_phase <config_path> <current_phase_id>
# Returns: next phase ID or "WORKFLOW_END" if no more phases
get_next_phase() {
  local config="$1"
  local current_phase="$2"

  # Find phase that depends on current phase
  local next_phase
  next_phase=$(yq ".phases[] | select(.depends_on[] == \"$current_phase\") | .id" "$config" | head -1)

  if [[ -z "$next_phase" ]] || [[ "$next_phase" == "null" ]]; then
    # No dependent phase - try sequential
    local phases
    phases=$(yq ".phases[].id" "$config")

    local found_current=false
    while IFS= read -r phase; do
      if [[ "$found_current" == "true" ]]; then
        echo "$phase"
        return 0
      fi
      if [[ "$phase" == "$current_phase" ]]; then
        found_current=true
      fi
    done <<< "$phases"

    echo "WORKFLOW_END"
  else
    echo "$next_phase"
  fi
}

# Check if step is a checkpoint
# Usage: is_checkpoint <config_path> <step_id>
is_checkpoint() {
  local config="$1"
  local step_id="$2"
  local step_type
  step_type=$(get_step_field "$config" "$step_id" "type")
  [[ "$step_type" == "checkpoint" ]]
}

# Check if step is a stop gate
# Usage: is_stop_gate <config_path> <step_id>
is_stop_gate() {
  local config="$1"
  local step_id="$2"
  local stop_gate
  stop_gate=$(get_step_field "$config" "$step_id" "stop_gate")
  [[ "$stop_gate" == "true" ]]
}

# Get max iterations for step
# Usage: get_max_iterations <config_path> <step_id> <default>
get_max_iterations() {
  local config="$1"
  local step_id="$2"
  local default="${3:-10}"
  local max
  max=$(get_step_field "$config" "$step_id" "max_iterations")
  if [[ "$max" == "null" ]] || [[ -z "$max" ]]; then
    echo "$default"
  else
    echo "$max"
  fi
}

# Get agents for step
# Usage: get_step_agents <config_path> <step_id>
get_step_agents() {
  local config="$1"
  local step_id="$2"
  yq ".phases[].steps[] | select(.id == \"$step_id\") | .agents[]" "$config"
}

# Get step prompt
# Usage: get_step_prompt <config_path> <step_id>
get_step_prompt() {
  local config="$1"
  local step_id="$2"
  yq ".phases[].steps[] | select(.id == \"$step_id\") | .prompt // \"\"" "$config"
}

# Substitute variables in string
# Usage: substitute_vars <string> <var1=value1> <var2=value2> ...
substitute_vars() {
  local str="$1"
  shift

  for var in "$@"; do
    local name="${var%%=*}"
    local value="${var#*=}"
    str="${str//\{$name\}/$value}"
  done

  echo "$str"
}

# Parse state file frontmatter field
# Usage: parse_state_field <state_file> <field>
parse_state_field() {
  local file="$1"
  local key="$2"
  sed -n '/^---$/,/^---$/{ /^'"$key"':/{ s/'"$key"': *"*\([^"]*\)"*/\1/p; q; }}' "$file"
}

# Update state file field
# Usage: update_state_field <state_file> <field> <value>
update_state_field() {
  local file="$1"
  local key="$2"
  local value="$3"

  # Create temp file and replace atomically
  local temp_file="${file}.tmp.$$"
  sed "s/^${key}: .*/${key}: \"${value}\"/" "$file" > "$temp_file"
  mv "$temp_file" "$file"
}

# Update numeric state file field (no quotes)
# Usage: update_state_numeric <state_file> <field> <value>
update_state_numeric() {
  local file="$1"
  local key="$2"
  local value="$3"

  local temp_file="${file}.tmp.$$"
  sed "s/^${key}: .*/${key}: ${value}/" "$file" > "$temp_file"
  mv "$temp_file" "$file"
}

# Export functions if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  export -f check_yq get_phase get_step get_step_field get_phase_steps
  export -f get_next_step get_next_phase is_checkpoint is_stop_gate
  export -f get_max_iterations get_step_agents get_step_prompt
  export -f substitute_vars parse_state_field update_state_field update_state_numeric
fi
