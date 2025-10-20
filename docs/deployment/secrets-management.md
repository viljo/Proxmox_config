# Secrets Management

All runtime credentials are stored in `group_vars/all/secrets.yml`, which is encrypted with Ansible Vault. The encryption password itself is *not* tracked; create a local file `.vault_pass.txt` (ignored by Git) containing a strong passphrase if you prefer unattended vault operations.

## Editing secrets

```bash
ANSIBLE_LOCAL_TEMP=$(pwd)/.ansible/tmp \
ANSIBLE_VAULT_PASSWORD_FILE=.vault_pass.txt \
ansible-vault edit group_vars/all/secrets.yml
```

If you prefer to be prompted for the password, omit the `ANSIBLE_VAULT_PASSWORD_FILE` environment variable and delete `.vault_pass.txt`.

## Adding new secrets

1. Reference the secret from inventory or role defaults using a `vault_` prefixed variable (for example, `vault_nextcloud_root_password`).
2. Run `ansible-vault edit group_vars/all/secrets.yml` and add the new key/value.
3. Re-run the relevant playbook; all plaintext `_open` fallbacks have been removed, so a missing vault value will surface immediately.

### LDAP users

Basic directory accounts live under the `vault_ldap_users` key in the vault. Each entry should follow this structure:

```json
{
  "uid": "jdoe",
  "given_name": "Jane",
  "sn": "Doe",
  "display_name": "Jane Doe",
  "mail": "jane@example.com",
  "password": "<plaintext password>",
  "groups": ["users", "admins"]
}
```

Passwords are stored temporarily in plaintext inside the vault; the LDAP role hashes them server-side when a user is created. The `groups` array augments the default group set in `ldap_default_user_groups`.

## Rotating the vault password

1. Write the new passphrase to `.vault_pass.txt` (or prepare to type it when prompted).
2. Re-key the vault file:

   ```bash
   ansible-vault rekey group_vars/all/secrets.yml
   ```

3. Distribute the updated `.vault_pass.txt` (or the new passphrase) to trusted operators only.

Remember to keep `.vault_pass.txt` out of backups and source control.
