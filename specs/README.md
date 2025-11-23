# Feature Specifications

This directory contains feature specifications for infrastructure enhancements and new services.

## Specification Status

### ✅ Completed

| Spec ID | Feature Name | Status | Deployed | Notes |
|---------|--------------|--------|----------|-------|
| [004](completed/004-demo-website/) | Demo Website | ✅ Complete | Yes | Validation website for Traefik/DNS |
| [010](completed/010-links-portal/) | Links Portal & Matrix Landing | ✅ Complete | Yes | Service directory at links.viljo.se + matrix animation at viljo.se |

### 🚧 Active

| Spec ID | Feature Name | Status | Started | Notes |
|---------|--------------|--------|---------|-------|
| [009](active/009-home-assistant-supervised/) | Home Assistant Supervised | 🚧 In Progress | 2025-10-22 | Add-on support (Hass.io) with Docker |

### 📋 Planned

| Spec ID | Feature Name | Priority | Complexity | Notes |
|---------|--------------|----------|------------|-------|
| [002](planned/002-docker-platform-selfservice/) | Docker Platform Self-Service | Low | High | Container provisioning API |
| [003](planned/003-external-ssh-admin/) | External SSH Admin Access | High | Low | SSH via viljo.se domain |
| [005](planned/005-webtop-browser/) | Webtop Browser | Medium | Medium | Browser-in-browser service |
| [006](planned/006-wireguard-vpn/) | WireGuard VPN | High | Medium | Secure remote access |
| [007](planned/007-gitlab-ci-runner/) | GitLab CI Runners | Medium | Low | Build executors |
| [008](planned/008-gitlab-cicd/) | GitLab CI/CD Pipelines | Medium | Medium | Automated deployments |
| [009](planned/009-jellyfin-media-server/) | Jellyfin Media Server | Medium | Medium | Media streaming service |

## Specification Lifecycle

```
📋 Planned → 🚧 Active → ✅ Completed
     ↓           ↓            ↓
  (ideas)   (in progress)  (deployed)
```

### Stage Definitions

1. **📋 Planned** (`planned/`)
   - Feature has been specced but not started
   - May have design documents
   - Waiting for capacity or dependencies

2. **🚧 Active** (`active/`)
   - Currently being implemented
   - Has assigned developer/team
   - Regular progress updates

3. **✅ Completed** (`completed/`)
   - Fully implemented and deployed
   - Passed testing and verification
   - Documentation complete
   - Archived for reference

## Specification Structure

Each spec directory should contain:

- **Required**:
  - `spec.md` - Main specification document

- **Optional** (depending on complexity):
  - `plan.md` - Implementation plan
  - `research.md` - Technical research and analysis
  - `data-model.md` - Data structures and entities
  - `quickstart.md` - Quick start guide
  - `tasks.md` - Implementation task breakdown
  - `checklists/` - Validation checklists
  - `contracts/` - API contracts and schemas

## Creating a New Spec

1. Create spec directory in `planned/`:
   ```bash
   mkdir specs/planned/009-feature-name
   ```

2. Create spec file:
   ```bash
   cp .specify/templates/spec-template.md specs/planned/009-feature-name/spec.md
   ```

3. Fill out the specification following the template

4. Update this README to include the new spec in the Planned table

## Moving Between Stages

### Planned → Active

When starting work on a planned spec:

```bash
git mv specs/planned/XXX-feature specs/active/XXX-feature
# Update this README to move from Planned to Active table
```

### Active → Completed

When deployment is complete:

```bash
git mv specs/active/XXX-feature specs/completed/XXX-feature
# Update this README to move from Active to Completed table
```

## Priority Levels

- **High**: Critical infrastructure, security, or blocking other work
- **Medium**: Important but not urgent, quality of life improvements
- **Low**: Nice to have, future enhancements

## Complexity Levels

- **Low**: 1-3 days of work, minimal dependencies
- **Medium**: 1-2 weeks of work, some integration required
- **High**: 2+ weeks, significant architecture changes

## Global Requirements for All New Services

All new public-facing services MUST comply with the following requirements:

### Service Registry Requirement

**SRR-001**: ALL new public-facing services MUST be added to the links portal
- Service entry MUST be added to `roles/demo_site/templates/links.html.j2`
- Entry MUST include: service name, description, icon/emoji, and full URL
- Service MUST be added to appropriate logical grouping
- When service is deprecated or removed, entry MUST be removed from links page

**Purpose**: Ensures users have a centralized directory to discover all available services.

**Reference**: See [Spec 010 - Links Portal](completed/010-links-portal/spec.md)

### DNS and Routing Requirements

- Service subdomain MUST be added to `loopia_dns_records` in inventory
- Service MUST be added to `traefik_services` configuration
- Service MUST be accessible via HTTPS with valid TLS certificate

## Implementation Guidelines

Before moving a spec to Active:

1. ✅ Spec document is complete and reviewed
2. ✅ Dependencies are identified and available
3. ✅ Resource allocation confirmed
4. ✅ Architecture decisions documented (ADRs if needed)
5. ✅ Testing approach defined

Before moving to Completed:

1. ✅ All code implemented and merged
2. ✅ Deployed to production
3. ✅ Tests passing
4. ✅ Documentation updated
5. ✅ Verified working as specified
6. ✅ Runbooks created if needed
7. ✅ **Service added to links portal** (if public-facing)

## Archived Specs

Specs that are deprecated, canceled, or superseded by other implementations:

_None yet_

## Constitution Compliance

Feature specifications are required by the project constitution:
> "All new features must have a specification document before implementation"

This ensures:
- Clear requirements before coding
- Architectural decisions are documented
- Testing criteria are defined
- Knowledge is preserved

## Related Documentation

- [Project README](../README.md) - Overview
- [Documentation Index](../docs/README.md) - All documentation
- [Architecture Decision Records](../docs/adr/) - Design decisions
- [Role Documentation](../roles/) - Implementation details

---

**Last Updated**: 2025-10-22
**Total Specs**: 10 (2 completed, 1 active, 7 planned)

