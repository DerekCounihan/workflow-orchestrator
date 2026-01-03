# Workflow Orchestrator

A Claude Code plugin for configurable workflow orchestration with multi-phase support, parallel agents, per-step looping, and human intervention checkpoints.

## Overview

Workflow Orchestrator replicates the OpenSpec workflow pattern as a standalone, marketplace-distributable plugin. It enables you to:

- **Define workflows in YAML** - Configure phases, steps, agents, and completion criteria
- **Run steps in loops** - Each step loops until completion criteria are met (like Ralph Wiggum)
- **Launch parallel agents** - Run multiple agents simultaneously within steps
- **Enforce checkpoints** - Pause for human intervention at critical decision points
- **Resume from interruption** - State is persisted, allowing workflows to be resumed

## Quick Start

### 1. Install the Plugin

```bash
/plugin marketplace add your-org/workflow-orchestrator
```

### 2. Start a Workflow

```bash
/workflow start openspec-proposal --feature "Add user authentication"
```

### 3. Monitor Progress

```bash
/workflow status
```

### 4. Cancel if Needed

```bash
/workflow cancel
```

## Commands

| Command | Description |
|---------|-------------|
| `/workflow start <name> [--feature <desc>]` | Start a workflow from a template |
| `/workflow status` | Show current workflow status |
| `/workflow cancel` | Cancel active workflow |
| `/workflow resume` | Resume a paused workflow |

## Workflow Configuration

Workflows are defined in YAML files. Here's a basic example:

```yaml
metadata:
  name: "my-workflow"
  version: "1.0.0"

settings:
  max_global_iterations: 100
  default_max_step_iterations: 10
  state_file: ".claude/workflows/{name}.state.md"

phases:
  - id: "research"
    name: "Research Phase"
    steps:
      - id: "research.1"
        name: "Launch Research Agents"
        type: "agents"
        parallel: true
        agents:
          - subagent_type: "codebase-pattern-analyzer"
            prompt: "Analyze patterns for: {feature_description}"
          - subagent_type: "architecture-reviewer"
            prompt: "Review architecture for: {feature_description}"
        max_iterations: 3
        completion_criteria:
          type: "agent_responses"
          min_agents: 2

      - id: "research.2"
        name: "Approval Checkpoint"
        type: "checkpoint"
        gate: "approval"
        stop_gate: true
        prompt: "Please review the research findings and approve to continue."
```

## Step Types

| Type | Description |
|------|-------------|
| `agents` | Launch one or more agents (parallel or sequential) |
| `command` | Execute a shell command or Claude prompt |
| `consolidate` | Merge outputs from previous agent steps |
| `checkpoint` | Pause for human input/approval |
| `conditional` | Branch based on conditions |

## Gate Checks

Gate checks run automatically after a step completes, validating code quality before advancing. If checks fail, the workflow blocks until issues are fixed.

### Configuration

```yaml
# Workflow-level default (applies to all steps)
settings:
  default_gate_checks: "typecheck-lint"

# Step-level override
steps:
  - id: "2.1"
    name: "Implementation"
    type: "task_runner"
    gate_checks:
      type: "typecheck-lint"
      on_failure: "block"
```

### Gate Types

| Type | Commands |
|------|----------|
| `none` | No checks (default) |
| `typecheck` | `pnpm typecheck` |
| `lint` | `pnpm lint` (Biome) |
| `typecheck-lint` | Both typecheck and lint |
| `full-suite` | Typecheck, lint, and tests |
| `custom` | Custom commands from config |

### Behavior

- **On Success**: Workflow advances to next step
- **On Failure**: Blocks advancement, prompts for fixes, re-checks on retry

## Completion Signals

When implementing workflow steps, use these signals:

| Signal | When to Use |
|--------|-------------|
| `<promise>STEP_COMPLETE</promise>` | Current step's completion criteria met |
| `<promise>WORKFLOW_COMPLETE</promise>` | All phases complete |

## Built-in Templates

### OpenSpec Workflow

The default `openspec-workflow.yaml` template includes:

- **Phase 0a**: Product Requirements Discovery
- **Phase 0b**: Technical Research
- **Phase 1**: Scaffolding & Specification
- **Phase 1.5**: Accuracy Validation
- **Phase 1.6**: Tech Steer Validation
- **Phase 1.7**: Final Spec Validation
- **Approval**: User approval checkpoint
- **Phase 2**: Implementation
- **Phase 3**: Archive

## State Management

Workflow state is stored in `.claude/workflows/{name}.state.md`. This file tracks:

- Current phase and step
- Iteration count per step
- Checkpoint responses
- Variables and outputs
- Errors and warnings

## Terminal UI

The workflow orchestrator provides colorful visual feedback in your terminal as steps complete:

