# Workflow Configuration Schema

This document describes the YAML schema for defining workflows in the Workflow Orchestrator plugin.

## Top-Level Structure

```yaml
metadata:
  name: string          # Workflow identifier (required)
  version: string       # Semantic version (required)
  description: string   # Human-readable description

settings:
  max_global_iterations: number      # Total iteration limit across all steps
  default_max_step_iterations: number # Default per-step limit
  state_file: string                 # State file path pattern
  output_dir: string                 # Output directory pattern
  default_gate_checks: string        # Default gate type: "none", "typecheck", "lint", "typecheck-lint", "full-suite"

variables:
  key: value            # Default variable values

phases:
  - id: string          # Phase identifier (required)
    name: string        # Phase name (required)
    description: string # Phase description
    depends_on: [string] # Phase dependencies
    trigger: string     # "auto" (default) or "manual"
    steps: [Step]       # List of steps
```

## Phase Definition

```yaml
phases:
  - id: "0a"                              # Unique phase ID
    name: "Product Requirements"          # Human-readable name
    description: "Gather product reqs"    # Optional description
    depends_on: []                        # List of phase IDs that must complete first
    trigger: "auto"                       # "auto" or "manual"

    steps:
      - id: "0a.1"                        # Step definitions
        # ...
```

### Phase Fields

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | string | Yes | - | Unique identifier (e.g., "0a", "1", "2.5") |
| `name` | string | Yes | - | Human-readable name |
| `description` | string | No | "" | Detailed description |
| `depends_on` | [string] | No | [] | Phase IDs that must complete first |
| `trigger` | string | No | "auto" | "auto" or "manual" |
| `steps` | [Step] | Yes | - | List of step definitions |

## Step Definition

```yaml
steps:
  - id: "0a.1"                    # Unique step ID
    name: "Launch Agents"         # Human-readable name
    type: "agents"                # Step type
    # Type-specific fields...
    max_iterations: 3             # Max loop iterations
    completion_criteria:          # How to detect completion
      type: "agent_responses"
      min_agents: 2
```

### Step Fields (Common)

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `id` | string | Yes | - | Unique identifier (e.g., "0a.1", "1.2.3") |
| `name` | string | Yes | - | Human-readable name |
| `type` | string | Yes | - | Step type (see Step Types below) |
| `prompt` | string | No | - | Prompt template for the step |
| `max_iterations` | number | No | settings.default | Max loop iterations |
| `completion_criteria` | object | No | - | Completion detection config |
| `optional` | boolean | No | false | Skip if conditions not met |
| `gate_checks` | object | No | - | Gate validation config (see Gate Checks below) |

## Step Types

### 1. `agents` - Launch Sub-Agents

Execute one or more AI agents.

```yaml
- id: "0b.2"
  name: "Launch Technical Agents"
  type: "agents"
  parallel: true                    # Run agents in parallel (default: false)
  agents:
    - subagent_type: "codebase-pattern-analyzer"
      prompt: "Analyze patterns for: {feature_description}"
      tools: ["Glob", "Grep", "Read"]
    - subagent_type: "architecture-reviewer"
      prompt: "Review architecture..."
  agent_count: 3                    # Number of agents to run (for dynamic selection)
  agent_selection: "dynamic"        # "all" or "dynamic"
  agent_pool: [...]                 # Pool for dynamic selection
  max_findings_per_agent: 10        # Limit findings per agent
  completion_criteria:
    type: "agent_responses"
    min_agents: 2                   # Minimum agents that must respond
```

### 2. `command` - Execute Command/Prompt

Execute a shell command or Claude prompt.

```yaml
- id: "0a.1"
  name: "Create Folder"
  type: "command"
  command: "mkdir -p {output_dir}"  # Shell command (optional)
  prompt: |                          # Claude prompt (optional)
    Create the output directory at {output_dir}
    When done, output: <promise>STEP_COMPLETE</promise>
  completion_criteria:
    type: "file_exists"
    path: "{output_dir}"
```

### 3. `consolidate` - Merge Agent Outputs

Consolidate outputs from previous agent steps.

