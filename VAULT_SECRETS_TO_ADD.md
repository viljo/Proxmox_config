# Vault Secrets Required for Remaining Deployments

## How to Add Secrets

```bash
cd /Users/anders/git/Proxmox_config
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Then add the following sections to the file:

---

## 1. Coolify Secrets (6 required)

**Add these to secrets.yml:**

```yaml
# Coolify Self-Hosted PaaS Platform
vault_coolify_root_password: "RFJ+sSUWeJE01FkTqzcRFpvjf2sG1PzThOdgOV0ULLk="
vault_coolify_postgres_password: "rG1YhpfYh2WGOaYogmiga4P9yqIlUqL1YT363aHV0eY="
vault_coolify_redis_password: "XIhZd7AdB/DE9pVdLLrl031NLQEUHEc7dz1usUnenpM="
vault_coolify_app_id: "coolify"
vault_coolify_app_key: "base64:9UtZLDtEOYvI/5NTzWX/BG5n2H0d4ut+XbbjP4YaCe0="
vault_coolify_pusher_app_secret: "TiuQQxz+5w5kK+OxnE6pFtYgll8mYtMWGHQuxl899nE="
```

**After adding, deploy with:**
```bash
ansible-playbook playbooks/coolify-deploy.yml --ask-vault-pass
```

---

## 2. Jitsi Meet Secrets (7 required)

**Generate secrets first:**
```bash
# Generate random secrets for Jitsi
for secret in jicofo_component jicofo_auth jvb_auth jibri_recorder jibri_xmpp oidc_client; do
  echo "vault_jitsi_${secret}_secret: \"$(openssl rand -base64 32)\""
done

# Root password
echo "vault_jitsi_root_password: \"$(openssl rand -base64 32)\""
```

**Add output to secrets.yml:**
```yaml
# Jitsi Meet Video Conferencing
vault_jitsi_root_password: "<generated above>"
vault_jitsi_jicofo_component_secret: "<generated above>"
vault_jitsi_jicofo_auth_password: "<generated above>"
vault_jitsi_jvb_auth_password: "<generated above>"
vault_jitsi_jibri_recorder_password: "<generated above>"
vault_jitsi_jibri_xmpp_password: "<generated above>"
vault_jitsi_oidc_client_secret: "<get from Keycloak after creating client>"
```

**Additional prerequisites for Jitsi:**

1. Create Keycloak OIDC client:
   ```bash
   # Access Keycloak admin
   # URL: https://keycloak.viljo.se/admin
   # Create client with:
   # - Client ID: jitsi
   # - Redirect URI: https://meet.viljo.se/*
   # - Client authentication: ON
   # Copy the client secret to vault_jitsi_oidc_client_secret above
   ```

2. Configure firewall UDP port forwarding:
   ```bash
   ssh root@192.168.1.3
   pct exec 101 -- nft add rule inet nat prerouting iifname eth0 udp dport 10000 dnat to 172.16.10.162:10000
   ```

3. Deploy Jitsi:
   ```bash
   ansible-playbook playbooks/site.yml --tags jitsi --ask-vault-pass
   ```

---

## Summary

**Coolify**: 6 secrets (already generated, just need to be added)
- Deployment time: ~5-10 minutes
- Complexity: Low
- **Recommended to deploy first**

**Jitsi**: 7 secrets + Keycloak client + firewall rule
- Deployment time: ~20-30 minutes
- Complexity: High
- **Deploy after Coolify**

---

## Current Status

✅ **All other services are deployed and working:**
- Traefik (HTTPS for all services)
- Nextcloud (with SSO fixed)
- GitLab (with SSO configured)
- qBittorrent (fully operational)
- Jellyfin (ready for media configuration)
- Keycloak (SSO provider)
- Links portal, Webtop, etc.

⏳ **Awaiting vault secrets:**
- Coolify (secrets generated, ready to add)
- Jitsi (secrets need generation + additional setup)

---

**Generated**: 2025-10-27
**Next Action**: Add Coolify secrets to vault and deploy
