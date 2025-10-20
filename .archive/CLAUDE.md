# Proxmox_config Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-20

## Active Technologies
- YAML (Ansible 2.15+), Shell scripting (bash) + Ansible, fail2ban, openssh-server, loopia-ddns (existing), nftables/iptables (003-external-ssh-admin)
- YAML (Ansible 2.15+), Jinja2 templates + LinuxServer.io Webtop Docker image, KasmVNC, Docker in LXC, Traefik reverse proxy (005-webtop-browser)
- LXC container storage (ZFS/LVM), persistent volumes for user home directories (005-webtop-browser)
- YAML (Ansible 2.15+), Shell scripting (bash 4.0+), Jinja2 templates (007-gitlab-ci-runner)
- PostgreSQL (GitLab database), Redis (GitLab cache), persistent volumes (ZFS/LVM for repositories, uploads, container registry) (007-gitlab-ci-runner)
- YAML (Ansible 2.15+), Jinja2 templates, Shell scripts + WireGuard (kernel module), wg-quick, qrencode, Debian 13 base (006-wireguard-vpn)
- File-based configuration (/etc/wireguard/wg0.conf), Ansible Vault for keys (006-wireguard-vpn)
- YAML (Ansible 2.15+), Jinja2 templates, Shell scripts (bash), GitLab CE 16.x+, GitLab Runner 16.x+ + GitLab Omnibus package, GitLab Runner package, Docker CE (for runner executor), PostgreSQL 13+ (bundled), Redis 6+ (bundled), Git 2.x (008-gitlab-cicd)
- File-based repository storage (/var/opt/gitlab/git-data), PostgreSQL for metadata, Redis for caching/queuing, artifact storage (/var/opt/gitlab/gitlab-rails/shared/artifacts) (008-gitlab-cicd)

## Project Structure
```
src/
tests/
```

## Commands
# Add commands for YAML (Ansible 2.15+), Shell scripting (bash)

## Code Style
YAML (Ansible 2.15+), Shell scripting (bash): Follow standard conventions

## Recent Changes
- 008-gitlab-cicd: Added YAML (Ansible 2.15+), Jinja2 templates, Shell scripts (bash), GitLab CE 16.x+, GitLab Runner 16.x+ + GitLab Omnibus package, GitLab Runner package, Docker CE (for runner executor), PostgreSQL 13+ (bundled), Redis 6+ (bundled), Git 2.x
- 006-wireguard-vpn: Added YAML (Ansible 2.15+), Jinja2 templates, Shell scripts + WireGuard (kernel module), wg-quick, qrencode, Debian 13 base
- 007-gitlab-ci-runner: Added YAML (Ansible 2.15+), Shell scripting (bash 4.0+), Jinja2 templates

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
