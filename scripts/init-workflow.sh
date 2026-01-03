#!/bin/bash
# Workflow Orchestrator - Initialize Workflow
# Creates state file and sets up workflow for execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"

# Source terminal UI helpers
source "${PLUGIN_ROOT}/scripts/terminal-ui.sh"

# Default values
WORKFLOW_NAME=""
CONFIG_PATH=""
FEATURE_DESCRIPTION=""
STATE_DIR=".claude/workflows"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --name)
      WORKFLOW_NAME="$2"
      shift 2
      ;;
    --config)
      CONFIG_PATH="$2"
      shift 2
      ;;
    --feature)
      FEATURE_DESCRIPTION="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: init-workflow.sh --name <workflow-name> [--config <path>] [--feature <description>]"
      echo ""
      echo "Options:"
      echo "  --name      Workflow name (required)"
      echo "  --config    Path to workflow.yaml (optional, uses template if not provided)"
      echo "  --feature   Feature description (optional, can be set later)"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$WORKFLOW_NAME" ]]; then
  echo "Error: --name is required"
  exit 1
fi

# Find config file
if [[ -z "$CONFIG_PATH" ]]; then
  # Check for local config
  if [[ -f ".claude/workflows/${WORKFLOW_NAME}.yaml" ]]; then
    CONFIG_PATH=".claude/workflows/${WORKFLOW_NAME}.yaml"
  elif [[ -f "${PLUGIN_ROOT}/templates/${WORKFLOW_NAME}.yaml" ]]; then
    CONFIG_PATH="${PLUGIN_ROOT}/templates/${WORKFLOW_NAME}.yaml"
  else
    echo "Error: Workflow config not found: ${WORKFLOW_NAME}"
    echo "Searched:"
    echo "  - .claude/workflows/${WORKFLOW_NAME}.yaml"
    echo "  - ${PLUGIN_ROOT}/templates/${WORKFLOW_NAME}.yaml"
    echo ""
    echo "Available templates:"
    ls "${PLUGIN_ROOT}/templates/"*.yaml 2>/dev/null | xargs -n1 basename | sed 's/.yaml//' || echo "  (none)"
    exit 1
  fi
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "Error: Config file not found: $CONFIG_PATH"
  exit 1
fi

# Check for yq (YAML parser)
if ! command -v yq &> /dev/null; then
  echo "Error: yq is required but not installed"
  echo "Install with: brew install yq"
  exit 1
fi

# Parse workflow metadata
WORKFLOW_VERSION=$(yq '.metadata.version // "1.0.0"' "$CONFIG_PATH")
WORKFLOW_DESC=$(yq '.metadata.description // ""' "$CONFIG_PATH")

# Get first phase and step
FIRST_PHASE=$(yq '.phases[0].id' "$CONFIG_PATH")
FIRST_STEP=$(yq '.phases[0].steps[0].id' "$CONFIG_PATH")

if [[ "$FIRST_PHASE" == "null" ]] || [[ -z "$FIRST_PHASE" ]]; then
  echo "Error: No phases defined in workflow config"
  exit 1
fi

