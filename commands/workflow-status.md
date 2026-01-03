---
description: "Show current workflow status"
allowed-tools: ["Bash", "Read"]
---

# Workflow Status

Display the current status of all workflows.

## Step 1: Find Workflow State Files

```bash
STATE_DIR=".claude/workflows"
if [[ -d "$STATE_DIR" ]]; then
  ls "$STATE_DIR"/*.state.md 2>/dev/null || echo "No workflow state files found"
else
  echo "No workflows directory found"
fi
```

## Step 2: Display Status for Each Workflow

For each state file found, display:

### Status Summary

| Field | Value |
|-------|-------|
| **Workflow** | {workflow_name} |
| **Status** | {status} (running/paused/completed/failed) |
| **Phase** | {current_phase} - {phase_name} |
| **Step** | {current_step} - {step_name} |
| **Iteration** | {current_iteration} / {max_iterations} |
| **Total Iterations** | {total_iterations} |
| **Started** | {started_at} |
| **Last Updated** | {last_updated} |

### Variables

| Variable | Value |
|----------|-------|
| feature_description | {value} |
| change_id | {value} |
| output_dir | {value} |

### Checkpoint Responses

If any checkpoints have been completed, show their responses.

### Errors/Warnings

If any errors or warnings have been recorded, display them.

## Step 3: Show Active Workflow Details

If a workflow is currently running, show the current step's details:

- Step type (agents, command, checkpoint, etc.)
- Completion criteria
- Max iterations for this step
- Progress toward completion

## Example Output

```
=== Workflow Status ===

Workflow: openspec-proposal
Status: RUNNING
Started: 2026-01-02T10:30:00Z
Last Updated: 2026-01-02T11:45:00Z

Phase: 0b - Technical Research
Step: 0b.2 - Launch Technical Agents
Iteration: 3/3

Variables:
  feature_description: "Add shop item purchase"
  change_id: "add-shop-purchase"
  output_dir: "openspec/changes/add-shop-purchase"

Checkpoints Completed:
  0a.4: "PRD looks good, proceed"
  0a.7: "PRD approved"

No errors or warnings.

---
To cancel: /workflow-cancel
To resume (if paused): /workflow-resume
```
