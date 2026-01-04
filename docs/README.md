# Safari Manager Documentation

This folder contains technical documentation for the Safari Manager platform.

## Contents

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | High-level system architecture, domain model, and design decisions |
| [../AGENTS.md](../AGENTS.md) | Coding conventions and generation rules for AI assistants |

## Documentation Structure

The documentation is split between two files for different purposes:

- **AGENTS.md** (root) — Focused on *how to write code*: conventions, patterns to follow/avoid, framework-specific rules. Includes a concise domain summary for context.
- **ARCHITECTURE.md** (docs/) — Focused on *what the system does*: domain concepts, workflows, architectural patterns, observability, deployment modes.

AI assistants receive AGENTS.md for generation context and can reference ARCHITECTURE.md for deeper understanding.

## Purpose

This documentation is intended to:

1. **Onboard new developers** by providing context on architectural decisions
2. **Guide AI assistants** with project conventions and patterns
3. **Preserve institutional knowledge** about the codebase

## Maintenance

These documents are intentionally kept at a high level to minimize maintenance burden. They describe patterns and principles rather than specific file paths or line numbers, which change frequently.

When updating:
- Focus on "why" over "what"
- Describe patterns, not implementations
- Update when architectural decisions change
- Avoid references to specific files unless absolutely necessary
- Keep AGENTS.md domain summary in sync with ARCHITECTURE.md core concepts
