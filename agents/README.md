# Agent Prompts

This directory contains custom agent definitions that are registered when the plugin is installed. Each agent has a specific role in the workflow orchestration process.

## How It Works

When the workflow YAML references an agent like:

```yaml
agents:
  - subagent_type: "product-domain-specialist"
    prompt: |
      Analyze requirements for: {feature_description}
```

Claude Code:
1. Finds the agent definition in `agents/product-domain-specialist.md`
2. Uses the frontmatter to configure tools and model
3. Combines the agent's base prompt with the step's specific prompt

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

## Agent Frontmatter

Each agent file includes YAML frontmatter that configures the agent:

```yaml
---
name: agent-name
description: What this agent does (shown in /agents list)
tools: ["Read", "Grep", "Glob", "WebSearch"]  # Available tools
model: inherit  # Optional: sonnet, opus, haiku, or inherit
---
```

## Customizing Agents

To customize agents for your project:

1. Copy the agent file to your project's `.claude/agents/` directory
2. Modify as needed
3. Your local version takes precedence over the plugin version

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