```yaml
- id: "0a.3"
  name: "Create PRD"
  type: "consolidate"
  source_steps: ["0a.2"]            # Steps to consolidate from
  template: "templates/prd.md"      # Optional template file
  output: "{output_dir}/prd.md"     # Output file path
  consolidation_rules:
    deduplication: true             # Remove duplicate suggestions
    conflict_resolution: "priority" # "priority", "user_choice", "first_wins"
  prompt: |
    Consolidate the outputs into a PRD document...
  completion_criteria:
    type: "file_exists"
    path: "{output_dir}/prd.md"
```

### 4. `checkpoint` - Human Intervention

Pause for human input/approval.

```yaml
- id: "0a.7"
  name: "Get Final Approval"
  type: "checkpoint"
  gate: "approval"                  # "approval", "questions", "confirmation"
  stop_gate: true                   # Cannot proceed without response
  prompt: |
    ## Final PRD Ready for Approval
    Please respond: "Approved" or "Changes needed: [describe]"
  required_response: true           # Must have response (default: true)
  required_keywords: ["approved", "lgtm"]  # Keywords that signal approval
  optional: false                   # Optional checkpoint
  default_response: ""              # Default if optional and no response
  collect_answers: true             # Store response in state
  timeout_action: "pause"           # "pause", "skip", "fail"
  on_approved: "goto:next"          # Action on approval
  on_rejected: "goto:0a.4"          # Action on rejection
```

### 5. `conditional` - Branch Logic

Branch based on conditions.

```yaml
- id: "0a.6"
  name: "Check Tech Steer"
  type: "conditional"
  condition: "checkpoint_0a.5_response != 'no changes needed'"
  then_steps:                       # Steps to execute if true
    - id: "0a.6.1"
      name: "Apply Changes"
      type: "command"
      # ...
  then_step: "0a.6.1"               # Or single step ID
  else_step: "0a.7"                 # Step to jump to if false
```

### 6. `skill` - Invoke Claude Skill

Execute a registered Claude Code skill.

```yaml
- id: "1.7.1"
  name: "Run Validate Spec"
  type: "skill"
  skill: "validate-spec"            # Skill name
  args: "{change_id}"               # Arguments to pass
  prompt: |
    Run the validate-spec skill...
```

### 7. `task_runner` - Execute Task List

Execute tasks from a markdown file.

```yaml
- id: "2.1"
  name: "Execute Tasks"
  type: "task_runner"
  task_file: "{output_dir}/tasks.md"
  incremental_review: true
  review_triggers:
    - pattern: "apps/api/"
      agents: ["architecture-reviewer", "security-reviewer"]
    - pattern: "*.tsx"
      agents: ["performance-reviewer", "accessibility-reviewer"]
```

## Completion Criteria

### `agent_responses` - Agent Response Count

```yaml
completion_criteria:
  type: "agent_responses"
  min_agents: 2                     # Minimum agents that must respond
```

### `file_exists` - File Existence Check

```yaml
completion_criteria:
  type: "file_exists"
  path: "{output_dir}/prd.md"       # Single path
  paths: ["{output_dir}/a.md", "{output_dir}/b.md"]  # Multiple paths
```

### `output_contains` - Output Pattern Match

```yaml
completion_criteria:
  type: "output_contains"
  pattern: "^\\d+\\."               # Regex pattern
  min_count: 10                     # Minimum matches
```

### `command_success` - Command Exit Code

```yaml
completion_criteria:
  type: "command_success"
  command: "openspec validate {change_id} --strict"
```

### `has_output` - Any Output

```yaml
completion_criteria:
  type: "has_output"                # Just needs to produce output
```

### `no_issues` - No Issues Found

```yaml
completion_criteria:
  type: "no_issues"                 # Agents reported no issues
```

## Gate Checks

Gate checks are validation steps that run automatically after a step completes, before advancing to the next step. If gate checks fail, the workflow blocks until issues are fixed.

### Configuration

Gate checks can be configured at two levels:

1. **Workflow-level default** (in `settings`):
```yaml
settings:
  default_gate_checks: "typecheck-lint"  # Applies to all steps
```

2. **Step-level override**:
```yaml
steps:
  - id: "2.1"
    name: "Implement Feature"
    type: "task_runner"
    gate_checks:
      type: "typecheck-lint"        # Override for this step
      on_failure: "block"           # "block" (default), "warn", "skip"
```

### Gate Types