### Status Banner
```
┌────────────────────────────────────────────────────────────┐
│  ⚙ WORKFLOW ORCHESTRATOR                                   │
├────────────────────────────────────────────────────────────┤
│  Workflow: openspec-proposal                               │
│  Phase:    0a                                              │
│  Step:     0a.2 - Launch Product Agents                    │
├────────────────────────────────────────────────────────────┤
│  Step Iteration:  2 / 10                                   │
│  Total Iterations: 15                                      │
└────────────────────────────────────────────────────────────┘
```

### Step Complete
```
┌────────────────────────────────────────────────────────────┐
│  ✓ STEP COMPLETE                                           │
├────────────────────────────────────────────────────────────┤
│  Step: 0a.2 - Launch Product Agents                        │
│  Iterations: 3                                             │
└────────────────────────────────────────────────────────────┘
```

### Phase Complete
```
╔════════════════════════════════════════════════════════════╗
║  ★ PHASE COMPLETE                                          ║
╠════════════════════════════════════════════════════════════╣
║  Phase: 0a - Product Requirements Discovery                ║
║  Steps Completed: 7                                        ║
╚════════════════════════════════════════════════════════════╝
```

### Checkpoint Pause
```
┌────────────────────────────────────────────────────────────┐
│  ⏸ CHECKPOINT - AWAITING INPUT                             │
├────────────────────────────────────────────────────────────┤
│  Step: 0a.4 - PRD Review                                   │
│                                                            │
│  Please review and provide your response...                │
└────────────────────────────────────────────────────────────┘
```

### Gate Check Status
```
┌────────────────────────────────────────────────────────────┐
│  ⚙ RUNNING GATE CHECKS                                     │
├────────────────────────────────────────────────────────────┤
│  Type: typecheck-lint                                      │
└────────────────────────────────────────────────────────────┘
│  ✓ All gate checks PASSED                                  │
└────────────────────────────────────────────────────────────┘
```

### Workflow Complete
```
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║     ✓✓✓  WORKFLOW COMPLETE  ✓✓✓                            ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║  Workflow:         openspec-proposal                       ║
║  Total Iterations: 87                                      ║
║  Phases Completed: 9                                       ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝
```

## How It Works

The workflow orchestrator uses Claude Code's **Stop Hook** mechanism to create persistent loops. When Claude tries to exit, the hook intercepts and either continues the workflow or allows exit.

### High-Level Flow

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         WORKFLOW ORCHESTRATOR                               │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                            │
│   User: /workflow start openspec --feature "Add auth"                      │
│                           │                                                │
│                           ▼                                                │
│   ┌─────────────────────────────────────────┐                              │
│   │  1. INITIALIZATION                       │                              │
│   │     • Load workflow.yaml template        │                              │
│   │     • Create .state.md file              │                              │
│   │     • Set variables (feature_desc, etc)  │                              │
│   │     • Inject first step prompt           │                              │
│   └─────────────────────────────────────────┘                              │
│                           │                                                │
│                           ▼                                                │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │                                                                     │  │
│   │   ╔═══════════════════════════════════════════════════════════════╗ │  │
│   │   ║              PHASE LOOP (Sequential)                          ║ │  │
│   │   ╠═══════════════════════════════════════════════════════════════╣ │  │
│   │   ║                                                               ║ │  │
│   │   ║   Phase 0a ──▶ Phase 0b ──▶ Phase 1 ──▶ ... ──▶ Phase N      ║ │  │
│   │   ║       │                                                       ║ │  │
│   │   ║       ▼                                                       ║ │  │
│   │   ║   ┌───────────────────────────────────────────────────────┐   ║ │  │
│   │   ║   │           STEP LOOP (Per-Step Iteration)              │   ║ │  │
│   │   ║   │                                                       │   ║ │  │
│   │   ║   │   Step 1 ──▶ Step 2 ──▶ Step 3 ──▶ ... ──▶ Step N    │   ║ │  │
│   │   ║   │      │                                                │   ║ │  │
│   │   ║   │      ▼                                                │   ║ │  │
│   │   ║   │   ┌─────────────────────────────────────────────┐     │   ║ │  │
│   │   ║   │   │  ITERATION LOOP (Until Complete)            │     │   ║ │  │
│   │   ║   │   │                                             │     │   ║ │  │
│   │   ║   │   │   iter 1 ──▶ iter 2 ──▶ ... ──▶ complete   │     │   ║ │  │
│   │   ║   │   │                                             │     │   ║ │  │
│   │   ║   │   └─────────────────────────────────────────────┘     │   ║ │  │
│   │   ║   │                                                       │   ║ │  │
│   │   ║   └───────────────────────────────────────────────────────┘   ║ │  │
│   │   ║                                                               ║ │  │
│   │   ╚═══════════════════════════════════════════════════════════════╝ │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                           │                                                │
│                           ▼                                                │
│   ┌─────────────────────────────────────────┐                              │
│   │  WORKFLOW COMPLETE                       │                              │
│   │     • State file marked "completed"      │                              │
│   │     • Claude allowed to exit             │                              │
│   └─────────────────────────────────────────┘                              │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Stop Hook Mechanism (Core Engine)

