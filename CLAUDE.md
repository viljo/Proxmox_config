## CRITICAL - SSH ACCESS RULES - DO NOT VIOLATE

### 192.168.1.0/24 Network SSH (Port 22) - ABSOLUTELY NEVER TOUCH
**The 192.168.1.0/24 management network SSH on port 22 is the USER'S EMERGENCY BACKUP ACCESS.**
- NEVER modify, remove, or change SSH port 22 configuration on the 192.168.1.0/24 network
- NEVER touch /etc/ssh/sshd_config Port 22 setting
- This is the user's last resort access method - DO NOT TOUCH IT UNDER ANY CIRCUMSTANCES

### External SSH Access (Port 2222 via ssh.viljo.se)
- External SSH access is on port 2222: `ssh -p 2222 root@ssh.viljo.se`
- This is the PRIMARY access method for Claude to use
- NAT rule: vmbr2:2222 → 192.168.1.3:2222
- Always use this for normal operations

### Access Priority
1. PRIMARY: `ssh -p 2222 root@ssh.viljo.se` (external via port 2222)
2. BACKUP (user only): `ssh root@192.168.1.3` (internal port 22) - CLAUDE MUST NEVER MODIFY THIS

* Dual ISP Architecture:
  - vmbr0: Starlink ISP (CGNAT) on 192.168.1.0/24 - Management ONLY - MUST NOT TOUCH
  - vmbr2: Bahnhof ISP (public IP via DHCP) - WAN for public services
* Always first access the services and proxmox host via their external dns alias .viljo.se (ssh, web, api etc), as a reserve backup if on the 192.168. net use direct local connection.
* inventory/services.yml:  Service Registry - Single Source of Truth, All services MUST be registered here before deployment
* Always update ansible playbooks so they have the same configuration as the system. The system shall be able to be recreated using the playbooks
* Use ansible vault to keep all secrets and API keys
* Save ansible vault password in a noncomitted textfile in project root
* Always strive to create end to end test (emulating a user testing the service) for all services
* Always run end to end test before assuming service is correctly deployed
* Always check and remove previous existing duplicates before creating a new service

* RemoteLLM/llama.cpp model naming:
  - Always use --alias flag with llama-server to set a clean model name (e.g., "qwen3-coder-30b")
  - Model names should not contain paths or file extensions
  - Standard format: {model-family}-{size} (e.g., "qwen3-coder-30b", "llama-3.1-8b")

* Service Testing - ENFORCING:
  - When testing services, ALWAYS test from external/public access (e.g., curl from the internet, not local)
  - Use WebFetch tool or external DNS resolution to verify services are reachable from outside
  - Local curl from the Proxmox host does NOT validate public accessibility
  - End-to-end tests must emulate a real user accessing from the internet

* Service Registry - ENFORCING:
  - ALWAYS use inventory/group_vars/all/services.yml as the single source of truth for deployed services
  - NEVER guess or assume which services exist - read the services.yml file first
  - Only test/deploy services that are listed in the registry
  - When adding new services, register them in services.yml BEFORE deployment

* Links Portal - ENFORCING:
  - ALL services in services.yml MUST be included in the links.viljo.se portal
  - Exception: Services with `show_in_portal: false` are explicitly excluded
  - When adding/removing services, the links portal MUST be updated to match services.yml
  - The links portal is the user-facing service directory - keep it in sync

* Loopia DNS Records - ENFORCING:
  - ALWAYS delete/replace old DNS records before adding new ones
  - NEVER add duplicate A records - remove the old IP first, then add the new one
  - The loopia-ddns script MUST remove existing records before creating new ones
  - If DNS shows multiple A records for the same subdomain, clean up duplicates immediately