| Type | Description | Commands |
|------|-------------|----------|
| `none` | No gate checks (default) | - |
| `skip` | Explicitly skip gates for this step | - |
| `typecheck` | TypeScript type checking only | `pnpm typecheck` |
| `lint` | Biome linting only | `pnpm lint` |
| `typecheck-lint` | Both typecheck and lint | `pnpm typecheck && pnpm lint` |
| `full-suite` | Typecheck, lint, and tests | `pnpm typecheck && pnpm lint && pnpm test` |
| `custom` | Custom commands | Specified in `commands` array |

### Custom Gate Checks

```yaml
gate_checks:
  type: "custom"
  commands:
    - "pnpm typecheck"
    - "pnpm lint"
    - "pnpm test:unit"
  on_failure: "block"
```

### Gate Check Behavior

1. **On Success**: Workflow advances to the next step normally
2. **On Failure**:
   - `block` (default): Stops advancement, prompts for fixes
   - `warn`: Logs warning but continues to next step
   - `skip`: Skips gate checks entirely

### Example: Implementation Phase with Gates

```yaml
phases:
  - id: "2"
    name: "Implementation"
    steps:
      - id: "2.1"
        name: "Execute Tasks"
        type: "task_runner"
        task_file: "{output_dir}/tasks.md"
        gate_checks:
          type: "typecheck-lint"    # Run after each task completion

      - id: "2.2"
        name: "Final Validation"
        type: "command"
        gate_checks:
          type: "full-suite"        # Full validation before completion
```

### Skipping Gates for Specific Steps

Use `type: "skip"` to bypass gates for documentation or research steps:

```yaml
steps:
  - id: "0a.3"
    name: "Create PRD"
    type: "consolidate"
    gate_checks:
      type: "skip"                  # No code changes, skip gates
```

## Variables

Variables can be used in prompts and paths with `{variable_name}` syntax.

### Built-in Variables

| Variable | Description |
|----------|-------------|
| `{feature_description}` | User-provided feature description |
| `{change_id}` | Generated change identifier |
| `{output_dir}` | Output directory path |
| `{question_count}` | Number of questions to generate |

### Checkpoint Variables

| Variable | Description |
|----------|-------------|
| `{checkpoint_X.X_response}` | Response from checkpoint step X.X |

### Custom Variables

Define in the `variables` section:

```yaml
variables:
  my_var: "default_value"
  another_var: 10
```

## State File Format

The state file uses Markdown with YAML frontmatter:

```yaml
---
workflow_name: "openspec-proposal"
workflow_version: "1.0.0"
workflow_config: ".claude/workflows/openspec.yaml"

status: "running"                   # running, paused, completed, failed, cancelled
started_at: "2026-01-02T10:30:00Z"
last_updated: "2026-01-02T11:45:00Z"

current_phase: "0b"
current_step: "0b.2"
current_iteration: 3

max_global_iterations: 200
default_max_step_iterations: 10
total_iterations: 45

phases:
  "0a":
    status: "completed"
    started_at: "..."
    completed_at: "..."
    steps_completed: 7
    total_iterations: 12

steps:
  "0a.1":
    status: "completed"
    iterations: 1
    completed_at: "..."

checkpoints:
  "0a.4":
    response: "PRD looks good"
    responded_at: "..."
  "0a.7":
    response: "Approved"
    responded_at: "..."

variables:
  feature_description: "Add shop purchase"
  change_id: "add-shop-purchase"
  output_dir: "openspec/changes/add-shop-purchase"

errors: []
warnings: []
---

# Workflow: openspec-proposal

[Human-readable progress display]
```

## Best Practices

### 1. Phase Design

- Keep phases focused on a single concern
- Use `depends_on` for explicit dependencies
- Use `trigger: manual` for optional phases (like archive)

### 2. Step Design

- Keep steps small and focused
- Use `checkpoint` for human decisions
- Set appropriate `max_iterations` limits

### 3. Agent Usage

- Use `parallel: true` when agents are independent
- Limit `max_findings_per_agent` to prevent overwhelming output
- Use `agent_selection: dynamic` for flexible agent pools

### 4. Completion Criteria

- Always define completion criteria for non-checkpoint steps
- Use `file_exists` for concrete deliverables
- Use `no_issues` for validation passes

### 5. Error Handling

- Set `on_rejected` for checkpoints to enable re-work
- Use `optional: true` for non-critical steps
- Set reasonable `max_iterations` to prevent infinite loops