The Stop Hook is the heart of the workflow orchestrator. It intercepts every exit attempt and decides what to do next:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           STOP HOOK FLOW                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Claude completes work and tries to exit                                   │
│                           │                                                 │
│                           ▼                                                 │
│   ┌─────────────────────────────────────────┐                               │
│   │  STOP HOOK INTERCEPTS                   │                               │
│   │  (hooks/stop-hook.sh)                   │                               │
│   └─────────────────────────────────────────┘                               │
│                           │                                                 │
│                           ▼                                                 │
│            ┌──────────────────────────────┐                                 │
│            │ Active workflow exists?       │                                 │
│            └──────────────────────────────┘                                 │
│                     │              │                                        │
│                    NO             YES                                       │
│                     │              │                                        │
│                     ▼              ▼                                        │
│            ┌──────────────┐  ┌──────────────────────────┐                   │
│            │ Allow Exit   │  │ Read last Claude output  │                   │
│            │ (exit 0)     │  │ from transcript          │                   │
│            └──────────────┘  └──────────────────────────┘                   │
│                                        │                                    │
│                                        ▼                                    │
│            ┌───────────────────────────────────────────────┐                │
│            │  Check for WORKFLOW_COMPLETE signal           │                │
│            │  <promise>WORKFLOW_COMPLETE</promise>         │                │
│            └───────────────────────────────────────────────┘                │
│                          │                │                                 │
│                        FOUND          NOT FOUND                             │
│                          │                │                                 │
│                          ▼                ▼                                 │
│            ┌──────────────────┐  ┌───────────────────────────────────┐      │
│            │ Mark workflow    │  │ Check for STEP_COMPLETE signal    │      │
│            │ "completed"      │  │ <promise>STEP_COMPLETE</promise>  │      │
│            │ Allow exit       │  └───────────────────────────────────┘      │
│            └──────────────────┘            │                │               │
│                                          FOUND          NOT FOUND           │
│                                            │                │               │
│                          ┌─────────────────┘                │               │
│                          ▼                                  │               │
│            ┌───────────────────────────────────┐            │               │
│            │  RUN GATE CHECKS                  │            │               │
│            │  (if configured)                  │            │               │
│            │                                   │            │               │
│            │  • typecheck: pnpm typecheck      │            │               │
│            │  • lint: pnpm lint                │            │               │
│            │  • full-suite: + tests            │            │               │
│            └───────────────────────────────────┘            │               │
│                     │              │                        │               │
│                   PASS           FAIL                       │               │
│                     │              │                        │               │
│                     ▼              ▼                        │               │
│   ┌─────────────────────┐  ┌─────────────────────┐         │               │
│   │ ADVANCE TO NEXT     │  │ BLOCK & REQUEST     │         │               │
│   │ STEP                │  │ FIXES               │         │               │
│   │                     │  │                     │         │               │
│   │ • Update state file │  │ Return JSON:        │         │               │
│   │ • Reset iteration=1 │  │ {                   │         │               │
│   │ • Get next prompt   │  │   "decision":"block"│         │               │
│   └─────────────────────┘  │   "reason": "Fix.." │         │               │
│            │               │ }                   │         │               │
│            │               └─────────────────────┘         │               │
│            │                        │                      │               │
│            ▼                        │                      │               │
│   ┌─────────────────────────┐       │                      │               │
│   │ Is next step a          │       │                      │               │
│   │ CHECKPOINT?             │       │                      │               │
│   └─────────────────────────┘       │                      │               │
│          │           │              │                      │               │
│         YES          NO             │                      │               │
│          │           │              │                      │               │
│          ▼           ▼              │                      │               │
│   ┌────────────┐  ┌────────────┐    │                      │               │
│   │ Pause for  │  │ Inject     │    │                      │               │
│   │ human      │  │ next step  │    │                      │               │
│   │ response   │  │ prompt     │    │                      │               │
│   └────────────┘  └────────────┘    │                      │               │
│          │           │              │                      │               │
│          └─────┬─────┘              │                      │               │
│                │                    │                      │               │
│                ▼                    │                      ▼               │
│   ┌────────────────────────────────────────────────────────────────────┐   │
│   │                     CONTINUE LOOP                                  │   │
│   │                                                                    │   │
│   │   Return JSON to Claude Code:                                      │   │
│   │   {                                                                │   │
│   │     "decision": "block",                                           │   │
│   │     "reason": "<next step prompt or fix instructions>",            │   │
│   │     "systemMessage": "Step: X.X - Name (iteration N/M)"            │   │
│   │   }                                                                │   │
│   │                                                                    │   │
│   │   Claude receives the prompt and continues working...              │   │
│   │                                                                    │   │
│   └────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Gate Check Flow (Quality Gates)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GATE CHECK FLOW                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Step outputs <promise>STEP_COMPLETE</promise>                             │
│                           │                                                 │
│                           ▼                                                 │
│   ┌─────────────────────────────────────────┐                               │
│   │  Get gate_checks config                 │                               │
│   │                                         │                               │
│   │  Priority:                              │                               │
│   │  1. Step-level: step.gate_checks.type   │                               │
│   │  2. Workflow: settings.default_gate_checks                              │
│   │  3. Default: "none"                     │                               │
│   └─────────────────────────────────────────┘                               │
│                           │                                                 │
│                           ▼                                                 │
│            ┌──────────────────────────────┐                                 │
│            │ Gate type = "none" or "skip"? │                                 │
│            └──────────────────────────────┘                                 │
│                     │              │                                        │
│                    YES             NO                                       │
│                     │              │                                        │
│                     ▼              ▼                                        │
│            ┌──────────────┐  ┌──────────────────────────────────────┐       │
│            │ Skip checks  │  │  Run gate checks script              │       │
│            │ Advance step │  │  scripts/run-gate-checks.sh          │       │
│            └──────────────┘  └──────────────────────────────────────┘       │
│                                        │                                    │
│                                        ▼                                    │
│                    ┌───────────────────────────────────────┐                │
│                    │         GATE TYPE EXECUTION           │                │
│                    ├───────────────────────────────────────┤                │
│                    │                                       │                │
│                    │  typecheck:     pnpm typecheck        │                │
│                    │  lint:          pnpm lint             │                │
│                    │  typecheck-lint: both                 │                │
│                    │  full-suite:    + pnpm test           │                │
│                    │  custom:        user commands         │                │
│                    │                                       │                │
│                    └───────────────────────────────────────┘                │
│                                        │                                    │
│                          ┌─────────────┴─────────────┐                      │
│                          │                           │                      │
│                       ALL PASS                   ANY FAIL                   │
│                          │                           │                      │
│                          ▼                           ▼                      │
│            ┌─────────────────────────┐  ┌─────────────────────────────┐     │
│            │  ✅ ADVANCE             │  │  ❌ BLOCK                    │     │
│            │                         │  │                             │     │
│            │  • Move to next step    │  │  • Stay on current step     │     │
│            │  • Reset iteration to 1 │  │  • Inject fix instructions  │     │
│            │  • Inject next prompt   │  │  • Wait for STEP_COMPLETE   │     │
│            │                         │  │  • Re-run gate checks       │     │
│            └─────────────────────────┘  └─────────────────────────────┘     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### OpenSpec Workflow Example

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    OPENSPEC WORKFLOW PHASES                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   /workflow start openspec --feature "Add shop purchase"                    │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ PHASE 0a: Product Requirements Discovery                            │   │
│   │                                                                     │   │
│   │   Step 0a.1: Create folder structure                                │   │
│   │        ↓                                                            │   │
│   │   Step 0a.2: Launch product domain agents (parallel)                │   │
│   │        ↓                                                            │   │
│   │   Step 0a.3: Consolidate into PRD                                   │   │
│   │        ↓                                                            │   │
│   │   Step 0a.4: [CHECKPOINT] Review PRD ◄── Human reviews              │   │
│   │        ↓                                                            │   │
│   │   Step 0a.5: Tech Steer questions                                   │   │
│   │        ↓                                                            │   │
│   │   Step 0a.6: [CHECKPOINT] Answer questions ◄── Human answers        │   │
│   │        ↓                                                            │   │
│   │   Step 0a.7: Final PRD approval                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ PHASE 0b: Technical Research                                        │   │
│   │                                                                     │   │
│   │   Step 0b.1: Create research folder                                 │   │
│   │        ↓                                                            │   │
│   │   Step 0b.2: Launch technical agents (parallel)                     │   │
│   │        ↓                                                            │   │
│   │   Step 0b.3: Consolidate into TRD                                   │   │
│   │        ↓                                                            │   │
│   │   Step 0b.4: [CHECKPOINT] Review TRD ◄── Human reviews              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ PHASE 1: Scaffolding & Specification                                │   │
│   │                                                                     │   │
│   │   Step 1.1: Generate spec.md from PRD + TRD                         │   │
│   │        ↓                                                            │   │
│   │   Step 1.2: Generate tasks.md                                       │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ PHASE 1.5-1.7: Multi-Pass Validation                                │   │
│   │                                                                     │   │
│   │   1.5: Accuracy agents (3 batches × 5 agents = 15 agents)           │   │
│   │        ↓                                                            │   │
│   │   1.6: Tech Steer agents (3 batches × 3 agents)                     │   │
│   │        ↓                                                            │   │
│   │   1.7: Final validation (11 specialized review agents)              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ APPROVAL CHECKPOINT                                                 │   │
│   │                                                                     │   │
│   │   [CHECKPOINT] Final approval ◄── Human approves or requests changes│   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ PHASE 2: Implementation                                             │   │
│   │                                                                     │   │
│   │   Step 2.1: Execute tasks from tasks.md                             │   │
│   │             ┌─────────────────────────────────────────┐             │   │
│   │             │  For each task:                         │             │   │
│   │             │    1. Implement the change              │             │   │
│   │             │    2. Mark task [x] complete            │             │   │
│   │             │    3. Run incremental review agents     │             │   │
│   │             │    4. Fix CRITICAL/ERROR issues         │             │   │
│   │             │                                         │             │   │
│   │             │  GATE CHECKS: typecheck-lint ◄──────────┼──── Quality │   │
│   │             │    • pnpm typecheck                     │      Gate   │   │
│   │             │    • pnpm lint                          │             │   │
│   │             └─────────────────────────────────────────┘             │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │ PHASE 3: Archive (manual trigger)                                   │   │
│   │                                                                     │   │
│   │   Step 3.1: Archive completed change                                │   │
│   │             openspec archive {change_id} --yes                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    ↓                                        │
│                   <promise>WORKFLOW_COMPLETE</promise>                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### State File Lifecycle

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         STATE FILE LIFECYCLE                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  .claude/workflows/openspec-add-shop-purchase.state.md                      │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  CREATED (status: running)                                           │   │
│  │                                                                      │   │
│  │  ---                                                                 │   │
│  │  workflow_name: openspec-proposal                                    │   │
│  │  status: running                                                     │   │
│  │  current_phase: "0a"                                                 │   │
│  │  current_step: "0a.1"                                                │   │
│  │  current_iteration: 1                                                │   │
│  │  variables:                                                          │   │
│  │    feature_description: "Add shop purchase"                          │   │
│  │    change_id: "add-shop-purchase"                                    │   │
│  │  ---                                                                 │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  RUNNING (iteration updates)                                         │   │
│  │                                                                      │   │
│  │  current_step: "0a.2"      ← Step advances                           │   │
│  │  current_iteration: 3       ← Iteration increments                   │   │
│  │  total_iterations: 15       ← Total across workflow                  │   │
│  │  phases:                                                             │   │
│  │    "0a": { status: "in_progress", steps_completed: 1 }              │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  PAUSED (at checkpoint)                                              │   │
│  │                                                                      │   │
│  │  status: paused                                                      │   │
│  │  current_step: "0a.4"       ← Waiting at checkpoint                  │   │
│  │  checkpoints:                                                        │   │
│  │    "0a.4": { awaiting_response: true }                              │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                          Human responds                                     │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  RESUMED (continuing)                                                │   │
│  │                                                                      │   │
│  │  status: running                                                     │   │
│  │  checkpoints:                                                        │   │
│  │    "0a.4": { response: "Approved", responded_at: "..." }            │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │  COMPLETED                                                           │   │
│  │                                                                      │   │
│  │  status: completed                                                   │   │
│  │  completed_at: "2026-01-02T15:30:00Z"                               │   │
│  │  total_iterations: 87                                                │   │
│  │  phases:                                                             │   │
│  │    "0a": { status: "completed" }                                    │   │
│  │    "0b": { status: "completed" }                                    │   │
│  │    "1":  { status: "completed" }                                    │   │
│  │    "2":  { status: "completed" }                                    │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## End-to-End Scenario: Adding a Shop Purchase Feature

