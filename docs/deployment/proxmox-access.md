# Proxmox Access Notes

- Primary management host: `mother` (Proxmox VE).
- SSH access available via: `ssh root@192.168.1.3`
- All infrastructure playbooks target inventory host `proxmox_admin`.
- When running Ansible locally, ensure `ANSIBLE_LOCAL_TEMP` and `ANSIBLE_REMOTE_TMP` point to writable paths (e.g. `$(pwd)/.ansible/tmp`).
