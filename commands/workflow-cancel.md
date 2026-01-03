---
description: "Cancel active workflow"
allowed-tools: ["Bash", "Read"]
---

# Cancel Workflow

Cancel any active workflows and clean up state files.

## Step 1: Find Active Workflows

```bash
STATE_DIR=".claude/workflows"
FOUND=false

if [[ -d "$STATE_DIR" ]]; then
  for file in "$STATE_DIR"/*.state.md; do
    if [[ -f "$file" ]]; then
      STATUS=$(sed -n '/^---$/,/^---$/{ /^status:/{ s/status: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
      if [[ "$STATUS" == "running" ]] || [[ "$STATUS" == "paused" ]]; then
        WORKFLOW_NAME=$(sed -n '/^---$/,/^---$/{ /^workflow_name:/{ s/workflow_name: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
        CURRENT_PHASE=$(sed -n '/^---$/,/^---$/{ /^current_phase:/{ s/current_phase: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
        CURRENT_STEP=$(sed -n '/^---$/,/^---$/{ /^current_step:/{ s/current_step: *"*\([^"]*\)"*/\1/p; q; }}' "$file")
        CURRENT_ITERATION=$(sed -n '/^---$/,/^---$/{ /^current_iteration:/{ s/current_iteration: *\([^"]*\)/\1/p; q; }}' "$file")

        echo "Found active workflow: $WORKFLOW_NAME"
        echo "  Status: $STATUS"
        echo "  Phase: $CURRENT_PHASE"
        echo "  Step: $CURRENT_STEP"
        echo "  Iteration: $CURRENT_ITERATION"
        echo ""

        FOUND=true
      fi
    fi
  done
fi

if [[ "$FOUND" == "false" ]]; then
  echo "No active workflows to cancel"
fi
```

## Step 2: Confirm Cancellation

If active workflows are found, ask for confirmation before cancelling.

## Step 3: Cancel Workflow

For each confirmed workflow to cancel:

1. Update status to "cancelled" in state file
2. Record cancellation timestamp
3. Optionally remove state file

```bash
# Update status to cancelled
sed -i 's/^status:.*/status: "cancelled"/' "$STATE_FILE"

# Or remove state file entirely
rm "$STATE_FILE"
```

## Step 4: Confirm Cancellation

```
Workflow cancelled: {workflow_name}
  Was at: Phase {phase} / Step {step} / Iteration {iteration}
  State file: {state_file}

The stop hook will no longer intercept exit attempts.
```

## Notes

- Cancelling a workflow does NOT undo any changes made to files
- Output files created during the workflow are preserved
- To resume work later, you'll need to start a new workflow
- Consider saving your progress before cancelling