This walkthrough shows exactly what happens when you run the OpenSpec workflow to add a new feature. We'll follow the journey of implementing "Add shop purchase functionality" from start to finish.

### Starting the Workflow

```bash
User: /workflow start openspec --feature "Add shop purchase functionality to allow users to buy items with points"
```

**What happens:**
1. Plugin loads `templates/openspec-workflow.yaml`
2. Creates state file at `.claude/workflows/openspec-add-shop-purchase.state.md`
3. Sets `feature_description` variable
4. Derives `change_id: "add-shop-purchase"`
5. Injects Phase 0a.1 prompt to Claude

---

### Phase 0a: Product Requirements Discovery

#### Step 0a.1: Create Folder Structure
```
Claude receives prompt:
"Create the OpenSpec change folder structure for: Add shop purchase functionality..."

Claude executes:
  mkdir -p openspec/changes/add-shop-purchase/research
  mkdir -p openspec/changes/add-shop-purchase/artifacts

Claude outputs: <promise>STEP_COMPLETE</promise>

Stop hook:
  ✓ STEP_COMPLETE detected
  ✓ Gate checks: none (skipped for non-code step)
  → Advance to step 0a.2
```

#### Step 0a.2: Launch Product Domain Agents
```
Claude receives prompt:
"Launch product research agents to analyze requirements..."

Claude launches 3 agents in parallel using Task tool:
  1. product-domain-specialist agent
     → Searches Nudj docs for "shop", "purchase", "rewards"
     → Finds: RewardAsset, RewardEntry, points currency system
     → Returns: "Shop purchases should use existing reward redemption patterns"

  2. product-edge-case-analyst agent
     → Analyzes user journeys for shop purchase
     → Returns: "Edge cases: insufficient points, sold out items,
                concurrent purchases, refund scenarios"

  3. competitor-researcher agent (via web search)
     → Researches gamification shop patterns
     → Returns: "Best practices: cart system, purchase history,
                wishlists, limited-time offers"

All agents complete. Claude consolidates findings.
Claude outputs: <promise>STEP_COMPLETE</promise>

Stop hook:
  ✓ STEP_COMPLETE detected
  → Advance to step 0a.3
```

