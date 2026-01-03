# Agent Prompts

This directory contains generic agent prompts that the workflow orchestrator injects into `general-purpose` agents.

## How It Works

When the workflow YAML references an agent like:

```yaml
agents:
  - subagent_type: "general-purpose"
    prompt_file: "agents/product-domain-specialist.md"
    prompt: |
      Analyze requirements for: {feature_description}
```

The orchestrator:
1. Reads the prompt file from this directory
2. Prepends it to the step's prompt
3. Launches a `general-purpose` agent with the combined prompt

## Available Agents

| Agent | Purpose |
|-------|---------|
| `product-domain-specialist.md` | Maps user requirements to platform concepts, researches industry patterns |
| `product-edge-case-analyst.md` | Identifies edge cases, failure modes, and user scenarios |
| `codebase-pattern-analyzer.md` | Maps codebase architecture, traces dependencies, identifies patterns |
| `architecture-reviewer.md` | Reviews file placement, layer separation, dependency direction |
| `backend-integration-analyst.md` | Analyzes data operations, caching, events, webhooks |
| `accuracy-validator.md` | Validates spec claims against actual codebase |
| `tech-steer-validator.md` | Ensures specs align with developer guidance |

## Customizing Agents

To customize agents for your project:

1. Copy the agent file to your project's `.claude/agents/` directory
2. Modify as needed
3. The workflow will use your local version if it exists

The lookup order is:
1. `.claude/agents/{agent-name}.md` (project-specific)
2. `${CLAUDE_PLUGIN_ROOT}/agents/{agent-name}.md` (plugin default)

## Creating New Agents

Agent prompt files should include:

1. **Role description** - What the agent does
2. **Focus areas** - Specific responsibilities
3. **Process/phases** - Step-by-step workflow
4. **Output format** - Expected structure of results
5. **Rules** - Constraints and guidelines
