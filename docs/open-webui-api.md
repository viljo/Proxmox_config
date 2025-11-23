# Open WebUI API Access

## Overview

Open WebUI at https://llm.viljo.se is configured with dual authentication:

1. **Web Interface**: Protected by OAuth2-Proxy (GitLab SSO)
2. **API Endpoints**: Accessible with API key authentication (bypasses OAuth)

This allows secure web UI access while enabling external API integrations.

## Architecture

```
Internet → Traefik (HTTPS)
              ↓
    ┌─────────┴─────────┐
    │                   │
Web UI Path        API Path (/api/*)
    │                   │
    ↓                   ↓
OAuth2-Proxy      Direct Access
(GitLab SSO)     (API Key Required)
    │                   │
    └─────────┬─────────┘
              ↓
        Open WebUI Container
              ↓
     Ollama LLM VM (172.31.31.201:11434)
```

## OAuth2-Proxy Configuration

The proxy is configured to skip authentication for API endpoints:

```yaml
environment:
  - OAUTH2_PROXY_SKIP_AUTH_REGEX=^/api/.*
```

This regex pattern allows all paths starting with `/api/` to bypass OAuth authentication.

## API Endpoints

Open WebUI provides OpenAI-compatible API endpoints:

### Public Endpoints (No Auth Required)

```bash
# Get API configuration
curl https://llm.viljo.se/api/config

# Response includes:
# - "enable_api_key": true
# - "auth": true
# - version, features, etc.
```

### Protected Endpoints (API Key Required)

All other API endpoints require an API key:

```bash
# List available models (requires API key)
curl https://llm.viljo.se/api/models \
  -H "Authorization: Bearer YOUR_API_KEY"

# Chat completion (OpenAI-compatible)
curl https://llm.viljo.se/api/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_API_KEY" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

## Generating API Keys

1. **Access Web UI**: Visit https://llm.viljo.se and authenticate with GitLab SSO (@viljo.se email)

2. **Navigate to Settings**: Click your profile → Settings

3. **API Keys Section**: Find "API Keys" or "Account" section

4. **Generate New Key**:
   - Click "Create API Key"
   - Give it a descriptive name (e.g., "External Integration")
   - Copy the key immediately (it won't be shown again)

5. **Store Securely**: Save the API key in a secure location (password manager, vault, etc.)

## Using API Keys

### cURL Examples

```bash
# Set API key as environment variable
export OPENAI_API_KEY="sk-..."  # Your Open WebUI API key
export OPENAI_API_BASE="https://llm.viljo.se"

# List models
curl $OPENAI_API_BASE/api/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# Chat completion
curl $OPENAI_API_BASE/api/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [
      {"role": "system", "content": "You are a helpful assistant."},
      {"role": "user", "content": "What is 2+2?"}
    ],
    "temperature": 0.7,
    "max_tokens": 150
  }'
```

### Python Example

```python
from openai import OpenAI

# Initialize client with Open WebUI endpoint
client = OpenAI(
    base_url="https://llm.viljo.se/v1",  # Note: /v1 suffix
    api_key="sk-..."  # Your Open WebUI API key
)

# List available models
models = client.models.list()
for model in models.data:
    print(f"- {model.id}")

# Chat completion
response = client.chat.completions.create(
    model="qwen2.5:0.5b",
    messages=[
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user", "content": "What is 2+2?"}
    ],
    temperature=0.7,
    max_tokens=150
)

print(response.choices[0].message.content)
```

### TypeScript/JavaScript Example

```typescript
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'https://llm.viljo.se/v1',
  apiKey: process.env.OPENAI_API_KEY,  // Your Open WebUI API key
});

async function chat() {
  const completion = await client.chat.completions.create({
    model: 'qwen2.5:0.5b',
    messages: [
      { role: 'system', content: 'You are a helpful assistant.' },
      { role: 'user', content: 'What is 2+2?' }
    ],
    temperature: 0.7,
    max_tokens: 150,
  });

  console.log(completion.choices[0].message.content);
}

chat();
```

## Security Considerations

### Web UI Security
- ✅ Protected by OAuth2-Proxy (GitLab SSO)
- ✅ Only @viljo.se email domain allowed
- ✅ Session cookies are secure, httpOnly, and SameSite=lax
- ✅ Auto-redirect to GitLab authentication

### API Security
- ✅ API key authentication required for all protected endpoints
- ✅ HTTPS only (TLS 1.2+)
- ✅ API keys can be revoked at any time
- ⚠️ API endpoints bypass OAuth (by design for external integrations)
- ⚠️ Keep API keys secret - treat them like passwords

### Best Practices

1. **API Key Management**:
   - Store API keys in environment variables or secure vaults
   - Never commit API keys to version control
   - Rotate keys periodically
   - Use separate keys for different applications
   - Revoke unused keys

2. **Network Security**:
   - API is only accessible via HTTPS
   - Certificate validation enabled by default
   - Monitor API usage via container logs

3. **Access Control**:
   - Only authenticated users (via OAuth) can generate API keys
   - API keys inherit user permissions
   - Audit API key usage regularly

## Monitoring

### Check OAuth2-Proxy Logs
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker logs oauth2-proxy-llm --tail 50"
```

### Check Open WebUI Logs
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker logs open-webui --tail 50"
```

### Verify OAuth Protection
```bash
# Web UI - should redirect to GitLab OAuth
curl -I https://llm.viljo.se

# API - should return 401 without API key
curl https://llm.viljo.se/api/models
```

## Troubleshooting

### Issue: Web UI not redirecting to OAuth

**Check OAuth2-proxy status:**
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker ps --filter name=oauth2-proxy-llm"
```

**Check logs:**
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker logs oauth2-proxy-llm --tail 100"
```

### Issue: API returns 401 with valid API key

**Verify API key is correct:**
- Check for typos
- Ensure no extra whitespace
- Verify key hasn't been revoked

**Check Open WebUI logs:**
```bash
ssh root@192.168.1.3 "pct exec 200 -- docker logs open-webui | grep -i 'api\|auth'"
```

### Issue: API bypassing OAuth but still getting 404

**Check endpoint path:**
- Ensure path starts with `/api/`
- OAuth2-proxy skip regex: `^/api/.*`
- Try `/api/config` to verify bypass is working

## Related Documentation

- [Open WebUI Documentation](https://docs.openwebui.com/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [OAuth2-Proxy Configuration](https://oauth2-proxy.github.io/oauth2-proxy/)
- Infrastructure: `docs/architecture/`
- Deployment: `playbooks/open-webui-deploy.yml`

## Configuration Files

- **Open WebUI**: `/opt/docker-stack/open-webui/docker-compose.yml` (LXC 200)
- **OAuth2-Proxy**: `/opt/docker-stack/oauth2-proxy-llm/docker-compose.yml` (LXC 200)
- **Service Registry**: `inventory/group_vars/all/services.yml`

## Summary

| Access Method | Authentication | Use Case |
|---------------|----------------|----------|
| Web UI (https://llm.viljo.se) | OAuth2-Proxy (GitLab SSO) | Human users, interactive chat |
| API (https://llm.viljo.se/api/*) | API Key (Bearer token) | External integrations, automation |

Both methods ultimately connect to the same Ollama LLM backend (172.31.31.201:11434), providing secure access while enabling flexibility for different use cases.