#### Step 0a.3: Consolidate into PRD
```
Claude receives prompt:
"Create PRD document from agent findings..."

Claude writes: openspec/changes/add-shop-purchase/prd.md
  # Product Requirements Document: Shop Purchase

  ## Overview
  Allow users to purchase shop items using their earned points.

  ## User Stories
  - As a user, I want to browse available shop items
  - As a user, I want to purchase items with my points balance
  - As a user, I want to see my purchase history

  ## Requirements
  1. Shop item catalog display
  2. Point balance validation
  3. Purchase transaction processing
  4. Purchase history tracking

  ## Edge Cases
  - Insufficient points: Show error, suggest earning more
  - Sold out: Gray out item, show "Out of Stock"
  - Concurrent purchase: Optimistic locking on inventory
  ...

Claude outputs: <promise>STEP_COMPLETE</promise>

Stop hook:
  → Advance to step 0a.4 (CHECKPOINT)
```

#### Step 0a.4: [CHECKPOINT] PRD Review
```
Claude receives checkpoint prompt:
"PRD is ready for review at openspec/changes/add-shop-purchase/prd.md
 Please review and respond: 'Approved' or 'Changes needed: [details]'"

Stop hook:
  ✓ Checkpoint detected
  → Pause workflow, await human response

=== WORKFLOW PAUSED ===

User reviews PRD and responds:
"Approved - looks good, but also add wishlist functionality"

Stop hook:
  ✓ Human response recorded
  → Resume workflow, advance to step 0a.5
```

