# Role: gitlab_runner_api

## Purpose

Deploys GitLab Runner with Docker executor in an LXC container on Proxmox VE via Proxmox API. This role handles the complete lifecycle of GitLab Runner deployment including:

- LXC container creation via Proxmox API
- Docker installation and configuration
- GitLab Runner installation
- Automatic runner registration with Docker executor
- Container nesting support for Docker-in-Docker (DinD)
- Integration with self-hosted GitLab instance

GitLab Runners execute CI/CD pipeline jobs defined in `.gitlab-ci.yml` files, providing isolated execution environments using Docker containers.

## Variables

See `defaults/main.yml` for all configurable variables.

### Key Variables

**Container Configuration:**
- `gitlab_runner_container_id`: LXC container ID (default: `154`)
- `gitlab_runner_hostname`: Container hostname (default: `gitlab-runner`)
- `gitlab_runner_cores`: CPU cores allocated (default: `4`)
- `gitlab_runner_memory`: RAM in MB (default: `8192`)
- `gitlab_runner_disk`: Root filesystem size in GB (default: `50`)
- `gitlab_runner_swap`: Swap size in MB (default: `2048`)
- `gitlab_runner_unprivileged`: Unprivileged container mode (default: `false` - privileged needed for Docker)
- `gitlab_runner_features`: Container features (default: `nesting=1` - required for Docker)

**Network Configuration:**
- `gitlab_runner_bridge`: Proxmox network bridge (default: `vmbr3`)
- `gitlab_runner_ip_address`: Static IP address (default: `172.16.10.154`)
- `gitlab_runner_netmask`: Network prefix length (default: `24`)
- `gitlab_runner_gateway`: Default gateway (default: `172.16.10.101`)
- `gitlab_runner_dns_servers`: List of DNS servers (default: `["1.1.1.1", "8.8.8.8"]`)

**GitLab Runner Configuration:**
- `gitlab_runner_url`: GitLab instance URL (default: `https://gitlab.viljo.se`)
- `gitlab_runner_registration_token`: Runner authentication token (from vault: `vault_gitlab_runner_registration_token`)
- `gitlab_runner_version`: GitLab Runner version (default: `18.5.0`)
- `gitlab_runner_concurrent`: Maximum concurrent jobs (default: `4`)

**Executor Configuration:**
- `gitlab_runner_executor`: Executor type (default: `docker`)
- `gitlab_runner_tags`: Runner tags for job filtering (default: `["docker", "linux", "self-hosted"]`)
- `gitlab_runner_docker_image`: Default Docker image for jobs (default: `debian:12`)
- `gitlab_runner_docker_privileged`: Enable privileged mode (default: `true` - required for Docker builds)
- `gitlab_runner_docker_volumes`: Volumes to mount in job containers (default: `["/cache", "/certs/client"]`)
- `gitlab_runner_docker_pull_policy`: Image pull policy (default: `if-not-present`)

**Credentials:**
- `gitlab_runner_root_password`: Container root password (from vault: `vault_gitlab_runner_root_password`)

## Dependencies

**Required Ansible Collections:**
- `ansible.builtin` (core modules)
- `community.proxmox` (Proxmox API module)

**External Services:**
- Proxmox VE host with API access
- GitLab instance for runner registration
- Network connectivity for package downloads
- Docker Hub access for pulling container images

**Vault Variables:**
- `vault_gitlab_runner_registration_token`: Runner registration token (obtain from GitLab: Admin → Runners)
- `vault_gitlab_runner_root_password`: Container root password

**Related Roles:**
- `gitlab_api` - Provides GitLab instance for runner registration
- `network` - Configures Proxmox network bridges

## Example Usage

### Basic Deployment with Docker Executor

```yaml
- hosts: proxmox_admin
  roles:
    - role: gitlab_runner_api
      vars:
        gitlab_runner_container_id: 154
        gitlab_runner_hostname: gitlab-runner
        gitlab_runner_url: https://gitlab.example.com
        gitlab_runner_executor: docker
        gitlab_runner_tags:
          - docker
          - linux
          - self-hosted
```

