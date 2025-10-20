# Architecture Decision Records (ADRs)

This directory contains Architecture Decision Records documenting significant architectural and design decisions made for the Proxmox infrastructure.

## What is an ADR?

An Architecture Decision Record captures an important architectural decision made along with its context and consequences. ADRs help future team members understand why certain decisions were made.

## Format

Each ADR follows this format:

```markdown
# ADR-###: [Short Title]

**Date**: YYYY-MM-DD
**Status**: [Proposed | Accepted | Deprecated | Superseded]
**Deciders**: [Names or roles]

## Context

What is the issue we're facing? What factors are at play?

## Decision

What decision did we make?

## Consequences

What becomes easier or more difficult as a result of this decision?

### Positive Consequences
- Benefit 1
- Benefit 2

### Negative Consequences
- Trade-off 1
- Trade-off 2

## Alternatives Considered

### Alternative 1: [Name]
Why we didn't choose this

### Alternative 2: [Name]
Why we didn't choose this

## References
- Link 1
- Link 2
```

## Existing ADRs

[Add ADRs as numbered files: 001-lxc-over-vms.md, 002-traefik-vs-nginx.md, etc.]

## Template

Use `docs/adr/template.md` as a starting point for new ADRs.

## Constitution Compliance

ADRs are required by the Constitution (Section: Documentation Requirements):
> "Architecture decision records for significant design choices"

Create an ADR whenever you make a decision that:
- Affects multiple services or roles
- Has significant performance or security implications
- Involves trade-offs between competing approaches
- Future maintainers will ask "why did we do it this way?"
