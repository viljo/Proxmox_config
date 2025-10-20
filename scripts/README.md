# Utility Scripts

This directory contains helper scripts for project maintenance and development.

## Available Scripts

### generate_role_readmes.sh

**Purpose**: Generate or update README.md files for Ansible roles based on a template.

**Usage**:
```bash
./scripts/generate_role_readmes.sh
```

**What it does**:
- Creates README.md for roles that don't have one
- Uses a template with placeholders for role-specific information
- Helps maintain consistent documentation across all roles

**Template Variables**:
- `{{ role_name }}`: Name of the Ansible role
- `{{ purpose }}`: What the role does (manual edit needed)
- `{{ variables }}`: Key configurable variables (manual edit needed)

**Output**: Creates `roles/<role_name>/README.md` for each role

## Creating New Scripts

When adding utility scripts to this directory:

1. **Naming Convention**: Use kebab-case: `script-name.sh`
2. **Shebang**: Start with `#!/usr/bin/env bash`
3. **Documentation**: Add description to this README
4. **Executable**: Make script executable: `chmod +x scripts/script-name.sh`
5. **Error Handling**: Use `set -euo pipefail` for safety

### Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

# Script: script-name.sh
# Purpose: Brief description of what this script does
# Usage: ./scripts/script-name.sh [args]

# Script implementation here
```

## Testing Scripts

Before committing new scripts:

1. Test with shellcheck:
   ```bash
   shellcheck scripts/*.sh
   ```

2. Test execution:
   ```bash
   bash -n scripts/script-name.sh  # Syntax check
   ./scripts/script-name.sh         # Actual run
   ```

3. Document any prerequisites or dependencies

## Script Categories

### Documentation
- `generate_role_readmes.sh` - Generate role documentation

### Maintenance
_No scripts yet - add maintenance scripts here_

### Deployment
_No scripts yet - add deployment helpers here_

### Testing
_No scripts yet - add testing utilities here_

## Related

- **[Development Documentation](../docs/development/)** - Development guides
- **[Tooling Configuration](../.tooling/)** - Linting and framework tools
- **[Project README](../README.md)** - Main project documentation

---

**Last Updated**: 2025-10-20
