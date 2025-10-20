# Development Tooling Configuration

This directory contains configuration files for development tools, linters, and frameworks used in the project.

## Directory Structure

```
.tooling/
├── README.md                    # This file
├── ansible-lint/                # Ansible linting configuration
│   └── .ansible-lint           # ansible-lint config
├── yaml-lint/                   # YAML linting configuration
│   └── .yamllint               # yamllint config
├── claude-code/                 # Claude Code configuration
│   └── commands/               # Slash commands (8 files)
└── specify/                     # Specify framework
    ├── memory/                 # Framework memory/context
    ├── scripts/                # Framework scripts
    └── templates/              # Spec templates
```

## Tool Configurations

### Ansible Lint

**Location**: `ansible-lint/.ansible-lint`
**Purpose**: Linting Ansible playbooks and roles for best practices

**Usage**:
```bash
# Run ansible-lint (reads config automatically)
ansible-lint

# Lint specific playbook
ansible-lint playbooks/site.yml

# Lint specific role
ansible-lint roles/firewall/
```

**Configuration**: See `ansible-lint/.ansible-lint` for rules and exclusions

### YAML Lint

**Location**: `yaml-lint/.yamllint`
**Purpose**: YAML file formatting and style checking

**Usage**:
```bash
# Run yamllint (reads config automatically)
yamllint .

# Lint specific file
yamllint inventory/hosts.yml

# Lint directory
yamllint roles/
```

**Configuration**: See `yaml-lint/.yamllint` for rules

### Claude Code

**Location**: `claude-code/`
**Purpose**: Claude Code editor slash commands and configuration

**Slash Commands** (`claude-code/commands/`):
- `/speckit.analyze` - Cross-artifact consistency analysis
- `/speckit.checklist` - Generate custom checklists
- `/speckit.clarify` - Identify underspecified areas
- `/speckit.constitution` - Manage project constitution
- `/speckit.implement` - Execute implementation plan
- `/speckit.plan` - Generate implementation plan
- `/speckit.specify` - Create/update feature specs
- `/speckit.tasks` - Generate task breakdown

**Usage**: Type `/` in Claude Code and select a command

### Specify Framework

**Location**: `specify/`
**Purpose**: Feature specification and planning framework

**Components**:
- `memory/constitution.md` - Project principles and standards
- `scripts/` - Framework automation scripts
- `templates/` - Templates for specs, plans, tasks, etc.

**Usage**: See `.specify/memory/constitution.md` for framework documentation

## Configuration File Locations

Some tools expect config files in specific locations. This directory consolidates them while maintaining compatibility:

| Tool | Expected Location | Actual Location | Solution |
|------|------------------|-----------------|----------|
| ansible-lint | `.ansible-lint` | `.tooling/ansible-lint/.ansible-lint` | Symlink or path arg |
| yamllint | `.yamllint` | `.tooling/yaml-lint/.yamllint` | Symlink or path arg |

### Creating Symlinks (if needed)

If tools don't auto-discover configs:

```bash
# Create symlinks in root
ln -s .tooling/ansible-lint/.ansible-lint .ansible-lint
ln -s .tooling/yaml-lint/.yamllint .yamllint
```

**Note**: Check if this is needed - many tools search parent directories automatically.

## Adding New Tools

When adding new development tools:

1. Create subdirectory: `.tooling/tool-name/`
2. Add configuration file
3. Document in this README
4. Update .gitignore if needed
5. Add usage examples

## Framework Updates

### Specify Framework

The Specify framework is managed separately. To update:

```bash
# Framework files are in .tooling/specify/
# Edit constitution, templates, or scripts as needed
```

### Claude Code Commands

Slash commands are in `.tooling/claude-code/commands/`. To add new commands:

1. Create `.md` file in `commands/`
2. Follow existing command format
3. Document in this README

## IDE Integration

### VSCode

VSCode extensions may need workspace settings:

```json
{
  "ansible.ansible.path": "ansible",
  "ansible.validation.lint.enabled": true,
  "ansible.validation.lint.path": ".tooling/ansible-lint/.ansible-lint",
  "yaml.schemas": {
    ".tooling/yaml-lint/.yamllint": "**/*.yml"
  }
}
```

### Other IDEs

Configuration paths may need to be adjusted for other IDEs. See IDE documentation.

## Ignoring Tooling in Git

The `.gitignore` file should include:
```
# Tooling artifacts
.ansible/
*.retry
```

But keep configuration files committed:
```
# Keep these
!.tooling/
```

## Related Documentation

- **[Development Guide](../docs/development/)** - Development workflows
- **[Contributing Guide](../docs/development/contributing.md)** - How to contribute
- **[Scripts](../scripts/)** - Utility scripts

---

**Last Updated**: 2025-10-20
**Tooling Version**: Consolidated in project restructure
