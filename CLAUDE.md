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