### High-Capacity Runner

```yaml
- hosts: proxmox_admin
  roles:
    - role: gitlab_runner_api
      vars:
        gitlab_runner_container_id: 154
        gitlab_runner_hostname: gitlab-runner-01
        gitlab_runner_cores: 8
        gitlab_runner_memory: 16384
        gitlab_runner_disk: 100
        gitlab_runner_concurrent: 8
        gitlab_runner_tags:
          - docker
          - linux
          - high-capacity
```

### Custom Docker Configuration

```yaml
- hosts: proxmox_admin
  roles:
    - role: gitlab_runner_api
      vars:
        gitlab_runner_docker_image: ubuntu:22.04
        gitlab_runner_docker_privileged: true
        gitlab_runner_docker_volumes:
          - /cache
          - /certs/client
          - /builds:/builds
        gitlab_runner_docker_pull_policy: always
```

## Deployment Process

1. **Container Creation**: Creates LXC container via Proxmox API with nesting enabled
2. **Network Configuration**: Configures static IP, gateway, and DNS
3. **Container Start**: Starts container via API and waits for SSH availability
4. **System Setup**: Installs ca-certificates, curl, and required packages
5. **Docker Installation**: Installs Docker CE via official installation script
6. **Runner Installation**: Installs GitLab Runner from official repository
7. **User Configuration**: Adds gitlab-runner user to docker group
8. **Runner Registration**: Registers runner with GitLab using Docker executor
9. **Concurrency Configuration**: Sets concurrent job limit in config.toml
10. **Service Start**: Enables and starts gitlab-runner systemd service
11. **Verification**: Verifies runner connectivity to GitLab instance

## Runner Registration

The role automatically registers the runner with the following configuration:

```bash
gitlab-runner register \
  --non-interactive \
  --url https://gitlab.viljo.se \
  --registration-token <token> \
  --executor docker \
  --docker-image debian:12 \
  --docker-privileged=true \
  --docker-volumes /cache,/certs/client \
  --docker-pull-policy if-not-present \
  --tag-list docker,linux,self-hosted \
  --name gitlab-runner \
  --run-untagged=false \
  --locked=false
```

**Runner Tags**:
- `docker`: Indicates Docker executor capability
- `linux`: Linux-based execution environment
- `self-hosted`: Distinguishes from shared GitLab.com runners

Jobs in `.gitlab-ci.yml` files can target this runner using tags:

```yaml
build-job:
  tags:
    - docker
    - self-hosted
  image: debian:12
  script:
    - echo "Running on self-hosted Docker runner"
```

## Docker Executor Capabilities

The Docker executor provides isolated job execution with the following capabilities:

### Supported Job Features

- **Docker-in-Docker (DinD)**: Build Docker images within CI jobs
- **Service Containers**: Run database/cache services during jobs (PostgreSQL, Redis, etc.)
- **Custom Images**: Use any Docker image from Docker Hub or private registries
- **Volume Mounts**: Persistent cache storage between jobs
- **Privileged Mode**: Required for Docker builds and system-level operations

### Example CI/CD Job

```yaml
# .gitlab-ci.yml
docker-build:
  tags:
    - docker
    - self-hosted
  image: docker:24
  services:
    - docker:24-dind
  variables:
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker build -t myapp:latest .
    - docker push myapp:latest
```

## Idempotency

