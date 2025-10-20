# Repository Guidelines

## Project Structure & Module Organization
Ansible roles live under `roles/`, each named for the service it provisions (for example `roles/traefik`, `roles/gitlab`). Top-level orchestration happens in `playbooks/site.yml`, while smaller playbooks in `playbooks/` target specific stacks. Shared inventory and defaults reside in `group_vars/` and `host_vars/`; keep vaulted secrets in `group_vars/all/secrets.yml`. The `inventory/` directory stores NetBox-driven dynamic inventories or fallback static hosts, and `docs/` captures architecture, backup, and recovery notes.

## Build, Test, and Development Commands
Target Python 3.11+ with `ansible-core` 2.16+ by installing `pip install -r requirements.txt`. Use `ansible-galaxy install -r requirements.yml` before contributing new roles to sync dependencies. Run fast syntax checks with `ansible-playbook playbooks/site.yml --check --diff` against a staging inventory. `ansible-lint` and `yamllint` catch formatting and best-practice issues; prefer `ansible-lint roles/<role>` during focused role work. For targeted validation, execute `ansible-playbook playbooks/service.yml --tags <service>` to exercise only updated components.

## Coding Style & Naming Conventions
Write YAML with two-space indentation and explicit document start when files exceed a single play. Prefer lower_snake_case for variables and host/group names; reserve upper-case for vault IDs or constants. Jinja templates should live in `roles/<role>/templates/` and use braces with surrounding spaces (`{{ var_name }}`) for readability. Keep handler names unique and descriptive, e.g., `restart_traefik_service`.

## Testing Guidelines
Validate every change with `ansible-playbook ... --check` against a disposable node before merging. Add idempotence verification by running the same playbook twice and confirming zero changes on the second pass. Where roles include Molecule scenarios, run `molecule test` to cover converge and verify stages. Include new assertions in `roles/<role>/tasks/verify.yml` when introducing configuration that can be programmatically checked.

## Commit & Pull Request Guidelines
Commits should use short, imperative subjects (e.g., `Add traefik TLS defaults`) and group related changes logically. Reference relevant issues in the commit body or PR description, and note any required follow-up tasks. Pull requests need a summary of the service touched, testing evidence (command outputs or logs), and screenshots for UI-facing updates such as dashboards or portals.

## Security & Configuration Tips
Never commit decrypted vault files, secrets, or the Ansible Vault password. Document credential sources in `docs/credentials.md` and update rotation schedules when modifying authentication systems. When adding network-exposed services, update the Traefik router definitions and nftables rules in the same change set to maintain consistent security.
