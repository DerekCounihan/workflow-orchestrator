---
description: "Resume a paused workflow"
allowed-tools: ["Bash", "Read", "Write", "Task"]
---

# Resume Workflow

Resume a paused workflow from where it left off.

## Step 1: Find Paused Workflows

```bash
STATE_DIR=".claude/workflows"
PAUSED_WORKFLOWS=()

if [[ -d "$STATE_DIR" ]]; then
  for file in "$STATE_DIR"/*.state.md; do
    if [[ -f "$file" ]]; then
      STATUS=$(sed -n '/^---$/,/^---$/{ /^status:/{ s/status: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
      if [[ "$STATUS" == "paused" ]]; then
        WORKFLOW_NAME=$(sed -n '/^---$/,/^---$/{ /^workflow_name:/{ s/workflow_name: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
        CURRENT_PHASE=$(sed -n '/^---$/,/^---$/{ /^current_phase:/{ s/current_phase: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
        CURRENT_STEP=$(sed -n '/^---$/,/^---$/{ /^current_step:/{ s/current_step: *"*\([^"]*\)"*/\1/p; q; }}' "$file")

        echo "Found paused workflow: $WORKFLOW_NAME"
        echo "  Phase: $CURRENT_PHASE"
        echo "  Step: $CURRENT_STEP"
        echo "  State file: $file"
        echo ""

        PAUSED_WORKFLOWS+=("$file")
      fi
    fi
  done
fi

if [[ ${#PAUSED_WORKFLOWS[@]} -eq 0 ]]; then
  echo "No paused workflows found"
fi
```

## Step 2: Select Workflow to Resume

If multiple paused workflows exist, let the user select which one to resume.

## Step 3: Resume Workflow

Update the workflow state to "running":

```bash
STATE_FILE="{selected_workflow_state_file}"

# Update status
sed -i 's/^status:.*/status: "running"/' "$STATE_FILE"

# Update timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i "s/^last_updated:.*/last_updated: \"$TIMESTAMP\"/" "$STATE_FILE"

echo "Workflow resumed: $WORKFLOW_NAME"
```

## Step 4: Get Current Step Prompt

Read the current step from the state file and get its prompt:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/get-step-prompt.sh" "$STATE_FILE" "$CURRENT_STEP"
```

## Step 5: Execute Step

Execute the step prompt. The stop hook will now manage iteration and advancement again.

## Checkpoint Handling

If the workflow was paused at a checkpoint:

1. Display the checkpoint prompt again
2. Wait for human response
3. Record the response in state file
4. Advance to next step

## Manual Phase Triggers

If the workflow was paused because the next phase requires manual trigger:

1. Confirm the user wants to proceed
2. Force advance to the manually-triggered phase
3. Execute the first step of that phase

```bash
# Force advance to manual phase
"${CLAUDE_PLUGIN_ROOT}/scripts/advance-step.sh" "$STATE_FILE" --force
```

## Notes

- Resuming restores the exact state from where the workflow was paused
- All previous checkpoint responses are preserved
- Iteration count continues from where it left off
- No work is lost when resuming