- Container creation uses Proxmox API state management (only creates if doesn't exist)
- Runner registration checks if runner is already registered before re-registering
- Configuration changes update `/etc/gitlab-runner/config.toml` idempotently
- Service status checks ensure runner is running

## Notes

### Performance Considerations

- Docker executor requires significant resources for concurrent builds
- Each job spawns a new Docker container with resource overhead
- Adjust `gitlab_runner_concurrent` based on available host resources
- Monitor disk usage: Docker images and build caches accumulate over time

Recommended resources per concurrent job:
- **CPU**: 1 core per concurrent job
- **Memory**: 2GB per concurrent job
- **Disk**: 10GB per concurrent job (for Docker layers and cache)

### Security

- **Privileged Container**: Runner container runs privileged (not unprivileged) to support Docker
- **Nesting Required**: Container feature `nesting=1` enables Docker-in-Docker
- **Secrets Management**: Use GitLab CI/CD variables (masked, protected) for credentials
- **Docker Isolation**: Each job runs in isolated Docker container
- **Runner Token**: Stored in Ansible Vault with `no_log: true` to prevent logging
- **Network Isolation**: Runner should be on isolated network segment (DMZ recommended)

### Container Registry Access

Configure GitLab Container Registry authentication in CI/CD jobs:

```yaml
before_script:
  - echo "$CI_REGISTRY_PASSWORD" | docker login -u "$CI_REGISTRY_USER" --password-stdin $CI_REGISTRY

script:
  - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA .
  - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```

### Troubleshooting

**Check Runner Status**:
```bash
ssh root@172.16.10.154
gitlab-runner status
gitlab-runner list
gitlab-runner verify
```

**View Runner Logs**:
```bash
ssh root@172.16.10.154
journalctl -u gitlab-runner -f
```

**Test Docker**:
```bash
ssh root@172.16.10.154
docker ps
docker run hello-world
```

**Check Runner in GitLab UI**:
- Navigate to: Admin Area → Runners
- Runner should appear with green indicator
- Tags: `docker`, `linux`, `self-hosted`

**Common Issues**:

1. **Runner not appearing in GitLab**:
   - Verify registration token is correct
   - Check GitLab URL is accessible from runner
   - Review runner logs: `journalctl -u gitlab-runner`

2. **Docker-in-Docker fails**:
   - Ensure container has `nesting=1` feature: `pct config 154 | grep features`
   - Verify privileged mode: `gitlab_runner_docker_privileged: true`
   - Check Docker service: `systemctl status docker`

3. **Jobs stuck with "This job is stuck"**:
   - Verify runner tags match job tags
   - Check runner is active: `gitlab-runner verify`
   - Review concurrent job limit: `gitlab_runner_concurrent`

### Rollback Procedure

1. **Stop and remove runner**:
```bash
# On Proxmox host
pct stop 154
pct destroy 154
```

2. **Remove runner from GitLab**:
- Admin Area → Runners → Find runner → Delete

3. **Redeploy**:
```bash
ansible-playbook playbooks/gitlab-runner-deploy.yml --ask-vault-pass
```

### Maintenance

**Update GitLab Runner**:
```bash
ssh root@172.16.10.154
apt-get update
apt-get install --only-upgrade gitlab-runner
systemctl restart gitlab-runner
```

**Clear Docker Cache**:
```bash
ssh root@172.16.10.154
docker system prune -af --volumes
```

**Monitor Disk Usage**:
```bash
ssh root@172.16.10.154
df -h /
docker system df
```

### Known Limitations

- Uses privileged LXC container (not unprivileged) due to Docker requirements
- Docker-in-Docker has performance overhead compared to native execution
- Concurrent job limit affects pipeline queue times
- No automatic cleanup of Docker images/volumes (manual maintenance required)
- Runner registration token must be manually obtained from GitLab UI

## Constitution Compliance

- ✅ **Infrastructure as Code**: Fully managed via Ansible role with Proxmox API
- ✅ **Security-First Design**: Vault secrets, network isolation, Docker container isolation
- ✅ **Idempotent Operations**: Safe re-run capability with state checks
- ✅ **Single Source of Truth**: Configuration centralized in role variables
- ✅ **Automated Operations**: Deployment fully automated via playbook

---

## Integration with CI/CD Templates

This runner is designed to work with the CI/CD templates in `specs/planned/008-gitlab-cicd/ci-templates/`:

- **docker-build.gitlab-ci.yml**: Docker image building
- **ansible-role-test.gitlab-ci.yml**: Ansible role testing and linting
- **deployment-with-approval.gitlab-ci.yml**: Multi-stage deployments with approval gates

See `specs/planned/008-gitlab-cicd/ci-templates/README.md` for template usage documentation.

---

**Status**: ✅ Production-ready - Docker executor configured and tested
**Last Updated**: 2025-10-27
