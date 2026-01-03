---
description: "Start a configurable workflow with multi-phase support and per-step looping"
argument-hint: "<workflow-name> [--feature <description>]"
allowed-tools: ["Bash", "Read", "Glob", "Write", "Task"]
---

# Start Workflow

Start a workflow from a template configuration.

## Arguments

- `<workflow-name>`: Name of the workflow template to use (required)
- `--feature <description>`: Feature description for variable substitution (optional)

## Available Workflows

Check available workflow templates:

```bash
ls ${CLAUDE_PLUGIN_ROOT}/templates/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/.yaml//'
```

Also check local workflows:

```bash
ls .claude/workflows/*.yaml 2>/dev/null | xargs -n1 basename | sed 's/.yaml//' || echo "(none)"
```

## Step 1: Parse Arguments

Extract the workflow name and feature description from $ARGUMENTS.

## Step 2: Validate Workflow Exists

Check if the workflow configuration exists:
1. First check `.claude/workflows/{name}.yaml`
2. Then check `${CLAUDE_PLUGIN_ROOT}/templates/{name}.yaml`

## Step 3: Initialize Workflow

Run the initialization script:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/init-workflow.sh" \
  --name "{workflow_name}" \
  --config "{config_path}" \
  --feature "{feature_description}"
```

This creates:
- State file at `.claude/workflows/{name}.state.md`
- Sets initial phase and step
- Tracks iteration count

## Step 4: Display Workflow Banner

**IMPORTANT**: Before executing the first step, display a visual workflow status banner:

```bash
source "${CLAUDE_PLUGIN_ROOT}/scripts/terminal-ui.sh"
print_workflow_status "{workflow_name}" "{phase}" "{step}" "{step_name}" "1" "{max_iterations}" "1"
```

This makes it clear to the user that a workflow is active and being orchestrated.

## Step 5: Execute First Step

Read the state file to get the first step, then execute its prompt.

**CRITICAL UI REQUIREMENT**: At each step transition, you MUST display workflow status:

1. **Before each step**: Show the workflow status banner with current phase/step
2. **After each step**: Show step completion with iterations used
3. **At checkpoints**: Show checkpoint banner and wait for input
4. **At phase transitions**: Show phase completion banner

Use the terminal-ui.sh functions:
- `print_workflow_status` - Show current step being executed
- `print_step_complete` - Show step completed
- `print_phase_complete` - Show phase completed
- `print_checkpoint` - Show waiting for user input
- `print_advancing` - Show moving to next step

The workflow is now active. The stop hook will:
1. Intercept exit attempts
2. Check for completion signals (`<promise>STEP_COMPLETE</promise>`)
3. Advance to next step when complete
4. Re-inject step prompt if not complete
5. Enforce checkpoints requiring human response

## Completion Signals

When completing a step, output:
```
<promise>STEP_COMPLETE</promise>
```

When the entire workflow is complete, output:
```
<promise>WORKFLOW_COMPLETE</promise>
```

## Example Usage

```bash
# Start the OpenSpec proposal workflow
/workflow openspec-proposal --feature "Add user authentication with OAuth"

# Start a custom workflow
/workflow my-custom-workflow --feature "Implement caching layer"
```

## Workflow Control

- **View status**: `/workflow-status`
- **Cancel workflow**: `/workflow-cancel`
- **Resume paused workflow**: `/workflow-resume`