#### Step 0a.5: Generate Tech Steer Questions
```
Claude receives prompt:
"Based on PRD feedback, generate 10 technical questions..."

Claude writes questions:
  1. Should wishlist be stored in MongoDB or Redis for quick access?
  2. How should we handle inventory management - real-time or batch?
  3. Should purchase history be a separate collection or embedded?
  ...

Claude outputs: <promise>STEP_COMPLETE</promise>

Stop hook:
  → Advance to step 0a.6 (CHECKPOINT)
```

#### Step 0a.6: [CHECKPOINT] Answer Tech Questions
```
=== WORKFLOW PAUSED ===

User answers:
"1. MongoDB with caching layer
 2. Real-time with optimistic locking
 3. Separate collection for analytics
 ..."

Stop hook:
  → Resume, advance to step 0a.7
```

#### Step 0a.7: Finalize PRD
```
Claude incorporates answers into PRD.
Claude outputs: <promise>STEP_COMPLETE</promise>

Stop hook:
  → Phase 0a complete, advance to Phase 0b
```

---

### Phase 0b: Technical Research

#### Step 0b.1: Create Research Folder
```
Claude creates: openspec/changes/add-shop-purchase/research/

Claude outputs: <promise>STEP_COMPLETE</promise>
```

#### Step 0b.2: Launch Technical Research Agents
```
Claude launches 4 agents in parallel:

  1. codebase-pattern-analyzer
     → Searches for existing purchase/transaction patterns
     → Finds: RewardRedemption flow in apps/api/src/routers/rewards/
     → Returns: "Follow existing redemption pattern with transaction wrapper"

  2. backend-integration-analyst
     → Analyzes data operations needed
     → Returns: "Need: ShopItem schema, Purchase schema, inventory tracking,
                points deduction via existing CurrencyService"

  3. architecture-reviewer
     → Reviews proposed architecture
     → Returns: "Recommendation: New shopRouter, reuse RewardService patterns,
                add ShopService layer"

  4. security-reviewer
     → Analyzes security implications
     → Returns: "Ensure: Rate limiting on purchases, validate point balance
                server-side, prevent negative balance exploits"

Claude outputs: <promise>STEP_COMPLETE</promise>
```