# Generate change_id from feature description (kebab-case, verb-led)
if [[ -n "$FEATURE_DESCRIPTION" ]]; then
  # Convert to kebab-case: lowercase, replace spaces with hyphens, remove special chars
  CHANGE_ID=$(echo "$FEATURE_DESCRIPTION" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g' | sed 's/ /-/g' | cut -c1-50)

  # Ensure it starts with a verb (add prefix if needed)
  if ! echo "$CHANGE_ID" | grep -qE '^(add|fix|update|remove|create|implement|enable|disable|refactor|migrate|improve)'; then
    CHANGE_ID="add-${CHANGE_ID}"
  fi
else
  CHANGE_ID="${WORKFLOW_NAME}-$(date +%Y%m%d%H%M%S)"
fi

# Create state directory
mkdir -p "$STATE_DIR"

# Determine state file path
STATE_FILE_TEMPLATE=$(yq '.settings.state_file // ".claude/workflows/{name}.state.md"' "$CONFIG_PATH")
STATE_FILE=$(echo "$STATE_FILE_TEMPLATE" | sed "s/{name}/${WORKFLOW_NAME}/g" | sed "s/{change_id}/${CHANGE_ID}/g")

# Create state directory if needed
mkdir -p "$(dirname "$STATE_FILE")"

# Check if workflow already active
if [[ -f "$STATE_FILE" ]]; then
  EXISTING_STATUS=$(sed -n '/^---$/,/^---$/{ /^status:/{ s/status: *"*\([^"]*\)"*/\1/p; q; }}' "$STATE_FILE")
  if [[ "$EXISTING_STATUS" == "running" ]]; then
    echo "Error: Workflow already running: $WORKFLOW_NAME"
    echo "State file: $STATE_FILE"
    echo ""
    echo "To cancel: /workflow cancel"
    echo "To resume: /workflow resume"
    exit 1
  fi
fi

# Get output directory template
OUTPUT_DIR_TEMPLATE=$(yq '.settings.output_dir // "openspec/changes/{change_id}"' "$CONFIG_PATH")
OUTPUT_DIR=$(echo "$OUTPUT_DIR_TEMPLATE" | sed "s/{change_id}/${CHANGE_ID}/g")

# Get all variables with defaults
VARIABLES=$(yq '.variables // {}' "$CONFIG_PATH")

# Get max iterations
MAX_GLOBAL_ITERATIONS=$(yq '.settings.max_global_iterations // 200' "$CONFIG_PATH")
DEFAULT_MAX_STEP_ITERATIONS=$(yq '.settings.default_max_step_iterations // 10' "$CONFIG_PATH")

# Create state file
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

cat > "$STATE_FILE" << EOF
---
workflow_name: "${WORKFLOW_NAME}"
workflow_version: "${WORKFLOW_VERSION}"
workflow_config: "${CONFIG_PATH}"

# Execution State
status: "running"
started_at: "${TIMESTAMP}"
last_updated: "${TIMESTAMP}"

# Current Position
current_phase: "${FIRST_PHASE}"
current_step: "${FIRST_STEP}"
current_iteration: 1

# Global Limits
max_global_iterations: ${MAX_GLOBAL_ITERATIONS}
default_max_step_iterations: ${DEFAULT_MAX_STEP_ITERATIONS}
total_iterations: 0

# Phase Tracking
phases:
  "${FIRST_PHASE}":
    status: "running"
    started_at: "${TIMESTAMP}"
    steps_completed: 0
    total_iterations: 0

# Step Tracking
steps:
  "${FIRST_STEP}":
    status: "running"
    iterations: 1
    started_at: "${TIMESTAMP}"

# Human Responses
checkpoints: {}

# Variables
variables:
  feature_description: "${FEATURE_DESCRIPTION}"
  change_id: "${CHANGE_ID}"
  output_dir: "${OUTPUT_DIR}"
  question_count: 10

# Error Tracking
errors: []
warnings: []
---

# Workflow: ${WORKFLOW_NAME}

## Status

**Status**: Running
**Phase**: ${FIRST_PHASE}
**Step**: ${FIRST_STEP}
**Started**: ${TIMESTAMP}

## Feature

${FEATURE_DESCRIPTION:-"(No feature description provided)"}

## Progress

[Progress will be updated as workflow executes]

## Completion Signals

When current step completes: \`<promise>STEP_COMPLETE</promise>\`
When workflow completes: \`<promise>WORKFLOW_COMPLETE</promise>\`
EOF

# Display initialization banner
print_header "WORKFLOW INITIALIZED"
print_success "Workflow initialized successfully!"
ui_print ""
ui_print "  ${WHITE}Name:${NC}      ${YELLOW}${WORKFLOW_NAME}${NC}"
ui_print "  ${WHITE}Config:${NC}    ${GRAY}${CONFIG_PATH}${NC}"
ui_print "  ${WHITE}State:${NC}     ${GRAY}${STATE_FILE}${NC}"
ui_print "  ${WHITE}Change ID:${NC} ${CYAN}${CHANGE_ID}${NC}"
ui_print "  ${WHITE}Output:${NC}    ${GRAY}${OUTPUT_DIR}${NC}"
ui_print ""
ui_print "  ${WHITE}Phase:${NC}     ${BLUE}${FIRST_PHASE}${NC}"
ui_print "  ${WHITE}Step:${NC}      ${GREEN}${FIRST_STEP}${NC}"
ui_print ""
print_info "The workflow is now active. The stop hook will manage iteration."