#### Step 0b.3: Consolidate into TRD
```
Claude writes: openspec/changes/add-shop-purchase/research/trd.md

  # Technical Research Document

  ## Architecture Decision
  - New ShopService following RewardService patterns
  - ShopItem and Purchase MongoDB collections
  - tRPC router: shopRouter with procedures:
    - shop.getItems
    - shop.purchase
    - shop.getPurchaseHistory

  ## Files to Modify
  - packages/database/src/schemas/shop-item.ts (new)
  - packages/database/src/schemas/purchase.ts (new)
  - apps/api/src/routers/shop.ts (new)
  - apps/api/src/services/shop.service.ts (new)
  - apps/user/app/shop/page.tsx (new)

  ## Security Considerations
  - Server-side point balance validation
  - Optimistic locking for inventory
  - Rate limiting: 10 purchases/minute/user
  ...

Claude outputs: <promise>STEP_COMPLETE</promise>
```

#### Step 0b.4: [CHECKPOINT] TRD Review
```
=== WORKFLOW PAUSED ===

User: "Approved"

Stop hook:
  → Phase 0b complete, advance to Phase 1
```

---

### Phase 1: Scaffolding & Specification

#### Step 1.1: Generate spec.md
```
Claude combines PRD + TRD into comprehensive spec:

  openspec/changes/add-shop-purchase/spec.md

  # Specification: Add Shop Purchase

  ## Summary
  Implement shop purchase functionality allowing users to buy items with points.

  ## Scope
  ### In Scope
  - Shop item catalog API and UI
  - Purchase transaction with point deduction
  - Purchase history
  - Wishlist functionality

  ### Out of Scope
  - Real money purchases
  - Subscription items
  - Gift purchases

  ## Technical Design
  [Detailed schemas, API contracts, component hierarchy]

  ## Test Plan
  [Unit tests, integration tests, E2E scenarios]

Claude outputs: <promise>STEP_COMPLETE</promise>
```

#### Step 1.2: Generate tasks.md
```
Claude generates implementation tasks:

  openspec/changes/add-shop-purchase/tasks.md

  # Implementation Tasks

  ## 1. Database Schema
  - [ ] 1.1 Create ShopItem schema with fields: name, description,
        pointsCost, inventory, imageUrl, category
  - [ ] 1.2 Create Purchase schema with fields: userId, itemId,
        pointsSpent, purchasedAt, status
  - [ ] 1.3 Add indexes for efficient queries

  ## 2. Backend Services
  - [ ] 2.1 Create ShopService with methods: getItems, purchase,
        getPurchaseHistory, addToWishlist
  - [ ] 2.2 Implement inventory management with optimistic locking
  - [ ] 2.3 Integrate with CurrencyService for point deduction

  ## 3. API Layer
  - [ ] 3.1 Create shopRouter with tRPC procedures
  - [ ] 3.2 Add input validation with Zod schemas
  - [ ] 3.3 Implement rate limiting middleware

  ## 4. Frontend
  - [ ] 4.1 Create ShopPage component with item grid
  - [ ] 4.2 Implement PurchaseModal with confirmation
  - [ ] 4.3 Add PurchaseHistory page
  - [ ] 4.4 Create WishlistButton component

  ## 5. Testing
  - [ ] 5.1 Unit tests for ShopService
  - [ ] 5.2 Integration tests for shopRouter
  - [ ] 5.3 E2E test for purchase flow

  ## 99. Validation
  - [ ] 99.1 Run pnpm typecheck
  - [ ] 99.2 Run pnpm lint
  - [ ] 99.3 Run pnpm test
  - [ ] 99.4 Manual smoke test

Claude outputs: <promise>STEP_COMPLETE</promise>
```

---

### Phase 1.5: Accuracy Validation

```
Claude launches 15 accuracy agents in 3 batches (5 agents each):

Batch 1: Schema & API accuracy
Batch 2: Frontend & UX accuracy
Batch 3: Security & performance accuracy

Agents review spec.md and tasks.md for:
  - Missing requirements from PRD
  - Technical inconsistencies
  - Gap analysis

Findings consolidated. Any CRITICAL issues require spec updates.

Claude outputs: <promise>STEP_COMPLETE</promise>
```

---

### Phase 1.6: Tech Steer Validation

```
Claude launches 9 tech steer agents in 3 batches:

Focus: Architectural decisions, patterns consistency, scalability

Agents validate:
  - Follows existing codebase patterns
  - No architectural anti-patterns
  - Scalability considerations addressed

Claude outputs: <promise>STEP_COMPLETE</promise>
```

---

### Phase 1.7: Final Spec Validation

```
Claude launches 11 specialized review agents:

  1. architecture-reviewer    → File placement, service layers
  2. testing-reviewer         → Test coverage, patterns
  3. performance-reviewer     → Server components, API calls
  4. dead-code-reviewer       → Unused code detection
  5. code-style-reviewer      → Formatting, naming
  6. type-safety-reviewer     → TypeScript strictness
  7. accessibility-reviewer   → Mobile, ARIA labels
  8. documentation-reviewer   → JSDoc, comments
  9. i18n-reviewer           → Translations
  10. patterns-reviewer       → React Query, tRPC patterns
  11. security-reviewer       → Auth, input validation

All agents report findings. Claude addresses any CRITICAL/ERROR issues.

Claude outputs: <promise>STEP_COMPLETE</promise>
```

---

### Approval Phase

```
=== WORKFLOW PAUSED ===

Claude presents:
"Specification complete and validated by 35 agents across 3 validation phases.

Files ready for implementation:
  - openspec/changes/add-shop-purchase/spec.md
  - openspec/changes/add-shop-purchase/tasks.md

Please review and respond:
  'Approved' - Begin implementation
  'Changes needed: [details]' - Revise specification"

User: "Approved"

Stop hook:
  → Advance to Phase 2: Implementation
```

---

### Phase 2: Implementation

#### Step 2.1: Execute Tasks
```
Claude reads tasks.md and begins implementation:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task 1.1: Create ShopItem schema

  Claude writes: packages/database/src/schemas/shop-item.ts

  import { z } from 'zod';

  export const shopItemSchema = z.object({
    _id: z.string(),
    name: z.string(),
    description: z.string(),
    pointsCost: z.number().positive(),
    inventory: z.number().nonnegative(),
    imageUrl: z.string().url(),
    category: z.enum(['merchandise', 'digital', 'experience']),
    isActive: z.boolean().default(true),
    createdAt: z.date(),
    updatedAt: z.date(),
  });

  Claude marks: [x] 1.1 Create ShopItem schema

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task 1.2: Create Purchase schema

  Claude writes: packages/database/src/schemas/purchase.ts

  [Implementation...]

  Claude marks: [x] 1.2 Create Purchase schema

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

... (Claude continues through all tasks)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task 4.1: Create ShopPage component

  Claude writes: apps/user/app/shop/page.tsx

  Triggers incremental review (pattern: "*.tsx"):
    - performance-reviewer: "Consider virtualization for large item lists"
    - accessibility-reviewer: "Add aria-label to purchase buttons"

  Claude fixes issues before proceeding.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Task 99: Validation

  Claude runs: pnpm typecheck
    ✓ No type errors

  Claude runs: pnpm lint
    ✓ No lint errors

  Claude runs: pnpm test
    ✓ All tests pass

All tasks complete!
Claude outputs: <promise>STEP_COMPLETE</promise>

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stop hook:
  ✓ STEP_COMPLETE detected
  ✓ Running gate checks (typecheck-lint)...

  🔍 Running TypeScript...
  ✅ TypeScript: PASSED

  🔍 Running Biome Lint...
  ✅ Biome Lint: PASSED

  ✅ All gate checks passed!

  → Phase 2 complete, advance to Phase 3
```

---

### Phase 3: Archive (Manual Trigger)

```
Phase 3 has trigger: "manual"

=== WORKFLOW PAUSED ===

User can resume later with: /workflow resume

User: /workflow resume

Claude executes:
  openspec archive add-shop-purchase --yes

  Moving openspec/changes/add-shop-purchase/ → openspec/changes/archive/
  Updating specs...
  ✓ Archive complete

Claude outputs: <promise>WORKFLOW_COMPLETE</promise>

Stop hook:
  ✓ WORKFLOW_COMPLETE detected
  → Mark workflow "completed"
  → Allow Claude to exit
```

---

### Final Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                         WORKFLOW COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: Add shop purchase functionality
Change ID: add-shop-purchase

Phases Completed:
  ✓ Phase 0a: Product Requirements Discovery (7 steps)
  ✓ Phase 0b: Technical Research (4 steps)
  ✓ Phase 1: Scaffolding & Specification (2 steps)
  ✓ Phase 1.5: Accuracy Validation (15 agents)
  ✓ Phase 1.6: Tech Steer Validation (9 agents)
  ✓ Phase 1.7: Final Spec Validation (11 agents)
  ✓ Approval: User approved
  ✓ Phase 2: Implementation (20 tasks)
  ✓ Phase 3: Archive

Total Iterations: 87
Human Checkpoints: 4
Agents Launched: 38
Gate Checks Passed: 1

Files Created:
  - packages/database/src/schemas/shop-item.ts
  - packages/database/src/schemas/purchase.ts
  - apps/api/src/routers/shop.ts
  - apps/api/src/services/shop.service.ts
  - apps/user/app/shop/page.tsx
  - apps/user/app/shop/[itemId]/page.tsx
  - apps/user/app/purchase-history/page.tsx
  - apps/user/components/shop/PurchaseModal.tsx
  - apps/user/components/shop/WishlistButton.tsx
  - __tests__/shop.service.test.ts
  - __tests__/shop.router.test.ts
  - tests/e2e/shop-purchase.spec.ts

Archived to: openspec/changes/archive/add-shop-purchase/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## License

MIT
